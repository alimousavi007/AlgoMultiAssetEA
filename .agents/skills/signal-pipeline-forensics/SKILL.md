---
name: signal-pipeline-forensics
description: Debug signal rejection/missing orders, trace pipeline, apply first-failure semantics, reconcile telemetry with config.
argument-hint: Describe symbol, timeframe, run/logs, rejection reason suspected, or missing trades.
---
# signal-pipeline-forensics

## Pipeline Trace
- Upstream skips → strategy evaluation → candidate creation → conflict arbitration → RiskEngine → PortfolioRisk → trading permission → TradeExecutor → display
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
