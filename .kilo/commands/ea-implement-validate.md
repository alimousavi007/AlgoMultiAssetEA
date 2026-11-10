---
description: One-invocation EA implementation, independent review, and authorized MT5 validation
---

# EA Implement + Validate — Composite Workflow

Use this workflow when the user requests an EA code change and expects the change to be reviewed and validated in the same Kilo task.

## 0. Composition contract

This is a single Kilo workflow that composes existing workflow instructions. Kilo discovers project workflows from `.kilo/commands/` and invokes this file as `/ea-implement-validate`.

Before acting, read and apply the complete instructions in:
- `.kilo/commands/ea-implement.md`
- `.kilo/commands/mt5-validate.md`

Do not attempt to trigger another slash command from inside this workflow (for example, do not type `/ea-implement` or `/mt5-validate` as if nested slash-command execution were supported). Read the component Markdown files with the available read tool and apply their protocols in this same session, in the order below. Reading a component file is not a separately invoked Workflow; report it as `APPLIED AS COMPONENT INSTRUCTIONS`, not `INVOKED`.

If a required component file cannot be read, stop and report `BLOCKED — COMPONENT WORKFLOW UNAVAILABLE`. Do not silently substitute remembered instructions.

Load additional component instructions only when the actual scope requires them:
- Hybrid lifecycle changes: `.kilo/commands/hybrid-lifecycle.md` and `.kilo/commands/hybrid-lifecycle-review.md`.
- Execution, risk, authority, persistence, retry, or broker-submission changes: `.kilo/commands/ea-risk-review.md`.
- Security boundary, sensitive data, dependency, shell, filesystem, or network changes: `.kilo/commands/security-review.md`.

## 1. Baseline and authorization

Apply the baseline, Git-preservation, project-context, Skill, Agent, investigation, and acceptance requirements from `ea-implement.md`.

- Read `AGENTS.MD` (exact case), applicable rules, approved decisions, and relevant Skills.
- Inspect branch, HEAD, status, staged/unstaged diffs, and untracked files before editing.
- Preserve all pre-existing user changes.
- Define an acceptance matrix before non-trivial implementation.
- Do not commit, push, reset, stash, discard, or stage-all.
- Determine the exact operations authorized by the current user request. Compile permission does not authorize runtime, Strategy Tester, DB mutation, or broker actions.

## 2. Scope selection

Classify the change before implementation.

- For ordinary EA code changes, apply `ea-implement.md`.
- If the change touches Context/Structure/Setup/Entry roles, Setup identity, freshness, News/Risk revalidation, Attempt submission, or reconciliation, also apply `hybrid-lifecycle.md`.
- If execution/risk/authority/persistence is affected, apply the review criteria in `ea-risk-review.md`.
- Apply `security-review.md` only when the changed surface crosses a security or privacy boundary.

Do not run unrelated specialist reviews merely to increase the number of audits.

## 3. Implement

Follow the implementation sequence from `ea-implement.md`:

`BASELINE → INVESTIGATE → ACCEPTANCE → IMPLEMENT`

Trace actual producers, consumers, callers, state transitions, side effects, and failure paths. Make the smallest justified change. Preserve approved architecture and user changes. Do not patch an unproven hypothesis or introduce an unapproved trading-policy, risk, schema, or retry change.

Use Kilo's actual Skill mechanism for relevant Skills. Use the Task/subagent mechanism for distinct read-only questions:
- `explore`: bounded discovery/call-graph trace when useful;
- `code-reviewer`: independent correctness review of the exact final diff;
- `risk-auditor`: only when execution, risk, authority, persistence, retries, or broker state is affected.

Verify exact registered Agent IDs before delegation. Report `UNAVAILABLE` if a requested resource cannot actually be invoked.

## 4. Independent review

After implementation stabilizes:

1. Obtain a read-only `code-reviewer` review of the exact diff and affected callers.
2. Add `risk-auditor` for execution/risk-sensitive changes.
3. For Hybrid lifecycle changes, apply the full review criteria in `hybrid-lifecycle-review.md`.
4. For security-sensitive changes, apply the relevant `security-review.md` criteria.

Give each reviewer a distinct, bounded question. Do not repeat an unchanged audit. Reconcile each finding against current source and authoritative documentation. Fix confirmed in-scope defects and review the correction.

## 5. Authorized MT5 validation

Only after implementation and review, apply the complete authorization, preflight, execution, evidence-classification, and reporting requirements in `mt5-validate.md`.

Validation stages are separate:
- static review;
- compilation;
- functional/unit/integration tests;
- Strategy Tester;
- controlled runtime observation;
- broker evidence.

Execute only the stages explicitly authorized and safe. Inspect exact scripts before execution. Preserve terminal data, reports, profiles, databases, and existing files. Never use live trading or broker submission as a test.

A skipped or unauthorized stage is `NOT RUN` or `BLOCKED`, never PASS. Do not claim runtime correctness from compilation.

## 6. Strict completion gate

For every acceptance criterion and every P0–P3 finding, record its state and evidence.

- Fix confirmed findings in scope and rerun affected regression checks.
- Do not silently defer, downgrade, or close a finding.
- Any documented risk acceptance or architecture/policy disposition must be explicit and supported by the user's approved project rules; otherwise keep the finding open.
- Do not report `COMPLETE` while a confirmed in-scope defect, failed check, or required-but-unverified criterion remains.
- If missing authorization prevents required verification, report `NOT COMPLETE — AUTHORIZATION REQUIRED`.

## 7. Final report (Persian)

Report:
1. initial branch/HEAD/status and preserved user changes;
2. scope and acceptance matrix;
3. changed files and behavior;
4. actual Skills and Agent invocations (distinguish invoked from component instructions read);
5. review findings and their dispositions;
6. exact validation commands, exit codes, logs, warnings, and artifacts;
7. stages not run and why;
8. final Git diff and remaining limitations;
9. status: `IMPLEMENTED`, `COMPILE VERIFIED`, `TEST VERIFIED`, `NOT COMPLETE`, or another evidence-accurate status.

No commit or push.
