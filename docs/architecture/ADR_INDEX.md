# ADR Index — Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| ADR-001 | Four Independent Timeframe Roles | Accepted | 2026-10-21 |
| ADR-002 | Setup Independence from Structure | Accepted | 2026-10-21 |
| ADR-003 | News Fail-Closed for New Entries | Accepted | 2026-10-21 |
| ADR-004 | Signal ≠ Execution Authorization | Accepted | 2026-10-21 |
| ADR-005 | Retry Only After Proven Terminal Failure | Accepted | 2026-10-21 |
| ADR-006 | Durable Identity Separation | Accepted | 2026-10-21 |
| ADR-007 | No Auto-Completion of Partial Fills | Accepted | 2026-10-21 |
| ADR-008 | Fail-Closed on Critical Uncertainty | Accepted | 2026-11-12 |
| ADR-009 | Minimal Durable Execution Ledger Schema | Accepted | 2026-11-12 |
| ADR-010 | Durable Intent Before Submission | Accepted | 2026-11-12 |
| ADR-011 | Attempt ID: Durable Sequence + Component | Accepted | 2026-11-12 |
| ADR-012 | Chart Coordinator Election via Ledger | Accepted | 2026-11-12 |
| ADR-013 | Multi-Symbol Scheduling via Timer | Accepted | 2026-11-12 |
| ADR-014 | Prometheus File-Based Metrics Export | Accepted | 2026-11-13 |
| ADR-015 | Threshold-Based Alerting with Cooldown | Accepted | 2026-11-13 |

---

## ADR-001: Four Independent Timeframe Roles

**Status**: Accepted
**Date**: 2026-10-21

### Context
The strategy requires analysis at multiple time horizons: macro context, market structure, trade setup, and precise entry timing.

### Decision
Define four independent timeframe roles:
- **Context** (e.g., D1/W1): Macro bias, long-term trend
- **Structure** (e.g., H4/H1): Market structure, swing points, levels
- **Setup** (e.g., M15/M30): Pattern formation, candidate generation
- **Entry** (e.g., M1/M5): Precise trigger, order placement

Each role maps to configurable timeframes per trading style. Roles are **independent** — a Setup timeframe does not derive from Structure timeframe.

### Consequences
- No implicit hierarchy or derivation between roles
- Each role's indicators/features computed independently
- Configuration complexity increased (4 timeframes per symbol)
- Eliminates look-ahead bias from cross-timeframe leakage

---

## ADR-002: Setup Independence from Structure

**Status**: Accepted
**Date**: 2026-10-21

### Context
Traditional approaches often derive setup timeframe from structure timeframe (e.g., "setup on 1/4 of structure TF").

### Decision
**Setup generation is independent of Structure**. A setup candidate is valid based on its own timeframe's pattern completion, not because a structure timeframe condition is met.

### Consequences
- Setups can form on any timeframe regardless of structure TF
- Reduces missed opportunities when structure TF is unclear
- Requires explicit regime/context gating to avoid noise
- Structure provides *bias*, not *permission*

---

## ADR-003: News Fail-Closed for New Entries

**Status**: Accepted
**Date**: 2026-10-21

### Context
News events create unpredictable volatility. News provider may be unavailable, stale, or misconfigured.

### Decision
**News operational failures block new entries (fail-closed)**. Position management remains separate and continues operating.

Specifically:
- `NEWS_UNAVAILABLE` → block new entries
- `NEWS_DISABLED` (config) → block new entries
- Provider initialization failure → install NoOp provider (which returns UNAVAILABLE)
- Existing positions: managed by `PositionManager` independently

### Consequences
- Conservative: misses trades during news provider issues
- Safe: never enters blindly during high-impact events
- Position management unaffected — trailing, scaling, closing still work

---

## ADR-004: Signal ≠ Execution Authorization

**Status**: Accepted
**Date**: 2026-10-21

### Context
A signal, candidate, score, or `TradePlan` is often mistaken for execution permission.

### Decision
**No signal/candidate/TradePlan constitutes execution authorization**. Authorization requires:
1. Valid Setup (fresh, not expired/invalidated)
2. Fresh revalidation of Setup + all mandatory gates
3. RiskEngine approval (volume, SL, TP, margin)
4. PortfolioRisk approval (exposure, correlation, limits)
5. TradeExecutor submission with valid authority

### Consequences
- Multiple explicit gates between signal and broker
- Audit trail at each gate
- No "implicit allow" paths

---

## ADR-005: Retry Only After Proven Terminal Failure

**Status**: Accepted
**Date**: 2026-10-21

### Context
Network issues, broker latency, and ambiguous `OrderSend()` results create uncertainty about whether an order was placed.

### Decision
**Retry only when terminal failure is proven**. Ambiguous outcomes require reconciliation, not retry.

Specifically:
- `OrderSend()` returns `true` but no callback → **reconcile**, don't retry
- Timeout waiting for `OnTradeTransaction` → **reconcile**, don't retry
- Empty ticket in callback → **reconcile** via ledger/history
- Only retry when: `TRADE_RETCODE_REQUOTE`, `TRADE_RETCODE_TIMEOUT` (explicit), or proven rejection

### Consequences
- No duplicate orders from timeout-based retries
- Requires durable ledger for reconciliation
- Slightly slower recovery from genuine transient failures

---

## ADR-006: Durable Identity Separation

**Status**: Accepted
**Date**: 2026-10-21

### Context
Correlating signals → orders → deals → positions requires stable identifiers.

### Decision
Keep these identities **distinct and separate**:
- `setup_id` — UUID per signal candidate (durable)
- `attempt_id` — Durable sequence + component per submission intent
- Order ticket — Broker-assigned, ephemeral
- Deal ticket — Broker-assigned, ephemeral
- Position identifier — Broker-assigned, persistent while open

**Never** use `Symbol + Magic + Time` or comment matching as proof of identity.

### Consequences
- Ledger schema stores all IDs explicitly
- Reconciliation uses broker identifiers first, durable IDs as fallback
- No ambiguity in partial fill / multi-attempt scenarios

---

## ADR-007: No Auto-Completion of Partial Fills

**Status**: Accepted
**Date**: 2026-10-21

### Context
Partial fills leave remaining volume. Auto-resubmission risks over-exposure.

### Decision
**Partial fill ≠ full fill**. Remaining volume:
- Stays as pending in `ExecutionLedger` (status = PARTIAL)
- Requires explicit human or fresh-signal authorization to complete
- `PositionManager` tracks actual position size, not requested size

### Consequences
- Prevents accidental over-leveraging
- Manual intervention required for remainder
- Clear audit trail of requested vs executed

---

## ADR-008: Fail-Closed on Critical Uncertainty

**Status**: Accepted
**Date**: 2026-11-12

### Context
Critical system components (risk, persistence, schema, broker connectivity) can enter uncertain states.

### Decision
**Fail closed** (block new entries) on:
- Risk engine unavailable or returns error
- ExecutionLedger schema migration failed
- Database corruption detected
- Broker/ledger reconciliation uncertainty
- Critical configuration validation failure

**Position management continues** — only new entries blocked.

### Consequences
- Trading stops during infrastructure issues
- Prevents undefined behavior
- Requires monitoring/alerting to detect fail-closed state

---

## ADR-009: Minimal Durable Execution Ledger Schema

**Status**: Accepted
**Date**: 2026-11-12

### Context
Need durable tracking of execution intent → attempt → outcome for reconciliation and audit.

### Decision
Two-table minimal schema:

```sql
setups (setup_id PK, strategy_group, logical_key, symbol, style, regime, bias, created_at, expired_at, status, payload_json)
attempts (attempt_id PK, setup_id FK, strategy_group, logical_key, action_type, requested_vol, requested_sl, requested_tp, status, broker_ticket, deal_ticket, position_id, created_at, submitted_at, resolved_at, retcode, retcode_ext, volume_filled, error_json)
```

Indexes: `setups(strategy_group, logical_key)`, `attempts(setup_id)`, `attempts(broker_ticket)`.

### Consequences
- SQLite-backed, single file per account
- Schema versioning via `PRAGMA user_version`
- Migration scripts for schema changes
- Queries optimized for reconciliation paths

---

## ADR-010: Durable Intent Before Submission

**Status**: Accepted
**Date**: 2026-11-12

### Context
Order submission can fail after intent is formed. Without durable record, restart loses context.

### Decision
**Durable intent must be confirmed before submission**:
1. Create `Attempt` record in ledger (status = PENDING)
2. Flush to disk (SQLite transaction commit)
3. Only then call `TradeExecutor.Execute()`
4. On success: update attempt with broker ticket
5. On failure: update attempt with retcode

### Consequences
- Every submission attempt is auditable
- Restart can reconcile in-flight attempts
- SQLite durability guarantees required (WAL mode, synchronous=FULL)

---

## ADR-011: Attempt ID: Durable Sequence + Component

**Status**: Accepted
**Date**: 2026-11-12

### Context
Need globally unique attempt IDs across restarts, charts, and accounts.

### Decision
`attempt_id` = `<durable_sequence>_<component_hash>`

- **Durable sequence**: Monotonically increasing integer stored in ledger (survives restart)
- **Component hash**: Hash of `(strategy_group, logical_key, action_type, timestamp_ms)`

Format: `ATT_<sequence>_<hash8>`

### Consequences
- No collision across charts/restarts
- Sequence provides ordering
- Component provides context for debugging

---

## ADR-012: Chart Coordinator Election via Ledger

**Status**: Accepted
**Date**: 2026-11-12

### Context
Multiple charts on same account need coordination for multi-symbol processing.

### Decision
**Single coordinator elected via `ExecutionLedger` authority**:
- `AcquireAuthority(key, token, epoch)` — atomic compare-and-swap
- `HeartbeatAuthority(key, token, epoch)` — periodic validation
- `ValidateAuthority(key, token, epoch)` — read-only check
- Coordinator processes all symbols; contexts forward user actions

### Consequences
- No external lock service needed
- Automatic failover on coordinator loss
- Authority epoch prevents split-brain

---

## ADR-013: Multi-Symbol Scheduling via Timer

**Status**: Accepted
**Date**: 2026-11-12

### Context
`OnTick()` only fires for the EA's chart symbol.

### Decision
**5-second `OnTimer()` drives multi-symbol processing**:
- Coordinator: loops all `g_runtime` symbols, calls `ProcessRuntime()`
- Contexts: receive snapshots via chart messages, update dashboard
- Discovery: Coordinator enumerates charts every 5s via `EventChartCustom()`

### Consequences
- Fixed 5s latency for non-chart symbols
- No background threads (MQL5 limitation)
- Timer also runs reconciliation, state refresh, metrics flush

---

## ADR-014: Prometheus File-Based Metrics Export

**Status**: Accepted
**Date**: 2026-11-13

### Context
Need observability without external dependencies (no HTTP server in MQL5).

### Decision
**File-based Prometheus text format export**:
- Write to `AlgoSystem/Metrics/metrics_<chart_id>.prom`
- External Promtail/Filebeat scrapes file
- 10-second flush interval (configurable)
- Instance label for multi-chart differentiation

### Consequences
- Zero network dependencies in EA
- Standard Prometheus ecosystem compatibility
- File I/O overhead minimal (small text file, 10s interval)

---

## ADR-015: Threshold-Based Alerting with Cooldown

**Status**: Accepted
**Date**: 2026-11-13

### Context
Need operator notification for critical conditions without alert fatigue.

### Decision
**Threshold-based alerts with per-category cooldown**:
- Severity: INFO, WARNING, CRITICAL
- Categories: MARGIN, DAILY_LOSS, DRAWDOWN, SPREAD, POSITIONS, NEWS, EXECUTION, CONNECTION, RISK
- Default cooldown: 60 seconds per category
- Delivery: Chart `Comment()` + `Alert()` popup for CRITICAL
- Structured logging via `CAlgoLogger`

### Consequences
- No external notification service required
- Cooldown prevents spam during sustained conditions
- Critical alerts visible even if chart minimized