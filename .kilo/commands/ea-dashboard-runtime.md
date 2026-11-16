---
description: End-to-end Dashboard Runtime validation: Safe Mode, A/B Tester runs, diagnostics analysis, root-cause fix, independent reviews
---

# EA Dashboard Runtime

You are coordinating the complete Dashboard Runtime validation for AlgoMultiAssetEA. Own the task end-to-end:

`BASELINE → SAFE MODE → SET A/B → VISUAL TESTER ×2 → DIAGNOSTICS → ROOT CAUSE → FIX → RE-VERIFY → REVIEW → WORKFLOW → DOCUMENT`

Do not stop at a plan when implementation is authorized and no material decision is unresolved.

## 1. Establish the actual baseline

- Read `AGENTS.MD`, `.kilo/rules/mql5.md`, `.kilo/rules/core.md`, and relevant Skills:
  - `algo-multiasset-ea` (project-wide)
  - `engineering` (implementation)
  - `hybrid-strategy-lifecycle` (Dashboard/Setup/Attempt lifecycle)
  - `mt5-strategy-tester` (Tester operations)
  - `signal-pipeline-forensics` (diagnostics analysis)
- Inspect branch, HEAD, `git status --short`, staged/unstaged diff, untracked files.
- Record pre-existing user changes; keep them separate from this task's diff.
- Verify 0-error/0-warning compile baseline.

## 2. Implement Safe Dashboard-Only Mode

- Add inputs: `InpDashboardSafeMode`, `InpEnforceSafeModeInTester`.
- Add functions: `IsSafeModeActive()` (Visual Tester only), `IsSafeModeEnforced()` (fail-closed elsewhere).
- Add global counters: `g_blocked_mutation_count`, `g_executed_mutation_count`.
- Guard ALL broker mutation paths:
  - `ProcessHybridDecision` (new entry submission)
  - `ProcessRetryPendingHandoff` (retry submission)
  - `OnTick` → `g_position_manager.Update()` (position mgmt)
  - `OnTimer` → `g_position_manager.Update()` (position mgmt)
- Log Safe Mode status at OnInit (unconditional).
- Log `MUTATION_BLOCKED` with both counters on every block.
- Resolve blocked attempts as `EXEC_STATE_ABORTED` (non-submission) with `MarkPlanConsumed`.
- Default `InpDashboardSafeMode=false`, `InpEnforceSafeModeInTester=true`.

## 3. Create Independent SET A/B Files

- Create `Experts/AlgoMultiAssetEA_DASH_A.set` and `Experts/AlgoMultiAssetEA_DASH_B.set`.
- Both must enable: `InpDashboardSafeMode=true`, `InpDashboardDiagnostics=true`.
- Dashboard-relevant differences:
  - View mode (FULL vs COMPACT), Overlay (true/false), Compact (true/false)
  - Log level (DEBUG vs INFO), Summary interval
  - Risk parameters (RiskPerTrade, MinScore, MaxPositions)
  - Strategy Group Key (different fingerprints)
  - Session filters, Spread filters, Freshness overrides
- Verify SET files pass validation harness.

## 4. Run Visual Strategy Tester ×2

- Preflight: `Invoke-MT5DashboardTester.ps1 -WhatIf` for both SETs.
- Execute: `Invoke-MT5DashboardTester.ps1 -SetFile <SET> -VisualMode` for SET A, then SET B.
- Each run must:
  - Use isolated output directory (`tools/tester-output/DASH_TEST_<timestamp>_<pid>/`)
  - Generate `tester.ini` with Visual Mode enabled
  - Run `terminal64.exe /config:...` (or `metatester64.exe` if available)
  - Complete without broker mutations (Safe Mode enforced)
  - Produce diagnostics JSON via `CDashboardDiag.GenerateReport()`
- Collect artifacts: diagnostics JSON, RunSummary, FailureTrace, screenshots if possible.

## 5. Analyze Diagnostics & Find Root Cause

- Run `Test-MT5DashboardDiagnostics.ps1` on each run's diagnostics JSON.
- Compare SET A vs SET B: Effective Config, Dashboard state, Snapshot lifecycle.
- Identify root cause of any Dashboard display/rendering issues.
- Verify negative fixtures (11 types) all produce expected FAIL at correct lifecycle stage.

## 6. Fix Root Cause & Re-Verify

- Implement minimal fix for identified root cause.
- Re-compile (0 errors, 0 warnings).
- Re-run Visual Tester with the affected SET to confirm fix.
- Re-run diagnostics analyzer to confirm PASS.

## 7. Independent Reviews

- Invoke `code-reviewer` on final diff (all changes since baseline).
- Invoke `risk-auditor` on execution safety, Safe Mode fail-closed, PositionManager guards.
- Reconcile findings; fix confirmed in-scope defects.

## 8. Final Verification

- Fresh compile: 0 errors, 0 warnings.
- Validation harness: PASS (4/4 checks, 22 invariants).
- Unit tests: 85/85 PASS.
- Negative fixture tests: 11/11 PASS (each fails at expected stage).

## 9. Create/Update Workflow & Documentation

- Create `.kilo/commands/ea-dashboard-runtime.md` (this workflow).
- Update `.kilo/WORKFLOW-CATALOG.md` with new workflow entry.
- Update `docs/architecture/EA_SYSTEM_INTEGRATION_AUDIT_AND_ROADMAP.fa.md` (§18/§19) with results.

## 10. Completion Gate

Do not mark complete until:
- Every acceptance criterion has a result (`PASSED`, `FAILED`, `NOT RUN`, `BLOCKED`).
- Final diff reviewed against initial baseline.
- Independent review findings resolved or explicitly accepted/deferred.
- Compile/test/runtime claims match actual evidence.
- No out-of-scope behavior or unauthorized operation occurred.

## Acceptance Matrix

| ID | Requirement | Source | Verification | Pass Condition |
|----|-------------|--------|--------------|----------------|
| DR-01 | Safe Mode blocks all broker mutations in live/backtest/opt | ea-implement.md | Static review + code-reviewer | All 4 mutation sites guarded, fail-closed default |
| DR-02 | Safe Mode allows mutations ONLY in Visual Tester | ea-implement.md | Static review | `IsSafeModeActive()` = Visual Tester only |
| DR-03 | Counters observable: both logged in MUTATION_BLOCKED | Risk audit SA-01 | Static review | Both `blocked=` and `executed=` in log |
| DR-04 | SET A/B created with Dashboard-relevant differences | This workflow | File diff | Different fingerprints, Safe Mode enabled |
| DR-05 | Visual Tester runs ×2 without broker mutations | mt5-strategy-tester | Tester execution | Safe Mode logs show blocked=0, executed=0 in Visual |
| DR-06 | Diagnostics JSON produced for each run | DashboardDiag.mqh | File existence | `diag_*.json` in output dir |
| DR-07 | Root cause identified from real Tester artifacts | Signal forensics | Analyzer output | FailureTrace.json shows specific stage |
| DR-08 | Fix verified by re-run | This workflow | Tester re-run | Analyzer PASS on re-run |
| DR-09 | code-reviewer PASS on final diff | ea-implement.md | Agent invocation | No P0-P1 defects |
| DR-10 | risk-auditor PASS on final diff | ea-risk-review.md | Agent invocation | No P0-P1 defects |
| DR-11 | Compile 0/0, Harness PASS, Unit 85/85 | Compile-MT5.ps1 | Run scripts | All pass |
| DR-12 | Negative fixtures 11/11 fail at expected stage | Test-MT5DashboardDiagnostics.ps1 | Run on fixtures | Each NEG_XX fails at correct lifecycle |
| DR-13 | Workflow catalog updated | This workflow | File edit | Entry in WORKFLOW-CATALOG.md |
| DR-14 | Roadmap §18/§19 updated | This workflow | File edit | Results documented |

## Status Labels

Use exactly: `IMPLEMENTED`, `STATICALLY REVIEWED`, `COMPILE VERIFIED`, `TEST VERIFIED`, `RUNTIME VERIFIED`, `NOT RUN`, `BLOCKED`.

- Visual Tester runs → `RUNTIME VERIFIED` only with actual terminal execution evidence.
- Without Tester execution → `BLOCKED` (explicitly note MT5/terminal limitation).
- Independent reviews → `STATICALLY REVIEWED` (agent output as evidence).

## Evidence Contract

Distinguish: `VERIFIED` (source/command output), `OBSERVED` (logs/runtime), `INFERRED`, `ASSUMED`, `UNVERIFIED`, `NOT RUN`, `BLOCKED`.

Never claim `RUNTIME VERIFIED` without terminal execution evidence. Never claim `COMPILE VERIFIED` without fresh log + EX5 hash.