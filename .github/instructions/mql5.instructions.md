---
applyTo: "**/*.mq5,**/*.mqh"
---

# AlgoMultiAssetEA — MQL5 Instructions

These rules apply to MQL5 source files in this repository.

## Before editing

Inspect only what is relevant to the change:

- current file
- related includes
- callers/dependencies when needed
- configuration
- relevant runtime flow

Do not rewrite existing logic without understanding current behavior.

## Compiler safety

Before changing a function call, inspect the actual:

- signature
- argument count
- argument types
- return type
- overloads

Never guess an MQL5 API.

## Market data

Always guard:

- insufficient bars
- unsynchronized series
- stale data
- invalid indicator handles
- CopyBuffer failures
- CopyRates failures
- invalid shifts
- invalid prices

Use closed-bar data for signal generation by default.

## Multi-symbol

The EA is multi-symbol.

Do not assume chart OnTick automatically services every managed symbol.
Consider:

- OnTimer
- per-symbol scheduling
- synchronization
- freshness
- runtime state
- closed-bar timing

## Trading and execution

Normalize prices and volumes against the actual symbol specification.

Respect:

- minimum/maximum/step volume
- digits
- tick size
- stops level
- freeze level
- trade mode
- netting/hedging

Inspect actual trade retcodes. A successful function return is not, by itself, proof that a trade was executed successfully.

## Risk

A signal never authorizes execution.

Never bypass:

- RiskEngine
- PortfolioRisk
- TradeExecutor
- loss limits
- position limits
- execution checks
- stop/target validation

If required risk cannot be calculated safely:

NO-TRADE

Never introduce martingale, uncontrolled averaging-down, implicit leverage escalation or loss-recovery sizing.

## Research / optimization

Detailed strategy-design, backtest, optimization, OOS and robustness rules live in:

`.github/skills/algo-multiasset-ea/SKILL.md`

For MQL5 source changes, follow that Skill when the task is related to strategy or risk research.

Do not add an indicator or parameter merely because one historical pass improves.

## Testing

Do not claim compile, runtime, backtest, optimization or OOS success without actual evidence.

Keep execution evidence separate from static reasoning.
