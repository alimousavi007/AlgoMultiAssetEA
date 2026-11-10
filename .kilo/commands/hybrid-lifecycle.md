---
description: Implement or diagnose a scoped Hybrid strategy lifecycle change
---

# Hybrid Lifecycle

Use this workflow only when the task changes Context/Structure/Setup/Entry roles, freshness, Setup identity/lifecycle, News/Risk revalidation, Attempt submission, or reconciliation.

## 1. Load context

Read `AGENTS.MD`, `.kilo/rules/mql5.md`, and the latest approved Hybrid decision records. Invoke Skills through Kilo's Skill tool:
- `algo-multiasset-ea`
- `hybrid-strategy-lifecycle`
- `engineering`
- add `trading-risk` for risk/execution changes;
- add `signal-pipeline-forensics` for observed missing/rejected signal paths.

Use `explore` for read-only producer/consumer tracing. Use `code-reviewer` and `risk-auditor` only for the distinct risks introduced by the patch.

## 2. Preserve decision boundaries

- Context, Structure, Setup, and Entry are four independent roles.
- Setup is not a child of Structure.
- Do not infer timeframe mappings, candle policy, expiry, invalidation, freshness thresholds, or time basis from legacy code.
- Keep `APPROVED`, `UNDECIDED`, `UNKNOWN`, and `EVIDENCE_PENDING` distinct.
- Preserve News operational fail-closed behavior for new entries and separate position management.
- A signal, score, candidate, or TradePlan is not execution authorization.
- Ambiguous broker outcomes require reconciliation; no retry without proven terminal failure.
- Do not claim restart-safe behavior without durable identity and recovery evidence.

## 3. Trace the lifecycle

`SETUP → VALIDATION → PRE-SUBMIT REVALIDATION → DURABLE INTENT → SUBMISSION → BROKER RESPONSE/OBSERVATION → RECONCILIATION → RESOLUTION`

For each transition identify owner, caller, input identity, state before/after, durable evidence, and failure behavior. Trace actual consumers; unused fields/enums/helpers do not satisfy a requirement.

## 4. Acceptance and implementation

Before editing, define observable acceptance criteria including negative cases and exact verification method. Implement only the requested lifecycle scope. Preserve SetupID, AttemptID, broker ticket/deal/position identifiers as distinct identities.

Do not alter schema/arbitration beyond scope; identify E2.7 dependency if required. Do not change authority or execution semantics outside the approved contract.

## 5. Verification and report

Use `/ea-risk-review` for execution/risk-sensitive changes; otherwise use `/ea-implement`'s independent review gate. Use the existing `/hybrid-lifecycle-review` Workflow for independent lifecycle review. For a same-session combined implementation and validation run, use `/hybrid-lifecycle-implement-validate`; that composite reads and applies the component instructions in one invocation.

Compile/test/runtime only when explicitly authorized and safe. Report each criterion `PASSED`, `FAILED`, `NOT RUN`, or `BLOCKED`.

Return in Persian: decision status, lifecycle trace, source evidence, changes, review findings, actual Skill/Agent usage, verification, and remaining unknowns.
