# Authority Recovery Acceptance Tests

## Purpose
Document isolated recovery tests for the Authority/ORPHANED recovery functionality (Workstream 1).

## Test Infrastructure Status
**MQL5 Native SQLite**: ✅ AVAILABLE - Uses MQL5 `DatabaseOpen`, `DatabaseExecute`, `DatabasePrepare`, `DatabaseRead`, `DatabaseColumnInteger`, `DatabaseColumnLong`, `DatabaseColumnText`, `DatabaseFinalize`, `DatabaseTransactionBegin`, `DatabaseTransactionCommit`, `DatabaseTransactionRollback`, `DatabaseClose` - no external dependencies required.

**Test Script**: `Scripts/TestAuthorityRecovery.mq5` - Compiles 0 errors, 0 warnings. **Program type: Script** (entry point: `OnStart()`). Run as a Script on a chart in MT5 terminal. Results printed to Expert log.

## Test Specification

### Test 1: ExpireStaleAuthority - Normal Expiry
**Objective**: Verify that a stale authority lease transitions to ORPHANED state
**Preconditions**:
- SQLite database with `account_authority` table (schema v5)
- Record exists with `claim_state = CLAIMED (1)`, `heartbeat_at` older than lease_seconds
- `owner_instance_token` set to valid token
**Inputs**:
- `authority_key`: "test-server_12345"
- `lease_seconds`: 30
- `owner_token`: "" (empty - allow expiry)
**Expected**:
- Returns `true` (expired)
- `claim_state` updated to `ORPHANED (3)`
- `owner_instance_token` cleared to empty string
- `released_at` set to current time
- `last_reason` = "HEARTBEAT_EXPIRED"
- `reason` output = "AUTHORITY_EXPIRED_TO_ORPHANED"

### Test 2: ExpireStaleAuthority - Self-Protection (Owner Token Provided)
**Objective**: Verify coordinator cannot expire its own lease
**Preconditions**:
- Record exists with `claim_state = CLAIMED`, `heartbeat_at` older than lease_seconds
- `owner_instance_token` = "coordinator-token-123"
**Inputs**:
- `authority_key`: "test-server_12345"
- `lease_seconds`: 30
- `owner_token`: "coordinator-token-123"
**Expected**:
- Returns `false` (not expired - protected)
- `claim_state` remains `CLAIMED`
- `owner_instance_token` unchanged
- `reason` output = "" (empty)

### Test 3: ExpireStaleAuthority - No Heartbeat Set
**Objective**: Verify authority without heartbeat is not expired
**Preconditions**:
- Record exists with `claim_state = CLAIMED`, `heartbeat_at = 0`
**Inputs**:
- `authority_key`: "test-server_12345"
- `lease_seconds`: 30
- `owner_token`: ""
**Expected**:
- Returns `false`
- `claim_state` remains `CLAIMED`
- `reason` output = ""

### Test 4: ExpireStaleAuthority - Ledger Unavailable
**Objective**: Verify graceful handling when database unavailable
**Preconditions**:
- `m_db_available = false` or `m_db_handle = INVALID_HANDLE`
**Inputs**:
- Any valid parameters
**Expected**:
- Returns `false`
- `reason` output = "LEDGER_UNAVAILABLE"

### Test 5: ExpireStaleAuthority - Invalid Parameters
**Objective**: Verify parameter validation
**Inputs**:
- `authority_key`: "" (empty)
- `lease_seconds`: 30
**Expected**:
- Returns `false`
- `reason` output = "INVALID_PARAMS"

### Test 6: RecoverAuthorityFromOrphaned - Authorization Unavailable (Fail-Closed)
**Objective**: Verify recovery is rejected when no trusted operator-authentication provider exists
**Preconditions**:
- Record exists with `claim_state = ORPHANED (3)`, `authority_epoch = 5`, `owner_instance_token = ""`
- `HashOperatorToken()` returns "UNVERIFIED" (no PKI/HMAC/IdP implemented)
**Inputs**:
- `authority_key`: "test-server_12345"
- `operator_token`: "operator-recovery-token-789"
- `current_epoch`: 5
- `new_owner_token`: "new-coordinator-token-abc"
**Expected**:
- Returns `false` (recovery rejected - fail-closed)
- `out_new_epoch` = 0
- `claim_state` remains `ORPHANED (3)` (unchanged)
- `owner_instance_token` remains `""` (unchanged)
- `authority_epoch` remains `5` (unchanged)
- No audit trail entry created (`last_reason` remains `""`)
- No database transaction attempted

### Test 7: RecoverAuthorityFromOrphaned - Epoch Mismatch (Fencing)
**Objective**: Verify epoch fencing prevents stale recovery
**Preconditions**:
- Record exists with `claim_state = ORPHANED`, `authority_epoch = 5`
**Inputs**:
- `authority_key`: "test-server_12345"
- `operator_token`: "operator-recovery-token-789"
- `current_epoch`: 4 (stale epoch)
- `new_owner_token`: "new-coordinator-token-abc"
**Expected**:
- Returns `false`
- No state changes (claim_state remains ORPHANED, epoch remains 5)

### Test 8: RecoverAuthorityFromOrphaned - Not ORPHANED State
**Objective**: Verify recovery only works from ORPHANED state
**Preconditions**:
- Record exists with `claim_state = CLAIMED (1)`, `authority_epoch = 5`
**Inputs**:
- `authority_key`: "test-server_12345"
- `operator_token`: "operator-recovery-token-789"
- `current_epoch`: 5
- `new_owner_token`: "new-coordinator-token-abc"
**Expected**:
- Returns `false`
- No state changes

### Test 9: RecoverAuthorityFromOrphaned - Empty Parameters
**Objective**: Verify parameter validation
**Inputs**:
- Various combinations with empty strings or `current_epoch <= 0`
**Expected**:
- Returns `false` for all invalid combinations

### Test 10: RecoverAuthorityFromOrphaned - Ledger Unavailable
**Objective**: Verify graceful handling when database unavailable
**Preconditions**:
- `m_db_available = false` or `m_db_handle = INVALID_HANDLE`
**Inputs**:
- Any valid parameters
**Expected**:
- Returns `false`

### Test 11: RecoverAuthorityFromOrphaned - Authorization Unavailable Audit Trail
**Objective**: Verify NO audit trail entry is created when recovery is rejected due to UNVERIFIED authorization
**Preconditions**: Same as Test 6
**Verification**:
- Recovery returns `false`
- Authority state remains `ORPHANED`
- Epoch unchanged
- Owner token unchanged
- `last_reason` remains empty (no transaction occurred)

### Test 12: ExpireStaleAuthority - owner_instance_token Cleared
**Objective**: Verify `owner_instance_token` is cleared on ORPHANED transition (fix for CR-02)
**Preconditions**: Same as Test 1
**Verification**:
- Query `owner_instance_token` column after expiry
- Confirm it is empty string ""

## ERL Retry Behavior Tests (Static Verification)

### Test ERL-1: Retry State Init
**Objective**: Verify retry state initializes correctly on first call
**Verification**: Static code inspection - `s_erl_retry_attempt` starts at 0, initializes to 1

### Test ERL-2: Partial Reads Tracking
**Objective**: Verify per-field read tracking across calls
**Verification**: Static code inspection - `s_erl_reads_ok[6]` and `s_erl_cached_vals[6]` track per-field success

### Test ERL-3: read_complete=false During Retries
**Objective**: Verify `read_complete=false` with `GV_READ_PENDING` during retry phase
**Verification**: Static code inspection - returns incomplete state while `s_erl_retry_attempt < ERL_MAX_READ_RETRIES`

### Test ERL-4: Fail-Closed After Max Retries
**Objective**: Verify fail-closed after `ERL_MAX_READ_RETRIES` exhausted
**Verification**: Static code inspection - returns `read_complete=false, valid=false, reason=GV_READ_FAILED`

### Test ERL-5: Success Resets Retry State
**Objective**: Verify retry state resets on successful read
**Verification**: Static code inspection - `s_erl_retry_attempt=0` after all 6 fields read

### Test ERL-6: Disabled Feature Bypasses Retry
**Objective**: Verify disabled feature returns immediately without retry logic
**Verification**: Static code inspection - early return with `valid=true, read_complete=true`

### Test ERL-7: GV Not Found Bypasses Retry
**Objective**: Verify missing GV returns immediately with fail-closed/permissive state
**Verification**: Static code inspection - early return with `valid=true, read_complete=true`

### Test ERL-8: No Blocking Sleep
**Objective**: Verify zero `Sleep()` calls in any code path
**Verification**: Static code inspection - all retries spread across event calls via static state

## Test Execution

### Compile Test Script
```powershell
# Compile TestAuthorityRecovery.mq5
& "C:\Program Files\AMarkets - MetaTrader 5\metaeditor64.exe" /compile:"Scripts\TestAuthorityRecovery.mq5" /inc:"." /inc:"C:\Program Files\AMarkets - MetaTrader 5\MQL5"
```

### Run Tests
1. Open MetaTrader 5 terminal
2. Open any chart
3. Drag `TestAuthorityRecovery` Script onto the chart
4. Configure inputs: `InpRunAllTests=true`, `InpTestCase=0`
5. Click OK to run
6. Check Expert log for results: "ALL TESTS PASSED" or failure details

**Note**: This is a Script (entry point: `OnStart()`), not an Expert Advisor. It does NOT run in Strategy Tester. It runs directly on a chart in the live terminal.

### Test Parameters
- `InpTestDatabaseName`: "Test_AuthorityRecovery.sqlite" (isolated test database)
- `InpRunAllTests`: true (run all 20 tests: 12 authority + 8 ERL)
- `InpTestCase`: 0 (run all) or 1-20 (specific test)

## Acceptance Gates (Workstream 1)

| Gate | Status | Notes |
|------|--------|-------|
| 1.1 `AcquireAuthority()` rejects ORPHANED | ✅ IMPLEMENTED | Modified in `ExecutionLedger.mqh` |
| 1.2 `RecoverAuthorityFromOrphaned()` with epoch fencing | ✅ IMPLEMENTED | Added in `ExecutionLedger.mqh` |
| 1.3 `ReleaseAuthority()` return-value check in `OnDeinit()` | ✅ IMPLEMENTED | Added in `AlgoMultiAssetEA.mq5` |
| 1.4 `Scripts/RecoverAuthority.mq5` operator script | ✅ IMPLEMENTED | Script compiles 0E/0W |
| 1.5 `ExpireStaleAuthority()` clears `owner_instance_token` | ✅ IMPLEMENTED | Fixed in `ExecutionLedger.mqh` line 4121 |
| 1.6 `RecoverAuthorityFromOrphaned()` records `operator_token_hash=UNVERIFIED` | ✅ IMPLEMENTED | Fixed in `ExecutionLedger.mqh` - no token-derived data |
| 1.7 `InpAuthorityLeaseSeconds` input parameter | ✅ IMPLEMENTED | Added to `AlgoMultiAssetEA.mq5` |
| 1.8 Compile: 0 errors, 0 warnings | ✅ VERIFIED | EA, Recovery Script, Test Script all compile clean |
| 1.9 ValidationHarness: 6/6 checks, 22/22 invariants | ✅ VERIFIED | All critical invariants pass |
| 1.10 Isolated recovery tests (Tests 1-12) | ✅ IMPLEMENTED | `Scripts/TestAuthorityRecovery.mq5` using native MQL5 SQLite |
| 1.11 ERL retry behavior tests (Tests ERL-1 to ERL-8) | ✅ IMPLEMENTED | Static verification in `Scripts/TestAuthorityRecovery.mq5` |
| 1.12 Authority recovery documentation | ✅ IMPLEMENTED | `docs/AUTHORITY_OPERATOR_RECOVERY.md` |
| 1.13 Acceptance report | ✅ COMPLETED | `docs/AUTHORITY_RECOVERY_ACCEPTANCE_REPORT.md` |

## Security Notes

### Authorization Recorded as UNVERIFIED (OPEN/P1)
The `HashOperatorToken()` function in `ExecutionLedger.mqh` now returns `"UNVERIFIED"`:
- **No token-derived data persisted** in audit trail
- **No FNV-1a, SHA-256, or any hash of token** stored
- **Explicit marker** for authorization trust model gap (OPEN/P1)
- Example: `operator-recovery-token-789` → `UNVERIFIED` (not `a1b2c3d4`, not `LEN=28|F=o|L=9`)

### Fail-Closed Recovery Gate (IMPLEMENTED)
**Status**: ✅ IMPLEMENTED in `ExecutionLedger.mqh` lines 4228-4234
**Behavior**: `RecoverAuthorityFromOrphaned()` now checks `HashOperatorToken()` result BEFORE any state mutation. When it returns "UNVERIFIED" (no trusted provider), the function:
1. Returns `false` immediately
2. Does NOT begin a database transaction
3. Does NOT mutate authority state, epoch, or owner token
4. Leaves `last_reason` unchanged
**Verification**: Test 6 and Test 11 validate this fail-closed behavior.

### Authorization Trust Model Gap (OPEN/P1)
**Status**: NOT IMPLEMENTED - Known security gap
**Location**: `Scripts/RecoverAuthority.mq5` and `ExecutionLedger.mqh`
**Issue**: The recovery script accepts `operator_token` input but does NOT validate it against a trusted authorization source (signed tokens, certificate validation, or external identity provider).
**Current Security Boundary**: Epoch fencing only (`current_epoch` must match ledger)
**Risk**: Operator with script access + ledger epoch value can recover authority without cryptographic identity proof.
**Required Decision**: Architectural approval needed for:
- Option A: HMAC-based operator tokens with shared secret
- Option B: X.509 certificate validation
- Option C: External identity provider (OAuth/OIDC)
- Option D: Explicit risk acceptance (documented, signed off)

**Preferred Architecture**: PKI signed, one-time authorization tokens with external verification component for MQL5 cryptographic capabilities.

**Workstream 1 Acceptance**: **NOT ACCEPTED** until trust model implemented or risk explicitly accepted.

## ERL Retry Behavior (Workstream 1 Security Fix)

### Non-Blocking Bounded Retry Implementation
- **Problem**: Original `ReadExtRiskLockState()` used `Sleep(100ms)` × 3 retries = up to 300ms blocking in OnTick/OnTimer
- **Solution**: Non-blocking state machine spreads retries across event calls
- **Mechanism**: Static variables track retry state (`s_erl_retry_attempt`, `s_erl_reads_ok[6]`, `s_erl_cached_vals[6]`)
- **Behavior**: 
  - First call: initializes retry state, attempts all 6 GV reads
  - Subsequent calls: retries only failed reads, returns `read_complete=false` with `GV_READ_PENDING`
  - After 3 attempts: returns fail-closed `read_complete=false, valid=false, GV_READ_FAILED`
  - Success: returns complete state, resets retry counter
- **Call Paths**: OnTick → RefreshTradingState, OnTimer → RefreshTradingState, ProcessHybridDecision → ReadExtRiskLockStateFresh
- **Fail-Closed**: PortfolioRisk.CheckExternalRiskLock treats `read_complete=false` as blocking (EXTERNAL_RISK_LOCK_INCOMPLETE_READ)

## Test Classification Summary

| Category | Count | Type | Execution Status |
|----------|-------|------|------------------|
| Authority Recovery | 12 | Functional Script tests (native MQL5 SQLite) | NOT RUN (requires MT5 terminal) |
| ERL Retry Behavior | 8 | Static verification (code inspection) | STATIC VERIFICATION ONLY |
| News State Machine | 10 | Test specifications only (no executable code) | NOT IMPLEMENTED |

**Total**: 12 executable + 8 static + 10 specified = 30 test cases documented

## Next Steps
1. ✅ Implemented fail-closed recovery gate in `RecoverAuthorityFromOrphaned()`
2. ✅ Corrected Test 6 and Test 11 to verify fail-closed rejection
3. ✅ Implemented isolated test script using native MQL5 SQLite (12 authority + 8 ERL tests)
4. ⚠️ Execute tests on MT5 terminal (requires terminal authorization)
5. ⚠️ Address authorization trust model gap (OPEN/P1) - requires architectural decision
6. Update acceptance report with test execution results when MT5 available