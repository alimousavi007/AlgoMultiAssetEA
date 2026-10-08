---
description: Safe Git finalize, commit and push workflow for AlgoMultiAssetEA
---

# GIT — FULL WORKFLOW

### TASK
این تغییرات را برای Commit / Push بررسی و نهایی کن:

[شرح / Files]

### WORKFLOW

1. CHECK

   اجرا کن:
   - git status
   - git diff
   - git diff --check
   - current branch
   - remote

2. SCOPE

   بررسی کن:
   - فقط Task changes
   - No unrelated changes
   - Previous user changes preserved
   - No generated / temporary files

   Scope unclear → STOP

3. COMMIT

   فقط تغییرات همین Task.

   Commit message:
   کوتاه + دقیق

4. VERIFY COMMIT

   - git status
   - git log -1 --oneline

5. PUSH

   فقط اگر:
   - branch صحیح
   - remote صحیح
   - commit صحیح
   - working tree قابل قبول

   Force push / reset / rebase ممنوع.

### STOP

- Unclear scope
- User changes at risk
- Conflict
- Remote issue
- Wrong branch

### OUTPUT

## RESULT
PASS / BLOCKED / FAILED

## CHANGED FILES
[...]

## COMMIT
[Hash + message]

## BRANCH
[...]

## REMOTE
[...]

## PUSH
SUCCESS / FAILED / NOT EXECUTED

## WORKING TREE
CLEAN / DIRTY

## FINAL
[نتیجه]