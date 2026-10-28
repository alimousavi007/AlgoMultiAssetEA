---
name: algo-multiasset-ea
description: Project-wide engineering context and safety contracts for AlgoMultiAssetEA. Use when a task spans modules, changes architecture or strategy behavior, or requires deciding which project-specific engineering, lifecycle, risk, forensics, tester, research, or Git workflow applies.
---

# AlgoMultiAssetEA — Project Contract

## Purpose and scope

Use this Skill for shared project facts and cross-cutting constraints. Load a specialist Skill only when its domain materially applies:

- `engineering`: implementation, bug fixes, refactors, compile/runtime diagnosis, code review.
- `hybrid-strategy-lifecycle`: four-role signal context, setup lifecycle, freshness, invalidation, execution attempts and reconciliation.
- `trading-risk`: risk decisions, exposure, limits, locks, sizing and execution safety.
- `signal-pipeline-forensics`: missing/rejected signals, missing orders, telemetry and event traces.
- `mt5-strategy-tester`: MT5 terminal/tester launch, test configuration and evidence collection.
- `research-optimization`: hypotheses, optimization, OOS/forward validation and robustness.
- `delivery-git`: status/diff review and explicitly authorized Git delivery.

Do not load every Skill by default. Avoid repeating a completed audit unless new evidence or a changed target warrants it.

## Source-of-truth discipline

1. Inspect the current source, callers, settings and logs before asserting behavior. Names, comments, reports and intended architecture are not proof of runtime behavior.
2. Distinguish `VERIFIED`, `OBSERVED`, `INFERRED`, `ASSUMED` and `UNVERIFIED`.
3. Cite file/function/line and the specific evidence for consequential findings. Prefer the earliest demonstrated failure over speculative downstream causes.
4. Never invent API behavior, broker behavior, data, tests, compile results or optimization outcomes.
5. When repository state and an older report disagree, verify current state and preserve the user's changes.

## Architecture facts and decision boundaries

- The active Hybrid design has four independent timeframe roles: **Context, Structure, Setup and Entry**. Setup is conceptually independent from Structure even when their configured timeframes happen to match.
- The exact role-to-timeframe mapping is not to be inferred from legacy SCALP/DAY/SWING mappings. Verify current approved decision records and implementation before changing it.
- The accepted data policy is closed-bar inputs for Context/Structure/Setup; Scalping Entry may use tick/live quote data; Day/Swing Entry uses closed-bar data. Do not silently generalize a role policy to another profile.
- Before submit, revalidate the setup, relevant data freshness, News gate and Risk gate. A detected candidate or valid `TradePlan` is not trade authorization.
- News operational failure blocks new entries (fail-closed); position management remains separate. Distinguish `NEWS_DISABLED`, operational unavailability and a valid no-event result.
- Retry only after a proven terminal failure. Timeout, missing response, absent broker evidence or an intent record alone does not prove that submission did not happen. Ambiguous outcomes require reconciliation.
- Persistent execution identity and reconciliation are prerequisites for dependable restart-safe operation. Keep `setup_id`, `attempt_id` and broker ticket/identifier distinct.
- The storage direction is internal SQLite, with a single-writer ownership model. Do not claim MQL5/SQLite durability guarantees without specific implementation evidence.
- Recovery must fail safe when the ledger is missing/inaccessible, schema is unsupported, migration is interrupted, corruption is detected, or writes/commits fail. An unresolved attempt or broker/ledger disagreement requires reconciliation. Do not automatically complete a partial fill.
- Attempt identity must exist before submission and be recoverable after restart; a volatile-only identifier is insufficient.
- Use the latest approved decision record for detailed expiry/invalidation predicates, News parameters and timestamp handling. If exact values or semantics are absent, preserve `UNDECIDED`/`UNKNOWN`; do not invent them.

## Strategy and feature inventory

The repository has components for Trend/Pullback, Breakout, Momentum, Mean Reversion and a separate Relative Value component. Do not assume a component is in the active signal path without tracing its callers. Relative Value is multi-leg and must not be treated as a standard single-leg `StrategySignal` unless the implementation proves that contract. The feature layer has included EMA, ADX, ATR, RSI, MACD, ROC, volume-ratio and candle/volatility features; verify the current source/configuration before asserting this inventory or adding a substitute. Configured symbols and profiles are mutable and must be checked in the active settings.

## Trading safety

- A signal is not permission to trade. Trace the actual authorization path before changing its order or semantics.
- Never bypass or weaken `CRiskEngine`, `CAlgoPortfolioRisk` and `CTradeExecutor`, nor any verified loss, position, exposure, margin, stop/target, spread or execution gate.
- Critical missing, stale, invalid or contradictory evidence must not become an executable entry. Prefer the established fail-closed behavior for the affected scope and reconcile uncertainty before retrying.
- Do not introduce martingale, uncontrolled averaging-down, loss-recovery sizing, implicit leverage escalation or unbounded retries.
- Claim correlation-aware limits only if the current implementation computes and uses correlation in the relevant decision path.

## Engineering and operation boundaries

- Understand → trace → plan → minimal change → verify → report.
- Preserve interfaces and established architecture. Do not add abstractions, indicators, parameters or scoring layers without a concrete need and a testable benefit.
- Source edits, compile, terminal launch, Strategy Tester, runtime/broker operations, Git stage/commit and push are separate actions. Perform only actions requested and authorized for the current task; explicit permission for one does not imply permission for the others.
- Never perform destructive Git cleanup or rewrite history. Review status and diff before delivery.
- A compile, historical test, OOS/forward run and live result are different evidence classes. Never present one as another.

## Reporting

For engineering/forensics: `FINDING`, `EVIDENCE`, `ROOT CAUSE`, `CHANGE`, `VERIFICATION`, `REMAINING RISK`.
For research: `BASELINE`, `HYPOTHESIS`, `EXPERIMENT`, `RESULT`, `OOS/FORWARD`, `ROBUSTNESS`, `DECISION`, `REMAINING RISK`.

Keep reports concise and decision-oriented. State blockers and unknowns directly; do not claim completion of a tool action that did not run.
