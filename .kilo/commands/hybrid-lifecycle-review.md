---
description: Independent read-only review of Hybrid setup, attempt, execution, and reconciliation lifecycle
---

# Hybrid Lifecycle Review — Read Only

## 1. Baseline
Establish the exact diff, branch, HEAD, and pre-existing user changes. Read `AGENTS.MD`, `.kilo/rules/mql5.md`, `.agents/skills/algo-multiasset-ea/SKILL.md`, and `.agents/skills/hybrid-strategy-lifecycle/SKILL.md`.

## 2. Invoke relevant resources
Load through Kilo's actual Skill tool:
- `algo-multiasset-ea`;
- `hybrid-strategy-lifecycle`;
- `engineering`;
- `trading-risk` when execution/risk is affected;
- `signal-pipeline-forensics` only when an observed signal/rejection path is in scope.

Use `code-reviewer` for independent correctness and `risk-auditor` for a distinct execution/risk question. Do not duplicate their assignments. Record actual invocation status.

## 3. Trace lifecycle
`SETUP → VALIDATION → PRE-SUBMIT REVALIDATION → DURABLE INTENT → SUBMISSION → BROKER RESPONSE/OBSERVATION → RECONCILIATION → RESOLUTION`

Verify actual producers, consumers, callers, identity keys, state transitions, transaction boundaries, and failure handling. Confirm that fields/enums are consumed, not merely declared.

## 4. Contract checks
- Context, Structure, Setup, and Entry remain independent roles.
- Setup is independent from Structure.
- Preserve approved closed-bar/live-quote role policies; do not invent unapproved mappings or thresholds.
- News operational failure blocks new entries; position management remains separate.
- D-08: distinct Setup/Attempt identities, volume snapshots, timestamps, broker evidence, retcodes, schema/migration, audit history.
- D-09: durable intent before submit; intent without broker evidence does not authorize a new submit.
- D-10: fail closed on missing/inaccessible DB, unsupported schema, interrupted migration, corruption, or failed write/commit.
- D-11: Attempt ID exists before submission and is restart-recoverable.
- `INTENT_DURABLE_NOT_SUBMITTED` can proceed only after fresh revalidation and proof that submission did not occur.
- `SUBMISSION_MAY_HAVE_OCCURRED` and `RECONCILIATION_REQUIRED` must not resubmit.
- Partial fill is not automatically completed.
- Retry only after proven terminal failure.

## 5. Findings
For each finding report severity, confidence, evidence class (`STATIC`/`RUNTIME`), file/function/line, triggering path, consequence, introduced/pre-existing/unknown status, and minimal correction. Do not claim runtime incidents from static code.

## 6. Safety and output
Read-only: no edits, compile, tester, terminal, DB mutation, broker operations, staging, commit, or push. Findings first, then reviewed/excluded scope, invariants checked, actual Skill/Agent usage, sources, and limitations. Use `NO CONFIRMED DEFECT FOUND IN THE REVIEWED SCOPE` only for the scope actually reviewed.
