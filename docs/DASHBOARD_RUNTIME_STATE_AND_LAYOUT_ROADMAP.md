# Dashboard Runtime State & Layout Remediation Roadmap

**Date**: 2026-11-21
**Mission**: Fix Dashboard visual/layout issues and External Risk Lock read integrity
**Status**: COMPLETE — All confirmed repairs implemented and verified

---

## Completed Workstreams

### ✅ Workstream 1: Increase Dashboard Width Correctly
**Root Cause**: `CalculateRequiredPanelWidth()` measured only atomic content, omitting long wrapped text
**Fix Applied**:
- Added `MeasureWrappedLines()` helper (lines 951-959)
- Modified `CalculateRequiredPanelWidth()` to binary-search for width keeping SYSTEM_STATUS long text ≤3 lines (lines 1023-1066)
- Bounded by theme-derived `min_card_width` (base*15) and `max_card_width` (base*35)
- No hardcoded multipliers; content-driven preferred width

**Verification**: Compile PASSED, ValidationHarness PASSED

### ✅ Workstream 2: Status Text & Card Height
**Root Cause**: Horizontal card boundary crossed wrapped Status text
**Fix Applied**:
- Verified single source of truth: `MeasureCardHeight()` uses `WrapText()` with same `content_width` as `RenderCard()`
- `LayoutCards()` stores `geom.content_width` used by both measurement and render
- Geometry-priority consistency verified: `LayoutCards()` writes by index, `Render()` reads by priority-sorted index

**Verification**: Code review confirmed no mismatch

### ✅ Workstream 3: System Lifecycle State Synchronization
**Root Cause**: Dashboard showed INITIALIZING after SYSTEM_READY
**Fix Applied**:
- Added `SetEAInitialized()` method (line 870-878)
- Called at `InitializeSystemWhenReady()` after `g_system_ready=true` (line 4194)
- Modified `GetSystemStatusBadge()` to gate INITIALIZING on `ea_initialized` only
- Exact-match ORPHANED (removed substring false-positive)

**Verification**: State transition trace documented; risk audit confirmed no gate bypass

### ✅ Workstream 4: Primary Strategy & Render Order
**Status**: VERIFIED — No changes needed
- All 5 primary fields (STYLE, REGIME, BIAS, LONG, SHORT) always rendered (priority 2-6)
- Primary strategy grid adapts to panel width via `CalculateStrategyGrid()`
- Geometry-priority mapping verified correct

### ✅ Workstream 5: Array Bounds (Finding 1)
**Status**: VERIFIED SAFE — No changes needed
- `ArrayResize(words, 1024)` + `word_count < 1024` allows indices 0-1023 (1024 words)
- `word_widths[1024]` fixed buffer matches
- `MAX_WRAP_LINES=80` stack buffer guarded at every write
- Code review P3 (unused `snapshot_valid`) FIXED

### ✅ Workstream 6: LayoutCards Geometry Ordering
**Status**: VERIFIED — No mismatch found
- `LayoutCards()` writes `m_card_geom[idx]` using original card indices
- `Render()` sorts `render_order[]` by priority, uses `m_card_geom[idx]`
- Single source of truth confirmed

### ✅ Workstream 7: Retry UI Throttling
**Status**: VERIFIED — Finding incorrect
- `SetRetryUIState()` sets `m_dirty=true`
- `Render()` bypasses throttle when `m_dirty || m_force_render`
- Interactive UI changes render immediately

### ✅ Workstream 8: MeasureText Performance
**Status**: NO ACTION — No evidence of material degradation
- `TextGetSize()` calls bounded by card count and text length
- Caching would add complexity without demonstrated need

### ✅ Workstream 9: Strategy Grid Height
**Status**: VERIFIED — Adaptive grid handles variable heights
- `CalculateStrategyGrid()` measures each card at column width
- Uses `max_card_h` for row height
- Space-exhaustion hides only lower-priority cards

### ✅ Workstream 10: External Risk Lock GV Reads
**Root Cause**: Boolean `GlobalVariableGet` overload not used
**Fix Applied**:
- Rewrote `ReadExtRiskLockState()` to use `bool GlobalVariableGet(name, &value)` for all 6 fields
- Any read failure → `valid=false, read_complete=false` (fail-closed)
- Propagated through `ToPortfolioRiskLockState()` → `CheckExternalRiskLock()`

**Verification**: Risk audit confirmed fail-closed chain intact

### ✅ Workstream 11: Defaults
**Status**: PRESERVED
- `InpDashboardViewMode = DASHBOARD_NORMAL` (1)
- `InpDashboardDiagnostics = false`
- Both in source defaults and standard SET file

---

## Validation Results

| Check | Result |
|-------|--------|
| Compile (MetaEditor 6230) | 0 Errors, 0 Warnings ✅ |
| ValidationHarness | 6 PASSED, 0 FAILED, 2 Pre-existing WARNING ✅ |
| Critical Invariants | 22/22 PASSED ✅ |
| Code Review (code-reviewer) | 1 P3 (unused var) — FIXED ✅ |
| Risk Audit (risk-auditor) | 3 P3 (dashboard display) — ALL FIXED ✅ |

---

## Remaining Pre-existing Limitations

| Item | Status | Requires |
|------|--------|----------|
| Standard Library consistency (STD-001) | WARNING | Architectural decision |
| Terminal origin.txt mismatch (ORG-001) | WARNING | Terminal re-registration |
| Strategy Tester / Visual Tester / Optimization | NOT RUN | Explicit user authorization |
| Live Broker Mutation | NOT PERFORMED | Explicit user authorization |
| Persistent Ledger / Authority Mutation | NOT PERFORMED | Explicit user authorization |
| Git Commit / Push / PR | NOT PERFORMED | Explicit user authorization |

---

## Next Steps (If Authorized)

1. **Strategy Tester Validation** — Run backtests with visual verification of Dashboard layout across timeframes/symbols
2. **Standard Library Resolution** — Decide: remove project StdLib copies, or align with install
3. **Terminal Origin Fix** — Re-register terminal data folder to match `C:\Program Files\AMarkets - MetaTrader 5`
4. **Git Delivery** — Commit changes to dedicated branch, open PR with review

---

## Files Modified

| File | Key Changes |
|------|-------------|
| `Include/AlgoSystem/HybridDashboard.mqh` | `GetSystemStatusBadge()`, `SetEAInitialized()`, `MeasureWrappedLines()`, `CalculateRequiredPanelWidth()` |
| `Experts/AlgoMultiAssetEA.mq5` | `ReadExtRiskLockState()` (boolean GVGet), `RefreshTradingState()` (ERL dashboard update), `InitializeSystemWhenReady()` (SetEAInitialized call) |

---

## Explicit Exclusions

- `STRATEGY TESTER / VISUAL TESTER / OPTIMIZATION: NOT RUN — EXPLICIT USER EXCLUSION`
- `LIVE BROKER MUTATION: NOT PERFORMED`
- `PERSISTENT LEDGER / AUTHORITY MUTATION: NOT PERFORMED`
- `GIT COMMIT / PUSH / PR: NOT PERFORMED`