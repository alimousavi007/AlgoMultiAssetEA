---
name: engineering
description: Engineering workflows for AlgoMultiAssetEA. Use for bug fixes, compile errors, runtime errors, features, refactors, code reviews, dashboard work, and verification tasks. Keep changes minimal and evidence-based.
argument-hint: Describe the bug, compile/runtime error, feature, refactor, dashboard issue, or review target.
---

# AlgoMultiAssetEA Engineering Skill

Use this skill with the core `algo-multiasset-ea` project skill.

## Global rule

Preserve existing architecture and user changes.

Use the smallest justified change.

Do not patch a symptom until the execution path and failure point are understood.

Stop investigation when the root cause or design requirement is sufficiently proven. Do not search unrelated code.

## BUG FIX

UNDERSTAND
→ TRACE
→ ROOT CAUSE
→ MINIMAL FIX
→ VERIFY
→ REPORT

Determine:

- observed symptom
- expected behavior
- exact failure point
- affected callers/dependencies
- root cause and evidence
- smallest safe fix

If the root cause is not sufficiently proven, do not make a speculative fix.

## COMPILE ERROR

COMPILER OUTPUT
→ PRIMARY ERROR
→ CASCADE ERRORS
→ MINIMAL FIX
→ COMPILE
→ VERIFY

Use actual compiler output.

Fix the earliest/root compile issue first before addressing likely cascade errors.

Success requires actual evidence of compilation. Do not infer success from code inspection.

## RUNTIME ERROR

EVENT
→ EXECUTION PATH
→ LOG SOURCE
→ STATE
→ FAILURE
→ ROOT CAUSE
→ MINIMAL FIX
→ RUNTIME VERIFY

Use Experts/Journal/Strategy Tester evidence when available.

Distinguish:

VERIFIED / OBSERVED / INFERRED / ASSUMED / UNVERIFIED

Do not replace runtime evidence with static reasoning.

## FEATURE

REQUIREMENT
→ EXISTING CAPABILITY
→ IMPACT/DEPENDENCIES
→ MINIMAL DESIGN
→ IMPLEMENT
→ VERIFY

Before adding code, check whether the requested behavior already exists or can be achieved by composing existing modules.

Do not create new abstractions or parameters without a demonstrated need.

## REFACTOR

Goal: behavior-preserving improvement.

Before change, identify:

- existing behavior
- public interfaces/callers
- state/lifecycle dependencies
- expected side effects

After change, verify behavior equivalence as far as the available tests permit.

Do not combine unrelated feature changes with a refactor.

## CODE REVIEW

Read-only unless the user explicitly asks for fixes.

Review priorities:

CRITICAL
HIGH
MEDIUM
LOW

Challenge:

- correctness
- risk-control bypass
- runtime state errors
- multi-symbol scheduling
- stale/invalid data
- duplicate execution
- API/signature misuse
- regression risk

Report findings with exact file/function references and evidence.

Do not modify code, commit, or push during review unless explicitly requested.

## DASHBOARD

Treat the dashboard as a UI consumer.

Inspect:

- OnInit
- OnTick
- OnTimer
- data sources
- rendering
- cache/state
- chart-symbol filtering

Never create fake signal/risk/domain objects merely to refresh UI.

Do not mutate trading logic to solve a dashboard-only problem.

Preserve exact chart-symbol filtering and last real evaluation state.

## VERIFY

After engineering changes:

1. inspect diff
2. inspect likely compile issues
3. compile when tooling permits
4. inspect actual compiler output
5. run the narrowest useful test
6. inspect diff again
7. report only actual evidence

Do not rerun unrelated tests.

## REPORT

### FINDING
### ROOT CAUSE
### CHANGE
### VERIFICATION
### REMAINING RISK

Name exact files/functions changed.
