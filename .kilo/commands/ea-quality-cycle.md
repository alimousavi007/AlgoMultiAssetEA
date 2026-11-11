---
description: End-to-end MQL5 compile, independent audit, repair, justified refactor, and regression gate
---

# EA Quality Cycle

Use this Workflow for an EA/MQL5 implementation task when the user expects the compile → audit → repair → optional refactor → repair cycle to finish in the same task. This Workflow explicitly authorizes **MetaEditor compilation only** when the user invokes it. It does not authorize Strategy Tester, launching or controlling a terminal, database writes/migrations, broker/network operations, or live trading.

## 0. Apply the minimum component Workflows

Read and apply these complete component files in this same Kilo session:
1. `.kilo/commands/ea-implement.md` — baseline, implementation, preservation, scoped review, and completion criteria.
2. `.kilo/commands/mt5-validate.md` — compile/test authorization boundaries, evidence classification, and reporting.

Apply additional component criteria only when relevant:
- `.kilo/commands/hybrid-lifecycle.md` and `.kilo/commands/hybrid-lifecycle-review.md` for Setup/Attempt/Coordinator/intent/reconciliation changes.
- `.kilo/commands/ea-risk-review.md` for risk, portfolio, execution, authority, retry, or broker-state changes.
- `.kilo/commands/security-review.md` for trust boundaries, dependencies, credentials, or external execution changes.

Do not try to invoke component slash commands recursively. A file read and applied here is `APPLIED AS COMPONENT INSTRUCTIONS`, not a separately invoked Workflow. Do not run irrelevant reviews.

## 1. Task list and baseline

Use the actual `todowrite` tool to create a concise task list with these stages; update it as work advances:
1. Verify baseline and authorization.
2. Compile the baseline and record diagnostics.
3. Audit and implement the scoped repair.
4. Refactor only if audit evidence justifies it; repair regressions.
5. Run final compile and affected regression checks.
6. Review the final diff and report.

Then:
- Read `AGENTS.MD`, `.kilo/rules/core.md`, `.kilo/rules/mql5.md`, relevant approved decisions, and relevant Skills.
- Inspect repository root, branch, HEAD, upstream, full `git status --short`, staged/unstaged diff, and untracked files before edits.
- Preserve all pre-existing user changes. Never reset, clean, restore, stash, switch branches, rebase, commit, or push.
- Define a compact acceptance matrix with observable requirements, source paths, verification methods, and pass criteria.
- Do not edit unrelated files or change strategy/risk policy without approval.

## 2. Invoke only relevant Skills and Agents

Use Kilo's actual Skill tool; do not substitute reading a file for invocation:
- Always for EA code: `algo-multiasset-ea` and `engineering`.
- Add `hybrid-strategy-lifecycle` for lifecycle/identity/attempt/reconciliation changes.
- Add `trading-risk` for risk/portfolio/execution/authority/retry changes.
- Add `signal-pipeline-forensics` only when the task traces a missing/rejected signal or data path.
- Add `mt5-strategy-tester` only when the user separately authorizes Strategy Tester preparation/execution.

Use the actual `task` tool for bounded independent work, after verifying available Agent IDs:
- `code-reviewer`: read-only review of the exact final diff, direct callers, error handling, and regression risk.
- `risk-auditor`: read-only review only when trading risk, portfolio, execution, authority, retries, or persistence are affected.
- `mt5-engineer`: focused MQL5/API/compiler investigation where specialist implementation knowledge is needed.
- `mt5-tester-operator`: do not invoke for this compile cycle; use only for a separately authorized Strategy Tester task.

Give each delegate a distinct question and read-only permissions unless an Agent is explicitly designated to implement. Reviewers must not edit. Record actual invocation IDs/results. If an Agent or Skill is unavailable, report that accurately; do not simulate its use.

## 3. Inspect and use existing tools

Inspect the relevant scripts and parameters before executing them:
- `tools/Compile-MT5.ps1`
- `tools/AlgoMultiAssetEA-ValidationHarness.ps1`
- `tools/ValidationHarness.Tests.ps1`

Do not create a second compiler or validation harness. Do not run two scripts that compile the same source back-to-back. Use `Compile-MT5.ps1` as the focused compiler; use the broader Validation Harness with `-SkipCompile` after that compile when its environment and checks apply.

Use the repository's configured terminal/data/include roots after verifying them. Do not silently substitute a different MetaEditor installation or include root. Inspect script side effects and target paths first; preserve prior logs and reports.

**Known tooling-test warning at the current main baseline:** `tools/ValidationHarness.Tests.ps1` contains 24 no-op assertions of the form `Assert-True $true`. These are not tests and must not be counted as coverage. Recheck the current branch before acting. If tooling/tests are in scope, replace affected placeholders with real assertions and run the regression suite. Otherwise report this pre-existing test-quality gap; never cite the test count alone as proof that the harness is correct.

## 4. Execute the quality cycle

### A. Baseline compile

Run the focused MetaEditor compiler against the exact source and verified include root, using the current project paths and PowerShell 5.1-compatible invocation, for example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Compile-MT5.ps1
```

Override path parameters only when the verified environment differs from the defaults. Capture the exact command, MetaEditor version, source path, include root, process exit code, fresh log, error/warning lines, EX5 timestamp, and EX5 SHA-256.

A missing/unrecognized summary, stale log, timeout, or unverified EX5 is `NOT VERIFIED`, not success.

### B. Audit

Audit the compiler output and only the relevant source scope:
- declarations, callers/callees, ownership, data/state flow, and side effects;
- error paths, invalid inputs, resource lifecycle, retries, timeout, and cleanup;
- interfaces and contracts changed by the patch;
- MQL5 API signatures/semantics against official documentation;
- existing unit/integration tests and whether assertions actually exercise behavior.

Use an independent Agent only for a distinct review question. Do not repeat an unchanged broad audit.

### C. Repair compiler and audit findings

Fix confirmed in-scope errors and P0–P3 defects with the smallest coherent change. Do not suppress warnings, weaken checks, change trading thresholds/policies, or add speculative fallbacks to make the build green.

After a source/header repair:
1. inspect the exact changed diff;
2. run the narrow tests invalidated by that edit;
3. recompile the affected EA entry point;
4. continue only from the new diagnostics.

Default compile acceptance is **0 errors and 0 warnings**. Each warning needs a root-cause disposition: fixed, or explicitly accepted through an approved and documented risk decision. Do not silently mark warnings as harmless.

### D. Refactor only if justified

Refactor only if the audit proves that duplication, unclear state ownership, coupling, error propagation, or complexity materially threatens correctness or maintainability. If no such evidence exists, explicitly skip refactoring.

Before refactoring, state the concrete defect it resolves and the invariants/interfaces that must remain unchanged. Keep the refactor scoped; do not combine cosmetic cleanup or unrelated renames.

### E. Repair refactor regressions

Review the refactor diff against the pre-refactor behavior and acceptance matrix. Fix every confirmed regression. Run the specific tests affected by the refactor, then recompile after the last source-affecting edit.

Do not repeat the entire audit if only one isolated function changed; recheck that function, its callers, and the specific invariant it can affect.

## 5. Final validation

After the last source change:
1. Run `tools/Compile-MT5.ps1` again. Require a fresh recognized log summary, **0 errors, 0 warnings**, and a fresh non-empty EX5 with recorded SHA-256.
2. Run `tools/AlgoMultiAssetEA-ValidationHarness.ps1` with the verified path parameters, `-SkipCompile -StrictMode -WarningsAsErrors`, and a unique JSON report path. This avoids a duplicate compilation while retaining the applicable structural/invariant checks.
3. Run only the relevant functional/regression tests. Inspect the actual assertions and environment requirements before invoking `ValidationHarness.Tests.ps1`; no-op assertions do not count.
4. Re-run the independent review only for changed fixes that alter the reviewed diff or risk path.
5. Inspect the complete final diff and final Git status. Do not stage, commit, push, or change branches.

Never run Strategy Tester, launch MT5/terminal processes outside the compiler, execute MQL5 Scripts, mutate databases, access a broker, or submit orders as part of this Workflow.

## 6. Strict completion gate

Do not report the task complete unless:
- all acceptance criteria have evidence;
- the final compile is fresh and reports 0 errors and 0 warnings;
- required affected tests pass with real assertions;
- all confirmed in-scope P0–P3 findings are fixed or have an explicit approved, documented architecture/policy/risk disposition;
- the final diff is reviewed and contains no unrelated edits;
- actual Workflow, Skill, Agent, and tool use is reported truthfully.

If a tool/environment dependency blocks proof, report the exact blocker and use `INCOMPLETE` or `BLOCKED`. Never claim zero errors without the current compile output.

## 7. Source hierarchy

Use current, version-relevant sources:
- Kilo Workflows: https://kilo.ai/docs/customize/workflows
- Kilo Skills: https://kilo.ai/docs/customize/skills
- Kilo tools and Task/TODO: https://kilo.ai/docs/automate/tools
- Kilo task TODO lists: https://kilo.ai/docs/code-with-ai/features/task-todo-list
- MetaEditor command-line compilation: https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide
- MetaEditor compilation behavior: https://www.metatrader5.com/en/metaeditor/help/development/compile
- MQL5 compiler errors: https://www.mql5.com/en/docs/constants/errorswarnings/errorscompile
- Microsoft PowerShell 5.1 `Start-Process`: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1
- .NET Framework `Process.WaitForExit(Int32)`: https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.waitforexit?view=netframework-4.8.1
- .NET Framework `Process.Kill()`: https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.kill?view=netframework-4.8.1
- Windows `taskkill /T /F` process-tree termination: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill

Use reputable secondary sources only to investigate details not settled by these primary sources; label them secondary and never treat them as platform guarantees.

## 8. Final report in Persian

Report:
1. baseline branch, HEAD, user changes preserved, and exact task scope;
2. required Workflow(s), component Workflows applied, Skills invoked, actual Agent IDs/results, and tools executed;
3. initial compile and final compile commands/results;
4. audit findings and evidence;
5. repairs and justified refactors, or why refactoring was skipped;
6. tests actually run, their real assertion coverage, and reports/artifact paths;
7. source links consulted;
8. each acceptance criterion and unresolved P0–P3 item;
9. explicit operations not run (Strategy Tester/runtime/database/broker/Git delivery).

Keep the report evidence-led. Do not claim any step ran unless its tool output exists.
