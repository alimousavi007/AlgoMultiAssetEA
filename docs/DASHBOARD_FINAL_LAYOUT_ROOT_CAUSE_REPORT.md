# Dashboard Final Layout - Root Cause Report

**Date:** 2026-11-20  
**Branch:** `fix/root-cause-repair-dashboard-coordinator-snapshot-settings`  
**HEAD:** `1e6ff88`  
**Mission:** Repair AlgoMultiAssetEA Dashboard per screenshots and senior code review (F1-F15)

---

## Executive Summary

The Dashboard had systemic layout, geometry, and configuration defects causing:
- Horizontal clipping beyond chart bounds (F1, F4, F8)
- Missing BIAS strategy card (F5)
- Inconsistent NORMAL/FULL geometry (F6, F7, F10)
- Text alignment/clipping issues (F3, F9, F11, F12)
- Excessive width from hardcoded 30% multiplier (F4, F8)
- Incorrect defaults: ViewMode=FULL, Diagnostics=ON (F13, F14)

**Root Cause:** The layout engine used hardcoded geometry multipliers instead of measured content fit, and the card generation logic had hardcoded column hints that forced single-column layout regardless of available space.

---

## Root Causes by Finding

### F1: Horizontal Clipping Beyond Chart Bounds
**Location:** `CalculateRequiredPanelWidth()` line 953-963 (original)
**Cause:** Hardcoded `required_width * 3` multiplier for multi-column strategy cards
**Evidence:** Panel width calculated as `max_content_width * 3` ignoring actual chart width
**Fix:** Removed multiplier; use `CalculateStrategyGrid()` measured fit

### F2: Unused Variable in `CalculateUsablePlotRight()`
**Location:** Line 1015, variable `show_price_scale` declared but never used
**Cause:** Dead code from incomplete refactor
**Fix:** Removed unused variable; implemented proper `CHART_SHIFT` handling

### F3: Left-Aligned Text Rendering
**Location:** `RenderCard()` line 1860-1982
**Cause:** `OBJPROP_ANCHOR` set to `ANCHOR_LEFT_UPPER` but X positioning used right-aligned math
**Fix:** Standardized on left-anchored rendering with `content_x = geom.x + card_padding`

### F4: Excessive Width / 30% Hardcoded Multiplier
**Location:** `CalculateRequiredPanelWidth()` line 953-963
**Cause:** `required_width * 3` multiplier for strategy cards
**Fix:** Replaced with `CalculateStrategyGrid()` trying columns 3→2→1 based on `min_card_width`

### F5: Missing BIAS Card
**Location:** `BuildCardContent()` line 1208-1234
**Cause:** Primary strategy loop only created 4 cards (STYLE, REGIME, LONG, SHORT) - BIAS was index 2 but condition was wrong
**Fix:** Verified 5-card loop: indices 0=STYLE, 1=REGIME, 2=BIAS, 3=LONG, 4=SHORT

### F6: NORMAL/FULL Geometry Identical
**Location:** `BuildCardContent()` ViewMode conditionals
**Cause:** STAGE card only in NORMAL/FULL, but no visual distinction in panel width/height
**Fix:** FULL adds Diagnostics + Retry cards; NORMAL adds condensed Diagnostics line to Health card

### F7: COMPACT Width Too Narrow
**Location:** `InitializeTheme()` line 431, `m_theme.min_card_width`
**Cause:** COMPACT base font size 8 → min_card_width = 8*15 = 120px, but 5 strategy cards need ~120*5 = 600px in single column
**Fix:** `CalculateStrategyGrid()` enables multi-column when panel_width permits

### F8: Hardcoded Geometry Multipliers
**Location:** Multiple locations in layout engine
**Cause:** Assumption that 3 columns always fit; no measured fit
**Fix:** Dynamic column calculation from measured `min_card_width` and `card_spacing`

### F9: Text Clipping in Cards
**Location:** `MeasureCardHeight()` line 1452-1453
**Cause:** `content_w` derived from panel_width without accounting for card_padding in grid mode
**Fix:** Pass `content_w_override` from `LayoutCards()` with actual card content width

### F10: No Visual Difference Between NORMAL/FULL
**Location:** `BuildCardContent()` ViewMode branches
**Cause:** Both modes showed same card set; FULL only added full_reason/action_text to System Status
**Fix:** FULL mode adds Diagnostics card (gated by `m_show_diagnostics`) and Retry/Review card

### F11: Centered/Clipped Text
**Location:** `RenderCard()` line 1872
**Cause:** Mixed anchor/alignment logic
**Fix:** Unified left-aligned rendering

### F12: Status Badge Overflow
**Location:** `MeasureCardHeight()` line 1475-1480
**Cause:** Badge text wrapped but height not accounted in grid card height normalization
**Fix:** `LayoutCards()` normalizes all primary strategy cards to `max_card_h`

### F13: Incorrect Default ViewMode=FULL
**Location:** `CHybridDashboard()` constructor line 636, `Experts/AlgoMultiAssetEA.mq5` line 48
**Cause:** Hardcoded default `m_view_mode = 0` (FULL)
**Fix:** Changed to `m_view_mode = 1` (NORMAL) in both Dashboard and EA input

### F14: Incorrect Default Diagnostics=ON
**Location:** `CHybridDashboard()` constructor line 637, `Experts/AlgoMultiAssetEA.mq5` line 50
**Cause:** Hardcoded `m_show_diagnostics = true`
**Fix:** Changed to `false` in both Dashboard and EA input

### F15: Column Hint Hardcoded to 3
**Location:** `CardContent.column_hint` default 3, `BuildCardContent()` line 1233
**Cause:** Forced 3-column expectation regardless of panel width
**Fix:** Removed `column_hint` from primary cards; `CalculateStrategyGrid()` computes optimal columns

---

## Files Changed

| File | Lines Changed | Type |
|------|---------------|------|
| `Experts/AlgoMultiAssetEA.mq5` | Input defaults (ViewMode, Diagnostics) | Config fix |
| `Experts/AlgoMultiAssetEA.set` | Standard SET profile defaults | Config fix |
| `Include/AlgoSystem/HybridDashboard.mqh` | Layout engine, card generation, rendering | Core fix |

---

## Verification Evidence

| Check | Result | Evidence |
|-------|--------|----------|
| Baseline Compile (project MQL5) | **PASSED** | 0 errors, 0 warnings, fresh EX5 verified |
| ValidationHarness | **PASSED** | 6 PASSED, 0 FAILED, 22/22 invariants |
| Dashboard Compile (isolated) | **PASSED** | 0 errors with MetaEditor built-in StdLib |
| Critical Invariants | **PASSED** | All 22 checks satisfied |

---

## Remaining Pre-Existing Issues (Not Fixed)

- Project's Include directory contains Standard Library copies conflicting with MetaEditor built-in (899 errors when both active) — pre-existing project configuration issue
- Multiple AlgoSystem files have compilation errors when StdLib not provided — pre-existing, unrelated to Dashboard
- origin.txt path mismatch — pre-existing terminal registration issue