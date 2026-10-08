---
name: algo-multiasset-ea
description: Project skill for AlgoMultiAssetEA, an MQL5 multi-asset trading system. Use for MQL5 engineering, debugging, strategy design, SCALP/DAY/SWING research, backtesting, optimization, OOS/forward validation, robustness testing, risk/capital management, and verification.
argument-hint: Describe the task, strategy, profile, test, optimization, or verification objective.
---

# AlgoMultiAssetEA Project Skill

## 1. Mission

Build and maintain a simple, robust, reproducible multi-asset algorithmic trading system.

The objective is NOT maximum historical profit.

The objective is a trading model whose logic, risk controls, and parameter choices remain defensible on unseen data and under realistic execution assumptions.

Priority:

CORRECTNESS
> RISK CONTROL
> EVIDENCE
> OOS VALIDATION
> ROBUSTNESS
> REPRODUCIBILITY
> AUDITABILITY
> PERFORMANCE
> COMPLEXITY

## 2. Working Principle

Treat the existing repository as the source of truth.

Engineering:

UNDERSTAND
→ TRACE
→ PLAN
→ CHANGE
→ VERIFY

Research:

BASELINE
→ HYPOTHESIS
→ EXPERIMENT
→ OOS/FORWARD
→ ROBUSTNESS
→ DECISION

Never invent source behavior, API capabilities, broker behavior, test results, or optimization results.

## 3. Current Architecture

The EA is multi-symbol and currently works with configured XAU, XAG and BTC symbols.

Profile timeframes:

SCALP: M15 structure → M5 signal → M1 entry
DAY:   H4 structure  → H1 signal → M15 entry
SWING: D1 structure  → H4 signal → H1 entry

Current feature layer includes:

EMA, ADX, ATR, RSI, MACD, ROC, volume ratio, candle/volatility features.

Current strategy layer includes:

Trend/Pullback
Breakout
Momentum
Mean Reversion

Relative Value exists as a separate multi-leg component and must not be treated as a normal single-leg StrategySignal without verifying the actual implementation.

The project also contains dedicated risk, portfolio-risk, tester-fitness, statistics and optimization components.

Inspect their actual behavior before extending them.

## 4. MQL5 Rules

Follow repository-specific MQL5 implementation rules in:

`.github/instructions/mql5.instructions.md`

Project-level requirements:

- Use closed-bar data for signal generation by default.
- Treat synchronization, sufficient history and data freshness as runtime readiness conditions.
- Do not assume chart OnTick services every managed symbol.
- Respect event-driven execution, tester/live differences and actual trade retcodes.
- Do not infer implementation behavior from names alone.

## 5. Trading Safety

A signal is NOT permission to trade.

Preserve the actual risk and execution gates implemented by the project:

TradingAllowed
→ Loss Limits
→ Spread / Execution Quality
→ Session
→ Position Limits
→ Portfolio Risk
→ Concentration / other verified portfolio checks
→ Stop Loss
→ Monetary Risk
→ Volume
→ Margin
→ TradeExecutor

Never bypass:

- RiskEngine
- PortfolioRisk
- TradeExecutor
- loss limits
- position limits
- execution checks
- stop/target validation

Never ignore execution retcodes.
Never trade stale or invalid data.
Never create duplicate execution.

If required risk information is unsafe or unavailable:

NO-TRADE

If critical runtime information is uncertain:

SIGNAL-ONLY or DIAGNOSTIC

Never introduce martingale, uncontrolled averaging-down, loss-recovery sizing, or unbounded risk escalation.

Do not claim correlation-aware risk unless the code actually computes and uses it.

## 6. Strategy Design

Treat SCALP, DAY and SWING as separate research models.

Do not assume one parameter set is appropriate for all profiles.

Research strategies independently before combining them:

- Trend/Pullback
- Breakout
- Momentum
- Mean Reversion

A combined portfolio result must not hide a strategy with no independent edge.

The system should support a valid NO-TRADE outcome.

Prefer decision structure such as:

Setup Quality
+
Regime Fit
+
Execution Quality
→
Signal Quality

but do not add new scoring layers unless their incremental value is testable.

## 7. Indicator / Feature Research

Existing features are the baseline.

New candidates such as:

VWAP
Bollinger Band Width
Donchian-style structure
Relative Volume
Spread/ATR
Chandelier-style exits

are hypotheses only.

Before adding a feature ask:

1. Is the information already represented by an existing feature?
2. Can its contribution be measured independently?
3. Does it improve OOS, not only IS?
4. Is the benefit stable across nearby parameter values?
5. Does it improve risk-adjusted behavior?
6. Does it generalize across assets or regimes?

Do not add indicators merely to increase signal complexity.

## 8. Optimization Method

Do not optimize everything at once.

Default order:

REGIME
→ ENTRY
→ EXIT
→ FILTERS
→ RISK

Keep optimization groups small, normally around 4–7 active parameters unless evidence justifies more.

For every optimization record:

- profile
- strategy
- parameter names
- start/step/stop
- data period
- tester model
- spread/commission assumptions
- fitness criterion
- acceptance gates

The existing EA has a controlled optimization surface and custom Tester Fitness.

Inspect the actual implementation before expanding it.

### Stable Region Rule

Do not promote a single isolated optimization peak.

Prefer a plateau where nearby parameter values remain acceptable for:

- performance
- drawdown
- trade count
- consistency

If the result collapses when a parameter moves slightly, treat it as fragile.

## 9. Backtest Standard

Before optimization:

1. Compile the EA.
2. Run a baseline with Optimization OFF.
3. Use `InpMode = MODE_BACKTEST` for trade/P&L testing.
4. Keep the remaining inputs unchanged for the baseline.
5. Record tester settings and EA inputs.
6. Inspect Journal/Experts output for data or runtime problems.

For final historical testing prefer:

Every tick based on real ticks

Use visualization only for short diagnostic tests.
Do not use visualization for normal optimization runs.

Ensure all managed symbols are available and historical data is usable.

Keep the main tester symbol consistent between comparative runs unless the experiment explicitly tests symbol selection.

Use realistic account balance, leverage, commission, swap and historical spread assumptions.

Do not treat a profitable report as proof of future profitability.

## 10. OOS / Forward / Walk-Forward

Separate development data from validation data.

Use:

IN-SAMPLE
→ parameter selection
→ OOS / Forward
→ untouched confirmation

Do not repeatedly tune on the same OOS period.

For material strategy changes, prefer rolling walk-forward validation where the available test process supports it.

A backtest is historical evidence.
A forward/OOS test is validation evidence.
Neither is live validation.

## 11. Robustness

For a candidate that passes initial OOS, test as appropriate:

1. nearby parameter values
2. different chronological periods
3. different assets
4. different market regimes
5. realistic spread/commission changes
6. execution-delay sensitivity
7. Monte Carlo/randomization tests when available

Investigate whether performance depends on one symbol, one regime, one period, or one narrow parameter combination.

## 12. Smart Risk / Capital Management

Research risk separately from entry logic.

Preferred sequence:

Account Equity
→ Base Monetary Risk
→ Stop Distance
→ Volatility Adjustment
→ Drawdown Adjustment
→ Portfolio Exposure
→ Concentration / Correlation when actually implemented
→ Position Constraints
→ Margin
→ Execution

Risk multipliers must be bounded, interpretable and monotonic.

Do not let risk optimization hide a weak signal model.

For dynamic risk proposals, test each component independently before combining them.

For correlation-aware risk, define before implementation:

- return lookback
- update frequency
- missing-data handling
- directional/concentration treatment
- portfolio impact

Do not claim correlation-aware risk unless the code actually computes and uses it.

## 13. Promotion / Rejection

A candidate is promotable only when the available evidence supports:

- acceptable expectancy/profitability
- acceptable drawdown
- sufficient trade sample
- stable nearby parameters
- acceptable OOS/forward behavior
- acceptable asset/regime sensitivity
- acceptable cost sensitivity
- no critical risk-control regression

Otherwise:

REJECT
or
RESEARCH MORE

Do not rescue a failed OOS result by tuning on the same OOS data.

## 14. Verification

For code changes:

- inspect diff
- compile when tooling permits
- inspect actual compiler output
- run the narrowest useful test
- inspect resulting diff again

For research:

- record exact configuration
- record actual results
- distinguish IS/OOS/forward
- inspect stability
- state unverified assumptions

Always distinguish:

VERIFIED
OBSERVED
INFERRED
ASSUMED
UNVERIFIED

Never claim compiled, tested, backtested, optimized, OOS-validated, or runtime-verified without evidence.

## 15. Git Safety

Preserve user changes.

Never automatically:

- reset
- clean
- delete unrelated files
- rewrite history
- force-push

Review status and diff before delivery.

## 16. Reporting

For engineering work report:

### FINDING
### ROOT CAUSE
### CHANGE
### VERIFICATION
### REMAINING RISK

For research/optimization report:

### BASELINE
### HYPOTHESIS
### EXPERIMENT
### RESULT
### OOS / FORWARD
### ROBUSTNESS
### DECISION
### REMAINING RISK

Name exact files/functions when code changed.

Do not expose hidden reasoning; report conclusions and evidence.