# ثبت تصمیمات (DECISION_LOG)

## ۱. هدف

این ثبت تمام تصمیمات معماری، استراتژی، ایمنی و عملیاتی تایید شده برای AlgoMultiAssetEA را کاتلوج می‌کند. هر تصمیم شامل شناسه، وضعیت، تصمیم‌گیرنده، تاریخ، مستندات استدلال و قراردادهای تأثیرگذار است.

**وضعیت‌ها:**
- **APPROVED** — تایید شده، در کد اعمال شده
- **UNDECIDED** — در انتظار تصمیم انسانی، پیش‌فرض fail-safe در جایگاه
- **UNKNOWN** — شواهد ناکافی، تحقیق لازم
- **EVIDENCE_PENDING** — تست/شواهد در انتظار، تصمیم مشروط
- **SUPERSEDED** — جایگزین شده توسط تصمیم جدیدتر

---

## ۲. تصمیمات معماری/استراتژی (مستقیم بر Verhalten تأثیرگذار)

| شناسه | موضوع | وضعیت | تصمیم‌گیرنده | تاریخ | خلاصه تصمیم | قراردادها/محدودیت‌های تأثیرگذار |
|------|--------|--------|------------|------|-------------|------------------------------|
| **D-001** | نقش‌های تایم‌فریم | **CONFLICT** | معماری | ۲۰۲۴-Q4 | ۴ نقش مستقل: Context(H4/D1), Structure(H1/H4), Setup(H1/H4), Entry(M15/M5/M1) | Setup مستقل از Structure؛ **اما در پیکربندی فعلی `setup_tf == structure_tf` در تمام سبک‌ها — تضاد مستند شده، نیازمند تصمیم M3** |
| **D-002** | مرزی اجرا | APPROVED | معماری | ۲۰۲۴-Q4 | `TradeExecutor` = تنها مرز فراخوانی بروکر | هیچ استراتژی دور زدن اجرا/ریسک |
| **D-003** | داشبورد | APPROVED | معماری | ۲۰۲۴-Q4 | داشبورد فقط مشاهده‌گر — عدم تغییر تصمیم معامله | UI ≠ منطق معامله |
| **D-004** | زمان‌بندی چند-نماد | APPROVED | معماری | ۲۰۲۴-Q4 | `OnTick` نمودار میزبان ≠ تمام نمادها — پیاده‌سازی از طریق `OnTimer` + `g_runtime`، کلاس `CScheduler` وجود ندارد | Timer/ صف نماد/تایم‌فریم |
| **D-005** | بلاک News | APPROVED | ریسک | ۲۰۲۴-Q4 | شکست عملیاتی News = بلاک ورود جدید (Fail-closed)؛ مدیریت پوزیشن جدا | Fail-closed روی `Entry`؛ `PositionManager` مستقل |
| **D-006** | تلاش مجدد | APPROVED | اجرا | ۲۰۲۴-Q4 | تلاش مجدد فقط پس از شکست ترمینال اثبات شده؛ عدم تلاش مجدد بر اساس timeout/ردگذار گم‌شده | همگام‌سازی دفترچه برای نتایج مبهم |
| **D-007** | هویت Setup/Attempt | APPROVED | اجرا | ۲۰۲۴-Q4 | `setup_id`، `attempt_id`، تیکت سفارش/معامله، شناسه پوزیشن — متمایز | Intent پایدار، Attempt منحصر به فرد |
| **D-008** | پرکردن جزئی | APPROVED | اجرا | ۲۰۲۴-Q4 | پرکردن جزئی ≠ پرکردن کامل — عدم تکمیل خودکار | حجم درخواستی/اجرا/باقی‌مانده متمایز |
| **D-009** | Fail-Closed Submit | APPROVED | اجرا | ۲۰۲۴-Q4 | Intent پایدار باید قبل از Submit تایید شود؛ تضمین‌های پایداری SQLite/MQL5 = UNKNOWN | D-08 skema min، D-09 policy |
| **D-010** | بازیابی Fail-Safe | APPROVED | اجرا | ۲۰۲۴-Q4 | بازیابی Fail-safe برای خرابی، نسخه schema نامعتبر، نوشتن ناموفق، تلاش‌های حل نشده | ذخیره‌سازی گم‌شده ≠ نصب تازه |
| **D-011** | تراکم Attempt ID | APPROVED | اجرا | ۲۰۲۴-Q4 | دنباله دیتابیس پایدار + مؤلفه منحصر به فرد؛ جزئیات یکتا/تصادم باز | D-08 skema |
| **D-012** | Revalidation ریسک | APPROVED | ریسک | ۲۰۲۴-Q4 | ریسک باید قبل از Submit یا تصمیم نگهداری سفارش باقی‌مانده revalidate شود | شکست/مبهم revalidation = ممنوعیت اقدام جدید |
| **D-013** | عدم بستن خودکار | APPROVED | ریسک | ۲۰۲۴-Q4 | پوزیشن‌های موجود نباید تنها برای رفع تداخل بسته شوند | مدیریت پوزیشن مستقل از گیت ورود |
| **D-014** | جریان اجرا | APPROVED | معماری | ۲۰۲۴-Q4 | `RiskEngine` → `PortfolioRisk` → `TradeExecutor` — ترتیب صریح، ردیابی قابل nebاشتن | نام مؤلفه ≠ اجرا — ردیابی فراخوان واقعی |
| **D-015** | تلاش مجدد خودکار | APPROVED | اجرا | ۲۰۲۴-Q4 | Intent پایدار و Attempt مبهم = عدم تلاش مجدد خودکار | حالت حل نشده صریح ترجیح داده می‌شود |
| **D-016** | تضمین‌های مرجعیت | APPROVED | مرجعیت | ۲۰۲۴-Q4 | انتشار/epoch هرگز rollback/hapus نمی‌شود؛ Coordinator منقضی شده بعد از lease رد می‌شود | `authority_epoch_fencing` |
| **D-017** | مدل اعتماد Coordinator | APPROVED | مرجعیت | ۲۰۲۴-Q4 | Coordinator مرجعیت متمرکز کنترل شده؛ Übernahme خودکار ممنوع | ORPHANED = حالت مسدود، بازیابی صریح |
| **D-018** | تازگی/انقضای Setup | APPROVED | استراتژی | ۲۰۲۴-Q4 | Setup باید پیش از Submit تازگی revalidate شود؛ انقضا بر اساس نقش تایم‌فریم | قراد تازگی صریح در SignalEngine |
| **D-019** | واگرایی RSI-only | APPROVED | استراتژی | ۲۰۲۶-۱۱-۲۱ | `CDivergenceEngine` فقط RSI — بافر iMACD histogram (بافر ۲) حذف شد | RSI+MACD = UNDECIDED، در Technical Debt (U-006) |

---

## ۳. تصمیمات ایمنی/ریسک

| شناسه | موضوع | وضعیت | تصمیم‌گیرنده | تاریخ | خلاصه تصمیم |
|------|--------|--------|------------|------|-------------|
| **D-020** | Fail-Closed Authority Recovery | APPROVED | ایمنی | ۲۰۲۶-۱۱-۲۱ | `ExecutionLedger::RecoverAuthorityFromOrphaned()` — گیت Fail-closed قبل از `DatabaseTransactionBegin()`، رد وقتی `HashOperatorToken()==UNVERIFIED`، بدون تغییر state/epoch/owner، بدون bypass |
| **D-021** | حالت‌های WS-2 (۱۸ حالت) | APPROVED | معماری | ۲۰۲۶-۱۱-۲۱ | ۱۸ حالت Runtime Readiness با `AuthoritativeOwner` صریح، انتقال‌های مجاز تعریف شده در `ENUM_RUNTIME_STATE` (AlgoMultiAssetEA.mq5:۴۸۲–۵۰۱) | نام‌های حالت: `RUNTIME_*` نه `WS2_*` |
| **D-022** | News Engine Fail-Closed | APPROVED | ریسک | ۲۰۲۶-۱۱-۲۱ | `CNewsEngine::EvaluateNews()` / `ShouldBlockEntry()` — تصمیم `DECISION_NEWS_BLOCKED` در موتور، پیش‌ازمهندسی حذف شده | کلاس صحیح: `CNewsEngine` (نه نام‌های فابریک شده قبلی) |
| **D-023** | PortfolioRisk WS-2 Fields | APPROVED | ریسک | ۲۰۲۶-۱۱-۲۱ | فیلدهای `read_complete`/`stale` برای fail-closed evaluaiton | در `PortfolioRisk.mqh` |

---

## ۴. تصمیمات عملیاتی/Git/تحویل

| شناسه | موضوع | وضعیت | تصمیم‌گیرنده | تاریخ | خلاصه تصمیم |
|------|--------|--------|------------|------|-------------|
| **D-024** | محافظت شاخه main | APPROVED | Git | ۲۰۲۴-Q4 | `main` محافظت شده: PR با ≥۱ review، status check، بدون force-push/delete | `main.branch_protection_policy` |
| **D-025** | ciclo کیفیت MQL5 | APPROVED | مهندسی | ۲۰۲۴-Q4 | baseline compile → audit → repair → refactor فقط با توجیه → repair → final compile → regression tests | `mql5_quality_cycle` |
| **D-026** | تشخیص Squash Merge | APPROVED | Git | ۲۰۲۴-Q4 | مقایسه Head SHA و Merge Commit SHA با درخت/blob/main — نه فقط تاریخچه commit | `squash_merge_detection` |
| **D-027** | گزارش تحویل Git | APPROVED | تحویل | ۲۰۲۴-Q4 | تمایز NOT AUTHORIZED / NOT RUN / FAILED / SUCCEEDED | `git_delivery.report_status` |
| **D-028** | پیش‌فرض داشبورد | APPROVED | UI | ۲۰۲۴-Q4 | `InpDashboardViewMode = DASHBOARD_NORMAL`, `InpDashboardDiagnostics = false` | `dashboard_defaults` |
| **D-029** | ایمنی Git/مجوز | APPROVED | Git | ۲۰۲۴-Q4 | هرگز reset/clean/stash/restore/amend/rebase/force-push/stage-all بدون مجوز صریح | `git_and_authorization_safety` |
| **D-030** | حذف شده (تکرار D-016) | **SUPERSEDED** | — | — | ادغام شده در D-016 (`authority_epoch_fencing`) | — |

---

## ۵. تصمیمات در انتظار (UNDECIDED/UNKNOWN) — نیاز به اقدام انسانی

| شناسه | موضوع | وضعیت | بلوکر | اقدام مورد نیاز | منبع بلوکر |
|------|--------|--------|-------|--------------|------------|
| **U-001** | مدل اعتماد رویداد نمودار | UNDECIDED | DT-006 | تصمیم A: امضای دیجیتال/namespace/rate-limit برای `OnChartEvent` | Workstream D |
| **U-002** | محافظت نمونه-واحد (Singleton) | UNDECIDED | DT-009 | تصمیم B: مطمئن کردن یک EA برای هر نماد/حساب | Workstream D |
| **U-003** |リカバری مالک مرده (Dead Owner) | UNDECIDED | DT-006 | تصمیم C: policy برای مالک حالت مرده در WS-2 | Workstream D |
| **U-004** | مالکیت جهان نماد (Symbol Universe) | UNDECIDED | DT-010 | تصمیم D: ثبت نماد متمرکز vs توزیع شده | Workstream D |
| **U-005** | F-E26-005 (استراتژی خاص) | UNDECIDED | — | تصمیم E: جزئیات استراتژی محرمانه — نیاز به مالک استراتژی | Workstream D |
| **U-006** | واگرایی RSI+MACD | UNDECIDED | DT-003 | تصمیم معماری M3: فعال‌سازی MACD divergence یا تأیید RSI-only | Workstream D |
| **U-007** | احراز هویت اپراتور (PKI/HMAC/IdP) | UNKNOWN | DT-002, B-003 | تحقیق M1، پیاده‌سازی M5 — فعلاً `UNVERIFIED` | Workstream D |
| **U-008** | پایداری SQLite/MQL5 | UNKNOWN | DT-005, B-004 | تست تصادم M5، تنظیم PRAGMA — فعلاً `UNVERIFIED` | Workstream D |
| **U-009** | آستانه‌های تازگی / امتیاز / وزن | UNKNOWN | — | تصمیم مالک استراتژی — هیچ آستانه اخترعی | Workstream D |
| **U-010** | نگاشت تایم‌فریم کاندیدا | UNKNOWN | — | تصمیم مالک استراتژی — فقط نقش‌های تایید شده | Workstream D |

---

## ۶. اصلاحات (Corrections) — ادعاهای قبلی متضاد

| شناسه | موضوع | قبل | بعد | شواهد | تاریخ |
|------|--------|-----|-----|--------|------|
| **CORR-001** | انتقال `entry_features` | ادعا: منتقل نمی‌شود | ✅ منتقل می‌شود در `BuildFeatureContext` | کد FeatureEngine | ۲۰۲۶-۱۰-۲۱ |
| **CORR-002** | وضعیت کامپایل فاز ۱۵ | ادعا: پایه فعلی | ❌ تاریخی — پایه فعلی تایید نشده | کامپایل مجدد لازم | ۲۰۲۶-۱۰-۲۱ |
| **CORR-003** | تست مرجعیت — نوع | ادعا: EA | ✅ Script با `OnStart()` | فایل `Scripts/TestAuthorityRecovery.mq5` | ۲۰۲۶-۱۱-۲۱ |
| **CORR-004** | واگرایی MACD | ادعا: RSI+MACD | ✅ فقط RSI — بافر ۲ وجود ندارد | کد DivergenceEngine، مستندات MQL5 | ۲۰۲۶-۱۱-۲۱ |

---

## ۷. الگوهای نام‌گذاری تصمیم

- **D-XXX** — تصمیم تایید شده (معماری/ریسک/اجرایی/Git)
- **U-XXX** — تصمیم در انتظار (نیاز به اقدام انسانی)
- **CORR-XXX** — اصلاح ادعای قبلی
- **DT-XXX** — تراکم فنی (در Technical Debt)

---

## ۸. بروزرسانی و مالکیت

- **مالک:** معمار اصلی / لیدر فنی
- **بروزرسانی:** در هر تصمیم معماری، بازبینی کد، یا فاز Roadmap
- **مخزن:** `docs/architecture/DECISION_LOG.fa.md` (این فایل)
- **همگام‌سازی:** Component Register، Rebuild Roadmap، Technical Debt

---

## ۹. ثبت تصمیم انسانی M1-DEC-D — ۲۰۲۶-۱۱-۲۲ (تاریخچه کامل)

### ۹.۱ تصمیم اول (رد پیشنهادی)
| شناسه | موضوع | پاسخ مالک پروژه | وضعیت تصمیم | اثر بر Gate |
|------|--------|----------------|-------------|-------------|
| **M1-DEC-D (v1)** | پذیرش عدم Resume خودکار Retry Handoff پس از Restart (Visibility ≠ Authority) | **رد شد؛ طراحی راهکار جایگزین لازم است** | **REJECTED — ALTERNATIVE REQUIRED** | **M0 BLOCKED** |

**توضیح:** مالک پروژه سیاست پیشنهادی مبنی بر موقت‌بودن Retry Handoff و Resume نشدن خودکار آن پس از Restart را نپذیرفت.

---

### ۹.۲ تصمیم نهایی — انتخاب Alternative A (۲۰۲۶-۱۱-۲۲)

| شناسه | موضوع | تصمیم مالک پروژه | وضعیت تصمیم | اثر بر Gate |
|------|--------|------------------|-------------|-------------|
| **M1-DEC-D** | Retry Handoff Non-Resumption Acceptance — انتخاب معماری بازیابی | **APPROVED — ALTERNATIVE A (Durable Recovery with Automated Revalidation)** | **OWNER SELECTED — DESIGN BASELINE** | **M1-DEC-D RESOLVED (Design)** |

**Alternative A — Durable Recovery with Automated Revalidation:**

**معماری:**
- بازیابی خودکار تنها برای وضعیت `INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED`
- در OnInit: Query `GetInterruptedRetryHandoffs()` و بازسازی handoff موقت
- پردازش از طریق `ProcessRetryPendingHandoff()` موجود
- اعتبارسنجی کامل پیش از Submit

**شرایط پیش‌نیاز (Preconditions) — باید همگی برقرار باشند:**
1. Approval Event معتبر، پایدار و خوانا باشد
2. `action_id` و `new_attempt_id` با هم تطبیق داشته باشند
3. `setup_claims.current_attempt_id` همان Attempt را نشان دهد
4. Retry Sequence دقیقاً مطابق Approval Event باشد
5. Attempt دقیقاً در وضعیت `INTENT_DURABLE_NOT_SUBMITTED` باشد
6. `submission_allowed == 0` (استثنا: `submission_allowed == 1` = RECONCILIATION_REQUIRED، کلا auto-recovery)
7. هیچ مدرک Submit، Order، Deal، Position، Partial Fill یا Broker Execution وجود نداشته باشد
8. Account Login و Server با حساب فعلی یکسان باشند
9. Strategy Group و Config Fingerprint معتبر و مطابق باشند
10. Symbol و Logical Setup Identity تغییر نکرده باشند
11. Coordinator و Authority با Epoch معتبر تأیید شوند
12. News Gate و Risk Gate تازه پاس شده باشند

**اعتبارسنجی مجدد (اجباری پیش از Submit):**
- تولید Plan تازه از HybridEngine
- اعتبارسنجی Setup و تازگی
- RiskEngine + PortfolioRisk
- اعتبارسنجی Symbol/Contract
- Authority/Epoch
- Ledger/Attempt State
- عدم Attempt/Submission تکراری

**موارد ممنوع برای Auto-Recovery (Fail-Closed):**
- `SUBMISSION_MAY_HAVE_OCCURRED` / `RECONCILIATION_REQUIRED` / Submitted / Partial Fill
- Broker Evidence موجود / Attempt unreadable or missing
- Approval/Event ناقص / Account-Server-Config mismatch
- Authority نامعتبر / ORPHANED / SQLite Transaction نامطمئن
- `submission_allowed == 1` (Bound but not marked) — باید Reconciliation شود

**Idempotency / Restart تکراری:**
- یک Approval Event فقط یک‌بار قابل مصرف (Claim/Retry Sequence با CAS کنترل)
- Authority/Epoch fencing مانع دو Instance همزمان
- عدم Coordinator معتبر = بلاک Submit

---

### ۹.۳ محدودیت‌های حیاتی و موارد UNVERIFIED (باید قبل از پیاده‌سازی حل شوند)

| مورد | شدت | توضیح | بلوکر پیاده‌سازی |
|------|------|--------|------------------|
| **FINDING-001** | CRITICAL | Zustand `INTENT_DURABLE_NOT_SUBMITTED` + `submission_allowed=1` (Bound but not marked) از Approval Event تازه جدا نشدنی است. اگر Prozess بعد از `MarkSubmissionBound` کرش کند، وضعیت شبیه تازه به نظر می‌رسد. | بله — باید `submission_allowed=1` را از auto-recovery مستثنی کنیم |
| **FINDING-002** | CRITICAL | `RecoverUnresolved` در OnInit تمام `INTENT_DURABLE_NOT_SUBMITTED` را cuarantine کرده و `RECONCILIATION_REQUIRED` می‌کند. Alternative A با این در تضاد است. | بله — باید RecoverUnresolved غیرفعال/مشروط شود |
| **FINDING-003** | HIGH | تضمین دوام SQLite بین `MarkSubmissionBound` و `MarkSubmissionMayHaveOccurred` = **UNVERIFIED** (D-008, DT-005, B-004) | بله — bound-not-marked به‌عنوان مبهم تلقی شود |
| **FINDING-004** | HIGH | `ProcessRetryPendingHandoff` فعلاً `submission_allowed` را چک نمی‌کند | بله — باید در recovery path اضافه شود |
| **FINDING-007** | HIGH | اعتبارسنجی Config/Account/Symbol/News در restart recovery ناقص است | بله — باید کامل شود |
| **FINDING-008** | HIGH | Alternative A بایستی operator consent را دور می‌زند (مخالف طراحی E2.6) | بله — باید re-consent explicit اضافه شود |
| **FINDING-003 (Risk-Auditor)** | UNVERIFIED | SQLite/MQL5 crash durability، WAL fsync، lock contention = ناشناخته | بله — تست M5 لازم |

**مهم:** این تصمیم **تنها طراحی معماری** است. **پیاده‌سازی مجاز نیست** تا زمانی که تمام موارد CRITICAL/HIGH حل و تست‌های مربوطه (M5) انجام شوند. تصمیم D-009، D-010، D-015، D-016 و قراردادهای Fail-Closed دیگر **باقی و غیرقابل تضعیف** می‌مانند.

---

### ۹.۴ تاریخچه کامل
- **۲۰۲۶-۱۱-۲۲ (v1):** پیشنهاد عدم Resume خودکار — **REJECTED**
- **۲۰۲۶-۱۱-۲۲ (v2):** انتخاب Alternative A — **OWNER SELECTED** (Design Baseline only)

---

*این ثبت THE منبع حقیقت برای تمام تصمیمات تایید شده است. هیچ کد، کامنت، یا مستندات قدیمی نمی‌تواند تصمیمات اینجا را 덮어쓰다 کند.*

