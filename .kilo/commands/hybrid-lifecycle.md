---
description: Continue Hybrid strategy lifecycle work safely
---

Read .agents/skills/hybrid-strategy-lifecycle/SKILL.md directly,
along with the relevant source files and project instructions.

1. Preserve approved decisions and distinguish them from
   UNDECIDED and UNVERIFIED items.
2. Keep Context, Structure, Setup, and Entry conceptually distinct.
3. Do not invent the final timeframe mapping, Entry contract,
   candle policy, expiry rules, freshness thresholds, or time basis.
4. Keep insufficient evidence distinct from confirmed structural
   invalidation.
5. Preserve fail-closed entry gating and separate position management.
6. Do not retry an ambiguous execution without reconciliation.
7. Do not claim restart-safe behavior without durable evidence.
8. Trace actual producers and consumers before changing a guard.
9. Implement only the explicitly requested scope.
10. No compile, tests, runtime, Strategy Tester, broker actions,
    commit, or push without explicit authorization.
11. Report in Persian: decision status, source evidence,
    change or blocker, and remaining unknowns.