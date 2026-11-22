# AlgoMultiAssetEA — API Reference

**Version**: 1.002
**Generated**: 2026-11-13

---

## Quick Index

| Class | File | Primary Purpose |
|-------|------|-----------------|
| `CAlgoStateManager` | `StateManager.mqh` | Persistent state, portfolio reconstruction, risk locks |
| `CRiskEngine` | `RiskEngine.mqh` | Account-level risk, position sizing, stop/target validation |
| `CAlgoPortfolioRisk` | `PortfolioRisk.mqh` | Portfolio exposure, correlation, concentration limits |
| `CTradeExecutor` | `TradeExecutor.mqh` | Broker order submission, retcode handling |
| `CExecutionLedger` | `ExecutionLedger.mqh` | Durable intent/attempt tracking, SQLite backend |
| `CPositionManager` | `PositionManager.mqh` | Position lifecycle, trailing, conflict resolution |
| `CAlgoLogger` | `Logger.mqh` | Structured + human logging, event counters |
| `CHybridDashboard` | `HybridDashboard.mqh` | Chart overlay, real-time status display |
| `CMetricsExporter` | `MetricsExporter.mqh` | Prometheus metrics export, periodic flush |
| `CAlertManager` | `MetricsExporter.mqh` | Threshold alerting, cooldown, on-chart display |
| `CSessionFilter` | `SessionFilter.mqh` | Trading session windows per symbol |
| `CNewsRiskService` | `NewsRiskService.mqh` | News provider, blackouts, event risk |
| `CHybridEngine` | `HybridEngine.mqh` | Strategies + Signal engine + Gates |
| `CHybridRegime` | `HybridRegime.mqh` | Market regime classification |

---

## CAlgoStateManager

### Initialization
```cpp
bool Initialize();                                    // Open DB, init schema
bool Reconstruct();                                   // Rebuild from ledger/history
```

### Portfolio State
```cpp
bool RefreshCurrentMetrics();                         // Update equity, positions, locks
bool GetPortfolioState(PortfolioState& state);        // Read current snapshot
```

### Risk Locks
```cpp
void ApplyLocks(double daily_limit_pct, double monthly_limit_pct, int max_consecutive);
```

### PortfolioState Output Struct
```cpp
struct PortfolioState {
    double equity;                 // Current equity
    double balance;                // Current balance
    double daily_start_equity;     // Equity at day start
    double monthly_start_equity;   // Equity at month start
    double daily_loss_percent;     // Daily loss as fraction (0.05 = 5%)
    double monthly_loss_percent;   // Monthly loss as fraction
    double total_open_risk_percent; // Portfolio risk exposure
    int total_positions;           // Open position count
    int consecutive_losses;        // Current losing streak
    bool daily_lock;               // Daily loss limit hit
    bool monthly_lock;             // Monthly loss limit hit
    bool trading_locked;           // Any lock active
};
```

---

## CRiskEngine

### Signal Evaluation
```cpp
bool Evaluate(const StrategySignal& signal, RiskDecision& decision);
```

### RiskDecision Output Struct
```cpp
struct RiskDecision {
    double calculated_volume;      // Normalized, validated volume
    double stop_loss;              // Absolute price
    double take_profit;            // Absolute price
    double risk_amount;            // Account currency at risk
    double risk_percent;           // As fraction of equity
    ENUM_REJECTION_REASON rejection_reason; // REJECT_NONE if OK
    bool valid;                    // True if all checks passed
};
```

### Helpers
```cpp
bool ValidateStops(const string symbol, ENUM_ORDER_TYPE type, double entry, double sl, double tp);
double CalculateVolume(double risk_pct, double sl_distance, double equity);
bool CheckMargin(double required_margin);
```

### Rejection Reasons (`ENUM_REJECTION_REASON`)
```
REJECT_NONE, REJECT_INVALID_SIGNAL, REJECT_UNCERTAIN_REGIME, REJECT_SESSION,
REJECT_SPREAD, REJECT_DAILY_LOSS, REJECT_MONTHLY_LOSS, REJECT_CONSECUTIVE_LOSSES,
REJECT_POSITION_LIMIT, REJECT_PORTFOLIO_RISK, REJECT_CORRELATION,
REJECT_INVALID_STOP, REJECT_INVALID_TARGET, REJECT_LOW_RR, REJECT_INVALID_VOLUME,
REJECT_MARGIN, REJECT_EXECUTION, REJECT_DUPLICATE_SIGNAL
```

---

## CAlgoPortfolioRisk

### Portfolio Gate
```cpp
bool CanOpen(const StrategySignal& signal, const RiskDecision& risk);
string LastRejectionReason() const;
```

### Reservation Aggregate (for metrics)
```cpp
struct ReservationAggregate {
    double reserved_margin;        // Margin reserved for pending
    double reserved_risk_pct;      // Risk % reserved
    int pending_count;             // Pending orders count
};
ReservationAggregate GetReservationAggregate() const;
```

### Configuration (via inputs)
- `InpMaxTotalPositions` — Global position limit
- `InpMaxCorrelatedPositions` — Correlated pair limit
- `InpMaxExposurePct` — Portfolio exposure cap
- `InpCorrelationThreshold` — Correlation coefficient limit

---

## CTradeExecutor

### Execution
```cpp
bool Execute(const FreshExecutionPlan& plan, ExecutionResult& result);
bool SyncAuthority(long epoch, bool has_authority);    // Coordinator sync
```

### FreshExecutionPlan Input Struct
```cpp
struct FreshExecutionPlan {
    string setup_id;               // Durable setup reference
    string attempt_id;             // Durable attempt reference
    string symbol;
    ENUM_ORDER_TYPE type;          // BUY/SELL
    double volume;                 // Pre-validated
    double stop_loss;
    double take_profit;
    double entry_price;            // 0 = market
    int deviation_points;          // Slippage tolerance
    ENUM_ORDER_TYPE_FILLING filling_mode;
    ulong magic;                   // Strategy-group magic
    string comment;                // Contains setup_id + attempt_id
    bool valid;
};
```

### ExecutionResult Output Struct
```cpp
struct ExecutionResult {
    bool success;
    ulong order_ticket;            // If submitted
    ulong deal_ticket;             // If filled
    double filled_volume;
    int retcode;                   // TRADE_RETCODE
    int retcode_external;          // Broker extended code
    string error_message;
};
```

---

## CExecutionLedger

### Lifecycle
```cpp
bool Initialize();                                     // Open DB, run migrations
void Shutdown();                                       // Close DB
```

### Setup Management
```cpp
string CreateSetup(const HybridDecision& decision);    // Returns setup_id
bool ExpireSetup(const string setup_id);
bool InvalidateSetup(const string setup_id, const string reason);
```

### Attempt Management
```cpp
string CreateAttempt(const string setup_id, 
                     ENUM_ATTEMPT_ACTION action,
                     double volume, double sl, double tp); // Returns attempt_id

bool RecordSubmission(const string attempt_id, ulong order_ticket);
bool RecordFill(const string attempt_id, ulong deal_ticket, double volume);
bool RecordPartialFill(const string attempt_id, ulong deal_ticket, double volume);
bool RecordRejection(const string attempt_id, int retcode, int retcode_ext, const string error);
```

### Reconciliation
```cpp
bool ReconcileUnresolved(int max_age_minutes);        // Timer-driven
bool ValidateAuthority(const string key, const string token, long epoch);
```

### Query
```cpp
bool GetAttempt(const string attempt_id, ExecutionAttemptRecord& out);
bool GetSetup(const string setup_id, SetupRecord& out);
bool GetRetryApprovalEventOutcome(const string action_id, string& outcome, string& new_attempt_id);
bool InspectSetupClaims(string& diag, int& orphan_claims, int limit);
```

### Record Structs
```cpp
struct SetupRecord {
    string setup_id;
    string strategy_group;
    string logical_key;
    string symbol;
    int style, regime, bias;
    long created_at, expired_at;
    int status;                    // PENDING, ACTIVE, EXPIRED, INVALIDATED
    string payload_json;
};

struct ExecutionAttemptRecord {
    string attempt_id;
    string setup_id;
    string strategy_group;
    string logical_key;
    int action_type;               // ENTRY, MODIFY, CLOSE, RETRY
    double requested_vol, requested_sl, requested_tp;
    int status;                    // PENDING, SUBMITTED, FILLED, PARTIAL, REJECTED, FAILED
    long broker_ticket, deal_ticket, position_id;
    long created_at, submitted_at, resolved_at;
    int retcode, retcode_ext;
    double volume_filled;
    string error_json;
};
```

---

## CPositionManager

### Lifecycle
```cpp
void Update();                                        // Called each timer: trailing, scaling, conflicts
```

### Conflict Detection
```cpp
bool HasConflict(const string symbol, ENUM_ORDER_TYPE type); // Check before new entry
```

### Position Control
```cpp
void ClosePosition(ulong ticket, const string reason);
void CloseAllPositions(const string reason);
void ModifyPosition(ulong ticket, double new_sl, double new_tp);
```

### Trailing/Scaling (configured via inputs)
- `InpTrailingMode` — NONE, FIXED, ATR, STRUCTURE
- `InpTrailingStartPct` — Profit % to activate
- `InpTrailingDistancePct` — Trail distance
- `InpScaleInEnabled` / `InpScaleOutEnabled`

---

## CAlgoLogger

### Configuration
```cpp
void StartRun();                                      // Generate new RunID
void SetInstanceId(const string id);                  // Multi-chart separation
void SetMinimumLevel(ENUM_LOG_LEVEL level);           // LOG_ERROR..LOG_OPTIMIZATION
void EnableConsole(bool enable);
void EnableFile(bool enable);
void SetFlushEachWrite(bool enable);
void SetSummaryInterval(int seconds);
```

### Event Logging (Primary API)
```cpp
bool Event(ENUM_LOG_LEVEL level,
           const string phase,        // "INIT", "MARKET", "SIGNAL", "RISK", "EXECUTION", "STATE"
           const string event,        // "SIGNAL_GENERATED", "RISK_APPROVED", "ORDER_SUBMITTED", etc.
           const string symbol = "",
           const string timeframe = "",
           const string strategy = "",
           const string signal_id = "",
           const string result = "",  // "OK", "REJECT", "FAIL", "PARTIAL"
           const string reason_code = "",
           const string reason = "",
           const int last_error = 0,
           const uint trade_retcode = 0,
           const double value1 = 0.0,
           const double value2 = 0.0,
           const double value3 = 0.0);
```

### Convenience Methods
```cpp
virtual void Log(ENUM_LOG_LEVEL level, const string message);
virtual void Error(const string message);
virtual void Warning(const string message);
virtual void Info(const string message);
virtual void Signal(const StrategySignal& signal);
virtual void Risk(const RiskDecision& decision);
virtual void Trade(const ExecutionResult& result);
```

### Counters (Auto-updated via Event)
```
m_events_total, m_errors_total, m_warnings_total
m_init_failures, m_market_failures, m_feature_failures
m_regime_events, m_strategy_batches, m_signals
m_risk_approvals, m_risk_rejections, m_portfolio_rejections
m_execution_attempts, m_execution_failures, m_execution_successes
m_state_failures
```

### Output Files
- `AlgoSystem/Logs/AlgoSystem_<date>_<instance>.csv` — Structured (18 columns)
- `AlgoSystem/Logs/AlgoSystem_Human_<date>_<instance>.log` — Human-readable

---

## CHybridDashboard

### Configuration
```cpp
void Enable(bool enabled);
void SetViewMode(int mode);                           // 0=FULL, 1=NORMAL, 2=COMPACT
void ShowDiagnostics(bool show);
void ShowOverlay(bool show);
void SetTitle(const string title);
void SetCompactView(bool compact);
```

### Data Input
```cpp
// Snapshot from Global Variables (multi-chart)
void SetRuntimeSnapshot(const string style, const string regime, const string bias,
                        const string long_score, const string short_score,
                        const string stage, const string reason,
                        datetime snap_time, datetime success_time, bool valid);

// Main update (coordinator chart)
void Update(const HybridDecision& decision, const PortfolioState& portfolio_state);

// Market view (context charts)
void RenderMarketView(const MarketSnapshot& market);
```

### Maintenance
```cpp
void HandleChartGeometryChange();                     // Call on chart resize
void Clear();                                         // Remove all objects
```

### View Modes
| Mode | Rows Shown | Use Case |
|------|------------|----------|
| FULL (0) | 14+ | Development, debugging |
| NORMAL (1) | 8 | Standard monitoring |
| COMPACT (2) | 4 | Minimal overlay |

---

## CMetricsExporter

### Initialization
```cpp
void Initialize(CAlgoLogger* logger, const string instance_id = "", int write_interval_seconds = 10);
```

### Periodic
```cpp
void OnTimer();                                       // Call from EA OnTimer
void ForceFlush();                                    // Immediate write
```

### Counter Increments
```cpp
void IncrementTicksProcessed();
void IncrementSignalsGenerated();
void IncrementSignalsApproved();
void IncrementSignalsRejected();
void IncrementOrdersSubmitted();
void IncrementOrdersFilled();
void IncrementOrdersRejected();
void IncrementPositionsOpen();
void IncrementPositionsClosed();
void IncrementErrors();
void IncrementWarnings();
```

### Gauge Setters
```cpp
void SetAccountMetrics(double balance, double equity, double margin, double free_margin, double margin_level);
void SetPortfolioMetrics(double exposure_pct, double unrealized_pnl, double realized_pnl, int active_positions, int pending_orders);
void SetRiskMetrics(double daily_loss_pct, double drawdown_pct, double var_95);
void SetEngineMetrics(double uptime_seconds, double avg_tick_latency_ms, int active_symbols);
void SetNewsMetrics(int events_pending, int blackout_active);
```

### Output
- File: `AlgoSystem/Metrics/metrics_<instance_id>.prom`
- Format: Prometheus text exposition format
- Labels: `instance="<chart_id>"` (if provided)

### Exported Metrics (22 total)
| Metric | Type | Description |
|--------|------|-------------|
| `algo_ticks_processed_total` | Counter | Ticks processed |
| `algo_signals_generated_total` | Counter | Signals generated |
| `algo_signals_approved_total` | Counter | Risk-approved |
| `algo_signals_rejected_total` | Counter | Risk-rejected |
| `algo_orders_submitted_total` | Counter | Orders sent |
| `algo_orders_filled_total` | Counter | Orders filled |
| `algo_orders_rejected_total` | Counter | Orders rejected |
| `algo_positions_open_total` | Counter | Positions opened |
| `algo_positions_closed_total` | Counter | Positions closed |
| `algo_errors_total` | Counter | Error count |
| `algo_warnings_total` | Counter | Warning count |
| `algo_account_balance` | Gauge | Account balance |
| `algo_account_equity` | Gauge | Account equity |
| `algo_account_margin` | Gauge | Used margin |
| `algo_account_free_margin` | Gauge | Free margin |
| `algo_account_margin_level` | Gauge | Margin level % |
| `algo_portfolio_exposure_pct` | Gauge | Portfolio exposure % |
| `algo_portfolio_unrealized_pnl` | Gauge | Unrealized P&L |
| `algo_portfolio_realized_pnl` | Gauge | Realized P&L |
| `algo_portfolio_active_positions` | Gauge | Open positions |
| `algo_portfolio_pending_orders` | Gauge | Pending orders |
| `algo_risk_daily_loss_pct` | Gauge | Daily loss % |
| `algo_risk_drawdown_pct` | Gauge | Drawdown % |
| `algo_risk_var_95` | Gauge | VaR 95% |
| `algo_engine_uptime_seconds` | Gauge | Uptime |
| `algo_engine_avg_tick_latency_ms` | Gauge | Avg tick latency |
| `algo_engine_active_symbols` | Gauge | Monitored symbols |
| `algo_news_events_pending` | Gauge | News events |
| `algo_news_blackout_active` | Gauge | Blackout (0/1) |

---

## CAlertManager

### Initialization
```cpp
void Initialize(CAlgoLogger* logger, CMetricsExporter* metrics = NULL);
```

### Threshold Configuration
```cpp
void SetThresholds(double margin_crit, double margin_warn,
                   double daily_loss_crit, double daily_loss_warn,
                   double dd_crit, double dd_warn,
                   double spread_mult, int pos_warn, int pos_crit,
                   int cooldown_seconds);
```

### Automated Checks (Call from OnTimer)
```cpp
void CheckMarginLevel(double margin_level_pct);
void CheckDailyLoss(double daily_loss_pct);
void CheckDrawdown(double drawdown_pct);
void CheckSpread(const string symbol, double spread_points, double normal_spread_points);
void CheckPositionCount(int active_positions);
void CheckNewsBlackout(bool is_blackout);
void CheckExecutionFailure(const string symbol, const string reason);
void CheckConnectionLost();
```

### Alert Record
```cpp
struct AlertRecord {
    datetime timestamp;
    ENUM_ALERT_SEVERITY severity;    // INFO, WARNING, CRITICAL
    string category;
    string message;
    string symbol;
    double value;
    double threshold;
    bool acknowledged;
};
```

### Query
```cpp
int GetAlertCount() const;
AlertRecord GetAlert(int index) const;
void AcknowledgeAlert(int index);
void ClearAcknowledged();
void ClearAll();
```

### Default Thresholds
| Category | Warning | Critical |
|----------|---------|----------|
| Margin Level | 200% | 150% |
| Daily Loss | 3% | 5% |
| Drawdown | 5% | 10% |
| Spread | 3x normal | — |
| Positions | 8 | 10 |
| Cooldown | 60s | 60s |

---

## CSessionFilter

### Configuration
```cpp
void SetSession(const string symbol, const TradingSession& session);
bool IsTradeAllowed(const string symbol, datetime time = 0) const;
```

### TradingSession Struct
```cpp
struct TradingSession {
    string name;
    int start_hour, start_min;    // UTC
    int end_hour, end_min;        // UTC
    bool enabled;
    bool allow_weekend;
};
```

### Predefined Sessions (via inputs)
- `InpSessionLondon` — 08:00-17:00 UTC
- `InpSessionNewYork` — 13:00-22:00 UTC
- `InpSessionTokyo` — 00:00-09:00 UTC
- `InpSessionSydney` — 22:00-07:00 UTC

---

## CNewsRiskService

### Configuration
```cpp
void SetParameters(int blackout_before_min, int blackout_after_min,
                   int cooldown_min, int impact_threshold,
                   bool prevent_entries, bool close_on_news);
bool SetProvider(INewsProvider* provider, bool take_ownership = false);
bool Initialize(INewsProvider* provider = NULL);
void SetEnabled(bool enabled);
```

### Evaluation
```cpp
NewsFeatures Evaluate(const string symbol, datetime current_time, const PortfolioState& portfolio);
bool ShouldBlockEntry(const NewsFeatures& news, const string symbol) const;
bool ShouldClosePosition(const NewsFeatures& news, const string symbol) const;
```

### NewsFeatures Output
```cpp
struct NewsFeatures {
    bool valid;
    ENUM_NEWS_STATE state;         // UNAVAILABLE, NO_EVENT, BLACKOUT, COOLDOWN, PASSED, DISABLED
    string reason;
    datetime next_event_time;
    string next_event_currency;
    string next_event_name;
    int next_event_impact;         // 1=Low, 2=Medium, 3=High
    datetime bar_time;
    string symbol;
    string reason_detail;
};
```

### ENUM_NEWS_STATE
```
NEWS_UNAVAILABLE       // Provider failed or not configured
NEWS_NO_EVENT_SCHEDULED // Clean
NEWS_BLACKOUT_ACTIVE   // Within blackout window
NEWS_COOLDOWN_ACTIVE   // Post-event cooldown
NEWS_EVENT_PASSED      // Event passed, still in cooldown
NEWS_DISABLED          // Disabled by config
```

---

## CHybridEngine

### Initialization
```cpp
bool Initialize(const HybridConfig& config);
```

### Main Evaluation
```cpp
HybridDecision Evaluate(const string symbol, const MarketSnapshot& market, const PortfolioState& portfolio);
```

### Configuration (HybridConfig)
```cpp
struct HybridConfig {
    ENUM_TRADING_STYLE style;
    double min_rr;
    double min_score;
    double conflict_threshold;
    double entry_tolerance_scalp;
    double entry_tolerance_day;
    double entry_tolerance_swing;
    bool allow_mean_reversion;
    // Timeframe role mappings (per style)
    ENUM_TIMEFRAMES tf_context, tf_structure, tf_setup, tf_entry;
};
```

### HybridDecision Output
```cpp
struct HybridDecision {
    string symbol;
    ENUM_DECISION_STATUS status;
    ENUM_TRADING_STYLE style;
    ENUM_HYBRID_REGIME regime;
    ENUM_BIAS_DIRECTION bias;
    double long_score, short_score;
    string main_reason;
    MarketContext context;      // news, liquidity, momentum, setup_market
};
```

### ENUM_DECISION_STATUS
```
DECISION_BUY_CANDIDATE, DECISION_SELL_CANDIDATE,
DECISION_NO_TRADE, DECISION_DATA_UNAVAILABLE,
DECISION_NEWS_BLOCKED, DECISION_RISK_REJECTED,
DECISION_CONFLICTED_SIGNAL, DECISION_SETUP_EXPIRED,
DECISION_SETUP_INVALIDATED
```

---

## CHybridRegime

### Detection
```cpp
bool Initialize();
ENUM_HYBRID_REGIME Detect(const MarketSnapshot& market, const FeatureSet& features);
```

### ENUM_HYBRID_REGIME
```
HYBRID_REGIME_TRENDING       // Strong directional bias
HYBRID_REGIME_RANGING        // Range-bound, mean reversion
HYBRID_REGIME_VOLATILITY_EXPANSION // Breakout/expansion
HYBRID_REGIME_COMPRESSION    // Volatility squeeze
HYBRID_REGIME_TRANSITION     // Regime change in progress
HYBRID_REGIME_INSUFFICIENT_DATA // Not enough history
```

---

## Enums Reference

### ENUM_TRADING_STYLE
```
STYLE_SCALPING     // M1/M5 entry, fast
STYLE_DAY_TRADING  // M15/H1 entry, intraday
STYLE_SWING_TRADING // H4/D1 entry, multi-day
```

### ENUM_BIAS_DIRECTION
```
BIAS_BULLISH, BIAS_BEARISH, BIAS_NEUTRAL, BIAS_CONFLICTED, BIAS_INSUFFICIENT_DATA
```

### ENUM_TRADING_MODE
```
MODE_SIGNAL_ONLY   // Dashboard only (default)
MODE_AUTO          // Live trading (needs InpLiveAutoConfirm)
MODE_BACKTEST      // Strategy Tester only
```

### ENUM_LOG_LEVEL
```
LOG_ERROR, LOG_WARNING, LOG_INFO, LOG_SIGNAL, LOG_TRADE, LOG_RISK, LOG_DEBUG, LOG_OPTIMIZATION
```

### ENUM_ALERT_SEVERITY
```
ALERT_INFO, ALERT_WARNING, ALERT_CRITICAL
```

### ENUM_ATTEMPT_ACTION
```
ATTEMPT_ENTRY, ATTEMPT_MODIFY, ATTEMPT_CLOSE, ATTEMPT_RETRY
```

---

## Error Codes (MQL5 TRADE_RETCODE)

Common codes handled explicitly:
```
TRADE_RETCODE_DONE (0)           // Success
TRADE_RETCODE_REQUOTE (10004)    // Requote - retry with new price
TRADE_RETCODE_REJECT (10006)     // Rejected - check reason
TRADE_RETCODE_TIMEOUT (10007)    // Timeout - reconcile
TRADE_RETCODE_INVALID_VOLUME (10013)
TRADE_RETCODE_INVALID_STOPS (10014)
TRADE_RETCODE_NO_MONEY (10019)   // Insufficient margin
TRADE_RETCODE_PRICE_CHANGED (10020)
TRADE_RETCODE_PRICE_OFF (10021)
TRADE_RETCODE_HEDGE_PROHIBITED (10016)
```

---

## Version Compatibility

| Component | Min Build | Notes |
|-----------|-----------|-------|
| Core EA | 5.0.0.5370 | Requires SQLite support |
| MetricsExporter | 5.0.0.5370 | File I/O, datetime |
| ExecutionLedger | 5.0.0.5370 | SQLite3 via DLL import |
| Dashboard | 5.0.0.5370 | Chart objects |

---

## See Also

- `docs/architecture/ARCHITECTURE.md` — System architecture overview
- `docs/architecture/ADR_INDEX.md` — Architecture decision records
- `Include/AlgoSystem/Types.mqh` — Core type definitions
- `Include/AlgoSystem/HybridTypes.mqh` — Hybrid-specific types
- `Include/AlgoSystem/Constants.mqh` — Magic numbers, version, enums