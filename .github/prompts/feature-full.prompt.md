---
description: Full Feature workflow for AlgoMultiAssetEA
---

# FEATURE — FULL WORKFLOW

### TASK
این Feature را پیاده کن:

[شرح Feature]

### GIT
Git را تا Push انجام بده؟
YES / NO

### WORKFLOW

1. INVESTIGATE
   - رفتار فعلی
   - Architecture
   - Dependencies / Callers
   - Data flow
   - Scope
   - Design
   - Safety / Runtime impact

2. IMPLEMENT
   - فقط طبق Plan
   - Minimal Change
   - Existing components را reuse کن
   - API / Architecture را بی‌دلیل تغییر نده

3. VERIFY
   - Compile
   - Errors / Warnings
   - Logic
   - Regression
   - Runtime در صورت امکان
   - Trading / Risk safety در صورت ارتباط

4. GIT
   فقط اگر GIT=YES و Verify=PASS:
   - status
   - diff
   - diff --check
   - فقط Task changes
   - commit
   - push

### STOP CONDITIONS

- Root Cause / Design unclear → STOP
- Implementation plan mismatch → STOP
- Verification FAIL → STOP
- Scope unclear → STOP
- Safety regression → FAIL / STOP
- Conflict / remote issue → STOP

### OUTPUT

فقط خلاصه نهایی:

## RESULT
PASS / FAIL / BLOCKED

## DESIGN
[خلاصه]

## IMPLEMENTED
[خلاصه]

## VERIFY
[Compile / Logic / Runtime]

## CHANGED FILES
[Files]

## COMMIT
[Hash / Not created]

## PUSH
SUCCESS / NOT EXECUTED / FAILED

## FINAL
[نتیجه]