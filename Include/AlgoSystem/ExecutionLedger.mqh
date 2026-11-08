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
//| Option B identity contract (R3A): setup_claims is authoritative  |
//| for strategy_group_key/logical_setup_key/canonical_identity and   |
//| claim serialization_version. execution_attempts stores execution  |
//| state and broker evidence only. The four identity fields below    |
//| are creation-time/caller context and are NOT durably persisted or |
//| reconstructed by GetAttempt(); empty/default values must never be |
//| treated as valid persisted setup identity. Use an explicit        |
//| fail-closed claim-resolution path for identity-dependent logic.   |
//|                                                                   |
//| F-002 schema v3 (source foundation, compile-unverified): durable  |
//| per-Attempt risk reservation fields. 1 reservation per Attempt,   |
//| initial reservation intended atomic with durable Intent. Legacy   |
//| rows use explicit LEGACY_UNVERIFIED semantics (DB NULL/unknown);  |
//| callers must fail closed on unknown/unverified reservation.       |
//+------------------------------------------------------------------+
#define EXEC_RISK_RESERVE_MODEL_V1        1
#define EXEC_RISK_RESERVE_STATE_UNKNOWN   0
#define EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED 1
#define EXEC_RISK_RESERVE_STATE_ACTIVE    2
#define EXEC_RISK_RESERVE_STATE_RELEASED  3
#define EXEC_RISK_RESERVE_STATE_INVALID   4

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
   string                strategy_group_key;      // creation-time context; not persisted by GetAttempt (Option B)
   string                logical_setup_key;        // creation-time context; not persisted by GetAttempt (Option B)
   string                canonical_identity;       // creation-time context; not persisted by GetAttempt (Option B)
   int                   serialization_version;    // claim serialization context; not persisted by GetAttempt (Option B)
   string                failure_class;
   ENUM_EXEC_ATTEMPT_STATE state;
   bool                  submission_allowed;
   string                last_reason;
   int                   schema_version;
   // F-002 durable per-Attempt risk reservation (schema v3). NULL/unknown in legacy DB rows => LEGACY_UNVERIFIED, never 0.
   double                risk_reserve_initial_amount;    // immutable initial reservation, account currency
   double                risk_reserve_remaining_amount;  // remaining reservation, account currency
   string                risk_reserve_currency;          // ACCOUNT_CURRENCY at reservation time
   double                risk_reserve_equity_snapshot;   // equity snapshot at reservation time
   double                risk_reserve_percent_snapshot;  // actual initial / equity_snapshot * 100
   int                   risk_reserve_model_version;     // distinct from schema/attempt/Option B versions
   int                   risk_reserve_state;             // EXEC_RISK_RESERVE_STATE_*
   int                   risk_reserve_revision;          // CAS/monotonic
   datetime              risk_reserve_updated_at;
   string                risk_reserve_release_reason;    // nullable
   bool                  risk_reserve_known;             // runtime/source guard: false => legacy/unverified/unknown (fail closed)
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
    bool               LogStateTransitionInTx(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE old_state,
                                             ENUM_EXEC_ATTEMPT_STATE new_state, const string reason,
                                             uint retcode=0);
    bool               PrepareIntentRecord(ExecutionAttemptRecord &record) const;
    bool               InsertIntentNoTx(const ExecutionAttemptRecord &record);
    bool               CreateIntentInTx(ExecutionAttemptRecord &record, string &err);
    bool               AffectedRowsIsOne(bool &ok);
    // F-002 schema v3 migration helpers (additive, fail-closed on drift/unknown future; best-effort duplicate-column tolerant).
    bool               TableHasColumn(const string table_name, const string column_name, bool &has_column);
    bool               MigrateV2ToV3AddColumnBestEffort(const string table_name, const string column_name, const string column_type);
    bool               VerifyExecutionAttemptsV3Columns();
    // F-002 durable per-Attempt risk reservation primitives (source foundation).
    void               InitRiskReservationUnknown(ExecutionAttemptRecord &record) const;
    void               InitRiskReservationLegacyUnverified(ExecutionAttemptRecord &record) const;
    bool               NormalizeRiskReservationForPersist(ExecutionAttemptRecord &record, string &err) const;
    bool               ReadAttemptRiskReservationColumns(int handle, int start_col, ExecutionAttemptRecord &record) const;
    bool               PopulateRiskReservationFromAttemptParams(const string symbol, ENUM_ORDER_INTENT intent, double volume, double entry_price, double stop_loss, ExecutionAttemptRecord &record, string &err) const;
    string             GenerateAttemptId();
    string             EscapeSQL(const string s) const;
    struct AttemptIdentityEventRef
      {
       string claim_id;
       string group;
       string lsk;
       string prior_id;
       string new_id;
       int    seq_before;
       int    seq_after;
      };

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
    // Option B (R3A): deprecated/unbound creation APIs fail closed (no DB mutation, no claim binding).
    bool               CreateIntent(ExecutionAttemptRecord &record);
    bool               MarkSubmissionBound(const string attempt_id, const string reason="");
    bool               CanSubmit(const string attempt_id, string &reason);
    bool               MarkSubmissionMayHaveOccurred(const string attempt_id, const string reason="");
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
    // RS-02: conservative quarantine for INTENT_DURABLE_NOT_SUBMITTED (no auto-resubmit)
    bool               QuarantineOrphanIntent(const ExecutionAttemptRecord &rec);

    // E2.3 / RS-01: Setup Claim lifecycle (durable logical-setup deduplication)
    // Option B (R3A): setup_claims is authoritative for logical setup identity.
    // Supported attempt creation paths only: CreateSetupClaimAndIntent (initial) and ApproveAndCreateRetry (controlled retry).
    // CreateClaim/CreateSetupClaim are deprecated compatibility APIs and fail closed (no durable mutation).
    enum ENUM_CLAIM_RESULT { CLAIM_CREATED=0, CLAIM_ALREADY_EXISTS, CLAIM_IDENTITY_COLLISION, CLAIM_ERROR, CLAIM_DEPRECATED_UNBOUND };
    ENUM_CLAIM_RESULT  CreateClaim(const string strategy_group_key,
                                    const string logical_setup_key,
                                    const string canonical_identity,
                                    int serialization_version,
                                    ExecutionAttemptRecord &initial_attempt);
    // Deprecated (Option B): claim-only acquisition without atomic intent is not a supported submission path.
    // Fails closed; no claim row is created/mutated.
    ENUM_CLAIM_RESULT  CreateSetupClaim(const string strategy_group_key,
                                        const string logical_setup_key,
                                        const string canonical_identity,
                                        int serialization_version,
                                        const string attempt_id);
    // RS-01 atomicity hardening: acquire claim and insert initial intent in one transaction where feasible.
    // Uses same tx-safe helpers (no nested tx). On any failure, neither claim nor intent is durably committed.
    ENUM_CLAIM_RESULT  CreateSetupClaimAndIntent(const string strategy_group_key,
                                                 const string logical_setup_key,
                                                 const string canonical_identity,
                                                 int serialization_version,
                                                 ExecutionAttemptRecord &attempt,
                                                 string &error_reason);
    bool               GetSetupClaim(const string strategy_group_key,
                                     const string logical_setup_key,
                                     string &claim_id,
                                     int &claim_state,
                                     string &current_attempt_id);
    // RS01: read-only diagnostics for claim-only/orphan records (fail-closed, no auto-release).
    int                InspectSetupClaims(string &out_report, int &out_orphan_count, int max_rows=20);
    // E2.6: controlled retry via local chart approval (source implementation; live DB/runtime not authorized).
    enum ENUM_RETRY_APPROVE_RESULT
      {
       RETRY_APPROVE_COMMITTED=0,          // atomic approval+new intent committed; caller may revalidate and use existing submission protocol
       RETRY_APPROVE_ALREADY_CONSUMED,     // deterministic action id already committed with identical fields (idempotent)
       RETRY_APPROVE_CANDIDATE_INVALID,    // claim/attempt/evidence/sequence/context no longer eligible
       RETRY_APPROVE_COMMIT_OUTCOME_UNKNOWN,// commit failed/uncertain; caller must read-back action id, block same op, reconcile
       RETRY_APPROVE_DB_ERROR,
       RETRY_APPROVE_NOT_AUTHORIZED
      };
    struct RetryLocalContext
      {
       string action_source;      // LOCAL_CHART_OBJECT_CLICK
       string auth_model;         // LOCAL_TERMINAL_SESSION_CONTEXT_ONLY
       string account_login;
       string account_server;
       long   chart_id;
       string chart_symbol;
       int    chart_period;
       string ea_program;
       int    terminal_build;
       datetime local_action_time;
       string bounded_reason;     // optional, bounded; not identity
      };
    static string      BuildRetryActionId(const string claim_id,const string prior_attempt_id,int expected_retry_sequence);
    bool               GetClaimById(const string claim_id,
                                    const string strategy_group_key,
                                    const string logical_setup_key,
                                    int &claim_state,
                                    string &current_attempt_id,
                                    int &retry_sequence);
    bool               IsRetryEligibleFinalFailure(const ExecutionAttemptRecord &attempt,string &why_not);
    ENUM_RETRY_APPROVE_RESULT ApproveAndCreateRetry(const string claim_id,
                                                    const string strategy_group_key,
                                                    const string logical_setup_key,
                                                    const string prior_attempt_id,
                                                    int expected_retry_sequence,
                                                    const RetryLocalContext &ctx,
                                                    const string evidence_reason,
                                                    ExecutionAttemptRecord &new_attempt,
                                                    string &out_action_id,
                                                    string &out_detail);
    bool               GetRetryApprovalEventOutcome(const string action_id,string &outcome,string &new_attempt_id);
    // E2.6 P1-B: bounded read-only durable candidate discovery (no DB writes). Uses same evidence
    // validator as ApproveAndCreateRetry. Fail-closed on any SQL/parse/DB error.
    struct RetryEligibleCandidate
      {
       bool     valid;
       string   claim_id;
       string   strategy_group_key;
       string   logical_setup_key;
       string   canonical_identity;
       int      serialization_version;
       int      claim_state;
       string   prior_attempt_id;
       int      retry_sequence;
       string   symbol;
       int      direction;
       int      attempt_state;
       string   failure_class;
       uint     retcode;
       double   requested_volume;
       double   executed_volume;
       double   remaining_volume;
       ulong    broker_order_ticket;
       ulong    broker_deal_ticket;
       ulong    broker_position_ticket;
       string   evidence_summary;
       string   eligibility_reason;
       bool     consumed_by_approval;
      };
    int                GetRetryEligibleCandidates(RetryEligibleCandidate &out[], int max_candidates, string &error);
    // E2.6-R1: read-only visibility for durably approved retry intents after restart/interruption.
    // NO handoff restoration, NO auto-submit, NO state/claim mutation, NO broker call.
    struct InterruptedRetryHandoff
      {
       bool     valid;
       string   action_id;
       string   claim_id;
       string   strategy_group_key;
       string   logical_setup_key;
       string   prior_attempt_id;
       string   new_attempt_id;
       int      retry_sequence_before;
       int      retry_sequence_after;
       datetime approval_timestamp;
       string   account_login;
       string   account_server;
       bool     approval_event_exists;
       int      new_attempt_state;      // EXEC_STATE_* or -1 unreadable/missing
       bool     new_attempt_readable;
       bool     submitted_recorded;     // durable submitted_at/state evidence only
       bool     submission_may_have_occurred;
       bool     reconciliation_required;
       string   status_code;            // bounded diagnostic (read-only)
       string   detail;
      };
    int                GetInterruptedRetryHandoffs(const string account_login,
                                                   const string account_server,
                                                   const string strategy_group_key,
                                                   InterruptedRetryHandoff &out[],
                                                   int max_rows,
                                                   string &error);
    // Deprecated split wrappers: fail-closed. EA must not call. No direct broker submission.
    bool               RetryAuthorize(const string claim_id,
                                     const string strategy_group_key,
                                     const string logical_setup_key,
                                     const string attempt_id,
                                     int expected_retry_sequence,
                                     const string operator_approval_ref,
                                     const string reason);
    bool               RetryCreate(const string claim_id,
                                  const string strategy_group_key,
                                  const string logical_setup_key,
                                  const string expected_prior_attempt_id,
                                  int expected_retry_sequence_after_authorize,
                                  ExecutionAttemptRecord &new_attempt);
    bool               ResolveClaim(const string claim_id,
                                   const string attempt_id,
                                   ENUM_EXEC_ATTEMPT_STATE final_state,
                                   const string reason);

    // Option B (R3A): read-only, fail-closed Attempt -> authoritative setup_claim identity resolver.
    // Never mutates DB/state, never infers/regenerates identity, never uses symbol/magic/time/tickets/chart.
    enum ENUM_ATTEMPT_IDENTITY_RESOLUTION
      {
       IDENTITY_RESOLVED=0,
       IDENTITY_NOT_FOUND,
       IDENTITY_AMBIGUOUS,
       IDENTITY_CONFLICT,
       IDENTITY_DB_UNAVAILABLE
      };
    ENUM_ATTEMPT_IDENTITY_RESOLUTION GetSetupIdentityForAttempt(
                                        const string attempt_id,
                                        string &claim_id,
                                        string &strategy_group_key,
                                        string &logical_setup_key,
                                        string &canonical_identity,
                                        int &serialization_version,
                                        string &detail);

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
    // RS01-CANON-01: stable canonical identity helpers (legacy v1 compatibility, fail-closed)
    static string      BuildStableCanonicalIdentity(const string strategy_group_key,
                                                   const string symbol,
                                                   const string setup_type,
                                                   int direction,
                                                   datetime signal_time,
                                                   int setup_tf,
                                                   int version=2);
    static bool        ParseLegacyV1CanonicalStable(const string canonical_identity,
                                                   string &out_group,
                                                   string &out_symbol,
                                                   string &out_direction,
                                                   string &out_signal_time,
                                                   string &out_setup_tf);
    bool               CanonicalSameLogicalSetup(const string existing_canonical,
                                                const string new_canonical);
    bool               UpgradeClaimCanonicalIfSafe(const string claim_id,
                                                  const string expected_existing,
                                                  const string new_canonical);
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
   // E2.6: schema v2 adds retry_approval_events (durable single-use controlled retry audit/idempotency).
   // Migration source is backward-compatible; live DB migration execution is NOT authorized in this phase.
   // F-002: schema v3 adds durable per-Attempt risk reservation columns on execution_attempts (additive, tx-safe migration source).
   // Live DB migration execution is NOT authorized in this task.
   m_schema_version = 3;
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

   // F-002 schema v3: durable per-Attempt risk reservation columns (additive). Legacy migrated rows may have NULLs
   // => LEGACY_UNVERIFIED semantics; callers must fail closed, never treat NULL as 0 risk.
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
                 "schema_version INTEGER,"
                 "risk_reserve_initial_amount REAL,"
                 "risk_reserve_remaining_amount REAL,"
                 "risk_reserve_currency TEXT,"
                 "risk_reserve_equity_snapshot REAL,"
                 "risk_reserve_percent_snapshot REAL,"
                 "risk_reserve_model_version INTEGER,"
                 "risk_reserve_state INTEGER,"
                 "risk_reserve_revision INTEGER,"
                 "risk_reserve_updated_at INTEGER,"
                 "risk_reserve_release_reason TEXT"
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

    // E2.6: durable single-use retry approval/audit events (no personal identity; local terminal session context only).
    // action_id is deterministic and bound to exact claim/prior attempt/retry sequence. No separate PENDING out-of-tx record.
    string sql6 = "CREATE TABLE IF NOT EXISTS retry_approval_events ("
                 "action_id TEXT PRIMARY KEY,"
                 "claim_id TEXT NOT NULL,"
                 "strategy_group_key TEXT NOT NULL,"
                 "logical_setup_key TEXT NOT NULL,"
                 "prior_attempt_id TEXT NOT NULL,"
                 "new_attempt_id TEXT NOT NULL UNIQUE,"
                 "retry_sequence_before INTEGER NOT NULL,"
                 "retry_sequence_after INTEGER NOT NULL,"
                 "approval_timestamp INTEGER NOT NULL,"
                 "action_source TEXT NOT NULL,"
                 "auth_model TEXT NOT NULL,"
                 "account_login TEXT,"
                 "account_server TEXT,"
                 "chart_id INTEGER,"
                 "chart_symbol TEXT,"
                 "chart_period INTEGER,"
                 "ea_program TEXT,"
                 "terminal_build INTEGER,"
                 "evidence_state INTEGER,"
                 "evidence_failure_class TEXT,"
                 "evidence_retcode INTEGER,"
                 "evidence_reason TEXT,"
                 "outcome TEXT NOT NULL,"
                 "schema_version INTEGER NOT NULL,"
                 "UNIQUE(claim_id, prior_attempt_id, retry_sequence_before)"
                 ");";
    ResetLastError();
    if(!ExecuteSQL(sql6))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(sql6:CREATE_RETRY_APPROVAL_EVENTS)";
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
       has_version = (StringLen(ver) > 0);
      }
    DatabaseFinalize(handle);

   // Record schema version only when absent; MigrateSchema performs versioned upgrades (fail-closed on unsupported).
   if(!has_version)
     {
      string set_ver = "INSERT INTO execution_schema_meta (key, value) VALUES ('schema_version', '" + IntegerToString(m_schema_version) + "');";
    ResetLastError();
    if(!ExecuteSQL(set_ver))
      {
       m_last_init_stage = "ExecutionLedger.CreateSchema";
       m_last_init_operation = "ExecuteSQL(set_schema_version_absent)";
       m_last_init_error = GetLastError();
       return false;
      }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Migrate Schema                                                    |
//| E2.6: versioned, backward-compatible migration source only.        |
//| Live DB migration execution is NOT authorized in this phase.      |
//| Idempotent: CREATE TABLE IF NOT EXISTS and schema meta updates;   |
//| fail-closed on unsupported/partial states.                        |
//+------------------------------------------------------------------+
bool CExecutionLedger::MigrateSchema()
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   // Read current version (best-effort; absence handled by CreateSchema meta set).
   string ver_sql = "SELECT value FROM execution_schema_meta WHERE key='schema_version';";
   int vh = DatabasePrepare(m_db_handle, ver_sql);
   if(vh == INVALID_HANDLE)
     {
      m_last_init_stage = "ExecutionLedger.MigrateSchema";
      m_last_init_operation = "DatabasePrepare(schema_version)";
      m_last_init_error = GetLastError();
      return false;
     }
   int current = 0;
   if(DatabaseRead(vh))
     {
      string v = DatabaseColumnString(vh, 0);
      current = (int)StringToInteger(v);
     }
   DatabaseFinalize(vh);
   // Fail closed on future/unsupported schema versions.
   if(current > m_schema_version)
     {
      m_last_init_stage = "ExecutionLedger.MigrateSchema";
      m_last_init_operation = "UnsupportedSchemaVersion";
      m_last_init_error = 0;
      return false;
     }
   // v1 -> v2: ensure retry_approval_events exists (additive, backward-compatible).
   if(current < 2)
     {
      string sql6 = "CREATE TABLE IF NOT EXISTS retry_approval_events ("
                   "action_id TEXT PRIMARY KEY,"
                   "claim_id TEXT NOT NULL,"
                   "strategy_group_key TEXT NOT NULL,"
                   "logical_setup_key TEXT NOT NULL,"
                   "prior_attempt_id TEXT NOT NULL,"
                   "new_attempt_id TEXT NOT NULL UNIQUE,"
                   "retry_sequence_before INTEGER NOT NULL,"
                   "retry_sequence_after INTEGER NOT NULL,"
                   "approval_timestamp INTEGER NOT NULL,"
                   "action_source TEXT NOT NULL,"
                   "auth_model TEXT NOT NULL,"
                   "account_login TEXT,"
                   "account_server TEXT,"
                   "chart_id INTEGER,"
                   "chart_symbol TEXT,"
                   "chart_period INTEGER,"
                   "ea_program TEXT,"
                   "terminal_build INTEGER,"
                   "evidence_state INTEGER,"
                   "evidence_failure_class TEXT,"
                   "evidence_retcode INTEGER,"
                   "evidence_reason TEXT,"
                   "outcome TEXT NOT NULL,"
                   "schema_version INTEGER NOT NULL,"
                   "UNIQUE(claim_id, prior_attempt_id, retry_sequence_before)"
                   ");";
      if(!ExecuteSQL(sql6))
        {
         m_last_init_stage = "ExecutionLedger.MigrateSchema";
         m_last_init_operation = "ExecuteSQL(v1->v2:CREATE_RETRY_APPROVAL_EVENTS)";
         m_last_init_error = GetLastError();
         return false;
        }
      current = 2;
      string set_ver2 = "INSERT OR REPLACE INTO execution_schema_meta (key, value) VALUES ('schema_version', '2');";
      if(!ExecuteSQL(set_ver2))
        {
         m_last_init_stage = "ExecutionLedger.MigrateSchema";
         m_last_init_operation = "ExecuteSQL(v1->v2:set_schema_version)";
         m_last_init_error = GetLastError();
         return false;
        }
     }
   // v2 -> v3 (F-002): additive durable per-Attempt risk reservation columns on execution_attempts.
   // No ALTER TABLE expression defaults (SQLite/MQL5 compatibility). Legacy rows receive NULL reservation fields
   // and MUST be treated as LEGACY_UNVERIFIED by readers/arbitration (never 0 risk). Idempotent best-effort adds.
   if(current < 3)
     {
      // Best-effort additive ALTERs; duplicate-column is treated as already-migrated for that column.
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_initial_amount", "REAL");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_remaining_amount", "REAL");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_currency", "TEXT");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_equity_snapshot", "REAL");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_percent_snapshot", "REAL");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_model_version", "INTEGER");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_state", "INTEGER");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_revision", "INTEGER");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_updated_at", "INTEGER");
      MigrateV2ToV3AddColumnBestEffort("execution_attempts", "risk_reserve_release_reason", "TEXT");
      if(!VerifyExecutionAttemptsV3Columns())
        {
         m_last_init_stage = "ExecutionLedger.MigrateSchema";
         m_last_init_operation = "ExecuteSQL(v2->v3:VERIFY_EXECUTION_ATTEMPTS_V3_COLUMNS)";
         m_last_init_error = GetLastError();
         return false;
        }
      string set_ver3 = "INSERT OR REPLACE INTO execution_schema_meta (key, value) VALUES ('schema_version', '3');";
      if(!ExecuteSQL(set_ver3))
        {
         m_last_init_stage = "ExecutionLedger.MigrateSchema";
         m_last_init_operation = "ExecuteSQL(v2->v3:set_schema_version)";
         m_last_init_error = GetLastError();
         return false;
        }
     }
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
//| Option B (R3A): deprecated fail-closed. Supported initial/retry  |
//| attempt creation must use CreateSetupClaimAndIntent or            |
//| ApproveAndCreateRetry (atomic claim-bound paths). No DB mutation. |
//+------------------------------------------------------------------+
bool CExecutionLedger::CreateIntent(ExecutionAttemptRecord &record)
  {
   record.last_reason = "OPTION_B_DEPRECATED_UNBOUND_CREATE_INTENT";
   return false;
  }

//+------------------------------------------------------------------+
//| Mark Submission Bound                                             |
//| Binds a durable intent for a possible single submission attempt.  |
//| The attempt remains INTENT_DURABLE_NOT_SUBMITTED (non-ambiguous,  |
//| no broker call recorded). submission_allowed is required by      |
//| CanSubmit. The ambiguous transition to                          |
//| SUBMISSION_MAY_HAVE_OCCURRED must happen only via               |
//| MarkSubmissionMayHaveOccurred immediately adjacent to the broker |
//| invocation.                                                       |
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

   // Restart/idempotency safety: a bound intent must not be rebound silently.
   if(rec.submission_allowed)
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   string sql = "UPDATE execution_attempts SET submission_bound_at = " + IntegerToString((long)now) +
                ", submission_allowed = 1, last_reason = '" + EscapeSQL(reason) + "' WHERE attempt_id = '" +
                EscapeSQL(attempt_id) + "' AND state = " + IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) +
                " AND submission_allowed = 0;";

   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }

   // State remains INTENT_DURABLE_NOT_SUBMITTED: intent is authorized/bound
   // but broker invocation has not occurred.
   if(!LogStateTransition(attempt_id, EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED, EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED, reason))
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
//| Authorizes at most the single pre-broker submission for a bound   |
//| attempt. Ambiguous/terminal/reconciling states are never          |
//| submittable (fail-closed, D-04/D-09/D-10/D-11).                  |
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
//| Mark Submission May Have Occurred                                 |
//| Final durable transition immediately adjacent to broker           |
//| invocation. After commit, the system must assume the broker call  |
//| may have occurred and must never auto-resubmit.                  |
//+------------------------------------------------------------------+
bool CExecutionLedger::MarkSubmissionMayHaveOccurred(const string attempt_id, const string reason)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   // Only a bound, still-unsubmitted intent may enter the ambiguous window.
   if(rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED || !rec.submission_allowed)
      return false;

   if(!DatabaseTransactionBegin(m_db_handle))
      return false;

   datetime now = TimeCurrent();
   string sql = "UPDATE execution_attempts SET submitted_at = " + IntegerToString((long)now) +
                ", state = " + IntegerToString((int)EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED) +
                ", last_reason = '" + EscapeSQL(reason) + "' WHERE attempt_id = '" +
                EscapeSQL(attempt_id) + "' AND state = " + IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) +
                " AND submission_allowed = 1;";

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
//| Record Submission                                                 |
//| Legacy/diagnostic: does not advance durable state without broker  |
//| evidence. Kept fail-closed; do not use to auto-authorize submit.  |
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
//| Option B (R3A): returns execution/broker evidence only.           |
//| strategy_group_key/logical_setup_key/canonical_identity/          |
//| serialization_version are NOT persisted in execution_attempts and  |
//| are NOT reconstructed here. Identity-dependent callers must use a |
//| validated setup_claim path (e.g. GetSetupIdentityForAttempt) and  |
//| must never treat empty/default values as valid persisted identity. |
//+------------------------------------------------------------------+
bool CExecutionLedger::GetAttempt(const string attempt_id, ExecutionAttemptRecord &record)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   string sql = "SELECT attempt_id, setup_id, symbol, magic, intent, direction, requested_volume, "
                "executed_volume, remaining_volume, entry_price, stop_loss, take_profit, "
                "created_at, submission_bound_at, submitted_at, broker_response_at, observed_at, resolved_at, "
                "last_retcode, last_retcode_desc, broker_order_ticket, broker_deal_ticket, broker_position_ticket, "
                "failure_class, state, submission_allowed, last_reason, schema_version, "
                "COALESCE(risk_reserve_initial_amount,0), COALESCE(risk_reserve_remaining_amount,0), COALESCE(risk_reserve_currency,''), "
                "COALESCE(risk_reserve_equity_snapshot,0), COALESCE(risk_reserve_percent_snapshot,0), COALESCE(risk_reserve_model_version,0), "
                "COALESCE(risk_reserve_state,-1), COALESCE(risk_reserve_revision,0), COALESCE(risk_reserve_updated_at,0), COALESCE(risk_reserve_release_reason,'') "
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
      // F-002: reservation columns at 28..37 (COALESCE protects NULL legacy). State -1/unknown => LEGACY_UNVERIFIED.
      ReadAttemptRiskReservationColumns(handle, 28, record);
      found = true;
     }
   DatabaseFinalize(handle);
   return found;
  }

//+------------------------------------------------------------------+
//| Recover Unresolved                                                |
//| RS-02: counts unresolved attempts (including orphan               |
//| INTENT_DURABLE_NOT_SUBMITTED variants A/B) AND quarantines them   |
//| safely. It never auto-resubmits.                                  |
//|                                                                   |
//| - Both variant A (submission_allowed=0) and variant B            |
//|   (submission_allowed=1) are quarantined conservatively: broker   |
//|   evidence/history access failure/possible match =>               |
//|   RECONCILIATION_REQUIRED. Absence of queried broker history is   |
//|   NOT proof of non-submission (history may be incomplete;         |
//|   SQLite/MQL5 crash durability/commit ordering vs broker call is  |
//|   not proven). We do NOT auto-ABORT on absence alone.            |
//|   submission_allowed=1 is never post-restart submit authorization.|
//|                                                                   |
//| Durability unknown: SQLite/MQL5 journal/synchronous/commit        |
//| semantics under crash are not proven here; recovery stays         |
//| conservative.                                                      |
//+------------------------------------------------------------------+
int CExecutionLedger::RecoverUnresolved(int &out_count)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     {
      out_count = 0;
      return 0;
     }

   // First, quarantine/orphan-handle INTENT_DURABLE_NOT_SUBMITTED rows (no auto-resubmit).
   string qsql = "SELECT attempt_id FROM execution_attempts WHERE state = " +
                 IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) +
                 " ORDER BY created_at ASC LIMIT 50;";
   int qh = DatabasePrepare(m_db_handle, qsql);
   if(qh != INVALID_HANDLE)
     {
      string orphan_ids[];
      int oc = 0;
      while(DatabaseRead(qh))
        {
         ArrayResize(orphan_ids, oc + 1);
         orphan_ids[oc] = DatabaseColumnString(qh, 0);
         oc++;
        }
      DatabaseFinalize(qh);
      for(int i = 0; i < oc; i++)
        {
         // Reconcile/quarantine each; failures are visible via state/history and blocking queries.
         ReconcileAttempt(orphan_ids[i]);
        }
     }

   // Also run standard reconciliation pass for ambiguous/post-submit unresolved states.
   ReconcileUnresolved(20);

   // Count all unresolved/orphan states (RS-02 visibility)
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
//| RS-02: Quarantine/resolve INTENT_DURABLE_NOT_SUBMITTED           |
//| Conservative: only ABORT when defensible non-submission evidence  |
//| exists (no broker history access failure AND no matching          |
//| order/deal for the attempt's own recorded broker tickets, AND     |
//| no symbol+magic match within the attempt time window). Any        |
//| history access failure, ambiguity, or possible match =>           |
//| RECONCILIATION_REQUIRED. Never auto-resubmit.                     |
//| submission_allowed=1 is NOT used as authorization; it records     |
//| pre-broker binding only.                                          |
//+------------------------------------------------------------------+
bool CExecutionLedger::QuarantineOrphanIntent(const ExecutionAttemptRecord &rec)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   if(rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      return false;

   // Attempt to collect broker evidence. HistorySelect failure => ambiguous/fail-closed.
   datetime from_time = rec.created_at - 3600;
   if(from_time < 0) from_time = 0;
   datetime to_time = TimeCurrent() + 3600;
   if(!HistorySelect(from_time, to_time))
     {
      MarkReconciliationRequired(rec.attempt_id, "RS-02: orphan INTENT_DURABLE_NOT_SUBMITTED; HistorySelect failed - fail closed");
      return false;
     }

   // Strong evidence: recorded broker tickets
   if(rec.broker_order_ticket > 0 || rec.broker_deal_ticket > 0 || rec.broker_position_ticket > 0)
     {
      MarkReconciliationRequired(rec.attempt_id, "RS-02: orphan INTENT has broker ticket evidence - reconciliation required (no auto-resubmit)");
      return false;
     }

   // Look for any matching deal/order by symbol+magic in attempt window (conservative).
   int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; i++)
     {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      if(deal_symbol != rec.symbol) continue;
      long deal_magic = 0;
      if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC, deal_magic))
        {
         if((ulong)deal_magic != rec.magic) continue;
        }
      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      // Conservative window: created_at-60 .. created_at+86400 (covers delayed reporting)
      if(deal_time < rec.created_at - 60) continue;
      if(deal_time > rec.created_at + 86400) continue;
      // Possible match exists => do not claim non-submission.
      MarkReconciliationRequired(rec.attempt_id, "RS-02: orphan INTENT has possible matching broker history - reconciliation required");
      return false;
     }

   int orders_total = HistoryOrdersTotal();
   for(int i = 0; i < orders_total; i++)
     {
      ulong order_ticket = HistoryOrderGetTicket(i);
      if(order_ticket == 0) continue;
      string ord_symbol = HistoryOrderGetString(order_ticket, ORDER_SYMBOL);
      if(ord_symbol != rec.symbol) continue;
      long ord_magic = 0;
      if(HistoryOrderGetInteger(order_ticket, ORDER_MAGIC, ord_magic))
        {
         if((ulong)ord_magic != rec.magic) continue;
        }
      datetime ord_time = (datetime)HistoryOrderGetInteger(order_ticket, ORDER_TIME_SETUP);
      if(ord_time < rec.created_at - 60) continue;
      if(ord_time > rec.created_at + 86400) continue;
      MarkReconciliationRequired(rec.attempt_id, "RS-02: orphan INTENT has possible matching order history - reconciliation required");
      return false;
     }

   // No broker evidence found in queried history. This is NOT a universal proof of non-submission
   // (history may be incomplete/unsynchronized; durability/ordering not proven). Keep conservative:
   // variant B (submission_allowed=1) => reconciliation required (MarkSubmissionMayHaveOccurred may
   // not have committed, but broker-call durability relative to our state is unknown).
   // variant A (submission_allowed=0) => reconciliation required as well unless future evidence contract
   // proves non-submission; we do not auto-ABORT on absence alone.
   MarkReconciliationRequired(rec.attempt_id,
      rec.submission_allowed ?
         "RS-02 variant B: INTENT bound (submission_allowed=1) but ambiguous state not durably observed; no broker evidence in queried history - reconciliation required (no auto-resubmit)" :
         "RS-02 variant A: INTENT not bound (submission_allowed=0) and no broker evidence in queried history - reconciliation required (durability/proof not established)");
   return false;
  }

//+------------------------------------------------------------------+
//| Reconcile Attempt                                                 |
//| RS-02: includes INTENT_DURABLE_NOT_SUBMITTED quarantine.         |
//| Never auto-resubmits. Ambiguity => RECONCILIATION_REQUIRED.       |
//+------------------------------------------------------------------+
bool CExecutionLedger::ReconcileAttempt(const string attempt_id)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   ExecutionAttemptRecord rec;
   if(!GetAttempt(attempt_id, rec))
      return false;

   // RS-02: orphan/quarantine path for INTENT_DURABLE_NOT_SUBMITTED (variants A/B)
   if(rec.state == EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      return QuarantineOrphanIntent(rec);

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
//| RS-02: includes INTENT_DURABLE_NOT_SUBMITTED orphans (fail-closed |
//| quarantine via ReconcileAttempt/QuarantineOrphanIntent). Never    |
//| auto-resubmits.                                                    |
//+------------------------------------------------------------------+
bool CExecutionLedger::ReconcileUnresolved(int max_attempts)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;

   string sql = "SELECT attempt_id FROM execution_attempts WHERE state IN (" +
                IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) + "," +
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
//| RS-02: INTENT_DURABLE_NOT_SUBMITTED is treated as unresolved/    |
//| blocking (fail-closed). Its real SQLite/MQL5 crash durability    |
//| relative to broker invocation is not proven, so it must never     |
//| authorize auto-resubmit and must not be silently bypassed.        |
//+------------------------------------------------------------------+
bool CExecutionLedger::HasBlockingUnresolved(string &blocking_reason)
   {
    if(!m_db_available || m_db_handle == INVALID_HANDLE)
      {
       blocking_reason = "Ledger not available";
       return true;
      }

    string sql = "SELECT COUNT(*) FROM execution_attempts WHERE state IN (" +
                 IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) + "," +
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
//| RS-02: includes INTENT_DURABLE_NOT_SUBMITTED (fail-closed).      |
//+------------------------------------------------------------------+
bool CExecutionLedger::HasUnresolvedForSymbol(const string symbol, bool include_ambiguous)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return true; // fail closed

   string sql = "SELECT COUNT(*) FROM execution_attempts WHERE symbol = '" + EscapeSQL(symbol) +
                "' AND state IN (" +
                IntegerToString((int)EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) + "," +
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
//| RS01-CANON-01: restart-stable canonical identity (v2)            |
//| Deterministic, length-prefixed fields. Excludes setup_id,        |
//| attempt_id, counters, TimeCurrent, MathRand.                     |
//+------------------------------------------------------------------+
string CExecutionLedger::BuildStableCanonicalIdentity(const string strategy_group_key,
                                                     const string symbol,
                                                     const string setup_type,
                                                     int direction,
                                                     datetime signal_time,
                                                     int setup_tf,
                                                     int version)
  {
   string key = "CAN" + IntegerToString(version) + "|";
   key += IntegerToString(StringLen(strategy_group_key)) + ":" + strategy_group_key + "|";
   key += IntegerToString(StringLen(symbol)) + ":" + symbol + "|";
   key += IntegerToString(StringLen(setup_type)) + ":" + setup_type + "|";
   key += "dir:" + IntegerToString(direction) + "|";
   key += "bar:" + IntegerToString((long)signal_time) + "|";
   key += "tf:" + IntegerToString(setup_tf);
   return key;
  }

//+------------------------------------------------------------------+
//| RS01-CANON-01: parse legacy v1 stable components                 |
//| Legacy v1: v1|group|symbol|direction|signal_time|setup_tf|setup_id
//| setup_id (7th) is volatile and MUST NOT participate in comparison.|
//+------------------------------------------------------------------+
bool CExecutionLedger::ParseLegacyV1CanonicalStable(const string canonical_identity,
                                                    string &out_group,
                                                    string &out_symbol,
                                                    string &out_direction,
                                                    string &out_signal_time,
                                                    string &out_setup_tf)
  {
   out_group=""; out_symbol=""; out_direction=""; out_signal_time=""; out_setup_tf="";
   if(StringFind(canonical_identity, "v1|") != 0)
      return false;
   // Split on '|' and extract stable fields 1..5 (0=v1, 6=volatile setup_id)
   string parts[];
   int n = StringSplit(canonical_identity, '|', parts);
   if(n < 6)
      return false;
   out_group       = parts[1];
   out_symbol      = parts[2];
   out_direction   = parts[3];
   out_signal_time = parts[4];
   out_setup_tf    = parts[5];
   return (out_group != "" || out_symbol != "" || out_signal_time != "");
  }

//+------------------------------------------------------------------+
//| RS01-CANON-01: compare logical identity with legacy v1 compat     |
//| Returns true only when stable logical components match.            |
//| Unknown/unsafe legacy formats => false (fail-closed collision).   |
//| Genuine hash collision with different stable identity remains     |
//| fail-closed because this returns false.                           |
//+------------------------------------------------------------------+
bool CExecutionLedger::CanonicalSameLogicalSetup(const string existing_canonical,
                                                 const string new_canonical)
  {
   if(existing_canonical == "" || new_canonical == "")
      return false;
   if(existing_canonical == new_canonical)
      return true;
   // v2 stable format: exact match required (deterministic builder)
   bool existing_v2 = (StringFind(existing_canonical, "CAN2|") == 0);
   bool new_v2      = (StringFind(new_canonical, "CAN2|") == 0);
   if(existing_v2 && new_v2)
      return (existing_canonical == new_canonical);
   // Legacy v1 compatibility: compare stable components only (ignore volatile setup_id)
   if(!existing_v2 && StringFind(existing_canonical, "v1|") == 0 && new_v2)
     {
      // new v2 -> compare by rebuilding expected v2 from stable parse of legacy? Or parse legacy and
      // compare each component against new v2 fields.
      string g,s,d,b,tf;
      if(!ParseLegacyV1CanonicalStable(existing_canonical,g,s,d,b,tf))
         return false; // unsafe/unknown legacy => fail-closed
      // Build expected stable identity from legacy components
      string expected = BuildStableCanonicalIdentity(g,s,"DEFAULT_SETUP",(int)StringToInteger(d),(datetime)StringToInteger(b),(int)StringToInteger(tf),2);
      return (expected == new_canonical);
     }
   if(existing_v2 && StringFind(new_canonical, "v1|") == 0)
     {
      string g,s,d,b,tf;
      if(!ParseLegacyV1CanonicalStable(new_canonical,g,s,d,b,tf))
         return false;
      string expected = BuildStableCanonicalIdentity(g,s,"DEFAULT_SETUP",(int)StringToInteger(d),(datetime)StringToInteger(b),(int)StringToInteger(tf),2);
      return (expected == existing_canonical);
     }
   // v1 vs v1: compare stable components only
   if(StringFind(existing_canonical, "v1|") == 0 && StringFind(new_canonical, "v1|") == 0)
     {
      string g1,s1,d1,b1,tf1,g2,s2,d2,b2,tf2;
      if(!ParseLegacyV1CanonicalStable(existing_canonical,g1,s1,d1,b1,tf1)) return false;
      if(!ParseLegacyV1CanonicalStable(new_canonical,g2,s2,d2,b2,tf2)) return false;
      return (g1==g2 && s1==s2 && d1==d2 && b1==b2 && tf1==tf2);
     }
   // Unknown format => fail-closed
   return false;
  }

//+------------------------------------------------------------------+
//| RS01-CANON-01: transactional upgrade of legacy canonical (safe)  |
//| Only upgrades when expected existing still matches (optimistic).  |
//| Failure => caller keeps fail-closed/duplicate behavior; no claim  |
//| uniqueness weakened.                                              |
//+------------------------------------------------------------------+
bool CExecutionLedger::UpgradeClaimCanonicalIfSafe(const string claim_id,
                                                   const string expected_existing,
                                                   const string new_canonical)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   if(claim_id == "" || new_canonical == "" || expected_existing == "")
      return false;
   // Never "upgrade" away a genuine difference
   if(!CanonicalSameLogicalSetup(expected_existing, new_canonical))
      return false;
   if(!DatabaseTransactionBegin(m_db_handle))
      return false;
   string sql = "UPDATE setup_claims SET canonical_identity='" + EscapeSQL(new_canonical) +
                "', serialization_version=2, updated_at=" + IntegerToString((long)TimeCurrent()) +
                " WHERE claim_id='" + EscapeSQL(claim_id) +
                "' AND canonical_identity='" + EscapeSQL(expected_existing) + "';";
   if(!ExecuteSQL(sql))
     {
      DatabaseTransactionRollback(m_db_handle);
      return false;
     }
   if(!DatabaseTransactionCommit(m_db_handle))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| E2.6: tx helpers (no nested transactions)                         |
//+------------------------------------------------------------------+
bool CExecutionLedger::LogStateTransitionInTx(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE old_state,
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

bool CExecutionLedger::PrepareIntentRecord(ExecutionAttemptRecord &record) const
  {
   if(record.attempt_id == "")
      return false;
   record.created_at = TimeCurrent();
   record.state = EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED;
   record.submission_allowed = false;
   record.executed_volume = 0.0;
   record.remaining_volume = record.requested_volume;
   record.schema_version = m_schema_version;
   // F-002 foundation: unknown runtime reservation remains explicit; InsertIntentNoTx fails closed until verified.
   if(record.risk_reserve_state == EXEC_RISK_RESERVE_STATE_UNKNOWN && !record.risk_reserve_known && record.risk_reserve_model_version == 0)
      InitRiskReservationUnknown(record);
   return true;
  }

bool CExecutionLedger::InsertIntentNoTx(const ExecutionAttemptRecord &record)
  {
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   ExecutionAttemptRecord persist = record;
   string perr="";
   // F-002: durable initial reservation is required atomically with durable Intent for supported schema v3 paths.
   // Legacy/unverified/unknown reservation is fail-closed for new intent persistence (never 0-risk, never silent).
   if(!NormalizeRiskReservationForPersist(persist, perr))
      return false;
   string sql = "INSERT INTO execution_attempts (attempt_id, setup_id, symbol, magic, intent, direction, "
                "requested_volume, executed_volume, remaining_volume, entry_price, stop_loss, take_profit, "
                "created_at, state, submission_allowed, schema_version, "
                "risk_reserve_initial_amount, risk_reserve_remaining_amount, risk_reserve_currency, "
                "risk_reserve_equity_snapshot, risk_reserve_percent_snapshot, risk_reserve_model_version, "
                "risk_reserve_state, risk_reserve_revision, risk_reserve_updated_at, risk_reserve_release_reason) VALUES ('" +
                EscapeSQL(persist.attempt_id) + "','" +
                EscapeSQL(persist.setup_id) + "','" +
                EscapeSQL(persist.symbol) + "'," +
                IntegerToString((long)persist.magic) + "," +
                IntegerToString((int)persist.intent) + "," +
                IntegerToString((int)persist.direction) + "," +
                DoubleToString(persist.requested_volume, 8) + "," +
                DoubleToString(persist.executed_volume, 8) + "," +
                DoubleToString(persist.remaining_volume, 8) + "," +
                DoubleToString(persist.entry_price, 8) + "," +
                DoubleToString(persist.stop_loss, 8) + "," +
                DoubleToString(persist.take_profit, 8) + "," +
                IntegerToString((long)persist.created_at) + "," +
                IntegerToString((int)persist.state) + "," +
                IntegerToString(0) + "," +
                IntegerToString(persist.schema_version) + "," +
                DoubleToString(persist.risk_reserve_initial_amount, 8) + "," +
                DoubleToString(persist.risk_reserve_remaining_amount, 8) + ",'" +
                EscapeSQL(persist.risk_reserve_currency) + "'," +
                DoubleToString(persist.risk_reserve_equity_snapshot, 8) + "," +
                DoubleToString(persist.risk_reserve_percent_snapshot, 8) + "," +
                IntegerToString(persist.risk_reserve_model_version) + "," +
                IntegerToString(persist.risk_reserve_state) + "," +
                IntegerToString(persist.risk_reserve_revision) + "," +
                IntegerToString((long)persist.risk_reserve_updated_at) + ",'" +
                EscapeSQL(persist.risk_reserve_release_reason) + "');";
   if(!ExecuteSQL(sql))
      return false;
   return LogStateTransitionInTx(persist.attempt_id, EXEC_STATE_NONE, EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED,
                                 "Intent created; risk_reserve=" + DoubleToString(persist.risk_reserve_initial_amount, 2) + " " + persist.risk_reserve_currency);
  }

bool CExecutionLedger::CreateIntentInTx(ExecutionAttemptRecord &record, string &err)
  {
   err = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { err="LEDGER_UNAVAILABLE"; return false; }
   if(record.attempt_id == "")
      record.attempt_id = GenerateAttemptId();
   if(!PrepareIntentRecord(record))
     { err="PREPARE_INTENT_FAILED"; return false; }
   if(!InsertIntentNoTx(record))
     { err="INSERT_INTENT_FAILED"; return false; }
   return true;
  }

bool CExecutionLedger::AffectedRowsIsOne(bool &ok)
  {
   ok = false;
   int h = DatabasePrepare(m_db_handle, "SELECT changes();");
   if(h == INVALID_HANDLE)
      return false;
   int affected = 0;
   if(DatabaseRead(h))
      DatabaseColumnInteger(h, 0, affected);
   DatabaseFinalize(h);
   ok = (affected == 1);
   return true;
  }

bool CExecutionLedger::TableHasColumn(const string table_name, const string column_name, bool &has_column)
  {
   has_column = false;
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   string sql = "PRAGMA table_info(" + EscapeSQL(table_name) + ");";
   int h = DatabasePrepare(m_db_handle, sql);
   if(h == INVALID_HANDLE)
      return false;
   while(DatabaseRead(h))
     {
      string name = DatabaseColumnString(h, 1);
      if(name == column_name)
        { has_column = true; DatabaseFinalize(h); return true; }
     }
   DatabaseFinalize(h);
   return true;
  }

bool CExecutionLedger::MigrateV2ToV3AddColumnBestEffort(const string table_name, const string column_name, const string column_type)
  {
   bool has = false;
   if(!TableHasColumn(table_name, column_name, has))
      return false;
   if(has)
      return true;
   string sql = "ALTER TABLE " + EscapeSQL(table_name) + " ADD COLUMN " + EscapeSQL(column_name) + " " + column_type + ";";
   // Best-effort: if column already exists in a race/drift case, treat as success; verification is authoritative.
   if(ExecuteSQL(sql))
      return true;
   has = false;
   if(TableHasColumn(table_name, column_name, has) && has)
      return true;
   return false;
  }

bool CExecutionLedger::VerifyExecutionAttemptsV3Columns()
  {
   bool ok=false;
   if(!TableHasColumn("execution_attempts","risk_reserve_initial_amount",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_remaining_amount",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_currency",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_equity_snapshot",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_percent_snapshot",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_model_version",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_state",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_revision",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_updated_at",ok) || !ok) return false;
   if(!TableHasColumn("execution_attempts","risk_reserve_release_reason",ok) || !ok) return false;
   return true;
  }

void CExecutionLedger::InitRiskReservationUnknown(ExecutionAttemptRecord &record) const
  {
   record.risk_reserve_initial_amount = 0.0;
   record.risk_reserve_remaining_amount = 0.0;
   record.risk_reserve_currency = "";
   record.risk_reserve_equity_snapshot = 0.0;
   record.risk_reserve_percent_snapshot = 0.0;
   record.risk_reserve_model_version = 0;
   record.risk_reserve_state = EXEC_RISK_RESERVE_STATE_UNKNOWN;
   record.risk_reserve_revision = 0;
   record.risk_reserve_updated_at = 0;
   record.risk_reserve_release_reason = "";
   record.risk_reserve_known = false;
  }

void CExecutionLedger::InitRiskReservationLegacyUnverified(ExecutionAttemptRecord &record) const
  {
   InitRiskReservationUnknown(record);
   record.risk_reserve_state = EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED;
   record.risk_reserve_release_reason = "LEGACY_SCHEMA_NULL";
   record.risk_reserve_known = false;
  }

bool CExecutionLedger::NormalizeRiskReservationForPersist(ExecutionAttemptRecord &record, string &err) const
  {
   err = "";
   if(!record.risk_reserve_known)
     { err = "RESERVATION_UNKNOWN_OR_UNVERIFIED"; return false; }
   if(record.risk_reserve_model_version != EXEC_RISK_RESERVE_MODEL_V1)
     { err = "RESERVATION_MODEL_UNKNOWN"; return false; }
   if(record.risk_reserve_currency == "")
     { err = "RESERVATION_CURRENCY_MISSING"; return false; }
   if(!MathIsValidNumber(record.risk_reserve_initial_amount) || record.risk_reserve_initial_amount <= 0.0)
     { err = "RESERVATION_INITIAL_INVALID"; return false; }
   if(!MathIsValidNumber(record.risk_reserve_remaining_amount) || record.risk_reserve_remaining_amount < 0.0)
     { err = "RESERVATION_REMAINING_INVALID"; return false; }
   if(!MathIsValidNumber(record.risk_reserve_equity_snapshot) || record.risk_reserve_equity_snapshot <= 0.0)
     { err = "RESERVATION_EQUITY_INVALID"; return false; }
   if(!MathIsValidNumber(record.risk_reserve_percent_snapshot) || record.risk_reserve_percent_snapshot <= 0.0)
     { err = "RESERVATION_PERCENT_INVALID"; return false; }
   if(record.risk_reserve_revision < 1)
     record.risk_reserve_revision = 1;
   if(record.risk_reserve_state <= EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED)
     record.risk_reserve_state = EXEC_RISK_RESERVE_STATE_ACTIVE;
   if(record.risk_reserve_updated_at <= 0)
     record.risk_reserve_updated_at = TimeCurrent();
   return true;
  }

bool CExecutionLedger::PopulateRiskReservationFromAttemptParams(const string symbol, ENUM_ORDER_INTENT intent, double volume, double entry_price, double stop_loss, ExecutionAttemptRecord &record, string &err) const
  {
   err = "";
   InitRiskReservationUnknown(record);
   if(symbol == "" || volume <= 0.0 || entry_price <= 0.0 || stop_loss <= 0.0)
     { err = "RESERVATION_INPUT_INVALID"; return false; }
   ENUM_ORDER_TYPE order_type = (intent == ORDER_INTENT_OPEN_LONG ? ORDER_TYPE_BUY : (intent == ORDER_INTENT_OPEN_SHORT ? ORDER_TYPE_SELL : (ENUM_ORDER_TYPE)-1));
   if(order_type != ORDER_TYPE_BUY && order_type != ORDER_TYPE_SELL)
     { err = "RESERVATION_ORDER_TYPE_INVALID"; return false; }
   double loss = 0.0;
   ResetLastError();
   if(!OrderCalcProfit(order_type, symbol, volume, entry_price, stop_loss, loss))
     { err = "RESERVATION_ORDERCALCPROFIT_FAILED"; return false; }
   loss = MathAbs(loss);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   if(!MathIsValidNumber(loss) || loss <= 0.0) { err = "RESERVATION_LOSS_INVALID"; return false; }
   if(!MathIsValidNumber(equity) || equity <= 0.0) { err = "RESERVATION_EQUITY_INVALID"; return false; }
   if(currency == "") { err = "RESERVATION_CURRENCY_INVALID"; return false; }
   record.risk_reserve_known = true;
   record.risk_reserve_model_version = EXEC_RISK_RESERVE_MODEL_V1;
   record.risk_reserve_state = EXEC_RISK_RESERVE_STATE_ACTIVE;
   record.risk_reserve_initial_amount = loss;
   record.risk_reserve_remaining_amount = loss;
   record.risk_reserve_currency = currency;
   record.risk_reserve_equity_snapshot = equity;
   record.risk_reserve_percent_snapshot = (loss / equity * 100.0);
   record.risk_reserve_revision = 1;
   record.risk_reserve_updated_at = TimeCurrent();
   record.risk_reserve_release_reason = "";
   return true;
  }

bool CExecutionLedger::ReadAttemptRiskReservationColumns(int handle, int start_col, ExecutionAttemptRecord &record) const
  {
   // start_col points to risk_reserve_initial_amount (REAL, nullable in legacy migrated rows).
   // COALESCE in SELECT maps NULL->0/''/-1; -1 state means legacy/null/unverified and must fail closed (never 0 risk).
   record.risk_reserve_initial_amount   = DatabaseColumnDouble2(handle, start_col + 0);
   record.risk_reserve_remaining_amount = DatabaseColumnDouble2(handle, start_col + 1);
   record.risk_reserve_currency         = DatabaseColumnString(handle, start_col + 2);
   record.risk_reserve_equity_snapshot  = DatabaseColumnDouble2(handle, start_col + 3);
   record.risk_reserve_percent_snapshot = DatabaseColumnDouble2(handle, start_col + 4);
   record.risk_reserve_model_version    = (int)DatabaseColumnLong2(handle, start_col + 5);
   record.risk_reserve_state            = (int)DatabaseColumnLong2(handle, start_col + 6);
   record.risk_reserve_revision         = (int)DatabaseColumnLong2(handle, start_col + 7);
   record.risk_reserve_updated_at       = (datetime)DatabaseColumnLong2(handle, start_col + 8);
   record.risk_reserve_release_reason   = DatabaseColumnString(handle, start_col + 9);
   if(record.risk_reserve_state < 0)
      record.risk_reserve_state = EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED;
   record.risk_reserve_known = (record.risk_reserve_state > EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED &&
                                record.risk_reserve_model_version == EXEC_RISK_RESERVE_MODEL_V1 &&
                                record.risk_reserve_currency != "" &&
                                record.risk_reserve_initial_amount > 0.0 &&
                                MathIsValidNumber(record.risk_reserve_initial_amount));
   if(!record.risk_reserve_known)
     {
      // Preserve amounts/currency for diagnostics only; known=false prevents reservation credit.
      if(record.risk_reserve_state == EXEC_RISK_RESERVE_STATE_UNKNOWN)
         InitRiskReservationLegacyUnverified(record);
      else if(record.risk_reserve_state == EXEC_RISK_RESERVE_STATE_LEGACY_UNVERIFIED)
         { record.risk_reserve_known = false; if(record.risk_reserve_release_reason=="") record.risk_reserve_release_reason="LEGACY_SCHEMA_NULL"; }
      else
         { InitRiskReservationUnknown(record); record.risk_reserve_state=EXEC_RISK_RESERVE_STATE_INVALID; }
     }
   return true;
  }



//+------------------------------------------------------------------+
//| Log State Transition                                             |
//+------------------------------------------------------------------+
bool CExecutionLedger::LogStateTransition(const string attempt_id, ENUM_EXEC_ATTEMPT_STATE old_state,
                                          ENUM_EXEC_ATTEMPT_STATE new_state, const string reason,
                                          uint retcode)
   {
    return LogStateTransitionInTx(attempt_id, old_state, new_state, reason, retcode);
   }

// E2.3: Setup Claim lifecycle implementations (minimal, fail-closed)
// Option B (R3A): legacy non-atomic/unbound APIs are fail-closed. No DB mutation.
CExecutionLedger::ENUM_CLAIM_RESULT CExecutionLedger::CreateClaim(
    const string strategy_group_key,
    const string logical_setup_key,
    const string canonical_identity,
    int serialization_version,
    ExecutionAttemptRecord &initial_attempt)
  {
   initial_attempt.last_reason = "OPTION_B_DEPRECATED_NONATOMIC_CREATE_CLAIM";
   return CLAIM_DEPRECATED_UNBOUND;
  }

//+------------------------------------------------------------------+
//| E2.6: controlled retry helpers (source-only; live DB/MT5 runtime  |
//| NOT authorized). No broker calls. No auto-retry.                  |
//+------------------------------------------------------------------+
string CExecutionLedger::BuildRetryActionId(const string claim_id,const string prior_attempt_id,int expected_retry_sequence)
  {
   return "RTRY|" + claim_id + "|" + prior_attempt_id + "|" + IntegerToString(expected_retry_sequence);
  }

bool CExecutionLedger::GetClaimById(const string claim_id,
                                    const string strategy_group_key,
                                    const string logical_setup_key,
                                    int &claim_state,
                                    string &current_attempt_id,
                                    int &retry_sequence)
  {
   claim_state = -1; current_attempt_id = ""; retry_sequence = -1;
   if(!m_db_available || m_db_handle == INVALID_HANDLE) return false;
   if(claim_id == "" || strategy_group_key == "" || logical_setup_key == "") return false;
   string sql = "SELECT claim_state,current_attempt_id,retry_sequence FROM setup_claims WHERE claim_id='" +
                EscapeSQL(claim_id) + "' AND strategy_group_key='" + EscapeSQL(strategy_group_key) +
                "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE) return false;
   bool found = false;
   if(DatabaseRead(handle))
     {
      DatabaseColumnInteger(handle, 0, claim_state);
      DatabaseColumnText(handle, 1, current_attempt_id);
      DatabaseColumnInteger(handle, 2, retry_sequence);
      found = true;
     }
   DatabaseFinalize(handle);
   return found;
  }

bool CExecutionLedger::IsRetryEligibleFinalFailure(const ExecutionAttemptRecord &attempt,string &why_not)
  {
   why_not = "";
   if(attempt.state != EXEC_STATE_FINAL_FAILURE)
     { why_not="ATTEMPT_NOT_FINAL_FAILURE state="+IntegerToString((int)attempt.state); return false; }
   string fc = attempt.failure_class;
   if(fc=="" || fc=="AMBIGUOUS" || fc=="TIMEOUT" || fc=="CONNECTION" || fc=="RECONNECTION_REQUIRED" ||
      fc=="AUTHORIZATION_DENIED" || fc=="UNKNOWN" || fc=="SUBMITTED" || fc=="PARTIAL_FILL" ||
      fc=="ABORTED" || fc=="SUCCESS" || fc=="RECONCILIATION_REQUIRED" ||
      StringFind(fc,"AMBIGUOUS")>=0 || StringFind(fc,"TIMEOUT")>=0 || StringFind(fc,"CONNECTION")>=0)
     { why_not="FORBIDDEN_OR_UNKNOWN_FAILURE_CLASS["+fc+"]"; return false; }
   if(attempt.last_retcode == TRADE_RETCODE_TIMEOUT || attempt.last_retcode == TRADE_RETCODE_CONNECTION ||
      attempt.last_retcode == TRADE_RETCODE_INVALID_PRICE || attempt.last_retcode == TRADE_RETCODE_PRICE_CHANGED ||
      attempt.last_retcode == TRADE_RETCODE_PRICE_OFF || attempt.last_retcode == TRADE_RETCODE_REQUOTE)
     { why_not="AMBIGUOUS_RETCODE["+IntegerToString((int)attempt.last_retcode)+"]"; return false; }
   if(attempt.broker_order_ticket > 0 || attempt.broker_deal_ticket > 0 || attempt.broker_position_ticket > 0)
     { why_not="BROKER_EVIDENCE_PRESENT_REQUIRES_RECONCILIATION"; return false; }
   if(attempt.executed_volume > 0.0)
     { why_not="EXECUTED_VOLUME_PRESENT"; return false; }
   if(fc != "FINAL_FAILURE")
     { why_not="UNPROVEN_TERMINAL_NON_EXECUTION_CLASS["+fc+"]"; return false; }
   return true;
  }

//+------------------------------------------------------------------+
//| E2.6 P1-B: bounded read-only durable retry candidate discovery.   |
//| ACTIVE claims only; exact binding; same evidence validator as     |
//| ApproveAndCreateRetry; excludes claim-only/orphan/inconsistent/   |
//| consumed/ambiguous. Deterministic order. No DB writes.            |
//| Fail-closed on SQL/prepare/read/parse/DB errors.                  |
//+------------------------------------------------------------------+
int CExecutionLedger::GetRetryEligibleCandidates(RetryEligibleCandidate &out[], int max_candidates, string &error)
  {
   ArrayResize(out, 0);
   error = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { error = "LEDGER_UNAVAILABLE"; return -1; }
   if(max_candidates < 1) max_candidates = 1;
   if(max_candidates > 10) max_candidates = 10;
   // Read-only: ACTIVE claims joined to current attempt. Bounded, deterministic.
   string sql =
      "SELECT sc.claim_id,sc.strategy_group_key,sc.logical_setup_key,sc.canonical_identity,sc.serialization_version,"
      "sc.claim_state,sc.current_attempt_id,sc.retry_sequence,"
      "ea.attempt_id,ea.symbol,ea.direction,ea.state,ea.failure_class,ea.last_retcode,"
      "ea.requested_volume,ea.executed_volume,ea.remaining_volume,"
      "ea.broker_order_ticket,ea.broker_deal_ticket,ea.broker_position_ticket,"
      "(SELECT COUNT(*) FROM retry_approval_events rae WHERE rae.claim_id=sc.claim_id AND rae.prior_attempt_id=sc.current_attempt_id AND rae.retry_sequence_before=sc.retry_sequence) AS consumed_count "
      "FROM setup_claims sc "
      "INNER JOIN execution_attempts ea ON ea.attempt_id=sc.current_attempt_id "
      "WHERE sc.claim_state=" + IntegerToString((int)SETUP_CLAIM_ACTIVE) +
      " AND sc.current_attempt_id IS NOT NULL AND sc.current_attempt_id <> '' "
      "ORDER BY sc.created_at ASC, sc.claim_id ASC, ea.attempt_id ASC "
      "LIMIT " + IntegerToString(max_candidates * 4) + ";";
   ResetLastError();
   int h = DatabasePrepare(m_db_handle, sql);
   if(h == INVALID_HANDLE)
     { error = "CANDIDATE_QUERY_PREPARE_FAILED"; return -1; }
   int returned = 0;
   while(DatabaseRead(h) && returned < max_candidates)
     {
      RetryEligibleCandidate c; ZeroMemory(c); c.valid = false;
      c.claim_id             = DatabaseColumnString(h, 0);
      c.strategy_group_key   = DatabaseColumnString(h, 1);
      c.logical_setup_key    = DatabaseColumnString(h, 2);
      c.canonical_identity   = DatabaseColumnString(h, 3);
      c.serialization_version= (int)DatabaseColumnLong2(h, 4);
      c.claim_state          = (int)DatabaseColumnLong2(h, 5);
      c.prior_attempt_id     = DatabaseColumnString(h, 6);
      c.retry_sequence       = (int)DatabaseColumnLong2(h, 7);
      string ea_attempt_id   = DatabaseColumnString(h, 8);
      c.symbol               = DatabaseColumnString(h, 9);
      c.direction            = (int)DatabaseColumnLong2(h, 10);
      c.attempt_state        = (int)DatabaseColumnLong2(h, 11);
      c.failure_class        = DatabaseColumnString(h, 12);
      c.retcode              = (uint)DatabaseColumnLong2(h, 13);
      c.requested_volume     = DatabaseColumnDouble2(h, 14);
      c.executed_volume      = DatabaseColumnDouble2(h, 15);
      c.remaining_volume     = DatabaseColumnDouble2(h, 16);
      c.broker_order_ticket  = (ulong)DatabaseColumnLong2(h, 17);
      c.broker_deal_ticket   = (ulong)DatabaseColumnLong2(h, 18);
      c.broker_position_ticket=(ulong)DatabaseColumnLong2(h, 19);
      int consumed_count     = (int)DatabaseColumnLong2(h, 20);
      if(c.claim_id == "" || c.strategy_group_key == "" || c.logical_setup_key == "" || c.prior_attempt_id == "" || ea_attempt_id == "")
         continue;
      if(c.prior_attempt_id != ea_attempt_id)
         continue;
      c.consumed_by_approval = (consumed_count > 0);
      if(c.consumed_by_approval)
         continue;
      // Reuse SAME evidence validator as ApproveAndCreateRetry (single source of truth).
      ExecutionAttemptRecord att;
      if(!GetAttempt(c.prior_attempt_id, att))
         continue; // fail-closed per row: no eligibility from partial/missing evidence
      if(att.attempt_id != c.prior_attempt_id || att.state != (ENUM_EXEC_ATTEMPT_STATE)c.attempt_state)
         continue;
      string why = "";
      if(!IsRetryEligibleFinalFailure(att, why))
         continue;
      c.requested_volume = att.requested_volume; c.executed_volume = att.executed_volume; c.remaining_volume = att.remaining_volume;
      c.broker_order_ticket = att.broker_order_ticket; c.broker_deal_ticket = att.broker_deal_ticket; c.broker_position_ticket = att.broker_position_ticket;
      c.failure_class = att.failure_class; c.retcode = att.last_retcode; c.attempt_state = (int)att.state;
      c.evidence_summary = "FINAL_FAILURE class=" + c.failure_class + " ret=" + IntegerToString((int)c.retcode) +
                           " req=" + DoubleToString(c.requested_volume,8) + " exec=" + DoubleToString(c.executed_volume,8) +
                           " rem=" + DoubleToString(c.remaining_volume,8) + " ord=" + IntegerToString((long)c.broker_order_ticket) +
                           " deal=" + IntegerToString((long)c.broker_deal_ticket) + " pos=" + IntegerToString((long)c.broker_position_ticket) +
                           " no-broker-evidence";
      c.eligibility_reason = "ELIGIBLE_FINAL_FAILURE_VERIFIED";
      c.valid = true;
      int idx = ArraySize(out); ArrayResize(out, idx + 1); out[idx] = c; returned++;
     }
   DatabaseFinalize(h);
   error = "";
   return returned;
  }

bool CExecutionLedger::GetRetryApprovalEventOutcome(const string action_id,string &outcome,string &new_attempt_id)
  {
   outcome=""; new_attempt_id="";
   if(!m_db_available || m_db_handle == INVALID_HANDLE || action_id=="") return false;
   string sql = "SELECT outcome,new_attempt_id FROM retry_approval_events WHERE action_id='" + EscapeSQL(action_id) + "';";
   int h = DatabasePrepare(m_db_handle, sql);
   if(h == INVALID_HANDLE) return false;
   bool found=false;
   if(DatabaseRead(h)) { outcome = DatabaseColumnString(h,0); new_attempt_id = DatabaseColumnString(h,1); found=true; }
   DatabaseFinalize(h);
   return found;
  }

//+------------------------------------------------------------------+
//| E2.6-R1: read-only interrupted durable retry handoff visibility. |
//| Identifies approved retry intent (retry_approval_events joined   |
//| to execution_attempts + setup_claims) that is not a submitted     |
//| terminal success path and may need operator reconciliation after  |
//| restart (transient handoff is NOT restored/submitted).           |
//| Bounded, deterministic, fail-closed, NO mutations/broker calls.   |
//+------------------------------------------------------------------+
int CExecutionLedger::GetInterruptedRetryHandoffs(const string account_login,
                                                  const string account_server,
                                                  const string strategy_group_key,
                                                  InterruptedRetryHandoff &out[],
                                                  int max_rows,
                                                  string &error)
  {
   ArrayResize(out, 0);
   error = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { error = "LEDGER_UNAVAILABLE"; return -1; }
   if(account_login == "" || account_server == "" || strategy_group_key == "")
     { error = "MISSING_CONTEXT_FILTER"; return -1; }
   if(max_rows < 1) max_rows = 1;
   if(max_rows > 10) max_rows = 10;
   // Exact durable correlation: approval event -> new attempt -> claim. Filter by persisted account/group context.
   // Exclude only durable terminal success already fully resolved from operator perspective? Keep submitted/completed
   // visible? Requirement: distinguish submitted/may-have-occurred/reconciliation-required/unresolved/unreadable.
   // We report rows where new attempt is not cleanly auto-ignorable: include INTENT_DURABLE_NOT_SUBMITTED,
   // SUBMISSION_MAY_HAVE_OCCURRED, SUBMITTED, RECONCILIATION_REQUIRED, PARTIAL_FILL, ABORTED/FINAL_FAILURE as
   // diagnostics; exclude COMPLETED to avoid stale noise unless claim still unresolved - keep bounded and explicit.
   string sql =
      "SELECT rae.action_id,rae.claim_id,rae.strategy_group_key,rae.logical_setup_key,rae.prior_attempt_id,rae.new_attempt_id,"
      "rae.retry_sequence_before,rae.retry_sequence_after,rae.approval_timestamp,rae.account_login,rae.account_server,rae.outcome,"
      "ea.state,ea.submitted_at,ea.broker_order_ticket,ea.broker_deal_ticket,ea.broker_position_ticket,ea.failure_class,"
      "sc.claim_state,sc.current_attempt_id,sc.retry_sequence "
      "FROM retry_approval_events rae "
      "LEFT JOIN execution_attempts ea ON ea.attempt_id=rae.new_attempt_id "
      "LEFT JOIN setup_claims sc ON sc.claim_id=rae.claim_id "
      "WHERE rae.account_login='" + EscapeSQL(account_login) + "' "
      "AND rae.account_server='" + EscapeSQL(account_server) + "' "
      "AND rae.strategy_group_key='" + EscapeSQL(strategy_group_key) + "' "
      "ORDER BY rae.approval_timestamp DESC, rae.action_id DESC "
      "LIMIT " + IntegerToString(max_rows * 3) + ";";
   ResetLastError();
   int h = DatabasePrepare(m_db_handle, sql);
   if(h == INVALID_HANDLE)
     { error = "INTERRUPTED_QUERY_PREPARE_FAILED"; return -1; }
   int returned = 0;
   while(DatabaseRead(h) && returned < max_rows)
     {
      InterruptedRetryHandoff r; ZeroMemory(r); r.valid=false; r.new_attempt_state=-1;
      r.action_id               = DatabaseColumnString(h, 0);
      r.claim_id                = DatabaseColumnString(h, 1);
      r.strategy_group_key      = DatabaseColumnString(h, 2);
      r.logical_setup_key       = DatabaseColumnString(h, 3);
      r.prior_attempt_id        = DatabaseColumnString(h, 4);
      r.new_attempt_id          = DatabaseColumnString(h, 5);
      r.retry_sequence_before   = (int)DatabaseColumnLong2(h, 6);
      r.retry_sequence_after    = (int)DatabaseColumnLong2(h, 7);
      r.approval_timestamp      = (datetime)DatabaseColumnLong2(h, 8);
      r.account_login           = DatabaseColumnString(h, 9);
      r.account_server          = DatabaseColumnString(h, 10);
      string outcome            = DatabaseColumnString(h, 11);
      bool ea_null = false; // DatabaseColumn* on LEFT JOIN null: treat as unreadable/missing
      // Heuristic: if new_attempt_id exists but join gave empty attempt_id-equivalent state fields, verify via GetAttempt.
      r.approval_event_exists = (r.action_id != "" && outcome != "");
      if(!r.approval_event_exists)
         continue;
      // Exact binding sanity
      if(r.claim_id=="" || r.strategy_group_key=="" || r.logical_setup_key=="" || r.prior_attempt_id=="" || r.new_attempt_id=="")
         continue;
      ExecutionAttemptRecord att; ZeroMemory(att);
      r.new_attempt_readable = GetAttempt(r.new_attempt_id, att);
      if(!r.new_attempt_readable)
        {
         r.new_attempt_state = -1;
         r.status_code = "INTERRUPTED_ATTEMPT_UNREADABLE";
         r.detail = "Durable approval exists but new attempt unreadable/missing; fail-closed, operator reconciliation required. No auto-submit.";
        }
      else
        {
         r.new_attempt_state = (int)att.state;
         r.submitted_recorded = (att.submitted_at > 0 || att.state == EXEC_STATE_SUBMITTED || att.state == EXEC_STATE_COMPLETED || att.broker_order_ticket>0 || att.broker_deal_ticket>0);
         r.submission_may_have_occurred = (att.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED || att.submitted_at > 0);
         r.reconciliation_required = (att.state == EXEC_STATE_RECONCILIATION_REQUIRED || att.state == EXEC_STATE_PARTIAL_FILL);
         if(att.state == EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
           {
            r.status_code = "INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED";
            r.detail = "Approved retry intent durably recorded; transient handoff not resumed after restart/interruption. NOT submitted by this status. No auto-submit/restore.";
           }
         else if(att.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
           {
            r.status_code = "INTERRUPTED_SUBMISSION_MAY_HAVE_OCCURRED";
            r.detail = "Submission may have occurred (ambiguous). Reconciliation required. No retry/auto-submit.";
           }
         else if(att.state == EXEC_STATE_RECONCILIATION_REQUIRED)
           {
            r.status_code = "INTERRUPTED_RECONCILIATION_REQUIRED";
            r.detail = "Attempt requires reconciliation. No retry/auto-submit.";
           }
         else if(att.state == EXEC_STATE_SUBMITTED || att.state == EXEC_STATE_PARTIAL_FILL)
           {
            r.status_code = "INTERRUPTED_SUBMITTED_OR_PARTIAL";
            r.detail = "Durable broker-submission/partial evidence exists; reconcile before any further action. No auto-submit.";
           }
         else if(att.state == EXEC_STATE_COMPLETED)
           {
            r.status_code = "INTERRUPTED_ALREADY_COMPLETED";
            r.detail = "Attempt completed; visibility only.";
           }
         else
           {
            r.status_code = "INTERRUPTED_UNRESOLVED_OR_TERMINAL";
            r.detail = "Attempt in state " + IntegerToString((int)att.state) + "; operator review required. No auto-submit.";
           }
        }
      // claim consistency (read-only)
      string cur_att=""; int cstate=-1, cseq=-1;
      if(GetClaimById(r.claim_id, r.strategy_group_key, r.logical_setup_key, cstate, cur_att, cseq))
        {
         if(cur_att != "" && cur_att != r.new_attempt_id)
            r.detail += " | claim.current_attempt differs (may have advanced); read-only visibility.";
        }
      else
        {
         r.detail += " | claim unreadable; fail-closed visibility.";
        }
      r.valid = true;
      int idx = ArraySize(out); ArrayResize(out, idx + 1); out[idx] = r; returned++;
     }
   DatabaseFinalize(h);
   error = "";
   return returned;
  }

CExecutionLedger::ENUM_RETRY_APPROVE_RESULT CExecutionLedger::ApproveAndCreateRetry(
    const string claim_id,
    const string strategy_group_key,
    const string logical_setup_key,
    const string prior_attempt_id,
    int expected_retry_sequence,
    const RetryLocalContext &ctx,
    const string evidence_reason,
    ExecutionAttemptRecord &new_attempt,
    string &out_action_id,
    string &out_detail)
  {
   out_action_id = ""; out_detail = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { out_detail="LEDGER_UNAVAILABLE"; return RETRY_APPROVE_DB_ERROR; }
   if(claim_id=="" || strategy_group_key=="" || logical_setup_key=="" || prior_attempt_id=="")
     { out_detail="MISSING_CANDIDATE_IDENTITY"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(expected_retry_sequence < 0)
     { out_detail="INVALID_RETRY_SEQUENCE"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(ctx.action_source != "LOCAL_CHART_OBJECT_CLICK")
     { out_detail="INVALID_ACTION_SOURCE"; return RETRY_APPROVE_NOT_AUTHORIZED; }
   RetryLocalContext effective_ctx = ctx;
   if(effective_ctx.auth_model == "")
      effective_ctx.auth_model = "LOCAL_TERMINAL_SESSION_CONTEXT_ONLY";

   string action_id = BuildRetryActionId(claim_id, prior_attempt_id, expected_retry_sequence);
   out_action_id = action_id;

   // Commit-unknown idempotency read-back (read-only).
   {
    string existing_outcome="", existing_new="";
    if(GetRetryApprovalEventOutcome(action_id, existing_outcome, existing_new) && existing_outcome != "")
      {
       string vsql = "SELECT claim_id,prior_attempt_id,retry_sequence_before,new_attempt_id,strategy_group_key,logical_setup_key "
                     "FROM retry_approval_events WHERE action_id='" + EscapeSQL(action_id) + "';";
       int vh = DatabasePrepare(m_db_handle, vsql);
       if(vh == INVALID_HANDLE) { out_detail="ACTION_READBACK_PREPARE_FAILED"; return RETRY_APPROVE_COMMIT_OUTCOME_UNKNOWN; }
       bool match=false;
       if(DatabaseRead(vh))
         {
          string e_claim=DatabaseColumnString(vh,0), e_prior=DatabaseColumnString(vh,1);
          int e_seq=(int)DatabaseColumnLong2(vh,2);
          string e_new=DatabaseColumnString(vh,3), e_g=DatabaseColumnString(vh,4), e_lsk=DatabaseColumnString(vh,5);
          match = (e_claim==claim_id && e_prior==prior_attempt_id && e_seq==expected_retry_sequence && e_g==strategy_group_key && e_lsk==logical_setup_key);
          if(match) existing_new = e_new;
         }
       DatabaseFinalize(vh);
       if(!match) { out_detail="ACTION_ID_COLLISION_INCONSISTENT_FIELDS"; return RETRY_APPROVE_CANDIDATE_INVALID; }
       if(existing_new != "")
         {
          ExecutionAttemptRecord committed_att;
          int cstate=-1; string ccur=""; int cseq=-1;
          bool att_ok = GetAttempt(existing_new, committed_att);
          bool claim_ok = GetClaimById(claim_id,strategy_group_key,logical_setup_key,cstate,ccur,cseq);
          if(att_ok && claim_ok && ccur==existing_new && cseq==expected_retry_sequence+1 && committed_att.state==EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
            { new_attempt = committed_att; out_detail="ALREADY_COMMITTED action_id="+action_id+" new_attempt="+existing_new; return RETRY_APPROVE_ALREADY_CONSUMED; }
         }
       out_detail="ACTION_EXISTS_BUT_COMMIT_OUTCOME_UNVERIFIED action_id="+action_id;
       return RETRY_APPROVE_COMMIT_OUTCOME_UNKNOWN;
      }
   }

   if(!DatabaseTransactionBegin(m_db_handle))
     { out_detail="BEGIN_TX_FAILED"; return RETRY_APPROVE_DB_ERROR; }

   // Reload exact claim and attempt inside tx.
   string check_sql = "SELECT claim_state,current_attempt_id,retry_sequence,strategy_group_key,logical_setup_key "
                      "FROM setup_claims WHERE claim_id='" + EscapeSQL(claim_id) +
                      "' AND strategy_group_key='" + EscapeSQL(strategy_group_key) +
                      "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   int ch = DatabasePrepare(m_db_handle, check_sql);
   if(ch == INVALID_HANDLE) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_PREPARE_FAILED"; return RETRY_APPROVE_DB_ERROR; }
   int claim_state=-1, retry_seq=-1; string current_attempt="", db_g="", db_lsk=""; bool claim_found=false;
   if(DatabaseRead(ch)) { DatabaseColumnInteger(ch,0,claim_state); DatabaseColumnText(ch,1,current_attempt); DatabaseColumnInteger(ch,2,retry_seq); DatabaseColumnText(ch,3,db_g); DatabaseColumnText(ch,4,db_lsk); claim_found=true; }
   DatabaseFinalize(ch);
   if(!claim_found) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_NOT_FOUND"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(claim_state != (int)SETUP_CLAIM_ACTIVE) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_NOT_ACTIVE"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(current_attempt != prior_attempt_id) { DatabaseTransactionRollback(m_db_handle); out_detail="CURRENT_ATTEMPT_CHANGED"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(retry_seq != expected_retry_sequence) { DatabaseTransactionRollback(m_db_handle); out_detail="RETRY_SEQUENCE_CHANGED"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(db_g != strategy_group_key || db_lsk != logical_setup_key) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_BINDING_MISMATCH"; return RETRY_APPROVE_CANDIDATE_INVALID; }

   ExecutionAttemptRecord prior;
   if(!GetAttempt(prior_attempt_id, prior)) { DatabaseTransactionRollback(m_db_handle); out_detail="PRIOR_ATTEMPT_NOT_FOUND"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   string why_not="";
   if(!IsRetryEligibleFinalFailure(prior, why_not)) { DatabaseTransactionRollback(m_db_handle); out_detail="EVIDENCE_GATE_FAILED:"+why_not; return RETRY_APPROVE_CANDIDATE_INVALID; }

   // Inspect existing approval event inside tx.
   {
    string esql = "SELECT claim_id,prior_attempt_id,retry_sequence_before,new_attempt_id FROM retry_approval_events WHERE action_id='" + EscapeSQL(action_id) + "';";
    int eh = DatabasePrepare(m_db_handle, esql);
    if(eh == INVALID_HANDLE) { DatabaseTransactionRollback(m_db_handle); out_detail="APPROVAL_LOOKUP_FAILED"; return RETRY_APPROVE_DB_ERROR; }
    if(DatabaseRead(eh))
      {
       string e_claim=DatabaseColumnString(eh,0), e_prior=DatabaseColumnString(eh,1), e_new=DatabaseColumnString(eh,3);
       int e_seq=(int)DatabaseColumnLong2(eh,2); DatabaseFinalize(eh);
       bool same = (e_claim==claim_id && e_prior==prior_attempt_id && e_seq==expected_retry_sequence);
       DatabaseTransactionRollback(m_db_handle);
       if(!same) { out_detail="ACTION_ID_INCONSISTENT_EXISTING"; return RETRY_APPROVE_CANDIDATE_INVALID; }
       out_detail="ALREADY_CONSUMED_IN_TX action_id="+action_id+" new_attempt="+e_new;
       return RETRY_APPROVE_ALREADY_CONSUMED;
      }
    DatabaseFinalize(eh);
   }

   // Create distinct new attempt intent in same tx (no broker call).
   if(new_attempt.attempt_id == "") new_attempt.attempt_id = GenerateAttemptId();
   if(new_attempt.attempt_id == prior_attempt_id) { DatabaseTransactionRollback(m_db_handle); out_detail="NEW_ATTEMPT_NOT_DISTINCT"; return RETRY_APPROVE_CANDIDATE_INVALID; }
   if(new_attempt.setup_id == "") new_attempt.setup_id = prior.setup_id;
   if(new_attempt.symbol == "") new_attempt.symbol = prior.symbol;
   if(new_attempt.magic == 0) new_attempt.magic = prior.magic;
   if(new_attempt.intent == 0) new_attempt.intent = prior.intent;
   if(new_attempt.direction == 0) new_attempt.direction = prior.direction;
   if(new_attempt.requested_volume <= 0.0) new_attempt.requested_volume = prior.requested_volume;
   if(new_attempt.entry_price <= 0.0) new_attempt.entry_price = prior.entry_price;
   if(new_attempt.stop_loss <= 0.0) new_attempt.stop_loss = prior.stop_loss;
   if(new_attempt.take_profit <= 0.0) new_attempt.take_profit = prior.take_profit;
   // F-002: durable per-Attempt reservation required atomically for retry intent. Compute from prior requested exposure
   // (conservative pre-submit reservation) if caller did not provide a verified reservation; fail closed if uncomputable.
   if(!new_attempt.risk_reserve_known)
     {
      string rerr="";
      if(!PopulateRiskReservationFromAttemptParams(new_attempt.symbol, new_attempt.intent, new_attempt.requested_volume, new_attempt.entry_price, new_attempt.stop_loss, new_attempt, rerr))
        { DatabaseTransactionRollback(m_db_handle); out_detail="RETRY_RESERVATION_FAILED:"+rerr; return RETRY_APPROVE_DB_ERROR; }
     }
   string txerr="";
   if(!CreateIntentInTx(new_attempt, txerr)) { DatabaseTransactionRollback(m_db_handle); out_detail="CREATE_INTENT_IN_TX_FAILED:"+txerr; return RETRY_APPROVE_DB_ERROR; }

   // Conditional claim advance with affected==1.
   string upd = "UPDATE setup_claims SET claim_state=" + IntegerToString((int)SETUP_CLAIM_ACTIVE) +
                ", current_attempt_id='" + EscapeSQL(new_attempt.attempt_id) + "'" +
                ", retry_sequence=" + IntegerToString(retry_seq + 1) +
                ", updated_at=" + IntegerToString((long)TimeCurrent()) +
                ", last_reason='E2.6_RETRY_APPROVED_ATOMIC action=" + EscapeSQL(action_id) +
                " prior=" + EscapeSQL(prior_attempt_id) + " new=" + EscapeSQL(new_attempt.attempt_id) + "' " +
                "WHERE claim_id='" + EscapeSQL(claim_id) +
                "' AND claim_state=" + IntegerToString((int)SETUP_CLAIM_ACTIVE) +
                " AND current_attempt_id='" + EscapeSQL(prior_attempt_id) +
                "' AND retry_sequence=" + IntegerToString(retry_seq) +
                " AND strategy_group_key='" + EscapeSQL(strategy_group_key) +
                "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   if(!ExecuteSQL(upd)) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_UPDATE_FAILED"; return RETRY_APPROVE_DB_ERROR; }
   bool ok=false;
   if(!AffectedRowsIsOne(ok) || !ok) { DatabaseTransactionRollback(m_db_handle); out_detail="CLAIM_UPDATE_AFFECTED_ROWS!=1"; return RETRY_APPROVE_CANDIDATE_INVALID; }

   // Durable single-use approval event (audit/idempotency), same tx.
   datetime ts = (effective_ctx.local_action_time>0 ? effective_ctx.local_action_time : TimeCurrent());
   string ev_reason = evidence_reason; if(StringLen(ev_reason)>240) ev_reason = StringSubstr(ev_reason,0,240);
   string b_reason = effective_ctx.bounded_reason; if(StringLen(b_reason)>120) b_reason = StringSubstr(b_reason,0,120);
   string ev_sql = "INSERT INTO retry_approval_events (action_id,claim_id,strategy_group_key,logical_setup_key,prior_attempt_id,new_attempt_id,"
                    "retry_sequence_before,retry_sequence_after,approval_timestamp,action_source,auth_model,account_login,account_server,"
                    "chart_id,chart_symbol,chart_period,ea_program,terminal_build,evidence_state,evidence_failure_class,evidence_retcode,"
                    "evidence_reason,outcome,schema_version) VALUES ('" +
                    EscapeSQL(action_id) + "','" + EscapeSQL(claim_id) + "','" + EscapeSQL(strategy_group_key) + "','" +
                    EscapeSQL(logical_setup_key) + "','" + EscapeSQL(prior_attempt_id) + "','" + EscapeSQL(new_attempt.attempt_id) + "'," +
                    IntegerToString(retry_seq) + "," + IntegerToString(retry_seq+1) + "," + IntegerToString((long)ts) + ",'" +
                    EscapeSQL(effective_ctx.action_source) + "','" + EscapeSQL(effective_ctx.auth_model) + "','" + EscapeSQL(effective_ctx.account_login) + "','" +
                    EscapeSQL(effective_ctx.account_server) + "'," + IntegerToString((long)effective_ctx.chart_id) + ",'" + EscapeSQL(effective_ctx.chart_symbol) + "'," +
                    IntegerToString(effective_ctx.chart_period) + ",'" + EscapeSQL(effective_ctx.ea_program) + "'," + IntegerToString(effective_ctx.terminal_build) + "," +
                    IntegerToString((int)prior.state) + ",'" + EscapeSQL(prior.failure_class) + "'," + IntegerToString((int)prior.last_retcode) + ",'" +
                    EscapeSQL(ev_reason) + ";ui=" + EscapeSQL(b_reason) + "','COMMITTED_NOT_SUBMITTED'," + IntegerToString(m_schema_version) + ");";
   if(!ExecuteSQL(ev_sql)) { DatabaseTransactionRollback(m_db_handle); out_detail="INSERT_APPROVAL_EVENT_FAILED"; return RETRY_APPROVE_DB_ERROR; }

   if(!LogStateTransitionInTx(prior_attempt_id, EXEC_STATE_FINAL_FAILURE, EXEC_STATE_FINAL_FAILURE,
                              "E2.6_RETRY_APPROVED action="+action_id+" new="+new_attempt.attempt_id+" src="+effective_ctx.action_source, prior.last_retcode))
     { DatabaseTransactionRollback(m_db_handle); out_detail="HISTORY_PRIOR_FAILED"; return RETRY_APPROVE_DB_ERROR; }

   if(!DatabaseTransactionCommit(m_db_handle))
     { DatabaseTransactionRollback(m_db_handle); out_detail="COMMIT_FAILED_OR_UNCERTAIN"; return RETRY_APPROVE_COMMIT_OUTCOME_UNKNOWN; }
   out_detail="COMMITTED action_id="+action_id+" new_attempt="+new_attempt.attempt_id+"; broker not called; revalidate before existing submission protocol";
   return RETRY_APPROVE_COMMITTED;
  }

//+------------------------------------------------------------------+
//| Deprecated split wrappers: fail-closed (no stranded RETRY_AUTH).  |
//+------------------------------------------------------------------+
bool CExecutionLedger::RetryAuthorize(const string claim_id,
                                     const string strategy_group_key,
                                     const string logical_setup_key,
                                     const string attempt_id,
                                     int expected_retry_sequence,
                                     const string operator_approval_ref,
                                     const string reason)
  {
   return false;
  }

bool CExecutionLedger::RetryCreate(const string claim_id,
                                  const string strategy_group_key,
                                  const string logical_setup_key,
                                  const string expected_prior_attempt_id,
                                  int expected_retry_sequence_after_authorize,
                                  ExecutionAttemptRecord &new_attempt)
  {
   return false;
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

//+------------------------------------------------------------------+
//| RS-01: GetSetupClaim                                              |
//+------------------------------------------------------------------+
bool CExecutionLedger::GetSetupClaim(const string strategy_group_key,
                                    const string logical_setup_key,
                                    string &claim_id,
                                    int &claim_state,
                                    string &current_attempt_id)
  {
   claim_id = "";
   claim_state = -1;
   current_attempt_id = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return false;
   if(strategy_group_key == "" || logical_setup_key == "")
      return false;
   string sql = "SELECT claim_id, claim_state, current_attempt_id FROM setup_claims WHERE strategy_group_key='" +
                EscapeSQL(strategy_group_key) + "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return false;
   bool found = false;
   if(DatabaseRead(handle))
     {
      claim_id = DatabaseColumnString(handle, 0);
      claim_state = (int)DatabaseColumnLong2(handle, 1);
      current_attempt_id = DatabaseColumnString(handle, 2);
      found = true;
     }
   DatabaseFinalize(handle);
   return found;
  }

//+------------------------------------------------------------------+
//| RS-01: CreateSetupClaim                                           |
//| Option B (R3A): deprecated fail-closed. Claim-only acquisition    |
//| without atomic intent is not a supported submission path and must  |
//| not create durable claim state through this compatibility API.    |
//| No DB mutation. Use CreateSetupClaimAndIntent for supported       |
//| initial attempts.                                                 |
//+------------------------------------------------------------------+
CExecutionLedger::ENUM_CLAIM_RESULT CExecutionLedger::CreateSetupClaim(
    const string strategy_group_key,
    const string logical_setup_key,
    const string canonical_identity,
    int serialization_version,
    const string attempt_id)
  {
   return CLAIM_DEPRECATED_UNBOUND;
  }

//+------------------------------------------------------------------+
//| RS-01 atomicity hardening: claim + initial intent in ONE tx.      |
//| On any failure, neither durable claim nor intent is committed.    |
//| No nested transactions. Uses existing tx-safe helpers.            |
//| Existing claim-only records remain visible/blocked (fail-closed).  |
//+------------------------------------------------------------------+
CExecutionLedger::ENUM_CLAIM_RESULT CExecutionLedger::CreateSetupClaimAndIntent(
    const string strategy_group_key,
    const string logical_setup_key,
    const string canonical_identity,
    int serialization_version,
    ExecutionAttemptRecord &attempt,
    string &error_reason)
  {
   error_reason = "";
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { error_reason="LEDGER_UNAVAILABLE"; return CLAIM_ERROR; }
   if(strategy_group_key == "" || logical_setup_key == "" || canonical_identity == "")
     { error_reason="MISSING_IDENTITY"; return CLAIM_ERROR; }
   if(attempt.attempt_id == "")
      attempt.attempt_id = GenerateAttemptId();
   // Check existing claim (read-only precheck; final authority is tx + UNIQUE constraint behavior)
   string existing_id = "", existing_canonical = "";
   string check_sql = "SELECT claim_id, canonical_identity FROM setup_claims WHERE strategy_group_key='" +
                      EscapeSQL(strategy_group_key) + "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "';";
   int handle = DatabasePrepare(m_db_handle, check_sql);
   if(handle == INVALID_HANDLE) { error_reason="CLAIM_PRECHECK_PREPARE_FAILED"; return CLAIM_ERROR; }
   bool exists = false;
   if(DatabaseRead(handle))
     { exists=true; existing_id=DatabaseColumnString(handle,0); existing_canonical=DatabaseColumnString(handle,1); }
   DatabaseFinalize(handle);
   if(exists)
     {
      if(!CanonicalSameLogicalSetup(existing_canonical, canonical_identity))
         { error_reason="IDENTITY_COLLISION"; return CLAIM_IDENTITY_COLLISION; }
      if(existing_canonical != canonical_identity)
         UpgradeClaimCanonicalIfSafe(existing_id, existing_canonical, canonical_identity);
      error_reason="CLAIM_ALREADY_EXISTS";
      return CLAIM_ALREADY_EXISTS;
     }
   if(!DatabaseTransactionBegin(m_db_handle))
     { error_reason="BEGIN_TX_FAILED"; return CLAIM_ERROR; }
   // Insert claim bound to this attempt_id
   string claim_id = "CLAIM_" + IntegerToString((long)TimeCurrent()) + "_" + IntegerToString(MathRand());
   datetime now = TimeCurrent();
   string insert_claim = "INSERT INTO setup_claims (claim_id, strategy_group_key, logical_setup_key, canonical_identity, "
                         "serialization_version, claim_state, current_attempt_id, retry_sequence, created_at, updated_at, last_reason) "
                         "VALUES ('" + EscapeSQL(claim_id) + "','" + EscapeSQL(strategy_group_key) + "','" +
                         EscapeSQL(logical_setup_key) + "','" + EscapeSQL(canonical_identity) + "'," +
                         IntegerToString(serialization_version) + "," + IntegerToString((int)SETUP_CLAIM_ACTIVE) + ",'" +
                         EscapeSQL(attempt.attempt_id) + "',0," + IntegerToString((long)now) + "," +
                         IntegerToString((long)now) + ",'CREATED_ATOMIC_WITH_INTENT');";
   if(!ExecuteSQL(insert_claim))
     { DatabaseTransactionRollback(m_db_handle); error_reason="INSERT_CLAIM_FAILED"; return CLAIM_ERROR; }
   bool ok=false;
   if(!AffectedRowsIsOne(ok) || !ok)
     { DatabaseTransactionRollback(m_db_handle); error_reason="CLAIM_AFFECTED_ROWS!=1"; return CLAIM_ERROR; }
   // Insert initial intent in SAME tx (no nested tx)
   string txerr="";
   // Ensure identity fields are present for audit/consistency
   if(attempt.strategy_group_key == "") attempt.strategy_group_key = strategy_group_key;
   if(attempt.logical_setup_key == "") attempt.logical_setup_key = logical_setup_key;
   if(attempt.canonical_identity == "") attempt.canonical_identity = canonical_identity;
   if(attempt.serialization_version == 0) attempt.serialization_version = serialization_version;
   if(!CreateIntentInTx(attempt, txerr))
     { DatabaseTransactionRollback(m_db_handle); error_reason="CREATE_INTENT_IN_TX_FAILED:"+txerr; return CLAIM_ERROR; }
   if(!DatabaseTransactionCommit(m_db_handle))
     { DatabaseTransactionRollback(m_db_handle); error_reason="COMMIT_FAILED_OR_UNCERTAIN"; return CLAIM_ERROR; }
   return CLAIM_CREATED;
  }

//+------------------------------------------------------------------+
//| RS01-CLAIMORPHAN-01: read-only claim observability               |
//| Inspects setup_claims and distinguishes claim-only (no matching   |
//| execution_attempt for current_attempt_id) from claim-with-intent. |
//| Returns row count inspected (>=0), -1 on query/DB failure         |
//| (fail-closed diagnostic). NEVER releases, resolves, recycles, or  |
//| creates attempts. No credentials/tokens exposed.                  |
//+------------------------------------------------------------------+
int CExecutionLedger::InspectSetupClaims(string &out_report, int &out_orphan_count, int max_rows)
  {
   out_report = "";
   out_orphan_count = 0;
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
      return -1;
   if(max_rows < 1) max_rows = 1;
   if(max_rows > 50) max_rows = 50;
   // Read-only: list recent/active claims (ACTIVE first) with enough fields for operator triage.
   string sql = "SELECT claim_id,strategy_group_key,logical_setup_key,canonical_identity,serialization_version,claim_state,current_attempt_id,created_at,last_reason "
                "FROM setup_claims WHERE claim_state=" + IntegerToString((int)SETUP_CLAIM_ACTIVE) +
                " ORDER BY created_at DESC LIMIT " + IntegerToString(max_rows) + ";";
   int handle = DatabasePrepare(m_db_handle, sql);
   if(handle == INVALID_HANDLE)
      return -1;
   int count = 0;
   while(DatabaseRead(handle) && count < max_rows)
     {
      string claim_id = DatabaseColumnString(handle, 0);
      string group    = DatabaseColumnString(handle, 1);
      string lsk      = DatabaseColumnString(handle, 2);
      string canon    = DatabaseColumnString(handle, 3);
      int    ver      = (int)DatabaseColumnLong2(handle, 4);
      int    state    = (int)DatabaseColumnLong2(handle, 5);
      string cur_att  = DatabaseColumnString(handle, 6);
      long   created  = DatabaseColumnLong2(handle, 7);
      string reason   = DatabaseColumnString(handle, 8);
      bool   has_attempt = false;
      if(cur_att != "")
        {
         ExecutionAttemptRecord rec;
         has_attempt = GetAttempt(cur_att, rec);
        }
      string canon_tag = (StringFind(canon, "v1|") == 0 ? "legacy_v1" : (StringFind(canon, "CAN2|") == 0 ? "v2" : "unknown"));
      string kind = has_attempt ? "CLAIM_WITH_ATTEMPT" : "CLAIM_ONLY_ORPHAN";
      if(!has_attempt) out_orphan_count++;
      // Bounded, non-sensitive detail (no owner tokens/credentials). Truncate canonical display.
      string canon_short = canon;
      if(StringLen(canon_short) > 64) canon_short = StringSubstr(canon_short, 0, 64) + "...";
      if(count > 0) out_report += " | ";
      out_report += kind + "[id=" + claim_id + ",g=" + group + ",lsk=" + lsk + ",v=" + IntegerToString(ver) +
                    ",canon=" + canon_tag + ",state=" + IntegerToString(state) + ",att=" + cur_att +
                    ",has_attempt=" + (has_attempt?"1":"0") + ",created=" + IntegerToString((int)created) +
                    ",reason=" + reason + "]";
      count++;
     }
   DatabaseFinalize(handle);
   return count;
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
    // Verify exactly one row was affected (conditional update)
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
    // Verify exactly one row was affected (conditional update)
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

CExecutionLedger::ENUM_ATTEMPT_IDENTITY_RESOLUTION CExecutionLedger::GetSetupIdentityForAttempt(
   const string attempt_id,
   string &claim_id,
   string &strategy_group_key,
   string &logical_setup_key,
   string &canonical_identity,
   int &serialization_version,
   string &detail)
  {
   claim_id = ""; strategy_group_key = ""; logical_setup_key = ""; canonical_identity = "";
   serialization_version = 0; detail = "";
   if(attempt_id == "")
     { detail = "ATTEMPT_ID_EMPTY"; return IDENTITY_NOT_FOUND; }
   if(!m_db_available || m_db_handle == INVALID_HANDLE)
     { detail = "LEDGER_DB_UNAVAILABLE"; return IDENTITY_DB_UNAVAILABLE; }

   // 1-2) Confirm attempt row exists; distinguish DB read failure from missing row.
   string a_sql = "SELECT attempt_id FROM execution_attempts WHERE attempt_id='" + EscapeSQL(attempt_id) + "';";
   ResetLastError();
   int ah = DatabasePrepare(m_db_handle, a_sql);
   if(ah == INVALID_HANDLE)
     { detail = "ATTEMPT_EXISTENCE_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
   bool attempt_exists = DatabaseRead(ah);
   DatabaseFinalize(ah);
   if(!attempt_exists)
     { detail = "ATTEMPT_ROW_NOT_FOUND"; return IDENTITY_NOT_FOUND; }

   // Collect unique candidate claim_ids from direct pointer and retry events.
   string candidates[];
   int ccount = 0;

   // 3) Direct claim candidates: setup_claims.current_attempt_id
   {
    string dsql = "SELECT claim_id FROM setup_claims WHERE current_attempt_id='" + EscapeSQL(attempt_id) + "';";
    int dh = DatabasePrepare(m_db_handle, dsql);
    if(dh == INVALID_HANDLE) { detail = "DIRECT_CLAIM_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
    while(DatabaseRead(dh))
      {
       string cid = DatabaseColumnString(dh, 0);
       if(cid != "")
         {
          bool seen = false;
          for(int i = 0; i < ccount; i++) if(candidates[i] == cid) { seen = true; break; }
          if(!seen) { ArrayResize(candidates, ccount + 1); candidates[ccount] = cid; ccount++; }
         }
      }
    DatabaseFinalize(dh);
   }

   // 4-5) Historical candidates via retry_approval_events; resolve each by exact claim_id/group/lsk binding.
   AttemptIdentityEventRef event_refs[];
   int ecount = 0;
   {
    string esql = "SELECT claim_id,strategy_group_key,logical_setup_key,prior_attempt_id,new_attempt_id,retry_sequence_before,retry_sequence_after "
                  "FROM retry_approval_events WHERE prior_attempt_id='" + EscapeSQL(attempt_id) + "' OR new_attempt_id='" + EscapeSQL(attempt_id) + "' "
                  "ORDER BY claim_id ASC,retry_sequence_before ASC,action_id ASC;";
    int eh = DatabasePrepare(m_db_handle, esql);
    if(eh == INVALID_HANDLE) { detail = "RETRY_EVENT_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
    while(DatabaseRead(eh))
      {
       AttemptIdentityEventRef er;
       er.claim_id = DatabaseColumnString(eh, 0);
       er.group = DatabaseColumnString(eh, 1);
       er.lsk = DatabaseColumnString(eh, 2);
       er.prior_id = DatabaseColumnString(eh, 3);
       er.new_id = DatabaseColumnString(eh, 4);
       er.seq_before = (int)DatabaseColumnLong2(eh, 5);
       er.seq_after = (int)DatabaseColumnLong2(eh, 6);
       if(er.claim_id == "" || er.group == "" || er.lsk == "" || er.prior_id == "" || er.new_id == "" || er.seq_after != er.seq_before + 1)
         { DatabaseFinalize(eh); detail = "RETRY_EVENT_ROW_INVALID_OR_INCONSISTENT"; return IDENTITY_CONFLICT; }
       // Event must resolve through exact claim_id + group + lsk binding.
       string csql = "SELECT claim_id FROM setup_claims WHERE claim_id='" + EscapeSQL(er.claim_id) + "' AND strategy_group_key='" + EscapeSQL(er.group) + "' AND logical_setup_key='" + EscapeSQL(er.lsk) + "';";
       int ch = DatabasePrepare(m_db_handle, csql);
       if(ch == INVALID_HANDLE) { DatabaseFinalize(eh); detail = "EVENT_CLAIM_BIND_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
       bool bound = DatabaseRead(ch);
       DatabaseFinalize(ch);
       if(!bound) { DatabaseFinalize(eh); detail = "RETRY_EVENT_CLAIM_BINDING_NOT_FOUND claim=" + er.claim_id; return IDENTITY_CONFLICT; }
       int idx = ArraySize(event_refs); ArrayResize(event_refs, idx + 1); event_refs[idx] = er;
       ecount++;
       bool seen = false;
       for(int i = 0; i < ccount; i++) if(candidates[i] == er.claim_id) { seen = true; break; }
       if(!seen) { ArrayResize(candidates, ccount + 1); candidates[ccount] = er.claim_id; ccount++; }
      }
    DatabaseFinalize(eh);
   }

   // 8) Zero / multiple distinct claims
   if(ccount == 0)
     { detail = "UNBOUND_OR_LEGACY_ATTEMPT_NO_AUTHORITATIVE_CLAIM_MAPPING attempt=" + attempt_id; return IDENTITY_NOT_FOUND; }
   if(ccount > 1)
     { detail = "MULTIPLE_DISTINCT_CLAIMS_MATCH_ATTEMPT count=" + IntegerToString(ccount); return IDENTITY_AMBIGUOUS; }
   claim_id = candidates[0];

   // 6) Load authoritative claim identity.
   string claim_state_s = ""; string current_attempt_id = ""; int retry_sequence = -1;
   {
    string csql = "SELECT strategy_group_key,logical_setup_key,canonical_identity,serialization_version,claim_state,current_attempt_id,retry_sequence "
                  "FROM setup_claims WHERE claim_id='" + EscapeSQL(claim_id) + "';";
    int ch = DatabasePrepare(m_db_handle, csql);
    if(ch == INVALID_HANDLE) { detail = "CLAIM_LOAD_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
    if(!DatabaseRead(ch)) { DatabaseFinalize(ch); detail = "CLAIM_ROW_NOT_FOUND claim=" + claim_id; return IDENTITY_CONFLICT; }
    strategy_group_key = DatabaseColumnString(ch, 0);
    logical_setup_key = DatabaseColumnString(ch, 1);
    canonical_identity = DatabaseColumnString(ch, 2);
    serialization_version = (int)DatabaseColumnLong2(ch, 3);
    int claim_state = (int)DatabaseColumnLong2(ch, 4);
    current_attempt_id = DatabaseColumnString(ch, 5);
    retry_sequence = (int)DatabaseColumnLong2(ch, 6);
    DatabaseFinalize(ch);
    if(strategy_group_key == "" || logical_setup_key == "" || canonical_identity == "")
      { detail = "CLAIM_IDENTITY_FIELDS_MISSING claim=" + claim_id; return IDENTITY_CONFLICT; }
   }

   // 9) Direct/current pointer consistency (if direct match exists) is implicit via candidate selection; validate chain below.

   // 10-11) Verify complete retry chain for this claim and that attempt is part of it/current pointer.
   {
    string rsql = "SELECT prior_attempt_id,new_attempt_id,retry_sequence_before,retry_sequence_after "
                  "FROM retry_approval_events WHERE claim_id='" + EscapeSQL(claim_id) + "' "
                  "AND strategy_group_key='" + EscapeSQL(strategy_group_key) + "' AND logical_setup_key='" + EscapeSQL(logical_setup_key) + "' "
                  "ORDER BY retry_sequence_before ASC, action_id ASC;";
    int rh = DatabasePrepare(m_db_handle, rsql);
    if(rh == INVALID_HANDLE) { detail = "CLAIM_CHAIN_PREPARE_FAILED"; return IDENTITY_DB_UNAVAILABLE; }
    string last_new = ""; int last_after = -1; int chain_count = 0;
    while(DatabaseRead(rh))
      {
       string prior = DatabaseColumnString(rh, 0);
       string nnew = DatabaseColumnString(rh, 1);
       int before = (int)DatabaseColumnLong2(rh, 2);
       int after = (int)DatabaseColumnLong2(rh, 3);
       if(prior == "" || nnew == "" || after != before + 1)
         { DatabaseFinalize(rh); detail = "RETRY_CHAIN_ROW_INVALID claim=" + claim_id; return IDENTITY_CONFLICT; }
       if(chain_count == 0)
         { if(before != 0) { DatabaseFinalize(rh); detail = "RETRY_CHAIN_DOES_NOT_START_AT_ZERO claim=" + claim_id; return IDENTITY_CONFLICT; } }
       else
         {
          if(before != last_after || prior != last_new)
            { DatabaseFinalize(rh); detail = "RETRY_CHAIN_DISCONTINUITY claim=" + claim_id; return IDENTITY_CONFLICT; }
         }
       last_new = nnew; last_after = after; chain_count++;
      }
    DatabaseFinalize(rh);
    if(retry_sequence < 0 || retry_sequence != chain_count)
      { detail = "CLAIM_RETRY_SEQUENCE_CHAIN_LENGTH_MISMATCH claim=" + claim_id; return IDENTITY_CONFLICT; }
    if(chain_count > 0)
      {
       if(current_attempt_id == "" || current_attempt_id != last_new)
         { detail = "CLAIM_CURRENT_ATTEMPT_NOT_LATEST_CHAIN_ATTEMPT claim=" + claim_id; return IDENTITY_CONFLICT; }
      }
    else
      {
       // retry_sequence zero: current pointer must be unambiguous attempt for this claim.
       if(current_attempt_id == "")
         { detail = "CLAIM_ZERO_RETRY_CURRENT_ATTEMPT_EMPTY claim=" + claim_id; return IDENTITY_CONFLICT; }
      }
    // Attempt must be the claim's current attempt or appear in validated chain events.
    bool in_chain = (current_attempt_id == attempt_id);
    if(!in_chain)
      {
       for(int i = 0; i < ecount; i++)
         {
          if(event_refs[i].claim_id == claim_id && (event_refs[i].prior_id == attempt_id || event_refs[i].new_id == attempt_id))
            { in_chain = true; break; }
         }
      }
    if(!in_chain)
      { detail = "ATTEMPT_NOT_PART_OF_RESOLVED_CLAIM_CHAIN claim=" + claim_id; return IDENTITY_CONFLICT; }
   }

   detail = "RESOLVED claim=" + claim_id + " group=" + strategy_group_key + " lsk=" + logical_setup_key + " chain_retry_seq=" + IntegerToString(retry_sequence);
   return IDENTITY_RESOLVED;
  }

#endif
