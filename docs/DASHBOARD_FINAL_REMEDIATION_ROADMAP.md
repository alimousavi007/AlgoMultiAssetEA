# Dashboard Final Remediation Roadmap

**Mission**: Complete every unfinished Dashboard-related TODO and fix every confirmed defect from F1–F15 code review and independent review findings.

**Status**: ✅ **COMPLETE** — All authorized acceptance criteria verified

---

## Roadmap Overview

This roadmap tracks the remediation of all Dashboard-related findings from the F1–F15 code review and independent review (Must Fix 1–2, Should Fix 3–6, Nice-to-have).

---

## Phase 1: Critical Defects (F1–F15) — ✅ COMPLETE

| Task | Finding | Action Taken | Verification |
|------|---------|--------------|--------------|
| 1.1 | F1: Chart Identity | Verified correct — dashboard bound to EA chart via `m_chart_id = ChartID()` | Source trace |
| 1.2 | F2: Unused variable | Verified not present — no `show_price_scale` in source | Grep search |
| 1.3 | F3: Negative/zero available_gap | Enhanced `RecalculateDashboardLayout()` with comprehensive edge-case handling | Code review |
| 1.4 | F4: CHART_HEIGHT_IN_PIXELS | Verified correct semantics per MQL5 docs | Documentation check |
| 1.5 | F5: External Risk Lock | Verified complete fail-closed implementation in PortfolioRisk | Source trace |
| 1.6 | F6: ResetDiagnosticsFields order | Verified correct — guard before call | Source trace |
| 1.7 | F7: Chart-change cleanup | Verified correct — `ObjectsDeleteAll` on prefix change | Source trace |
| 1.8 | F8: Candle width geometry | Improved — measures actual width via bar 0/bar 1 coordinates | Code review |
| 1.9 | F9: Render ordering | Verified correct — single authoritative `Render()` with proper sequence | Source trace |
| 1.10 | F10: Retry UI throttling | Verified correct — all setters set `m_dirty = true` | Source trace |
| 1.11 | F11: CardContent copying | Accepted — necessary MQL5 limitation, shallow string copy | Code review |
| 1.12 | F12: Object tracking arrays | Verified adequate — 512 labels, 32 buttons, 32 card BGs | Capacity analysis |
| 1.13 | F13: WrapText whitespace | Improved — filters empties, preserves newlines, tabs→spaces | Code review |
| 1.14 | F14: Theme literals | Verified centralized — all tokens in `DashboardTheme` struct | Code review |
| 1.15 | F15: ExtRiskLockState copy | Verified complete — passed by const&, no copy function needed | Code review |

---

## Phase 2: Independent Review Must Fixes — ✅ COMPLETE

| Task | Finding | Action Taken | Verification |
|------|---------|--------------|--------------|
| 2.1 | Must Fix 1: Stage canonicalization | Fixed — unified `"NOT_EVALUATED"` → `"NOT EVALUATED"` in `SetRuntimeSnapshot()` and `BuildCardContent()` | Diff review |
| 2.2 | Must Fix 2: Diagnostics font minimum | Verified correct — clamp at 7 in `InitializeTheme()` | Code review |

---

## Phase 3: Independent Review Should Fixes — ✅ COMPLETE

| Task | Finding | Action Taken | Verification |
|------|---------|--------------|--------------|
| 3.1 | Should Fix 3: Max 3 columns | Verified not present — `CalculateStrategyGrid()` uses measured fit | Code review |
| 3.2 | Should Fix 4: Magic number 3 | Verified uses enum — `RETRY_UI_CONFIRM_READY = 2` | Code review |
| 3.3 | Should Fix 5: Grid/width consistency | Verified consistent — panel width from content, grid adapts to panel | Code review |
| 3.4 | Should Fix 6: NORMAL Diagnostics capacity | Verified adequate — 16-field array, dynamic iteration | Code review |

---

## Phase 4: Nice-to-Have Items — ✅ COMPLETE

| Task | Finding | Action Taken | Verification |
|------|---------|--------------|--------------|
| 4.1 | Remove dead `column_hint` | Verified not present in `CardContent` struct | Code review |
| 4.2 | Evaluate struct-copy | Accepted — MQL5 limitation, negligible impact | Code review |
| 4.3 | Simplify LayoutCards loops | Not needed — separate loops per group with distinct logic | Design review |
| 4.4 | Clarify enum mapping | Verified clear — explicit comment table in `DashboardViewModeToInternal()` | Code review |

---

## Phase 5: Settings & Defaults — ✅ COMPLETE

| Task | Setting | Expected | Actual | Status |
|------|---------|----------|--------|--------|
| 5.1 | `InpDashboardViewMode` | `DASHBOARD_NORMAL` (1) | Source line 48, SET line 11 | ✅ |
| 5.2 | `InpDashboardDiagnostics` | `false` | Source line 50, SET line 13 | ✅ |
| 5.3 | `InpDashboard` | `true` | Source line 49, SET line 12 | ✅ |
| 5.4 | `InpDashboardSafeMode` | `false` | Source line 132, SET (default) | ✅ |

---

## Phase 6: Verification & Validation — ✅ COMPLETE

| Task | Check | Result | Evidence |
|------|-------|--------|----------|
| 6.1 | Baseline compile | ✅ PASSED | 0 errors, 0 warnings |
| 6.2 | Post-fix compile | ✅ PASSED | 0 errors, 0 warnings |
| 6.3 | EX5 provenance | ✅ VERIFIED | Fresh EX5, SHA256 recorded |
| 6.4 | ValidationHarness | ✅ PASSED | 6/6 checks, 22/22 invariants |
| 6.5 | Critical invariants | ✅ ALL SATISFIED | INV-001 PASSED |

---

## Phase 7: Documentation — ✅ COMPLETE

| Document | Path | Status |
|----------|------|--------|
| Final Remediation Report | `docs/DASHBOARD_FINAL_REMEDIATION_REPORT.md` | ✅ Created |
| Final Remediation Roadmap | `docs/DASHBOARD_FINAL_REMEDIATION_ROADMAP.md` | ✅ Created |
| Settings Traceability Matrix | `docs/SETTINGS_TRACEABILITY_MATRIX.md` | ✅ Created |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation | Status |
|------|------------|--------|------------|--------|
| StdLib copy mismatch (STD-001) | High (pre-existing) | Medium | Use project StdLib for compile; document for architectural decision | Documented |
| origin.txt path mismatch (ORG-001) | High (pre-existing) | Low | Terminal re-registration needed | Documented |
| Unverified runtime visual | Medium | Medium | Strategy Tester validation excluded per scope | Accepted |
| Dashboard layout on extreme charts | Low | Low | Edge-case handling in `RecalculateDashboardLayout()` | Tested via invariants |

---

## Sign-Off

**Mission Status**: ✅ **COMPLETE — ALL AUTHORIZED ACCEPTANCE CRITERIA VERIFIED**

**Completed By**: MT5 Engineer (Ponytail lite mode)
**Date**: 2026-11-20
**Branch**: `fix/root-cause-repair-dashboard-coordinator-snapshot-settings` @ `1e6ff88`

---

**Explicit Exclusions (per mission scope):**
- `STRATEGY TESTER / VISUAL TESTER / OPTIMIZATION: NOT RUN — EXPLICIT USER EXCLUSION`
- `LIVE BROKER MUTATION: NOT PERFORMED`
- `PERSISTENT LEDGER / AUTHORITY MUTATION: NOT PERFORMED`
- `GIT COMMIT / PUSH / PR: NOT PERFORMED`