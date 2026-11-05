#ifndef __ALGOSYSTEM_EXECUTIONLEDGER_MQH__
#define __ALGOSYSTEM_EXECUTIONLEDGER_MQH__

#include "Types.mqh"
#include <Files\File.mqh>
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Execution Ledger States                                          |
//+------------------------------------------------------------------+
enum ENUM_EXEC_ATTEMPT_STATE
  {
   EXEC_STATE_NONE = 0,
   EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED,
   EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED,
   EXEC_STATE_SUBMITTED,
   EXEC_STATE_PARTIAL_FILL,
   EXEC_STATE_COMPLETED,
   EXEC_STATE_FINAL_FAILURE,
   EXEC_STATE_RECONCILIATION_REQUIRED,
   EXEC_STATE_ABORTED
  };

// E2.3: Setup Claim state
enum ENUM_SETUP_CLAIM_STATE
  {
   SETUP_CLAIM_UNCLAIMED = 0,
   SETUP_CLAIM_ACTIVE,
   SETUP_CLAIM_RETRY_AUTHORIZED,
   SETUP_CLAIM_RESOLVED
  };

// E2.4: Gateway Authority state
enum ENUM_GATEWAY_AUTHORITY_STATE
  {
   GATEWAY_AUTHORITY_UNCLAIMED = 0,
   GATEWAY_AUTHORITY_CLAIMED,
   GATEWAY_AUTHORITY_RELEASED,
   GATEWAY_AUTHORITY_ORPHANED
  };

//+------------------------------------------------------------------+
//| Execution Attempt Record                                         |
//+------------------------------------------------------------------+
struct ExecutionAttemptRecord
  {
   string                attempt_id;
   string                setup_id;
   string                symbol;
   ulong                 magic;
   ENUM_ORDER_INTENT     intent;
   ENUM_SIGNAL_DIRECTION direction;
   double                requested_volume;
   double                executed_volume;
   double                remaining_volume;
   double                entry_price;
   double                stop_loss;
   double                take_profit;
   datetime              created_at;
   datetime              submission_bound_at;
   datetime              submitted_at;
   datetime              broker_response_at;
   datetime              observed_at;
   datetime              resolved_at;
   uint                  last_retcode;
   string                last_retcode_desc;
   ulong                 broker_order_ticket;
   ulong                 broker_deal_ticket;
   ulong                 broker_position_ticket;
   string                failure_class;
   ENUM_EXEC_ATTEMPT_STATE state;
   bool                  submission_allowed;
   string                last_reason;
   int                   schema_version;
  };

//+------------------------------------------------------------------+
//| Execution Ledger                                                  |
//+------------------------------------------------------------------+
class CExecutionLedger
  {
private:
   int                m_db_handle;
   bool               m_initialized;
   bool               m_db_available;
   string             m_db_filename;
   int                m_schema_version;
   int                m_open_attempts_count;
   string             m_last_init_stage;
   string             m_last_init_operation;
   int                m_last_init_error;

   bool               CreateSchema();
   bool               MigrateSchema();
   bool               ExecuteSQL(const string sql);
   string             GenerateAttemptId();
   string             EscapeSQL(const string s) const;

public:
                     CExecutionLedger();
                    ~CExecutionLedger();

   bool               Initialize(const string db_name="execution_ledger.sqlite");
   void               Deinitialize();

    bool               IsInitialized() const { return m_initialized && m_db_available; }
    bool               IsAvailable() const { return m_db_available; }
   string             LastInitStage() const { return m_last_init_stage; }
   string             LastInitOperation() const { return m_last_init_operation; }
   int                LastInitError() const { return m_last_init_error; }

    bool               GetAttemptState(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE &state);
    bool               GetAttempt(const string attempt_id, ExecutionAttemptRecord &record);
    bool               HasUnresolvedForSymbol(const string symbol, bool include_ambiguous);

   // Intent and submission tracking
   bool               CreateIntent(ExecutionAttemptRecord &record);
   bool               MarkSubmissionBound(const string attempt_id, const string reason="");
   bool               CanSubmit(const string attempt_id, string &reason);
   bool               RecordSubmission(const string attempt_id);

   // Result tracking
   bool               RecordResult(const string attempt_id, const ExecutionResult &result, const string reason="");
   bool               MarkReconciliationRequired(const string attempt_id, const string reason);
   bool               ResolveAttempt(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE final_state, const string reason);

    // Broker reconciliation
    bool               ReconcileAttempt(const string attempt_id);
    bool               ReconcileUnresolved(int max_attempts=10);
    int                RecoverUnresolved(int &out_count);
    bool               HasBlockingUnresolved(string &blocking_reason);

    // E2.3: Setup Claim lifecycle
    enum ENUM_CLAIM_RESULT { CLAIM_CREATED=0, CLAIM_ALREADY_EXISTS, CLAIM_IDENTITY_COLLISION, CLAIM_ERROR };
    ENUM_CLAIM_RESULT  CreateClaim(const string strategy_group_key,
                                    const string logical_setup_key,
                                    const string canonical_identity,
                                    int serialization_version,
                                    ExecutionAttemptRecord &initial_attempt);
    bool               RetryAuthorize(const string claim_id,
                                     const string attempt_id,
                                     const string reason);
    bool               RetryCreate(const string claim_id,
                                  const string new_attempt_id,
                                  ExecutionAttemptRecord &new_attempt);
    bool               ResolveClaim(const string claim_id,
                                   const string attempt_id,
                                   ENUM_EXEC_ATTEMPT_STATE final_state,
                                   const string reason);

    // E2.4: Gateway Authority
    bool               ProvisionAuthority(const string authority_key);
    bool               AcquireAuthority(const string authority_key,
                                       const string owner_token,
                                       long &out_epoch);
    bool               ReleaseAuthority(const string authority_key,
                                      const string owner_token,
                                      long current_epoch);
    bool               HeartbeatAuthority(const string authority_key,
                                        const string owner_token,
                                        long current_epoch);
    bool               ValidateAuthority(const string authority_key,
                                       const string owner_token,
                                       long current_epoch);
    int                GetAuthorityState(const string authority_key);

    // State history
    bool               LogStateTransition(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE old_state,
                                          ENUM_EXEC_ATTEMPT_STATE new_state, const string reason,
                                          uint retcode=0);
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CExecutionLedger::CExecutionLedger()
  {
   m_db_handle = INVALID_HANDLE;
   m_initialized = false;
   m_db_available = false;
   m_db_filename = "";
   m_schema_version = 1;
    m_open_attempts_count = 0;
    m_last_init_stage = "";
    m_last_init_operation = "";
    m_last_init_error = 0;
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CExecutionLedger::~CExecutionLedger()
  {
   Deinitialize();
  }

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CExecutionLedger::Initialize(const string db_name)
  {
   if(m_initialized)
      return m_db_available;

    m_last_init_stage = "";
    m_last_init_operation = "";
    m_last_init_error = 0;

    m_db_filename = db_name;
    ResetLastError();
    m_db_handle = DatabaseOpen(m_db_filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);

    if(m_db_handle == INVALID_HANDLE)
      {
       m_last_init_stage = "ExecutionLedger.DatabaseOpen";
       m_last_init_operation = "DatabaseOpen";
       m_last_init_error = GetLastError();
       m_db_available = false;
       m_initialized = true;
       return false;
      }

   m_db_available = true;

   // Check schema
    if(!CreateSchema())
      {
       if(m_last_init_stage == "")
         {
          m_last_init_stage = "ExecutionLedger.CreateSchema";
          m_last_init_operation = "CreateSchema";
          m_last_init_error = GetLastError();
         }
       DatabaseClose(m_db_handle);
       m_db_handle = INVALID_HANDLE;
       m_db_available = false;
       m_initialized = true;
       return false;
      }

   if(!MigrateSchema())
     {
      // Migration failure is serious - don't proceed
      DatabaseClose(m_db_handle);
      m_db_handle = INVALID_HANDLE;
      m_db_available = false;
      m_initialized = true;
      return false;
     }

   m_initialized = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void CExecutionLedger::Deinitialize()
  {
   if(m_db_handle != INVALID_HANDLE)
     {
      DatabaseClose(m_db_handle);
      m_db_handle = INVALID_HANDLE;
     }
   m_db_available = false;
   m_initialized = false;
  }

//+------------------------------------------------------------------+
//| Escape SQL                                                        |
//+------------------------------------------------------------------+
string CExecutionLedger::EscapeSQL(const string s) const
   {
    string result = s;
    StringReplace(result, "'", "''");
    return result;
   }

//+------------------------------------------------------------------+
//| Database Column String Helper                                    |
//+------------------------------------------------------------------+
string DatabaseColumnString(int handle, int column)
   {
    string result = "";
    DatabaseColumnText(handle, column, result);
    return result;
   }

long DatabaseColumnLong2(int handle, int column)
   {
    long result = 0;
    DatabaseColumnLong(handle, column, result);
    return result;
   }

double DatabaseColumnDouble2(int handle, int column)
   {
    double result = 0.0;
    DatabaseColumnDouble(handle, column, result);
    return result;
   }

//+------------------------------------------------------------------+
//| Execute SQL                                                       |
//+------------------------------------------------------------------+
bool CExecutionLedger::ExecuteSQL(const string sql)
  {
   if(m_db_handle == INVALID_HANDLE)
      return false;

    if(!DatabaseExecute(m_db_handle, sql))
       return false;
    return true;
  }

//+------------------------------------------------------------------+
//| Create Schema                                                     |
//+------------------------------------------------------------------+
bool CExecutionLedger::CreateSchema()
  {
   if(m_db_handle == INVALID_HANDLE)
      return false;

   string sql1 = "CREATE TABLE IF NOT EXISTS execution_attempts ("
                 "attempt_id TEXT PRIMARY KEY,"
                 "setup_id TEXT,"
                 "symbol TEXT,"
                 "magic INTEGER,"
                 "intent INTEGER,"
                 "direction INTEGER,"
                 "requested_volume DOUBLE,"
                 "executed_volume DOUBLE,"
                 "remaining_volume DOUBLE,"
                 "entry_price DOUBLE,"
                 "stop_loss DOUBLE,"
                 "take_profit DOUBLE,"
                 "created_at INTEGER,"
                 "submission_bound_at INTEGER,"
                 "submitted_at INTEGER,"
                 "broker_response_at INTEGER,"
                 "observed_at INTEGER,"
                 "resolved_at INTEGER,"
                 "last_retcode INTEGER,"
                 "last_retcode_desc TEXT,"
                 "broker_order_ticket INTEGER,"
                 "broker_deal_ticket INTEGER,"
                 "broker_position_ticket INTEGER,"
                 "failure_class TEXT,"
                 "state INTEGER,"
                 "submission_allowed INTEGER,"
                 "last_reason TEXT,"
                 "schema_version INTEGER"
                 ");";

    ResetLastError();
    if(!ExecuteSQL(sql1))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql1:CREATE_EXECUTION_ATTEMPTS)";
       m_last_init_error = GetLastError();
       return false;
      }

    string sql2 = "CREATE TABLE IF NOT EXISTS execution_state_history ("
                 "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                 "attempt_id TEXT,"
                 "old_state INTEGER,"
                 "new_state INTEGER,"
                 "transition_at INTEGER,"
                 "reason TEXT,"
                 "retcode INTEGER"
                 ");";

    ResetLastError();
    if(!ExecuteSQL(sql2))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql2:CREATE_EXECUTION_STATE_HISTORY)";
       m_last_init_error = GetLastError();
       return false;
      }

    string sql3 = "CREATE TABLE IF NOT EXISTS execution_schema_meta ("
                 "key TEXT PRIMARY KEY,"
                 "value TEXT"
                 ");";

    ResetLastError();
    if(!ExecuteSQL(sql3))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql3:CREATE_EXECUTION_SCHEMA_META)";
       m_last_init_error = GetLastError();
       return false;
      }

    // E2.3: setup_claims table
    string sql4 = "CREATE TABLE IF NOT EXISTS setup_claims ("
                 "claim_id TEXT PRIMARY KEY,"
                 "strategy_group_key TEXT,"
                 "logical_setup_key TEXT,"
                 "canonical_identity TEXT,"
                 "serialization_version INTEGER,"
                 "claim_state INTEGER,"
                 "current_attempt_id TEXT,"
                 "retry_sequence INTEGER,"
                 "created_at INTEGER,"
                 "updated_at INTEGER,"
                 "resolved_at INTEGER,"
                 "last_reason TEXT,"
                 "UNIQUE(strategy_group_key, logical_setup_key)"
                 ");";

    ResetLastError();
    if(!ExecuteSQL(sql4))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql4:CREATE_SETUP_CLAIMS)";
       m_last_init_error = GetLastError();
       return false;
      }

    // E2.4: account_authority table
    string sql5 = "CREATE TABLE IF NOT EXISTS account_authority ("
                 "GatewayAuthorityKey TEXT PRIMARY KEY,"
                 "claim_state INTEGER,"
                 "authority_epoch INTEGER,"
                 "owner_instance_token TEXT,"
                 "created_at INTEGER,"
                 "claimed_at INTEGER,"
                 "released_at INTEGER,"
                 "heartbeat_at INTEGER,"
                 "last_reason TEXT"
                 ");";

    ResetLastError();
    if(!ExecuteSQL(sql5))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql5:CREATE_ACCOUNT_AUTHORITY)";
       m_last_init_error = GetLastError();
       return false;
      }

   // Check/set schema version
   string check_sql = "SELECT value FROM execution_schema_meta WHERE key='schema_version';";
    ResetLastError();
    int handle = DatabasePrepare(m_db_handle, check_sql);
    if(handle == INVALID_HANDLE)
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "DatabasePrepare(check_schema_version)";
       m_last_init_error = GetLastError();
       return false;
      }

    bool has_version = false;
    ResetLastError();
    bool read_ok = DatabaseRead(handle);
    if(!read_ok)
      {
       int read_error = GetLastError();
       // 5126 = ERR_DATABASE_NO_MORE_DATA: normal end-of-results
       if(read_error != 5126)
         {
          m_last_init_stage = "ExecutionLedger.CreateSchema";
          m_last_init_operation = "DatabaseRead(check_schema_version)";
          m_last_init_error = read_error;
          DatabaseFinalize(handle);
          return false;
         }
      }
    else
      {
       string ver = DatabaseColumnString(handle, 0);
       if(ver == IntegerToString(m_schema_version))
          has_version = true;
      }
    DatabaseFinalize(handle);

   if(!has_version)
     {
      string set_ver = "INSERT OR REPLACE INTO execution_schema_meta (key, value) VALUES ('schema_version', '" + IntegerToString(m_schema_version) + "');";
    ResetLastError();
    if(!ExecuteSQL(set_ver))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(set_schema_version)";
       m_last_init_error = GetLastError();
       return false;
      }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Migrate Schema                                                    |
//+------------------------------------------------------------------+
bool CExecutionLedger::MigrateSchema()
  {
   // For now, just validate schema version
   return true;
  }

//+------------------------------------------------------------------+
//| Generate Attempt ID                                               |
//+------------------------------------------------------------------+
string CExecutionLedger::GenerateAttemptId()
  {
   datetime now = TimeCurrent();
   string id = "ATT_" + IntegerToString((long)now) + "_" + IntegerToString(MathRand()) + "_" + IntegerToString(GetTickCount());
   return id;
  }

//+------------------------------------------------------------------+
//| Create Intent                                                     |
//+------------------------------------------------------------------+
bool CExecutionLedger::CreateIntent(ExecutionAttemptRecord &record)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   if(record.attempt_id == "")
      record.attempt_id = GenerateAttemptId();

   record.created_at = TimeCurrent();
   record.state = EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED;
   record.submission_allowed = false;
   record.executed_volume = 0.0;
   record.remaining_volume = record.requested_volume;
   record.schema_version = m_schema_version;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   string sql = "INSERT INTO execution_attempts (attempt_id, setup_id, symbol, magic, intent, direction, "
                "requested_volume, executed_volume, remaining_volume, entry_price, stop_loss, take_profit, "
                "created_at, state, submission_allowed, schema_version) VALUES ('" +
                EscapeSQL(record.attempt_id) + "','" +
                EscapeSQL(record.setup_id) + "','" +
                EscapeSQL(record.symbol) + "'," +
                IntegerToString((long)record.magic) + "," +
                IntegerToString((int)record.intent) + "," +
                IntegerToString((int)record.direction) + "," +
                DoubleToString(record.requested_volume, 8) + "," +
                DoubleToString(record.executed_volume, 8) + "," +
                DoubleToString(record.remaining_volume, 8) + "," +
                DoubleToString(record.entry_price, 8) + "," +
                DoubleToString(record.stop_loss, 8) + "," +
                DoubleToString(record.take_profit, 8) + "," +
                IntegerToString((long)record.created_at) + "," +
                IntegerToString((int)record.state) + "," +
                IntegerToString(0) + "," +
                IntegerToString(record.schema_version) + ");";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(record.attempt_id, EXEC_STATE_NONE, EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED, "Intent created"))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Mark Submission Bound                                             |
//+------------------------------------------------------------------+
bool CExecutionLedger::MarkSubmissionBound(const string attempt_id, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   if(rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   string sql = "UPDATE execution_attempts SET submission_bound_at = " + IntegerToString((long)now) +
                ", submission_allowed = 1, last_reason = '" + EscapeSQL(reason) + "' WHERE attempt_id = '" +
                EscapeSQL(attempt_id) + "' AND state = " + IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) + ";";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(attempt_id, EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED, EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED, reason))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Can Submit                                                        |
//+------------------------------------------------------------------+
bool CExecutionLedger::CanSubmit(const string attempt_id, string &reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     {
      reason = "Ledger not available";
      return false;
     }

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
     {
      reason = "Attempt not found";
      return false;
     }

    if(rec.state == EXEC_STATE_SUBMITTED ||
       rec.state == EXEC_STATE_RECONCILIATION_REQUIRED ||
       rec.state == EXEC_STATE_PARTIAL_FILL ||
       rec.state == EXEC_STATE_COMPLETED ||
       rec.state == EXEC_STATE_FINAL_FAILURE ||
       rec.state == EXEC_STATE_ABORTED)
      {
       reason = "Attempt in non-submittable state: " + IntegerToString((int)rec.state);
       return false;
      }

    if(rec.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
      {
       // Ambiguous state - must not authorize a second submission on restart/retry
       reason = "Attempt in ambiguous state - reconciliation required";
       return false;
      }

    if(rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      {
       reason = "Invalid state for submission";
       return false;
      }

    if(!rec.submission_allowed)
      {
       reason = "Submission not bound";
       return false;
      }

    reason = "OK";
    return true;
  }

//+------------------------------------------------------------------+
//| Record Submission                                                 |
//+------------------------------------------------------------------+
bool CExecutionLedger::RecordSubmission(const string attempt_id)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   if(rec.state != EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED && rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      return false;

    if(rec.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
      {
       // Ambiguous state - do not transition to SUBMITTED without broker evidence
       return false;
      }
    else if(rec.state == EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      {
       // Do not auto-transition from intent to submitted without binding/authorization
       return false;
      }

   return false;
  }

//+------------------------------------------------------------------+
//| Record Result                                                     |
//+------------------------------------------------------------------+
bool CExecutionLedger::RecordResult(const string attempt_id, const ExecutionResult &result, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   ENUM_EXEC_ATTEMPT_STATE new_state = rec.state;

   if(result.reconciliation_required)
     {
      new_state = EXEC_STATE_RECONCILIATION_REQUIRED;
     }
   else if(result.partial_fill)
     {
      new_state = EXEC_STATE_PARTIAL_FILL;
     }
   else if(result.success)
     {
      new_state = EXEC_STATE_COMPLETED;
     }
   else
     {
      if(result.failure_class == "FINAL_FAILURE")
         new_state = EXEC_STATE_FINAL_FAILURE;
      else
         new_state = EXEC_STATE_RECONCILIATION_REQUIRED;
     }

   string sql = "UPDATE execution_attempts SET broker_response_at = " + IntegerToString((long)now) +
                ", observed_at = " + IntegerToString((long)now) +
                ", executed_volume = " + DoubleToString(result.executed_volume, 8) +
                ", remaining_volume = " + DoubleToString(MathMax(0.0, rec.requested_volume - result.executed_volume), 8) +
                ", last_retcode = " + IntegerToString((long)result.retcode) +
                ", last_retcode_desc = '" + EscapeSQL(result.message) + "'" +
                ", broker_order_ticket = " + IntegerToString((long)result.order_ticket) +
                ", broker_deal_ticket = " + IntegerToString((long)result.deal_ticket) +
                ", broker_position_ticket = " + IntegerToString((long)result.position_ticket) +
                ", failure_class = '" + EscapeSQL(result.failure_class) + "'" +
                ", state = " + IntegerToString((int)new_state) +
                ", last_reason = '" + EscapeSQL(reason) + "'" +
                " WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(attempt_id, rec.state, new_state, reason, result.retcode))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Mark Reconciliation Required                                      |
//+------------------------------------------------------------------+
bool CExecutionLedger::MarkReconciliationRequired(const string attempt_id, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   string sql = "UPDATE execution_attempts SET state = " + IntegerToString((int)EXEC_STATE_RECONCILIATION_REQUIRED) +
                ", observed_at = " + IntegerToString((long)now) +
                ", last_reason = '" + EscapeSQL(reason) + "'" +
                " WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(attempt_id, rec.state, EXEC_STATE_RECONCILIATION_REQUIRED, reason))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Resolve Attempt                                                   |
//+------------------------------------------------------------------+
bool CExecutionLedger::ResolveAttempt(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE final_state, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   if(final_state != EXEC_STATE_COMPLETED && final_state != EXEC_STATE_FINAL_FAILURE && final_state != EXEC_STATE_ABORTED)
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   string sql = "UPDATE execution_attempts SET state = " + IntegerToString((int)final_state) +
                ", resolved_at = " + IntegerToString((long)now) +
                ", last_reason = '" + EscapeSQL(reason) + "'" +
                " WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(attempt_id, rec.state, final_state, reason))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Get Attempt                                                       |
//+------------------------------------------------------------------+
bool CExecutionLedger::GetAttempt(const string attempt_id, ExecutionAttemptRecord &record)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   string sql = "SELECT attempt_id, setup_id, symbol, magic, intent, direction, requested_volume, "
                "executed_volume, remaining_volume, entry_price, stop_loss, take_profit, "
                "created_at, submission_bound_at, submitted_at, broker_response_at, observed_at, resolved_at, "
                "last_retcode, last_retcode_desc, broker_order_ticket, broker_deal_ticket, broker_position_ticket, "
                "failure_class, state, submission_allowed, last_reason, schema_version "
                "FROM execution_attempts WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";

   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return false;

   bool found = false;
   if(DatabaseRead(handle))
     {
      record.attempt_id = DatabaseColumnString(handle, 0);
      record.setup_id = DatabaseColumnString(handle, 1);
      record.symbol = DatabaseColumnString(handle, 2);
      record.magic = (ulong)DatabaseColumnLong2(handle, 3);
      record.intent = (ENUM_ORDER_INTENT)DatabaseColumnLong2(handle, 4);
      record.direction = (ENUM_SIGNAL_DIRECTION)DatabaseColumnLong2(handle, 5);
      record.requested_volume = DatabaseColumnDouble2(handle, 6);
      record.executed_volume = DatabaseColumnDouble2(handle, 7);
      record.remaining_volume = DatabaseColumnDouble2(handle, 8);
      record.entry_price = DatabaseColumnDouble2(handle, 9);
      record.stop_loss = DatabaseColumnDouble2(handle, 10);
      record.take_profit = DatabaseColumnDouble2(handle, 11);
      record.created_at = (datetime)DatabaseColumnLong2(handle, 12);
      record.submission_bound_at = (datetime)DatabaseColumnLong2(handle, 13);
      record.submitted_at = (datetime)DatabaseColumnLong2(handle, 14);
      record.broker_response_at = (datetime)DatabaseColumnLong2(handle, 15);
      record.observed_at = (datetime)DatabaseColumnLong2(handle, 16);
      record.resolved_at = (datetime)DatabaseColumnLong2(handle, 17);
      record.last_retcode = (uint)DatabaseColumnLong2(handle, 18);
      record.last_retcode_desc = DatabaseColumnString(handle, 19);
      record.broker_order_ticket = (ulong)DatabaseColumnLong2(handle, 20);
      record.broker_deal_ticket = (ulong)DatabaseColumnLong2(handle, 21);
      record.broker_position_ticket = (ulong)DatabaseColumnLong2(handle, 22);
      record.failure_class = DatabaseColumnString(handle, 23);
      record.state = (ENUM_EXEC_ATTEMPT_STATE)DatabaseColumnLong2(handle, 24);
      record.submission_allowed = (DatabaseColumnLong2(handle, 25) == 1);
      record.last_reason = DatabaseColumnString(handle, 26);
      record.schema_version = (int)DatabaseColumnLong2(handle, 27);
      found = true;
     }
   DatabaseFinalize(handle);
   return found;
  }

//+------------------------------------------------------------------+
//| Recover Unresolved                                                |
//+------------------------------------------------------------------+
int CExecutionLedger::RecoverUnresolved(int &out_count)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     {
      out_count = 0;
      return 0;
     }

   string sql = "SELECT COUNT(*) FROM execution_attempts WHERE state IN (" +
                IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) + "," +
                IntegerToString((int)EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED) + "," +
                IntegerToString((int)EXEC_STATE_SUBMITTED) + "," +
                IntegerToString((int)EXEC_STATE_PARTIAL_FILL) + "," +
                IntegerToString((int)EXEC_STATE_RECONCILIATION_REQUIRED) + ");";

   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
     {
      out_count = 0;
      return 0;
     }

   int count = 0;
   if(DatabaseRead(handle))
      count = (int)DatabaseColumnLong2(handle, 0);
   DatabaseFinalize(handle);

   out_count = count;
   return count;
  }

//+------------------------------------------------------------------+
//| Reconcile Attempt                                                 |
//+------------------------------------------------------------------+
bool CExecutionLedger::ReconcileAttempt(const string attempt_id)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   // Only reconcile in specific states
   if(rec.state != EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED &&
      rec.state != EXEC_STATE_SUBMITTED &&
      rec.state != EXEC_STATE_RECONCILIATION_REQUIRED &&
      rec.state != EXEC_STATE_PARTIAL_FILL)
      return false;

   // Try to find matching orders/deals
   // Search in history
   datetime from_time = rec.created_at - 3600;
   if(from_time < 0) from_time = 0;
   datetime to_time = TimeCurrent() + 3600;

   if(!HistorySelect(from_time, to_time))
      return false;

   // Prefer order/deal/position tickets if present in record
   if(rec.broker_order_ticket > 0)
     {
      // Try to find deals by order
      int deals_total = HistoryDealsTotal();
      double total_volume = 0.0;
      ulong found_deal = 0;
      ulong found_order = rec.broker_order_ticket;
      for(int i = 0; i < deals_total; i++)
        {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0) continue;
         ulong deal_order = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
         if(deal_order != rec.broker_order_ticket) continue;
         string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_symbol != rec.symbol) continue;
         long deal_magic = 0;
         if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC, deal_magic))
           {
            if((ulong)deal_magic != rec.magic) continue;
           }
         total_volume += HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
         if(found_deal == 0) found_deal = deal_ticket;
        }
        if(total_volume > 0.0)
          {
           if(!DatabaseTransactionBegin(m_db_handle))
              return false;
           datetime now = TimeCurrent();
           ENUM_EXEC_ATTEMPT_STATE new_state = EXEC_STATE_COMPLETED;
           if(total_volume < rec.requested_volume - 0.00001)
              new_state = EXEC_STATE_PARTIAL_FILL;
           // Try to resolve position ticket if missing
           ulong pos_ticket_resolved = rec.broker_position_ticket;
           if(pos_ticket_resolved == 0)
             {
              // Try to use position identifier from order/deal
               if(found_order > 0 && HistoryOrderSelect(found_order))
                 {
                  long pos_id = HistoryOrderGetInteger(found_order, ORDER_POSITION_ID);
                  if(pos_id > 0)
                    {
                     int total_pos = PositionsTotal();
                     ulong resolved_pt = 0;
                     int match_count = 0;
                     for(int pp = 0; pp < total_pos; pp++)
                       {
                        ulong pt2 = PositionGetTicket(pp);
                        if(pt2 == 0) continue;
                        if(!PositionSelectByTicket(pt2)) continue;
                        string psym2 = PositionGetString(POSITION_SYMBOL);
                        if(psym2 != rec.symbol) continue;
                        long pm2 = PositionGetInteger(POSITION_MAGIC);
                        if((ulong)pm2 != rec.magic) continue;
                        long pid2 = PositionGetInteger(POSITION_IDENTIFIER);
                        if((ulong)pid2 != (ulong)pos_id) continue;
                        match_count++;
                        resolved_pt = pt2;
                        if(match_count > 1) { resolved_pt = 0; break; }
                       }
                     if(match_count == 1 && resolved_pt != 0) pos_ticket_resolved = resolved_pt;
                    }
                 }
               if(pos_ticket_resolved == 0 && found_deal > 0 && HistoryDealSelect(found_deal))
                 {
                  long pos_id = HistoryDealGetInteger(found_deal, DEAL_POSITION_ID);
                  if(pos_id > 0)
                    {
                     int total_pos = PositionsTotal();
                     ulong resolved_pt = 0;
                     int match_count = 0;
                     for(int pp = 0; pp < total_pos; pp++)
                       {
                        ulong pt2 = PositionGetTicket(pp);
                        if(pt2 == 0) continue;
                        if(!PositionSelectByTicket(pt2)) continue;
                        string psym2 = PositionGetString(POSITION_SYMBOL);
                        if(psym2 != rec.symbol) continue;
                        long pm2 = PositionGetInteger(POSITION_MAGIC);
                        if((ulong)pm2 != rec.magic) continue;
                        long pid2 = PositionGetInteger(POSITION_IDENTIFIER);
                        if((ulong)pid2 != (ulong)pos_id) continue;
                        match_count++;
                        resolved_pt = pt2;
                        if(match_count > 1) { resolved_pt = 0; break; }
                       }
                     if(match_count == 1 && resolved_pt != 0) pos_ticket_resolved = resolved_pt;
                    }
                 }

             }
           string sql = "UPDATE execution_attempts SET broker_deal_ticket = " + 
IntegerToString((long)(found_deal>0?found_deal:rec.broker_deal_ticket)) +
                        ", broker_order_ticket = " + IntegerToString((long)found_order) +
                        ", broker_position_ticket = " + IntegerToString((long)pos_ticket_resolved) +
                        ", executed_volume = " + DoubleToString(total_volume, 8) +
                        ", remaining_volume = " + DoubleToString(MathMax(0.0, rec.requested_volume - total_volume), 8) 
+
                        ", broker_response_at = " + IntegerToString((long)now) +
                        ", observed_at = " + IntegerToString((long)now) +
                        ", resolved_at = " + IntegerToString((long)now) +
                        ", state = " + IntegerToString((int)new_state) +
                        ", last_reason = 'Reconciled with broker history by order ticket' " +
                        " WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";
         if(!ExecuteSQL(sql))
           {
            DatabaseTransactionRollback(m_db_handle);
            return false;
           }
         if(!LogStateTransition(attempt_id, rec.state, new_state, "Broker reconciliation matched by order ticket"))
           {
            DatabaseTransactionRollback(m_db_handle);
            return false;
           }
         if(!DatabaseTransactionCommit(m_db_handle))
            return false;
         return true;
        }
     }

    // Try to find matching orders/deals
    // First check deals
    int deals_total = HistoryDealsTotal();
    bool found_match = false;
    ulong matched_deal = 0;
    ulong matched_order = 0;
    double matched_volume = 0;
    int match_count = 0;

    for(int i = 0; i < deals_total; i++)
      {
       ulong deal_ticket = HistoryDealGetTicket(i);
       if(deal_ticket == 0) continue;

       long deal_magic = 0;
       if(!HistoryDealGetInteger(deal_ticket, DEAL_MAGIC, deal_magic))
          continue;
       if((ulong)deal_magic != rec.magic)
          continue;

       string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
       if(deal_symbol != rec.symbol)
          continue;

       // Check time proximity (within reasonable window)
       datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
       if(deal_time < rec.created_at - 300 || deal_time > TimeCurrent() + 300)
          continue;

       // Found potential match
       match_count++;
       matched_deal = deal_ticket;
       matched_volume += HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
       matched_order = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
       found_match = (match_count >= 1);
      }

    if(!found_match || match_count != 1)
      {
       // No evidence found or ambiguous match - do not auto-resolve to failure
       if(rec.state == EXEC_STATE_RECONCILIATION_REQUIRED)
          return false;
       // Mark as reconciliation required if we don't have evidence
       if(rec.state == EXEC_STATE_SUBMITTED || rec.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
          {
           MarkReconciliationRequired(attempt_id, "No conclusive broker evidence found during reconciliation");
          }
       return false;
      }

     // Found match - but ensure it's conclusive
      if(matched_volume <= 0.0)
        {
         if(rec.state == EXEC_STATE_RECONCILIATION_REQUIRED)
            return false;
         MarkReconciliationRequired(attempt_id, "Ambiguous broker evidence during reconciliation");
         return false;
        }

     // Try to resolve position ticket if missing
     ulong pos_ticket_resolved = rec.broker_position_ticket;
     if(pos_ticket_resolved == 0)
       {
        // Try to use position identifier from order/deal
         if(matched_order > 0 && HistoryOrderSelect(matched_order))
           {
            long pos_id = HistoryOrderGetInteger(matched_order, ORDER_POSITION_ID);
            if(pos_id > 0)
              {
               int total_pos = PositionsTotal();
               ulong resolved_pt = 0;
               int match_count = 0;
               for(int pp = 0; pp < total_pos; pp++)
                 {
                  ulong pt2 = PositionGetTicket(pp);
                  if(pt2 == 0) continue;
                  if(!PositionSelectByTicket(pt2)) continue;
                  string psym2 = PositionGetString(POSITION_SYMBOL);
                  if(psym2 != rec.symbol) continue;
                  long pm2 = PositionGetInteger(POSITION_MAGIC);
                  if((ulong)pm2 != rec.magic) continue;
                  long pid2 = PositionGetInteger(POSITION_IDENTIFIER);
                  if((ulong)pid2 != (ulong)pos_id) continue;
                  match_count++;
                  resolved_pt = pt2;
                  if(match_count > 1) { resolved_pt = 0; break; }
                 }
               if(match_count == 1 && resolved_pt != 0) pos_ticket_resolved = resolved_pt;
              }
           }
         if(pos_ticket_resolved == 0 && matched_deal > 0 && HistoryDealSelect(matched_deal))
           {
            long pos_id = HistoryDealGetInteger(matched_deal, DEAL_POSITION_ID);
            if(pos_id > 0)
              {
               int total_pos = PositionsTotal();
               ulong resolved_pt = 0;
               int match_count = 0;
               for(int pp = 0; pp < total_pos; pp++)
                 {
                  ulong pt2 = PositionGetTicket(pp);
                  if(pt2 == 0) continue;
                  if(!PositionSelectByTicket(pt2)) continue;
                  string psym2 = PositionGetString(POSITION_SYMBOL);
                  if(psym2 != rec.symbol) continue;
                  long pm2 = PositionGetInteger(POSITION_MAGIC);
                  if((ulong)pm2 != rec.magic) continue;
                  long pid2 = PositionGetInteger(POSITION_IDENTIFIER);
                  if((ulong)pid2 != (ulong)pos_id) continue;
                  match_count++;
                  resolved_pt = pt2;
                  if(match_count > 1) { resolved_pt = 0; break; }
                 }
               if(match_count == 1 && resolved_pt != 0) pos_ticket_resolved = resolved_pt;
              }
           }
        // No fallback to ambiguous symbol+magic matching
       }

     // Found match
     if(!DatabaseTransactionBegin(m_db_handle))
        return false;

     datetime now = TimeCurrent();
     ENUM_EXEC_ATTEMPT_STATE new_state = EXEC_STATE_COMPLETED;
     if(matched_volume < rec.requested_volume - 0.00001)
        new_state = EXEC_STATE_PARTIAL_FILL;

     string sql = "UPDATE execution_attempts SET broker_deal_ticket = " + IntegerToString((long)matched_deal) +
                  ", broker_order_ticket = " + IntegerToString((long)matched_order) +
                  ", broker_position_ticket = " + IntegerToString((long)pos_ticket_resolved) +
                  ", executed_volume = " + DoubleToString(matched_volume, 8) +
                  ", remaining_volume = " + DoubleToString(MathMax(0.0, rec.requested_volume - matched_volume), 8) +
                  ", broker_response_at = " + IntegerToString((long)now) +
                  ", observed_at = " + IntegerToString((long)now) +
                  ", resolved_at = " + IntegerToString((long)now) +
                  ", state = " + IntegerToString((int)new_state) +
                  ", last_reason = 'Reconciled with broker history' " +
                  " WHERE attempt_id = '" + EscapeSQL(attempt_id) + "';";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!LogStateTransition(attempt_id, rec.state, new_state, "Broker reconciliation matched"))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   if(!DatabaseTransactionCommit(m_db_handle))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Reconcile Unresolved                                              |
//+------------------------------------------------------------------+
bool CExecutionLedger::ReconcileUnresolved(int max_attempts)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   string sql = "SELECT attempt_id FROM execution_attempts WHERE state IN (" +
                IntegerToString((int)EXEC_STATE_SUBMITTED) + "," +
                IntegerToString((int)EXEC_STATE_RECONCILIATION_REQUIRED) + "," +
                IntegerToString((int)EXEC_STATE_PARTIAL_FILL) +
                ") ORDER BY created_at ASC LIMIT " + IntegerToString(max_attempts) + ";";

   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return false;

   string attempts[];
   int count = 0;
   while(DatabaseRead(handle))
     {
      ArrayResize(attempts, count + 1);
      attempts[count] = DatabaseColumnString(handle, 0);
      count++;
     }
   DatabaseFinalize(handle);

   for(int i = 0; i < count; i++)
      ReconcileAttempt(attempts[i]);

   return true;
   }

//+------------------------------------------------------------------+
//| Has Blocking Unresolved                                           |
//+------------------------------------------------------------------+
bool CExecutionLedger::HasBlockingUnresolved(string &blocking_reason)
   {
    if(!m_db_available || m_db_handle == INVALID_HANDLE)
      {
       blocking_reason = "Ledger not available";
       return true;
      }

    string sql = "SELECT COUNT(*) FROM execution_attempts WHERE state IN (" +
                 IntegerToString((int)EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED) + "," +
                 IntegerToString((int)EXEC_STATE_SUBMITTED) + "," +
                 IntegerToString((int)EXEC_STATE_RECONCILIATION_REQUIRED) + "," +
                 IntegerToString((int)EXEC_STATE_PARTIAL_FILL) + ");";

    int handle = DatabasePrepare(m_db_handle, sql);
    if(handle == INVALID_HANDLE)
      {
       blocking_reason = "Ledger query failed";
       return true;
      }

    int count = 0;
    if(DatabaseRead(handle))
       count = (int)DatabaseColumnLong2(handle, 0);
    DatabaseFinalize(handle);

    if(count > 0)
      {
       blocking_reason = "Unresolved execution attempts exist";
       return true;
      }

    blocking_reason = "";
    return false;
   }

//+------------------------------------------------------------------+
//| Has Unresolved For Symbol                                         |
//+------------------------------------------------------------------+
bool CExecutionLedger::HasUnresolvedForSymbol(const string symbol, bool include_ambiguous)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return true; // fail closed

   string sql = "SELECT COUNT(*) FROM execution_attempts WHERE symbol = '" + EscapeSQL(symbol) +
                "' AND state IN (" +
                IntegerToString((int)EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED) + "," +
                IntegerToString((int)EXEC_STATE_SUBMITTED);

   if(include_ambiguous)
      sql += "," + IntegerToString((int)EXEC_STATE_RECONCILIATION_REQUIRED) + "," + IntegerToString((int)EXEC_STATE_PARTIAL_FILL);

   sql += ");";

   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return true;

   int count = 0;
   if(DatabaseRead(handle))
      count = (int)DatabaseColumnLong2(handle, 0);
   DatabaseFinalize(handle);

   return count > 0;
  }

//+------------------------------------------------------------------+
//| Get Attempt State                                                 |
//+------------------------------------------------------------------+
bool CExecutionLedger::GetAttemptState(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE &state)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;
   state = rec.state;
   return true;
   }

//+------------------------------------------------------------------+
//| Log State Transition                                             |
//+------------------------------------------------------------------+
bool CExecutionLedger::LogStateTransition(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE old_state,
                                          ENUM_EXEC_ATTEMPT_STATE new_state, const string reason,
                                          uint retcode)
   {
    if(!m_db_available || m_db_handle == INVALID_HANDLE)
       return false;

    datetime now = TimeCurrent();
    string sql = "INSERT INTO execution_state_history (attempt_id, old_state, new_state, transition_at, reason, retcode) VALUES ('" +
                 EscapeSQL(attempt_id) + "'," +
                 IntegerToString((int)old_state) + "," +
                 IntegerToString((int)new_state) + "," +
                 IntegerToString((long)now) + ",'" +
                 EscapeSQL(reason) + "'," +
                 IntegerToString((long)retcode) + ");";

    return ExecuteSQL(sql);
   }

// E2.3: Setup Claim lifecycle implementations (minimal, fail-closed)
CExecutionLedger::ENUM_CLAIM_RESULT CExecutionLedger::CreateClaim(
    const string strategy_group_key,
    const string logical_setup_key,
    const string canonical_identity,
    int serialization_version,
    ExecutionAttemptRecord &initial_attempt)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return CLAIM_ERROR;
   if(strategy_group_key == "" || logical_setup_key == "" || canonical_identity == "")
      return CLAIM_ERROR;
   // Check existing claim
   string check_sql = "SELECT claim_id, canonical_identity FROM setup_claims WHERE strategy_group_key='" +
                      EscapeSQL(strategy_group_key) + "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return CLAIM_ERROR;
   bool exists = false;
   string existing_canonical = "";
   if(DatabaseRead(handle))
     {
      exists = true;
      DatabaseColumnText(handle, 1, existing_canonical);
     }
   DatabaseFinalize(handle);
   if(exists)
     {
      if(existing_canonical != canonical_identity)
         return CLAIM_IDENTITY_COLLISION;
      return CLAIM_ALREADY_EXISTS;
     }
   // Persist initial Attempt first (separate transaction)
   if(initial_attempt.attempt_id == "")
      initial_attempt.attempt_id = GenerateAttemptId();
   if(!CreateIntent(initial_attempt))
      return CLAIM_ERROR;
   // Create claim row (atomic)
   if(!DatabaseTransactionBegin(m_db_handle))
      return CLAIM_ERROR;
   string claim_id = "CLAIM_" + IntegerToString((long)TimeCurrent()) + "_" + IntegerToString(MathRand());
   datetime now = TimeCurrent();
   string insert_claim = "INSERT INTO setup_claims (claim_id, strategy_group_key, logical_setup_key, canonical_identity, "
                        "serialization_version, claim_state, current_attempt_id, retry_sequence, created_at, updated_at, last_reason) "
                        "VALUES ('" + EscapeSQL(claim_id) + "','" + EscapeSQL(strategy_group_key) + "','" +
                        EscapeSQL(logical_setup_key) + "','" + EscapeSQL(canonical_identity) + "'," +
                        IntegerToString(serialization_version) + "," + IntegerToString((int)SETUP_CLAIM_ACTIVE) + ",'" +
                        EscapeSQL(initial_attempt.attempt_id) + "',0," + IntegerToString((long)now) + "," +
                        IntegerToString((long)now) + ",'CREATED');";
   if(!ExecuteSQL(insert_claim))
     {
      DatabaseTransactionRollback(m_db_handle);
      return CLAIM_ERROR;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return CLAIM_ERROR;
     }
   return CLAIM_CREATED;
  }

bool CExecutionLedger::RetryAuthorize(const string claim_id, const string attempt_id, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   string check_sql = "SELECT claim_state, current_attempt_id FROM setup_claims WHERE claim_id='" + EscapeSQL(claim_id) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return false;
   int claim_state = -1;
   string current_attempt = "";
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, claim_state);
      DatabaseColumnText(handle, 1, current_attempt);
     }
   DatabaseFinalize(handle);
   if(claim_state != (int)SETUP_CLAIM_ACTIVE)
      return false;
   if(current_attempt != attempt_id)
      return false;
   ENUM_EXEC_ATTEMPT_STATE st;
   if(!GetAttemptState(attempt_id, st))
      return false;
   if(st != EXEC_STATE_FINAL_FAILURE)
      return false;
   // Evidence validation: proven terminal non-execution required
   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;
   if(rec.failure_class == "" || rec.failure_class == "AMBIGUOUS" ||
      rec.failure_class == "TIMEOUT" || rec.failure_class == "RECONCILIATION_REQUIRED")
      return false;
   if(rec.last_retcode == TRADE_RETCODE_TIMEOUT || rec.last_retcode == TRADE_RETCODE_CONNECTION)
      return false;
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   string sql = "UPDATE setup_claims SET claim_state=" + IntegerToString((int)SETUP_CLAIM_RETRY_AUTHORIZED) +
                ", updated_at=" + IntegerToString((long)TimeCurrent()) +
                ", last_reason='" + EscapeSQL(reason) + "' " +
                "WHERE claim_id='" + EscapeSQL(claim_id) + "' AND claim_state=" +
                IntegerToString((int)SETUP_CLAIM_ACTIVE) + ";";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::RetryCreate(const string claim_id, const string new_attempt_id, ExecutionAttemptRecord &new_attempt)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   string check_sql = "SELECT claim_state, current_attempt_id, retry_sequence FROM setup_claims WHERE claim_id='" + EscapeSQL(claim_id) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return false;
   int claim_state = -1;
   string current_attempt = "";
   int retry_seq = 0;
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, claim_state);
      DatabaseColumnText(handle, 1, current_attempt);
      DatabaseColumnInteger(handle, 2, retry_seq);
     }
   DatabaseFinalize(handle);
   if(claim_state != (int)SETUP_CLAIM_RETRY_AUTHORIZED)
      return false;
   // Create new durable Attempt Intent first
   if(new_attempt.attempt_id == "")
      new_attempt.attempt_id = GenerateAttemptId();
   if(!CreateIntent(new_attempt))
      return false;
   // Consume retry authorization and update claim
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   string sql = "UPDATE setup_claims SET claim_state=" + IntegerToString((int)SETUP_CLAIM_ACTIVE) +
                ", current_attempt_id='" + EscapeSQL(new_attempt.attempt_id) + "'," +
                " retry_sequence=" + IntegerToString(retry_seq + 1) + "," +
                " updated_at=" + IntegerToString((long)TimeCurrent()) + " " +
                "WHERE claim_id='" + EscapeSQL(claim_id) + "' AND claim_state=" +
                IntegerToString((int)SETUP_CLAIM_RETRY_AUTHORIZED) + ";";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::ResolveClaim(const string claim_id, const string attempt_id,
                                   ENUM_EXEC_ATTEMPT_STATE final_state, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   string check_sql = "SELECT claim_state, current_attempt_id FROM setup_claims WHERE claim_id='" + EscapeSQL(claim_id) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return false;
   int claim_state = -1;
   string current_attempt = "";
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, claim_state);
      DatabaseColumnText(handle, 1, current_attempt);
     }
   DatabaseFinalize(handle);
   if(claim_state != (int)SETUP_CLAIM_ACTIVE)
      return false;
   if(current_attempt != attempt_id)
      return false;
   // Verify persisted Attempt state supports requested terminal disposition
   ExecutionAttemptRecord att_rec;
   if(!GetAttempt(attempt_id, att_rec))
      return false;
   if(final_state != EXEC_STATE_COMPLETED && final_state != EXEC_STATE_FINAL_FAILURE &&
      final_state != EXEC_STATE_ABORTED)
      return false;
   bool state_supports = false;
   if(final_state == EXEC_STATE_COMPLETED && att_rec.state == EXEC_STATE_COMPLETED)
      state_supports = true;
   else if(final_state == EXEC_STATE_FINAL_FAILURE && att_rec.state == EXEC_STATE_FINAL_FAILURE)
      state_supports = true;
   else if(final_state == EXEC_STATE_ABORTED && att_rec.state == EXEC_STATE_ABORTED)
      state_supports = true;
   if(!state_supports)
      return false;
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   string sql = "UPDATE setup_claims SET claim_state=" + IntegerToString((int)SETUP_CLAIM_RESOLVED) +
                ", resolved_at=" + IntegerToString((long)TimeCurrent()) +
                ", updated_at=" + IntegerToString((long)TimeCurrent()) +
                ", last_reason='" + EscapeSQL(reason) + "' " +
                "WHERE claim_id='" + EscapeSQL(claim_id) + "' AND claim_state=" +
                IntegerToString((int)SETUP_CLAIM_ACTIVE) + ";";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

// E2.4: Gateway Authority implementations (fail-closed)
bool CExecutionLedger::ProvisionAuthority(const string authority_key)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE || authority_key == "")
      return false;
   // Idempotent: insert UNCLAIMED only if not exists
   string check_sql = "SELECT claim_state FROM account_authority WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return false;
   bool exists = false;
   if(DatabaseRead(handle))
      exists = true;
   DatabaseFinalize(handle);
   if(exists)
      return true; // already provisioned
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   datetime now = TimeCurrent();
   string sql = "INSERT INTO account_authority (GatewayAuthorityKey, claim_state, authority_epoch, created_at, last_reason) "
                "VALUES ('" + EscapeSQL(authority_key) + "'," + IntegerToString((int)GATEWAY_AUTHORITY_UNCLAIMED) +
                ",0," + IntegerToString((long)now) + ",'PROVISIONED');";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::AcquireAuthority(const string authority_key, const string owner_token, long &out_epoch)
  {
   out_epoch = 0;
   if(!m_db_available || m_db_handle == INVALID_HANDLE || authority_key == "" || owner_token == "")
      return false;
   // Provision if missing
   if(!ProvisionAuthority(authority_key))
      return false;
   // Read current state
   string check_sql = "SELECT claim_state, authority_epoch FROM account_authority WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE)
      return false;
   int state = -1;
   long epoch = 0;
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, state);
      // authority_epoch is INTEGER; read as long via DatabaseColumnLong? use integer
      // MQL5 DatabaseColumnLong exists
     }
   DatabaseFinalize(handle);
   if(state == (int)GATEWAY_AUTHORITY_ORPHANED)
      return false; // blocks acquisition
   if(state != (int)GATEWAY_AUTHORITY_UNCLAIMED && state != (int)GATEWAY_AUTHORITY_RELEASED)
      return false; // already owned
   // Conditional acquisition
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   datetime now = TimeCurrent();
   string sql = "UPDATE account_authority SET claim_state=" + IntegerToString((int)GATEWAY_AUTHORITY_CLAIMED) +
                ", owner_instance_token='" + EscapeSQL(owner_token) + "'," +
                " authority_epoch=authority_epoch+1," +
                " claimed_at=" + IntegerToString((long)now) + "," +
                " heartbeat_at=" + IntegerToString((long)now) + "," +
                " last_reason='ACQUIRED' " +
                "WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "' " +
                "AND (claim_state=" + IntegerToString((int)GATEWAY_AUTHORITY_UNCLAIMED) +
                " OR claim_state=" + IntegerToString((int)GATEWAY_AUTHORITY_RELEASED) + ");";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   // Verify exactly one row was affected
   int changes_handle = DatabasePrepare(m_db_handle, "SELECT changes();");
   if(changes_handle == INVALID_HANDLE)
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   int affected = 0;
   if(DatabaseRead(changes_handle))
      DatabaseColumnInteger(changes_handle, 0, affected);
   DatabaseFinalize(changes_handle);
   if(affected != 1)
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   // Read back epoch
   string read_sql = "SELECT authority_epoch FROM account_authority WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "' AND owner_instance_token='" + EscapeSQL(owner_token) + "';";
   int rhandle = DatabasePrepare(m_db_handle, read_sql);
   if(rhandle != INVALID_HANDLE && DatabaseRead(rhandle))
     {
      DatabaseColumnLong(rhandle, 0, out_epoch);
     }
   if(rhandle != INVALID_HANDLE)
      DatabaseFinalize(rhandle);
   if(out_epoch <= 0)
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::ReleaseAuthority(const string authority_key, const string owner_token, long current_epoch)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   datetime now = TimeCurrent();
   string sql = "UPDATE account_authority SET claim_state=" + IntegerToString((int)GATEWAY_AUTHORITY_RELEASED) +
                ", released_at=" + IntegerToString((long)now) + "," +
                " owner_instance_token='', last_reason='RELEASED' " +
                "WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "' " +
                "AND owner_instance_token='" + EscapeSQL(owner_token) + "' " +
                "AND authority_epoch=" + IntegerToString(current_epoch) + ";";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::HeartbeatAuthority(const string authority_key, const string owner_token, long current_epoch)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   datetime now = TimeCurrent();
   string sql = "UPDATE account_authority SET heartbeat_at=" + IntegerToString((long)now) +
                " WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "' " +
                "AND owner_instance_token='" + EscapeSQL(owner_token) + "' " +
                "AND authority_epoch=" + IntegerToString(current_epoch) + " " +
                "AND claim_state=" + IntegerToString((int)GATEWAY_AUTHORITY_CLAIMED) + ";";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   return true;
  }

bool CExecutionLedger::ValidateAuthority(const string authority_key, const string owner_token, long current_epoch)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE || authority_key == "" || owner_token == "")
      return false;
   string sql = "SELECT claim_state, owner_instance_token, authority_epoch FROM account_authority WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "';";
   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return false;
   int state = -1;
   string token = "";
   long epoch = 0;
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, state);
      DatabaseColumnText(handle, 1, token);
      DatabaseColumnLong(handle, 2, epoch);
     }
   DatabaseFinalize(handle);
   if(state != (int)GATEWAY_AUTHORITY_CLAIMED)
      return false;
   if(token != owner_token)
      return false;
   if(epoch != current_epoch)
      return false;
   return true;
  }

int CExecutionLedger::GetAuthorityState(const string authority_key)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE || authority_key == "")
      return -1;
   string sql = "SELECT claim_state FROM account_authority WHERE GatewayAuthorityKey='" + EscapeSQL(authority_key) + "';";
   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return -1;
   int state = -1;
   if(DatabaseRead(handle))
      DatabaseColumnInteger(handle, 0, state);
   DatabaseFinalize(handle);
   return state;
  }

#endif
