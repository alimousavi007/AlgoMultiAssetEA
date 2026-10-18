---
name: delivery-git
description: Git delivery workflow for AlgoMultiAssetEA. Use when reviewing repository state, preparing commits, committing verified changes, or pushing when explicitly requested.
argument-hint: Describe the delivery, commit, branch, diff, or push objective.
---

# AlgoMultiAssetEA Delivery & Git Skill

Use this skill after engineering or research work when Git delivery is requested.

## Safety

Preserve user changes.

Never automatically:

- reset
- clean
- delete unrelated files
- rewrite history
- force-push
- discard uncommitted user work

Do not use Git to hide an unclear scope.

## Delivery workflow

STATUS
→ DIFF
→ DIFF CHECK
→ SCOPE CHECK
→ COMMIT
→ PUSH only when explicitly requested

Before commit:

- inspect `git status`
- inspect the diff
- check whitespace with `git diff --check`
- verify only intended files are included
- confirm verification status
- review commit scope

Do not commit known broken/unverified work unless the user explicitly asks for that delivery.

## Push

Push only when explicitly requested or when the calling task clearly authorizes push.

Never force-push.

Do not rebase or rewrite history as part of routine delivery.

## REPORT

State:

- branch
- files included
- verification status
- commit hash/message when committed
- push status when pushed
- any remaining risk or blocked step
