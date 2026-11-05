---
description: Independent read-only trading risk and execution audit
---

Delegate independent review to Risk Auditor and, where useful,
Code Reviewer. Select only relevant Skills.

1. Trace Signal -> RiskEngine -> PortfolioRisk -> TradeExecutor.
2. Inspect data freshness, sizing, SL/TP, limits, and broker
   result handling where relevant.
3. Distinguish signal rejection, risk rejection, and execution failure.
4. Check duplicate execution and ambiguous outcomes.
5. Do not edit files, loosen controls, run tests, or trade.
6. Every finding must include file/function evidence and severity.
7. Report false positives and unresolved evidence gaps explicitly.
8. Return the result in Persian.