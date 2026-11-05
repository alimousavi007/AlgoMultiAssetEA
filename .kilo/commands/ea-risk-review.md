---
description: Independent read-only review of execution, risk, authority, and lifecycle safety
---

# EA Risk Review — Read Only

Review the specified diff and affected execution paths, not the entire EA by default.

## 1. Baseline and scope

- Establish exact branch, HEAD, baseline commit, working-tree state, and review diff.
- Separate current-task changes from pre-existing user work.
- If the before/after baseline is missing, state that limitation; do not invent attribution.
- Read `AGENTS.MD`, applicable MQL5 rules, and approved decision records.

## 2. Skills and agents

Load via the Skill tool:
- `algo-multiasset-ea`;
- `trading-risk` for risk/execution;
- `hybrid-strategy-lifecycle` for Setup/Attempt/reconciliation;
- `engineering` for code/API semantics;
- `signal-pipeline-forensics` only for a real signal/rejection trace.

Use `code-reviewer` for a distinct general correctness review and `risk-auditor` for execution/risk-specific review, when available. Both are read-only. Give each a bounded question; do not duplicate the same audit.

## 3. Review path

Trace the actual call graph, not class names or comments. For execution changes, inventory all broker mutation entry points and follow each to the actual API call.

Check only relevant items:
- authority identity, epoch/fencing and stale-owner rejection;
- entry authorization versus position-management authorization;
- risk gates and portfolio scope;
- durable intent and Attempt identity;
- duplicate submission and ambiguous broker outcomes;
- partial fills, retcodes, broker identifiers and reconciliation;
- DB errors, transaction boundaries and fail-closed behavior;
- MQL5 API signatures, return values, event ordering and object lifetime.

Preserve approved invariants. A cached coordinator flag or successful local return is not proof of current authority or broker execution.

## 4. Evidence and findings

For every finding provide:
- ID/severity (`P0`–`P3`);
- confidence (`CONFIRMED`, `CONDITIONAL`, `UNVERIFIED`);
- evidence class (`STATIC` or `RUNTIME`);
- file/function/line;
- triggering condition and reachable call path;
- concrete consequence;
- introduced/pre-existing/unknown;
- smallest correction.

Do not elevate hypothetical concerns into confirmed defects. Do not report a runtime event without logs or execution evidence.

## 5. Research

Use official Kilo documentation for Kilo mechanisms and official MQL5 documentation for platform/API behavior. Use broker-specific official documentation only when the broker contract matters. Third-party sources are secondary.

## 6. Output (Persian)

Findings first, highest severity first. Then list reviewed scope, excluded scope, invariants checked, actual Skills/Agents invoked, sources consulted, and validation limitations.

If none: `NO CONFIRMED DEFECT FOUND IN THE REVIEWED SCOPE`.

Do not edit files, compile, test, launch MT5, use Strategy Tester, mutate DB, trade, commit, or push.
