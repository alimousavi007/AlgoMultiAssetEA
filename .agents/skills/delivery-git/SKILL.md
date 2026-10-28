---
name: delivery-git
description: Safe Git delivery for AlgoMultiAssetEA. Use to inspect repository status and diffs, validate scope, prepare a commit, or push only after the corresponding action is explicitly authorized.
---

# Git Delivery Gate

## Safety contract

- Preserve all pre-existing user changes, staged content and untracked files.
- Never run `reset`, `clean`, `restore`, `stash`, destructive checkout/switch, rebase, amend, history rewrite or force-push.
- Do not stage all files blindly and do not use Git to conceal uncertain scope.
- A request to fix or edit files does **not** authorize commit or push. Commit and push require separate explicit authorization.
- Do not commit known broken/unverified changes unless the user explicitly requests that delivery.

## Read-only gate

1. Confirm repository root and current branch.
2. Read `git status --short --branch`.
3. Review the full diff, including staged and unstaged changes; inspect relevant untracked files without adding them.
4. Check whitespace with `git diff --check` (and the staged equivalent if relevant).
5. Map every changed path to the task scope. Separate pre-existing changes from changes made for this task where evidence allows.
6. Record actual verification status and remaining risk.

If Git tools are unavailable, state that the gate could not be run. Do not simulate its result.

## Commit gate — only after explicit authorization

- Reconfirm status and diff immediately before staging.
- Stage only the exact approved paths.
- Recheck the staged diff and staged whitespace.
- Use a concise message that describes the change; do not claim tests not run.
- Report the new commit SHA and included paths only after Git confirms success.

## Push gate — separate explicit authorization

- Verify branch and upstream.
- Confirm the target remote/branch and inspect the commits to be pushed.
- Never force-push.
- Report the actual push result; do not infer success from local commit existence.

## Delivery report

State branch, included paths, pre-existing changes preserved, `diff --check` result, verification evidence, commit status/SHA, push status and unresolved blockers. Use `NOT RUN` rather than implying a check occurred.
