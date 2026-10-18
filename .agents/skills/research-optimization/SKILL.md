---
name: research-optimization
description: Research, backtest, optimization, OOS/forward and robustness workflow for AlgoMultiAssetEA. Use for SCALP/DAY/SWING strategy research, parameter experiments, Tester Fitness, walk-forward validation, and promotion/rejection decisions.
argument-hint: Describe the profile, strategy, hypothesis, data period, test, optimization, OOS, or robustness objective.
---

# AlgoMultiAssetEA Research & Optimization Skill

Use this skill with the core `algo-multiasset-ea` project skill.

## Research discipline

Do not confuse a plausible trading story with measured edge.

Before a meaningful experiment state:

- hypothesis
- measurable objective
- falsification evidence
- likely redundancy with existing features
- overfitting risks
- required validation

Prefer existing features and small controlled experiments.

## Research workflow

BASELINE
→ HYPOTHESIS
→ CONTROLLED EXPERIMENT
→ OOS/FORWARD
→ ROBUSTNESS
→ DECISION

Do not repeatedly tune on the same OOS segment.

Treat SCALP, DAY and SWING as separate research models unless an experiment explicitly tests transferability.

Research strategies independently before combining:

- Trend/Pullback
- Breakout
- Momentum
- Mean Reversion

A combined portfolio result must not hide a strategy with no independent edge.

## Backtest

Before optimization:

1. compile
2. run baseline with Optimization OFF
3. use `InpMode = MODE_BACKTEST` for trade/P&L testing
4. keep other inputs unchanged for the baseline
5. record tester settings and EA inputs
6. inspect Journal/Experts output

Prefer `Every tick based on real ticks` for final historical testing.

Use visualization only for short diagnostics.

Use realistic balance, leverage, commission, swap and spread assumptions.

A profitable backtest is historical evidence, not proof of future profitability.

## Optimization

Do not optimize everything at once.

Default order:

REGIME
→ ENTRY
→ EXIT
→ FILTERS
→ RISK

Normally keep active optimization parameters around 4–7 unless evidence justifies more.

Record:

- profile
- strategy
- parameter names
- start/step/stop
- data period
- tester model
- spread/commission assumptions
- fitness criterion
- acceptance gates

Inspect the actual optimization surface and Tester Fitness implementation before adding parameters.

## Stable region

Do not promote an isolated peak.

Prefer a plateau where nearby parameter values remain acceptable for:

- performance
- drawdown
- trade count
- consistency

A candidate is fragile when small parameter changes collapse performance.

## OOS / Forward

Use:

IN-SAMPLE
→ parameter selection
→ OOS / Forward
→ untouched confirmation

Prefer rolling walk-forward validation for material strategy changes when supported by the available test process.

Never rescue a failed OOS result by tuning on that same OOS data.

## Robustness

For a candidate that passes initial OOS, test as appropriate:

- nearby parameters
- different chronological periods
- different assets
- different regimes
- realistic spread/commission changes
- execution-delay sensitivity
- Monte Carlo/randomization when available

Investigate dependence on one symbol, one regime, one period, or one narrow parameter combination.

## Promotion

Promote only when available evidence supports:

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

## REPORT

### BASELINE
### HYPOTHESIS
### EXPERIMENT
### RESULT
### OOS / FORWARD
### ROBUSTNESS
### DECISION
### REMAINING RISK

Report exact settings and actual measured results.
