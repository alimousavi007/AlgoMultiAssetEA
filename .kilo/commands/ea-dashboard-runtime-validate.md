---
description: Composite end-to-end Dashboard runtime validation: diagnosis, implementation, compile/audit/repair, controlled Visual Tester verification, and independent reviews
---

# EA Dashboard Runtime Validate

Composite command: `/ea-dashboard-runtime-validate`

This Workflow orchestrates complete AlgoMultiAssetEA Dashboard investigation, implementation, compile/audit/repair cycle, controlled MT5 Visual Strategy Tester verification, independent reviews, and strict completion gates **when the user separately invokes it for the actual Dashboard mission**.

## Mission boundary (this preparation artifact)

- This file is a reusable Workflow definition only.
- When invoked for execution, it must follow project permissions and never execute unauthorized MQL5 edits, compilation, terminal launch, Strategy Tester, DB mutation, or broker operations.
- Do not start this Workflow automatically after preparing it.

## 1. Composition contract (non-recursive)

Primary execution owner: the active Kilo session/agent running `/ea-dashboard-runtime-validate`.

Read and apply the full instructions of these component Workflow files **in the same session**:

| Component file | Role | Record as |
|---|---|---|
| `.kilo/commands/ea-dashboard-runtime.md` | Dashboard runtime requirements, diagnostic lifecycle, Safe Mode intent, Visual Tester and Dashboard acceptance criteria (subject to compatibility overrides in §4) | `APPLIED AS COMPONENT INSTRUCTIONS` |
| `.kilo/commands/ea-implement.md` | Baseline, evidence-led implementation, minimal correction, independent review and repair discipline | `APPLIED AS COMPONENT INSTRUCTIONS` |
| `.kilo/commands/mt5-validate.md` | Compilation, functional/static/runtime/tester authorization, artifacts, and evidence classification | `APPLIED AS COMPONENT INSTRUCTIONS` |

Conditionally read/apply when scope requires them:

| Condition | Component file | Record as |
|---|---|---|
| Safe Mode, execution, authority, risk, retry, broker mutation, or persistence changes | `.kilo/commands/ea-risk-review.md` (if present) | `APPLIED AS COMPONENT INSTRUCTIONS` |
| Coordinator, Chart Context, Setup, Attempt, Snapshot ownership, or reconciliation changes | `.kilo/commands/hybrid-lifecycle-review.md` (if present) | `APPLIED AS COMPONENT INSTRUCTIONS` |

Rules:
- **Never invoke a child slash command recursively and never assume nested dispatch will execute.**
- Do **not** compose `/ea-investigate-fix-validate` as another full pipeline (overlaps implementation/validation). Reuse its investigation criteria only where needed.
- Do **not** duplicate the entire `/ea-quality-cycle` file; preserve its quality principles and apply only portions needed for the Dashboard task.
- If a required component path cannot be read, stop with a precise blocker (`BLOCKED`) rather than silently skipping it.

## 2. Registry, Skills, Agents, TODO, and tool-schema discipline

### 2.1 Before every file modification (mandatory)
Before **every individual** `edit`, `write`, patch, or other file-modifying tool call:
1. Inspect the current Kilo tool registry.
2. Find the exact registered editing tool.
3. Read its current full argument schema.
4. Identify required/optional parameters, exact names, types, constraints.
5. Build the call using exactly that schema.
6. Verify operation result.
7. Re-read the modified file.
8. Inspect diff and verify intended result.

Never guess tool names/parameters (including `filePath`, `path`, `oldString`, `newString`, `content`). On invalid arguments, re-read schema and correct; do not guess. Do not bypass native editing schemas with shell redirection, Python writes, or unrelated MCP filesystem tools.

### 2.2 Before every MCP invocation (mandatory)
Inspect the actual connected MCP tool registry and full schema before **every individual operation**. Verify exact tool name, required/optional args and constraints, operation classification, expected return fields, and side effects. Never infer schema from docs, prior sessions, or older inventories.

### 2.3 Skills (actual `skill` tool only)
Invoke via native `skill` tool (reading `SKILL.md` is **not** invocation):
- Always for this composite execution: `algo-multiasset-ea`, `engineering`, `documentation-quality`.
- When running the Dashboard mission: `signal-pipeline-forensics`, `hybrid-strategy-lifecycle`, `mt5-strategy-tester`.
- Conditionally: `trading-risk` for execution/risk/Safe Mode changes; other specialist Skills only when changed scope requires.

If unavailable, report `UNAVAILABLE`/`BLOCKED`; never simulate.

### 2.4 Agents (actual `task` tool only)
Inspect Agent registry and native Task schema before delegation. Use bounded, non-overlapping questions; reviewers read-only.
- `explore`: read-only inventory/discovery (including Workflow/tool conflicts).
- Future execution support when registered: `mt5-engineer` (MQL5/API/runtime investigation), `mt5-tester-operator` (explicitly authorized isolated Tester operations only), `code-reviewer` (independent read-only final diff review), `risk-auditor` (independent read-only Safe Mode/execution safety review).
Verify registered IDs and actual tool availability; never simulate unavailable resources or claim invocation that did not occur.

### 2.5 TODO (`todowrite`)
Inspect actual `todowrite` schema before use. Maintain a small list for multi-step/dependent work, update at meaningful transitions, complete only with evidence, and leave no unfinished applicable items. Do not claim TODO use unless tool actually ran.

## 3. Authoritative compatibility overrides for `ea-dashboard-runtime.md`

The component `ea-dashboard-runtime.md` contains instructions that must be interpreted/overridden as follows:

### 3.1 Safe Mode semantics (authoritative)
- **When Dashboard Safe Mode is enabled, broker mutations must remain blocked in every execution context, including Visual Strategy Tester.**
- Separate and evidence each: (a) Visual Tester mode detected, (b) Dashboard graphical rendering active, (c) broker mutation authorization blocked.
- **Visual rendering permission must never imply broker-mutation permission.**
- Audit all actual reachable paths to `CTrade` and broker APIs **before launching Tester** (static reachability evidence). Zero runtime mutation counters are necessary but **not sufficient** without static path coverage.
- Do not invoke any trading MCP tool during audit or Dashboard-only validation.

### 3.2 Existing SET A/B files
- Inspect `Experts/AlgoMultiAssetEA_DASH_A.set` and `Experts/AlgoMultiAssetEA_DASH_B.set` before future Tester runs.
- **Preserve existing tracked SET files; no overwrite without explicit authorization.**
- Controlled Dashboard comparison must use **identical strategy/risk/configuration** and differ only in presentation; existing A/B may not be valid for isolating presentation effects—state this explicitly if so.
- Temporary test inputs must use **unique isolated paths**.
- **No artificial weakening of strategy thresholds, risk controls, or safety gates to create visible signals.**

### 3.3 Tester scripts and tool availability
- Check existence before use: `tools/Invoke-MT5DashboardTester.ps1`, `tools/Test-MT5DashboardDiagnostics.ps1`.
- Inspect complete script contents/help/parameters/write targets/side effects before execution; never claim existence or behavior from older Workflow text.
- Verified local parameter notes (inspect current script before run): prefer actual params (e.g. `-SetFilePath`, `-Visual`, `-WhatIf`, `-EnableDiagnostics`) rather than undocumented aliases like `-SetFile`/`-VisualMode`.
- Reuse actual connected MCP Tester tools when current schemas support the operation; reuse existing project tools where appropriate.
- Create a new helper **only** if a concrete, demonstrated coverage gap exists. Do not create duplicate compilers, Tester wrappers, or validation harnesses.
- Explicitly verify the correct MetaEditor installation; compiler script defaults may differ from the MCP-connected terminal.

### 3.4 Negative fixtures
- Inspect analyzer and fixture contracts and define **expected outcomes per fixture**.
- Do not require every negative fixture to hard-fail unless the contract requires it; do not turn a valid warning-only fixture into a false failure or silently count it as a hard pass.

### 3.5 Diagnostics timestamps
- Distinguish actual timestamps from proxy timestamps.
- If a diagnostic field uses `snapshot_time` (or similar) as a proxy for process/data/feature/evaluation timestamps, do not treat those fields as independent evidence. Do not invent timestamps or runtime events.

## 4. Single execution cycle (phases A–H)

### Phase A — Baseline and evidence
- Read exact applicable project instructions and approved decisions (`AGENTS.MD`, `.kilo/rules/core.md`, `.kilo/rules/mql5.md`, relevant Skills/records).
- Inspect Git status and preserve existing user changes (separate from task diff).
- Verify actual terminal, Data Folder, MetaEditor, and build identity.
- Inspect current Dashboard artifacts and tools.
- Discover actual Terminal/MCP tools and schemas.
- Collect read-only runtime evidence only where authorized.
- Establish baseline compile and record exact evidence.

### Phase B — Root-cause diagnosis
Trace: `CHART SYMBOL → UNIVERSE → SYMBOL READINESS → RUNTIME INITIALIZATION → COORDINATOR/AUTHORITY → REGISTRATION → SNAPSHOT WRITE → SNAPSHOT READ → APPLY → RENDER`.
Also distinguish: `DASHBOARD STATE` vs `ACTUAL SIGNAL EVALUATION`.
Default reproduction target (from supplied BTCUSD/D1 context when applicable): `CHART SYMBOL NOT CONFIGURED`, `NOT EVALUATED` in Dashboard fields, and separate `CHART_GEOMETRY_CHANGED` / E2.6 Retry UI message—do not assume same root cause. Earliest evidenced failure is primary.

### Phase C — Safe Mode and mutation audit
- Audit all reachable broker mutation paths before any Dashboard Tester operation.
- No trading MCP tools.
- Evidence = static reachability + actual runtime evidence; counters alone insufficient.

### Phase D — Implementation and quality cycle
Enforce: `BASELINE COMPILE → SCOPED AUDIT → REPAIR IF NEEDED → REFACTOR ONLY IF JUSTIFIED → REPAIR REGRESSIONS IF NEEDED → FINAL COMPILE → AFFECTED REGRESSION TESTS`.
- Baseline compile before edits; audit diagnostics/relevant paths; fix confirmed defects; refactor only with evidence; repair regressions.
- After any source-affecting final change, compile again.
- Do not repeat unchanged broad audits; do not run two tools back-to-back if both compile same source.
- **Default compile acceptance: 0 errors and 0 warnings.** Stale log or existing EX5 is not proof of fresh build.
- Use `tools/Compile-MT5.ps1` and existing validation harness after inspecting exact local implementations; verify correct MetaEditor installation explicitly.

### Phase E — Controlled Visual Tester
Only after: current MCP tool registry discovery, exact schema inspection, static Safe Mode audit, fresh verified compile, isolated Tester configuration, exact symbol/timeframe/history/data preflight, confirmed Visual mode support, and local Tester agent confirmation.
- Never substitute non-visual Tester results for Visual Dashboard verification.
- No optimization during Visual testing; no live broker operations.
- Do not assume `OnChartEvent` mouse/keyboard interactions are fully reproducible in Strategy Tester.
- Use actual Tester tools/scripts per verified params/schemas; preserve tracked SETs and use isolated temp inputs.

### Phase F — Actual artifacts and verification
Collect real: Tester status/completion evidence, Expert/Tester journals, Dashboard Diagnostics JSON, RunID and source/EX5 identity, Safe Mode counters, Snapshot lifecycle, visual screenshots or equivalent actual rendering evidence, failure traces, final test report.
- Process start/file existence alone is not completion/provenance proof.

### Phase G — Independent review
- `code-reviewer`: exact final code diff (read-only).
- `risk-auditor`: when risk/authority/mutation code changed (read-only).
- `mt5-engineer`: only for a distinct unresolved MQL5/platform issue.
Non-overlapping questions; reconcile all confirmed P0–P3 findings.

### Phase H — Strict completion
Remain `NOT COMPLETE` while any required runtime or visual criterion is blocked. Do not close known P0–P3 defects without verified correction or approved architecture/policy disposition.
Do not claim success merely because compile/unit tests passed, snapshot writing/objects exist, non-visual Tester completed, or an error string disappeared.

## 5. Technical acceptance matrix (future execution)

| # | Requirement |
|---|---|
| 1 | Correct current chart symbol identification |
| 2 | Correct symbol-universe inclusion |
| 3 | Per-symbol runtime readiness |
| 4 | Recovery of pending symbol initialization after dependencies become ready |
| 5 | Idempotent runtime initialization and no duplicate runtime instances |
| 6 | Approved Coordinator/Chart Context behavior |
| 7 | Registration and ACK validation |
| 8 | Complete, correctly scoped Snapshot publication |
| 9 | Correct Snapshot read and generation validation |
| 10 | Correct application of runtime fields |
| 11 | Truthful `NOT EVALUATED`, waiting, unavailable, stale and blocked states |
| 12 | Actual graphical rendering |
| 13 | Dashboard behavior after chart-geometry changes |
| 14 | E2.6 Retry UI separation and safety |
| 15 | Safe Mode static mutation-path coverage |
| 16 | Safe Mode runtime counters |
| 17 | Fresh 0-error/0-warning compile |
| 18 | Relevant regression tests |
| 19 | Visual Tester completion with actual artifacts |
| 20 | Independent code/risk review when relevant |

Do not require a signal to appear merely to prove Dashboard health. If no closed-bar evaluation is due or market data is unavailable, Dashboard must show correct readiness state (no invented score/signal).

## 6. Official references (consult when relevant; cite only if actually opened/read)

Kilo: [Workflows](https://kilo.ai/docs/customize/workflows), [Tools](https://kilo.ai/docs/automate/tools), [MCP](https://kilo.ai/docs/automate/mcp/using-in-kilo-code).
MetaTrader: [Visual Testing](https://www.metatrader5.com/en/terminal/help/algotrading/visualization), [Strategy Testing](https://www.metatrader5.com/en/terminal/help/algotrading/testing), [Testing Features](https://www.metatrader5.com/en/terminal/help/algotrading/testing_features).
MQL5: [SymbolIsSynchronized](https://www.mql5.com/en/docs/marketinformation/symbolissynchronized), [CopyRates](https://www.mql5.com/en/docs/series/copyrates), [OnTimer](https://www.mql5.com/en/docs/event_handlers/ontimer), [OnChartEvent](https://www.mql5.com/en/docs/event_handlers/onchartevent), [ObjectCreate](https://www.mql5.com/en/docs/objects/objectcreate), [ChartRedraw](https://www.mql5.com/en/docs/chart_operations/chartredraw).

## 7. Evidence, status, and reporting

- Distinguish: `VERIFIED`, `OBSERVED`, `INFERRED`, `ASSUMED`, `UNVERIFIED`, `NOT RUN`, `BLOCKED`.
- Use statuses only with evidence: `IMPLEMENTED`, `STATICALLY REVIEWED`, `COMPILE VERIFIED`, `TEST VERIFIED`, `RUNTIME VERIFIED`, `NOT RUN`, `BLOCKED`.
- `RUNTIME VERIFIED` requires actual terminal/tester execution evidence; non-visual completion is not Visual Dashboard proof.
- `COMPILE VERIFIED` requires fresh log + EX5 identity evidence.
- Report in Persian: baseline/preserved changes, root cause/evidence, changes before/after, acceptance matrix, actual Workflow/Skill/Agent/tool invocations (including `INVOKED` / `APPLIED AS COMPONENT INSTRUCTIONS` / `UNAVAILABLE`), sources actually consulted, exact validation commands/results/warnings, unresolved risks/blockers.
- Do not claim Dashboard execution or successful runtime verification from this Workflow definition alone.
- End with final status: `WORKFLOW_READY`, `PARTIALLY_READY`, or `BLOCKED` per preparation/mission context as applicable.
