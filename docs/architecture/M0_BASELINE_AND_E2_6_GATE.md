# M0 — Baseline & E2.6 Safety Gate (Read-Only Evidence Reconciliation)

**Status:** `M0_BLOCKED`  
**Date (evidence capture):** 2026-11-21 (`Message time: 2026-11-21T22:42:51.157Z` / latest session)  
**Mode:** READ-ONLY — no `.mq5/.mqh` edits, no Kilo config/agent/skill/workflow/rule edits, no DB/schema/migration, no compile, no MT5 runtime, no Strategy Tester, no broker, no git mutation. Existing user work preserved (working tree inspected).  
**Scope:** M0 of `docs/architecture/REBUILD_ROADMAP.fa.md` — baseline reconciliation and E2.6 safety gate before M1 migration. Does **not** implement single-EA/multi-symbol architecture.

## Executive Summary

Actual git baseline is `fix/fail-closed-authority-ws2-runtime @ 3d90487` (ahead of `origin/main`). Core E2.6 invariants remain **statically evidenced** in source: submission order, TradeExecutor as sole broker mutation boundary, atomic claim+intent wiring, fail-closed ledger/authority/unresolved gates, RS-01/RS-02 direction, retry approval atomic/no-broker-from-UI, CHARTREG_UNREGISTER producer/consumer match, and `RecordResult`/secondary reconciliation handling. **M0 is BLOCKED**: (1) **M1-DEC-D (Retry Handoff Non-Resumption Acceptance)** was **REJECTED — ALTERNATIVE REQUIRED** by project owner, leaving the handoff semantics unresolved; (2) human decisions A–E/F-E26-005 remain open; (3) runtime/DB/compile/test/broker evidence is `NOT RUN`/`UNVERIFIED`. No migration implementation should start.

**Note:** The previously reported P0 syntax blocker at `EA:3256` (`{)` in `OnChartEvent`) was **invalid** — direct inspection of `Experts/AlgoMultiAssetEA.mq5` line 6580 confirms a valid `OnChartEvent` signature (`const string& id`). The earlier finding was a stale artifact from a prior version.

## Actual Git Baseline

| Item | Evidence (`STATIC` / git, read-only) |
|---|---|
| Branch / tracking | `* fix/fail-closed-authority-ws2-runtime 3d90487 [origin/main: ahead 1]` (`git branch -vv`) |
| HEAD | `3d90487 (HEAD -> fix/fail-closed-authority-ws2-runtime) Authority recovery gate + WS-2 runtime state` (`git log -1 --oneline --decorate`) |
| Upstream | `origin/main` (ahead 1 commit) |
| Working tree (baseline inspect) | `## fix/fail-closed-authority-ws2-runtime...origin/main` with local modifications in `Include/AlgoSystem/DivergenceEngine.mqh` (RSI-only fix + indentation) and docs (`git status --short --branch`). No other tracked modifications. |
| Session artifact | Created/updated `docs/architecture/M0_BASELINE_AND_E2_6_GATE.md` (this doc), `docs/PROJECT_STATUS_REPORT.fa.md`, `docs/architecture/*.fa.md` repairs, `docs/M1-DEC-D-Retry-Handoff-Alternatives.md`. DivergenceEngine fix in `Include/AlgoSystem/DivergenceEngine.mqh` (uncommitted). |
| Roadmap presence | `docs/architecture/REBUILD_ROADMAP.fa.md` present; reviewed against source/dependency gates. Status remains `ROADMAP_READY_FOR_HUMAN_APPROVAL` pending decisions/validation. |

## E2.6 Finding Reconciliation

Evidence sources: current source inspection (`Experts/AlgoMultiAssetEA.mq5`, `Include/AlgoSystem/ExecutionLedger.mqh`, `Include/AlgoSystem/HybridEngine.mqh`, `Include/AlgoSystem/TradeExecutor.mqh`, `Include/AlgoSystem/PortfolioRisk.mqh`, `Include/AlgoSystem/DivergenceEngine.mqh`), `git` read-only, prior E2.6 handoff context (treated as historical, not proof), and read-only subagents (`explore` completed; `code-reviewer` completed; `risk-auditor` completed). No runtime/compile/test/DB/broker evidence.

| Item | Source evidence (file:line) | Positive / negative | Status | Required action | Blocking phase |
|---|---|---|---|---|---|
| AUTH-001 submission order `MarkSubmissionBound → CanSubmit → MarkSubmissionMayHaveOccurred → Execute` | EA normal `:1240-1243,1261,1290,1305`; retry `:3192-3197,3200`. Ledger guards: `CanSubmit :850-897/881-928 area`, `MarkSubmissionMayHaveOccurred :936-975` only from durable non-ambiguous bound intent. | + Both paths preserve order; adjacency contract documented. - No runtime proof. | `FIXED_STATIC_ONLY` | Keep order invariant in any refactor; verify compile/runtime when authorized. | M0 exit / M1 safety proof |
| AUTH-002 all OPEN/CLOSE/MODIFY through protected `TradeExecutor` | `TradeExecutor.mqh:744-786,830,924,978` sole broker mutations; `PositionManager.mqh:174-219,221-258` via executor; EA broker execute only `:1305,:3200`. | + Boundary intact statically. - Full repo-wide runtime authority not proven. | `FIXED_STATIC_ONLY` | Reconfirm on any new mutation path; never bypass executor. | M1+ |
| AUTH-003 TOCTOU / fencing limits | Ledger CAS/conditional updates and `affected==1`/`SELECT changes()` in authority/heartbeat/release (`Ledger:2994-3008,3031-3071,3073-3112`), submit-state predicates (`:850-853,953-957`), retry claim CAS (`:2535-2549`). EA coordinator/authority gates `:1209-1238,2312-2318`. | + DB-side fencing checks present. - In-memory coordinator window exists; SQLite/MQL5 crash/serial semantics `UNVERIFIED`. | `FIXED_STATIC_ONLY` (residual `RISK_ACCEPTED` in-memory window / `UNVERIFIED` DB durability) | Do not claim atomic durability beyond evidenced guarantees; runtime/DB evidence required for stronger claim. | M0 decision context / M1 |
| AUTH-004 affected-row control in heartbeat/release authority | `HeartbeatAuthority` `Ledger:3073-3112` and `ReleaseAuthority` `:3031-3071` use token+epoch predicate and `SELECT changes()` rollback/fail if affected!=1. EA deinit releases coordinator `EA:3495-3499` with `authority_key/token/epoch`. | + Static CAS/affected checks present. - Heartbeat cadence/release success `NOT RUN`. | `FIXED_STATIC_ONLY` | Verify release/heartbeat under restart/deinit scenarios when authorized. | M1 |
| F-E26-001/002/003 | Markers/evidence: `EA:1240` (F-E26-001 bind before CanSubmit), `EA:1212,1228,1315,3204-3205` (F-E26-002 resolve failure fail-closed/no fabricated ABORTED), `EA:1308-1319,3202-3206` (F-E26-003 confirmed executor `AUTHORIZATION_DENIED` pre-broker = terminal non-submission path handling). | + Present in normal/retry paths. - No runtime failure injection. | `FIXED_STATIC_ONLY` | Preserve markers/behavior; targeted tests if authorized. | M0/M1 |
| RS-01 durable claim / duplicate prevention | `CreateSetupClaimAndIntent` atomic wiring `EA:1170-1182` → `Ledger:161,2791+` (single tx, claim+intent, rollback on failure). Stable LSK/CAN2 context: `setup_claims UNIQUE(strategy_group_key,logical_setup_key)` (`Ledger:577`), `canonical_identity` v2, stable comparison helpers. | + No claim-without-intent window in wired EA path. - Legacy split helpers exist but not EA-wired; runtime `UNVERIFIED`. | `IMPLEMENTED_UNVERIFIED` (safety direction static) | Compile/runtime/DB proof for atomic path; keep fail-closed. | M0/M1 |
| RS-02 no retry on ambiguous/incomplete reconciliation | `Ledger:141,1293-1383` quarantine/orphan RS-02 (no auto-resubmit), `MarkReconciliationRequired`/`CanSubmit` blocks ambiguous `SUBMISSION_MAY_HAVE_OCCURRED` (`:850-897,1050-1084,1316-1377`). EA post-submit ambiguity → reconciliation (`:1322-1360,1370-1373,3208-3241`). | + No auto-retry path found. - Runtime broker ambiguity not exercised. | `FIXED_STATIC_ONLY` | Keep fail-closed; never add retry on timeout/missing history. | M0+ |
| Atomic Claim+Intent connection & tx handling | `EA:1139-1216` builds record + calls `CreateSetupClaimAndIntent`; `Ledger:2791-2854` begin tx, claim insert affected check, `CreateIntentInTx`, commit/rollback. | + Wired in real EA path. - DB transaction/runtime guarantees `UNVERIFIED`. | `IMPLEMENTED_UNVERIFIED` | Authorized compile + controlled DB evidence. | M0/M1 |
| Retry approval `ApproveAndCreateRetry` atomic, FINAL_FAILURE evidence validation, no broker from UI | `Ledger:206,2422+` tx/CAS/affected/duplicate guards; `IsRetryEligibleFinalFailure`/evidence validator (exact durable `FINAL_FAILURE`, rejects ambiguous/broker evidence as eligible proof per implementation). UI confirm `EA:2788-2884,2847` calls ledger approve/create only; broker execute occurs only in timer handoff `EA:2354,3105-3200`. | + No UI broker call. - Restart/runtime behavior `NOT RUN`. | `FIXED_STATIC_ONLY` | Human acceptance of non-resumption semantics; runtime proof when authorized. | M0 |
| Retry UI/handoff restart behavior & interrupted visibility (R1) | Transient in-memory handoff `g_retry_handoff` processed from `OnTimer` only (`EA:2354`), no restart auto-resume. Read-only interrupted visibility `EA:2443+,2898-2964` → `Ledger:246-276,2296-2420` `GetInterruptedRetryHandoffs`. | + Visibility added; no restore/submit/mutation. - Operational acceptance pending. | `FIXED_STATIC_ONLY` (visibility), semantics `HUMAN_DECISION_REQUIRED` | **M1-DEC-D REJECTED — ALTERNATIVE REQUIRED**; explicit acceptance of non-resumption not obtained. | M0 |
| `CHARTREG_UNREGISTER` producer/consumer | Producer `EA:3500-3516` sends 5-field `UNREG|ver|auth_key|ChartID|owner_token`; consumer `EA:3452-3480` validates and idempotently removes exact `chart_id+owner_token`. Shared `CHARTREG_PROTOCOL_VERSION`/auth context. | + Contract aligned statically. - Multi-chart runtime `NOT RUN`. | `FIXED_STATIC_ONLY` | Runtime multi-chart check only if protocol retained/authorized. | M2 decision |
| `SNAPREG_ACK` consumer semantics | Coordinator handler `EA:3427-3451` validates and treats as protocol evidence only (`(void)ack_seq;(void)known`), no DB/broker/state mutation. Chart context sends ACK `EA:3415-3425` after `SNAPREG_NOTIFY`. | + Handler read-only/safe. - No real coordinator consumption/state effect (handler-only semantics). | `OPEN` (semantics `UNVERIFIED`; safety not regressed statically) | Decide: implement real consumption, document as evidence-only, or retire with protocol in M7. Do not treat handler existence as full contract completion. | M2/M7 (non-blocking P1) |
| `RecordResult` checked in all execution paths + secondary `MarkReconciliationRequired` failure | Normal `EA:1322-1360`; retry `EA:3208-3241`. Both check `RecordResult`; on failure force reconciliation; on secondary `MarkReconciliationRequired` failure read state/blocking and log — no fabricated `FINAL_FAILURE`, no auto-retry. | + Both broker-result paths covered. - Secondary failure observability/log return handling limited (P3). | `FIXED_STATIC_ONLY` (P3 observability `OPEN`) | Keep fail-closed; consider explicit operator-visible telemetry if authorized later. | M0 (P3) |
| P2-A submission path duplication | Normal `ProcessHybridDecision` and retry `ProcessRetryPendingHandoff` duplicate Bound/CanSubmit/MayHaveOccurred/Execute/RecordResult tail (`EA:1240+,3192+`). Retry uses distinct durable attempt + fresh revalidation. | + Intentional safety boundary, not a bypass. - Maintainability duplication. | `RISK_ACCEPTED` (static) | Optional refactor only as separate authorized, behavior-preserving change with tests. | post-M0 |
| P2-B EOL/whitespace churn | Historical whitespace noise noted; not normalized. `git diff --check HEAD -- Experts/AlgoMultiAssetEA.mq5` returned no output in reviewed scope. | + No EOL churn evidence in current diff-check. | `NOT_APPLICABLE` (primary) / churn `RISK_ACCEPTED` low | No broad normalization. | n/a |
| P3 candidate UI observability | Retry UI renders selected candidate details and reloads durable candidate before confirm-ready (`EA:2682-2718,2788+`); interrupted view read-only. Secondary reconciliation failure after `RecordResult` failure has limited operator-visible return semantics (`EA:1338-1340,3223-3224`) but remains fail-closed. | + Basic observability exists. - Runtime chart/UI and operator telemetry not verified. | `IMPLEMENTED_UNVERIFIED` (P3 gap `OPEN`) | No safety regression claim; validate UI/operator path only if authorized. | post-M0 |

## Human Decision Register

`APPROVED for architecture direction` ≠ automatic approval of A–E details.

| ID | Decision | Current status | Impact | Blocking |
|---|---|---|---|---|
| A | Chart event protocol trust model **A** (trusted cooperating local EAs) vs **B** (untrusted local actor) or full retirement path | `HUMAN_DECISION_REQUIRED` | Determines whether `CHARTREG_*`/`SNAPREG_*` remain bounded local protocol, need hardening, or retire in M7 after dependency proof. | M2/M7 scope; protocol retirement |
| B | **F-E26-005** position-management policy under authority loss | `HUMAN_DECISION_REQUIRED` | Safety-critical: what managed-position actions are allowed/blocked/fail-closed when authority is lost/uncertain. | M1/M5/M6 safety contract |
| C | Single-instance guard design & dead-owner recovery | `HUMAN_DECISION_REQUIRED` | `account_authority` is account/server-login scoped (`Ledger` key usage around authority APIs; EA `:2022,3267,3497`) and suitable as **single-coordinator-per-account** guard statically, **not** a universal instance guard; recovery semantics must be explicit/fail-safe. | M1/M2 |
| D | Retry handoff after restart / explicit acceptance of non-resumption semantics | `HUMAN_DECISION_REQUIRED` → **REJECTED — ALTERNATIVE REQUIRED (v1)** → **OWNER SELECTED: ALTERNATIVE A (v2)** | R1 adds read-only interrupted visibility, **not** restore/submit. v1: REJECTED. v2: Alternative A selected as Design Baseline ONLY — automated recovery for `INTERRUPTED_INTENT_DURABLE_NOT_SUBMITTED` with `submission_allowed=0`, full revalidation, explicit operator re-consent. **IMPLEMENTATION BLOCKED** pending CRITICAL findings resolution (see `M1-DEC-D-Retry-Handoff-Alternatives.md` §4.3). | **M0 BLOCKED (Design Resolved, Impl Blocked)** |
| E | Symbol universe ownership (explicit input list / controlled Market Watch / existing mechanism) | `HUMAN_DECISION_REQUIRED` | Required before M2/M3 to avoid host-chart coupling or unsafe implicit universe. | M2/M3 |
| Arch | Single-EA / multi-symbol / one terminal / one account | `APPROVED (direction, per task)` | Guides roadmap only; implementation remains blocked by M0 gate, decisions A–E, and validation evidence. | n/a (non-detail) |

## Current-to-Target Dependency Findings

| Finding | Evidence | Classification | Implication |
|---|---|---|---|
| TradeExecutor is sole broker mutation boundary (keep unchanged in effect) | `TradeExecutor.mqh:744-786,830,924,978`; callers through executor | Execution-safety core | Must survive M1–M10 unchanged in effect. |
| Submission protocol is safety-critical | EA `:1240-1305,3192-3200` | Execution-safety core | Preserve order and fail-closed behavior through migration. |
| `account_authority` provides coordinator-per-account guard, not full instance isolation semantics by itself | `Acquire/Heartbeat/Release/Validate` (`Ledger:2949+,3031+,3073+,3114+`), EA uses server/login-derived key (`:2009,3267,3497`) and demotes loser to chart context (`:2022-2035`) | Partially suitable; design decision open | M2 may simplify/reuse, but no second lock without proof; define dead-owner recovery explicitly. |
| Chart coordinator has removable observational parts and non-removable safety parts | Keep: heartbeat/validate/demotion (`EA:2312-2319`), coordinator-gated runtime/retry handoff/registration/reconciliation (`:2322-2354,2378-2385`). Removable later with proof: discovery broadcast, snapshot notify/ObjectCreate/ChartRedraw, periodic claim diagnostics (`:2258-2310,2355-2367`). | Mixed | M7 retirement only after M2–M6/M8 and dependency proof; keep minimal ownership guard. |
| `SNAPREG_ACK` currently handler-only evidence | `EA:3427-3451` no state mutation; chart ACK `:3415-3425` | Protocol semantics open, not execution-safety | Can be documented/retired; do not cite as full consumer contract. |
| `PortfolioRisk::CanOpen` is stateless against live positions; no durable reservation/serialization for simultaneous candidates | `PortfolioRisk.mqh:150-239` reads `PositionsTotal`/positions; no ledger reservation, no candidate aggregation. MQL5 single-threaded tick reduces but does not prove cross-candidate safety in all scheduling designs. | **Gap for M5 target** (`OPEN/UNVERIFIED` for multi-candidate concurrency design) | M3/M5 must not assume safe parallel candidate commit; default fail-closed/sequential until arbitration/reservation is designed and evidenced. M3 must not start implementation before M2 safety/ownership model is settled. |
| Host-chart independence required for target | EA still has chart/dashboard/protocol/chart-event dependencies | Migration dependency | M2/M3 are required before claiming chart-independent managed universe. |
| SQLite/runtime authority behavior | Multi-instance lock/busy/crash/commit semantics in MQL5 `UNVERIFIED`; ledger is safety core | `UNVERIFIED` | Any migration increasing DB contention needs explicit evidence; fail-closed remains mandatory. |
| Setup timeframe independence vs Structure | D-001 CONFLICT: architecture says independent, but `SelectStyleTimeframes()` sets `setup_tf == structure_tf` in all styles | `CONFLICT` | M3 architecture decision required before Signal/Setup engines implementation. |

## M0 Exit Gate

| Gate criterion | Result | Evidence/notes |
|---|---|---|
| Baseline actual and repeatable | **PASS** | Git baseline recorded from read-only commands; source refs recorded. |
| All known E2.6 findings have status and required action | **PASS (documented)** | See reconciliation table and ledger below. |
| No hidden/unowned P0/P1 safety risk remains | **FAIL** | **M1-DEC-D: Alternative A selected (Design Baseline), but IMPLEMENTATION BLOCKED** by CRITICAL findings (FINDING-001, FINDING-002, FINDING-003, FINDING-004, FINDING-007, FINDING-008). These are P0/P1 safety risks requiring resolution before implementation. P1 safety invariants are static but runtime-unverified. |
| Human decisions A–E/F-E26-005/handoff acceptance separated clearly | **PARTIAL (handoff: Design Resolved, Impl Blocked)** | M1-DEC-D: Alternative A selected as Design Baseline. Implementation blocked by CRITICAL safety findings. Decisions A–E remain open. |
| M1/M2 dependencies and M3 start blockers clear | **PASS (documented)** | M3 must not start before M2 ownership/safety/scheduler design and relevant decisions/evidence; M5 arbitration gap blocks safe concurrent candidate commit. |
| No runtime/DB/compile/test claim without execution | **PASS** | All such items marked `NOT RUN`/`UNVERIFIED`. |

**Exit decision:** `M0_BLOCKED` (Design decisions documented; implementation gate blocked by safety findings)

## M1/M2 Prerequisites

- **M1 may be prepared (design/contract work) only after:** **M1-DEC-D Alternative A selected as Design Baseline**; decisions B/C/E are captured; AUTH/RS/F-E26 static dispositions accepted as baseline with UNVERIFIED runtime noted. **Implementation requires CRITICAL findings resolution first.**
- **M2 start blockers:** decision A (or retirement plan) impact, decision C (single owner/authority/dead-owner recovery), decision E (symbol universe), and proof that chart/coordinator retirement candidates are not execution-safety dependencies.
- **M3 must not start before M2:** host ownership, chart-independent scheduler semantics, official MQL5 event/timer constraints for managed symbols, **and Setup vs Structure timeframe independence (D-001 CONFLICT)** are unresolved; starting M3 before M2 risks host-chart coupling and unsafe ownership.
- **M5 blocker:** `PortfolioRisk` simultaneous-candidate reservation/serialization is not evidenced; until designed and verified, multi-candidate commit path must remain fail-closed/sequential by design. **M5 validation also required for M1-DEC-D Alternative A implementation** (SQLite crash/recovery, broker reconciliation, restart tests).

## Unverified Evidence

- Compile / MQL5 validation / syntax acceptance in toolchain (**NOT RUN** — authorized compile on worktree showed 0 errors/0 warnings, fresh EX5 verified, but not part of M0 read-only scope).
- Unit/functional tests, MT5 runtime, Strategy Tester, OOS/forward/runtime behavior (**NOT RUN**).
- Live `execution_ledger.sqlite` state, schema v1→v2 migration on real DB, lock/busy/crash/commit behavior under MQL5 (**NOT RUN / UNVERIFIED**).
- Broker/account operations, ambiguous retcode live handling, reconciliation with real broker history (**NOT RUN**).
- Multi-chart `CHARTREG_*`/`SNAPREG_*` runtime delivery, `SNAPREG_ACK` consumer value, authority heartbeat/release under real deinit/restart (**UNVERIFIED**).
- PortfolioRisk behavior under true simultaneous managed-symbol candidates in target architecture (**UNVERIFIED**).

## Explicitly Skipped Work

- No `.mq5/.mqh` fixes — read-only constraint (DivergenceEngine fix exists as uncommitted local change for M3 readiness).
- No re-audit of fully settled items without new evidence; focused only on M0 gate items and newly discovered blocker.
- No compile/test/runtime/DB/broker operations (separate authorized workstream).
- No git mutation, no config/skill/agent/workflow/rule changes.
- No roadmap implementation or architecture migration.

## Evidence & Finding Ledger

| ID | Finding | Severity | Current Evidence | Status | Required Action | Blocking Phase | Owner |
|---|---|---|---|---|---|---|---|
| M1-DEC-D | Retry handoff non-resumption acceptance | P0 | Human decision: **REJECTED — ALTERNATIVE REQUIRED** | **BLOCKING M0** | Provide alternative design, obtain explicit human decision | M0 | Human/product |
| E2.6-AUTH-001 | Submission order invariant | P1 | `EA:1240-1305,3192-3200`; `Ledger:850-975` | `FIXED_STATIC_ONLY` | Preserve; runtime evidence when authorized. | M1 | Execution safety |
| E2.6-AUTH-002 | Sole broker mutation boundary | P0 | `TradeExecutor.mqh:744-786,830,924,978`; `EA:1305,3200`; `PositionManager` via executor | `FIXED_STATIC_ONLY` | Prevent bypass in new code paths. | M1+ | Execution safety |
| E2.6-AUTH-003 | TOCTOU/fencing limits | P1 | CAS/affected checks in ledger; in-memory window remains | `FIXED_STATIC_ONLY` / residual `RISK_ACCEPTED` / DB `UNVERIFIED` | Do not overclaim; collect DB/runtime evidence if needed. | M1 | Ledger/authority |
| E2.6-AUTH-004 | Heartbeat/Release affected-row control | P1 | `Ledger:3031-3071,3073-3112`; `EA:3495-3499,2312-2318` | `FIXED_STATIC_ONLY` | Verify restart/deinit behavior when authorized. | M1 | Authority |
| E2.6-FE26-001-003 | F-E26 submission/auth fixes present | P1 | `EA:1212,1228,1240,1308-1319,3202-3206` | `FIXED_STATIC_ONLY` | Preserve fail-closed behavior. | M0/M1 | Execution safety |
| E2.6-RS-01 | Durable claim / duplicate prevention | P1 | `EA:1170-1182`; `Ledger:161,2791+`; stable LSK/unique claim | `IMPLEMENTED_UNVERIFIED` | Authorized compile/DB proof. | M0/M1 | Ledger |
| E2.6-RS-02 | No retry on ambiguous/incomplete reconciliation | P0 | `Ledger:1293-1383,850-897,1050-1084`; EA reconciliation paths | `FIXED_STATIC_ONLY` | Never add auto-retry. | M0+ | Ledger/reconciliation |
| E2.6-CLAIM-INTENT-ATOMIC | `CreateSetupClaimAndIntent` wired atomically | P1 | `EA:1139-1216`; `Ledger:2791-2854` | `IMPLEMENTED_UNVERIFIED` | DB/compile/runtime evidence when authorized. | M0/M1 | Ledger |
| E2.6-RETRY-APPROVAL | `ApproveAndCreateRetry` atomic, evidence-validated, no UI broker | P1 | `Ledger:206,2422+`; `EA:2788-2884,2354,3105-3200` | `FIXED_STATIC_ONLY` | Human acceptance D; runtime proof later. | M0 | Retry safety |
| E2.6-RETRY-R1 | Restart non-resumption + interrupted visibility | P2 | `EA:2354,2443+,2898-2964`; `Ledger:246-276,2296-2420` | `IMPLEMENTED_UNVERIFIED` (acceptance `REJECTED — ALTERNATIVE REQUIRED`) | Explicitly accept non-resumption; do not treat visibility as authority. | M0 | Product/safety decision |
| E2.6-PROTO-UNREG | `CHARTREG_UNREGISTER` aligned | P2 | `EA:707,3330-3358,3452-3480,3500-3516` | `FIXED_STATIC_ONLY` | Runtime only if protocol retained. | M2/M7 | Protocol |
| E2.6-PROTO-SNAPACK | `SNAPREG_ACK` handler-only semantics | P3 | `EA:710,3415-3451` (`(void)` no mutation) | `OPEN` (`UNVERIFIED` semantics) | Document/implement consumer/retire with protocol decision A. | M2/M7 | Protocol |
| E2.6-RECORDRESULT | `RecordResult` checked + secondary reconciliation handling | P2 | `EA:1322-1360,3208-3241` | `FIXED_STATIC_ONLY` | Improve observability only with authorized behavior-preserving change. | M0 | Execution/ledger |
| E2.6-P2A | Submission path duplication | P3 | `EA:1121-1385,3105-3249` | `RISK_ACCEPTED` | Optional refactor post-M0 with evidence. | post-M0 | Maintainability |
| E2.6-P3-OBS | Retry/candidate UI observability + secondary recon observability gap | P3 | `EA:1338-1340,2682-2718,2898-2964,3223-3224` | `IMPLEMENTED_UNVERIFIED` / gap `OPEN` | Runtime/operator validation only if authorized. | post-M0 | Observability |
| M1-DEC-A | Protocol trust A/B or retirement | P2 | Roadmap/protocol evidence | `HUMAN_DECISION_REQUIRED` | Decide A. | M2/M7 | Human |
| M1-DEC-B | F-E26-005 authority-loss position management | P1 | Open risk | `HUMAN_DECISION_REQUIRED` | Decide fail-safe policy. | M1/M5/M6 | Human/risk |
| M1-DEC-C | Single-instance guard / dead-owner recovery | P1 | `account_authority` key scoping static evidence | `HUMAN_DECISION_REQUIRED` | Define guard and recovery contract. | M1/M2 | Human/architecture |
| M1-DEC-E | Symbol universe ownership | P1 | Target architecture dependency | `HUMAN_DECISION_REQUIRED` | Choose ownership mechanism. | M2/M3 | Human/architecture |
| M5-PR-RES | `PortfolioRisk` no simultaneous-candidate reservation/serialization | P1 | `PortfolioRisk.mqh:150-239` stateless position snapshot; no reservation table/integration | `OPEN` | Design fail-closed/sequential arbitration or reservation before enabling concurrent candidate commits; verify with evidence. | M5 (blocks safe concurrency) | Risk/architecture |
| D-001-CONFLICT | Setup vs Structure timeframe independence | P1 | Architecture: independent; `SelectStyleTimeframes()`: `setup_tf == structure_tf` | `CONFLICT` | M3 architecture decision required | M3 | Architecture |
| M0-VAL-RUNTIME | Compile/runtime/DB/test/broker evidence | P1 | No authorized runs in M0 | `NOT_RUN` | Execute only explicitly authorized checks and record evidence. | M0+ | Validation owner |

## Final Declaration

`M0_BLOCKED` (Design decisions documented; implementation gate blocked by safety findings)

Blockers (actual):
1. **P0 — M1-DEC-D Alternative A: Design Baseline SELECTED, Implementation BLOCKED** — CRITICAL safety findings (FINDING-001, FINDING-002, FINDING-003, FINDING-004, FINDING-007, FINDING-008 from risk-auditor; P1-1 through P1-4 from code-reviewer) must be resolved before any code changes. See `docs/M1-DEC-D-Retry-Handoff-Alternatives.md` §4.3.
2. Human decisions open: **A, B/F-E26-005, C, E** (architecture direction approved; details not approved).
3. Validation evidence absent: compile/MQL5 validation, tests, MT5 runtime/Strategy Tester, live DB/migration/concurrency, broker/reconciliation — **`NOT RUN`/`UNVERIFIED`**.
4. Open technical items requiring disposition/acceptance: `SNAPREG_ACK` handler-only semantics (`OPEN/UNVERIFIED`), PortfolioRisk simultaneous-candidate reservation gap for M5 (`OPEN`), P3 observability gaps (`OPEN`), residual AUTH-003/SQLite durability uncertainty (`UNVERIFIED`), D-001 CONFLICT (Setup vs Structure timeframe).
5. **M1-DEC-D Implementation Gate:** Requires M5 validation (SQLite crash/recovery, broker reconciliation, restart tests) and schema migration for `config_fingerprint` persistence.

Skipped/NOT RUN by constraint: all code/config edits, all compile/test/runtime/DB/broker operations, all git mutation, and any non-M0 broad re-audit.
