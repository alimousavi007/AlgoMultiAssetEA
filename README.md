# AlgoMultiAssetEA

Multi-asset algorithmic trading system for MetaTrader 5.

## Overview

AlgoMultiAssetEA is a production-oriented MQL5 expert advisor implementing a hybrid signal architecture with four independent timeframe roles (Context, Structure, Setup, Entry), durable execution ledger, portfolio risk management, and snapshot-driven dashboard.

## Architecture

```
MarketData → Features → Regime → Strategies → SignalEngine → TradeFilters
    → RiskEngine → PortfolioRisk → TradeExecutor → PositionManager
```

### Core Components

- **CHybridSignalEngine** (`Include/AlgoSystem/HybridEngine.mqh`) — Signal generation with multi-timeframe analysis
- **CHybridDashboard** (`Include/AlgoSystem/HybridDashboard.mqh`) — Snapshot-driven chart dashboard
- **CExecutionLedger** (`Include/AlgoSystem/ExecutionLedger.mqh`) — SQLite-backed durable execution log
- **CRiskEngine** (`Include/AlgoSystem/RiskEngine.mqh`) — Account-level risk evaluation
- **CAlgoPortfolioRisk** (`Include/AlgoSystem/PortfolioRisk.mqh`) — Portfolio exposure/concentration limits
- **CTradeExecutor** (`Include/AlgoSystem/TradeExecutor.mqh`) — Trade submission and result interpretation
- **CPositionManager** (`Include/AlgoSystem/PositionManager.mqh`) — Position lifecycle management

### Approved Strategy Contracts

- **D-01**: Four independent timeframe roles — Context, Structure, Setup, Entry
- **D-02**: Setup generation independent of Structure
- **D-03**: News operational failures block new entries (fail-closed)
- **D-04**: Retry only after proven terminal failure
- **D-05**: Durable intent required before submission
- **D-06**: Partial fill ≠ full fill (requested/executed/remaining distinct)
- **D-07**: No auto-close for conflict
- **D-08**: Minimal durable Execution Ledger schema
- **D-09**: Fail-closed submission policy
- **D-10**: Fail-safe recovery for corruption/unsupported schemas
- **D-11**: Durable Attempt ID with database-backed sequence

## Building

Requires MetaEditor 5.0.0.5370+ (AMarkets MetaTrader 5).

```powershell
# Compile EA
.\tools\Compile-MT5.ps1 -Source "Experts\AlgoMultiAssetEA.mq5" -IncludeRoot "Include"

# Run validation harness (compile skipped)
.\tools\AlgoMultiAssetEA-ValidationHarness.ps1 -SkipCompile
```

## Testing

```powershell
# Run validation harness tests
.\tools\ValidationHarness.Tests.ps1
```

## Project Structure

```
MQL5/
├── Experts/
│   └── AlgoMultiAssetEA.mq5          # Main EA entry point
├── Include/
│   └── AlgoSystem/                    # Core library headers
│       ├── HybridEngine.mqh           # Signal engine
│       ├── HybridDashboard.mqh        # Dashboard
│       ├── ExecutionLedger.mqh        # SQLite ledger
│       ├── RiskEngine.mqh             # Risk engine
│       ├── PortfolioRisk.mqh          # Portfolio risk
│       ├── TradeExecutor.mqh          # Trade execution
│       ├── PositionManager.mqh        # Position management
│       └── ... (other modules)
├── Scripts/
│   ├── Tests/                         # Integration tests
│   └── UnitTests/                     # Unit tests
├── tools/
│   ├── Compile-MT5.ps1                # Primary compile script
│   ├── AlgoMultiAssetEA-ValidationHarness.ps1
│   ├── ValidationHarness.Tests.ps1
│   ├── SQLite-TestFixtures.ps1
│   └── AlgoMultiAssetEA-TestOrchestrator.ps1
├── .agents/skills/                    # Kilo agent skills
├── .kilo/                             # Kilo configuration
├── AGENTS.md                          # Project instructions
└── README.md                          # This file
```

## Configuration

Key inputs (see `AlgoMultiAssetEA.mq5` inputs section):

- **Trading Style**: Scalping / Day Trading / Swing Trading
- **Risk Parameters**: Max risk per trade, max daily loss, max positions
- **Dashboard**: View mode, diagnostics, overlay
- **Session Filters**: Trading hours, news avoidance
- **Portfolio Limits**: Correlation, concentration, exposure caps

## Documentation

- `AGENTS.md` — Project instructions and engineering rules
- `.kilo/rules/mql5.md` — MQL5-specific engineering rules
- `.kilo/rules/core.md` — Universal project rules
- `.agents/skills/` — Specialized workflows and skills

## License

Proprietary — Internal use only.