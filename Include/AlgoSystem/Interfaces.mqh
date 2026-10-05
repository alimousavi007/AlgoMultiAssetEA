#ifndef __ALGOSYSTEM_INTERFACES_MQH__
#define __ALGOSYSTEM_INTERFACES_MQH__

#include "Types.mqh"

class IMarketDataProvider
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Update(const string symbol,
                       ENUM_TIMEFRAMES timeframe) = 0;

   virtual bool GetSnapshot(const string symbol,
                            ENUM_TIMEFRAMES timeframe,
                            MarketSnapshot &snapshot) = 0;

   virtual bool IsNewClosedBar(const string symbol,
                               ENUM_TIMEFRAMES timeframe) = 0;
  };

class IFeatureEngine
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Calculate(const MarketSnapshot &market,
                          FeatureSet &features) = 0;
  };

class IRegimeEngine
  {
public:
   virtual bool Initialize() = 0;

   virtual ENUM_REGIME_TYPE Detect(const MarketSnapshot &market,
                                   const FeatureSet &features) = 0;
  };

class IStrategy
  {
public:
   virtual bool Initialize() = 0;

   virtual ENUM_STRATEGY_ID Id() const = 0;

   virtual bool Evaluate(const StrategyContext &context,
                          StrategySignal &signal) = 0;
  };

class ISignalEngine
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Evaluate(const StrategySignal &signals[],
                         const int count,
                         StrategySignal &selected_signal) = 0;
  };

class IRiskEngine
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Evaluate(const StrategySignal &signal,
                          RiskDecision &decision) = 0;
  };

class IPortfolioRisk
  {
public:
   virtual bool Initialize() = 0;

   virtual bool CanOpen(const StrategySignal &signal,
                        const RiskDecision &risk) = 0;

   virtual double CurrentRiskPercent() const = 0;
  };

class ITradeExecutor
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Validate(const ExecutionRequest &request) = 0;

   virtual bool Execute(const ExecutionRequest &request,
                        ExecutionResult &result) = 0;
  };

class IPositionManager
  {
public:
   virtual bool Initialize() = 0;

   virtual void Update() = 0;

   virtual bool ManagePositions() = 0;

   virtual bool HasPosition(const string symbol,
                            ENUM_STRATEGY_ID strategy) = 0;
  };

class IStateManager
  {
public:
   virtual bool Initialize() = 0;

   virtual bool Reconstruct() = 0;

   virtual bool GetPortfolioState(PortfolioState &state) = 0;

   virtual bool UpdateAfterTrade(const ExecutionResult &result) = 0;
  };

class ILogger
  {
public:
   virtual void Log(ENUM_LOG_LEVEL level,
                    const string message) = 0;

   virtual void Error(const string message) = 0;

   virtual void Warning(const string message) = 0;

   virtual void Info(const string message) = 0;

   virtual void Signal(const StrategySignal &signal) = 0;

   virtual void Risk(const RiskDecision &decision) = 0;

   virtual void Trade(const ExecutionResult &result) = 0;
  };

#endif