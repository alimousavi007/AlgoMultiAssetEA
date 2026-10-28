---
name: signal-pipeline-forensics
description: Diagnose missing, rejected, duplicated or displayed-but-not-executed AlgoMultiAssetEA signals by tracing actual pipeline gates, event logs, configuration and broker evidence without changing behavior.
---

# Signal Pipeline Forensics

This is a diagnostic, read-only workflow unless the user separately asks for a fix. Use with `algo-multiasset-ea`; load `hybrid-strategy-lifecycle` for Hybrid setup/attempt/reconciliation questions.

## Trace the real path

Start from the user's observed symptom, then trace only relevant modules through the actual implementation. Candidate stages may include:

`SCHEDULER/DATA → FEATURE/STRATEGY EVALUATION → CANDIDATE → CONFLICT ARBITRATION → RISK → PORTFOLIO/TRADE PERMISSION → PRE-SUBMIT GATES → TRADE EXECUTOR → BROKER EVENTS → DISPLAY/TELEMETRY`

This is a search guide, not a claim that every build has exactly this ordering. Verify the producer, consumer, callers and actual order in source.

## First-failure semantics

- Report a condition as the cause only when evidence shows the condition was evaluated and failed in that execution path.
- A configured blocker, enum value, log label or comment is not proof the branch ran.
- Missing telemetry is not proof that a gate rejected the signal; lack of a trade is not proof that no signal existed.
- Preserve all relevant denominators: evaluated candidates, rejected candidates by confirmed gate, submit attempts, broker outcomes and displayed items. State the population/time window behind each count.
- Distinguish candidate detection, setup approval, risk approval, request submission, order acceptance, deal execution, position state and UI display.

## Correlate evidence

Match available evidence using RunID, symbol, role/timeframe, setup ID, attempt ID, magic, order/deal/position identifiers, source/EX5 identity, configuration, and timestamps. Check timezones and event ordering. Treat a field as useful only if it is actually emitted and its semantics are verified.

For multi-symbol behavior, inspect event scheduling and data readiness; do not assume chart-symbol `OnTick` proves every managed symbol was evaluated. For indicator paths, confirm history readiness, copied counts, shift/index alignment and freshness.

## Hybrid and execution investigation

- Trace Context/Structure/Setup/Entry inputs and provenance separately.
- Trace setup lifecycle and pre-submit revalidation through the actual consumers.
- Trace News, Risk, PortfolioRisk and TradeExecutor in their observed order.
- Treat timeouts, absent callbacks or missing position evidence as unresolved unless terminal failure is independently proven.
- Correlate execution with broker order/deal/history/position evidence; never infer a trade from a candidate or `TradePlan` alone.
- If ledger and broker disagree, report the reconciliation gap; do not recommend blind retry.

## Output

For each finding include: severity, exact file/function/line, observed evidence (log excerpts and actual values), expected behavior, confirmed vs possible cause, alternative explanations, missing telemetry/evidence and the narrowest next diagnostic step.

Keep diagnosis separate from remediation. Do not change strategy or risk behavior merely to make logs or dashboard output look correct. Do not state runtime truth from static source alone.
