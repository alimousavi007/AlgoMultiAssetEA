---
description: Safely synchronize the local project with its verified GitHub upstream using fetch and fast-forward only
---

# Repository Update — Safe Git Synchronization

Use this Workflow when the user explicitly asks to update/synchronize the local project from its GitHub repository. Invoke it as **/repo-update**.

Default behavior updates **only the currently checked-out branch from its configured upstream**. An explicit remote branch may be supplied as an argument (for example, **/repo-update workflows/composite-pipelines-2026-11-11**); in that case, switch/create a local tracking branch only after all safety checks pass.

This Workflow performs Git synchronization only. It does not implement source changes, install dependencies, compile MQL5, run tests, launch MT5, modify databases, or perform broker operations.

## 1. Establish the repository and Git baseline

1. Identify the actual repository root with **git rev-parse --show-toplevel**. Do not assume the terminal starts in the repository root.
2. Confirm the root belongs to the expected repository, **alimousavi007/AlgoMultiAssetEA**.
3. Read **AGENTS.MD** and applicable Git safety rules.
4. Record:
   - current branch and whether HEAD is detached;
   - current HEAD SHA and latest commit;
   - complete status, including staged, unstaged, and untracked files;
   - all remotes and their fetch URLs;
   - branch tracking configuration (remote and merge ref);
   - whether the repository is shallow or has unresolved merge/rebase/cherry-pick state.
5. Use the installed Git version's supported commands. Adapt quoting to the active shell (PowerShell on the project's Windows setup).

Do not expose credentials embedded in remote URLs. Redact usernames, tokens, passwords, and query parameters in the report.

## 2. Hard safety gates — stop before fetching or switching when necessary

Stop without changing Git state if any of the following applies:

- The repository root is wrong or cannot be established.
- HEAD is detached.
- The working tree has any staged, unstaged, or untracked changes.
- A merge, rebase, cherry-pick, revert, or other Git operation is in progress.
- The expected repository cannot be verified from the remote URL.
- The target branch or its upstream is ambiguous.
- Required Git commands fail or return an unexpected result.

For a dirty tree, report the exact branch and affected paths. Do not stage, commit, stash, reset, clean, restore, checkout, switch, merge, rebase, or discard anything. Do not propose an automatic stash as a workaround. Wait for the user to decide how to handle local changes.

Verify that the remote used for synchronization resolves to this canonical repository:

- HTTPS: https://github.com/alimousavi007/AlgoMultiAssetEA
- SSH: git@github.com:alimousavi007/AlgoMultiAssetEA.git

Allow the optional trailing .git and URL scheme/SSH syntax differences only. Do not accept a similarly named repository, fork, or different owner. Do not print embedded credentials.

## 3. Select the synchronization target

### A. No explicit branch argument

- Stay on the current branch; do not switch.
- Require a configured upstream for that branch.
- Read the branch's configured remote and merge ref (for example, branch.<name>.remote and branch.<name>.merge).
- Verify that the configured remote resolves to the canonical repository above.
- Verify the upstream ref is a remote-tracking branch and maps to the configured merge ref.
- If no upstream exists, do not guess main, origin/main, or another branch. Report that tracking setup needs an explicit decision.

### B. An explicit remote branch argument is supplied

- Treat the argument as a branch name, not a URL, refspec, commit SHA, or shell fragment. Validate it with Git's branch/ref format checker; reject ambiguous or invalid names.
- Determine the remote without guessing: prefer the current branch's configured remote only if its fetch URL resolves to the canonical repository. If that is unavailable, require exactly one configured remote whose fetch URL resolves to the canonical repository. If zero or multiple candidates remain, stop and report the ambiguity.
- Do not decide whether the remote branch exists from a possibly stale remote-tracking ref. Fetch the selected remote first (Section 4), then verify the exact fetched ref exists.
- If the current branch is already tracking that exact remote branch, remain on it.
- Otherwise, switching is permitted only because the user explicitly named the target branch and only after the clean-tree gate has passed.
- If the local target branch already exists, require its configured upstream to be exactly the selected remote and target branch. If no upstream exists or it points elsewhere, stop; do not repoint it automatically. Inspect its local commits before switching.
- If the local target branch does not exist, create it as a tracking branch from the exact verified remote-tracking ref after fetch.
- Never overwrite an existing local branch or change branch tracking configuration implicitly.

If the exact remote branch does not exist after fetch, stop. Do not substitute main or another branch.

## 4. Fetch without changing working files

After the repository, clean-tree, canonical-remote, and target-selection gates pass, fetch from the verified remote.

For the current branch's configured upstream:

~~~~powershell
git fetch <remote-name>
~~~~

For an explicitly named branch, fetch that exact branch into its corresponding remote-tracking ref so the check cannot rely on stale local metadata:

~~~~powershell
git fetch <remote-name> refs/heads/<target-branch>:refs/remotes/<remote-name>/<target-branch>
~~~~

The remote name and target branch must already have been validated as separate Git ref/name components. Do not build or execute a shell command from unchecked user text.

Do not use pull as the first operation. Fetch first so the incoming state can be inspected before changing the checked-out files.

After fetch, verify the exact remote-tracking ref exists and resolves. A fetch error, authentication failure, missing ref, or unexpected remote state is a blocker; do not fall back to another remote.

For an explicitly named target branch, activate it now, before calculating ahead/behind counts:

- If it is already the current branch, do not switch.
- If the local branch exists, re-verify that its upstream is exactly the selected remote/branch and then switch to it.
- If it does not exist locally, create it and set tracking to the exact verified remote-tracking ref with Git's tracking-branch switch operation.
- The working tree must still be clean immediately before switching. If it is not clean, stop.
- Never reset, overwrite, delete, or repoint a local branch to make the switch succeed.

Only after this step is the selected local branch the comparison base for Section 5.

## 5. Inspect the incoming update before applying it

Calculate ahead/behind counts between local HEAD and the exact verified upstream:

~~~~powershell
git rev-list --left-right --count HEAD <verified-upstream>
~~~~

Interpret the two numbers as LOCAL_AHEAD and REMOTE_AHEAD:

| Result | Meaning | Action |
|---|---|---|
| 0 0 | Already synchronized | Do not merge |
| 0 N, N > 0 | Local branch is behind | Continue to fast-forward gate |
| N 0, N > 0 | Local branch has local-only commits | Do not update or push; report local-ahead |
| N M, both > 0 | Histories diverged | Stop; no merge/rebase |
| Invalid/missing result | State cannot be proven | Stop |

When REMOTE_AHEAD is greater than zero, inspect before applying:

~~~~powershell
git log --oneline HEAD..<verified-upstream>
git diff --stat HEAD..<verified-upstream>
git diff --name-status HEAD..<verified-upstream>
~~~~

Review the incoming commit list and changed paths for unexpected scope, deletion/rename of important files, submodule pointer changes, generated/binary artifacts, sensitive data, and repository configuration changes.

Also inspect ignored local paths with **git status --short --ignored --untracked-files=all**. Compare ignored files/directories against every incoming changed path, accounting for parent/child path collisions and case-insensitive path matching on Windows. If an incoming file could replace or conflict with an ignored local file/directory, stop and report both paths. Do not delete or move the ignored item. If the collision analysis cannot be completed reliably, stop before applying the update.

If the incoming change is suspicious, materially broader than the requested update, or cannot be safely understood, stop and report the exact paths/commits rather than applying it blindly.

## 6. Apply fast-forward only

Only when all safety gates pass, the tree is still clean, local HEAD is strictly behind the verified upstream, and the incoming diff is within the requested repository update, execute:

~~~~powershell
git merge --ff-only <verified-upstream>
~~~~

This must be a fast-forward. Never create a merge commit, rebase, cherry-pick, or force-update a branch.

If Git refuses the fast-forward for any reason, stop and inspect. Do not attempt an automatic conflict resolution or alternative update strategy.

## 7. Verify synchronization

Re-run and capture:

~~~~powershell
git branch --show-current
git rev-parse HEAD
git rev-parse <verified-upstream>
git rev-list --left-right --count HEAD <verified-upstream>
git status --short --branch
git log -1 --oneline
git show --stat --oneline HEAD
~~~~

A successful synchronized result requires:

- current branch is the selected target;
- local HEAD equals the verified upstream SHA;
- ahead/behind count is 0 0;
- working tree is clean;
- no unexpected branch, remote, or tracking configuration changes occurred.

If any condition fails, report NOT COMPLETE and the exact evidence. Do not claim that the project is updated merely because fetch succeeded.

## 8. Absolute prohibitions

Never run these commands or equivalents during this Workflow:

~~~~powershell
git reset --hard
git clean -fd
git clean -fdx
git stash
git restore .
git checkout -- .
git rebase
git commit
git push
git push --force
~~~~

Also prohibited:
- staging files or changing Git configuration/upstream without explicit separate authorization;
- merging into main unless main is itself the explicitly selected current upstream and the user has requested that update;
- deleting or renaming branches;
- editing source, configuration, workflow, or documentation files;
- launching MT5, compiling, running tests, migrating databases, or contacting a broker.

A request to update from GitHub authorizes fetch and a safe fast-forward of the explicitly selected branch; it does not authorize commit, push, branch deletion, history rewriting, or local-change disposal.

## 9. Final report (Persian)

Report, with exact evidence:

1. repository root and canonical remote (credentials redacted);
2. original branch, HEAD, tracking remote/ref, and initial working-tree status;
3. target selection (current upstream or explicitly named branch);
4. fetch result;
5. local-ahead/remote-ahead counts and incoming commit/file summary;
6. whether fast-forward was applied or why it was not;
7. final branch, local HEAD, upstream SHA, ahead/behind count, and working-tree status;
8. exact blockers or remaining user decisions.

Use statuses accurately: UPDATED, ALREADY UP TO DATE, LOCAL AHEAD — NOT PUSHED, BLOCKED — DIRTY WORKTREE, BLOCKED — DIVERGED, BLOCKED — UPSTREAM UNVERIFIED, or NOT COMPLETE.

Never report UPDATED unless final local HEAD equals the verified upstream and the working tree is clean.
