---
name: hybrid-strategy-lifecycle
description: "Analyze or change the AlgoMultiAssetEA Hybrid signal contract: Context/Structure/Setup/Entry roles, freshness, setup expiry/invalidation, pre-submit revalidation, durable attempts, News/Risk gates and broker reconciliation."
---

# Hybrid Strategy Lifecycle Contract

Use with `algo-multiasset-ea`; use `signal-pipeline-forensics` when the question concerns a live trace, missing trade or rejection event.

## Decision status

Keep decisions evidence-labelled: `APPROVED`, `UNDECIDED`, `UNKNOWN`, `EVIDENCE_PENDING`. Current source is implementation evidence, not automatically an approved architecture decision.

## Timeframe roles and data policy

- The design has four independent roles: `Context`, `Structure`, `Setup`, `Entry`. Setup is not a child of Structure.
- Use the approved closed-bar policy for Context/Structure/Setup. Scalping Entry may be driven by tick/live-quote evidence; Day/Swing Entry uses closed-bar evidence.
- Exact role-to-timeframe mapping remains a decision boundary: inspect the latest approved decision record and current configuration; do not revive legacy three-role mappings by assumption.
- Every feature/snapshot used for a decision must preserve symbol, role/timeframe provenance, source timestamp and validity/freshness evidence. A successful data call alone does not prove data is current or aligned to the intended bar.
- If the exact Entry trigger, freshness thresholds or a required profile-specific predicate is not specified, mark it `UNDECIDED`; do not invent values.

## Before any new entry

Revalidate, against current evidence:

1. setup identity, lifecycle state, expiry and structural validity;
2. required inputs and role-specific freshness;
3. News state and configured blackout/cooldown policy;
4. Risk decision and applicable portfolio/execution constraints;
5. current quote, spread, entry distance and stop/target validity as required by the actual implementation;
6. whether the same setup/attempt has already been consumed or submitted.

A candidate, score or `TradePlan` is not broker execution evidence. Trace each gate from producer to consumer before claiming it is effective.

## News semantics

- Operational failure/unavailability blocks new entries (fail-closed).
- Position management is separate from the entry News gate.
- Do not conflate News disabled, provider/service failure, a valid no-event result, active blackout, active cooldown and a passed event.
- Use the current approved policy for event impact, currency mapping, blackout/cooldown boundaries and timestamp source. Unknown details remain unknown.

## Setup identity and lifecycle

- Keep opportunity `setup_id`, submission `attempt_id`, order ticket, deal ticket and position identifier distinct.
- Keep detected, valid, expired, invalidated, consumed and rejected states distinct.
- Data unavailable/invalid does not prove structural invalidation, but missing critical evidence must still prevent unsafe submission.
- Expiry and structural invalidation must be explicit predicates with provenance. Do not infer expiry from an arbitrary age or invalidation from a missing feature.
- Volatile same-session duplicate suppression does not prove restart-safe duplicate prevention.

## Durable execution and recovery decisions

- Storage direction: internal SQLite; ownership: single writer. Do not state SQLite/MQL5 durability semantics as verified unless the exact configuration, transaction and flush behavior are demonstrated.
- Minimum ledger contract (D-08): independent `setup_id` and `attempt_id`; requested/executed/remaining-volume snapshots; distinct created/submitted/broker-response/observed/resolved timestamps; broker identifiers when available; retcode; schema/migration status; auditable state history.
- D-09: fail closed and durably record intent before broker submission. The fact that an intent exists while no broker record is visible does **not** by itself authorize submission.
- D-10: fail safe for missing/inaccessible DB, unsupported schema, interrupted migration, corruption or failed write/commit. Unresolved attempts or broker/ledger disagreement require reconciliation.
- D-11: create Attempt ID before submission and make it restart-recoverable; do not rely on volatile-only identity.
- `INTENT_DURABLE_NOT_SUBMITTED` is the only recovery state that can permit a new submit, and only after fresh revalidation and proof that the prior submit did not occur. `SUBMISSION_MAY_HAVE_OCCURRED` or `RECONCILIATION_REQUIRED` must not resubmit.
- Never automatically complete a partial fill. Account for executed and remaining volume using actual broker evidence and the approved policy.
- A retry is allowed only after a proven terminal failure. Timeout, missing callback, empty ticket or transiently absent position is not proof of terminal failure.
- If impact cannot be bounded, block the affected symbol/execution scope; escalate wider only when portfolio impact cannot be ruled out.

## Time handling

The architecture requires server-time and UTC awareness. Preserve source timestamps and explicit conversion rules. Do not mix local PC time, server time, bar time and UTC without a documented conversion and comparison contract. Unspecified DST, offset or authoritative-clock details remain `UNKNOWN`.

## Required evidence/report

Trace `SETUP → REVALIDATION → INTENT → SUBMISSION → BROKER RESPONSE/OBSERVATION → RESOLUTION`. For each transition report owner/function, durable state before/after, evidence and failure behavior. Distinguish static inspection from compile, tester and live evidence. Never claim safe restart/retry behavior without crash-window and reconciliation evidence.
