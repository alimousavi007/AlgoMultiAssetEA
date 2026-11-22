# AlgoMultiAssetEA — Adaptive Card-Based Dashboard Remediation Roadmap

**Mission:** Full implementation of Adaptive Card-Based Dashboard replacing the three-column table layout  
**Branch:** `fix/root-cause-repair-dashboard-coordinator-snapshot-settings`  
**HEAD:** `1e6ff88`  
**Date:** 2026-11-20  
**Status:** **IN PROGRESS** — Roadmap created, implementation starting

---

## Executive Summary

The current Dashboard uses a three-column table layout (Section | Label | Value) implemented in `HybridDashboard.mqh`. The new design requires an **Adaptive Card-Based Dashboard** with:

1. **Header**: Product identity, Symbol, Timeframe (each once)
2. **System Status Card**: Prominent card with state badge, full reason, action
3. **Strategy Overview Cards**: STYLE, REGIME, BIAS, LONG, SHORT, STAGE — always visible
4. **Diagnostics Section**: Separate lower section, smaller typography, toggleable
5. **Retry/Review Card**: Integrated into same layout engine, conditional

All sizing/positioning must be **content- and geometry-driven** using `TextGetSize`/`MeasureText`.

---

## Current State Analysis (From Previous Investigation)

### Existing Assets (Reusable)
| Asset | Location | Status |
|-------|----------|--------|
| `DashboardState` model with `DashboardFieldState` | `HybridDashboard.mqh` lines 23-81 | ✅ VERIFIED — Full traceability |
| `MeasureText()` / `WrapText()` helpers | `HybridDashboard.mqh` lines 227-314 | ✅ VERIFIED — MQL5 OBJPROP_WIDTH |
| `RecalculateDashboardLayout()` responsive | `HybridDashboard.mqh` lines 389-430 | ✅ VERIFIED — Percentage-based panel |
| `HandleChartGeometryChange()` | `HybridDashboard.mqh` lines 513-533 | ✅ VERIFIED — Resize handling |
| Retry UI integrated in layout | `HybridDashboard.mqh` lines 52-80, 770-820 | ✅ VERIFIED — Dynamic buttons |
| 9 System Health setters | `HybridDashboard.mqh` lines 544-606 | ✅ VERIFIED — Full source/validity |
| Strategy Snapshot setter | `HybridDashboard.mqh` lines 175-190 | ✅ VERIFIED — GV snapshot path |

### Current Layout (To Replace)
- **Three-column table**: Section | Label | Value
- **Fixed row-based**: `visible_rows` = 4/6/14 per ViewMode
- **Column widths**: 30%/30%/40% of panel
- **Row height**: Fixed 13px

### Data Sources (Verified)
| Field | Source | Path |
|-------|--------|------|
| COORDINATOR | `g_coordinator_mode` + Authority | `UpdateDashboardForChart()` → `SetCoordinatorState()` |
| AUTHORITY | `CExecutionLedger` epoch/token | `ValidateAuthority()` → `SetAuthorityState()` |
| LEDGER | `CExecutionLedger` schema/state | `OnInit` → `SetLedgerState()` |
| CHART REG | Chart registration logic | `RegisterChart()` → `SetChartRegistrationState()` |
| SNAPSHOT | `GVSnapshotData` double-buffer | `ApplySnapshotToDashboard()` → `SetRuntimeSnapshot()` |
| BLOCKING | Risk/News/Coordinator gates | `CanAdmit()` → `SetBlockingSubsystem()` |
| FAIL REASON | Last rejection code/reason | `Execute()` → `SetFailureReason()` |
| LAST OK STAGE | Pipeline execution | `SetLastSuccessfulStage()` |
| ACTION REQUIRED | User-actionable state | `RetryUI`/`SafeMode` → `SetActionRequired()` |
| STYLE/REGIME/BIAS/LONG/SHORT/STAGE/REASON | `GVSnapshotData` | `ApplySnapshotToDashboard()` → `SetRuntimeSnapshot()` |

---

## New Card-Based Design Specification

### 1. Header Card
```
┌─────────────────────────────────────────────────────────┐
│  ALGO HYBRID [SAFE MODE]                                │
│  EURUSD  H1                                              │
│  Strategy: TREND_PULLBACK (optional)                    │
└─────────────────────────────────────────────────────────┘
```
- Compact, full-width
- Symbol + Timeframe ONCE
- Optional strategy identity only if useful/available

### 2. System Status Card (Prominent)
```
┌─────────────────────────────────────────────────────────┐
│  ⚠ SYSTEM STATUS: BLOCKED                               │
│  Coordinator: UNAVAILABLE                               │
│  Authority: ORPHANED                                    │
│  Strategy: BLOCKED                                      │
│  Reason: AUTHORITY_ORPHANED                             │
│  Action: Explicit recovery required                     │
└─────────────────────────────────────────────────────────┘
```
- State badge (READY/INITIALIZING/WAITING/BLOCKED/UNAVAILABLE/ERROR/ORPHANED)
- Full failure reason (no truncation)
- Action only when supported by architecture

### 3. Strategy Overview Cards (Always Visible)
```
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   STYLE     │ │  REGIME     │ │    BIAS     │
│ DAY_TRADING │ │  TRENDING   │ │  BULLISH    │
└─────────────┘ └─────────────┘ └─────────────┘

┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   STAGE     │ │    LONG     │ │   SHORT     │
│  EVALUATED  │ │ CANDIDATE   │ │   NO TRADE  │
└─────────────┘ └─────────────┘ └─────────────┘
```
- Adaptive grid: 2 or 3 columns based on available width
- Each card: Label + Value
- Color-coded values (GREEN/RED/AMBER/GREY)
- NEVER hidden by Diagnostics toggle

### 4. Diagnostics Section (Toggleable, Below Primary)
```
┌─────────────────────────────────────────────────────────┐
│  DIAGNOSTICS (smaller font)                             │
│  ─────────────────────────────────────────────────────  │
│  Coordinator: CONNECTED (Lease: 30s)        ● GREEN     │
│  Authority: VALID (Epoch: 5)                ● GREEN     │
│  Ledger: VALID (DB: available)              ● GREEN     │
│  Chart Registration: REGISTERED             ● GREEN     │
│  Snapshot: VALID (Gen: 42, 5s ago)          ● GREEN     │
│  Blocking Subsystem: NONE                   ● GREY      │
│  Last Successful Stage: EVALUATED           ● SILVER    │
│  Action Required: (none)                    ● GREY      │
│  Reason: NO_NEW_CLOSED_BAR                  ● SILVER    │
└─────────────────────────────────────────────────────────┘
```
- Smaller typography than primary cards
- Only visible when `InpDashboardDiagnostics=true`
- Hides ONLY diagnostic details when OFF
- Primary cards (STYLE/REGIME/BIAS/LONG/SHORT/STAGE) ALWAYS visible

### 5. Retry/Review Card (Conditional)
```
┌─────────────────────────────────────────────────────────┐
│  RETRY/REVIEW: REVIEW_READY                             │
│  Candidate: EURUSD dir=1 claim=CLM_abc prior=ATT_xyz   │
│  Seq: 2 class=FINAL_FAILURE ret=10009 ord=12345        │
│  Deal: 67890 Pos: 11111 Ev: EXECUTION_TIMEOUT          │
│  ─────────────────────────────────────────────────────  │
│  [Inspect] [Review] [Next] [Confirm] [Cancel]          │
└─────────────────────────────────────────────────────────┘
```
- Only visible when `RetryUIState.ui_state != 0` (active)
- Integrated in same layout engine
- Dynamic button widths from caption metrics
- No execution authority implied

---

## Implementation Roadmap

### Unit C1: Card ViewModel & Content Model
**Objective:** Define card-based data structures replacing row-based model

**Files:** `HybridDashboard.mqh`

**Design:**
```cpp
// Card types
enum ENUM_CARD_TYPE {
    CARD_HEADER = 0,
    CARD_SYSTEM_STATUS = 1,
    CARD_STRATEGY_OVERVIEW = 2,
    CARD_DIAGNOSTICS = 3,
    CARD_RETRY_REVIEW = 4
};

// Card content - self-contained
struct CardContent {
    ENUM_CARD_TYPE type;
    string title;                    // Card header
    string subtitle;                 // Optional subtitle
    string fields[];                 // Key-value pairs for overview cards
    string field_labels[];           // Labels for key-value pairs
    string field_colors[];           // Colors for values
    string status_badge;             // For System Status card
    string status_color;             // Badge color
    string full_reason;              // Full reason text (no truncation)
    string action_text;              // Action required
    bool visible;                    // Runtime visibility
    int priority;                    // Layout priority
};

// Layout-calculated geometry
struct CardGeometry {
    int x, y;                        // Top-left position
    int width, height;               // Calculated dimensions
    int content_width;               // Available for text
    int rows_needed;                 // Based on wrapped content
};
```

**Acceptance:**
- All DashboardState fields mapped to CardContent
- No data loss from current model
- CardContent serializable for debugging

---

### Unit C2: Adaptive Layout Engine
**Objective:** Calculate card positions/sizes from actual chart geometry and content

**Files:** `HybridDashboard.mqh`

**Algorithm:**
```
1. Get chart dimensions (CHART_WIDTH_IN_PIXELS, CHART_HEIGHT_IN_PIXELS)
2. Calculate panel width: % of chart width per ViewMode (20/30/38%)
3. Measure Header card height (title + symbol/tf + optional strategy)
4. Measure System Status card height (badge + 4-5 lines wrapped)
5. Measure Strategy Overview cards:
   - Determine columns: 1, 2, or 3 based on panel_width / min_card_width
   - Measure each card (label + wrapped value)
   - Arrange in grid
6. If Diagnostics ON: measure Diagnostics section below
7. If Retry active: measure Retry card below
8. Calculate total height, clamp to chart bounds
9. Position cards top-to-bottom with spacing
```

**Key Functions:**
- `MeasureCardContent()` — uses `MeasureText`/`WrapText` for exact bounds
- `CalculateCardGrid()` — determines columns/rows for Strategy cards
- `LayoutCards()` — positions all cards, returns total height

**Acceptance:**
- No hardcoded positions/sizes
- Adapts to 320×240 through 1920×1080
- One/two/three column Strategy grid auto-selected
- Long text wraps, grows card height
- Panel never exceeds chart bounds

---

### Unit C3: Card Renderer & Chart Object Synchronizer
**Objective:** Single renderer creating/updating chart objects for all cards

**Files:** `HybridDashboard.mqh`

**Object Naming:**
```
AlgoHybridDashboard_BG_<chart_id>          // Background panel
AlgoHybridDashboard_CARD_<type>_<index>_BG // Card backgrounds
AlgoHybridDashboard_CARD_<type>_<index>_LBL_<n> // Card labels
AlgoHybridDashboard_CARD_RETRY_BTN_<n>     // Retry buttons
```

**Rendering Pipeline:**
```
Render()
  → RecalculateDashboardLayout() (if geometry changed)
  → LayoutCards() (calculate all CardGeometry)
  → CreateOrUpdateCardObjects() (backgrounds + labels)
  → UpdateCardContent() (set text, colors, positions)
  → HideUnusedObjects()
  → ChartRedraw()
```

**Card Backgrounds:** `OBJ_RECTANGLE_LABEL` with subtle borders
**Card Labels:** `OBJ_LABEL` with measured positions
**Buttons:** `OBJ_BUTTON` with dynamic widths

**Acceptance:**
- Single `Render()` entry point
- All objects managed (create/update/delete)
- No stale objects on ViewMode/Diagnostics/Resize changes
- Throttled rendering (500ms interval, force for critical)
- Object cleanup on `Clear()` and deinit

---

### Unit C4: Typography & Theme System
**Objective:** Centralized design tokens, readability constraints

**Files:** `HybridDashboard.mqh`

**Design Tokens:**
```cpp
struct DashboardTheme {
    // Fonts
    string font_family = "Consolas";
    int font_size_primary = 9;      // Strategy cards
    int font_size_header = 9;       // Header
    int font_size_status = 9;       // System Status
    int font_size_diagnostics = 7;  // Diagnostics (smaller)
    int font_size_retry = 8;        // Retry card
    
    // Colors
    color bg_panel = clrWhite;
    color bg_card = clrWhite;
    color border_card = clrSilver;
    color text_primary = clrBlack;
    color text_secondary = clrDimGray;
    color text_muted = clrGray;
    color status_ready = clrDarkGreen;
    color status_waiting = clrDarkOrange;
    color status_blocked = clrDarkRed;
    color status_error = clrMaroon;
    color status_unavailable = clrDimGray;
    color diag_valid = clrDarkGreen;
    color diag_invalid = clrDarkRed;
    color diag_unknown = clrDimGray;
    color btn_primary = clrSteelBlue;
    color btn_confirm = clrDarkGreen;
    color btn_cancel = clrMaroon;
    color btn_disabled = clrDimGray;
    
    // Spacing
    int panel_margin = 16;
    int card_spacing = 8;
    int card_padding = 10;
    int card_border_radius = 0; // MQL5 rect labels don't support radius
    int min_card_width = 120;
    int max_card_width = 400;
};
```

**Readability Constraints:**
- Primary content: ≥ 9px, high contrast
- Diagnostics: ≥ 7px, readable contrast
- Minimum card width: 120px
- Maximum lines per card: 15 (then scroll/page if needed)

---

### Unit C5: Settings Integration & Diagnostics Toggle
**Objective:** Wire settings to card visibility, verify A/B behavior

**Files:** `HybridDashboard.mqh`, `AlgoMultiAssetEA.mq5`

**Settings Mapping:**
| Setting | Current | New Behavior |
|---------|---------|--------------|
| `InpDashboard` | Enable/disable | Master toggle |
| `InpDashboardViewMode` | Row limits | Panel width % (COMPACT=20%, NORMAL=30%, FULL=38%) |
| `InpDashboardDiagnostics` | Show/hide diag rows | Show/hide Diagnostics SECTION only |
| `InpDashboardSafeMode` | Safe mode badge | Header badge + mutation block |

**Test A (Config A):**
- `InpDashboard=true`, `ViewMode=FULL`, `Diagnostics=true`
- Expect: All cards visible, Diagnostics section expanded

**Test B (Config B):**
- `InpDashboard=true`, `ViewMode=NORMAL`, `Diagnostics=false`
- Expect: Header, System Status, Strategy cards — NO Diagnostics section

---

### Unit C6: Retry/Review Card Integration
**Objective:** Embed Retry UI in layout engine, dynamic buttons

**Files:** `HybridDashboard.mqh`

**State Mapping:**
```cpp
// RetryUIState already in DashboardState (lines 52-80)
// Add to layout when ui_state != 0
// Button captions: "Inspect", "Review", "Next", "Confirm", "Cancel"
// Width = MeasureText(caption) + 16px padding
// Disabled buttons: grey, no click handler
```

**Layout Position:** Below Diagnostics (or below Strategy cards if Diagnostics OFF)

---

### Unit C7: Hardcode Audit & Object Lifecycle
**Objective:** Eliminate remaining hardcodes, verify object cleanup

**Audit List:**
| Value | Location | Status |
|-------|----------|--------|
| Panel margin (16px) | Layout | ✅ Design constraint |
| Card spacing (8px) | Layout | ✅ Design constraint |
| Card padding (10px) | Layout | ✅ Design constraint |
| Min card width (120px) | Layout | ✅ Readability constraint |
| Font sizes (7/8/9) | Theme | ✅ ViewMode-aware |
| Panel width % (20/30/38) | Layout | ✅ ViewMode-aware |
| Row height (13) | REMOVED | → Card height from content |
| Visible rows (4/6/14) | REMOVED | → Content-driven |
| Column widths (30/30/40) | REMOVED | → Card grid auto |

**Object Lifecycle:**
- `CreateOrUpdateCardObjects()` — creates if missing, updates if exists
- `HideUnusedObjects()` — sets `OBJPROP_TIMEFRAMES=OBJ_NO_PERIODS`
- `Clear()` — deletes all by prefix
- `OnDeinit()` — calls `Clear()`

---

## Dependencies & Order

```
C1 (Card ViewModel) 
    → C2 (Layout Engine uses CardContent)
        → C3 (Renderer uses CardGeometry)
            → C4 (Theme used by Renderer)
                → C5 (Settings wire to ViewModel)
                    → C6 (Retry card uses Layout+Renderer)
                        → C7 (Audit validates all)
```

---

## Acceptance Criteria Summary

### Design
- [ ] Three-column table removed
- [ ] Card-based adaptive UI implemented
- [ ] Clear visual hierarchy (Header → Status → Strategy → Diagnostics → Retry)
- [ ] Header compact, Symbol/TF once
- [ ] System Status prominent with badge
- [ ] Strategy cards adaptive grid
- [ ] Diagnostics separate lower section
- [ ] Retry integrated in layout

### Primary Information
- [ ] STYLE always visible (Dashboard enabled)
- [ ] REGIME always visible
- [ ] BIAS always visible
- [ ] LONG always visible
- [ ] SHORT always visible
- [ ] STAGE displayed when valid
- [ ] Diagnostics ON adds below, doesn't hide primary
- [ ] Diagnostics OFF hides only diagnostic section

### Diagnostics Correctness
- [ ] Coordinator state accurate (from DashboardState)
- [ ] Authority state accurate (ORPHANED distinct)
- [ ] Ledger independently sourced
- [ ] Registration independently sourced
- [ ] Snapshot state/freshness accurate
- [ ] No Status/Diagnostics contradiction
- [ ] NOT EVALUATED ≠ BLOCKED ≠ UNAVAILABLE ≠ ERROR
- [ ] Full failure reasons accessible (no truncation)

### Responsive UI
- [ ] Dynamic card width from content
- [ ] Dynamic card height from wrapped text
- [ ] Dynamic positioning (top-to-bottom flow)
- [ ] Adaptive 1/2/3 column Strategy grid
- [ ] Typography within readability constraints
- [ ] Complete text wrapping (no clipping)
- [ ] No overlapping cards/buttons
- [ ] No stale objects
- [ ] Chart resize handled
- [ ] Reinitialization handled
- [ ] Long diagnostics accessible

### Settings
- [ ] Diagnostics ON behavior verified (Config A)
- [ ] Diagnostics OFF behavior verified (Config B)
- [ ] COMPACT/NORMAL/FULL verified
- [ ] Settings traced to consumers
- [ ] No unexpected default overrides
- [ ] SET keys valid
- [ ] No unrelated strategy/risk settings modified

### Safety & Architecture
- [ ] Single Coordinator preserved
- [ ] No automatic takeover
- [ ] ORPHANED blocks
- [ ] Epoch/fencing preserved
- [ ] Owner validation preserved
- [ ] No retry authorization regression
- [ ] No broker mutation
- [ ] No persistent production state mutation

### Quality
- [ ] Existing user modifications preserved
- [ ] All applicable TODO items complete
- [ ] Relevant tests pass
- [ ] Compile 0 errors
- [ ] 0 unexplained warnings
- [ ] Correct source/build provenance
- [ ] EX5 timestamp and SHA256 recorded
- [ ] Code review completed
- [ ] Risk review completed
- [ ] Git delivery not performed

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|------------|
| Layout engine complexity | MEDIUM | Reuse existing MeasureText/WrapText, test incrementally |
| Card object management | MEDIUM | Single CreateOrUpdate pattern, indexed cleanup |
| ViewMode transitions | LOW | Dirty flag forces full relayout |
| Diagnostics toggle | LOW | Boolean flag, simple conditional render |
| Retry UI integration | LOW | Already in DashboardState, just layout position |
| Text measurement performance | LOW | Cached word widths, throttled render (500ms) |
| MQL5 OBJPROP_WIDTH reliability | LOW | Verified working pattern in current code |

---

## Evidence Requirements

Each unit must produce:
1. **Code changes** with exact file/line references
2. **Compile log** — 0 errors, 0 warnings
3. **Test results** — ValidationHarness 88/88 PASS
4. **Visual verification** — Static analysis of layout calculations
5. **Regression check** — All 16 previous findings remain FIXED

---

## Timeline

**Single Mission:** All units implemented, tested, reviewed, reported

---

## Final Deliverables

1. `docs/DASHBOARD_CARD_BASED_ROADMAP.md` — This file
2. `docs/DASHBOARD_CARD_BASED_ROOT_CAUSE_REPORT.md` — Post-implementation
3. Updated `docs/SETTINGS_TRACEABILITY_MATRIX.md` — If settings change
4. Modified `Include/AlgoSystem/HybridDashboard.mqh` — Complete rewrite
5. Modified `Experts/AlgoMultiAssetEA.mq5` — Settings wiring
6. Final Persian report

---

**Status:** Ready for implementation — Starting Unit C1