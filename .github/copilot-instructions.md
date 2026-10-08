# AlgoMultiAssetEA — Copilot Instructions

This repository is an existing MQL5/MetaTrader 5 multi-asset algorithmic trading system.

Treat repository code and verified runtime/test evidence as the source of truth.

## Core priorities

CORRECTNESS > RISK CONTROL > EVIDENCE > OOS VALIDATION > ROBUSTNESS > REPRODUCIBILITY > AUDITABILITY > PERFORMANCE > COMPLEXITY

## Always

- Inspect current code and relevant dependencies before editing.
- Preserve existing architecture unless redesign is explicitly requested.
- Make the smallest justified change.
- Preserve user changes and review the diff.
- Never invent APIs, broker behavior, test results, optimization results or runtime behavior.
- Use closed-bar data for signal generation by default.
- Treat a signal as non-authorizing until risk and execution gates approve it.

## Trading safety

Never bypass:

- RiskEngine
- PortfolioRisk
- TradeExecutor
- loss limits
- position limits
- execution validation
- stop/target validation

If required risk information is unsafe or unavailable: NO-TRADE.
If critical runtime information is uncertain: SIGNAL-ONLY or DIAGNOSTIC.

## Multi-symbol MQL5

Respect indicator handles, CopyBuffer, CopyRates, synchronization, data freshness, symbol properties, price/volume normalization, stops/freeze levels, netting/hedging, tester/live differences and trade retcodes.

Do not assume chart OnTick automatically services all managed symbols; consider OnTimer and per-symbol runtime state.

## Research / optimization

For non-trivial trading research, use the project AlgoMultiAssetEA skill in `.github/skills/algo-multiasset-ea/SKILL.md`.

Do not add indicators or optimize parameters merely because a historical result improves. Require a measurable hypothesis, controlled experiment and unseen-data validation.

## Verification

Never claim compiled, tested, backtested, optimized, OOS-validated or runtime-verified without actual evidence.

Distinguish:
VERIFIED / OBSERVED / INFERRED / ASSUMED / UNVERIFIED

## Git

Do not reset, clean, rewrite history or force-push unless explicitly instructed.
