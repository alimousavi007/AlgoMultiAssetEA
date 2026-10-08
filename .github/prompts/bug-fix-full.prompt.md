---
description: Full Bug Fix workflow for AlgoMultiAssetEA
---

# BUG — FULL WORKFLOW

### TASK
این Bug را بررسی و اصلاح کن:

[شرح Bug]

[Log / Error / Screenshot]

### GIT
Git را تا Push انجام بده؟
YES / NO

### WORKFLOW

1. INVESTIGATION
   - Symptom
   - Expected behavior
   - Execution path
   - Failure point
   - Callers / Dependencies
   - Root Cause
   - Evidence
   - Minimal Fix Plan

   اگر Root Cause اثبات نشد → STOP

2. FIX
   - فقط Root Cause
   - Minimal Change
   - Preserve architecture / API
   - Preserve user changes
   - No unrelated refactor

3. VERIFY
   - Compile
   - Errors / Warnings
   - Logic regression
   - Runtime در صورت امکان
   - Relevant logs
   - Trading / Risk safety در صورت ارتباط

4. GIT
   فقط اگر GIT=YES و Verify=PASS:
   - status
   - diff
   - diff --check
   - Task scope check
   - commit
   - push

### SAFETY

- Risk / Safety checks را bypass نکن.
- Invalid data → No Trade
- Symbol not ready → No Trade
- Risk rejection → No Trade
- Existing locks / limits حفظ شوند.

### STOP

FAIL / BLOCKED / Scope unclear / Safety regression / Conflict → STOP

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## ROOT CAUSE
[خلاصه]

## FIX
[خلاصه]

## VERIFY
[نتیجه]

## CHANGED FILES
[Files]

## COMMIT
[Hash / Not created]

## PUSH
SUCCESS / NOT EXECUTED / FAILED

## FINAL
[نتیجه]