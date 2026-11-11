---
description: Diagnose an EA issue, implement the evidenced correction when authorized, then validate it
---

# EA Investigate → Fix → Validate — Composite Workflow

Use this workflow when the user reports a defect or runtime symptom and requests both root-cause investigation and a corrective implementation.

## 0. Composition contract

Read and apply these complete component instructions in this same session:
1. `.kilo/commands/ea-investigate.md`
2. `.kilo/commands/ea-implement.md`
3. `.kilo/commands/mt5-validate.md`

For relevant execution/risk changes, also read `.kilo/commands/ea-risk-review.md`. For Hybrid lifecycle symptoms, read `.kilo/commands/hybrid-lifecycle.md` and `.kilo/commands/hybrid-lifecycle-review.md`. For a security/privacy boundary, read `.kilo/commands/security-review.md`.

Do not try to invoke child slash commands from inside this Workflow. Load the files with the read tool and apply their instructions sequentially. Record them as `APPLIED AS COMPONENT INSTRUCTIONS`, not as separately `INVOKED` Workflows. If a required file cannot be read, report a blocker rather than using a remembered or partial version.

## 1. Phase A — Read-only diagnosis

Apply `ea-investigate.md` first.

- Establish the real baseline and preserve all user changes.
- Trace the earliest evidenced failure through input, configuration, state, callers, gates, side effects, and logs.
- Separate confirmed facts, observations, inferences, assumptions, and unknowns.
- Consult current official documentation when API or platform semantics matter.
- Do not edit, compile, test, launch MT5, mutate a database, trade, or change Git state during this diagnosis phase.
- Identify the smallest corrective change and the evidence that would prove it.

If the user requested diagnosis only, stop here and report the root cause and safest next step. Do not implement merely because this composite contains an implementation phase.

## 2. Transition gate

Proceed to implementation only when both conditions are true:
1. The user's current request explicitly asks for a fix/change, not diagnosis alone.
2. The root cause and required behavior are sufficiently evidenced to define safe acceptance criteria.

If root cause remains uncertain, competing explanations remain material, or a required architecture/policy decision is unresolved, stop without speculative edits. Report the exact missing evidence or decision.

## 3. Phase B — Evidence-led implementation

When the transition gate passes, apply `ea-implement.md` using the diagnosis as the investigation result; do not repeat the same unchanged audit.

- Define acceptance criteria, including negative and failure cases.
- Make the smallest justified correction.
- Preserve approved architecture, interfaces, and user changes.
- Load relevant Skills through Kilo's Skill mechanism.
- Use `explore` for bounded read-only tracing when useful.
- Use `code-reviewer` for independent correctness review.
- Add `risk-auditor` only when execution/risk/authority/persistence is affected.
- Apply Hybrid or Security component criteria only when the changed path requires them.

Fix confirmed findings and review corrections. Do not treat a code change as proof that the original runtime symptom is resolved.

## 4. Phase C — Authorized validation

Apply `mt5-validate.md` after implementation and review.

- Recheck authorization independently for compile, functional test, Strategy Tester, runtime, database, and broker operations.
- Inspect all scripts for side effects before execution.
- Capture exact commands, exit codes, source/binary identity, logs, warnings, and artifacts.
- Keep static, compile, test, tester, runtime, and broker evidence separate.
- Mark unexecuted stages `NOT RUN` or `BLOCKED`; never infer PASS.

## 5. Strict closure

Maintain a finding ledger for the original symptom and every newly discovered P0–P3 issue.

A finding may be closed only with a verified correction or a valid explicit architecture/policy disposition under the project's approved rules. No known issue may be silently deferred or hidden by a successful compile. If any required verification is blocked, status remains `NOT COMPLETE`.

## 6. Final report (Persian)

Report:
1. baseline and preserved changes;
2. original symptom and earliest evidenced root cause;
3. confirmed versus inferred facts and missing evidence;
4. corrective implementation and changed files;
5. independent review findings;
6. validation stages, exact outputs, and artifacts;
7. stages not run and authorization blockers;
8. finding ledger and final status.

Never claim a runtime incident was reproduced unless execution evidence shows it. Never claim a correction was runtime-verified when only source inspection or compilation was performed. No commit or push.
