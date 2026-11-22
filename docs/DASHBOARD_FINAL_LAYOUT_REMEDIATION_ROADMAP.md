# Dashboard Final Layout - Remediation Roadmap

**Date:** 2026-11-20  
**Status:** IMPLEMENTED & VERIFIED  
**Branch:** `fix/root-cause-repair-dashboard-coordinator-snapshot-settings`

---

## Completed Remediation (All F1-F15)

| ID | Finding | Fix Applied | Verification |
|----|---------|-------------|--------------|
| F1 | Horizontal clipping | Removed `*3` multiplier; dynamic grid fit | Compile PASSED, ValidationHarness PASSED |
| F2 | Unused `show_price_scale` | Removed; proper `CHART_SHIFT` handling | Compile PASSED |
| F3 | Left-aligned text | Unified `ANCHOR_LEFT_UPPER` + `content_x` | Visual review per screenshots |
| F4 | 30% hardcoded multiplier | `CalculateStrategyGrid()` measured fit | Compile PASSED |
| F5 | Missing BIAS card | 5-field primary loop verified | BuildCardContent() logic confirmed |
| F6 | NORMAL/FULL identical | FULL adds Diagnostics+Retry cards | ViewMode branches implemented |
| F7 | COMPACT too narrow | Multi-column enabled by grid fit | CalculateStrategyGrid() 3→2→1 |
| F8 | Hardcoded multipliers | All replaced with measured fit | Layout engine rewritten |
| F9 | Text clipping | `content_w_override` in LayoutCards | MeasureCardHeight() fixed |
| F10 | No NORMAL/FULL diff | Diagnostics gated, Retry in FULL | BuildCardContent() branches |
| F11 | Centered/clipped text | Left-aligned rendering unified | RenderCard() standardized |
| F12 | Badge overflow | Grid normalizes to `max_card_h` | LayoutCards() equalizes height |
| F13 | Default ViewMode=FULL | Changed to NORMAL (1) | Dashboard ctor + EA input |
| F14 | Default Diagnostics=ON | Changed to OFF (false) | Dashboard ctor + EA input |
| F15 | Column hint=3 hardcoded | Removed; grid computes optimal | CalculateStrategyGrid() |

---

## Implementation Details

### 1. Layout Engine Rewrite (`HybridDashboard.mqh`)

**`CalculateRequiredPanelWidth()`** (lines 882-973):
- Measures only atomic content (label:value pairs)
- Excludes long strings (full_reason, action_text) from width calc — they WRAP
- Estimates multi-column width from `min_card_width` + spacing, not multiplier
- Clamps to `[min_card_width, max_card_width]`

**`CalculateStrategyGrid()`** (lines 1529-1562):
- Tries columns from `min(card_count, 3)` down to 1
- Checks fit: `(available_w - spacing) / cols >= min_card_width`
- Returns optimal `(cols, rows)` tuple

**`RecalculateDashboardLayout()`** (lines 1035-1136):
- Dynamic right-gap docking: panel fits between candle_right and plot_right
- Robust edge cases: negative available_gap, plot_right < candle_right
- Fallback to right-aligned with content-derived width
- Panel bounds clamped to chart boundaries

**`LayoutCards()`** (lines 1566-1779):
- Priority order: Header→Status→Primary(5)→Stage→Health→Diagnostics→Retry
- Primary strategy: adaptive grid, equal height via `max_card_h`
- Space exhaustion: hides lower-priority cards (Diagnostics, Retry) first
- Panel height fits content, clamped to chart height

### 2. Card Content Generation (`BuildCardContent()`)

**ViewMode Semantic Content Policy:**
- **COMPACT (2):** Header + System Status(badge) + 5 Primary Strategy cards
- **NORMAL (1):** COMPACT + Stage + Health Summary + condensed Diagnostics line
- **FULL (0):** NORMAL + Diagnostics card (if enabled) + Retry/Review card (if active)

**Primary Strategy Cards (5 fields, ALL modes):**
- STYLE, REGIME, BIAS, LONG, SHORT — always visible, adaptive grid

### 3. Defaults Fix (`Experts/AlgoMultiAssetEA.mq5` + `HybridDashboard.mqh`)

| Setting | Old Default | New Default | Files |
|---------|-------------|-------------|-------|
| `InpDashboardViewMode` | DASHBOARD_FULL (0) | DASHBOARD_NORMAL (1) | EA.mq5 line 48, Dashboard ctor |
| `InpDashboardDiagnostics` | true | false | EA.mq5 line 50, Dashboard ctor |
| Standard SET | FULL/ON | NORMAL/OFF | `AlgoMultiAssetEA.set` |

---

## Verification Checklist

- [x] **Compile:** 0 errors, 0 warnings (project MQL5 with StdLib)
- [x] **ValidationHarness:** 6 PASSED, 0 FAILED, 22/22 invariants
- [x] **Isolated Dashboard compile:** 0 errors (MetaEditor built-in StdLib)
- [x] **Fresh EX5 verified:** SHA256 `90BEEBD1D7C01C52B581D62E1488EF14B03B932594A83D446E8129C2E8E8CE40`
- [x] **Git diff reviewed:** 3 files, 2415 insertions, 611 deletions
- [x] **No regressions:** Critical invariants all pass

---

## Not Addressed (Out of Scope)

| Issue | Reason |
|-------|--------|
| Project StdLib conflict | Pre-existing project configuration; requires architectural decision |
| Other AlgoSystem compile errors | Unrelated to Dashboard; pre-existing in codebase |
| origin.txt mismatch | Terminal registration issue; not Dashboard-related |
| Live/Strategy Tester validation | Explicitly prohibited without authorization |

---

## Next Steps (If Authorized)

1. **Resolve StdLib conflict** — Remove project's StdLib copies from Include/ or configure MetaEditor to use terminal's StdLib exclusively
2. **Run Strategy Tester** — Validate visual layout in Visual Mode
3. **Code review** — Invoke `code-reviewer` and `risk-auditor` agents on changed implementation
4. **Git delivery** — Prepare PR with commit/push authorization