---
description: Evidence-led implementation with scoped independent review and authorized verification
---

# EA Implement

You are coordinating a real change in the existing AlgoMultiAssetEA repository. Own the task end-to-end:

`BASELINE → INVESTIGATE → ACCEPTANCE → IMPLEMENT → INDEPENDENT REVIEW → VERIFY → REPORT`

Do not stop at a plan when implementation is authorized and no material decision is unresolved.

## 1. Establish the actual baseline

- Read `AGENTS.MD`, `.kilo/rules/mql5.md`, and only the relevant project Skills/decision records.
- Inspect branch, HEAD, `git status --short`, staged/unstaged diff, untracked files, and relevant recent history before editing.
- Treat the current workspace as authoritative; never assume a prior report or remote branch describes local state.
- Record pre-existing user changes and keep them separate from this task's diff.
- Never reset, clean, restore, stash, checkout/switch, rebase, amend, stage-all, commit, or push unless explicitly authorized.

## 2. Select the minimum relevant Kilo resources

Use the actual Skill tool to load:
- `algo-multiasset-ea` for every cross-module/project task.
- `engineering` for implementation.
- Add `hybrid-strategy-lifecycle` for Setup/Attempt/News/freshness/reconciliation changes.
- Add `trading-risk` for risk, portfolio, authorization, or broker-mutation changes.
- Add `signal-pipeline-forensics` for missing/rejected signal or data-flow diagnosis.

Delegate only distinct questions through Kilo's Task/subagent mechanism:
- `explore`: read-only call graph, data flow, ownership, and failure-path discovery.
- `code-reviewer`: read-only review of the actual final diff and affected callers.
- `risk-auditor`: read-only review when execution, risk, authority, retry, or broker state is affected.

Do not invoke reviewers for unrelated work. Do not let delegates edit. Verify the exact registered agent IDs before invocation. If a resource cannot be invoked, state `UNAVAILABLE` or `APPLIED FROM FILE`; never claim it ran.

## 3. Investigate before editing

- Trace producer → consumer, direct callers, state transitions, side effects, and failure paths.
- Use source and current logs as evidence; distinguish `VERIFIED`, `OBSERVED`, `INFERRED`, `ASSUMED`, and `UNVERIFIED`.
- Check existing implementation and approved decisions before adding a field, helper, class, or abstraction.
- For external API/platform semantics, consult the relevant official documentation first. Third-party sources are secondary and cannot override official contracts or project decisions.
- If root cause is not established, do not patch a guess. State the competing hypotheses and the exact evidence needed.

## 4. Define acceptance before implementation

Write a compact acceptance matrix:
`ID | observable requirement | source path | verification method | pass condition`

Include relevant negative/failure cases, not only the happy path. Define what cannot be proven statically. Identify the smallest coherent file/function scope and likely regressions.

## 5. Implement

- Make the smallest change satisfying the acceptance criteria.
- Preserve public interfaces, approved architecture, user changes, and unrelated behavior.
- Do not add duplicate state or abstractions when an existing path can be corrected.
- Do not change trading policy, thresholds, risk limits, retry semantics, persistence guarantees, or schema without explicit approval.
- For execution changes, trace every broker mutation and ensure no bypass path remains.
- Keep position management separate from entry gates.
- Ambiguous execution outcomes require reconciliation, never speculative retry.

## 6. Independent review

After the implementation is stable:
- Invoke `code-reviewer` on the exact task diff, direct callers, and relevant failure paths.
- Invoke `risk-auditor` only when the change affects execution/risk/authority/attempt state.
- Give each reviewer a distinct question and read-only scope.
- Reconcile every finding against current source and authoritative documentation. Do not blindly accept speculative findings.
- Fix confirmed in-scope defects, then review only the changed correction. Do not repeat unchanged audits.

## 7. Authorized verification

- Read the relevant validation workflow and inspect the exact build/test script before execution.
- Compile, run tests, launch terminal, use Strategy Tester, mutate DB, or contact a broker only when the current user request explicitly authorizes that exact class of operation.
- A compile authorization is not runtime/tester/broker authorization.
- Run the narrowest useful checks. Capture exact command, exit code, full relevant output, artifact identity, and warnings.
- Report static review, compile, functional test, Strategy Tester, and runtime as separate evidence classes.
- If a script has side effects or its behavior is unclear, do not run it; inspect and report the blocker.

## 8. Completion gate

Do not mark implementation complete until:
- every acceptance criterion has a result (`PASSED`, `FAILED`, `NOT RUN`, `BLOCKED`);
- final diff is reviewed against the initial baseline;
- independent review findings are resolved or explicitly accepted/deferred;
- compile/test/runtime claims match actual evidence;
- no out-of-scope behavior or unauthorized operation occurred.

## 9. Final report (Persian)

Report:
1. baseline and preserved user changes;
2. root cause and evidence;
3. files/functions changed and behavior before/after;
4. acceptance matrix;
5. actual Workflow/Skill/Agent invocation evidence;
6. official and secondary sources actually consulted;
7. exact validation commands/results/warnings;
8. unresolved risks and next dependency.

Use a precise status such as `IMPLEMENTED_PENDING_REVIEW`, `INCOMPLETE`, or `BLOCKED`. Never call a phase complete merely because it compiles.
