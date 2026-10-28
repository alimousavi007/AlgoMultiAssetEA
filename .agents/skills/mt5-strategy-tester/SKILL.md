---
name: mt5-strategy-tester
description: Configure, launch and verify MetaTrader 5 backtests or optimizations using terminal64.exe and tester INI/SET inputs; diagnose launch failures and preserve reproducible test evidence.
---

# MT5 Strategy Tester Operations

Use only when a test/launch has been explicitly requested and authorized. A request to inspect code or design a test is not permission to run MT5 or connect to a broker.

## Preflight

1. Resolve the exact terminal installation path, terminal build, terminal data directory and account/profile context. Do not confuse installation root with the data folder; detect portable mode rather than guessing.
2. Resolve the exact `.mq5` source, the intended `.ex5`, and the build/source identity. Never assume an existing `.ex5` corresponds to the current source.
3. Confirm EA inputs, `InpMode`, symbol, timeframe, date range, deposit, leverage, tick model, optimization mode, spread/cost assumptions and report destination.
4. Check that symbols are available and required history/ticks are synchronized and sufficient.
5. Create unique INI/SET/log/report paths. Do not overwrite existing configs or results without explicit permission.
6. Record preflight values before launch.

## Launch

- Use the documented terminal configuration mechanism when appropriate, e.g. `terminal64.exe /config:<absolute-path-to-ini>`; quote paths correctly for the actual shell.
- Do not substitute `metatester64.exe` for the documented terminal launch workflow.
- Do not launch a live terminal, log into an account, enable automated trading or submit orders as a side effect of a test task.
- If the launch mechanism or tester INI syntax is uncertain for the installed build, verify it against official MetaTrader documentation and the current terminal before execution.

## Evidence and completion

A process starting is not proof the test completed. Collect the actual process exit/terminal status, RunID if available, Journal/Experts logs, test report and exact inputs/settings. Distinguish initialization, completion and a failed/partial run.

Use one of: `VERIFIED`, `NOT VERIFIED`, `FAILED_TO_START`, `PARTIAL`, `FAILED`, `BLOCKED`. A successful historical report is not forward or live validation.

## Reproducibility

Record source/EX5 identity, terminal build, account/tester context, symbol/profile, dates, model, inputs, costs, optimization/fitness criteria and artifact paths. Keep visualization for short diagnostics, not routine optimization. Prefer real-tick modelling for final historical checks when suitable tick data is available and the experiment calls for it.

## Reporting

State preflight, exact command/config, actual start/completion evidence, report path, result, limitations and remaining risk. Never report a test as passed based only on a process existing or a report filename appearing.
