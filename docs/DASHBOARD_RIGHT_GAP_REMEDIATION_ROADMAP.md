# Dashboard Right-Gap Docking — Remediation Roadmap

**Project:** AlgoMultiAssetEA  
**Component:** `Include/AlgoSystem/HybridDashboard.mqh` + `Experts/AlgoMultiAssetEA.mq5`  
**Date:** 2026-11-20  
**Status:** **IMPLEMENTED** — All fixes complete, compile-verified, static-reviewed  
**Next Phase:** Runtime validation (requires explicit authorization)

---

## 1. Remediation Summary

| Phase | Status | Description |
|-------|--------|-------------|
| **P1: Geometry & Docking** | ✅ COMPLETE | Dynamic right-gap docking using `ChartTimePriceToXY`, `CHART_WIDTH_IN_BARS`, `CHART_SHIFT`, `CHART_SHIFT_SIZE` |
| **P2: Layout Priority** | ✅ COMPLETE | Strategy Primary cards (5 fields) render first in all ViewModes; priority-based space exhaustion |
| **P3: State Consistency** | ✅ COMPLETE | `ResetDiagnosticsFields()` called at start of `UpdateDashboardForChart()` |
| **P4: Object Cleanup** | ✅ COMPLETE | Chart-specific retry prefix; `Clear()` deletes both prefixes; chart-change cleanup |
| **P5: Display Robustness** | ✅ COMPLETE | Label capacity 512, wrap limit 80, font clamp ≥6pt, array bounds fixed |

---

## 2. Detailed Implementation Map

### 2.1 New Functions Added

| Function | File | Purpose |
|----------|------|---------|
| `CalculateCurrentCandleRightEdge()` | `HybridDashboard.mqh:950` | Computes pixel X of current candle right edge using `ChartTimePriceToXY` + `CHART_WIDTH_IN_BARS` |
| `CalculateUsablePlotRight()` | `HybridDashboard.mqh:984` | Computes usable plot right boundary accounting for `CHART_SHIFT`/`CHART_SHIFT_SIZE` |
| `ResetDiagnosticsFields()` | `HybridDashboard.mqh:810` | Canonical reset for Diagnostics-only fields (`external_risk_lock_state`, `last_successful_stage`, `reason`) |

### 2.2 Functions Significantly Modified

| Function | Key Changes |
|----------|-------------|
| `RecalculateDashboardLayout()` | Rewritten: dynamic width = `min(preferred_width, available_gap)`; fallback with candle clamp |
| `LayoutCards()` | Reordered: priority-based (Header→Status→Primary→Stage→Health→Diagnostics→Retry); Primary/Stage always rendered |
| `BuildCardContent()` | Verified: Primary Strategy fields priority 2–6; all 5 visible in all ViewModes |
| `Clear()` | Added `ObjectsDeleteAll(chart_id, m_retry_btn_prefix)`; label reset loop uses `m_label_count` |
| `Render()` (chart-change) | Delete both `m_object_prefix` and `m_retry_btn_prefix` before reassignment |
| `InitializeTheme()` | Font clamp: `base_size >= 6`, `diagnostics >= 6` |
| `UpdateDashboardForChart()` (EA) | Added `g_dashboard.ResetDiagnosticsFields()` at start |

### 2.3 Constants Updated

| Constant | Old | New | Location |
|----------|-----|-----|----------|
| `MAX_WRAP_LINES` | 40 | 80 | Line 4 |
| `m_label_names[]` | 256 | 512 | Line 175 |
| `m_label_rel_x/y/valid[]` | 256 | 512 | Lines 176–178 |
| `m_label_count` | 256 | 512 | Line 668 |

---

## 3. Acceptance Criteria — All MET

| Criterion | Verification |
|-----------|--------------|
| **Zero compile errors/warnings** | ✅ MetaEditor 5.0.0.6230: 0 errors, 0 warnings |
| **ValidationHarness passes** | ✅ 6/6 critical invariants; 2 pre-existing warnings only |
| **Code review (code-reviewer)** | ✅ P2 findings fixed; no P0/P1 |
| **Risk audit (risk-auditor)** | ✅ P2/P3 findings fixed; no P0/P1 |
| **No trading logic bypass** | ✅ Dashboard remains observational only |
| **No risk gate bypass** | ✅ Confirmed by risk audit |
| **No auto-retry** | ✅ Retry UI display-only; ledger handles approval |

---

## 4. Pending Validation Gates (Require Explicit Authorization)

| Gate | Status | Required Authorization |
|------|--------|------------------------|
| **Live Chart Verification** | NOT RUN | User must attach EA to chart and verify: right-gap docking, ViewMode transitions, no ghost objects on removal |
| **Strategy Tester Backtest** | NOT RUN | User must run backtest with dashboard enabled; verify no crashes, correct rendering |
| **Visual Strategy Tester** | NOT RUN | User must run visual test; verify layout at different chart sizes/timeframes |
| **Multi-Symbol Stress** | NOT RUN | Verify dashboard on multiple charts simultaneously |

---

## 5. Risk Register — Post-Remediation

| ID | Risk | Severity | Status | Notes |
|----|------|----------|--------|-------|
| R-1 | Primary cards hidden on extremely small charts | P2 | MITIGATED | Primary/Stage now always rendered; only Health/Diagnostics/Retry hidden |
| R-2 | Label array mismatch | P3 | FIXED | `Clear()` now uses `m_label_count` (512) |
| R-3 | Fallback candle overlap | P3 | FIXED | Fallback clamps `panel_x >= candle_right + edge_spacing` |
| R-4 | Unused `show_price_scale` variable | P3 | DEFERRED | No functional impact; kept for future price-scale-aware width |
| R-5 | Runtime reachability unconfirmed | — | PENDING | Requires live/visual test authorization |

---

## 6. Rollback Plan

If any regression is discovered during authorized validation:

1. **Git revert:** `git revert <commit-hash>` (preserves history)
2. **Baseline EX5:** `E9CB78174A88AB112E7CAD5FC23D9662C7BBD83794E6A36A77A8CBD91446D333` (pre-mission)
3. **Fallback behavior:** Hardcoded 30% width, original card order, original cleanup

---

## 7. Handoff Notes for Next Session

- **Branch:** `fix/root-cause-repair-dashboard-coordinator-snapshot-settings`  
- **HEAD:** `1e6ff88` (unchanged — commits require explicit authorization)  
- **EX5:** `670A5B86D165133AEAFA60F537A255425937F0502E688C14BDA5D5CBCF750DA8`  
- **Documentation:** `docs/DASHBOARD_RIGHT_GAP_ROOT_CAUSE_REPORT.md`, this file  
- **Key invariant:** Dashboard remains **observational only** — never submits trades, never bypasses risk gates

---

## 8. Sign-Off

**Engineering Lead:** Kilo (MT5 Engineer role)  
**Reviewers:** code-reviewer (P2 findings fixed), risk-auditor (P2/P3 findings fixed)  
**Validation:** Static only — runtime gates pending authorization  
**Decision:** Ready for authorized runtime validation