---
description: Full Runtime Error workflow for AlgoMultiAssetEA
---

# RUNTIME ERROR — FULL WORKFLOW

### TASK
Runtime مشکل دارد:

[Log / Screenshot / Behavior]

### GIT
بعد از Verify، Commit/Push انجام شود؟
YES / NO

### WORKFLOW

1. INVESTIGATE
   Trace:

   Event
   → Execution Path
   → Log Source
   → State
   → Failure Point
   → Root Cause

   بررسی کن:
   - OnInit / OnTick / OnTimer
   - Data readiness
   - Symbol synchronization
   - State
   - Timing
   - Logic
   - Trading / Execution

2. FIX
   - فقط Root Cause
   - Minimal Change
   - Preserve safety / error handling
   - Preserve useful logs

3. VERIFY
   - Startup
   - Initialization
   - Relevant Event
   - State transition
   - Relevant logs
   - Runtime behavior
   - Regression
   - Trading behavior در صورت ارتباط

4. GIT
   فقط اگر Verify=PASS و GIT=YES.

### SAFETY

- Invalid data → No Trade
- Symbol not ready → No Trade
- Risk failure → No Trade
- Existing safety gates preserved

### STOP

Runtime هنوز مشکل دارد → FAIL / STOP
Runtime بدون Evidence → NOT VERIFIED
Conflict / remote issue → STOP

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## ROOT CAUSE
[...]

## FIX
[...]

## RUNTIME EVIDENCE
[...]

## COMPILE
Errors = ?
Warnings = ?

## REGRESSION
None / Found / Not Verified

## COMMIT
[...]

## PUSH
[...]

## FINAL
[نتیجه]