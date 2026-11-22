# Root Cause Implementation Report

## Summary
This report documents the root causes identified and fixes implemented for the Authority/ORPHANED Recovery (Workstream 1) and Runtime Readiness State Machine (Workstream 2) security and behavioral issues.

---

## Workstream 1: Authority/ORPHANED Recovery

### Root Cause 1: Token Leakage in Audit Trail
**Finding**: `HashOperatorToken()` returned `LEN=X|F=Y|L=Z` format exposing token length, first character, and last character.
**Impact**: Information leakage in persisted audit logs (`last_reason` column).
**Fix**: Replaced with `UNVERIFIED` marker - no token-derived data persisted.
**Location**: `Include/AlgoSystem/ExecutionLedger.mqh` lines 4290-4299
**Verification**: Test 11 validates UNVERIFIED marker, no plaintext/hash.

### Root Cause 2: ORPHANED State Not Properly Clearing Owner Token
**Finding**: `ExpireStaleAuthority()` did not clear `owner_instance_token` when transitioning to ORPHANED.
**Impact**: Stale token could be misused or cause confusion on recovery.
**Fix**: Added `owner_instance_token = '', ` to UPDATE statement (line 4121).
**Location**: `Include/AlgoSystem/ExecutionLedger.mqh` line 4121
**Verification**: Test 12 validates token cleared to empty string.

### Root Cause 3: AcquireAuthority() Allowed ORPHANED Re-acquisition
**Finding**: Normal acquisition path allowed transitioning from ORPHANED to CLAIMED without explicit operator action.
**Impact**: Violated "no automatic takeover" architecture decision - ORPHANED is a blocking state.
**Fix**: Modified `AcquireAuthority()` to ONLY accept UNCLAIMED or RELEASED states. ORPHANED requires explicit `RecoverAuthorityFromOrphaned()`.
**Location**: `Include/AlgoSystem/ExecutionLedger.mqh` lines 3920-3935
**Verification**: Gate 1.1 verified.

### Root Cause 4: Missing Explicit Recovery Mechanism
**Finding**: No auditable, epoch-fenced operator recovery method existed.
**Impact**: Could not recover from ORPHANED without violating security boundaries.
**Fix**: Implemented `RecoverAuthorityFromOrphaned()` with epoch fencing, conditional update, and audit trail.
**Location**: `Include/AlgoSystem/ExecutionLedger.mqh` lines 4190-4285
**Verification**: Tests 6-11 validate recovery flow, epoch fencing, audit trail.

### Root Cause 5: Authorization Trust Model Gap (OPEN/P1)
**Finding**: Recovery script accepts operator_token but validates only epoch match, not token authenticity.
**Impact**: Operator with script access + epoch value can recover without cryptographic proof.
**Status**: Documented as OPEN/P1. Audit trail records `operator_token_hash=UNVERIFIED`.
**Required**: Architectural decision for PKI/HMAC/external IdP.

### Root Cause 9: Missing Fail-Closed Recovery Gate (RESOLVED)
**Finding**: `RecoverAuthorityFromOrphaned()` would proceed with recovery when authorization was UNVERIFIED (no trusted provider), mutating authority state based on epoch fencing alone.
**Impact**: Recovery could succeed without any operator authentication, violating fail-closed principle.
**Fix**: Added explicit fail-closed check BEFORE any state mutation (lines 4228-4234 in `ExecutionLedger.mqh`):
```cpp
string operator_token_hash = HashOperatorToken(operator_token);
if(operator_token_hash == "UNVERIFIED")
   {
   // Explicit diagnostics: authorization provider unavailable.
   // No state change, no epoch increment, no owner token mutation.
   return false;
   }
```
**Location**: `Include/AlgoSystem/ExecutionLedger.mqh` lines 4228-4234
**Verification**: Test 6 (`Test_RecoverAuthority_AuthorizationUnavailable`) and Test 11 (`Test_RecoverAuthority_AuthorizationUnavailableAudit`) validate this fail-closed behavior.

---

## Workstream 1: ERL Retry Behavior (Security Fix)

### Root Cause 6: Blocking Sleep in Event Handlers
**Finding**: `ReadExtRiskLockState()` used `Sleep(100ms)` × 3 retries = up to 300ms blocking in OnTick/OnTimer.
**Call Paths**:
- OnTick → RefreshTradingState → ReadExtRiskLockState
- OnTimer → RefreshTradingState → ReadExtRiskLockState
- ProcessHybridDecision → ReadExtRiskLockStateFresh → ReadExtRiskLockState
**Impact**: EA event processing blocked, potential missed ticks/timer events.
**Fix**: Non-blocking retry state machine using static variables to spread retries across event calls.
**Location**: `Experts/AlgoMultiAssetEA.mq5` lines 2029-2139
**Verification**: 8 static verification tests (ERL-1 through ERL-8), ValidationHarness pass.

---

## Workstream 2: Runtime Readiness State Machine

### Root Cause 7: Ad-hoc State Management
**Finding**: Runtime state tracked via boolean `valid` + string `wait_state` - no formal state machine.
**Impact**: Difficult to reason about, debug, and extend; inconsistent blocking/resolution logic.
**Fix**: Formal `ENUM_RUNTIME_STATE` with 17 states, `TransitionTo()` with audit logging, explicit readiness checks.
**Location**: `Experts/AlgoMultiAssetEA.mq5` lines 200-220, 3700-4130
**Verification**: Gates 2.1-2.13 complete, ValidationHarness pass.

### Root Cause 8: News Integration Not Connected to State Machine
**Finding**: News evaluation existed but not integrated as a formal blocking state in runtime lifecycle.
**Impact**: News blocks could not be tracked, resolved, or logged through state machine.
**Fix**: Added `RUNTIME_BLOCKED_NEWS` state, `IsNewsBlockActive()` gate, `CheckBlockedConditionResolution()` handles news resolution.
**Location**: `Experts/AlgoMultiAssetEA.mq5` lines 3960-4033, `HybridEngine.mqh` public methods
**Verification**: Test cases TC-NS-01 through TC-NS-10 defined, fail-closed verified in source.

---

## Files Modified

| File | Workstream | Changes |
|------|------------|---------|
| `Include/AlgoSystem/ExecutionLedger.mqh` | WS1 | `HashOperatorToken()` → UNVERIFIED; `ExpireStaleAuthority()` clears token; `AcquireAuthority()` rejects ORPHANED; `RecoverAuthorityFromOrphaned()` epoch-fenced recovery; **Fail-closed gate added (lines 4228-4234)** |
| `Scripts/RecoverAuthority.mq5` | WS1 | Security warnings; token redacted; UNVERIFIED audit trail documented; OPEN/P1 gap noted |
| `Scripts/TestAuthorityRecovery.mq5` | WS1 | 20 test cases (12 authority + 8 ERL) using native MQL5 SQLite; **Tests 6 & 11 corrected for fail-closed** |
| `Experts/AlgoMultiAssetEA.mq5` | WS1+WS2 | `ReleaseAuthority()` return check; `InpAuthorityLeaseSeconds`; **Non-blocking ERL retry**; Full state machine (ENUM, TransitionTo, readiness, ProcessRuntime refactor, blocked resolution, error recovery, IsNewsBlockActive) |
| `Include/AlgoSystem/HybridEngine.mqh` | WS2 | `EvaluateNews()`, `ShouldBlockEntry()` public methods |
| `Include/AlgoSystem/PortfolioRisk.mqh` | WS1 | Already handles `read_complete=false` as fail-closed |

---

## Verification Status

| Check | Result |
|-------|--------|
| EA Compile | 0 Errors, 0 Warnings ✅ |
| RecoverAuthority Script Compile | 0 Errors, 0 Warnings ✅ |
| TestAuthorityRecovery Script Compile | 0 Errors, 0 Warnings ✅ |
| ValidationHarness | 6/6 checks, 22/22 invariants ✅ |
| Authority Tests (12) | Implemented as Script (native MQL5 SQLite), NOT RUN (MT5 terminal auth required) |
| ERL Tests (8) | Static verification implemented |
| News Tests (10) | Implemented in production code as behavioral logic; NO executable test code; NOT RUN (MT5 Strategy Tester auth required for behavioral verification) |

---

## Open Items

| ID | Description | Priority | Status |
|----|-------------|----------|--------|
| OPEN/P1 | Authorization trust model (PKI/HMAC/IdP) | P1 | Requires architectural decision |
| TEST-01 | Execute authority recovery tests as Script on MT5 terminal | P2 | Pending MT5 terminal authorization |
| TEST-02 | Execute ERL retry behavior tests | P2 | Pending MT5 terminal authorization |
| TEST-03 | Execute news state machine tests (TC-NS-01 to TC-NS-10) | P2 | Pending MT5 Strategy Tester authorization |

---

## Acceptance Status

| Workstream | Status | Blocker |
|------------|--------|---------|
| WS1: Authority Recovery | **NOT ACCEPTED** | OPEN/P1 authorization trust model (recovery blocked by fail-closed gate) |
| WS1: ERL Retry Fix | **IMPLEMENTED** | None (verified via compile + static analysis) |
| WS2: Runtime State Machine | **IMPLEMENTED / STATICALLY VERIFIED** | Behavioral tests pending MT5 |

---

*Report generated: 2026-11-21T21:55:00Z*
*Baseline: `fix/dashboard-layout-defects` @ `3d3e07b` + local changes*