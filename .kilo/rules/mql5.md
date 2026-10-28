# AlgoMultiAssetEA — MQL5 Engineering Rules

These project rules apply when authoring, editing, reviewing or debugging MQL5 code and trading behavior. They are loaded through the `instructions` entry in `kilo.jsonc`; keep this file focused on MQL5 implementation details. Project architecture and approved Hybrid decisions live in the relevant Skills.

## 1. Evidence before API changes

- Inspect the actual declaration, overload, argument types, return value and relevant include before changing an MQL5 call.
- Prefer the official MQL5 Reference linked below. Do not invent API names, enum values, structure fields, retcode meanings or broker guarantees.
- For properties whose retrieval can fail, prefer the Boolean/output-parameter overload where it allows explicit success checking; reset/read `GetLastError()` when useful. Validate returned values as well as the API result.
- Do not infer runtime behavior from a class/function name, comment or intended design. Trace callers and actual conditions.

## 2. Symbol properties, price and volume

Read specifications for the exact symbol being traded; do not assume Forex defaults or reuse `_Symbol` specifications for another managed asset.

- Use `SymbolInfoInteger()` for integer/enum properties such as `SYMBOL_DIGITS`, `SYMBOL_TRADE_STOPS_LEVEL`, `SYMBOL_TRADE_FREEZE_LEVEL`, `SYMBOL_TRADE_MODE`, `SYMBOL_TRADE_EXEMODE`, `SYMBOL_FILLING_MODE` and relevant order permissions.
- Use `SymbolInfoDouble()` for properties such as `SYMBOL_POINT`, `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, `SYMBOL_VOLUME_STEP`, `SYMBOL_VOLUME_LIMIT` and tick-value properties when needed.
- `SYMBOL_POINT`, decimal digits and `SYMBOL_TRADE_TICK_SIZE` are not interchangeable. `NormalizeDouble(price, digits)` controls decimal precision; by itself it does not guarantee that price is aligned to the trade tick size. Apply tick-size-aware price alignment and then validate the result against the symbol's precision and trading rules.
- Respect `SYMBOL_TRADE_STOPS_LEVEL` for minimum stop distances and consider `SYMBOL_TRADE_FREEZE_LEVEL` for modifications/deletions in the relevant context. Do not treat the two as identical or assume a zero value proves every request is legal.
- Validate volume against the actual minimum, maximum, step and direction-specific aggregate `SYMBOL_VOLUME_LIMIT` where applicable. Normalize volume on a valid step and revalidate afterward. For risk-based sizing, round down rather than up; if the minimum tradable volume exceeds the risk budget, reject the trade instead of forcing the minimum.
- Do not assume contract size, tick value, profit currency, margin mode or filling policy. Check available symbol properties and the relevant calculation result.
- Check the result of `SymbolInfoTick()` and quote validity/freshness before using bid/ask. For the latest quote, prefer the tick structure rather than combining unrelated property reads.

## 3. Series, history and indicator buffers

- Check that symbol/timeframe history is selected, synchronized and sufficient before calculating signals. Treat unavailable or stale inputs as readiness failures, not as a valid neutral signal.
- For `CopyRates()`/`CopyBuffer()`, check the return count against the exact requested count. Handle partial/zero copy results and invalid values explicitly.
- Make array indexing/orientation explicit. Verify the relationship between shift, logical series index, copied data and bar timestamp; do not assume the newest bar resides at a particular index without confirming the array setup and copy semantics.
- Ensure indicator handles are valid, wait/check for calculated bars as required, and release handles at the appropriate lifecycle point. Do not repeatedly create indicator handles on every tick without a justified lifecycle design.
- For closed-bar strategy inputs, use the intended completed-bar shift and preserve each input's symbol/timeframe/timestamp provenance. A current forming bar is not a closed bar.
- Avoid look-ahead leakage in tester/research code: no future bar, future event or post-outcome information may affect a prior decision.

## 4. Event model and multi-symbol scheduling

- `OnTick()` is triggered by ticks for the chart symbol of the EA. Do not assume it guarantees an evaluation for every managed symbol.
- Trace how each managed symbol is scheduled (for example, timer/scheduler logic) and how missing ticks, stale quotes, symbol synchronization and terminal workload are handled.
- Keep event handlers bounded. Do not rely on a fixed ordering or one callback per trade request for trade transactions.
- Distinguish server time, bar time, UTC and local machine time. Preserve timestamps with their source/meaning; do not compare mixed clock domains without documented conversion.

## 5. Trade requests, return values and retcodes

- A `true` result from `OrderSend()` means the request passed basic local/structural checks and was accepted for further processing; it does not, by itself, prove the intended trade executed.
- `OrderCheck()` success is a preflight result, not a promise of later execution. The market, margin, permissions and broker response may change before submission or execution.
- For Standard Library `CTrade`, inspect the Boolean method result **and** documented `ResultRetcode()`, `ResultRetcodeDescription()`, order/deal/volume/price accessors as relevant. For direct `OrderSend()`, inspect `MqlTradeResult.retcode` and `retcode_external` where applicable.
- Distinguish completed execution, partial completion, placed/accepted orders, requotes, rejection and ambiguous outcomes using documented constants and actual result fields. Do not use magic numbers or treat a single retcode as universal proof independent of request type.
- For partial execution, compare requested, executed and remaining volumes. Follow the approved project policy; do not mark the entire attempt complete or automatically resubmit the remainder.
- Log enough structured evidence to correlate the attempt, request, retcode, order/deal identifiers, volume and timestamp without leaking secrets. A log message is not a substitute for broker evidence.
- `OnTradeTransaction()` can be called multiple times for a request and transaction arrival order is not guaranteed. Reconcile using the actual transaction type and identifiers; never assume one request equals one event or one callback.
- Do not retry after timeout or ambiguous response. Retry only when terminal failure is proven; otherwise follow the approved execution-ledger reconciliation policy.

## 6. Positions, orders and identity

- Know whether the account uses netting or hedging semantics before designing correlation and position management.
- Distinguish order ticket, deal ticket, `POSITION_TICKET` and `POSITION_IDENTIFIER`; do not treat them as interchangeable. Use documented history/position properties for the relationship required by the task.
- Prefer strong broker identifiers when available. Do not correlate an execution solely by symbol, time proximity, comment or magic number when a stronger identifier exists.
- Require an unambiguous match before assigning a position to an attempt. Zero or multiple matches are unresolved states, not permission to guess.
- Check every `PositionSelect...`, `OrderSelect`/history selection and relevant property retrieval before consuming the selected object's data; selection state can become stale as the account changes.
- Do not make restart-safe or duplicate-prevention claims based only on in-memory flags. Follow the project's durable intent/attempt and reconciliation contract.

## 7. Project risk boundaries

The relevant implementation currently includes:

- `CRiskEngine` — account-level risk evaluation, stop/target validation, volume sizing, margin pre-check and external risk lock.
- `CAlgoPortfolioRisk` — portfolio-level limits/exposure checks. Claim concentration or correlation behavior only to the extent the code demonstrably implements and consumes it.
- `CTradeExecutor` — trade request submission and interpretation of execution results/position correlation.

Preserve the responsibilities and actual call order of these components. The names above do not establish their effective enforcement; trace callers before changing a gate. Never bypass a risk gate or allow unknown critical risk state to become an executable entry.

## 8. Error handling and resource lifecycle

- Check return values for file, indicator, series, symbol-property, history-selection and trade APIs where documented. Record `GetLastError()` when it adds diagnostic value, and reset stale error state before a call if using it to attribute that call's failure.
- Keep resources under a clear lifecycle: create/open in initialization or controlled setup; validate use; release/close on failure and deinitialization as appropriate.
- Avoid swallowed errors, fallback values that look valid, and logs that say “success” before the required evidence exists.
- Do not perform broad exception-like recovery when the safe response should be block-and-diagnose.

## 9. Verification, tester and authorization

- Source review, successful compilation, tester completion, OOS/forward validation and live behavior are different evidence levels. State exactly which occurred.
- Compile, launch MT5, run Strategy Tester/optimization, connect to a broker or execute any live order only when that operation is explicitly authorized for the current task and available tooling permits it.
- For an authorized change, inspect the diff before and after verification and capture actual compiler/test output. A process start, EX5 timestamp or report filename alone is not proof of successful test completion.
- Preserve user changes. Do not run destructive Git commands or commit/push unless separately authorized.

## 10. Official references

Use the version-relevant MQL5 Reference and confirm API details at the point of change:

- [OrderSend](https://www.mql5.com/en/docs/trading/ordersend)
- [OrderCheck](https://www.mql5.com/en/docs/trading/ordercheck)
- [OnTradeTransaction](https://www.mql5.com/en/docs/event_handlers/ontradetransaction)
- [CTrade](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade)
- [SymbolInfoDouble](https://www.mql5.com/en/docs/marketinformation/symbolinfodouble)
- [Symbol properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants)
- [NormalizeDouble](https://www.mql5.com/en/docs/convert/normalizedouble)
- [CopyBuffer](https://www.mql5.com/en/docs/series/copybuffer)
- [CopyRates](https://www.mql5.com/en/docs/series/copyrates)
- [BarsCalculated](https://www.mql5.com/en/docs/series/barscalculated)

If official documentation and observed broker/build behavior seem to differ, capture the exact build/request/result and report the discrepancy; do not generalize a broker-specific observation into an MQL5 guarantee.
