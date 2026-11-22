# AlgoMultiAssetEA — Architecture Documentation

**Version**: 1.002 (Hybrid)
**Last Updated**: 2026-11-13

---

## 1. System Overview

AlgoMultiAssetEA is a production-oriented **multi-asset, multi-timeframe** Expert Advisor for MetaTrader 5. It implements a **signal-only by default** architecture with a clean separation between signal generation, risk evaluation, portfolio management, and execution.

### 1.1 Core Philosophy

```
MarketData → Features → Regime → Strategies → SignalEngine → TradeFilters
    → RiskEngine → PortfolioRisk → TradeExecutor → PositionManager
```

**Key Principles**:
- **Strategies are signal-oriented only** — they never bypass execution authorization
- **Risk gates are mandatory** — every signal passes through `CRiskEngine` and `CAlgoPortfolioRisk`
- **Execution boundary is `CTradeExecutor`** — the only component calling broker APIs
- **Dashboard is observational** — never alters trading decisions
- **Multi-symbol scheduling** — `OnTick()` alone does not service all managed symbols

### 1.2 Approved Trading Boundaries (Decision Records)

| Decision | ID | Summary |
|----------|-----|---------|
| Timeframe Roles | D-01 | Context, Structure, Setup, Entry = four independent roles |
| Setup Independence | D-02 | Setup generation independent of Structure |
| News Failure | D-03 | News operational failures block new entries (fail-closed); position management separate |
| Signal ≠ Auth | D-04 | Signal/candidate/TradePlan is not execution authorization |
| Retry Policy | D-05 | Retry only after proven terminal failure; ambiguous outcomes require reconciliation |
| Durable Identity | D-06 | `setup_id`, `attempt_id`, order/deal tickets, position IDs distinct |
| Partial Fill | D-07 | Do not auto-complete partial fills |
| Fail-Closed Risk | D-08 | Critical risk/persistence/schema/broker uncertainty → block |
| Ledger Schema | D-09 | Minimal durable Execution Ledger schema with independent Setup/Attempt identities |
| Submission | D-10 | Durable intent must be confirmed before submission |
| Attempt ID | D-11 | Durable DB-backed sequence + unique component for attempt IDs |

---

## 2. Module Architecture

### 2.1 Core Pipeline Components

| Module | File | Responsibility |
|--------|------|----------------|
| **Market Data** | `MarketData.mqh` | Symbol snapshots, rates, ticks, indicator handles |
| **Feature Engine** | `Indicators.mqh`, `HybridEngine.mqh` | Technical features, market structure, liquidity |
| **Regime Engine** | `HybridRegime.mqh` | Market regime classification (Trend/Range/Vol/Compression) |
| **Strategies** | `HybridEngine.mqh` | Signal generation per trading style (Scalp/Day/Swing) |
| **Signal Engine** | `HybridEngine.mqh` | Candidate assembly, conflict resolution, scoring |
| **Trade Filters** | `SessionFilter.mqh`, `NewsRiskService.mqh` | Session windows, news blackouts, spread filters |
| **Risk Engine** | `RiskEngine.mqh` | Account-level risk, stops/targets, volume sizing, margin pre-check |
| **Portfolio Risk** | `PortfolioRisk.mqh` | Portfolio limits, exposure, correlation, concentration |
| **Trade Executor** | `TradeExecutor.mqh` | Order submission, retcode interpretation, position correlation |
| **Position Manager** | `PositionManager.mqh` | Position lifecycle, trailing, scaling, conflict resolution |
| **Execution Ledger** | `ExecutionLedger.mqh` | Durable intent/attempt tracking, reconciliation |
| **State Manager** | `StateManager.mqh` | Persistent state, locks, portfolio reconstruction |
| **Logger** | `Logger.mqh` | Structured + human-readable logging, counters |
| **Dashboard** | `HybridDashboard.mqh` | Chart overlay, real-time status, diagnostics |
| **Metrics/Alerts** | `MetricsExporter.mqh` | Prometheus export, threshold alerting |

### 2.2 Supporting Systems

| System | File | Purpose |
|--------|------|---------|
| **Configuration** | `Config.mqh`, `Constants.mqh` | Input groups, enums, magic numbers |
| **Types** | `Types.mqh`, `HybridTypes.mqh` | Core structs, enums, feature/decision types |
| **Interfaces** | `Interfaces.mqh` | Abstract contracts for providers/engines |
| **Statistics** | `Statistics.mqh` | Performance tracking, trade analytics |
| **Tester Fitness** | `TesterFitness.mqh` | Custom optimization fitness functions |
| **Optimization** | `Optimization.mqh` | Parameter space, walk-forward controller |
| **Session Filter** | `SessionFilter.mqh` | Trading session windows per symbol |
| **Concurrency** | *(in EA)* | `CFairLock`, `CChartMessageQueue`, `CSubscriberRegistry` |

---

## 3. Data Flow

### 3.1 Primary Path (Signal → Execution)

```
OnTick/OnTimer
    │
    ▼
RefreshTradingState() ─────► g_state (CRiskStateManager)
    │                           │
    │                           ▼
    │                    PortfolioState (equity, locks, positions)
    │
    ▼
ProcessRuntime(symbol) ─────► MarketSnapshot + FeatureSet
    │                           │
    ▼                           ▼
HybridEngine.Evaluate() ──► HybridDecision (candidate + gates)
    │                           │
    │                    [NewsGate, RiskGate, PortfolioGate]
    │
    ▼
BuildFreshPlan() ─────────► FreshExecutionPlan
    │                           │
    ▼                           ▼
RiskEngine.Evaluate() ──► RiskDecision (volume, SL, TP)
    │                           │
    ▼                           ▼
PortfolioRisk.CanOpen() ──► bool (+ ReservationAggregate)
    │                           │
    ▼                           ▼
TradeExecutor.Execute() ──► ExecutionResult
    │                           │
    ▼                           ▼
ExecutionLedger.Record() ─► Durable Attempt/Setup
    │                           │
    ▼                           ▼
PositionManager.Update() ──► Active position tracking
```

### 3.2 Multi-Symbol Scheduling

- **Chart Symbol**: Serviced by `OnTick()`
- **Other Symbols**: Serviced by 5-second `OnTimer()` → `ProcessRuntime()` loop
- **Discovery**: Coordinator chart enumerates peer charts via `EventChartCustom()`
- **State Sync**: Snapshot sequence + authority epoch via chart objects

---

## 4. Key Data Structures

### 4.1 MarketSnapshot (`HybridTypes.mqh`)
```cpp
struct MarketSnapshot {
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    datetime closed_bar_time;
    double open, high, low, close;
    double bid, ask;
    int spread_points;
    SymbolProperties properties;
    bool valid;
};
```

### 4.2 FeatureSet (`HybridTypes.mqh`)
```cpp
struct FeatureSet {
    // Trend: ADX, EMA slope, MACD
    // Momentum: RSI, Stoch, CCI
    // Volatility: ATR, BB width, Keltner
    // Volume: OBV, VWAP deviation, profile
    // Structure: Swing highs/lows, equal levels, sweeps
    // Liquidity: Volume profile VAH/VAL/POC
    bool valid;
};
```

### 4.3 HybridDecision (`HybridTypes.mqh`)
```cpp
struct HybridDecision {
    string symbol;
    ENUM_DECISION_STATUS status;    // BUY/SELL/NO_TRADE/BLOCKED/EXPIRED...
    ENUM_TRADING_STYLE style;
    ENUM_HYBRID_REGIME regime;
    ENUM_BIAS_DIRECTION bias;
    double long_score, short_score;
    string main_reason;
    MarketContext context;          // news, liquidity, momentum, setup_market
    // Gate results embedded
};
```

### 4.4 PortfolioState (`Types.mqh`)
```cpp
struct PortfolioState {
    double equity, balance;
    double daily_start_equity, monthly_start_equity;
    double daily_loss_percent, monthly_loss_percent;
    double total_open_risk_percent;
    int total_positions;
    int consecutive_losses;
    bool daily_lock, monthly_lock, trading_locked;
};
```

### 4.5 Execution Ledger Schema (`ExecutionLedger.mqh`)
```sql
-- Setup table (one per signal candidate)
CREATE TABLE setups (
    setup_id        TEXT PRIMARY KEY,     -- UUID
    strategy_group  TEXT NOT NULL,
    logical_key     TEXT NOT NULL,        -- symbol|style|regime|bias|tf_hash
    symbol          TEXT NOT NULL,
    style           INTEGER NOT NULL,
    regime          INTEGER NOT NULL,
    bias            INTEGER NOT NULL,
    created_at      INTEGER NOT NULL,     -- Unix timestamp
    expired_at      INTEGER,
    status          INTEGER NOT NULL,     -- PENDING, ACTIVE, EXPIRED, INVALIDATED
    payload_json    TEXT                  -- Full decision snapshot
);

-- Attempt table (one per submission intent)
CREATE TABLE attempts (
    attempt_id      TEXT PRIMARY KEY,     -- Durable sequence + component
    setup_id        TEXT NOT NULL REFERENCES setups(setup_id),
    strategy_group  TEXT NOT NULL,
    logical_key     TEXT NOT NULL,
    action_type     INTEGER NOT NULL,     -- ENTRY, MODIFY, CLOSE, RETRY
    requested_vol   REAL NOT NULL,
    requested_sl    REAL,
    requested_tp    REAL,
    status          INTEGER NOT NULL,     -- PENDING, SUBMITTED, FILLED, PARTIAL, REJECTED, FAILED
    broker_ticket   INTEGER,              -- Order ticket if submitted
    deal_ticket     INTEGER,              -- Deal ticket if filled
    position_id     INTEGER,              -- Position identifier if opened
    created_at      INTEGER NOT NULL,
    submitted_at    INTEGER,
    resolved_at     INTEGER,
    retcode         INTEGER,              -- MQL5 TRADE_RETCODE
    retcode_ext     INTEGER,
    volume_filled   REAL DEFAULT 0,
    error_json      TEXT
);
```

---

## 5. Concurrency Model

### 5.1 Chart Coordination
- **Single Coordinator**: One chart per account holds authority (via `ExecutionLedger.AcquireAuthority()`)
- **Chart Contexts**: Other charts register, receive snapshots, forward user actions
- **Heartbeat**: Coordinator validates authority every timer cycle (5s)
- **Failover**: If coordinator loses authority, next eligible chart acquires it

### 5.2 Thread-Safe Components (WP-05)
| Component | Purpose |
|-----------|---------|
| `CFairLock` | FIFO mutex with owner tracking, prevents starvation |
| `CChartMessageQueue` | Lock-free SPSC ring buffer for inter-chart messages |
| `CSubscriberRegistry` | Thread-safe subscriber list for snapshot broadcast |

---

## 6. Configuration

### 6.1 Input Groups (AlgoMultiAssetEA.mq5)

| Group | Key Inputs |
|-------|------------|
| **01. General** | Trading Style, Strategy Group Key, Execution Mode, Dashboard settings |
| **02. Symbols** | Dynamic Forex Universe, Gold/Silver/Crypto symbols |
| **03. Hybrid Decision** | Min RR, Min Score, Conflict Threshold, Entry Tolerances |
| **04. Volume Profile** | Session/Rolling bars, Value Area %, Enable |
| **05. Liquidity/Structure** | Swing lookback, Equal tolerance, Max level age, Sweep confirm |
| **06. Risk** | Daily/Monthly loss limits, Max positions, Consecutive losses |
| **07. News** | Blackout minutes, Cooldown, Impact threshold, Prevent entries |
| **08. Execution** | Deviation, Filling mode, Magic offset, Live auto-confirm |
| **09. Logging** | Level, File enable, Flush each write, Summary interval |

### 6.2 SET Files
- `Experts/AlgoMultiAssetEA.set` — Live/default parameters
- `profiles/AlgoMultiAssetEA.set` — Optimization parameter ranges

---

## 7. API Reference

### 7.1 Core Classes (Public Interface)

#### `CAlgoStateManager` (`StateManager.mqh`)
```cpp
bool Initialize();                          // Initialize DB, schema
bool RefreshCurrentMetrics();               // Update equity, positions, locks
bool GetPortfolioState(PortfolioState&);    // Read current portfolio snapshot
bool Reconstruct();                         // Rebuild state from ledger/history
void ApplyLocks(double daily, double monthly, int consec); // Apply risk locks
```

#### `CRiskEngine` (`RiskEngine.mqh`)
```cpp
bool Evaluate(const StrategySignal&, RiskDecision&); // Size, SL, TP, margin check
bool ValidateStops(const string symbol, ENUM_ORDER_TYPE, double entry, double sl, double tp);
double CalculateVolume(double risk_pct, double sl_dist, double equity);
bool CheckMargin(double required_margin);
```

#### `CAlgoPortfolioRisk` (`PortfolioRisk.mqh`)
```cpp
bool CanOpen(const StrategySignal&, const RiskDecision&); // Portfolio limits
string LastRejectionReason() const;
ReservationAggregate GetReservationAggregate() const; // For metrics
```

#### `CTradeExecutor` (`TradeExecutor.mqh`)
```cpp
bool Execute(const FreshExecutionPlan&, ExecutionResult&); // Submit order
bool SyncAuthority(long epoch, bool has_authority);       // Coordinator sync
```

#### `CExecutionLedger` (`ExecutionLedger.mqh`)
```cpp
bool Initialize();                          // Open DB, run migrations
string CreateSetup(const HybridDecision&);  // Durable setup record
string CreateAttempt(const string setup_id, ...); // Durable attempt
bool RecordSubmission(const string attempt_id, ulong ticket);
bool RecordFill(const string attempt_id, ulong deal_ticket, double vol);
bool RecordRejection(const string attempt_id, int retcode);
bool ReconcileUnresolved(int max_age_minutes); // Timer-based reconciliation
bool ValidateAuthority(key, token, epoch);    // Coordinator check
```

#### `CPositionManager` (`PositionManager.mqh`)
```cpp
void Update();                               // Trailing, scaling, conflict check
bool HasConflict(const string symbol, ENUM_ORDER_TYPE type);
void ClosePosition(ulong ticket, const string reason);
```

#### `CAlgoLogger` (`Logger.mqh`)
```cpp
void StartRun();                             // New run ID
void SetInstanceId(const string);            // Multi-chart separation
void SetMinimumLevel(ENUM_LOG_LEVEL);
void EnableConsole(bool);
void EnableFile(bool);
void Event(level, phase, event, symbol, tf, strategy, signal_id, result, reason_code, reason, error, retcode, v1, v2, v3);
```

#### `CHybridDashboard` (`HybridDashboard.mqh`)
```cpp
void Enable(bool);
void SetViewMode(int);                       // 0=FULL, 1=NORMAL, 2=COMPACT
void ShowDiagnostics(bool);
void ShowOverlay(bool);
void SetRuntimeSnapshot(style, regime, bias, long, short, stage, reason, time, success_time, valid);
void Update(const HybridDecision&, const PortfolioState&);
void RenderMarketView(const MarketSnapshot&);
void HandleChartGeometryChange();
void Clear();
```

#### `CMetricsExporter` (`MetricsExporter.mqh`)
```cpp
void Initialize(CAlgoLogger* logger, string instance_id, int interval_sec);
void OnTimer();                              // Periodic flush
void ForceFlush();

// Counters
void IncrementTicksProcessed();
void IncrementSignalsGenerated/Approved/Rejected();
void IncrementOrdersSubmitted/Filled/Rejected();
void IncrementPositionsOpen/Closed();
void IncrementErrors/Warnings();

// Gauges
void SetAccountMetrics(balance, equity, margin, free_margin, margin_level);
void SetPortfolioMetrics(exposure_pct, unrealized_pnl, realized_pnl, positions, orders);
void SetRiskMetrics(daily_loss_pct, drawdown_pct, var_95);
void SetEngineMetrics(uptime_sec, avg_latency_ms, active_symbols);
void SetNewsMetrics(events_pending, blackout_active);
```

#### `CAlertManager` (`MetricsExporter.mqh`)
```cpp
void Initialize(CAlgoLogger* logger, CMetricsExporter* metrics);
void SetThresholds(margin_crit, margin_warn, daily_loss_crit, daily_loss_warn,
                   dd_crit, dd_warn, spread_mult, pos_warn, pos_crit, cooldown_sec);

void CheckMarginLevel(double level);
void CheckDailyLoss(double pct);
void CheckDrawdown(double pct);
void CheckSpread(symbol, spread, normal_spread);
void CheckPositionCount(int count);
void CheckNewsBlackout(bool);
void CheckExecutionFailure(symbol, reason);
void CheckConnectionLost();
```

---

## 8. Deployment & Operations

### 8.1 Prerequisites
- MetaTrader 5 Build 5.0.0.5370+
- MQL5 Standard Library (project copy preferred)
- SQLite3 (bundled via `ExecutionLedger.mqh`)

### 8.2 Installation
1. Copy `Experts/AlgoMultiAssetEA.mq5` + `Include/AlgoSystem/` to terminal data folder
2. Compile via `tools/Compile-MT5.ps1` or MetaEditor
3. Attach to **one chart per account** (coordinator auto-elected)
4. Configure inputs per trading style

### 8.3 Running Modes
| Mode | Description |
|------|-------------|
| `MODE_SIGNAL_ONLY` | Dashboard + logs only, no orders (default) |
| `MODE_AUTO` | Live trading, requires `InpLiveAutoConfirm=true` |
| `MODE_BACKTEST` | Strategy Tester only |

### 8.4 Monitoring
- **Metrics**: `AlgoSystem/Metrics/metrics_<chart_id>.prom` (Prometheus format)
- **Logs**: `AlgoSystem/Logs/AlgoSystem_<date>_<chart_id>.csv` + `.log`
- **Dashboard**: Chart overlay (enable via `InpDashboard`)

---

## 9. Testing & Validation

### 9.1 Validation Harness
```powershell
# Full validation (compile + invariants)
.\tools\ValidationHarness.Tests.ps1

# Skip compile (use existing EX5)
.\tools\ValidationHarness.Tests.ps1 -SkipCompile

# Strict mode (NOT_VERIFIED = exit 18)
.\tools\ValidationHarness.Tests.ps1 -Strict
```

### 9.2 Strategy Tester
- Baseline profile: `Experts/AlgoMultiAssetEA.set`
- Optimization profile: `profiles/AlgoMultiAssetEA.set`
- Fitness: `CTesterFitness` (Sharpe + stability + trade quality)

### 9.3 Regression Gates
- 85 unit/integration tests in `ValidationHarness.Tests.ps1`
- Invariant checks: OnTick, HybridTypes, ExecutionLedger schema
- Broker mutation scanner: Flags `CTrade` outside `TradeExecutor`

---

## 10. Appendix: File Map

```
Experts/
  AlgoMultiAssetEA.mq5           # Main EA entry point

Include/AlgoSystem/
  Constants.mqh                  # Enums, magic numbers, version
  Types.mqh                      # Core structs (MarketSnapshot, PortfolioState, etc.)
  HybridTypes.mqh               # Hybrid-specific types (Decision, Context, Features)
  Interfaces.mqh                # Abstract provider/engine contracts
  Config.mqh                    # Input validation, defaults
  Utilities.mqh                 # Math, string, time helpers

  MarketData.mqh                # Rates, ticks, symbol specs
  Indicators.mqh                # Indicator handles, calculations
  HybridRegime.mqh              # Regime detection engine
  HybridEngine.mqh              # Strategies + Signal engine + Gates
  HybridDashboard.mqh           # Chart overlay UI

  RiskEngine.mqh                # Account-level risk, sizing
  PortfolioRisk.mqh             # Portfolio limits, exposure
  TradeExecutor.mqh             # Order submission, retcode handling
  ExecutionLedger.mqh           # SQLite-backed durable ledger
  PositionManager.mqh           # Position lifecycle management
  StateManager.mqh              # Persistent state, locks

  Logger.mqh                    # Structured + human logging
  Statistics.mqh                # Trade analytics
  TesterFitness.mqh             # Custom fitness for optimization
  Optimization.mqh              # Parameter space, WFO controller
  SessionFilter.mqh             # Trading session windows
  NewsRiskService.mqh           # News provider, blackouts
  MetricsExporter.mqh           # Prometheus metrics + Alerting
  LiquidityEngine.mqh           # Volume profile, market structure
  MomentumEngine.mqh            # Momentum features
  BiasEngine.mqh                # Bias calculation
  DivergenceEngine.mqh          # Divergence detection
  VolumeProfile.mqh             # Profile calculation
  EnvironmentProvider.mqh       # Terminal/account info

docs/
  architecture/
    ARCHITECTURE.md             # This file
  api/                          # Per-class API reference (auto-generated)
  security/
    SECURITY_AUDIT.md           # WP-01 security review
  testing/
    TESTER_REPORT.md            # WP-02 tester results
```

---

## 11. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.002 | 2026-11-13 | Kilo | WP-07 Metrics/Alerts, WP-08 Architecture docs |
| 1.001 | 2026-11-12 | — | WP-01 through WP-06 complete |
| 1.000 | 2026-10-21 | — | Baseline Hybrid architecture |