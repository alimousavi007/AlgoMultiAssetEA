---
description: Prepare and perform explicitly authorized Git delivery safely
---

# Git Delivery

This workflow is for Git inspection and delivery only. It does not authorize commit or push by itself.

## 1. Establish baseline and ownership

- Inspect branch, HEAD, upstream, status, staged/unstaged diff, untracked files, recent history, and relevant remote state.
- Separate task changes from pre-existing user changes.
- Confirm the exact files intended for delivery and ensure no unrelated files are included.
- Run `git diff --check` only if shell use is authorized.

## 2. Safety

Never use reset, clean, restore, stash, checkout/switch, rebase, amend, force-push, or stage-all.
Never discard user changes.
Do not stage, commit, or push unless the user explicitly authorizes each operation. Authorization to commit does not imply authorization to push.

## 3. Delivery preflight

Before staging:
- inspect the complete final diff;
- confirm relevant validation evidence and known warnings;
- check secrets, generated artifacts, local paths, logs, credentials, and unintended files;
- identify branch and exact file list;
- prepare the proposed commit message.

If any scope ambiguity exists, stop before staging and report it.

## 4. Execute only authorized actions

Stage only explicit file paths. After staging, inspect the staged diff and status again. Commit only if explicitly authorized. Push only if separately authorized. Never force-push.

After each operation, verify resulting HEAD, branch/upstream, and remote status. A successful local commit does not prove push success.

## 5. Output (Persian)

Report baseline, exact staged/committed files, validation evidence, commit SHA, push result, remote tracking status, and any remaining local changes. Distinguish `NOT AUTHORIZED`, `NOT RUN`, `FAILED`, and `SUCCEEDED`.
