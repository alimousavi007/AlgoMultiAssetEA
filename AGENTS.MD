# AlgoMultiAssetEA — Project Instructions

## Project Identity

This repository contains AlgoMultiAssetEA, an existing MQL5/MetaTrader 5 multi-asset algorithmic trading system.

Treat this as a real existing codebase, not as a greenfield coding exercise.

## Mission

Understand the existing implementation, preserve valid work, make the smallest justified change, verify it with real evidence, and document the result.

Priority:

CORRECTNESS
>
RISK CONTROL
>
REPRODUCIBILITY
>
ROBUSTNESS
>
OOS VALIDATION
>
AUDITABILITY
>
PERFORMANCE
>
COMPLEXITY

## Default Workflow

Always follow:

UNDERSTAND
→ CLASSIFY
→ INVENTORY
→ PLAN
→ EXECUTE
→ VERIFY
→ REPORT

For existing code, default to:

PRESERVE
→ UNDERSTAND
→ VERIFY
→ MINIMALLY PATCH
→ REGRESSION TEST
→ DOCUMENT

Do not redesign a working subsystem merely because another design appears cleaner.

## Evidence Discipline

Never claim that something:

- compiled
- passed
- backtested
- optimized
- works at runtime
- is broker compatible
- was verified

unless actual evidence exists.

Use these evidence states when appropriate:

VERIFIED
OBSERVED
INFERRED
ASSUMED
UNVERIFIED

Clearly distinguish facts from assumptions and inference.

If verification is unavailable, explicitly say so.

## Repository First

Before modifying code:

1. Inspect the relevant implementation.
2. Trace callers and dependencies.
3. Inspect related types and interfaces.
4. Understand the current runtime path.
5. Identify the root cause.
6. Identify the smallest safe change.
7. Inspect the git state when relevant.

Do not invent missing files, APIs, capabilities, broker behavior, or test results.

## Existing Architecture

Preserve the conceptual architecture:

MarketData
→ Features
→ Regime
→ Strategies
→ SignalEngine
→ TradeFilters
→ RiskEngine
→ PortfolioRisk
→ TradeExecutor
→ PositionManager

Supporting systems include:

StateManager
Logger
Dashboard
Statistics
Testing
Optimization
WFO
Robustness
Configuration

Strategies should remain signal-oriented.

TradeExecutor is the execution boundary.

Do not allow individual strategies to bypass the execution boundary.

## Trading Safety

Never:

- enable live trading implicitly
- trade invalid or stale market data
- trade when risk cannot be calculated safely
- bypass risk controls
- ignore trade retcodes
- assume broker capabilities
- use unbounded retries
- create duplicate execution
- hide critical failures
- bypass position limits
- bypass portfolio limits

When critical uncertainty exists, prefer:

NO-TRADE
or
SIGNAL-ONLY
or
DIAGNOSTIC

## MQL5 Rules

Respect:

- MQL5 types
- function signatures
- enums
- structs
- classes
- object lifetime
- include dependencies
- event-driven execution
- OnInit
- OnTick
- OnTimer
- OnTradeTransaction
- OnDeinit
- indicator handles
- CopyBuffer
- CopyRates
- symbol synchronization
- symbol properties
- digits
- point size
- tick size
- volume minimum
- volume maximum
- volume step
- stops level
- freeze level
- netting
- hedging
- tester/live differences
- trade server retcodes

Never invent an MQL5 API.

## Multi-Symbol Runtime

The system manages multiple symbols.

Do not assume that an OnTick event for the chart symbol is sufficient to service every managed symbol.

Explicitly consider:

- scheduling
- OnTimer
- per-symbol processing
- data synchronization
- data freshness
- bar availability
- runtime state isolation

## Market Data

Guard against:

- insufficient bars
- unsynchronized series
- stale data
- invalid indicator handles
- CopyBuffer failure
- CopyRates failure
- invalid shifts
- invalid prices
- invalid volumes

Signal logic should normally use closed candles unless the strategy explicitly requires otherwise.

## Risk

Risk safety has priority over signal generation.

A valid signal is not permission to trade.

Conceptual flow:

TradingAllowed
→ Loss Limits
→ Spread
→ Session
→ Position Limits
→ Portfolio Risk
→ Correlation
→ Stop Loss
→ Risk Amount
→ Volume
→ Margin
→ Execution

Risk failure means NO-TRADE.

## Signal Identity

Use deterministic signal identity where applicable.

Default concept:

Symbol + StrategyID + Timeframe + ClosedBarTime

## State

State reconstruction should safely handle:

- open positions
- account state
- historical trades
- restarts
- netting
- hedging
- duplicate execution prevention

## Logging

Critical paths must not fail silently.

Prefer structured, searchable and auditable diagnostics.

Important events should expose enough information to diagnose:

- symbol
- timeframe
- strategy
- signal ID
- result
- reason
- error code
- trade retcode
- relevant values

Do not create unnecessary log noise.

## Dashboard

The dashboard is observational only.

It must not influence trading decisions.

For multi-symbol processing, avoid one runtime instance unintentionally overwriting another runtime instance's display state.

## Optimization

Do not confuse a log level such as LOG_OPTIMIZATION with the complete optimization subsystem.

Optimization must remain compatible with:

- Strategy Tester
- fitness
- in-sample validation
- out-of-sample validation
- walk-forward testing
- robustness analysis

Do not generate excessive per-pass logging.

## Testing

Preferred validation sequence:

Compile
→ Functional Checks
→ In-Sample
→ Out-of-Sample
→ Walk-Forward
→ Robustness
→ Controlled Runtime Verification

Compilation alone is not proof of trading-system correctness.

## Change Discipline

Every meaningful change should answer:

1. What is wrong?
2. Why is it happening?
3. What is the smallest safe fix?
4. What files/functions need to change?
5. How will it be verified?
6. What could regress?

Prefer local fixes over broad rewrites.

Do not refactor unrelated code.

## Git Safety

Never automatically:

- git reset
- git clean
- delete unrelated files
- rewrite history
- force-push

unless explicitly instructed.

Preserve user changes.

## Reporting

Finish meaningful work with:

### FINDING

What was discovered.

### ROOT CAUSE

Why it happens.

### CHANGE

What was changed.

### VERIFICATION

What was actually verified.

### REMAINING RISK

What remains unverified or potentially risky.

Never hide uncertainty.