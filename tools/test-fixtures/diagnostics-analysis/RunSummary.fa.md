# Dashboard Diagnostics Analysis Summary

**Run ID:** DIAG_NEG_11_RENDERING_MISSING
**Analysis Time:** 2026-11-16 01:08:34
**Source JSON:** C:\Users\mousa\AppData\Roaming\MetaQuotes\Terminal\EBC70E542FD2519E5E0B3CC8F66A5C22\MQL5\tools\test-fixtures\diag_NEG_11_rendering_missing.json

## Overall Result
- **Errors:** 1
- **Warnings:** 0
- **Assertions:** 23 total, 21 passed, 2 failed
- **First Failure Stage:** RENDER
- **Dashboard Verified:** False

## Lifecycle Chain
| Stage | Status | Detail |
|-------|--------|--------|
| INPUT | ✅ PASS | Input parameters received |
| CONFIG | ✅ PASS | Config propagated without mismatch |
| RUNTIME | ✅ PASS | At least one valid runtime |
| DATA | ✅ PASS | Market data available for snapshot |
| FEATURES | ✅ PASS | Features computed for at least one write |
| ENGINE | ✅ PASS | Engine evaluation completed for at least one read |
| SNAPSHOT_WRITE | ✅ PASS | Complete snapshot write |
| SNAPSHOT_READ | ✅ PASS | Successful snapshot read |
| APPLY | ✅ PASS | Dashboard apply with valid snapshot |
| RENDER | ❌ FAIL | Dashboard verified flag true |

## Errors
- Lifecycle chain BROKEN at stage: RENDER

## Warnings
- None

## Assertions
- Schema.run_info: PASS - Present
- Schema.snapshot_writes: PASS - Present
- Schema.snapshot_reads: PASS - Present
- Schema.dashboard_applies: PASS - Present
- Schema.config_checks: PASS - Present
- Schema.runtime_states: PASS - Present
- Write.EURUSD.Gen1.Success: PASS - KeyLen=19, Written=2, Failed=0
- Read.EURUSD.Gen1.Success: PASS - Age=1s
- Correlation.EURUSD.Gen1: PASS - Writer/Reader generation match
- Apply.Last.Success: PASS - Stage=EVALUATED, Gen=1, Valid=True
- Apply.DashboardVerified: FAIL - From JSON flag
- Config.AllMatch: PASS - No mismatches in 1 checks
- Runtime.EURUSD.Idx0.Valid: PASS - Gen=1, Stage=3
- Chain.INPUT: PASS - Input parameters received
- Chain.CONFIG: PASS - Config propagated without mismatch
- Chain.RUNTIME: PASS - At least one valid runtime
- Chain.DATA: PASS - Market data available for snapshot
- Chain.FEATURES: PASS - Features computed for at least one write
- Chain.ENGINE: PASS - Engine evaluation completed for at least one read
- Chain.SNAPSHOT_WRITE: PASS - Complete snapshot write
- Chain.SNAPSHOT_READ: PASS - Successful snapshot read
- Chain.APPLY: PASS - Dashboard apply with valid snapshot
- Chain.RENDER: FAIL - Dashboard verified flag true
