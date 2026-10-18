---
name: mt5-strategy-tester
description: MetaTrader 5 Strategy Tester configuration, terminal launch via terminal64.exe /config, backtest troubleshooting, reproducibility, and result verification.
argument-hint: Describe tester config, INI/SET, symbol, dates, model, or launch issue.
---
# mt5-strategy-tester

## Key Concepts
- Distinguish terminal installation (exe) vs terminal data directory.
- Verify source identity and EX5 identity before launching.
- Create unique INI/SET; never overwrite existing configs blindly.

## Launch Workflow
1. Identify 	erminal64.exe, MetaEditor, data dir, source, EX5.
2. Generate unique SET/INI with absolute paths.
3. Verify profile, mode, symbol, period, EA inputs, dates, tick model.
4. Launch: 	erminal64.exe /config:"<absolute-path-to-ini>".
5. Never use metatester64.exe as replacement for this mechanism.
6. Verify completion; collect RunID, logs, report.

## Evidence
- Report VERIFIED/NOT VERIFIED/FAILED_TO_START/PARTIAL/FAILED with concrete evidence.
- No live trading, no silent parameter changes, no claims based only on process existence.
