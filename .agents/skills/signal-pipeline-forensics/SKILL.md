---
name: signal-pipeline-forensics
description: Debug signal rejection/missing orders, trace pipeline, apply first-failure semantics, reconcile telemetry with config.
argument-hint: Describe symbol, timeframe, run/logs, rejection reason suspected, or missing trades.
---
# signal-pipeline-forensics

## Pipeline Trace
- Upstream skips -> strategy evaluation -> candidate creation -> conflict arbitration -> RiskEngine -> PortfolioRisk -> trading permission -> TradeExecutor -> display
- Apply first-failure: only report reason when that condition actually executed and failed.

## Investigation
- Count actual log events with denominators.
- Distinguish missing telemetry from genuine rejection.
- Reconcile RunID, symbol, TF, timestamps, source/EX5 identity, config.
- Avoid speculative causes.
- Diagnostics only; preserve behavior.

## Evidence
- File/function/line, actual values, log excerpts, unresolved unknowns.
- Never treat candidate as proof of approval/execution/trade.

## Hybrid Lifecycle Forensics
- Trace Context/Structure/Setup/Entry inputs and their actual data sources.
- Verify data freshness, snapshot validity, role/timeframe provenance and setup revalidation.
- Trace Setup identity and lifecycle state through the entry handoff.
- Trace structural invalidation from producer to gate.
- Trace News, Risk, PortfolioRisk and Execution gates in actual order.
- Distinguish candidate detection, setup approval, risk approval, request submission, and broker-confirmed execution.
- Do not infer rejection from missing telemetry or report a condition as the cause unless the condition actually executed and failed.
- Use exact file/function/line and real log evidence where available.
- Never claim a trade occurred based only on a candidate or TradePlan.

