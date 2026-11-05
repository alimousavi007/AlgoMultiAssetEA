---
description: Review Git scope and prepare safe delivery
---

Use the delivery-git Skill.

1. Inspect branch, status, diff, untracked files, and relevant history.
2. Run git diff --check if shell execution is authorized.
3. Separate current-task changes from pre-existing user changes.
4. Identify the exact files and intended delivery scope.
5. Never use reset, clean, stash, restore, rebase, amend,
   history rewriting, or force-push.
6. Never stage all files blindly.
7. Report verification status and any blockers.
8. Stop before staging or committing unless explicitly authorized.
9. Commit only with explicit commit authorization.
10. Push only with explicit push authorization.
11. Report branch, files, commit and push status in Persian.