---
description: Controlled, explicitly authorized MT5 compilation and testing
---

# MT5 Validate

This workflow controls validation only. It does not authorize live trading, broker operations, or destructive terminal actions.

## 1. Authorization gate

Identify which exact stage the user authorized:
- compile only;
- static/functional test;
- Strategy Tester;
- controlled non-trading runtime observation.

Do not infer authorization for a later stage from an earlier one. If authorization is absent, stop before execution and provide the safe preparation/evidence needed.

## 2. Preflight

- Load `algo-multiasset-ea` and `mt5-strategy-tester` via the Skill tool; add `trading-risk` for execution/risk validation.
- Use `mt5-tester-operator` only for explicitly authorized tester operations.
- Inspect the exact script before running it. Determine whether it launches terminals, changes files/settings, accesses DB, or can submit broker requests.
- Identify source revision, terminal installation, data directory, MetaEditor, EX5, inputs, and existing reports.
- Preserve existing INI/SET/report/data files. Never overwrite without explicit permission.
- For tester runs, isolate persistent ledger/state from live operational data.
- Verify source-to-binary identity; timestamps alone do not prove build provenance.

## 3. Execute only the authorized stage

- Compile only with a proven compile-only command/script.
- Run only the requested test mode and exact approved configuration.
- Never enable live trading or submit orders.
- Do not terminate existing terminal processes or alter account settings.
- Capture exact command, exit code, compiler/tester logs, artifact paths, and relevant warnings/errors.

## 4. Evidence classification

Report each separately:
- `STATIC_REVIEW`
- `COMPILE`
- `FUNCTIONAL_TEST`
- `STRATEGY_TESTER`
- `RUNTIME_OBSERVATION`
- `BROKER_EVIDENCE`

Use `VERIFIED`, `FAILED`, `PARTIAL`, `NOT RUN`, or `BLOCKED`. A compile pass does not prove runtime correctness, strategy correctness, broker compatibility, or safe execution.

## 5. Output (Persian)

Include authorization scope, exact source/binary/terminal identity, commands, exit codes, raw relevant diagnostics, warnings with file/line, artifacts, test configuration, evidence classification, and remaining limitations.

Never claim a stage ran without direct output. No commit or push.
