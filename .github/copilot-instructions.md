# AlgoMultiAssetEA — Copilot Instructions

This repository is an existing MQL5/MetaTrader 5 multi-asset algorithmic trading system.

Treat repository code as the source of truth.

## Core Priorities

CORRECTNESS > RISK CONTROL > REPRODUCIBILITY > ROBUSTNESS > OOS VALIDATION > AUDITABILITY > PERFORMANCE > COMPLEXITY

## Engineering Rules

Before editing:

1. Inspect the current implementation.
2. Inspect relevant dependencies and callers.
3. Understand the current behavior.
4. Identify the root cause.
5. Make the smallest justified change.
6. Verify the change with actual evidence.

Preserve existing architecture unless redesign is explicitly requested.

Do not invent APIs, broker capabilities, runtime behavior, compiler results, backtest results, or optimization results.

## MQL5

Respect:

- MQL5 types and signatures
- indicator handles
- CopyBuffer
- CopyRates
- series synchronization
- symbol properties
- price normalization
- volume normalization
- stops/freeze levels
- netting/hedging
- tester/live differences
- server retcodes
- event-driven execution

Do not assume one chart OnTick services all managed symbols.

Use closed candles for signal generation by default.

## Trading Safety

A signal does not authorize execution.

Never bypass:

- RiskEngine
- PortfolioRisk
- TradeExecutor
- position limits
- loss limits
- execution checks

If risk cannot be calculated safely:

NO-TRADE

If critical runtime information is uncertain:

SIGNAL-ONLY or DIAGNOSTIC

## Verification

Never claim:

- compiled
- tested
- backtested
- optimized
- runtime verified

without real evidence.

Clearly separate:

VERIFIED
OBSERVED
INFERRED
ASSUMED
UNVERIFIED

## Git

Preserve user changes.

Do not perform destructive git operations unless explicitly requested.

Review the diff before broad changes.