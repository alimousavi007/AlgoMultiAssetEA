---
description: Unified evidence-led workflow for investigation, implementation, review, security, documentation and validation
---

# Project Engineering — Unified Workflow

This Workflow consolidates the former `/project-task`, `/security-review` and `/docs-review` responsibilities. Use `/project-engineering` for general project work that has no more specific specialist Workflow.

Prefer a specialist Workflow when it clearly owns the task (for example `/ea-implement-validate`, `/ea-investigate-fix-validate`, `/ea-risk-review`, `/hybrid-lifecycle-implement-validate`, `/mt5-validate` or `/git-delivery`). Do not run overlapping Workflows for the same work.

## 1. Classify the task

Select only the modes required by the user's outcome:

- **Research/answer:** evidence gathering; no edits.
- **Investigate:** trace the issue; read-only unless a fix is requested.
- **Implement:** scoped changes and verification.
- **Review:** bounded read-only review unless remediation is requested.
- **Security:** applicable threat-boundary assessment; read-only unless a fix is requested.
- **Documentation:** create/revise requested docs and verify claims against implementation.
- **Validation:** authorized checks only.
- **Delivery:** inspect/prepare Git delivery; commit and push require separate explicit authorization.

Combined modes are permitted only when they produce distinct required outcomes. Do not add modes for ceremony.

## 2. Baseline and scope

- Read `AGENTS.MD` and applicable `.kilo/rules/`; preserve exact casing.
- When relevant, inspect branch, HEAD, status, staged/unstaged diff, untracked and relevant ignored files.
- Inspect only relevant source, callers, dependencies, configuration, tests, docs and existing `tools/`.
- Separate pre-existing user changes from task changes; preserve both.
- Define scope, assumptions, non-goals, permissions and observable acceptance criteria before non-trivial work.
- If baseline/root cause is uncertain, gather evidence; do not patch guesses.

## 3. Kilo resources

### Skills
Invoke Skills using Kilo's native `skill` tool. Reading a Skill file or naming it is not invocation. Load only applicable Skills:
- `engineering`: implementation, diagnosis, refactor, code review;
- `algo-multiasset-ea`: cross-cutting project context and approved invariants;
- `security-review`: security-sensitive code, configuration, data or automation;
- `documentation-quality`: documentation work;
- specialist Skills only when their domain is affected.

Record actual status as `INVOKED`, `APPLIED FROM FILE` or `UNAVAILABLE`.

### Agents
Use native `task` only for a distinct question that benefits from independent work. Verify the actual Agent ID first:
- `explore`: read-only discovery/dependency inventory;
- `code-reviewer`: independent read-only code correctness;
- `risk-auditor`: trading-risk/execution paths;
- `general`: bounded independent non-MQL5 review, only if registered and suitable.

Give each Agent a non-overlapping task and least privilege. Reviewers never edit. Do not delegate for appearance; report unavailable Agents honestly.

### TODO
For multi-step/dependent work, use actual `todowrite`. Keep the list short and update it at meaningful transitions. Do not claim use unless the tool ran. Trivial one-step tasks need no TODO list.

## 4. Evidence-led investigation and implementation

- Trace actual callers/callees, data flow, state transitions, side effects and failure paths.
- Prefer current source and reproducible evidence over names, comments, old reports or assumptions.
- Use official documentation for API/product/platform/shell/version contracts. Use credible secondary sources for corroboration or documented gaps; they never override official contracts or repository evidence.
- Check source relevance, version, maintenance and applicability. Cite material conclusions and record sources actually consulted.
- Define positive, negative and failure-path acceptance criteria for non-trivial changes.
- Make the smallest change that meets the requirement while preserving interfaces, approved architecture, user work and unrelated behavior.
- Before adding a script, module, abstraction, dependency or Workflow, search for an existing equivalent and prove the gap.
- Do not install dependencies or external tools without demonstrated need and compatibility/security review.

## 5. Conditional security review

Apply only checks relevant to the affected surface: secrets/sensitive data; authentication, authorization and ownership; input validation, parsing, serialization and injection; filesystem/path safety; process execution and argument quoting; network/TLS/trust boundaries; dependency provenance, pinning, maintenance and license; logging/privacy/retention; concurrency, race conditions and failure handling.

For trading paths, consider account identity, execution authorization, durable state, reconciliation and unintended broker-side effects only when actually in scope.

For each confirmed/conditional finding report severity, confidence, exact location, preconditions, reachable failure/attack path, concrete impact, evidence and minimal mitigation. Separate vulnerabilities, hardening advice and unverified concerns.

Review-only is read-only. Do not exploit, scan production, fuzz external systems, access secrets, submit broker requests or edit files unless a defined implementation/test scope is explicitly authorized. A limited clean review does not prove the whole system secure.

## 6. Conditional documentation work

When documentation is requested or needed to explain a delivered change:
- establish audience, purpose, canonical location and level of detail;
- verify claims against current source, configuration, API and actual behavior;
- verify paths, commands, Workflow/Skill/Agent IDs, parameters, versions, links and examples;
- distinguish implemented, proposed, deprecated and unverified behavior;
- organize around purpose, prerequisites, procedure, examples, verification, troubleshooting and limitations as appropriate;
- keep one canonical explanation and link to it instead of duplicating;
- protect secrets, private paths and personal/account data.

Do not edit docs in review-only mode or document planned/unverified behavior as implemented.

## 7. Tools, validation and repair

- Inspect each script's help, parameters, write targets, process launches and external side effects before execution.
- Reuse `tools/`; do not create duplicate compilers, validation harnesses, testers or wrappers without a proven gap.
- Run only authorized checks relevant to changed behavior. Capture exact commands, environment/version, exit codes, diagnostics and artifact paths.
- Keep static inspection, parser checks, unit/functional tests, compilation, Strategy Tester, runtime and broker evidence distinct.

For MQL5 implementation requiring compilation, use:
`baseline compile → scoped audit → repair if needed → refactor only if justified → repair refactor regressions if needed → final compile and relevant tests`.

Use `tools/Compile-MT5.ps1` and existing validation tools where appropriate. Default compile acceptance is zero errors and zero warnings. Investigate every warning; fix it or obtain explicit approved, documented risk disposition. Unrecognized summary, stale log, timeout or unverified EX5 means `NOT VERIFIED`, not PASS.

After the final source-affecting repair/refactor, compile again. Do not rerun unchanged audits or unrelated tests. Compilation does not authorize Strategy Tester, terminal launch, database mutation, runtime/broker operations or live trading.

For non-MQL5 work, run relevant parser, unit, integration and CI checks; do not launch MetaEditor merely because PowerShell/docs changed.

## 8. Review and completion gates

- Inspect the complete final diff, including new/deleted files.
- Use independent read-only review only when it adds distinct evidence.
- Fix confirmed in-scope defects and rerun checks invalidated by fixes.
- Inspect assertions; no-op assertions are not coverage, and test counts alone prove nothing.
- Process launch, file existence, timestamps, skipped stages or unrelated green checks do not prove success.
- Do not close/defer known P0–P3 findings without a verified fix or explicit approved architecture/policy decision or risk acceptance.
- Mark every criterion `PASSED`, `FAILED`, `NOT RUN` or `BLOCKED`. If a required check cannot run, state the exact blocker and keep the gate open.

## 9. Authorization and preservation

Editing, shell execution, tests, compilation, terminal launch, Strategy Tester, database mutation, external network actions, broker operations, Git staging, committing and pushing are separate permissions.

Preserve user changes and artifacts. Never reset, clean, restore, stash, discard, amend, rebase, force-push or stage all files. Do not commit/push without explicit authorization for each operation. Do not launch MT5, connect to a broker, execute MQL5 Scripts, mutate trading state or submit orders unless the current task explicitly authorizes that exact action. Apply least privilege and never expose secrets in code/logs/reports/prompts.

## 10. Final report

Respond in Persian unless requested otherwise. Report proportionally:
1. task, selected mode(s), scope and baseline;
2. findings/root cause and evidence;
3. exact changed files and behavior;
4. acceptance criteria/results;
5. Workflows, Skills, Agents and tools actually invoked;
6. official/secondary sources actually consulted;
7. checks run/not run, versions, exit codes and artifacts;
8. unresolved risks, blockers and explicit dispositions;
9. final Git status and delivery actions, if applicable.

Use evidence labels precisely: `VERIFIED`, `OBSERVED`, `INFERRED`, `ASSUMED`, `UNVERIFIED`, `NOT RUN`, `BLOCKED`. Never claim an action or result without evidence.
