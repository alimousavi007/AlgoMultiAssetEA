# AlgoMultiAssetEA — MQL5 Engineering Rules (Kilo Addendum)

These rules apply when editing, reviewing, debugging, compiling, or testing MQL5 source and related trading implementation in this repository.

They supplement the project-wide instructions in `AGENTS.md`. Do not duplicate rules already stated there.

## Compiler Safety (Detail)

Before changing any function call, inspect the actual declaration:

- Signature
- Argument count
- Argument types (exact MQL5 types)
- Return type
- Overloads

Never guess an MQL5 API. Use the source headers and official documentation only.

## Price/Volume Normalization

Normalize all prices and volumes against the **actual symbol specification** at runtime:

- `SymbolInfoDouble(symbol, SYMBOL_DIGITS)` / `SYMBOL_POINT` / `SYMBOL_TRADE_TICK_SIZE`
- `SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)` / `SYMBOL_VOLUME_MAX` / `SYMBOL_VOLUME_STEP`
- `SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)` / `SYMBOL_TRADE_FREEZE_LEVEL`
- `SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE)`

Do not assume standard contract sizes, tick values, or lot steps.

## Trade Retcode Discipline

A successful function return (`true`/`OrderSend` result) is **not**, by itself, proof that a trade was executed successfully.

Always:
- Capture and inspect the actual `trade.retcode()` / `OrderGetInteger(ORDER_RETCODE)` / `DealGetInteger(DEAL_RETCODE)`
- Distinguish `TRADE_RETCODE_DONE` from partial fills, requotes, rejections, and broker-specific codes
- Log the retcode and its meaning for every execution attempt

## Risk Pipeline Components (Explicit)

The project implements these specific risk/execution classes. Preserve their responsibilities and ordering:

- `CRiskEngine` — account risk, stop/target validation, volume calculation, margin pre-check
- `CPortfolioRisk` — portfolio-level exposure, correlation (when implemented), concentration limits
- `CTradeExecutor` — order submission, retcode handling, position ticket tracking

Never bypass or reorder: `RiskEngine` → `PortfolioRisk` → `TradeExecutor`.

## Research & Optimization Reference

Detailed strategy-design, backtest, optimization, OOS, and robustness rules live in:

`.agents/skills/algo-multiasset-ea/SKILL.md`

For MQL5 source changes related to strategy or risk research, follow that Skill.