# Implementation Roadmap Status

## Overview
This document tracks the implementation status of all workstreams and their acceptance criteria for the AlgoMultiAssetEA project.

---

## Workstream 1: Authority/ORPHANED Recovery

### Implementation Gates (13/13 Complete)

| Gate | Description | Status | Evidence |
|------|-------------|--------|----------|
| WS1-G1 | `AcquireAuthority()` rejects ORPHANED | ✅ DONE | `ExecutionLedger.mqh` lines 3920-3935 |
| WS1-G2 | `RecoverAuthorityFromOrphaned()` with epoch fencing | ✅ DONE | `ExecutionLedger.mqh` lines 4190-4285 |
| WS1-G3 | `ReleaseAuthority()` return-value check in `OnDeinit()` | ✅ DONE | `AlgoMultiAssetEA.mq5` lines 6684-6692 |
| WS1-G4 | `Scripts/RecoverAuthority.mq5` operator script | ✅ DONE | Compiles 0E/0W |
| WS1-G5 | `ExpireStaleAuthority()` clears `owner_instance_token` | ✅ DONE | `ExecutionLedger.mqh` line 4121 |
| WS1-G6 | `RecoverAuthorityFromOrphaned()` records `operator_token_hash=UNVERIFIED` | ✅ DONE | `ExecutionLedger.mqh` lines 4227-4234, 4290-4299 |
| WS1-G7 | `InpAuthorityLeaseSeconds` input parameter | ✅ DONE | `AlgoMultiAssetEA.mq5` input + usage |
| WS1-G8 | Compile: 0 errors, 0 warnings | ✅ VERIFIED | All 3 components compile clean |
| WS1-G9 | ValidationHarness: 6/6 checks, 22/22 invariants | ✅ VERIFIED | Harness exit code 0 |
| WS1-G10 | Isolated recovery tests (Tests 1-12) | ✅ DONE | `TestAuthorityRecovery.mq5` - native MQL5 SQLite |
| WS1-G11 | ERL retry behavior tests (ERL-1 to ERL-8) | ✅ DONE | Static verification in `TestAuthorityRecovery.mq5` |
| WS1-G12 | Authority recovery documentation | ✅ DONE | `docs/AUTHORITY_OPERATOR_RECOVERY.md` |
| WS1-G13 | Acceptance report | ✅ DONE | `docs/AUTHORITY_RECOVERY_ACCEPTANCE_REPORT.md` |

### Security Gates

| Gate | Description | Status | Notes |
|------|-------------|--------|-------|
| SEC-1 | Token leakage eliminated from audit trail | ✅ RESOLVED | UNVERIFIED marker, no token-derived data |
| SEC-2 | ORPHANED transition clears owner token | ✅ RESOLVED | Line 4121 |
| SEC-3 | No automatic takeover from ORPHANED | ✅ RESOLVED | AcquireAuthority rejects ORPHANED |
| SEC-4 | Explicit epoch-fenced recovery | ✅ RESOLVED | RecoverAuthorityFromOrphaned |
| SEC-5 | Authorization trust model | ❌ OPEN/P1 | Requires architectural decision |
| SEC-6 | ERL blocking Sleep removed | ✅ RESOLVED | Non-blocking state machine |
| SEC-7 | Fail-closed recovery gate | ✅ RESOLVED | RecoverAuthorityFromOrphaned lines 4228-4234 |

### Test Execution Status

| Test Suite | Tests | Implementation | Execution |
|------------|-------|----------------|-----------|
| Authority Recovery | 12 | ✅ COMPLETE (Script with native MQL5 SQLite) | ❌ NOT RUN (MT5 terminal auth required) |
| ERL Retry Behavior | 8 | ✅ STATIC VERIFICATION | Static only (code inspection) |
| News State Machine | 10 | ✅ Code implemented (behavioral logic) | ❌ NOT RUN (MT5 Strategy Tester auth required) |

### Acceptance Status

**NOT ACCEPTED** — Blocked by OPEN/P1 authorization trust model gap. Recovery is now fail-closed (blocked) until trusted authentication provider is implemented.

**Conditions for Acceptance**:
1. Implement operator authorization validation (PKI/HMAC/external IdP) OR
2. Explicit risk acceptance signed by authorized stakeholder

---

## Workstream 2: Runtime Readiness State Machine

### Implementation Gates (13/13 Complete)

| Gate | Description | Status | Evidence |
|------|-------------|--------|----------|
| WS2-G1 | `ENUM_RUNTIME_STATE` enum defined with all states | ✅ DONE | `AlgoMultiAssetEA.mq5` lines 482-502 |
| WS2-G2 | `runtime_state` field added to `CSymbolRuntime` | ✅ DONE | `AlgoMultiAssetEA.mq5` line 592 |
| WS2-G3 | `TransitionTo()` method with audit logging | ✅ DONE | `AlgoMultiAssetEA.mq5` lines 640-657 |
| WS2-G4 | Readiness check methods (`IsReadyForEvaluation`, `IsBlocked`, `IsTerminal`, `IsError`) | ✅ DONE | `AlgoMultiAssetEA.mq5` lines 660-681 |
| WS2-G5 | `ProcessRuntime` refactored to state machine pattern | ✅ DONE | `AlgoMultiAssetEA.mq5` lines 3775-3850 |
| WS2-G6 | Explicit state transitions for all gates | ✅ DONE | ProcessEntryBarWait, ProcessDataFetch, ProcessFeatureCalculation, ProcessSignalBarWait, ProcessEvaluation |
| WS2-G7 | Blocked condition resolution checks | ✅ DONE | `CheckBlockedConditionResolution` lines 4031-4103 |
| WS2-G8 | Error state with recovery attempt logic | ✅ DONE | `AttemptRuntimeRecovery` lines 4035-4070 |
| WS2-G9 | Dashboard snapshot mapping updated | ✅ DONE | `UpdateRuntimeSnapshot` lines 4075-4130 |
| WS2-G10 | Compile: 0 errors, 0 warnings | ✅ VERIFIED | EA compiles clean |
| WS2-G11 | ValidationHarness: 6/6, 22/22 | ✅ VERIFIED | Harness exit code 0 |
| WS2-G12 | State transition logging verified | ✅ DONE | `TransitionTo` logs to `g_logger` |
| WS2-G13 | Documentation | ✅ DONE | `docs/RUNTIME_READINESS_STATE_MODEL.md` |

### Behavioral Test Cases (10/10 Defined)

| Test Case | Description | Implementation | Execution |
|-----------|-------------|----------------|-----------|
| TC-NS-01 | News disabled | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-02 | News enabled, provider unavailable (fail-closed) | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-03 | Active blackout | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-04 | Cooldown active | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-05 | Event passed | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-06 | No event scheduled | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-07 | Block resolution - blackout expires | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-08 | Block resolution - provider unavailable | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-09 | Multi-symbol independence | ✅ Code implemented | ❌ NOT RUN (Strategy Tester) |
| TC-NS-10 | Position management separation | ✅ Verified (separate code path) | N/A |

### Acceptance Status

**IMPLEMENTED / STATICALLY VERIFIED** — Behavioral verification pending MT5 authorization.

**Conditions for Full Behavioral Acceptance**:
1. Execute news state machine test cases (TC-NS-01 through TC-NS-10) in Strategy Tester when MT5 authorized
2. Verify state transition logs match expected sequences

---

## Workstream 3: ERL Retry Behavior Fix (Part of WS1)

### Implementation Summary

| Component | Change | Status |
|-----------|--------|--------|
| `ReadExtRiskLockState()` | Non-blocking retry state machine | ✅ DONE |
| `ENUM_EXT_RISK_LOCK_REASON` | Added `GV_READ_PENDING` (10), shifted `UNKNOWN` to 11 | ✅ DONE |
| `ExtRiskLockReasonToString()` | Added `GV_READ_PENDING` string | ✅ DONE |
| Static retry tracking | `s_erl_retry_attempt`, `s_erl_reads_ok[6]`, `s_erl_cached_vals[6]` | ✅ DONE |
| Fail-closed preserved | `PortfolioRisk.CheckExternalRiskLock` handles `read_complete=false` | ✅ VERIFIED |

### Call Graph Safety

**Before (Blocking)**:
```
OnTick/OnTimer → RefreshTradingState → ReadExtRiskLockState → Sleep(100ms) × 3 = 300ms BLOCK
```

**After (Non-Blocking)**:
```
OnTick/OnTimer → RefreshTradingState → ReadExtRiskLockState → One read cycle → Return (read_complete=false during retries)
                                                                              → Next call retries remaining → Return
                                                                              → After 3 attempts → Fail-closed
```

### Test Coverage

| Test | Description | Type |
|------|-------------|------|
| ERL-1 | Retry State Init | Static Verification |
| ERL-2 | Partial Reads Tracking | Static Verification |
| ERL-3 | read_complete=false During Retries | Static Verification |
| ERL-4 | Fail-Closed After Max Retries | Static Verification |
| ERL-5 | Success Resets Retry State | Static Verification |
| ERL-6 | Disabled Feature Bypasses Retry | Static Verification |
| ERL-7 | GV Not Found Bypasses Retry | Static Verification |
| ERL-8 | No Blocking Sleep | Static Verification |

---

## Pre-Existing Issues (Unrelated to Current Work)

| Issue | Description | Status |
|-------|-------------|--------|
| StdLib Conflict | Project Include contains Standard Library copies that differ from terminal | Pre-existing, architectural decision needed |
| origin.txt Path Mismatch | Terminal data folder origin maps to `C:\Program Files\AMarkets-MetaTrader5` not `C:\Program Files\AMarkets - MetaTrader 5` | Pre-existing, terminal registration |

---

## Overall Project Status

| Workstream | Implementation | Static Verification | Behavioral Tests | Acceptance |
|------------|----------------|---------------------|------------------|------------|
| WS1: Authority Recovery | ✅ COMPLETE | ✅ PASS | ❌ PENDING MT5 (Script) | ❌ NOT ACCEPTED (OPEN/P1) |
| WS1: ERL Retry Fix | ✅ COMPLETE | ✅ PASS | Static only | ✅ IMPLEMENTED |
| WS2: Runtime State Machine | ✅ COMPLETE | ✅ PASS | ❌ PENDING MT5 (Strategy Tester) | ✅ STATICALLY VERIFIED |

---

## Next Dependencies

| Dependency | Required For | Status |
|------------|--------------|--------|
| Architectural decision: Operator authorization trust model | WS1 Final Acceptance | BLOCKED |
| MT5 terminal authorization | Authority/ERL Script execution | PENDING |
| MT5 Strategy Tester authorization | News behavioral test execution | PENDING |
| Git commit/push authorization | Delivery of implementation changes | PENDING |

---

## Quality Gates Summary

| Gate | Status | Evidence |
|------|--------|----------|
| Baseline Compile | ✅ PASS | 0E/0W for EA, Recovery Script, Test Script |
| ValidationHarness | ✅ PASS | 6/6 checks, 22/22 invariants |
| Static Code Review | ✅ PASS | Root causes addressed, no regressions |
| Security Audit (WS1) | ⚠️ PARTIAL | Token leakage fixed, fail-closed gate implemented, auth gap OPEN/P1 |
| Risk Audit (ERL) | ✅ PASS | Non-blocking retry, fail-closed preserved |
| Documentation | ✅ COMPLETE | All 6 docs updated |

---

*Roadmap updated: 2026-11-21T21:55:00Z*
*Baseline: `fix/dashboard-layout-defects` @ `3d3e07b` + local changes*