# M1-DEC-D: Retry Handoff Non-Resumption Acceptance — Architecture Alternatives

**Document Type**: Design Analysis & Decision Record  
**Status**: DRAFT — Pending Owner Approval  
**Date**: 2026-11-22  
**Task Classification**: Architecture Design / Decision Support  
**Evidence Level**: STATIC SOURCE TRACE (read-only, no runtime verification)

---

## Executive Summary

This document provides a complete read-only trace of the ACTUAL Retry Handoff behavior in AlgoMultiAssetEA source code and presents three architecture alternatives for M1-DEC-D (Retry Handoff Non-Resumption Acceptance).

**Current Behavior (VERIFIED from source):**
- Retry handoff is TRANSIENT (in-memory only, `g_retry_handoff`)
- Durable approval events persist in `retry_approval_events` table
- After restart: visibility only via `GetInterruptedRetryHandoffs`, NO automatic resubmission
- Fail-closed design: ambiguous states → RECONCILIATION_REQUIRED

**Decision Required**: Choose architecture for retry handoff non-resumption acceptance that balances:
- Safety (no duplicate submissions)
- Operability (recover legitimate retries)
- Auditability (clear state transitions)
- Complexity (implementation burden)

---

## PART 1: SOURCE TRACE (ACTUAL IMPLEMENTATION)

### 1.1 Where is Retry Handoff Created?

**VERIFIED**: Lines 6061-6072 of `Experts/AlgoMultiAssetEA.mq5`

```mql5
// In RetryUIHandleConfirmClick()
if(res == CExecutionLedger::RETRY_APPROVE_COMMITTED || res == CExecutionLedger::RETRY_APPROVE_ALREADY_CONSUMED)
  {
   ZeroMemory(g_retry_handoff); g_retry_handoff.active=true;
   g_retry_handoff.action_id = action_id;
   g_retry_handoff.claim_id = g_retry_review.claim_id;
   g_retry_handoff.strategy_group_key = g_retry_review.strategy_group_key;
   g_retry_handoff.logical_setup_key = g_retry_review.logical_setup_key;
   g_retry_handoff.prior_attempt_id = g_retry_review.prior_attempt_id;
   g_retry_handoff.new_attempt_id = new_attempt.attempt_id;
   g_retry_handoff.expected_retry_sequence = g_retry_review.retry_sequence;
   g_retry_handoff.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   g_retry_handoff.account_server = AccountInfoString(ACCOUNT_SERVER);
   g_retry_handoff.config_fingerprint = g_config_fingerprint;
   g_retry_handoff.created_at = TimeCurrent();
   g_retry_ui_state = E2E6_UI_COMMITTED;
```

**Struct Definition**: Lines 5681-5695

```mql5
struct RetryPendingHandoff
  {
   bool   active;
   string action_id;
   string claim_id;
   string strategy_group_key;
   string logical_setup_key;
   string prior_attempt_id;
   string new_attempt_id;
   int    expected_retry_sequence;
   long   account_login;
   string account_server;
   string config_fingerprint;
   datetime created_at;
  };
```

**Key Characteristics**:
- **TRANSIENT**: In-memory global variable only
- **Crash-fragile**: Lost on terminal restart or EA reinitialization
- **Context-bound**: Includes account/server/config fingerprint for validation
- **No automatic restoration**: Not persisted, not recovered

---

### 1.2 Who Owns Retry Handoff?

**VERIFIED**: Multiple owners with distinct roles:

#### A. Transient Handoff Owner: EA Process
- **Location**: `g_retry_handoff` global variable
- **Lifecycle**: Created on approval confirmation, destroyed on:
  - Successful submission (line 6574: `g_retry_handoff.active=false`)
  - Context mismatch (line 6360)
  - Authority loss (line 6426)
  - Revalidation failure (line 6412)
  - Safe Mode block (line 6525)
- **NOT recoverable after restart**

#### B. Durable Approval Owner: Execution Ledger
- **Location**: `retry_approval_events` table (lines 841-872 of ExecutionLedger.mqh)
- **Lifecycle**: Created atomically in `ApproveAndCreateRetry()` (line 3577-3589)
- **Persistent**: Survives restart, crash, terminal restart
- **Schema**:
  ```sql
  CREATE TABLE retry_approval_events (
      action_id TEXT PRIMARY KEY,
      claim_id TEXT NOT NULL,
      strategy_group_key TEXT NOT NULL,
      logical_setup_key TEXT NOT NULL,
      prior_attempt_id TEXT NOT NULL,
      new_attempt_id TEXT NOT NULL UNIQUE,
      retry_sequence_before INTEGER NOT NULL,
      retry_sequence_after INTEGER NOT NULL,
      approval_timestamp INTEGER NOT NULL,
      action_source TEXT NOT NULL,
      auth_model TEXT NOT NULL,
      account_login TEXT NOT NULL,
      account_server TEXT NOT NULL,
      outcome TEXT NOT NULL,  -- "COMMITTED_NOT_SUBMITTED" or result
      -- ... additional evidence fields
  );
  ```

#### C. Durable Intent Owner: Execution Ledger
- **Location**: `execution_attempts` table
- **State**: `EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED`
- **Created by**: `ApproveAndCreateRetry()` (line 3554: `CreateIntentInTx()`)
- **Persistent**: Survives restart
- **Critical**: This is the NEW attempt (distinct from prior_attempt_id)

---

### 1.3 What Information Persists?

**VERIFIED**: After `ApproveAndCreateRetry()` commits:

| Component | Persists? | Location | Recoverable? |
|-----------|-----------|----------|--------------|
| Approval event | YES | `retry_approval_events` table | YES via `GetInterruptedRetryHandoffs` |
| New attempt intent | YES | `execution_attempts` table | YES via `GetAttempt` |
| Claim advancement | YES | `setup_claims.current_attempt_id` | YES |
| Retry sequence | YES | `setup_claims.retry_sequence` | YES |
| Transient handoff | NO | `g_retry_handoff` (RAM only) | NO |
| UI state | NO | `g_retry_ui_state` (RAM only) | NO |

#### What `GetInterruptedRetryHandoffs` Returns

**VERIFIED**: Lines 3303-3427 of ExecutionLedger.mqh

```mql5
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
```

**Query Logic** (lines 3324-3336):
```sql
SELECT rae.action_id, rae.claim_id, ..., 
       ea.state, ea.submitted_at, ea.broker_order_ticket, ...
FROM retry_approval_events rae
LEFT JOIN execution_attempts ea ON ea.attempt_id=rae.new_attempt_id
LEFT JOIN setup_claims sc ON sc.claim_id=rae.claim_id
WHERE rae.account_login='...' AND rae.account_server='...' 
  AND rae.strategy_group_key='...'
ORDER BY rae.approval_timestamp DESC
```

**Status Classification** (lines 3379-3408):
- `INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED` — new attempt state 1, NOT submitted
- `INTERRUPTED_SUBMISSION_MAY_HAVE_OCCURRED` — ambiguous, state 2
- `INTERRUPTED_RECONCILIATION_REQUIRED` — state 7
- `INTERRUPTED_SUBMITTED_OR_PARTIAL` — states 3/4
- `INTERRUPTED_ALREADY_COMPLETED` — state 5
- `INTERRUPTED_UNRESOLVED_OR_TERMINAL` — other states
- `INTERRUPTED_ATTEMPT_UNREADABLE` — new attempt missing/unreadable

---

### 1.4 What Causes Terminal Failure?

**VERIFIED**: `IsRetryEligibleFinalFailure()` lines 3167-3189 of ExecutionLedger.mqh

#### FINAL_FAILURE Conditions (ALL must be true):

```mql5
bool CExecutionLedger::IsRetryEligibleFinalFailure(const ExecutionAttemptRecord &attempt, string &why_not)
{
   // 1. State must be FINAL_FAILURE
   if(attempt.state != EXEC_STATE_FINAL_FAILURE) return false;
   
   // 2. Failure class must NOT be ambiguous/unknown
   if(fc=="" || fc=="AMBIGUOUS" || fc=="TIMEOUT" || fc=="CONNECTION" || 
      fc=="RECONNECTION_REQUIRED" || fc=="AUTHORIZATION_DENIED" || fc=="UNKNOWN" || 
      fc=="SUBMITTED" || fc=="PARTIAL_FILL" || fc=="ABORTED" || 
      fc=="SUCCESS" || fc=="RECONCILIATION_REQUIRED" ||
      StringFind(fc,"AMBIGUOUS")>=0 || StringFind(fc,"TIMEOUT")>=0 || 
      StringFind(fc,"CONNECTION")>=0) return false;
   
   // 3. Retcode must NOT be ambiguous
   if(attempt.last_retcode == TRADE_RETCODE_TIMEOUT || 
      attempt.last_retcode == TRADE_RETCODE_CONNECTION ||
      attempt.last_retcode == TRADE_RETCODE_INVALID_PRICE || 
      attempt.last_retcode == TRADE_RETCODE_PRICE_CHANGED ||
      attempt.last_retcode == TRADE_RETCODE_PRICE_OFF || 
      attempt.last_retcode == TRADE_RETCODE_REQUOTE) return false;
   
   // 4. No broker evidence
   if(attempt.broker_order_ticket > 0 || attempt.broker_deal_ticket > 0 || 
      attempt.broker_position_ticket > 0) return false;
   
   // 5. No executed volume
   if(attempt.executed_volume > 0.0) return false;
   
   // 6. Failure class must be exactly "FINAL_FAILURE"
   if(fc != "FINAL_FAILURE") return false;
   
   return true;
}
```

**Summary**: Only terminal non-execution with proven no broker contact qualifies.

#### Which Retcodes are FINAL_FAILURE vs AMBIGUOUS?

| Retcode | Classification | Rationale |
|---------|---------------|-----------|
| `TRADE_RETCODE_TIMEOUT` | AMBIGUOUS | Broker may have received request |
| `TRADE_RETCODE_CONNECTION` | AMBIGUOUS | Unknown if request reached broker |
| `TRADE_RETCODE_INVALID_PRICE` | AMBIGUOUS | Price changed, broker state unknown |
| `TRADE_RETCODE_PRICE_CHANGED` | AMBIGUOUS | Price changed, broker state unknown |
| `TRADE_RETCODE_PRICE_OFF` | AMBIGUOUS | Price outside market, state unknown |
| `TRADE_RETCODE_REQUOTE` | AMBIGUOUS | Requote occurred, state unknown |
| Any other with `failure_class="FINAL_FAILURE"` | FINAL_FAILURE | Terminal non-execution proven |

---

### 1.5 How is Ambiguous Outcome Handled?

**VERIFIED**: `MarkReconciliationRequired()` lines 1522-1556 of ExecutionLedger.mqh

```mql5
bool CExecutionLedger::MarkReconciliationRequired(const string attempt_id, const string reason)
{
   // Validates attempt exists
   if(!GetAttempt(attempt_id, rec)) return false;
   
   // Atomic transition to RECONCILIATION_REQUIRED
   DatabaseTransactionBegin(m_db_handle);
   UPDATE execution_attempts SET 
       state = EXEC_STATE_RECONCILIATION_REQUIRED,
       observed_at = now,
       last_reason = reason
   WHERE attempt_id = attempt_id;
   
   LogStateTransition(attempt_id, rec.state, EXEC_STATE_RECONCILIATION_REQUIRED, reason);
   DatabaseTransactionCommit(m_db_handle);
}
```

**When Called**:
1. `RecordResult()` fails to write after broker call (line 3451, 6542)
2. `IsRetryEligibleFinalFailure()` returns false (line 6401, 6417)
3. Revalidation fails (line 6417)
4. Authority validation fails before submit (line 6426)
5. Unresolved attempts block submission (line 6437)
6. Executor returns ambiguous result (line 3632, 6563)

**Reconciliation Process** (lines 2112-2421):
- `ReconcileAttempt()` queries broker history
- Searches for matching orders/deals by symbol+magic+time window
- If found: transitions to COMPLETED or PARTIAL_FILL
- If not found: remains RECONCILIATION_REQUIRED
- **NEVER auto-resubmits**

---

### 1.6 After Restart — What Recovers?

**VERIFIED**: `OnInit()` lines 4935-4760 of AlgoMultiAssetEA.mq5

#### What OnInit Restores:

| Component | Restored? | Method | Result |
|-----------|-----------|--------|--------|
| Authority | YES | Acquire/Validate | Coordinator or Chart Context mode |
| Execution Ledger DB | YES | Initialize | Connection to SQLite |
| Retry candidates | YES | `GetRetryEligibleCandidates` | List for UI review |
| Interrupted handoffs | YES (visibility only) | `GetInterruptedRetryHandoffs` | Read-only status |
| Transient handoff | NO | — | Lost, NOT restored |
| UI state | NO | — | Reset to HIDDEN |
| Duplicate suppression | NO | — | Lost (in-memory only) |

#### Authority Checks (lines 4701-4755):

```mql5
int astate = g_execution_ledger.GetAuthorityState(authority_key);

if(astate == GATEWAY_AUTHORITY_ORPHANED)
  {
   g_coordinator_mode = COORD_MODE_UNAVAILABLE;
   g_coordinator_unavailable_reason = "AUTHORITY_ORPHANED";
   // Explicit recovery required (separate operator action)
  }
else
  {
   // Try to acquire or validate
   if(g_execution_ledger.AcquireAuthority(authority_key, g_owner_instance_token, epoch))
     {
      g_coordinator_mode = COORD_MODE_COORDINATOR;
      g_authority_epoch = epoch;
     }
   else if(astate == GATEWAY_AUTHORITY_CLAIMED)
     {
      g_coordinator_mode = COORD_MODE_CHART_CONTEXT;
      // Another EA owns authority
     }
  }
```

#### Visibility vs Authority

**VERIFIED**: Lines 6115-6159

- **Visibility**: `RetryUILoadInterruptedList()` calls `GetInterruptedRetryHandoffs()`
  - Read-only query
  - No state mutation
  - No broker call
  - No automatic action
  - Status: "READ_ONLY_NO_AUTO_SUBMIT"

- **Authority**: Required for submission
  - `ValidateAuthority()` must pass
  - Coordinator mode required
  - Epoch-based fencing
  - Heartbeat required

---

### 1.7 What Prevents Duplicate Submit?

**VERIFIED**: Multi-layer defense in `ProcessRetryPendingHandoff()` lines 6351-6578

#### Layer 1: Transient Handoff Check (line 6354)
```mql5
if(!g_retry_handoff.active) return;
```
- After restart: `g_retry_handoff.active=false` (default)
- Handoff must be recreated in-memory
- **Effect**: No automatic retry after restart

#### Layer 2: Authority Validation (lines 6362-6364)
```mql5
if(!g_execution_ledger.ValidateAuthority(auth_key, g_owner_instance_token, g_authority_epoch))
  { g_retry_ui_status="HANDOFF_BLOCKED_AUTHORITY"; return; }
```
- Epoch-based fencing
- Stale coordinator denied

#### Layer 3: Durable Approval Read-Back (lines 6368-6372)
```mql5
if(!g_execution_ledger.GetRetryApprovalEventOutcome(g_retry_handoff.action_id, outcome, rb_new) || outcome=="")
  { g_retry_ui_status="HANDOFF_COMMIT_UNKNOWN_BLOCKED"; return; }
if(rb_new != g_retry_handoff.new_attempt_id)
  { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_IDENTITY_MISMATCH"; return; }
```
- Verifies approval event still exists
- Validates new_attempt_id matches

#### Layer 4: Claim State Validation (lines 6375-6378)
```mql5
if(!g_execution_ledger.GetClaimById(..., current_attempt, retry_seq))
  { g_retry_ui_status="HANDOFF_CLAIM_RELOAD_FAILED"; return; }
if(current_attempt != g_retry_handoff.new_attempt_id || retry_seq != expected_retry_sequence + 1)
  { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_CLAIM_ADVANCED_OR_CHANGED"; return; }
```
- Claim must still point to new_attempt
- Retry sequence must match

#### Layer 5: Attempt State Validation (lines 6380-6383)
```mql5
if(!g_execution_ledger.GetAttempt(g_retry_handoff.new_attempt_id, new_att))
  { g_retry_ui_status="HANDOFF_ATTEMPT_RELOAD_FAILED"; return; }
if(new_att.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
  { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_ATTEMPT_NOT_SUBMITTABLE"; return; }
```
- New attempt must be in correct state
- Must NOT have been submitted yet

#### Layer 6: CanSubmit Authorization (lines 6385-6386, 6446-6447)
```mql5
if(!g_execution_ledger.CanSubmit(g_retry_handoff.new_attempt_id, submit_reason))
  { g_retry_ui_status="HANDOFF_CANNOT_SUBMIT"; return; }
```

**CanSubmit Logic** (lines 1322-1369):
```mql5
bool CExecutionLedger::CanSubmit(const string attempt_id, string &reason)
{
   // 1. State must be INTENT_DURABLE_NOT_SUBMITTED
   if(rec.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED) return false;
   
   // 2. submission_allowed must be true (set by MarkSubmissionBound)
   if(!rec.submission_allowed) return false;
   
   // 3. NOT in ambiguous/terminal states
   if(rec.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED ||
      rec.state == EXEC_STATE_RECONCILIATION_REQUIRED ||
      rec.state == EXEC_STATE_SUBMITTED ||
      rec.state == EXEC_STATE_COMPLETED ||
      rec.state == EXEC_STATE_FINAL_FAILURE ||
      rec.state == EXEC_STATE_ABORTED) return false;
   
   return true;
}
```

#### Layer 7: MarkSubmissionBound (lines 6466-6467)
```mql5
if(!g_execution_ledger.MarkSubmissionBound(request.attempt_id, "..."))
  { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_BIND_FAILED"; 
    g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"..."); return; }
```

**MarkSubmissionBound** (lines 1271-1314):
- Sets `submission_allowed=1`
- Idempotent: fails if already bound
- Atomic CAS: `WHERE submission_allowed=0`

#### Layer 8: MarkSubmissionMayHaveOccurred (lines 6470-6471)
```mql5
if(!g_execution_ledger.MarkSubmissionMayHaveOccurred(request.attempt_id, "..."))
  { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_MAY_HAVE_OCCURRED_FAILED"; 
    g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"..."); return; }
```

**MarkSubmissionMayHaveOccurred** (lines 1377-1416):
- Transitions: `INTENT_DURABLE_NOT_SUBMITTED` → `SUBMISSION_MAY_HAVE_OCCURRED`
- Sets `submitted_at` timestamp
- **Immediately before broker call**
- If this fails: broker NOT called, state remains bound

#### Layer 9: Broker Execution (line 6528)
```mql5
bool execution_ok = g_executor.Execute(request, result);
```

**Executor Authorization** (TradeExecutor.mqh lines 47-59):
```mql5
bool HasExecutionAuthority(string &reason) const
{
   if(!m_auth_configured || m_auth_ledger==NULL) return false;
   if(!m_auth_ledger.IsAvailable()) return false;
   if(!m_auth_is_coordinator) return false;
   if(!m_auth_ledger.ValidateAuthority(m_auth_key, m_auth_token, m_auth_epoch)) return false;
   return true;
}
```

---

## PART 2: ARCHITECTURE ALTERNATIVES

### Alternative A — Durable Recovery with Automated Revalidation

#### Architecture
- **Core**: Automatic resumption of approved retry handoffs after restart
- **Recovery**: On OnInit, query `GetInterruptedRetryHandoffs` and automatically recreate transient handoff
- **Revalidation**: Full pre-submit revalidation before broker call
- **Authority**: Coordinator-only, epoch-fenced

#### State Transitions
```
RESTART → GetInterruptedRetryHandoffs() → 
  FOR each INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED:
    Recreate g_retry_handoff (in-memory)
    → ProcessRetryPendingHandoff() (timer path)
    → Full revalidation
    → Submit if all checks pass
    → Mark RECONCILIATION_REQUIRED if any check fails
```

#### Persistence Model
- **Transient handoff**: Reconstructed from durable approval event
- **No schema change**: Uses existing `retry_approval_events` + `execution_attempts`
- **Recovery key**: `action_id` (deterministic, unique)

#### Restart Behavior
1. OnInit queries `GetInterruptedRetryHandoffs` (visibility)
2. **NEW**: Automatically recreates `g_retry_handoff` for each `INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED`
3. Sets timer to process handoffs
4. `ProcessRetryPendingHandoff()` runs full revalidation
5. Submits only if ALL checks pass

#### Authority Requirements
- Coordinator mode required
- Valid epoch (fencing)
- Heartbeat active
- **No change from current**

#### Ledger Requirements
- **No schema change**
- Uses existing tables:
  - `retry_approval_events` (approval record)
  - `execution_attempts` (new attempt intent)
  - `setup_claims` (claim advancement)

#### Attempt Identity
- **Distinct**: new_attempt_id != prior_attempt_id
- **Durable**: attempt_id from ledger
- **Magic**: Per-attempt magic allocated (F-005.2)

#### Retry Eligibility
- **Unchanged**: `IsRetryEligibleFinalFailure()` must pass
- **Revalidation**: Full fresh plan + risk + admission check

#### Broker Reconciliation
- **Unchanged**: Existing `ReconcileAttempt()` logic
- **Ambiguous outcomes**: → RECONCILIATION_REQUIRED

#### Risk Revalidation
- **Mandatory**: Fresh plan from HybridEngine
- **Mandatory**: Risk calculation from RiskEngine
- **Mandatory**: Portfolio admission from PortfolioRisk
- **Mandatory**: Final admission revalidation immediately before submit

#### Duplicate Prevention
- **Unchanged**: All 9 layers remain
- **Enhanced**: Automatic recovery adds one more check (approval event existence)

#### Failure Modes
| Failure | Handled? | Result |
|---------|----------|--------|
| Approval event missing | YES | Handoff not recreated |
| New attempt state wrong | YES | Handoff not recreated |
| Revalidation fails | YES | Mark RECONCILIATION_REQUIRED |
| Authority lost | YES | Handoff blocked |
| Broker ambiguous | YES | Mark RECONCILIATION_REQUIRED |
| Duplicate submission | YES | CanSubmit blocks |

#### Security Risks
- **Low**: Automatic recovery is deterministic and bounded
- **Low**: Full revalidation prevents stale approvals
- **Medium**: Increased automation may mask underlying issues

#### Complexity
- **Medium**: Requires automatic handoff recreation logic in OnInit
- **Medium**: Additional logging for recovery events
- **Low**: Reuses existing revalidation path

#### Test Cases
1. Restart after approval, before submission → auto-submit after revalidation
2. Restart after approval, revalidation fails → RECONCILIATION_REQUIRED
3. Restart after submission → no duplicate
4. Restart after ambiguous outcome → no duplicate
5. Multiple restarts → idempotent
6. Authority lost during recovery → blocked

#### Acceptance Criteria
- [ ] OnInit automatically recreates handoff for INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED
- [ ] Full revalidation before submit
- [ ] No duplicate submissions after restart
- [ ] Audit log for recovery events
- [ ] Fail-closed on any validation failure

---

### Alternative B — Durable Handoff with Explicit Authorization

#### Architecture
- **Core**: Persist handoff state durably, require explicit operator authorization to resume
- **Recovery**: OnInit loads interrupted handoffs into READ-ONLY view
- **Authorization**: Separate operator action required to resume each handoff
- **Revalidation**: Full pre-submit revalidation before broker call

#### State Transitions
```
RESTART → GetInterruptedRetryHandoffs() → 
  Display in UI (READ-ONLY)
  → Operator reviews each handoff
  → Operator explicitly authorizes (NEW ACTION)
  → Recreate transient handoff
  → ProcessRetryPendingHandoff()
  → Full revalidation
  → Submit or Mark RECONCILIATION_REQUIRED
```

#### Persistence Model
- **Transient handoff**: Reconstructed only after explicit authorization
- **NEW TABLE**: `retry_handoff_authorization`
  ```sql
  CREATE TABLE retry_handoff_authorization (
      authorization_id TEXT PRIMARY KEY,
      action_id TEXT NOT NULL,
      operator_token TEXT NOT NULL,
      authorization_timestamp INTEGER NOT NULL,
      authorization_context TEXT NOT NULL,
      UNIQUE(action_id)
  );
  ```
- **Audit trail**: Every authorization recorded

#### Restart Behavior
1. OnInit queries `GetInterruptedRetryHandoffs` (visibility)
2. **NEW**: Display interrupted handoffs in dashboard
3. **NEW**: Operator reviews each handoff
4. **NEW**: Operator explicitly authorizes via chart object click
5. **NEW**: Authorization recorded in `retry_handoff_authorization`
6. Transient handoff recreated
7. `ProcessRetryPendingHandoff()` runs

#### Authority Requirements
- Coordinator mode required
- Valid epoch (fencing)
- **NEW**: Operator token required for authorization
- **NEW**: Authorization event logged

#### Ledger Requirements
- **NEW TABLE**: `retry_handoff_authorization`
- **Schema migration**: v5 → v6 (additive, tx-safe)
- **Unchanged**: Existing tables remain

#### Attempt Identity
- **Unchanged**: Distinct, durable, magic-allocated

#### Retry Eligibility
- **Unchanged**: `IsRetryEligibleFinalFailure()` must pass
- **NEW**: Authorization must exist

#### Broker Reconciliation
- **Unchanged**: Existing logic

#### Risk Revalidation
- **Unchanged**: Full revalidation mandatory

#### Duplicate Prevention
- **Unchanged**: All 9 layers
- **NEW**: Authorization check (layer 10)
- **NEW**: Authorization single-use (UNIQUE constraint)

#### Failure Modes
| Failure | Handled? | Result |
|---------|----------|--------|
| No authorization | YES | Handoff not resumed |
| Authorization expired | YES | Handoff not resumed |
| Wrong operator | YES | Authorization denied |
| Revalidation fails | YES | Mark RECONCILIATION_REQUIRED |
| Duplicate authorization | YES | UNIQUE constraint blocks |

#### Security Risks
- **Low**: Explicit authorization required
- **Low**: Operator accountability
- **Medium**: Additional operator burden

#### Complexity
- **Medium**: New table + migration
- **Medium**: New UI flow for authorization
- **Low**: Reuses existing revalidation

#### Test Cases
1. Restart → handoff visible but not active
2. Operator authorizes → handoff active
3. Operator does not authorize → handoff remains inactive
4. Duplicate authorization → blocked
5. Wrong operator → blocked
6. Authorization + revalidation failure → RECONCILIATION_REQUIRED

#### Acceptance Criteria
- [ ] OnInit loads interrupted handoffs into READ-ONLY view
- [ ] Explicit operator authorization required to resume
- [ ] Authorization recorded durably
- [ ] Full revalidation before submit
- [ ] No duplicate authorizations

---

### Alternative C — Reconcile-and-Recreate

#### Architecture
- **Core**: After restart, ALL interrupted handoffs are marked RECONCILIATION_REQUIRED
- **Recovery**: No automatic resumption; operator must resolve each handoff manually
- **Recreation**: Operator can approve a NEW retry (fresh approval event)
- **Revalidation**: Full pre-submit revalidation

#### State Transitions
```
RESTART → GetInterruptedRetryHandoffs() → 
  FOR each interrupted handoff:
    Mark new_attempt as RECONCILIATION_REQUIRED (if not already terminal)
  → Operator reviews RECONCILIATION_REQUIRED attempts
  → Operator manually resolves (close, modify, or abandon)
  → Operator can create NEW retry approval (fresh action_id)
  → ProcessRetryPendingHandoff() (new handoff)
  → Full revalidation
  → Submit
```

#### Persistence Model
- **Transient handoff**: NOT recreated; marked RECONCILIATION_REQUIRED instead
- **No schema change**: Uses existing tables
- **Recovery**: Manual operator resolution

#### Restart Behavior
1. OnInit queries `GetInterruptedRetryHandoffs`
2. **NEW**: For each INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED:
   - Call `MarkReconciliationRequired(new_attempt_id, "RESTART_INTERRUPTION")`
3. Handoff remains inactive
4. Operator must manually resolve or create new retry

#### Authority Requirements
- **Unchanged**: Coordinator, epoch, heartbeat

#### Ledger Requirements
- **No schema change**
- Uses existing `MarkReconciliationRequired()`

#### Attempt Identity
- **Unchanged**: Distinct, durable

#### Retry Eligibility
- **Unchanged**: `IsRetryEligibleFinalFailure()`
- **NEW**: Prior attempt must NOT be RECONCILIATION_REQUIRED

#### Broker Reconciliation
- **Enhanced**: All interrupted handoffs automatically enter reconciliation
- **Manual**: Operator must resolve each

#### Risk Revalidation
- **Unchanged**: Full revalidation

#### Duplicate Prevention
- **Unchanged**: All 9 layers
- **Enhanced**: RECONCILIATION_REQUIRED state blocks submission

#### Failure Modes
| Failure | Handled? | Result |
|---------|----------|--------|
| Interrupted handoff | YES | Marked RECONCILIATION_REQUIRED |
| Operator ignores | YES | Remains blocked |
| Operator resolves incorrectly | NO | Risk of incorrect state |
| New retry approval | YES | Fresh approval required |

#### Security Risks
- **Low**: Fail-closed by default
- **Medium**: Increased operator burden
- **Medium**: Risk of operator error during manual resolution

#### Complexity
- **Low**: Minimal new code (just call MarkReconciliationRequired)
- **Low**: Reuses existing resolution paths
- **Medium**: Operator training required

#### Test Cases
1. Restart → interrupted handoff marked RECONCILIATION_REQUIRED
2. Operator resolves → handoff cleared
3. Operator creates new retry → fresh approval
4. Operator ignores → remains blocked
5. Multiple restarts → idempotent (already RECONCILIATION_REQUIRED)

#### Acceptance Criteria
- [ ] OnInit marks all interrupted handoffs as RECONCILIATION_REQUIRED
- [ ] No automatic resumption
- [ ] Operator must manually resolve or recreate
- [ ] Full revalidation for new retries
- [ ] No duplicate submissions

---

## PART 3: COMPARISON MATRIX

### 3.1 Advantages/Disadvantages

| Criterion | Alt A (Auto-Recovery) | Alt B (Explicit Auth) | Alt C (Reconcile-Recreate) |
|-----------|----------------------|----------------------|---------------------------|
| **Safety** | ✓ High (full revalidation) | ✓ High (explicit auth) | ✓ Highest (fail-closed) |
| **Operability** | ✓ High (automatic) | ✗ Medium (manual auth) | ✗ Low (manual resolve) |
| **Auditability** | ✓ High (recovery log) | ✓ Highest (auth log) | ✓ Medium (reconciliation log) |
| **Complexity** | ✗ Medium | ✗ Medium-High | ✓ Low |
| **Duplicate Risk** | ✓ Lowest (auto-check) | ✓ Low | ✓ Low |
| **Operator Burden** | ✓ Lowest | ✗ Medium | ✗ Highest |
| **Recovery Speed** | ✓ Fastest | ✗ Medium | ✗ Slowest |

### 3.2 Preservation of Approved Decisions

| Decision | Alt A | Alt B | Alt C | Notes |
|----------|-------|-------|-------|-------|
| **D-006** (Durable Intent) | ✓ | ✓ | ✓ | All preserve |
| **D-007** (Attempt Identity) | ✓ | ✓ | ✓ | All preserve |
| **D-008** (Ledger Schema) | ✓ | ✗ (v6) | ✓ | B requires migration |
| **D-009** (Fail-Closed Submit) | ✓ | ✓ | ✓ | All preserve |
| **D-010** (Recovery Fail-Safe) | ✓ | ✓ | ✓ | All preserve |
| **D-011** (Execution Ledger) | ✓ | ✓ | ✓ | All preserve |
| **D-012** (Setup Claim) | ✓ | ✓ | ✓ | All preserve |
| **D-014** (Authority) | ✓ | ✓ | ✓ | All preserve |
| **D-015** (Risk Revalidation) | ✓ | ✓ | ✓ | All preserve |
| **D-016** (Reconciliation) | ✓ | ✓ | ✓ | All preserve |
| **D-017** (No Auto-Close) | ✓ | ✓ | ✓ | All preserve |
| **D-018** (Conflict Scope) | ✓ | ✓ | ✓ | All preserve |

### 3.3 Match to Actual Source Behavior

| Behavior | Current Source | Alt A | Alt B | Alt C |
|----------|---------------|-------|-------|-------|
| Transient handoff | YES | Recreated | Recreated with auth | NOT recreated |
| Durable approval | YES | Used | Used | Used |
| Visibility after restart | YES | Enhanced | Enhanced | Enhanced |
| Auto-resubmit | NO | **YES** | No (auth required) | No |
| Manual resolution | YES | Optional | Required | Required |

**VERIFIED**: Current source does NOT auto-resubmit after restart (lines 6147-6158 of AlgoMultiAssetEA.mq5).

### 3.4 Risk Assessment

| Risk | Alt A | Alt B | Alt C |
|------|-------|-------|-------|
| Duplicate submission | Low | Low | Lowest |
| Stale approval used | Low (revalidation) | Low (revalidation) | Low (revalidation) |
| Authority race | Low (epoch) | Low (epoch) | Low (epoch) |
| Broker ambiguity | Low (reconciliation) | Low (reconciliation) | Low (reconciliation) |
| Operator error | Lowest | Medium | Highest |
| System complexity | Medium | Highest | Lowest |
| Implementation risk | Medium | High | Low |

---

## PART 4: HUMAN DECISION OUTPUT

### 4.1 Recommended Alternative

**RECOMMENDATION: Alternative C — Reconcile-and-Recreate**

**Rationale**:
1. **Safest**: Fail-closed by default; all interrupted handoffs marked RECONCILIATION_REQUIRED
2. **Simplest**: Minimal new code; reuses existing `MarkReconciliationRequired()`
3. **No schema change**: No migration required
4. **Preserves all decisions**: D-006 through D-018 intact
5. **Matches current behavior**: Extends existing fail-closed philosophy
6. **Lowest implementation risk**: No new tables, no new UI flows
7. **Clear audit trail**: All interruptions logged as RECONCILIATION_REQUIRED

**Trade-offs**:
- **Higher operator burden**: Manual resolution required
- **Slower recovery**: No automatic resumption
- **Requires training**: Operators must understand reconciliation workflow

**Mitigation**:
- Clear UI status: "INTERRUPTED_RECONCILIATION_REQUIRED"
- Operator runbook: Step-by-step resolution guide
- Audit log: Track all manual resolutions

### 4.2 Remaining Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Operator ignores RECONCILIATION_REQUIRED | Medium | Dashboard alert; blocking unresolved checks |
| Operator resolves incorrectly | Medium | Training; audit log; reversible actions |
| Increased support burden | Low | Documentation; runbook |
| Slower recovery time | Low | Acceptable for safety |

### 4.3 Contracts That Don't Change

**UNCHANGED**:
- D-006: Durable intent (SQLite)
- D-007: Attempt identity (distinct attempt_id)
- D-008: Ledger schema (v5, no migration)
- D-009: Fail-closed submission
- D-010: Recovery fail-safe
- D-011: Execution ledger authority
- D-012: Setup claim lifecycle
- D-014: Authority fencing (epoch)
- D-015: Risk revalidation
- D-016: Reconciliation required for ambiguous
- D-017: No auto-close for conflict
- D-018: Conflict block scope

**NEW BEHAVIOR**:
- On OnInit: Mark all INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED as RECONCILIATION_REQUIRED
- No automatic retry resumption
- Operator must manually resolve or create new retry

### 4.4 Exact Decision Record Text

```markdown
## M1-DEC-D: Retry Handoff Non-Resumption Acceptance

**Status**: PROPOSAL / PENDING APPROVAL  
**Date**: 2026-11-22  
**Decision Owner**: [Pending]

### Context
After restart, approved retry handoffs (INTENT_DURABLE_NOT_SUBMITTED) remain in a 
durable but non-submitted state. Current implementation provides visibility only; 
no automatic resubmission occurs.

### Decision
**Alternative C — Reconcile-and-Recreate**

On system initialization (OnInit):
1. Query `GetInterruptedRetryHandoffs()` for all interrupted handoffs
2. For each `INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED`:
   - Call `MarkReconciliationRequired(new_attempt_id, "RESTART_INTERRUPTION")`
3. Display in dashboard as RECONCILIATION_REQUIRED
4. No automatic resubmission

Operator must:
- Review each RECONCILIATION_REQUIRED attempt
- Manually resolve (close, modify, or abandon)
- OR create fresh retry approval (new action_id, new approval event)

### Rationale
- **Safety**: Fail-closed by default; no automatic broker submission
- **Simplicity**: Minimal code change; reuses existing MarkReconciliationRequired()
- **No migration**: No schema change required
- **Auditability**: All interruptions logged
- **Preserves decisions**: D-006 through D-018 intact

### Consequences
**Positive**:
- Safest option (no duplicate submissions)
- Simplest implementation
- Clear audit trail

**Negative**:
- Higher operator burden
- Slower recovery (manual resolution required)
- Requires operator training

### Implementation
** OnInit() enhancement:
```mql5
// After GetInterruptedRetryHandoffs() call
for(int i=0; i<g_retry_interrupted_count; i++)
  {
   if(g_retry_interrupted[i].status_code == "INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED")
     {
      g_execution_ledger.MarkReconciliationRequired(
          g_retry_interrupted[i].new_attempt_id,
          "RESTART_INTERRUPTION: Interrupted retry handoff marked for reconciliation");
     }
  }
```

### Verification
- Restart after approval → new attempt marked RECONCILIATION_REQUIRED
- No automatic submission
- Operator can resolve or create new retry
- Audit log records all actions

### References
- Source trace: This document, Part 1
- ExecutionLedger.mqh: MarkReconciliationRequired() lines 1522-1556
- AlgoMultiAssetEA.mq5: GetInterruptedRetryHandoffs() lines 6115-6159
```

---

## APPENDIX A: Evidence Summary

**VERIFIED** (from source code):
- Retry handoff is transient (in-memory only)
- Approval events persist in `retry_approval_events` table
- New attempt intent persists in `execution_attempts` table
- No automatic resubmission after restart (current behavior)
- Fail-closed design throughout
- All decisions D-006 through D-018 preserved

**NOT VERIFIED** (requires runtime testing):
- Actual restart behavior
- Broker reconciliation accuracy
- Operator workflow effectiveness
- Performance impact

**Evidence Level**: STATIC SOURCE TRACE (read-only)

---

## APPENDIX B: Implementation Checklist

### Phase 1: OnInit Enhancement
- [ ] Add loop after `GetInterruptedRetryHandoffs()`
- [ ] Call `MarkReconciliationRequired()` for each INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED
- [ ] Log each action
- [ ] Update dashboard status

### Phase 2: Operator Runbook
- [ ] Document RECONCILIATION_REQUIRED workflow
- [ ] Screenshots of dashboard status
- [ ] Step-by-step resolution guide
- [ ] Examples of common scenarios

### Phase 3: Testing
- [ ] Restart test: approval → restart → RECONCILIATION_REQUIRED
- [ ] Restart test: submission → restart → no duplicate
- [ ] Restart test: ambiguous → restart → RECONCILIATION_REQUIRED
- [ ] Operator resolution test
- [ ] New retry approval test

### Phase 4: Deployment
- [ ] Code review
- [ ] Compile verification
- [ ] Documentation review
- [ ] Operator training
- [ ] Production deployment

---

**END OF DOCUMENT**