---
description: Behavior-preserving Refactor workflow for AlgoMultiAssetEA
---

# REFACTOR — FULL WORKFLOW

### TASK
این بخش Refactor شود:

[File / Component]

### GIT
بعد از Verify، Commit/Push انجام شود؟
YES / NO

### HARD RULE

Behavior فعلی باید حفظ شود.

### WORKFLOW

1. INVESTIGATE

   بررسی:
   - Duplication
   - Complexity
   - Responsibilities
   - Dependencies
   - Callers
   - Public interfaces
   - State
   - Side effects

   Behavior Contract را مشخص کن.

2. FIX

   فقط Plan تأییدشده را اجرا کن.

   - Structure only
   - No feature
   - No bug fix unrelated
   - No broad rename / formatting
   - Public API unchanged
   - State / Error / Trading behavior preserved

3. VERIFY

   Before vs After:

   - Inputs
   - Outputs
   - Return values
   - State transitions
   - Error behavior
   - Side effects
   - Callers
   - Interfaces
   - Risk / Trading

   سپس:
   - Compile
   - Diff
   - diff --check
   - Runtime در صورت امکان

4. GIT
   فقط در صورت PASS و GIT=YES.

### PASS

اگر Behavior تغییر کرده:
FAIL

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## REFACTOR
[...]

## BEHAVIOR
PRESERVED / CHANGED / NOT VERIFIED

## COMPILE
Errors = ?
Warnings = ?

## REGRESSION
None / Found / Not Verified

## CHANGED FILES
[...]

## COMMIT
[...]

## PUSH
[...]

## FINAL
[نتیجه]