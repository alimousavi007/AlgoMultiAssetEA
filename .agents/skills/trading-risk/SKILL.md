---
name: trading-risk
description: Risk and execution safety workflow for AlgoMultiAssetEA. Use when changing or reviewing RiskEngine, PortfolioRisk, TradeExecutor, risk sizing, loss limits, position limits, exposure, locks, stops, margin, or execution gates.
argument-hint: Describe the risk/execution change, failure, or scenario to investigate.
---

# AlgoMultiAssetEA Trading Risk Skill

Use this skill with the core `algo-multiasset-ea` project skill.

## Non-negotiable principle

SIGNAL ≠ TRADE AUTHORIZATION

Risk and execution gates must remain authoritative.

Never bypass or weaken:

RiskEngine
→ PortfolioRisk
→ TradeExecutor

Do not allow unsafe or unavailable risk information to become an executable trade.

Default under critical uncertainty:

NO-TRADE

## Safety workflow

TRACE:

Signal
→ RiskEngine
→ PortfolioRisk
→ State / Locks
→ Execution
→ Position Management

Inspect the actual implementation and callers before changing any gate.

Do not infer capability from names, comments, enums, or intended architecture.

## Risk change workflow

BASELINE
→ IDENTIFY RISK AUTHORITY
→ DEFINE FAILURE MODE
→ MINIMAL CHANGE
→ SAFETY REVIEW
→ COMPILE
→ NARROW TEST
→ REPORT

For dynamic risk, verify separately:

- base monetary risk
- stop distance
- volatility adjustment
- drawdown adjustment
- portfolio exposure
- concentration/correlation when actually implemented
- position constraints
- margin
- execution

Risk multipliers must be bounded, interpretable and monotonic.

Never introduce:

- martingale
- uncontrolled averaging-down
- loss-recovery sizing
- implicit leverage escalation
- unbounded retry-based recovery

## Required scenarios

When relevant, reason/test at least:

1. normal trade
2. risk rejection
3. external lock
4. state lock
5. invalid/missing market data
6. invalid symbol/volume
7. invalid SL/TP
8. execution failure/retcode rejection
9. position/exposure limit
10. portfolio concentration

Use only scenarios relevant to the actual change.

## Correlation

Do not claim correlation-aware risk unless the code actually computes and uses it.

Before implementing correlation-aware risk, define:

- return lookback
- update frequency
- missing-data handling
- directional/concentration treatment
- portfolio impact

Test incremental value separately from entry logic.

## Evidence

Distinguish:

VERIFIED / OBSERVED / INFERRED / ASSUMED / UNVERIFIED

A plausible risk-control story is not proof that the runtime path enforces it.

## REPORT

### FINDING
### ROOT CAUSE
### CHANGE
### VERIFICATION
### REMAINING RISK

For risk research, also report exact configuration, acceptance gates and evidence.
