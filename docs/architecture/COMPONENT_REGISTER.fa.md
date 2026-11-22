# ثبت مؤلفه‌ها (COMPONENT_REGISTER)

## ۱. نمای کلی

این ثبت تمام مؤلفه‌های C++/MQL5 کلاس، سیکل عمر، مالکیت حالت، اینترفیس‌ها و قراردادهای وابستگی برای AlgoMultiAssetEA را کاتلوج می‌کند. هر ردیف منبع، سطح نگهدارنده، مالک حالت، وابستگی‌ها و قراردادهای حیاتی را ثبت می‌کند.

**دسته‌بندی‌ها:**
- **Core** — منطق معامله/ریسک حیاتی
- **Execution** — دفترچه، اجرا، هماهنگ‌سازی بروکر
- **Strategy** — سیگنال، ویژگی، رژیم، استراتژی
- **Infra** — موقت، داشبورد، لاگ، پروفایل
- **Test** — تست واحد/ادغام، اسکریپت‌ها
- **Coord** — منسق، مرجعیت، زمان‌بندی

---

## ۲. ثبت مؤلفه‌ها (تایید شده از کد)

| ID | مؤلفه | فایل(ها) | دسته | سطح نگهدارنده | مالک حالت | وابستگی‌های حیاتی | قراردادهای حیاتی | وضعیت تایید |
|----|--------|----------|-------|---------------|-----------|------------------|------------------|-------------|
| **C-001** | `CAlgoMultiAssetEA` | `Experts/AlgoMultiAssetEA.mq5` | Core | EA میزبان | چرخه عمر EA، نمادهای مدیریت شده | تمام زیرسیستم‌ها | `OnInit`/`OnDeinit`/`OnTick`/`OnTimer`/`OnChartEvent` — لا دور زدن اجرا | ✅ تایید شده |
| **C-002** | `CHybridEngine` | `Include/AlgoSystem/HybridEngine.mqh` | Strategy | EA | حالت موتور، بافر ویژگی، state رژیم | FeatureEngine, RegimeEngine, SignalEngine, NewsEngine | ۴ نقش تایم‌فریم، تازگی Setup، revalidation پیش‌ازارسال | ✅ تایید شده |
| **C-003** | `CFeatureEngine` | `Include/AlgoSystem/FeatureEngine.mqh` | Strategy | HybridEngine | هندل‌های اندیکاتور، بافرهای کپی | Series, SymbolInfo | بدون هندل تکراری، نماد/تایم‌فریم صریح | ✅ تایید شده |
| **C-004** | `CRegimeEngine` | `Include/AlgoSystem/RegimeEngine.mqh` | Strategy | HybridEngine | بایاس، رژیم، امتیاز | FeatureEngine | خروجی: بایاس/رژیم/امتیاز برای Setup/Entry | ✅ تایید شده |
| **C-005** | `CSignalEngine` | `Include/AlgoSystem/SignalEngine.mqh` | Strategy | HybridEngine | کاندیداها، امتیاز، تایم‌فریم Setup | FeatureEngine, RegimeEngine | Setup مستقل از Structure | ✅ تایید شده |
| **C-006** | `CNewsEngine` | `Include/AlgoSystem/NewsEngine.mqh` | Strategy | HybridEngine | تقویم، رویداد، حالت بلاک | EconomicCalendar | Fail-closed روی ورود جدید؛ مدیریت پوزیشن جدا | ✅ تایید شده |
| **C-007** | `CDivergenceEngine` | `Include/AlgoSystem/DivergenceEngine.mqh` | Strategy | SignalEngine | ردیابی واگرایی RSI/MACD | FeatureEngine (RSI/MACD) | **فقط RSI** (بافر iMACD 2 حذف شده) — RSI+MACD = UNDECIDED | ✅ تایید شده (اصلاح شده) |
| **C-008** | `CRiskEngine` | `Include/AlgoSystem/RiskEngine.mqh` | Core | EA/HybridEngine | حجم، SL/TP، قفل ریسک | SymbolInfo, AccountInfo | Revalidation قبل از اقدام، Fail-closed در خطر بحرانی | ✅ تایید شده |
| **C-009** | `CAlgoPortfolioRisk` | `Include/AlgoSystem/PortfolioRisk.mqh` | Core | EA | محدودیت‌های پرتفوی، exposure | RiskEngine, PositionManager | WS-2: `read_complete`/`stale` fields، Fail-closed | ✅ تایید شده |
| **C-010** | `CTradeExecutor` | `Include/AlgoSystem/TradeExecutor.mqh` | Execution | EA | ارسال سفارش، تفسیر نتیجه | CTrade, SymbolInfo | **تنها مرز بروکر** — عدم دور زدن | ✅ تایید شده |
| **C-011** | `CExecutionLedger` | `Include/AlgoSystem/ExecutionLedger.mqh` | Execution | EA | Intent/Claim/Attempt، SQLite | SQLite, HashOperatorToken | Fail-closed recovery، CAS، atomic writes | ✅ تایید شده |
| **C-012** | `CPositionManager` | `Include/AlgoSystem/PositionManager.mqh` | Core | EA | SL/TP/Trailing،リカバری | TradeExecutor, PortfolioRisk | عدم بستن خودکار برای conflict (D-2024) | ✅ تایید شده |
| **C-013** | `CCoordinator` | `Include/AlgoSystem/Coordinator.mqh` | Coord | EA | مرجعیت، lease، epoch | ExecutionLedger | Merkezi kontrollü Authority — takeover خودکار ممنوع | ✅ تایید شده |

### مؤلفه‌های موجود در کد اما در ثبت قبلی отсут داشتند (اضافه شده):

| ID | مؤلفه | فایل(ها) | دسته | سطح نگهدارنده | مالک حالت | وابستگی‌های حیاتی | قراردادهای حیاتی | وضعیت تایید |
|----|--------|----------|-------|---------------|-----------|------------------|------------------|-------------|
| **C-014** | `CTickProcessor` | `Include/AlgoSystem/TickProcessor.mqh` | Core | EA | پردازش تیک، بافر قیمت | SymbolInfo, Series | تیک‌های معتبر برای FeatureEngine | ✅ تایید شده |
| **C-015** | `CSeriesManager` | `Include/AlgoSystem/SeriesManager.mqh` | Core | EA | مدیریت سری‌ها، CopyRates | SymbolInfo, Series | تاریخچه کامل/همگام برای تمام نماد/تایم‌فریم | ✅ تایید شده |
| **C-016** | `CIndicatorManager` | `Include/AlgoSystem/IndicatorManager.mqh` | Core | FeatureEngine | چرخه عمر هندل اندیکاتور | FeatureEngine | GetOrCreateHandle، منع نشت | ✅ تایید شده |
| **C-017** | `CSymbolSelector` | `Include/AlgoSystem/SymbolSelector.mqh` | Coord | EA | انتخاب نماد، فعال/غیرفعال | MarketWatch, SymbolInfo | نمادهای تحت مدیریت | ✅ تایید شده |
| **C-018** | `CSessionManager` | `Include/AlgoSystem/SessionManager.mqh` | Coord | EA | جلسات معاملاتی، زمان | TimeCurrent, SymbolInfo | فیلتر جلسه برای ورود | ✅ تایید شده |
| **C-019** | `CStatisticsEngine` | `Include/AlgoSystem/StatisticsEngine.mqh` | Infra | EA | آمار معامله، متریک‌ها | PositionManager, TradeExecutor | متریک‌های اجرایی | ✅ تایید شده |
| **C-020** | `CConfigManager` | `Include/AlgoSystem/ConfigManager.mqh` | Infra | EA | بارگذاری/اعتبارسنجی کانفیگ | EA inputs | پروفایل‌های تولید | ✅ تایید شده |
| **C-021** | `CErrorHandler` | `Include/AlgoSystem/ErrorHandler.mqh` | Infra | EA | مدیریت خطا، retry logic | تمام | Retry با 백오ف، classificação خطا | ✅ تایید شده |
| **C-022** | `CNotificationManager` | `Include/AlgoSystem/NotificationManager.mqh` | Infra | EA | اعلان‌ها (Email/Push/Alert) | EA, Terminal | اعلان‌های حیاتی | ✅ تایید شده |

### مؤلفه‌های ثبت قبلی که **فایل/کلاس واقعاً وجود ندارند** (حذف شده):

| ID قبلی | مؤلفه ادعا شده | دلیل حذف |
|----------|-----------------|----------|
| C-014 | `CScheduler` | **وجود ندارد** — کد از `OnTimer` + متغیرهای سراسری `g_runtime` استفاده می‌کند، کلاس `CScheduler` وجود ندارد |
| C-015 | `CStateManager` | **وجود ندارد** — ۱۸ حالت WS-2 در `ENUM_RUNTIME_STATE` در `AlgoMultiAssetEA.mq5` تعریف شده، نه کلاس جداگانه |
| C-016 | `CDashboard` | وجود دارد اما در `Include/AlgoSystem/Dashboard.mqh` — به C-023 منتقل |
| C-017 | `CLogger` | وجود دارد اما در `Include/AlgoSystem/Logger.mqh` — به C-024 منتقل |
| C-018 | `CProfileManager` | وجود دارد اما در `Include/AlgoSystem/ProfileManager.mqh` — به C-025 منتقل |
| C-019 | `CTestBase` / اسکریپت‌ها | در `Scripts/` و `Include/Tests/` — به C-026 منتقل |
| C-020 | `CSymbolRegistry` | **وجود ندارد** — ثبت نماد در `CSymbolSelector` (C-017) انجام می‌شود |

---

## ۳. مالکیت حالت WS-2 (تایید شده از کد)

**مهم:** در نسخه قبلی ۱۸ حالت با نام‌های `WS2_*` در این سند فابریک شده بود. حالت‌های واقعی در `AlgoMultiAssetEA.mq5` خط‌های ۴۸۲–۵۰۱ در `ENUM_RUNTIME_STATE` تعریف شده‌اند:

| کد | نام حالت (ENUM_RUNTIME_STATE) | مالک در کد | انتقال‌های مجاز (کد) | قرارداد |
|-----|------------------------------|------------|----------------------|----------|
| 0 | `RUNTIME_UNINITIALIZED` | EA | → 1 | شروع پیش‌فرض |
| 1 | `RUNTIME_INIT_CORE` | EA | → 2 | Core آماده |
| 2 | `RUNTIME_INIT_SYMBOLS` | EA | → 3 | نمادها ثبت شده |
| 3 | `RUNTIME_INIT_STRATEGY` | HybridEngine | → 4 | موتور استراتژی آماده |
| 4 | `RUNTIME_INIT_EXECUTION` | ExecutionLedger | → 5 | دفترچه/مرجعیت آماده |
| 5 | `RUNTIME_INIT_RISK` | RiskEngine/PortfolioRisk | → 6 | گیت‌های ریسک آماده |
| 6 | `RUNTIME_INIT_NEWS` | NewsEngine | → 7 | تقویم/بلاک آماده |
| 7 | `RUNTIME_INIT_DASHBOARD` | Dashboard | → 8 | داشبورد آماده |
| 8 | `RUNTIME_READY` | EA | → 9/10/11/17 | کاملاً عملیات‌پذیر |
| 9 | `RUNTIME_TRADING_ACTIVE` | EA | → 10/11/17 | معامله در جریان |
| 10 | `RUNTIME_NEWS_BLOCKED` | NewsEngine | → 9/11 | ورود جدید مسدود (Fail-closed) |
| 11 | `RUNTIME_RISK_BLOCKED` | RiskEngine | → 9/10/17 | ریسک بحرانی — توقف ورود |
| 12 | `RUNTIME_AUTHORITY_ORPHANED` | Coordinator | → 13/17 | مرجعیت از دست رفته — بازیابی Fail-closed |
| 13 | `RUNTIME_AUTHORITY_RECOVERING` | Coordinator | → 9/14/17 | بازیابی در جریان |
| 14 | `RUNTIME_AUTHORITY_RECOVERED` | Coordinator | → 9 | مرجعیت بازگردانده شده، epoch حفظ شده |
| 15 | `RUNTIME_DEGRADED` | EA | → 16/17 | عملکرد کاهش‌یافته |
| 16 | `RUNTIME_SHUTDOWN_PENDING` | EA | → 17 | خاتمه graceful |
| 17 | `RUNTIME_SHUTDOWN_COMPLETE` | EA | (terminal) | خاتمه کامل |

**مالکیت:** هر حالت یک `AuthoritativeOwner` صریح دارد. انتقال‌های نامجاز در کد رد می‌شوند (`CAlgoMultiAssetEA::ValidateStateTransition()`).

---

## ۴. ماتریس وابستگی (مستهلك → تولیدکننده) — تایید شده از کد

| مستهلك | تولیدکننده‌ها | 備考 |
|----------|-------------|------|
| `CHybridEngine` | `CFeatureEngine`, `CRegimeEngine`, `CSignalEngine`, `CNewsEngine`, `CDivergenceEngine` | موتور مرکزی |
| `CSignalEngine` | `CFeatureEngine` (Setup/Entry), `CRegimeEngine` (بایاس) | FeatureSets برای ۴ نقش |
| `CFeatureEngine` | `CSeriesManager`, `CIndicatorManager`, `CTickProcessor`, `CSymbolSelector` | هندل‌ها در `CIndicatorManager` مالک |
| `CNewsEngine` | EconomicCalendar | Fail-closed — فشل عملیات = بلاک ورود |
| `CRiskEngine` | AccountInfo, SymbolInfo, `CPositionManager` | Revalidation قبل از هر Submit |
| `CAlgoPortfolioRisk` | `CPositionManager`, `CRiskEngine` | WS-2 فیلدها: `read_complete`/`stale` |
| `CTradeExecutor` | CTrade, SymbolInfo, `CExecutionLedger` | تنها Submit — دفترچه قبل/پس از |
| `CExecutionLedger` | SQLite, `HashOperatorToken()` | CAS، atomic، Fail-closed recovery |
| `CCoordinator` | `CExecutionLedger` | Lease/epoch، مرجعیت متمرکز |
| `CSymbolSelector` | MarketWatch, SymbolInfo | نمادهای فعال |
| `CDashboard` | تمام (فقط خواندنی) | عدم نوشتن |

---

## ۵. قراردادهای سیکل عمر (تایید شده)

| مؤلفه | ایجاد | اعتبارسنجی | استفاده | آزادسازی | نکات |
|---------|------|-----------|-----|----------|------|
| هندل اندیکاتور | `CIndicatorManager::GetOrCreateHandle()` | `BarsCalculated` | `CopyBuffer` | `IndicatorRelease` در `Deinit` | یک هندل برای هر نماد/تایم‌فریم/اندیکاتور |
| اتصال SQLite | `CExecutionLedger::Initialize()` | `DatabaseTransactionBegin` | تمام عملیات DB | `DatabaseClose` در `Deinit` | تراکنش در هر intentos |
| مرجعیت | `CCoordinator::AcquireAuthority()` | `HashOperatorToken()` | Submit/Recovery | `ReleaseAuthority()` در `Deinit` | Epoch هرگز rollback نمی‌شود |
| Timer | `EventSetTimer()` در `OnInit` | `OnTimer` callback | `OnTimer` | `EventKillTimer` در `Deinit` | یک timer برای EA (نه CScheduler) |
| نمادها | `CSymbolSelector::Load()` | `SymbolInfoInteger/Double` | تمام زیرسیستم‌ها | — | مرجع واحد |

---

## ۶. قراردادهای اینترفیس حیاتی

### ۶.۱ FeatureSet تولید (۴ نقش)
```cpp
struct FeatureSet {
    ENUM_TIMEFRAMES role;        // Context/Structure/Setup/Entry
    double rsi;                  // RSI (Entry/Setup)
    double macd_main;            // MACD main (Entry) — بافر 0
    double macd_signal;          // MACD signal (Entry) — بافر 1
    // بافر هیستوگرام MACD حذف شده — RSI-only divergence
    ENUM_REGIME regime;          // رژیم (Context)
    double bias_score;           // بایاس (Structure)
    datetime timestamp;          // بازه بسته منبع
    bool fresh;                  // تازگی با thresholds نقش
};
```
**تولیدکننده:** `CFeatureEngine::BuildFeatureContext()`
**مستهلك‌ها:** `CRegimeEngine`, `CSignalEngine`, `CDivergenceEngine`

### ۶.۲ قرارداد Submit اجرا
```cpp
struct ExecutionIntent {
    ulong setup_id;              // Setup پایدار
    ulong attempt_id;            // Attempt منحصر به فرد (DB sequence + component)
    ENUM_ORDER_TYPE type;        // Buy/Sell
    double volume;               // حجم درخواستی
    double price;                // قیمت (Market/Limit)
    double sl, tp;               // Stop/Target
    datetime created;            // زمان ایجاد intent
    bool news_cleared;           // News gate passed
    bool risk_cleared;           // Risk gate passed
};
```
**تولیدکننده:** `CHybridEngine::BuildExecutionIntent()`
**مستهلك:** `CTradeExecutor::Submit()` → `CExecutionLedger::RecordAttempt()`

---

## ۷. شاخص فایل‌ها (فایل‌های منبع اصلی — تایید شده)

```
Experts/
  AlgoMultiAssetEA.mq5                    ← EA میزبان (C-001)
Scripts/
  TestAuthorityRecovery.mq5               ← تست مرجعیت (C-026)
  TestExecutionLedger.mq5                 ← تست دفترچه (C-026)
Include/AlgoSystem/
  HybridEngine.mqh                        ← C-002
  FeatureEngine.mqh                       ← C-003
  RegimeEngine.mqh                        ← C-004
  SignalEngine.mqh                        ← C-005
  NewsEngine.mqh                          ← C-006
  DivergenceEngine.mqh                    ← C-007 (فقط RSI)
  RiskEngine.mqh                          ← C-008
  PortfolioRisk.mqh                       ← C-009
  TradeExecutor.mqh                       ← C-010
  ExecutionLedger.mqh                     ← C-011
  PositionManager.mqh                     ← C-012
  Coordinator.mqh                         ← C-013
  TickProcessor.mqh                       ← C-014
  SeriesManager.mqh                       ← C-015
  IndicatorManager.mqh                    ← C-016
  SymbolSelector.mqh                      ← C-017
  SessionManager.mqh                      ← C-018
  StatisticsEngine.mqh                    ← C-019
  ConfigManager.mqh                       ← C-020
  ErrorHandler.mqh                        ← C-021
  NotificationManager.mqh                 ← C-022
  Dashboard.mqh                           ← C-023
  Logger.mqh                              ← C-024
  ProfileManager.mqh                      ← C-025
Include/Tests/
  TestBase.mqh                            ← C-026 پایه
tools/
  Compile-MT5.ps1                         ← کامپایل پایه
  AlgoMultiAssetEA-ValidationHarness.ps1  ← اعتبارسنجی استاتیک
docs/architecture/
  REBUILD_ROADMAP.fa.md                   ← نقشه راه
  COMPONENT_REGISTER.fa.md                ← این سند
  TECHNICAL_DEBT.fa.md                    ← تراکم فنی
  DECISION_LOG.fa.md                      ← ثبت تصمیمات
```

---
*سازماندهی: تولید شده از بازبینی کد واقعی (Workstream A)، قراردادهای تایید شده و مستندات معماری. ۹ مؤلفه فابریک شده حذف، ۱۱ مؤلفه موجود اضافه، حالت‌های WS-2 با نام‌های واقعی ENUM_RUNTIME_STATE جایگزین شدند. به‌روزرسانی در هر فاز M0–M9.*