---
description: End-to-end implementation, lifecycle review, and authorized validation for Hybrid execution-state changes
---

# Hybrid Lifecycle Implement + Review + Validate — Composite Workflow

Use only when the requested change materially affects Hybrid lifecycle semantics: Context/Structure/Setup/Entry roles, freshness, Setup identity or claims, News/Risk revalidation, Attempt creation/submission, Coordinator authority, durable intent, reconciliation, restart recovery, or related persistence.

## 0. Composition contract

Read and apply these component Workflow files in the same Kilo session:
1. `.kilo/commands/ea-implement.md` — baseline, implementation discipline, preservation, and independent-review requirements.
2. `.kilo/commands/hybrid-lifecycle.md` — Hybrid-specific architecture and lifecycle constraints.
3. `.kilo/commands/hybrid-lifecycle-review.md` — independent lifecycle review criteria.
4. `.kilo/commands/ea-risk-review.md` — execution/risk review criteria.
5. `.kilo/commands/mt5-validate.md` — authorization and validation.

Do not try to run these component workflows as nested slash commands. Read their full Markdown instructions and apply them sequentially in this one invocation. Distinguish `APPLIED AS COMPONENT INSTRUCTIONS` from a Workflow that was separately `INVOKED`. Stop with an explicit blocker if any required file is unavailable.

## 1. Baseline and decision boundary

- Read `AGENTS.MD`, `.kilo/rules/core.md`, `.kilo/rules/mql5.md`, relevant approved decision records, and applicable Skills.
- Inspect actual branch, HEAD, complete Git status, and diff before editing. Preserve user changes.
- Define scope and acceptance criteria before implementation.
- Do not change unapproved architecture, timeframe mappings, freshness thresholds, expiry/invalidation rules, risk limits, schema, retry policy, or broker semantics.
- Keep approved, undecided, unknown, and evidence-pending decisions distinct.

## 2. Required lifecycle trace

Trace the actual implementation, not just enum or class declarations:

`SETUP → VALIDATION → PRE-SUBMIT REVALIDATION → DURABLE INTENT → SUBMISSION → BROKER RESPONSE/OBSERVATION → RECONCILIATION → RESOLUTION`

For each transition identify:
- actual owner, producer, consumer, caller, and callee;
- stable identity and state before/after;
- durable evidence and transaction boundary;
- failure, timeout, restart, duplicate, and concurrency behavior;
- whether the next state is actually reachable and enforced.

Preserve these contracts:
- Context, Structure, Setup, and Entry are four independent roles; Setup is independent from Structure.
- News operational failure blocks new entries; position management remains separate.
- A signal, candidate, score, or TradePlan is not execution authorization.
- SetupID, AttemptID, order/deal tickets, and position identifiers remain distinct.
- Durable intent precedes broker submission.
- Ambiguous submission and `RECONCILIATION_REQUIRED` never authorize speculative resubmission.
- Retry requires proven terminal failure.
- Partial fill is not automatically complete.
- Persistence/schema/migration/write uncertainty fails closed.

## 3. Implementation

Apply the implementation requirements from `ea-implement.md` and the Hybrid-specific rules from `hybrid-lifecycle.md`.

Use the minimum relevant Skills through Kilo's Skill tool:
- `algo-multiasset-ea`
- `hybrid-strategy-lifecycle`
- `engineering`
- add `trading-risk` for risk/execution/authority work;
- add `signal-pipeline-forensics` only for an evidenced signal/rejection trace.

Delegate bounded, read-only work:
- `explore` for lifecycle/call-graph discovery;
- `code-reviewer` for general correctness;
- `risk-auditor` for risk/execution/authority/retry/persistence.

Verify Agent IDs and actual invocations. Delegates must not edit. Do not repeat identical audits.

## 4. Independent lifecycle and risk review

After implementation:
- Apply the complete checklist in `hybrid-lifecycle-review.md`.
- Apply `ea-risk-review.md` to execution/risk-sensitive paths.
- Obtain independent `code-reviewer` and, where relevant, `risk-auditor` results.
- Reconcile every P0–P3 finding with source and official MQL5 documentation.
- Correct confirmed defects and review the corrections.
- Do not treat field declarations, compile success, or a passing static invariant as proof of durable runtime enforcement.

## 5. Authorized validation

Apply `mt5-validate.md` without expanding its permission scope.

At minimum, identify the necessary compile and test coverage for the changed lifecycle path. Where authorized, validate persistence, interrupted transitions, restart recovery, duplicate prevention, reconciliation, schema/migration behavior, and regression paths using isolated test data.

Do not launch MT5, run Strategy Tester or MQL5 Scripts, mutate databases, or contact a broker unless the current user request explicitly authorizes that exact operation. Compile permission does not imply these permissions.

## 6. Strict completion gate

- Track every acceptance criterion and P0–P3 finding.
- Fix confirmed issues; rerun tests affected by each correction.
- Do not silently defer known defects or claim completion from static inspection/compile alone.
- Any unresolved architecture or policy choice remains open until explicitly decided under the project's approval process.
- Required-but-unrun runtime, persistence, migration, or restart validation keeps the phase `NOT COMPLETE`.

## 7. Final report (Persian)

Include baseline, preserved user changes, lifecycle call/state trace, approved decisions relied upon, files changed, acceptance matrix, actual Skill/Agent invocations, independent review findings, exact compile/test/runtime evidence, unrun checks, residual blockers, and final evidence-based status.

No commit or push.
