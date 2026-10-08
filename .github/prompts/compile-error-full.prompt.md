---
description: Full Compile Error workflow for AlgoMultiAssetEA
---

# COMPILE ERROR — FULL WORKFLOW

### TASK
Compile Error دارم:

[Compiler Output]

### GIT
بعد از Verify، Commit/Push انجام شود؟
YES / NO

### WORKFLOW

1. INVESTIGATE
   - Errorها را Trace کن.
   - Primary vs Cascade را جدا کن.
   - File / Line / Function
   - Root Cause
   - Dependencies
   - Proposed Fix

2. FIX
   - فقط Primary Root Cause
   - Cascadeها را با تغییر اضافی درمان نکن.
   - Minimal Change
   - Preserve API / Architecture
   - No unrelated changes

3. COMPILE
   بررسی کن:
   - Errors
   - Warnings
   - Code generated

4. VERIFY
   - Remaining errors
   - Callers / interfaces
   - Logic regression
   - Diff
   - diff --check

5. GIT
   فقط اگر Verify=PASS و GIT=YES:
   - ready check
   - commit
   - push

### STOP

- Root Cause unclear → STOP
- Compile still failing → STOP
- Scope unclear → STOP
- Unexpected architecture change → STOP

### PASS

فقط اگر:

Errors = 0
Warnings = 0
Code generated = successful

و Diff قابل قبول باشد.

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## PRIMARY ERRORS
[...]

## ROOT CAUSE
[...]

## FIX
[...]

## COMPILE
Errors = ?
Warnings = ?
Code generated = ?

## DIFF
PASS / FAIL

## COMMIT
[...]

## PUSH
[...]

## FINAL
[نتیجه]