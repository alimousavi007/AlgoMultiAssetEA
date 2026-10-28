---
name: research-optimization
description: Design and evaluate AlgoMultiAssetEA strategy experiments, parameter optimization, Tester Fitness, out-of-sample/forward validation, walk-forward analysis and robustness; use when measuring an edge or deciding whether to promote/reject a candidate.
---

# Strategy Research & Optimization

Use with `algo-multiasset-ea`; use `mt5-strategy-tester` for actual tester operations. Do not run a compile/test/optimization unless the current task explicitly authorizes execution.

## Experiment contract

Before a material experiment, specify:

- falsifiable hypothesis and mechanism;
- baseline and control variables;
- target metric(s), constraints and rejection criteria;
- profile, strategy, symbol set and market regimes;
- data period, source quality and costs;
- parameters being varied and why;
- train/validation/OOS/forward split and leakage controls.

Prefer the smallest experiment that can disconfirm the hypothesis. Check overlap with existing features before adding an indicator or score. Do not expand the optimization surface without evidence of incremental value.

## Controlled workflow

`BASELINE → HYPOTHESIS → ONE CONTROLLED EXPERIMENT → OOS/FORWARD → ROBUSTNESS → DECISION`

When supported by the hypothesis, tune in a controlled order such as `REGIME → ENTRY → EXIT → FILTERS → RISK`; this is a sequencing heuristic, not a mandatory recipe. Do not optimize every group at once.

Treat SCALP, DAY and SWING as separate research models unless the experiment explicitly tests transferability. Evaluate Trend/Pullback, Breakout, Momentum and Mean Reversion independently before allowing a combined portfolio result to hide a weak component. Verify actual strategy and Tester Fitness implementation before relying on names or assumptions.

## Backtest and optimization

- Establish a baseline with optimization off and preserve all unchanged inputs.
- Use `InpMode = MODE_BACKTEST` for trade/P&L experiments only after verifying that this is the intended current mode.
- Prefer real-tick modelling for final historical tests when appropriate, with realistic spread, commission, swap, balance, leverage and symbol history.
- Optimize small, logically related groups. Around 4–7 active parameters is a heuristic, not a universal rule; reduce the count when sample size or evidence is weak.
- Record parameter names/ranges/steps, tester model, data dates, symbols, costs, fitness criterion, trade count and acceptance gates.
- Avoid repeated tuning against one OOS segment. Reuse of validation data turns it into development data.

## Validation and robustness

Keep chronological partitions separated:

`IN-SAMPLE → selection → OOS/forward → untouched confirmation`

For material changes, prefer rolling walk-forward analysis when the process supports it. For candidates passing initial validation, examine as relevant:

- adjacent parameter values and stable plateaus;
- different periods, assets and regimes;
- spread/commission/swap and execution-delay sensitivity;
- sufficient trade sample and dependence on a small number of trades;
- Monte Carlo/randomization only when method and assumptions are documented.

Do not promote an isolated peak. Small parameter changes that destroy results indicate fragility. Do not rescue failed OOS performance by tuning against that same data.

## Decision

Choose `PROMOTE`, `REJECT` or `RESEARCH MORE` based on predeclared criteria, not on the best-looking run. Evidence should address expectancy/profitability, drawdown, sample size, parameter stability, OOS/forward performance, asset/regime sensitivity, cost sensitivity and risk-control regressions. Do not invent universal thresholds after seeing results; if acceptance thresholds were not set, state that limitation.

## Report

`BASELINE | HYPOTHESIS | CONFIGURATION | RESULT | OOS/FORWARD | ROBUSTNESS | DECISION | REMAINING RISK`

Include exact settings and measured outputs. Distinguish historical backtest, OOS, forward-demo and live evidence. No result means no promotion claim.
