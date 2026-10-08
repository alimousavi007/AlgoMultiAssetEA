---
description: Full Dashboard/UI workflow for AlgoMultiAssetEA
---

# DASHBOARD — FULL WORKFLOW

### TASK
این Dashboard/UI مشکل دارد یا این تغییر را می‌خواهم:

[شرح]

### GIT
بعد از Verify، Commit/Push انجام شود؟
YES / NO

### WORKFLOW

1. INVESTIGATE

   Trace:
   - OnInit
   - OnTick
   - OnTimer
   - Dashboard update flow
   - Data source
   - Rendering
   - State / cache
   - Chart Symbol filtering

   مشخص کن:
   آیا UI Domain State واقعی را overwrite می‌کند؟

   مخصوصاً بررسی کن:
   - Fake Signal
   - Fake Risk
   - Fake Domain State

2. FIX

   - UI فقط Consumer باشد.
   - Real data استفاده شود.
   - Fake Signal / Risk ایجاد نشود.
   - Presentation State از Domain State جدا باشد.
   - Chart Symbol filtering حفظ شود.
   - Trading logic تغییر نکند.
   - Scope فقط Dashboard باشد.

3. VERIFY

   بررسی:
   - Initial state
   - Real signal
   - Real risk
   - Market update
   - Timer update
   - Chart symbol
   - Multiple symbols
   - No fake state
   - No regression
   - Compile
   - Runtime در صورت امکان

4. GIT
   فقط در صورت PASS و GIT=YES.

### PASS

فقط اگر:
- Real Signal حفظ شده.
- Real Risk حفظ شده.
- Timer / Market refresh آنها را overwrite نمی‌کند.
- Fake State وجود ندارد.
- Chart filtering صحیح است.
- Compile موفق است.
- Regression مشاهده نشده.

### OUTPUT

## RESULT
PASS / FAIL / BLOCKED

## ROOT CAUSE
[...]

## FIX
[...]

## REAL SIGNAL
PASS / FAIL / NOT VERIFIED

## REAL RISK
PASS / FAIL / NOT VERIFIED

## FAKE STATE
NONE / FOUND / NOT VERIFIED

## COMPILE
Errors = ?
Warnings = ?

## RUNTIME
PASS / FAIL / NOT VERIFIED

## CHANGED FILES
[...]

## COMMIT
[...]

## PUSH
[...]

## FINAL
[نتیجه]