# AlgoMultiAssetEA Strategy Tester Report

**Report Date**: 2026-11-13  
**EA Version**: 1.002 (compiled 2026-11-13 15:31)  
**Terminal**: AMarkets MetaTrader 5 Build 5.0.0.5370  
**Test Profile**: `AlgoMultiAssetEA_v1.002_DAY_BASELINE.set`  
**Optimization Profile**: `AlgoMultiAssetEA_v1.002_DAY_OPTIMIZATION.set`

---

## 1. Test Configuration

### 1.1 Environment
| Parameter | Value |
|-----------|-------|
| Terminal Installation | `C:\Program Files\AMarkets - MetaTrader 5` |
| Terminal Data Folder | `C:\Users\mousa\AppData\Roaming\MetaQuotes\Terminal\EBC70E542FD2519E5E0B3CC8F66A5C22` |
| MetaEditor | `metaeditor64.exe` (Build 5.0.0.5370) |
| Tester Agent | `metatester64.exe` (Build 5.0.0.5370) |
| EA Path | `MQL5\Experts\AlgoMultiAssetEA.mq5` |
| EX5 Path | `MQL5\Experts\AlgoMultiAssetEA.ex5` (SHA256: `a1b2c3d4...` - to be filled after verification) |

### 1.2 Test Parameters (Baseline)
| Category | Parameter | Value |
|----------|-----------|-------|
| **General** | Trading Style | STYLE_DAY_TRADING (1) |
| | Execution Mode | MODE_BACKTEST (3) |
| | Log Level | LOG_DEBUG (6) |
| **Symbols** | Primary | XAUUSDb (Gold) |
| | Secondary | XAGUSDb (Silver), BTCUSD (Bitcoin) |
| | Dynamic Universe | Disabled |
| **Hybrid Decision** | Min RR | 1.5 |
| | Min Score | 70.0 |
| | Conflict Threshold | 15.0 |
| | Entry Tolerance (Day) | 20 points |
| **Volume Profile** | Session Bars | 78 |
| | Rolling Bars | 156 |
| | Value Area % | 0.68 |
| **Liquidity** | Swing Lookback | 5 |
| | Equal Tolerance | 3 points |
| | Max Level Age | 100 bars |
| | Sweep Confirm | 3 bars |
| **Divergence** | RSI Period | 14 |
| | MACD Fast/Slow/Signal | 12/26/9 |
| | Pivot Tolerance | 0.02% |
| | Max Age | 30 bars |
| **Momentum** | Lookback | 50 |
| **Regime** | ADX Period | 14 |
| | ADX Trend Threshold | 25 |
| | High Vol Ratio | 1.5 |
| | Low Vol Ratio | 0.7 |
| | Range Lookback | 20 |
| | Hysteresis | 3 bars |
| **News** | Enabled | false |
| **Risk** | Risk/Trade | 1.0% |
| | Daily Loss Limit | 3.0% |
| | Monthly Loss Limit | 10.0% |
| | Max Consecutive Losses | 3 |
| | Max Positions Total | 3 |
| | Max Positions/Symbol | 1 |
| | Max Positions/Strategy | 1 |
| | Max Portfolio Risk | 3.0% |
| | Max Precious Metals Risk | 2.0% |
| | Margin Safety | 0.80 |
| | Deviation Points | 20 |
| **Sessions** | Session Filter | true (0-24) |
| | Spread Filter | true (max 50 points) |
| **Position Mgmt** | Break-Even | false |
| | Trailing | false |
| | Time Exit | false |
| **Freshness** | Context/Structure/Setup | 300s |
| | Entry | 60s |

### 1.3 Backtest Settings
| Parameter | Value |
|-----------|-------|
| Symbol | XAUUSDb |
| Timeframe | H1 (Context), M15 (Entry) |
| Model | Every tick based on real ticks |
| Date From | 2026.01.01 |
| Date To | 2026.11.01 |
| Deposit | 100,000 USD |
| Currency | USD |
| Leverage | 1:100 |
| Optimization | Disabled (single pass) |
| Visual Mode | Disabled |

---

## 2. Architecture Under Test

### 2.1 Signal Pipeline (Hybrid Engine)
```
MarketData → Features → Regime → Strategies → SignalEngine
    ↓
Volume Profile (VP) → Liquidity/Structure → Regime (ADX/Vol)
    ↓
Divergence (RSI/MACD) → Momentum (ATR/ROC) → News Filter
    ↓
Bias Engine → Gate Check (Hard Gates) → Score Calculation
    ↓
TradePlan Build → RiskEngine → PortfolioRisk → TradeExecutor
```

### 2.2 Hard Gates (Fail-Closed)
1. **Data Sufficient** — All 4 timeframe snapshots valid
2. **Data Fresh** — Per-role freshness thresholds met
3. **Setup Valid** — Volume Profile calculated
4. **Regime Compatible** — Not INSUFFICIENT_DATA
5. **News Clear** — No high-impact news blackout
6. **Spread Acceptable** — Within style-specific max
7. **Entry Distance** — Price within tolerance
8. **RR Minimum** — ≥ 1.5
9. **Score Threshold** — ≥ 70.0
10. **Conflict Threshold** — Long/Short diff ≥ 15.0

### 2.3 Risk & Execution Flow (F-002/F-005.2)
```
Signal → RiskEngine.Evaluate() → PortfolioRisk.CanOpen()
    → PortfolioRisk.CanAdmit() [with reservations]
    → ExecutionLedger.CreateSetupClaimAndIntent() [atomic]
    → TradeExecutor.Execute() [with authority check]
    → ExecutionLedger.RecordResult() + Reconciliation
```

---

## 3. Expected Test Outcomes

### 3.1 Baseline Pass Criteria
| Metric | Threshold | Rationale |
|--------|-----------|-----------|
| **Compile** | 0 errors, 0 warnings | Quality gate |
| **Static Tests** | 85/85 PASS | Regression suite |
| **Backtest Completion** | 100% bars processed | No crashes |
| **Trade Count** | > 0 trades | Signal generation active |
| **Max Drawdown** | < 10% | Risk limits enforced |
| **Profit Factor** | > 1.0 | Positive expectancy |
| **Sharpe Ratio** | > 0.5 | Risk-adjusted return |
| **Recovery Factor** | > 1.0 | Drawdown recovery |
| **No Orphan Attempts** | 0 unresolved | Ledger integrity |
| **Authority Valid** | Coordinator elected | E2.6 enforced |

### 3.2 Key Metrics to Record
- Net Profit / Gross Profit / Gross Loss
- Max Drawdown (%, $)
- Total Trades / Win Rate / Avg Win / Avg Loss
- Profit Factor / Expected Payoff / Sharpe / Sortino
- SQN (System Quality Number)
- Max Consecutive Wins/Losses
- Longest Winning/Losing Streak
- Average Trade Duration
- Margin Calls / Stop Outs (should be 0)

---

## 4. Test Execution Procedure

### 4.1 Preflight Checklist
```powershell
# 1. Verify EX5 is fresh (compile timestamp = source timestamp)
# 2. Verify symbol history synchronized (XAUUSDb H1, M15)
# 3. Verify terminal build matches MetaEditor build
# 4. Load profile: AlgoMultiAssetEA_v1.002_DAY_BASELINE.set
# 5. Confirm MODE_BACKTEST selected
# 6. Confirm date range and deposit
```

### 4.2 Launch Command
```powershell
# Via terminal64.exe with INI config (recommended)
# Or via Strategy Tester UI with loaded .set profile
```

### 4.3 Post-Test Verification
```powershell
# 1. Check Experts log for: SYSTEM_READY, initialization sequence
# 2. Check Journal for: test start/end, any errors
# 3. Export HTML report from Strategy Tester
# 4. Verify EX5 SHA256 matches pre-test
# 5. Run regression suite: tools\ValidationHarness.Tests.ps1
```

---

## 5. Optimization Protocol (Walk-Forward)

### 5.1 In-Sample / Out-of-Sample Split
| Period | Type | Date Range | Purpose |
|--------|------|------------|---------|
| IS-1 | In-Sample | 2026.01.01 - 2026.04.30 | Parameter optimization |
| OOS-1 | Out-of-Sample | 2026.05.01 - 2026.07.31 | Validation |
| IS-2 | In-Sample | 2026.05.01 - 2026.08.31 | Re-optimization |
| OOS-2 | Out-of-Sample | 2026.09.01 - 2026.11.01 | Final validation |

### 5.2 Optimization Parameters (Genetic Algorithm)
- **Generations**: 50
- **Population**: 100
- **Fitness**: Custom (`CTesterFitness::Calculate()`)
  - `NetProfit / MaxDrawdown * SQN * Sqrt(TradeCount)`
- **Forward Pass**: 30% of IS period
- **Criteria**: Max Drawdown < 15%, Trade Count > 30, Profit Factor > 1.2

### 5.3 Parameter Ranges (from `AlgoMultiAssetEA_v1.002_DAY_OPTIMIZATION.set`)
| Parameter | Min | Max | Step |
|-----------|-----|-----|------|
| InpMinRR | 1.0 | 3.0 | 0.1 |
| InpMinScore | 50 | 90 | 5 |
| InpConflictThreshold | 5 | 30 | 5 |
| InpEntryToleranceDay | 10 | 50 | 5 |
| InpSwingLookback | 3 | 10 | 1 |
| InpEqualTolerancePoints | 1 | 10 | 1 |
| InpSweepConfirmBars | 1 | 5 | 1 |
| InpADXTrendThreshold | 20 | 30 | 1 |
| InpHighVolatilityRatio | 1.2 | 2.0 | 0.1 |
| InpLowVolatilityRatio | 0.5 | 1.0 | 0.1 |
| InpRangeLookback | 10 | 50 | 5 |
| InpHysteresisBars | 1 | 10 | 1 |
| InpRiskPercent | 0.5 | 2.0 | 0.25 |
| InpDailyLossLimit | 2.0 | 5.0 | 0.5 |
| InpMonthlyLossLimit | 5.0 | 20.0 | 1.0 |
| InpMaxPortfolioRisk | 2.0 | 5.0 | 0.5 |
| InpBreakEvenTriggerR | 0.5 | 2.0 | 0.25 |
| InpTrailingATRMultiplier | 1.0 | 3.0 | 0.25 |
| InpMaxHoldingMinutes | 120 | 480 | 60 |
| InpFreshnessContextSeconds | 60 | 600 | 60 |

---

## 6. Validation Results (To Be Filled After Execution)

### 6.1 Baseline Test
| Metric | Result | Status |
|--------|--------|--------|
| Compile | TBD | ⬜ NOT RUN |
| Static Tests (85) | TBD | ⬜ NOT RUN |
| Backtest Start | TBD | ⬜ NOT RUN |
| Backtest Complete | TBD | ⬜ NOT RUN |
| Net Profit | TBD | ⬜ NOT RUN |
| Max Drawdown % | TBD | ⬜ NOT RUN |
| Profit Factor | TBD | ⬜ NOT RUN |
| Sharpe Ratio | TBD | ⬜ NOT RUN |
| Total Trades | TBD | ⬜ NOT RUN |
| Win Rate % | TBD | ⬜ NOT RUN |
| Orphan Attempts | TBD | ⬜ NOT RUN |

### 6.2 Walk-Forward Results
| Period | Net Profit | Max DD% | PF | Trades | Status |
|--------|------------|---------|----|--------|--------|
| IS-1 | TBD | TBD | TBD | TBD | ⬜ NOT RUN |
| OOS-1 | TBD | TBD | TBD | TBD | ⬜ NOT RUN |
| IS-2 | TBD | TBD | TBD | TBD | ⬜ NOT RUN |
| OOS-2 | TBD | TBD | TBD | TBD | ⬜ NOT RUN |

### 6.3 Robustness Checks
| Check | Result | Status |
|-------|--------|--------|
| Parameter Stability (OOS/IS correlation) | TBD | ⬜ NOT RUN |
| Monte Carlo (100 runs, 95% CI) | TBD | ⬜ NOT RUN |
| Slippage/Spread Sensitivity (+50%) | TBD | ⬜ NOT RUN |
| Different Symbol (XAGUSDb) | TBD | ⬜ NOT RUN |
| Different Style (SWING) | TBD | ⬜ NOT RUN |

---

## 7. Known Limitations & Risks

| Risk | Mitigation |
|------|------------|
| **History Quality** — Tick data may have gaps | Verify `SymbolIsSynchronized` in logs; use "Every tick based on real ticks" model |
| **Spread Assumptions** — Backtest uses historical spread | Test with widened spread (+50%) in sensitivity |
| **News Data** — News filter disabled in baseline | Enable `InpNewsEnabled=true` for separate test |
| **Multi-Symbol** — Baseline tests XAUUSDb only | Run separate tests for XAGUSDb, BTCUSD |
| **Execution Model** — MODE_BACKTEST enables execution | Verify `InpMode=3` and `MQLInfoInteger(MQL_TESTER)` |
| **Ledger Persistence** — SQLite in tester may differ | Verify `ExecutionLedger.Initialize()` succeeds in tester |

---

## 8. Artifacts

| Artifact | Path | Description |
|----------|------|-------------|
| Baseline Profile | `MQL5\profiles\Tester\AlgoMultiAssetEA_v1.002_DAY_BASELINE.set` | Single-pass backtest config |
| Optimization Profile | `MQL5\profiles\Tester\AlgoMultiAssetEA_v1.002_DAY_OPTIMIZATION.set` | Genetic optimization config |
| Compiled EX5 | `MQL5\Experts\AlgoMultiAssetEA.ex5` | Build artifact (verify SHA256) |
| Source MQ5 | `MQL5\Experts\AlgoMultiAssetEA.mq5` | Source code (v1.002) |
| Regression Suite | `tools\ValidationHarness.Tests.ps1` | 85 static tests |
| Compile Script | `tools\Compile-MT5.ps1` | MetaEditor build with log capture |

---

## 9. Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Strategy Developer | | | |
| Risk Review | | | |
| QA / Test Engineer | | | |
| Production Deploy | | | |

---

**Note**: This report documents the test *plan and configuration*. Actual results must be filled in after authorized Strategy Tester execution. A successful compile and static test pass are prerequisites but do not constitute trading validation.

**Status**: `NOT RUN` — Awaiting explicit authorization for Strategy Tester execution.