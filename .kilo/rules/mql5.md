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

- `SymbolInfoInteger(symbol, SYMBOL_DIGITS)` for digits (integer property).
- `SymbolInfoDouble(symbol, SYMBOL_POINT)` and `SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE)` for point/tick size.
- `SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)`, `SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX)`, `SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP)` for volume constraints.
- `SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)`, `SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL)`, `SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE)` for integer trading constraints.

Do not assume standard contract sizes, tick values, volume steps, or contract sizes. Use the actual symbol specifications as the source of truth.

## Trade Retcode Discipline

A successful function return or a retcode alone is **not**, by itself, proof that a trade was executed successfully or that the intended full volume was filled.

Always:
- For the Standard Library CTrade, inspect ResultRetcode() and ResultRetcodeDescription() and use documented result accessors.
- For direct OrderSend calls, inspect the actual MqlTradeResult.retcode.
- Distinguish rejection, requote, partial execution, successful order handling, and confirmed deal/position evidence using properties and events actually supported by MQL5 (e.g. OrderGetInteger, DealGetInteger, HistoryOrderSelect, PositionSelect).
- Distinguish TRADE_RETCODE_DONE from partial fills, requotes, rejections, and broker-specific codes.
- Log the retcode and its meaning for every execution attempt. Do not invent API names.

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
