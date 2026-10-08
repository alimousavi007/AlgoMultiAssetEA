---
description: Full Trading and Risk Logic workflow for AlgoMultiAssetEA
---

# TRADING / RISK — FULL WORKFLOW

### TASK
این Trading / Risk behavior تغییر کند:

[شرح]

### GIT
بعد از Verify، Commit/Push انجام شود؟
YES / NO

### WORKFLOW

1. INVESTIGATE

   Trace کامل:

   Signal
   → Risk
   → Portfolio Risk
   → State / Locks
   → Execution
   → Position Management

   مشخص کن:
   - Current logic
   - Target behavior
   - Decision point
   - Safety gates
   - No-trade conditions
   - Regression risks

2. FIX

   فقط Logic موردنظر را تغییر بده.

   حفظ شود:
   - Risk gates
   - External / State locks
   - Daily / Monthly Loss
   - Consecutive Loss
   - Position limits
   - Exposure / Portfolio Risk
   - Symbol readiness
   - Market data validation
   - Volume / Margin checks
   - Execution validation

3. VERIFY

   سناریوها:

   1. Normal case
   2. Risk rejection
   3. External lock
   4. State lock
   5. Invalid market data
   6. Invalid symbol
   7. Invalid volume
   8. Execution failure
   9. Position / exposure limit

   سپس:
   - Compile
   - Runtime
   - Regression

4. GIT
   فقط اگر Safety=PASS و Verify=PASS و GIT=YES.

### HARD RULE

Signal ≠ Trade Authorization

هیچ Safety Gate را حذف، bypass یا تضعیف نکن.

### PASS

فقط اگر:
- Target behavior صحیح باشد.
- Safety behavior حفظ شده باشد.
- No regression مشاهده نشده باشد.
- Compile موفق باشد.
- Runtime در صورت ادعای verification با Evidence تأیید شده باشد.

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## TARGET BEHAVIOR
[...]

## PIPELINE
PASS / FAIL

## SAFETY
PASS / FAIL

## COMPILE
Errors = ?
Warnings = ?

## RUNTIME
PASS / FAIL / NOT VERIFIED

## REGRESSION
[...]

## CHANGED FILES
[...]

## COMMIT
[...]

## PUSH
[...]

## FINAL
[نتیجه]