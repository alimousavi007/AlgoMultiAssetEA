---
description: Read-only, evidence-backed root-cause investigation
---

# EA Investigate — Read Only

Purpose: establish the earliest supported root cause and the smallest useful next action without changing the workspace.

## 1. Safety and baseline

- Read `AGENTS.MD` and `.kilo/rules/mql5.md`.
- Inspect only relevant source, callers, configuration, logs, and prior decision records.
- Git inspection is observational only. Do not edit, compile, test, launch terminals, mutate DB, trade, or change Git state.

## 2. Skills and delegation

Use the Skill tool for:
- `algo-multiasset-ea` as project context;
- `engineering` for code/control-flow diagnosis;
- `signal-pipeline-forensics` for signal/data/rejection traces;
- add `hybrid-strategy-lifecycle` or `trading-risk` only when directly relevant.

Use `explore` for a bounded read-only trace when available. Do not invoke implementation or tester agents. Record actual invocation status; reading a file is not invocation.

## 3. Trace the failure

Follow the actual path:
`EVENT/INPUT → CONFIGURATION → STATE → CALLER/CALLEE → GATE → SIDE EFFECT/RETURN → LOG`

- Identify the function that emits the symptom and the first condition that can produce it.
- Trace the values and identity keys used at that point.
- Check initialization order, configuration loading, symbol/strategy mapping, stale state, and error propagation when relevant.
- Distinguish terminal/broker facts from EA configuration and local state.
- For a runtime rejection, use logs/trace evidence to identify the earliest executed failure. Without runtime evidence, label the result `STATICALLY IDENTIFIED — NOT OBSERVED`.
- Do not infer that downstream gates ran if an earlier return prevented them.

## 4. Research

When API or platform semantics matter:
1. consult official Kilo/MQL5/MetaTrader/Microsoft documentation relevant to the exact behavior;
2. check version/environment differences;
3. use credible third-party discussions only as secondary corroboration;
4. record uncertainty instead of converting assumptions into facts.

## 5. Stop condition

Stop when the root cause is supported well enough to select a safe next action. Do not expand into a general architecture audit. If evidence is insufficient, list the precise missing observation and stop.

## 6. Output (Persian)

Return:
- `FINDING`
- `ROOT CAUSE`
- `EVIDENCE` (file/function/line, log timestamp, exact values)
- `CONFIRMED / INFERRED / UNKNOWN`
- `ALTERNATIVE EXPLANATIONS`
- `MISSING EVIDENCE`
- `SAFEST NEXT STEP`

No code changes and no generic follow-up audit.
