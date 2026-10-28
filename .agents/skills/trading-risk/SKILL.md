---
name: trading-risk
description: Review or change AlgoMultiAssetEA account sizing, stops/targets, loss/position limits, locks, portfolio exposure/concentration, margin and execution gates; prioritize fail-safe behavior and evidence of the real enforcement path.
---

# Trading Risk & Execution Safety

Use with `algo-multiasset-ea`; use `hybrid-strategy-lifecycle` for setup/attempt reconciliation and `signal-pipeline-forensics` for observed rejection paths.

## Authority principle

`SIGNAL ≠ TRADE AUTHORIZATION`. Inspect actual callers and control flow before relying on a risk class, flag, comment or rejection enum. Never bypass or weaken the verified responsibilities of `CRiskEngine`, `CAlgoPortfolioRisk` or `CTradeExecutor`.

If critical risk evidence is missing, invalid, stale or contradictory, do not allow the affected entry to proceed. Follow the current approved lock/blocking scope; if it cannot be bounded, escalate conservatively and document why.

## Risk review sequence

`BASELINE → ACTUAL GATE TRACE → FAILURE MODES → MINIMAL CHANGE → SAFETY REVIEW → AUTHORIZED VERIFICATION`

Check only components relevant to the target, including:

- account equity/balance and monetary-risk basis;
- stop distance and account-currency loss estimate;
- broker volume minimum/maximum/step/limit and risk-preserving rounding;
- stop/target legality and reward/risk criteria;
- margin pre-check and current trading/symbol permissions;
- loss, position and portfolio limits;
- concentration/exposure and correlation only if actually computed and consumed;
- execution response, partial fill and unresolved-attempt handling;
- position management and recovery-state integrity.

Do not assume the code's order of gates from this list: trace the actual path and report its order.

## Forbidden risk patterns

Do not introduce martingale, uncontrolled averaging-down, loss-recovery sizing, implicit leverage escalation, unbounded retries, or an upward volume adjustment that exceeds the computed risk budget.

Risk multipliers must be bounded, interpretable and tested separately. Do not let risk optimization conceal a weak signal model or treat a correlation-based claim as true without implementation evidence.

## Relevant failure scenarios

Select scenarios relevant to the change: normal approval; each expected rejection; external/state lock; invalid or stale data; unknown symbol constraints; invalid volume/SL/TP; margin failure; spread/execution rejection; portfolio limit; duplicate submission; timeout/ambiguous result; partial fill; restart with missing ledger; ledger/broker disagreement.

Reasoning about a scenario is not a test. Execute tests only when explicitly authorized and available.

## Retry and reconciliation

A retry is permitted only after a proven terminal failure. A request Boolean, retcode in isolation, timeout, missing ticket or temporarily absent position is not enough. Inspect the documented API result and any broker history/transaction evidence. If submission may have occurred, require reconciliation before another submit. Do not auto-complete a partial fill.

## Evidence and report

Distinguish `VERIFIED`, `OBSERVED`, `INFERRED`, `ASSUMED`, `UNVERIFIED`. Report the current enforcement path, exact values/configuration, root cause, smallest safe change, authorized verification, risk scenarios not checked and remaining risk. Never equate a plausible risk-control explanation with proof the runtime path enforces it.
