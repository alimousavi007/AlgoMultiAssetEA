---
name: hybrid-strategy-lifecycle
description: Hybrid timeframe roles (Context/Structure/Setup/Entry), setup lifecycle, setup identity, freshness, structural invalidation, revalidation, News/Risk gating, attempts, and execution reconciliation for AlgoMultiAssetEA.
---

# Skill: hybrid-strategy-lifecycle

## Status
APPROVED / UNDECIDED / UNVERIFIED

## Approved Contracts
- Four independent roles; Setup remains independent of Structure.
- News operational failure blocks new entries; position management is separate.
- Retry only after a proven terminal failure; ambiguous execution requires reconciliation.
- Persistence and reconciliation are prerequisites for dependable operational use.
- Freshness thresholds are configurable per symbol and role.
- D-08: minimum durable schema includes separate Setup ID and Attempt ID, volume snapshots, distinct timestamps, broker evidence, and auditable state history.
- D-09: fail-closed behavior and durable intent logging before submission; no broker submission until the intent is durably confirmed.
- For uncertain impact: block the affected symbol/execution scope and escalate to portfolio-wide blocking if portfolio impact cannot be ruled out.
- SINGLE_WRITER is the approved ownership approach.
- EVIDENCE_PENDING remains the evidence status where evidence has not been established.

## Undecided (do not assume)
- Exact four-role timeframe mapping
- Exact Entry trigger and revalidation contract
- Complete closed-bar/live-quote policy by role/profile
- Setup expiry and structural invalidation semantics
- Detailed News policy
- Server-time/UTC basis

## Identity Rules
- Keep Setup opportunity identity distinct from Attempt/Execution identity and broker ticket identifiers.
- Do not declare a specific identity key final just because current code uses it.
- Do not modify identity semantics without an established contract.
- Do not claim restart-safe duplicate prevention without durable persistence and reconciliation.

## Lifecycle Rules
- Keep detected, valid, expired, invalidated, consumed, and rejected states distinct.
- Data unavailable/invalid is not automatically the same fact as structural invalidation. Missing critical evidence must still prevent an unsafe entry.
- Trace the real producer and consumer before claiming any guard is effective.
- Always separate static findings from tested/runtime evidence.
