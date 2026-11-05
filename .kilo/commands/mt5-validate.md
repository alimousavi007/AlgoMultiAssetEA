---
description: Controlled MT5 compilation and validation workflow
---

Use MT5 Tester Operator for approved tester operations.

1. Identify the exact source, EX5, terminal, MetaEditor, and data paths.
2. Establish the requested validation scope before execution.
3. Compilation, functional tests, Strategy Tester, and runtime
   checks are separate validation stages.
4. Do not overwrite existing INI/SET configurations or reports.
5. Execute only the validation stages explicitly authorized by
   the user for this task.
6. Never enable live trading or submit broker orders.
7. Capture actual logs, exit status, and test reports.
8. Report VERIFIED, FAILED, PARTIAL, or UNVERIFIED for each stage.
9. Never infer successful compilation or execution without evidence.
10. Report in Persian, including remaining risks.