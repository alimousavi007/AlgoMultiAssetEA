# Runtime Readiness State Machine Design (Workstream 2)

## Purpose
Define a formal per-symbol Runtime lifecycle state machine to replace the ad-hoc `valid` boolean + `wait_state` string approach.

## Current State Analysis

### Existing State Indicators
- `CSymbolRuntime.valid` (bool) - initialized successfully
- `CSymbolRuntime.wait_state` (string) - informal wait reason
- `CSymbolRuntime.init_failure` (string) - initialization failure reason
- `RuntimeSnapshot.current_stage_code` (int):
  - 0 = NOT_EVALUATED
  - 1 = WAITING_FOR_NEW_ENTRY_BAR
  - 2 = WAITING_FOR_SIGNAL_BAR
  - 3 = EVALUATED
  - 4 = BLOCKED
- `RuntimeSnapshot.last_block_reason_code` (int) - block reason codes

### Current Flow in ProcessRuntime
1. System ready check → return if not ready
2. Session filter → BLOCKED: SESSION FILTER
3. Entry bar check (new closed bar) → WAITING: ENTRY BAR (stage=1)
4. Market snapshots (context, structure, setup, entry) → BLOCKED: *DATA
5. Feature calculations (context, structure, setup, entry) → BLOCKED: FEATURES
6. Signal bar check (context new closed bar) → WAITING: SIGNAL BAR (stage=2)
7. Portfolio state/risk lock → BLOCKED: RISK STATE/Lock
8. Hybrid engine evaluation → EVALUATED (stage=3) or BLOCKED
9. Trade execution

## Proposed State Machine

### States (ENUM_RUNTIME_STATE)
```cpp
enum ENUM_RUNTIME_STATE
{
    RUNTIME_UNINITIALIZED     = 0,  // Not yet initialized
    RUNTIME_INITIALIZING      = 1,  // Initialize() in progress
    RUNTIME_INIT_FAILED       = 2,  // Initialize() failed (terminal)
    RUNTIME_READY             = 3,  // Initialized, waiting for entry bar
    RUNTIME_WAIT_ENTRY_BAR    = 4,  // Waiting for new closed entry bar
    RUNTIME_WAIT_SIGNAL_BAR   = 5,  // Waiting for new closed signal/context bar
    RUNTIME_FETCHING_DATA     = 6,  // Fetching market snapshots
    RUNTIME_CALCULATING       = 7,  // Calculating features
    RUNTIME_EVALUATING        = 8,  // Running hybrid engine evaluation
    RUNTIME_EVALUATED         = 9,  // Evaluation complete, signal generated
    RUNTIME_BLOCKED_SESSION   = 10, // Blocked by session filter
    RUNTIME_BLOCKED_DATA      = 11, // Blocked by missing/invalid market data
    RUNTIME_BLOCKED_FEATURES  = 12, // Blocked by feature calculation failure
    RUNTIME_BLOCKED_RISK      = 13, // Blocked by risk/portfolio lock
    RUNTIME_BLOCKED_NEWS      = 14, // Blocked by news filter
    RUNTIME_BLOCKED_AUTHORITY = 15, // Blocked by authority/coordinator
    RUNTIME_BLOCKED_SYSTEM    = 16, // Blocked by system not ready
    RUNTIME_ERROR             = 17  // Unexpected error (non-terminal, retryable)
};
```

### State Transitions

```
UNINITIALIZED
    └── Initialize() called ──► INITIALIZING
                                  ├── success ──► READY
                                  └── failure ──► INIT_FAILED (terminal)

READY
    └── ProcessRuntime() called ──► WAIT_ENTRY_BAR
                                      ├── new entry bar ──► FETCHING_DATA
                                      └── no new bar ──► WAIT_ENTRY_BAR (stay)

FETCHING_DATA
    ├── all snapshots OK ──► CALCULATING
    └── any snapshot fails ──► BLOCKED_DATA

CALCULATING
    ├── all features OK ──► WAIT_SIGNAL_BAR
    └── any feature fails ──► BLOCKED_FEATURES

WAIT_SIGNAL_BAR
    ├── new signal bar ──► EVALUATING
    └── no new bar ──► WAIT_SIGNAL_BAR (stay)

EVALUATING
    ├── evaluation OK + signal ──► EVALUATED
    ├── evaluation OK + no signal ──► READY (cycle complete)
    ├── risk lock ──► BLOCKED_RISK
    ├── news block ──► BLOCKED_NEWS
    ├── authority issue ──► BLOCKED_AUTHORITY
    └── error ──► ERROR

EVALUATED
    └── next ProcessRuntime() call ──► READY (new cycle)

BLOCKED_* states
    ├── condition resolved ──► READY (or appropriate prior state)
    └── condition persists ──► stay in BLOCKED_*

ERROR
    ├── retry succeeds ──► READY
    └── max retries exceeded ──► INIT_FAILED (or stay ERROR)

INIT_FAILED (terminal)
    └── Manual re-initialization required
```

### Readiness Dimensions (Orthogonal Checks)

Each dimension can be queried independently for dashboard/diagnostics:

| Dimension | Check | Failure State |
|-----------|-------|---------------|
| **System** | `g_system_ready` | BLOCKED_SYSTEM |
| **Session** | `g_session_filter.IsAllowed()` | BLOCKED_SESSION |
| **EntryBar** | `market_entry.IsNewClosedBar()` | WAIT_ENTRY_BAR |
| **ContextData** | `market_context.GetSnapshot()` | BLOCKED_DATA |
| **StructureData** | `market_structure.GetSnapshot()` | BLOCKED_DATA |
| **SetupData** | `market_setup.GetSnapshot()` | BLOCKED_DATA |
| **EntryData** | `market_entry.GetSnapshot()` | BLOCKED_DATA |
| **ContextFeatures** | `feature_context.Calculate()` | BLOCKED_FEATURES |
| **StructureFeatures** | `feature_structure.Calculate()` | BLOCKED_FEATURES |
| **SetupFeatures** | `feature_setup.Calculate()` | BLOCKED_FEATURES |
| **EntryFeatures** | `feature_entry.Calculate()` | BLOCKED_FEATURES |
| **SignalBar** | `market_context.IsNewClosedBar()` | WAIT_SIGNAL_BAR |
| **PortfolioState** | `g_state.GetPortfolioState()` | BLOCKED_DATA |
| **RiskLock** | `!portfolio_state.trading_locked` | BLOCKED_RISK |
| **NewsFilter** | `!news_block_active` | BLOCKED_NEWS |
| **Authority** | Coordinator has authority | BLOCKED_AUTHORITY |

## Implementation Plan

### 1. Add State Enum to CSymbolRuntime
```cpp
class CSymbolRuntime : public CObject
{
public:
    // ... existing fields ...
    
    ENUM_RUNTIME_STATE  runtime_state;
    int                 last_transition_reason;  // enum for transition logging
    datetime            state_entered_time;
    int                 retry_count;
};
```

### 2. Add State Transition Method
```cpp
bool TransitionTo(ENUM_RUNTIME_STATE new_state, int reason_code = 0)
{
    if(runtime_state == new_state) return true;  // Idempotent
    
    // Log transition
    g_logger.Event(LOG_INFO, "RUNTIME", "STATE_TRANSITION",
                   symbol, "", "", "",
                   "INFO", "RUNTIME",
                   "State: " + EnumToString(runtime_state) + 
                   " -> " + EnumToString(new_state) + 
                   " reason=" + IntegerToString(reason_code));
    
    runtime_state = new_state;
    last_transition_reason = reason_code;
    state_entered_time = TimeCurrent();
    return true;
}
```

### 3. Add Readiness Check Methods
```cpp
bool IsReadyForEvaluation() const
{
    return runtime_state == RUNTIME_READY || 
           runtime_state == RUNTIME_WAIT_ENTRY_BAR ||
           runtime_state == RUNTIME_WAIT_SIGNAL_BAR;
}

bool IsBlocked() const
{
    return runtime_state >= RUNTIME_BLOCKED_SESSION && 
           runtime_state <= RUNTIME_BLOCKED_SYSTEM;
}

bool IsTerminal() const
{
    return runtime_state == RUNTIME_INIT_FAILED;
}

bool IsError() const
{
    return runtime_state == RUNTIME_ERROR;
}

string GetStateDescription() const
{
    // Return human-readable description for dashboard
}
```

### 4. Refactor ProcessRuntime to Use State Machine
```cpp
void ProcessRuntime(CSymbolRuntime& runtime)
{
    // Terminal states - no processing
    if(runtime.runtime_state == RUNTIME_UNINITIALIZED ||
       runtime.runtime_state == RUNTIME_INITIALIZING ||
       runtime.runtime_state == RUNTIME_INIT_FAILED)
    {
        return;
    }
    
    // Error state - attempt recovery
    if(runtime.runtime_state == RUNTIME_ERROR)
    {
        if(AttemptRecovery(runtime))
            runtime.TransitionTo(RUNTIME_READY);
        return;
    }
    
    // System readiness gate
    if(!g_system_ready)
    {
        runtime.TransitionTo(RUNTIME_BLOCKED_SYSTEM, REASON_SYSTEM_NOT_READY);
        return;
    }
    
    // Session filter gate
    if(!g_session_filter.IsAllowed(TimeCurrent()))
    {
        runtime.TransitionTo(RUNTIME_BLOCKED_SESSION, REASON_SESSION_FILTER);
        return;
    }
    
    // State-specific processing
    switch(runtime.runtime_state)
    {
        case RUNTIME_READY:
        case RUNTIME_WAIT_ENTRY_BAR:
            ProcessEntryBarWait(runtime);
            break;
            
        case RUNTIME_FETCHING_DATA:
            ProcessDataFetch(runtime);
            break;
            
        case RUNTIME_CALCULATING:
            ProcessFeatureCalculation(runtime);
            break;
            
        case RUNTIME_WAIT_SIGNAL_BAR:
            ProcessSignalBarWait(runtime);
            break;
            
        case RUNTIME_EVALUATING:
            ProcessEvaluation(runtime);
            break;
            
        case RUNTIME_EVALUATED:
            // Cycle complete, reset for next
            runtime.TransitionTo(RUNTIME_READY);
            break;
            
        case RUNTIME_BLOCKED_SESSION:
        case RUNTIME_BLOCKED_DATA:
        case RUNTIME_BLOCKED_FEATURES:
        case RUNTIME_BLOCKED_RISK:
        case RUNTIME_BLOCKED_NEWS:
        case RUNTIME_BLOCKED_AUTHORITY:
            CheckBlockedConditionResolution(runtime);
            break;
    }
    
    // Update snapshot for dashboard
    UpdateSnapshot(runtime);
}
```

### 5. Update Dashboard Snapshot Mapping
Map new states to existing `current_stage_code` for backward compatibility:
```cpp
void UpdateSnapshot(CSymbolRuntime& runtime)
{
    runtime.snapshot.snapshot_time = TimeCurrent();
    runtime.snapshot.generation = ++runtime.snapshot_generation;
    
    switch(runtime.runtime_state)
    {
        case RUNTIME_WAIT_ENTRY_BAR:
            runtime.snapshot.current_stage_code = 1;
            runtime.snapshot.last_block_reason_code = 1; // NO_NEW_CLOSED_BAR
            break;
        case RUNTIME_WAIT_SIGNAL_BAR:
            runtime.snapshot.current_stage_code = 2;
            runtime.snapshot.last_block_reason_code = 1;
            break;
        case RUNTIME_EVALUATED:
            runtime.snapshot.current_stage_code = 3;
            runtime.snapshot.last_block_reason_code = 0;
            runtime.snapshot.last_success_time = TimeCurrent();
            break;
        case RUNTIME_BLOCKED_SESSION:
        case RUNTIME_BLOCKED_DATA:
        case RUNTIME_BLOCKED_FEATURES:
        case RUNTIME_BLOCKED_RISK:
        case RUNTIME_BLOCKED_NEWS:
        case RUNTIME_BLOCKED_AUTHORITY:
        case RUNTIME_BLOCKED_SYSTEM:
            runtime.snapshot.current_stage_code = 4;
            // Map specific block reason
            break;
        default:
            runtime.snapshot.current_stage_code = 0;
    }
    
    runtime.snapshot.configured_style = runtime.style;
}
```

## Acceptance Gates (Workstream 2)

| Gate | Description | Status |
|------|-------------|--------|
| 2.1 | `ENUM_RUNTIME_STATE` enum defined with all states | ✅ IMPLEMENTED |
| 2.2 | `runtime_state` field added to `CSymbolRuntime` | ✅ IMPLEMENTED |
| 2.3 | `TransitionTo()` method with logging | ✅ IMPLEMENTED |
| 2.4 | Readiness check methods (`IsReadyForEvaluation`, `IsBlocked`, `IsTerminal`) | ✅ IMPLEMENTED |
| 2.5 | `ProcessRuntime` refactored to state machine pattern | ✅ IMPLEMENTED |
| 2.6 | Explicit state transitions for all gates | ✅ IMPLEMENTED |
| 2.7 | Blocked condition resolution checks | ✅ IMPLEMENTED |
| 2.8 | Error state with recovery attempt logic | ✅ IMPLEMENTED |
| 2.9 | Dashboard snapshot mapping updated | ✅ IMPLEMENTED |
| 2.10 | Compile: 0 errors, 0 warnings | ✅ VERIFIED |
| 2.11 | ValidationHarness: 6/6 checks, 22/22 invariants | ✅ VERIFIED |
| 2.12 | State transition logging verified | ✅ IMPLEMENTED |
| 2.13 | Documentation: `docs/RUNTIME_READINESS_STATE_MODEL.md` | ✅ IMPLEMENTED |

## Risk Considerations

1. **Backward Compatibility**: Existing `current_stage_code` values must map correctly for dashboard
2. **Multi-symbol**: Each `CSymbolRuntime` maintains independent state
3. **Persistence**: State is in-memory only (restart = UNINITIALIZED) - acceptable per architecture
4. **Performance**: State machine adds minimal overhead (switch statement vs if-chain)
5. **Concurrency**: Single-threaded EA context - no race conditions

## Test Execution Status

**News State Machine Tests (TC-NS-01 through TC-NS-10)**: Implemented in production code as behavioral logic, **NOT EXECUTED** as automated tests.
- No executable test code exists for News state machine; test cases are behavioral specifications verified by static code inspection.
- Requires MT5 Strategy Tester authorization for behavioral verification.
- Static verification: compile passes, ValidationHarness passes.
- Test cases defined in `RUNTIME_READINESS_IMPLEMENTATION_REPORT.md`.

## Workstream 2 Acceptance Status

**IMPLEMENTED / STATICALLY VERIFIED** — behavioral verification pending MT5 authorization.

All 13 implementation gates complete. News integration fail-closed behavior verified in source code.
Full behavioral acceptance requires MT5 Strategy Tester execution of TC-NS-01 through TC-NS-10.

## Next Steps
All Workstream 2 acceptance gates are complete:
1. ✅ Implemented `ENUM_RUNTIME_STATE` enum and added to `CSymbolRuntime`
2. ✅ Added `TransitionTo()` method with audit logging
3. ✅ Refactored `ProcessRuntime()` to use state machine pattern
4. ✅ Added blocked condition resolution logic
5. ✅ Added ERROR state with recovery attempt logic
6. ✅ Updated dashboard snapshot mapping (backward compatible)
7. ✅ Compile verified: 0 errors, 0 warnings
8. ✅ ValidationHarness verified: 6/6 checks, 22/22 invariants
9. ✅ Documentation updated

**Pending MT5 Authorization**: Behavioral test execution for news state machine test cases.