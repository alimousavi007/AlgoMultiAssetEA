---
name: engineering
description: Evidence-led implementation and review for AlgoMultiAssetEA. Use for MQL5 bug fixes, compiler/runtime errors, features, refactors, code reviews and dashboard defects; trace the actual path and make the smallest justified change.
---

# Engineering Workflow

Use with `algo-multiasset-ea`; add a specialist Skill only when its domain applies.

## Invariants

- Preserve architecture, public interfaces and user changes unless the requirement explicitly authorizes a change.
- Trace callers, state transitions and side effects before editing; do not patch a symptom or speculate when root cause is unproven.
- Before adding a parameter, module or abstraction, check whether existing behavior already satisfies the requirement.
- Static inspection is not compile or runtime evidence.
- Compile, test, launch a terminal or use Strategy Tester only when the task explicitly authorizes that operation and the required tooling is available.

## Bug fix

`SYMPTOM → REPRO/EVIDENCE → EXECUTION TRACE → ROOT CAUSE → MINIMAL FIX → AUTHORIZED VERIFICATION`

Record expected vs observed behavior, exact failure point, callers/dependencies and evidence. If the evidence does not establish a root cause, report the competing hypotheses and next evidence required instead of making a speculative fix.

## Compile error

1. Read the actual compiler output and identify the first/root diagnostic.
2. Check declarations, includes, types, overloads and the earliest error before treating later messages as independent defects.
3. Make the smallest change justified by the diagnostic.
4. Run a compile only if authorized; quote the actual result and identify the exact source/build artifact.

Do not equate source inspection with a successful compile, or a previous compile with the current source revision.

## Runtime defect

Trace `EVENT → INPUTS → STATE → CALLERS → LOG/RETcode → FAILURE`. Use Experts/Journal/Tester output and timestamps where available. Separate missing telemetry from a condition that was actually evaluated and failed.

## Feature

`REQUIREMENT → EXISTING CAPABILITY → DEPENDENCIES/SAFETY → MINIMAL DESIGN → IMPLEMENT → AUTHORIZED VERIFICATION`

Specify observable acceptance criteria before coding. Do not couple unrelated behavior or change trading logic to fix a UI-only defect.

## Refactor

Treat a refactor as behavior-preserving. Establish existing behavior, public callers, state/lifecycle and side effects first; avoid bundling unrelated fixes. State which equivalence checks were actually possible.

## Code review

Read-only unless fixes are explicitly requested. Prioritize correctness, risk bypass, stale/misindexed data, state transitions, multi-symbol scheduling, duplicate execution, MQL5 API misuse, and regression risk. Findings must include exact file/function/line and a reproducible explanation. Do not edit, commit or push during a review unless those actions are separately authorized.

## Dashboard/UI

Trace actual producers, cache/state and lifecycle hooks such as `OnInit`, `OnTick` and `OnTimer`. Keep display as a consumer of domain state: do not fabricate signals, risk decisions or trades to refresh the UI. Preserve chart-symbol filtering and the last genuine evaluation state.

## Final verification and report

After an authorized change: inspect final diff, inspect likely compile/runtime concerns, run only the narrowest authorized useful check, capture actual output, and inspect the diff again.

Report: `FINDING`, `EVIDENCE`, `ROOT CAUSE`, `CHANGE`, `VERIFICATION`, `REMAINING RISK`. Name exact changed files/functions. Explicitly label checks `PASSED`, `FAILED`, `NOT RUN` or `BLOCKED`.
