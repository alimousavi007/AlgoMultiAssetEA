#property strict
#property version   "1.001"
#property description "Multi-Asset Algorithmic EA: XAU/XAG/BTC | Scalp/Day/Swing | Signal-only by default"

#include "../Include/AlgoSystem/Constants.mqh"
#include "../Include/AlgoSystem/Types.mqh"
#include "../Include/AlgoSystem/Config.mqh"
#include "../Include/AlgoSystem/Utilities.mqh"
#include "../Include/AlgoSystem/MarketData.mqh"
#include "../Include/AlgoSystem/Indicators.mqh"
#include "../Include/AlgoSystem/RegimeEngine.mqh"
#include "../Include/AlgoSystem/TrendStrategy.mqh"
#include "../Include/AlgoSystem/BreakoutStrategy.mqh"
#include "../Include/AlgoSystem/MomentumStrategy.mqh"
#include "../Include/AlgoSystem/MeanReversionStrategy.mqh"
#include "../Include/AlgoSystem/RelativeValueStrategy.mqh"
#include "../Include/AlgoSystem/SignalEngine.mqh"
#include "../Include/AlgoSystem/RiskEngine.mqh"
#include "../Include/AlgoSystem/PortfolioRisk.mqh"
#include "../Include/AlgoSystem/TradeExecutor.mqh"
#include "../Include/AlgoSystem/PositionManager.mqh"
#include "../Include/AlgoSystem/Logger.mqh"
#include "../Include/AlgoSystem/Dashboard.mqh"
#include "../Include/AlgoSystem/Statistics.mqh"
#include "../Include/AlgoSystem/TesterFitness.mqh"
#include "../Include/AlgoSystem/Optimization.mqh"
#include "../Include/AlgoSystem/StateManager.mqh"
#include "../Include/AlgoSystem/SessionFilter.mqh"

//==================================================================
// Inputs
//==================================================================
input group "SYSTEM"
input ENUM_TRADING_PROFILE InpProfile=PROFILE_DAY;
input ENUM_TRADING_MODE    InpMode=MODE_SIGNAL_ONLY;
input bool                 InpLiveAutoConfirm=false;
input bool                 InpDashboard=true;
input ENUM_LOG_LEVEL       InpLogLevel=LOG_INFO;
input bool                 InpLogFile=true;
input bool                 InpLogFlushEachWrite=true;
input int                  InpLogSummarySeconds=60;

input group "SYMBOLS"
input string InpGoldSymbol="XAUUSDb";
input string InpSilverSymbol="XAGUSDb";
input string InpBitcoinSymbol="BTCUSD";

input group "RISK"
input double InpRiskPercent=1.0;
input double InpDailyLossLimit=3.0;
input double InpMonthlyLossLimit=10.0;
input int    InpMaxConsecutiveLosses=3;
input int    InpMaxPositionsTotal=3;
input int    InpMaxPositionsPerSymbol=1;
input int    InpMaxPositionsPerStrategy=1;
input double InpMaxPortfolioRisk=3.0;
input double InpMaxPreciousMetalsRisk=2.0;
input double InpMinRR=1.50;
input double InpMarginSafetyFraction=0.80;

input group "SIGNAL"
input double InpMinimumSignalScore=70.0;
input double InpConflictThreshold=5.0;
input bool   InpEnableMeanReversion=false;
input bool   InpEnableRelativeValue=false;

input group "PROFILE STRATEGY POLICY"
input bool   InpUseProfileSignalScoreOverrides=false;
input bool   InpScalpTrendEnabled=true;
input bool   InpScalpBreakoutEnabled=true;
input bool   InpScalpMomentumEnabled=true;
input bool   InpScalpMeanReversionEnabled=true;
input bool   InpDayTrendEnabled=true;
input bool   InpDayBreakoutEnabled=true;
input bool   InpDayMomentumEnabled=true;
input bool   InpDayMeanReversionEnabled=true;
input bool   InpSwingTrendEnabled=true;
input bool   InpSwingBreakoutEnabled=true;
input bool   InpSwingMomentumEnabled=true;
input bool   InpSwingMeanReversionEnabled=true;
input double InpScalpTrendMinimumScore=70.0;
input double InpScalpBreakoutMinimumScore=70.0;
input double InpScalpMomentumMinimumScore=70.0;
input double InpScalpMeanReversionMinimumScore=70.0;
input double InpDayTrendMinimumScore=70.0;
input double InpDayBreakoutMinimumScore=70.0;
input double InpDayMomentumMinimumScore=70.0;
input double InpDayMeanReversionMinimumScore=70.0;
input double InpSwingTrendMinimumScore=70.0;
input double InpSwingBreakoutMinimumScore=70.0;
input double InpSwingMomentumMinimumScore=70.0;
input double InpSwingMeanReversionMinimumScore=70.0;

input group "FEATURES"
input int InpEMA_Fast=20;
input int InpEMA_Slow=50;
input int InpEMA_Long=200;
input int InpADX_Period=14;
input int InpATR_Period=14;
input int InpRSI_Period=14;
input int InpMACD_Fast=12;
input int InpMACD_Slow=26;
input int InpMACD_Signal=9;
input int InpROC_Period=10;
input int InpVolume_Period=20;

input group "REGIME"
input int    InpADXTrendThreshold=25;
input double InpHighVolatilityRatio=1.50;
input double InpLowVolatilityRatio=0.70;
input int    InpRangeLookback=20;
input double InpRegimeBreakoutBufferATR=0.10;
input double InpRangeWidthATR=4.0;
input double InpTrendEMASepATR=0.25;

input group "BREAKOUT"
input int    InpBreakoutLookback=20;
input double InpBreakoutBufferATR=0.10;
input double InpBreakoutRangeATR=0.80;
input double InpBreakoutVolumeRatio=1.20;
input double InpBreakoutCandleStrength=0.50;
input double InpBreakoutStopATR=1.50;
input double InpBreakoutStructureBufferATR=0.20;
input double InpBreakoutRR=1.50;

input group "SESSION"
input bool InpSessionFilter=true;
input int  InpSessionStartHour=0;
input int  InpSessionEndHour=24;

input group "POSITION MANAGEMENT"
input bool   InpBreakEven=false;
input double InpBreakEvenTriggerR=1.0;
input double InpBreakEvenOffsetPoints=0.0;
input bool   InpTrailing=false;
input ENUM_TIMEFRAMES InpTrailingTF=PERIOD_H1;
input int    InpTrailingATRPeriod=14;
input double InpTrailingATRMultiplier=2.0;
input bool   InpTimeExit=false;
input int    InpMaxHoldingMinutes=240;

input group "EXECUTION"
input ulong InpDeviationPoints=20;

bool ProfileStrategyEnabled(const ENUM_TRADING_PROFILE profile,
                            const ENUM_STRATEGY_ID strategy)
  {
   if(profile==PROFILE_SCALP)
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpScalpTrendEnabled;
      if(strategy==STRATEGY_BREAKOUT) return InpScalpBreakoutEnabled;
      if(strategy==STRATEGY_MOMENTUM) return InpScalpMomentumEnabled;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpScalpMeanReversionEnabled;
     }
   else if(profile==PROFILE_SWING)
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpSwingTrendEnabled;
      if(strategy==STRATEGY_BREAKOUT) return InpSwingBreakoutEnabled;
      if(strategy==STRATEGY_MOMENTUM) return InpSwingMomentumEnabled;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpSwingMeanReversionEnabled;
     }
   else
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpDayTrendEnabled;
      if(strategy==STRATEGY_BREAKOUT) return InpDayBreakoutEnabled;
      if(strategy==STRATEGY_MOMENTUM) return InpDayMomentumEnabled;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpDayMeanReversionEnabled;
     }

   return false;
  }

double ProfileSignalScoreOverride(const ENUM_TRADING_PROFILE profile,
                                  const ENUM_STRATEGY_ID strategy)
  {
   if(profile==PROFILE_SCALP)
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpScalpTrendMinimumScore;
      if(strategy==STRATEGY_BREAKOUT) return InpScalpBreakoutMinimumScore;
      if(strategy==STRATEGY_MOMENTUM) return InpScalpMomentumMinimumScore;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpScalpMeanReversionMinimumScore;
     }
   else if(profile==PROFILE_SWING)
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpSwingTrendMinimumScore;
      if(strategy==STRATEGY_BREAKOUT) return InpSwingBreakoutMinimumScore;
      if(strategy==STRATEGY_MOMENTUM) return InpSwingMomentumMinimumScore;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpSwingMeanReversionMinimumScore;
     }
   else
     {
      if(strategy==STRATEGY_TREND_PULLBACK) return InpDayTrendMinimumScore;
      if(strategy==STRATEGY_BREAKOUT) return InpDayBreakoutMinimumScore;
      if(strategy==STRATEGY_MOMENTUM) return InpDayMomentumMinimumScore;
      if(strategy==STRATEGY_MEAN_REVERSION) return InpDayMeanReversionMinimumScore;
     }

   return -1.0;
  }

double MinimumSignalScoreFor(const ENUM_TRADING_PROFILE profile,
                             const ENUM_STRATEGY_ID strategy)
  {
   if(!InpUseProfileSignalScoreOverrides)
      return InpMinimumSignalScore;

   double score_override=
      ProfileSignalScoreOverride(profile,strategy);
   return (score_override<0.0 ?
           InpMinimumSignalScore :
           score_override);
  }

bool ValidSignalScoreOverride(const double score)
  {
   return score==-1.0 ||
          (score>=0.0 && score<=100.0);
  }

//==================================================================
// Runtime context
//==================================================================
class CSymbolRuntime
  {
public:
   string symbol;
   ENUM_TIMEFRAMES structure_tf;
   ENUM_TIMEFRAMES signal_tf;
   ENUM_TIMEFRAMES entry_tf;

   CMarketDataEngine market_structure;
   CMarketDataEngine market_signal;
   CMarketDataEngine market_entry;

   CFeatureEngine feature_structure;
   CFeatureEngine feature_signal;
   CRegimeEngine  regime_engine;

   CTrendPullbackStrategy trend;
   CBreakoutStrategy      breakout;
   CMomentumStrategy      momentum;
   CMeanReversionStrategy mean_reversion;

   bool valid;
   string last_failure;

   CSymbolRuntime()
     {
      symbol="";
      structure_tf=PERIOD_CURRENT;
      signal_tf=PERIOD_CURRENT;
      entry_tf=PERIOD_CURRENT;
      valid=false;
      last_failure="";
     }

   bool Initialize(const string in_symbol,
                   const ENUM_TIMEFRAMES in_structure_tf,
                   const ENUM_TIMEFRAMES in_signal_tf,
                   const ENUM_TIMEFRAMES in_entry_tf)
     {
      valid=false;
      last_failure="";

      symbol=in_symbol;
      structure_tf=in_structure_tf;
      signal_tf=in_signal_tf;
      entry_tf=in_entry_tf;

      if(symbol=="")
        {
         last_failure="Empty symbol";
         return false;
        }

      if(!market_structure.Initialize() ||
         !market_signal.Initialize() ||
         !market_entry.Initialize())
        {
         last_failure="MarketData.Initialize failed";
         return false;
        }

      feature_structure.SetParameters(
         InpEMA_Fast,
         InpEMA_Slow,
         InpEMA_Long,
         InpADX_Period,
         InpATR_Period,
         InpRSI_Period,
         InpMACD_Fast,
         InpMACD_Slow,
         InpMACD_Signal,
         InpROC_Period,
         InpVolume_Period);

      feature_signal.SetParameters(
         InpEMA_Fast,
         InpEMA_Slow,
         InpEMA_Long,
         InpADX_Period,
         InpATR_Period,
         InpRSI_Period,
         InpMACD_Fast,
         InpMACD_Slow,
         InpMACD_Signal,
         InpROC_Period,
         InpVolume_Period);

      ResetLastError();
      if(!feature_structure.InitializeFor(
            symbol,
            structure_tf))
        {
         last_failure="FeatureStructure.InitializeFor failed LastError="+IntegerToString(GetLastError());
         ResetLastError();
         return false;
        }

      ResetLastError();
      if(!feature_signal.InitializeFor(
            symbol,
            signal_tf))
        {
         last_failure="FeatureSignal.InitializeFor failed LastError="+IntegerToString(GetLastError());
         ResetLastError();
         return false;
        }

      regime_engine.SetParameters(
         InpADXTrendThreshold,
         InpHighVolatilityRatio,
         InpLowVolatilityRatio,
         InpRangeLookback,
         InpRegimeBreakoutBufferATR,
         InpRangeWidthATR,
         InpTrendEMASepATR);

      if(!regime_engine.Initialize())
        {
         last_failure="RegimeEngine.Initialize failed";
         return false;
        }

      trend.SetParameters(
         0.30,
         0.75,
         0.50,
         0.0,
         5.0,
         -5.0,
         0.0,
         50.0,
         70.0,
         30.0,
         50.0,
         1.50,
         0.20,
         InpMinRR,
         MinimumSignalScoreFor(
            InpProfile,
            STRATEGY_TREND_PULLBACK),
         InpADXTrendThreshold);

      breakout.SetParameters(
         InpBreakoutLookback,
         InpBreakoutBufferATR,
         InpRangeWidthATR,
         InpBreakoutRangeATR,
         InpBreakoutVolumeRatio,
         InpBreakoutCandleStrength,
         0.0,
         6.0,
         -6.0,
         0.0,
         InpBreakoutStopATR,
         InpBreakoutStructureBufferATR,
         InpBreakoutRR,
         MinimumSignalScoreFor(
            InpProfile,
            STRATEGY_BREAKOUT));

      if(!trend.Initialize())
        {
         last_failure="TrendStrategy.Initialize failed";
         return false;
        }

      if(!breakout.Initialize())
        {
         last_failure="BreakoutStrategy.Initialize failed";
         return false;
        }

      momentum.SetMinimumSignalScore(
         MinimumSignalScoreFor(
            InpProfile,
            STRATEGY_MOMENTUM));
      if(!momentum.Initialize())
        {
         last_failure="MomentumStrategy.Initialize failed";
         return false;
        }

      mean_reversion.SetMinimumSignalScore(
         MinimumSignalScoreFor(
            InpProfile,
            STRATEGY_MEAN_REVERSION));
      if(!mean_reversion.Initialize())
        {
         last_failure="MeanReversionStrategy.Initialize failed";
         return false;
        }

      // First observations initialize bar state without creating a signal.
      market_entry.IsNewClosedBar(symbol,entry_tf);
      market_signal.IsNewClosedBar(symbol,signal_tf);

      valid=true;
      return true;
     }

  };

//==================================================================
// Globals
//==================================================================
CSymbolRuntime g_runtime[3];

CAlgoStateManager   g_state;
CAlgoPortfolioRisk  g_portfolio_risk;
CRiskEngine         g_risk_engine;
CTradeExecutor      g_executor;
CPositionManager    g_position_manager;
CSignalEngine       g_signal_engine;
CAlgoLogger         g_logger;
CAlgoDashboard      g_dashboard;
CSessionFilter      g_session_filter;
CRelativeValueStrategy g_relative_value;
CTesterFitness      g_tester_fitness;
COptimizationController g_optimizer;

bool g_system_ready=false;
bool g_initialization_started=false;
bool g_initialization_failed=false;
string g_runtime_wait_state[3];
string g_runtime_init_failure[3];
bool g_last_trading_locked=false;
string g_last_runtime_dashboard_status="";

//==================================================================
// Helpers
//==================================================================
void SelectProfileTimeframes(ENUM_TRADING_PROFILE profile,
                             ENUM_TIMEFRAMES &structure_tf,
                             ENUM_TIMEFRAMES &signal_tf,
                             ENUM_TIMEFRAMES &entry_tf)
  {
   if(profile==PROFILE_SCALP)
     {
      structure_tf=PERIOD_M15;
      signal_tf=PERIOD_M5;
      entry_tf=PERIOD_M1;
      return;
     }

   if(profile==PROFILE_SWING)
     {
      structure_tf=PERIOD_D1;
      signal_tf=PERIOD_H4;
      entry_tf=PERIOD_H1;
      return;
     }

   structure_tf=PERIOD_H4;
   signal_tf=PERIOD_H1;
   entry_tf=PERIOD_M15;
  }

bool ValidInputSet()
  {
   if(InpGoldSymbol=="" &&
      InpSilverSymbol=="" &&
      InpBitcoinSymbol=="")
      return false;

   if(!ValidSignalScoreOverride(InpScalpTrendMinimumScore) ||
      !ValidSignalScoreOverride(InpScalpBreakoutMinimumScore) ||
      !ValidSignalScoreOverride(InpScalpMomentumMinimumScore) ||
      !ValidSignalScoreOverride(InpScalpMeanReversionMinimumScore) ||
      !ValidSignalScoreOverride(InpDayTrendMinimumScore) ||
      !ValidSignalScoreOverride(InpDayBreakoutMinimumScore) ||
      !ValidSignalScoreOverride(InpDayMomentumMinimumScore) ||
      !ValidSignalScoreOverride(InpDayMeanReversionMinimumScore) ||
      !ValidSignalScoreOverride(InpSwingTrendMinimumScore) ||
      !ValidSignalScoreOverride(InpSwingBreakoutMinimumScore) ||
      !ValidSignalScoreOverride(InpSwingMomentumMinimumScore) ||
      !ValidSignalScoreOverride(InpSwingMeanReversionMinimumScore))
      return false;

   if(InpRiskPercent<=0.0 ||
      InpDailyLossLimit<=0.0 ||
      InpMonthlyLossLimit<=0.0 ||
      InpMinRR<=0.0)
      return false;

   if(InpEMA_Fast<=0 ||
      InpEMA_Slow<=InpEMA_Fast ||
      InpEMA_Long<=InpEMA_Slow)
      return false;

   if(InpMACD_Fast<=0 ||
      InpMACD_Slow<=InpMACD_Fast ||
      InpMACD_Signal<=0)
      return false;

   if(InpSessionStartHour<0 || InpSessionStartHour>23 ||
      InpSessionEndHour<0 || InpSessionEndHour>24)
      return false;

   return true;
  }

long MagicForStrategy(const ENUM_STRATEGY_ID strategy)
  {
   if(strategy==STRATEGY_TREND_PULLBACK) return MAGIC_TREND;
   if(strategy==STRATEGY_BREAKOUT) return MAGIC_BREAKOUT;
   if(strategy==STRATEGY_MOMENTUM) return MAGIC_MOMENTUM;
   if(strategy==STRATEGY_MEAN_REVERSION) return MAGIC_MEAN_REVERSION;
   if(strategy==STRATEGY_RELATIVE_VALUE) return MAGIC_RELATIVE_VALUE;
   return MAGIC_BASE;
  }

bool StructureCompatible(const ENUM_STRATEGY_ID strategy,
                         const ENUM_REGIME_TYPE signal_regime,
                         const ENUM_REGIME_TYPE structure_regime)
  {
   if(signal_regime==REGIME_UNCERTAIN ||
      structure_regime==REGIME_UNCERTAIN)
      return false;

   if(strategy==STRATEGY_TREND_PULLBACK)
     {
      if(signal_regime==REGIME_TREND_UP)
         return structure_regime==REGIME_TREND_UP ||
                structure_regime==REGIME_BREAKOUT;

      if(signal_regime==REGIME_TREND_DOWN)
         return structure_regime==REGIME_TREND_DOWN ||
                structure_regime==REGIME_BREAKOUT;
     }

   if(strategy==STRATEGY_BREAKOUT)
     {
      return structure_regime==REGIME_BREAKOUT ||
             structure_regime==REGIME_TREND_UP ||
             structure_regime==REGIME_TREND_DOWN;
     }

   if(strategy==STRATEGY_MOMENTUM)
     {
      if(signal_regime==REGIME_TREND_UP)
         return structure_regime==REGIME_TREND_UP ||
                structure_regime==REGIME_BREAKOUT;

      if(signal_regime==REGIME_TREND_DOWN)
         return structure_regime==REGIME_TREND_DOWN ||
                structure_regime==REGIME_BREAKOUT;

      if(signal_regime==REGIME_BREAKOUT)
         return structure_regime!=REGIME_RANGE;
     }

   if(strategy==STRATEGY_MEAN_REVERSION)
      return structure_regime==REGIME_RANGE ||
             structure_regime==REGIME_LOW_VOLATILITY;

   return false;
  }

bool NormalizeSignalStopsToTick(StrategySignal &signal,
                               string &reason)
  {
   reason="";

   if(!signal.valid ||
      (signal.direction!=SIGNAL_LONG &&
       signal.direction!=SIGNAL_SHORT))
     {
      reason="Invalid signal direction";
      return false;
     }

   double tick_size=
      SymbolInfoDouble(
         signal.symbol,
         SYMBOL_TRADE_TICK_SIZE);
   long digits=0;

   if(tick_size<=0.0 ||
      !SymbolInfoInteger(signal.symbol,SYMBOL_DIGITS,digits))
     {
      reason="Symbol tick size or digits unavailable";
      return false;
     }

   bool stop_round_up=
      (signal.direction==SIGNAL_SHORT);
   bool target_round_up=
      (signal.direction==SIGNAL_LONG);

   double stop=
      CAlgoUtils::NormalizePriceToTick(
         signal.stop,
         tick_size,
         stop_round_up,
         (int)digits);
   double target=
      CAlgoUtils::NormalizePriceToTick(
         signal.target,
         tick_size,
         target_round_up,
         (int)digits);

   if(stop<=0.0 ||
      target<=0.0 ||
      (signal.direction==SIGNAL_LONG &&
       (stop>=signal.entry || target<=signal.entry)) ||
      (signal.direction==SIGNAL_SHORT &&
       (stop<=signal.entry || target>=signal.entry)))
     {
      reason="Tick normalization invalidated stop/target levels";
      return false;
     }

   signal.stop=stop;
   signal.target=target;
   return true;
  }

bool BuildExecutionRequest(const StrategySignal &signal,
                           const RiskDecision &risk,
                           ExecutionRequest &request)
  {
   request.intent=
      signal.direction==SIGNAL_LONG ?
      ORDER_INTENT_OPEN_LONG :
      ORDER_INTENT_OPEN_SHORT;

   request.symbol=signal.symbol;
   request.direction=signal.direction;
   request.strategy=signal.strategy;

   request.volume=risk.calculated_volume;
   request.price=signal.entry;

   request.stop_loss=signal.stop;
   request.take_profit=signal.target;

   request.position_ticket=0;
   request.magic=MagicForStrategy(signal.strategy);

   request.comment="AlgoMultiAssetEA";
   request.signal_id=signal.signal_id;

   return true;
  }

void LogReject(const string symbol,const string reason)
  {
   g_logger.Log(LOG_DEBUG,
                 "Rejected symbol="+symbol+
                 " reason="+reason);
  }

void LogInitSuccess(const string stage,
                     const string detail="")
  {
   g_logger.Event(
      LOG_INFO,
      "INIT",
      "INIT_STAGE_OK",
      "",
      "",
      stage,
      "",
      "OK",
      "",
      detail);
  }

void LogInitFailureEvent(const string stage,
                         const string detail="")
  {
   int err=GetLastError();
   g_logger.Event(
      LOG_ERROR,
      "INIT",
      "INIT_FAILED",
      "",
      "",
      stage,
      "",
      "FAIL",
      "INIT",
      detail,
      err);
   ResetLastError();
  }

void LogRiskLockTransition(const PortfolioState &state)
  {
   if(state.trading_locked==g_last_trading_locked)
      return;

   g_last_trading_locked=state.trading_locked;

   g_logger.Event(
      state.trading_locked ? LOG_WARNING : LOG_INFO,
      "STATE",
      state.trading_locked ?
         "TRADING_LOCK_ON" :
         "TRADING_LOCK_OFF",
      "",
      "",
      "",
      "",
      state.trading_locked ? "LOCKED" : "UNLOCKED",
      state.trading_locked ? "RISK_LOCK" : "RISK_LOCK_CLEARED",
      "daily="+DoubleToString(state.daily_loss_percent,2)+
      " monthly="+DoubleToString(state.monthly_loss_percent,2)+
      " consecutive="+IntegerToString(state.consecutive_losses),
      0,
      0,
      state.daily_loss_percent,
      state.monthly_loss_percent,
      (double)state.consecutive_losses);
  }

void UpdateDashboardForChart()
  {
   if(!g_system_ready || !InpDashboard)
      return;

   g_last_runtime_dashboard_status="";
   string chart_symbol=ChartSymbol(0);

   for(int i=0;i<3;i++)
     {
      if(!g_runtime[i].valid ||
         g_runtime[i].symbol!=chart_symbol)
         continue;

      MarketSnapshot market;
      ResetLastError();

      if(!g_runtime[i].market_signal.GetSnapshot(
            g_runtime[i].symbol,
            g_runtime[i].signal_tf,
            market))
        {
         g_dashboard.ShowStatus(
            "WAITING FOR MARKET DATA | "+chart_symbol);
         ResetLastError();
         return;
        }

      FeatureSet features;
      ResetLastError();

      if(!g_runtime[i].feature_signal.Calculate(
            market,
            features))
        {
         g_dashboard.ShowStatus(
            "WAITING FOR INDICATOR DATA | "+chart_symbol);
         ResetLastError();
         return;
        }

      ENUM_REGIME_TYPE regime=
         g_runtime[i].regime_engine.Detect(
            market,
            features);

      PortfolioState portfolio;
      if(!g_state.GetPortfolioState(portfolio))
        {
         g_dashboard.ShowStatus(
            "RISK STATE UNAVAILABLE | ENTRY BLOCKED");
         return;
        }

      g_dashboard.UpdateMarket(
         market,
         features,
         regime,
         portfolio);

      return;
     }

   g_dashboard.ShowStatus(
      "CHART SYMBOL NOT CONFIGURED | "+chart_symbol);
  }

void ShowRuntimeGateStatus(CSymbolRuntime &runtime,
                           const string status)
  {
   if(!InpDashboard ||
      runtime.symbol!=ChartSymbol(0))
      return;

   string signal_tf=EnumToString(runtime.signal_tf);
   string entry_tf=EnumToString(runtime.entry_tf);
   StringReplace(signal_tf,"PERIOD_","");
   StringReplace(entry_tf,"PERIOD_","");

   string dashboard_status=
      status+
      " | "+signal_tf+"/"+entry_tf;

   if(dashboard_status==g_last_runtime_dashboard_status)
      return;

   g_last_runtime_dashboard_status=dashboard_status;
   g_dashboard.ShowStatus(dashboard_status);
  }

bool PrepareRuntimeAnalysis(CSymbolRuntime &runtime,
                           MarketSnapshot &signal_market,
                           MarketSnapshot &structure_market,
                           FeatureSet &signal_features,
                           FeatureSet &structure_features,
                           ENUM_REGIME_TYPE &signal_regime,
                           ENUM_REGIME_TYPE &structure_regime)
  {
   ResetLastError();
   if(!runtime.market_signal.GetSnapshot(
         runtime.symbol,
         runtime.signal_tf,
         signal_market))
     {
      g_logger.Event(
         LOG_ERROR,"MARKET","MARKET_SNAPSHOT_FAILED",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","FAIL",
         "SIGNAL_SNAPSHOT","Market signal snapshot failed",GetLastError());
      ResetLastError();
      return false;
     }

   ResetLastError();
   if(!runtime.market_structure.GetSnapshot(
         runtime.symbol,
         runtime.structure_tf,
         structure_market))
     {
      g_logger.Event(
         LOG_ERROR,"MARKET","MARKET_SNAPSHOT_FAILED",
         runtime.symbol,EnumToString(runtime.structure_tf),"","","FAIL",
         "STRUCTURE_SNAPSHOT","Market structure snapshot failed",GetLastError());
      ResetLastError();
      return false;
     }

   ResetLastError();
   if(!runtime.feature_signal.Calculate(
         signal_market,
         signal_features))
     {
      g_logger.Event(
         LOG_ERROR,"FEATURE","FEATURE_CALC_FAILED",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","FAIL",
         "SIGNAL_FEATURES","Signal feature calculation failed",GetLastError());
      ResetLastError();
      return false;
     }

   ResetLastError();
   if(!runtime.feature_structure.Calculate(
         structure_market,
         structure_features))
     {
      g_logger.Event(
         LOG_ERROR,"FEATURE","FEATURE_CALC_FAILED",
         runtime.symbol,EnumToString(runtime.structure_tf),"","","FAIL",
         "STRUCTURE_FEATURES","Structure feature calculation failed",GetLastError());
      ResetLastError();
      return false;
     }

   signal_regime=
      runtime.regime_engine.Detect(
         signal_market,
         signal_features);

   structure_regime=
      runtime.regime_engine.Detect(
         structure_market,
         structure_features);

   g_logger.Event(
      LOG_DEBUG,"REGIME","REGIME_DETECTED",
      runtime.symbol,EnumToString(runtime.signal_tf),"","","OK",
      "REGIME",
      "signal="+EnumToString(signal_regime)+
      " structure="+EnumToString(structure_regime),
      0,0,
      signal_features.adx,
      signal_features.atr,
      signal_features.rsi);

   return true;
  }

bool BuildRuntimeStrategyContext(CSymbolRuntime &runtime,
                                 const MarketSnapshot &signal_market,
                                 const FeatureSet &signal_features,
                                 const ENUM_REGIME_TYPE signal_regime,
                                 StrategyContext &context,
                                 PortfolioState &portfolio_state)
  {
   context.market=signal_market;
   context.features=signal_features;
   context.regime=signal_regime;
   context.trading_allowed=false;
   context.rejection_reason="";

   if(!g_state.GetPortfolioState(portfolio_state))
     {
      context.rejection_reason="Portfolio risk state unavailable";
      g_logger.Event(
         LOG_ERROR,"RISK","RISK_STATE_UNAVAILABLE",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","REJECT",
         "RISK_STATE","Portfolio state is unavailable; entry blocked");
      ShowRuntimeGateStatus(
         runtime,
         "BLOCKED: RISK STATE UNAVAILABLE");
      return false;
     }

   LogRiskLockTransition(portfolio_state);

   context.trading_allowed=true;
   if(portfolio_state.trading_locked)
     {
      context.trading_allowed=false;
      context.rejection_reason="Risk lock active";

      g_logger.Event(
         LOG_WARNING,"RISK","RISK_LOCK_ACTIVE",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","REJECT",
         "RISK_LOCK","Trading locked by portfolio state");
     }

   return true;
  }

int EvaluateRuntimeStrategies(CSymbolRuntime &runtime,
                              const StrategyContext &context,
                              const ENUM_REGIME_TYPE signal_regime,
                              const ENUM_REGIME_TYPE structure_regime,
                              StrategySignal &candidates[])
  {
   for(int i=0;i<5;i++)
     {
      candidates[i].valid=false;
      candidates[i].direction=SIGNAL_NONE;
     }

   int candidate_count=0;

   if(context.trading_allowed &&
      ProfileStrategyEnabled(
         InpProfile,
         STRATEGY_TREND_PULLBACK) &&
      StructureCompatible(
         STRATEGY_TREND_PULLBACK,
         signal_regime,
         structure_regime))
     {
      StrategySignal signal;
      if(runtime.trend.Evaluate(context,signal) && signal.valid)
        {
         candidates[candidate_count]=signal;
         candidate_count++;
        }
     }

   if(context.trading_allowed &&
      ProfileStrategyEnabled(
         InpProfile,
         STRATEGY_BREAKOUT) &&
      StructureCompatible(
         STRATEGY_BREAKOUT,
         signal_regime,
         structure_regime))
     {
      StrategySignal signal;
      if(runtime.breakout.Evaluate(context,signal) && signal.valid)
        {
         candidates[candidate_count]=signal;
         candidate_count++;
        }
     }

   if(context.trading_allowed &&
      ProfileStrategyEnabled(
         InpProfile,
         STRATEGY_MOMENTUM) &&
      StructureCompatible(
         STRATEGY_MOMENTUM,
         signal_regime,
         structure_regime))
     {
      StrategySignal signal;
      if(runtime.momentum.Evaluate(context,signal) && signal.valid)
        {
         candidates[candidate_count]=signal;
         candidate_count++;
        }
     }

   if(context.trading_allowed &&
      InpEnableMeanReversion &&
      ProfileStrategyEnabled(
         InpProfile,
         STRATEGY_MEAN_REVERSION) &&
      StructureCompatible(
         STRATEGY_MEAN_REVERSION,
         signal_regime,
         structure_regime))
     {
      StrategySignal signal;
      if(runtime.mean_reversion.Evaluate(context,signal) && signal.valid)
        {
         candidates[candidate_count]=signal;
         candidate_count++;
        }
     }

   // Relative Value is multi-leg and is intentionally not converted
   // into the single-leg StrategySignal path.
   if(InpEnableRelativeValue &&
      runtime.symbol==InpGoldSymbol)
     {
      g_relative_value.SetPair(
         InpGoldSymbol,
         InpSilverSymbol);

      if(g_relative_value.Initialize())
        {
         RelativeValueOpportunity rv;
         if(g_relative_value.EvaluatePair(
               runtime.signal_tf,
               rv))
           {
            g_logger.Info(
               "RelativeValue opportunity: "+
               rv.reason+
               " z="+
               DoubleToString(rv.zscore,2)+
               " score="+
               DoubleToString(rv.score,1));
           }
        }
     }

   g_logger.Event(
      LOG_DEBUG,"STRATEGY","STRATEGY_BATCH_EVALUATED",
      runtime.symbol,EnumToString(runtime.signal_tf),"","","OK",
      candidate_count>0 ? "CANDIDATE_FOUND" : "NO_CANDIDATE",
      "candidate_count="+IntegerToString(candidate_count));

   return candidate_count;
  }

void ProcessRuntimeCandidates(CSymbolRuntime &runtime,
                              const StrategySignal &candidates[],
                              const int candidate_count,
                              const MarketSnapshot &signal_market,
                              const FeatureSet &signal_features,
                              const ENUM_REGIME_TYPE signal_regime,
                              const PortfolioState &portfolio_state)
  {
   StrategySignal selected_signal;
   selected_signal.valid=false;

   if(candidate_count<=0)
     {
      g_logger.Event(
         LOG_DEBUG,"SIGNAL","SIGNAL_NOT_GENERATED",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","NOOP",
         "NO_CANDIDATE","No strategy candidate qualified");

      RiskDecision empty_risk;
      empty_risk.decision=RISK_UNDEFINED;
      g_dashboard.Update(
         signal_market,
         signal_features,
         signal_regime,
         selected_signal,
         empty_risk,
         portfolio_state);
      return;
     }

   StrategySignal normalized_candidates[5];
   int normalized_count=0;
   for(int i=0;i<candidate_count;i++)
     {
      StrategySignal candidate=candidates[i];
      string normalization_failure="";

      if(!NormalizeSignalStopsToTick(
            candidate,
            normalization_failure))
        {
         g_logger.Event(
            LOG_WARNING,"SIGNAL","SIGNAL_LEVELS_REJECTED",
            candidate.symbol,
            EnumToString(candidate.timeframe),
            EnumToString(candidate.strategy),
            candidate.signal_id,
            "REJECT","INVALID_TICK_LEVELS",
            normalization_failure);
         continue;
        }

      normalized_candidates[normalized_count]=candidate;
      normalized_count++;
     }

   if(normalized_count<=0)
     {
      RiskDecision empty_risk;
      empty_risk.decision=RISK_UNDEFINED;
      g_dashboard.Update(
         signal_market,
         signal_features,
         signal_regime,
         selected_signal,
         empty_risk,
         portfolio_state);
      return;
     }

   ResetLastError();
   if(!g_signal_engine.Evaluate(
         normalized_candidates,
         normalized_count,
         selected_signal))
     {
      g_logger.Event(
         LOG_ERROR,"SIGNAL","SIGNAL_ENGINE_FAILED",
         runtime.symbol,EnumToString(runtime.signal_tf),"","","FAIL",
         "SIGNAL_ENGINE","Signal arbitration failed",GetLastError());
      ResetLastError();

      RiskDecision empty_risk;
      empty_risk.decision=RISK_UNDEFINED;
      g_dashboard.Update(
         signal_market,
         signal_features,
         signal_regime,
         selected_signal,
         empty_risk,
         portfolio_state);
      return;
     }

   g_logger.Signal(selected_signal);

   RiskDecision risk;

   if(!g_risk_engine.Evaluate(
         selected_signal,
         risk))
     {
      g_logger.Risk(risk);
      g_dashboard.Update(
         signal_market,
         signal_features,
         signal_regime,
         selected_signal,
         risk,
         portfolio_state);
      return;
     }

   if(!g_portfolio_risk.CanOpen(
         selected_signal,
         risk))
     {
      risk.decision=RISK_REJECTED;
      risk.rejection_reason=REJECT_PORTFOLIO_RISK;
      risk.reason=
         g_portfolio_risk.LastRejectionReason();

      g_logger.Event(
         LOG_WARNING,"PORTFOLIO","PORTFOLIO_REJECTED",
         selected_signal.symbol,
         EnumToString(selected_signal.timeframe),
         EnumToString(selected_signal.strategy),
         selected_signal.signal_id,
         "REJECT",
         g_portfolio_risk.LastRejectionCode(),
         g_portfolio_risk.LastRejectionReason(),
         0,0,
         risk.risk_percent,
         g_portfolio_risk.CurrentRiskPercent(),
         portfolio_state.total_positions);

      g_logger.Risk(risk);
      g_dashboard.Update(
         signal_market,
         signal_features,
         signal_regime,
         selected_signal,
         risk,
         portfolio_state);
      return;
     }

   g_logger.Risk(risk);

   g_dashboard.Update(
      signal_market,
      signal_features,
      signal_regime,
      selected_signal,
      risk,
      portfolio_state);

   bool execute=false;

   if(InpMode==MODE_AUTO)
      execute=true;

   if(InpMode==MODE_BACKTEST &&
      MQLInfoInteger(MQL_TESTER))
      execute=true;

   if(!execute)
     {
      g_logger.Event(
         LOG_DEBUG,"EXECUTION","EXECUTION_SKIPPED",
         selected_signal.symbol,EnumToString(selected_signal.timeframe),
         EnumToString(selected_signal.strategy),selected_signal.signal_id,
         "NOOP","SIGNAL_ONLY","Execution disabled by mode");
      return;
     }

   ExecutionRequest request;
   BuildExecutionRequest(
      selected_signal,
      risk,
      request);

   g_logger.Event(
      LOG_INFO,"EXECUTION","EXECUTION_SUBMITTED",
      request.symbol,EnumToString(selected_signal.timeframe),
      EnumToString(request.strategy),request.signal_id,
      "SUBMIT","EXECUTION_READY","Order execution request ready",
      0,0,request.volume,request.stop_loss,request.take_profit);

   ExecutionResult result;

   if(!g_executor.Execute(
         request,
         result))
     {
      g_logger.Trade(result);
      return;
     }

   g_logger.Trade(result);
   if(!g_state.UpdateAfterTrade(result))
      g_logger.Event(
         LOG_ERROR,"STATE","STATE_RECONSTRUCT_FAILED",
         selected_signal.symbol,
         EnumToString(selected_signal.timeframe),
         EnumToString(selected_signal.strategy),
         selected_signal.signal_id,
         "FAIL","HISTORY_OR_ACCOUNT_STATE",
         "Post-trade state reconstruction failed; new entries blocked");
  }

void ProcessRuntime(CSymbolRuntime &runtime)
  {
   if(!runtime.valid || !g_system_ready)
      return;

   if(!g_session_filter.IsAllowed(TimeCurrent()))
     {
      ShowRuntimeGateStatus(runtime,"BLOCKED: SESSION FILTER");
      return;
     }

   // Execution evaluation is synchronized to entry bars first,
   // then to a new signal bar. This prevents repeated evaluation.
   if(!runtime.market_entry.IsNewClosedBar(
         runtime.symbol,
         runtime.entry_tf))
     {
      ShowRuntimeGateStatus(
         runtime,
         "WAITING: ENTRY BAR");
      return;
     }

   if(!runtime.market_signal.IsNewClosedBar(
         runtime.symbol,
         runtime.signal_tf))
     {
      ShowRuntimeGateStatus(
         runtime,
         "WAITING: SIGNAL BAR");
      return;
     }

   MarketSnapshot signal_market;
   MarketSnapshot structure_market;
   FeatureSet signal_features;
   FeatureSet structure_features;
   ENUM_REGIME_TYPE signal_regime;
   ENUM_REGIME_TYPE structure_regime;

   if(!PrepareRuntimeAnalysis(
         runtime,
         signal_market,
         structure_market,
         signal_features,
         structure_features,
         signal_regime,
         structure_regime))
      return;

   StrategyContext context;
   PortfolioState portfolio_state;
   if(!BuildRuntimeStrategyContext(
      runtime,
      signal_market,
      signal_features,
      signal_regime,
      context,
      portfolio_state))
      return;

   StrategySignal candidates[5];
   int candidate_count=
      EvaluateRuntimeStrategies(
         runtime,
         context,
         signal_regime,
         structure_regime,
         candidates);

   ProcessRuntimeCandidates(
      runtime,
      candidates,
      candidate_count,
      signal_market,
      signal_features,
      signal_regime,
      portfolio_state);
  }

//==================================================================
// Initialization diagnostics
//==================================================================
void InitFailure(const string stage,const string detail="")
  {
   int err=GetLastError();
   g_logger.Event(
      LOG_ERROR,
      "INIT",
      "INIT_FAILED",
      "",
      "",
      stage,
      "",
      "FAIL",
      "INIT",
      detail,
      err);
   ResetLastError();
  }

bool ValidateConfiguredSymbol(const string role,const string symbol)
  {
   if(symbol=="")
     {
      g_logger.Event(
         LOG_INFO,"INIT","INIT_SYMBOL_DISABLED",
         "","",role,"","SKIP","SYMBOL_DISABLED","No symbol configured");
      return true;
     }

   bool custom=false;
   ResetLastError();
   if(!SymbolExist(symbol,custom))
     {
      return true;
     }

   ResetLastError();
   if(!SymbolSelect(symbol,true))
     {
      return true;
     }

   g_logger.Event(
      LOG_INFO,"INIT","INIT_SYMBOL_SELECTED",
      symbol,"",role,"","OK","SYMBOL_SELECTED",
      "Configured symbol is selected; synchronization is checked asynchronously");
   return true;
  }

enum ENUM_SYSTEM_INIT_STATUS
  {
   SYSTEM_INIT_FAILED=-1,
   SYSTEM_INIT_WAITING=0,
   SYSTEM_INIT_READY=1
  };

int InitializePendingRuntimes()
  {
   string symbols[3];
   symbols[0]=InpGoldSymbol;
   symbols[1]=InpSilverSymbol;
   symbols[2]=InpBitcoinSymbol;

   string roles[3];
   roles[0]="GOLD";
   roles[1]="SILVER";
   roles[2]="BITCOIN";

   ENUM_TIMEFRAMES structure_tf;
   ENUM_TIMEFRAMES signal_tf;
   ENUM_TIMEFRAMES entry_tf;
   SelectProfileTimeframes(
      InpProfile,
      structure_tf,
      signal_tf,
      entry_tf);

   ENUM_TIMEFRAMES timeframes[3];
   timeframes[0]=structure_tf;
   timeframes[1]=signal_tf;
   timeframes[2]=entry_tf;

   bool tester_single_symbol=
      (MQLInfoInteger(MQL_TESTER)!=0);
   int runtime_count=0;

   for(int i=0;i<ArraySize(symbols);i++)
     {
      if(symbols[i]=="")
         continue;

      if(tester_single_symbol &&
         symbols[i]!=_Symbol)
        {
         if(g_runtime_wait_state[i]!="TESTER_SKIPPED")
           {
            g_logger.Event(
               LOG_INFO,"INIT","INIT_TESTER_SYMBOL_SKIPPED",
               symbols[i],"",roles[i],"","SKIP",
               "TESTER_SINGLE_SYMBOL",
               "Tester evaluates the chart symbol only");
            g_runtime_wait_state[i]="TESTER_SKIPPED";
           }
         continue;
        }

      bool custom_symbol=false;
      if(!SymbolExist(symbols[i],custom_symbol))
        {
         if(g_runtime_wait_state[i]!="SYMBOL_MISSING")
           {
            g_runtime_wait_state[i]="SYMBOL_MISSING";
            g_logger.Event(
               LOG_WARNING,"INIT","INIT_SYMBOL_UNAVAILABLE",
               symbols[i],"",roles[i],"","SKIP",
               "SYMBOL_MISSING",
               "Configured symbol is unavailable; other symbols remain active");
           }
         continue;
        }

      ResetLastError();
      if(!SymbolSelect(symbols[i],true))
        {
         int select_error=GetLastError();
         string select_state=
            "SYMBOL_SELECT_FAILED_"+IntegerToString(select_error);
         if(g_runtime_wait_state[i]!=select_state)
           {
            g_runtime_wait_state[i]=select_state;
            g_logger.Event(
               LOG_WARNING,"INIT","INIT_SYMBOL_UNAVAILABLE",
               symbols[i],"",roles[i],"","WAIT",
               "SYMBOL_SELECT",
               "Unable to select configured symbol; other symbols remain active",
               select_error);
           }
         ResetLastError();
         continue;
        }

      if(g_runtime[i].valid)
        {
         runtime_count++;
         continue;
        }

      if(!SymbolIsSynchronized(symbols[i]))
        {
         string request_details="";
         for(int timeframe_index=0;
             timeframe_index<ArraySize(timeframes);
             timeframe_index++)
           {
            MqlRates rates[1];
            ResetLastError();
            int copied=CopyRates(
               symbols[i],
               timeframes[timeframe_index],
               0,
               1,
               rates);
            int request_error=GetLastError();

            if(copied!=1)
              {
               if(request_details!="")
                  request_details+=", ";

               request_details+=
                  EnumToString(timeframes[timeframe_index])+
                  " copied="+IntegerToString(copied)+
                  " error="+IntegerToString(request_error);
              }
           }

         string wait_state=request_details;
         if(wait_state=="")
            wait_state="history requests accepted";

         if(wait_state!=g_runtime_wait_state[i])
           {
            g_runtime_wait_state[i]=wait_state;
            g_logger.Event(
               LOG_INFO,"INIT","INIT_SYMBOL_WAITING",
               symbols[i],"",roles[i],"","WAIT",
               "SYMBOL_SYNC",
               "Waiting for this symbol only: "+wait_state);
           }
         continue;
        }

      g_runtime_wait_state[i]="";
      if(!g_runtime[i].Initialize(
            symbols[i],
            structure_tf,
            signal_tf,
            entry_tf))
        {
         string failure=g_runtime[i].last_failure;
         if(failure!=g_runtime_init_failure[i])
           {
            g_runtime_init_failure[i]=failure;
            g_logger.Event(
               LOG_WARNING,"INIT","INIT_RUNTIME_PENDING",
               symbols[i],"",roles[i],"","WAIT",
               "RUNTIME_INIT",
               "Runtime initialization failed; other symbols remain active: "+
               failure,
               GetLastError());
            ResetLastError();
           }
         continue;
        }

      g_runtime_init_failure[i]="";
      runtime_count++;
      g_logger.Event(
         LOG_INFO,"INIT","INIT_RUNTIME_READY",
         symbols[i],"",roles[i],"","READY",
         "RUNTIME_INIT","Symbol runtime initialized");
     }

   return runtime_count;
  }

ENUM_SYSTEM_INIT_STATUS InitializeSystemWhenReady()
  {
   if(g_system_ready)
      return SYSTEM_INIT_READY;

   if(g_initialization_started)
      return SYSTEM_INIT_WAITING;

   g_initialization_started=true;

   g_session_filter.Set(
      InpSessionFilter,
      InpSessionStartHour,
      InpSessionEndHour);

   if(!g_state.Initialize())
     {
      g_initialization_started=false;
      InitFailure(
         "StateManager.Initialize",
         "Risk state reconstruction failed; history or account metrics are unavailable");
      return SYSTEM_INIT_FAILED;
     }

   g_state.ApplyLocks(
      InpDailyLossLimit,
      InpMonthlyLossLimit,
      InpMaxConsecutiveLosses);

   g_risk_engine.SetParameters(
      InpRiskPercent,
      InpMinRR,
      InpMarginSafetyFraction);

   if(!g_risk_engine.Initialize())
     {
      g_initialization_started=false;
      InitFailure("RiskEngine.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   g_portfolio_risk.SetParameters(
      InpMaxPortfolioRisk,
      InpMaxPositionsTotal,
      InpMaxPositionsPerSymbol,
      InpMaxPositionsPerStrategy,
      InpMaxPreciousMetalsRisk,
      InpGoldSymbol,
      InpSilverSymbol);

   if(!g_portfolio_risk.Initialize())
     {
      g_initialization_started=false;
      InitFailure("PortfolioRisk.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   g_executor.SetDeviationPoints(
      InpDeviationPoints);

   if(!g_executor.Initialize())
     {
      g_initialization_started=false;
      InitFailure("TradeExecutor.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   g_position_manager.SetExecutor(
      &g_executor);

   g_position_manager.SetBreakEven(
      InpBreakEven,
      InpBreakEvenTriggerR,
      InpBreakEvenOffsetPoints);

   g_position_manager.SetTrailing(
      InpTrailing,
      InpTrailingTF,
      InpTrailingATRPeriod,
      InpTrailingATRMultiplier);

   g_position_manager.SetTimeExit(
      InpTimeExit,
      InpMaxHoldingMinutes);

   if(!g_position_manager.Initialize())
     {
      g_initialization_started=false;
      InitFailure("PositionManager.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   g_signal_engine.SetParameters(
      InpConflictThreshold,
      0.0);

   if(!g_signal_engine.Initialize())
     {
      g_initialization_started=false;
      InitFailure("SignalEngine.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   int runtime_count=InitializePendingRuntimes();

   if(!g_state.Reconstruct())
     {
      g_initialization_started=false;
      InitFailure(
         "StateManager.Reconstruct",
         "Risk state reconstruction failed; trading remains disabled");
      return SYSTEM_INIT_FAILED;
     }

   g_state.ApplyLocks(
      InpDailyLossLimit,
      InpMonthlyLossLimit,
      InpMaxConsecutiveLosses);

   g_initialization_started=false;
   g_initialization_failed=false;
   g_system_ready=true;

   g_logger.Event(
      LOG_INFO,"SYSTEM","SYSTEM_READY",
      _Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),"","",
      "READY","INIT_COMPLETE",
      "AlgoMultiAssetEA initialized version="+ALGO_SYSTEM_VERSION+
      " mode="+IntegerToString((int)InpMode)+
      " runtimes_ready="+IntegerToString(runtime_count));

   UpdateDashboardForChart();
   return SYSTEM_INIT_READY;
  }

//==================================================================
// OnInit
//==================================================================
int OnInit()
  {
   g_logger.StartRun();
   g_logger.SetMinimumLevel(InpLogLevel);
   g_logger.SetSummaryInterval(InpLogSummarySeconds);
   g_logger.SetFlushEachWrite(InpLogFlushEachWrite);
   g_logger.EnableConsole(true);

   if(InpLogFile)
      g_logger.EnableFile(true);
   else
      g_logger.EnableFile(false);

   g_logger.Event(
      LOG_INFO,"SYSTEM","SYSTEM_START",
      _Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),"","",
      "START","RUN",
      "AlgoMultiAssetEA OnInit started RunID="+g_logger.RunId());

   if(!ValidInputSet())
     {
      InitFailure("ValidInputSet");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpMode==MODE_AUTO &&
      !MQLInfoInteger(MQL_TESTER) &&
      !InpLiveAutoConfirm)
     {
      InitFailure("LiveAutoConfirm","MODE_AUTO requires InpLiveAutoConfirm=true");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpMode==MODE_BACKTEST &&
      !MQLInfoInteger(MQL_TESTER))
     {
      InitFailure("BacktestMode","MODE_BACKTEST requires Strategy Tester");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ValidateConfiguredSymbol("GOLD",InpGoldSymbol))
      return INIT_FAILED;

   if(!ValidateConfiguredSymbol("SILVER",InpSilverSymbol))
      return INIT_FAILED;

   if(!ValidateConfiguredSymbol("BITCOIN",InpBitcoinSymbol))
      return INIT_FAILED;

   g_dashboard.Enable(InpDashboard);

   ResetLastError();
   if(!EventSetTimer(5))
     {
      InitFailure("EventSetTimer","5-second timer setup failed");
      return INIT_FAILED;
     }

   ENUM_SYSTEM_INIT_STATUS init_status=
      InitializeSystemWhenReady();
   if(init_status==SYSTEM_INIT_FAILED)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

//==================================================================
// OnTick
//==================================================================
bool RefreshTradingState()
  {
   if(!g_state.RefreshCurrentMetrics())
      return false;

   g_state.ApplyLocks(
      InpDailyLossLimit,
      InpMonthlyLossLimit,
      InpMaxConsecutiveLosses);

   PortfolioState current_state;
   if(!g_state.GetPortfolioState(current_state))
      return false;

   LogRiskLockTransition(current_state);
   return true;
  }

void OnTick()
  {
   if(!g_system_ready)
      return;

   bool risk_state_ready=RefreshTradingState();

   g_logger.MaybeWriteSummary(false);

   // Position management runs tick-by-tick independently of signal
   // generation.
   g_position_manager.Update();

   if(!risk_state_ready)
      return;

   for(int i=0;i<3;i++)
      ProcessRuntime(g_runtime[i]);
  }

//==================================================================
// OnTimer
//==================================================================
void OnTimer()
  {
   if(!g_system_ready)
     {
      if(g_initialization_failed)
         return;

      ENUM_SYSTEM_INIT_STATUS init_status=
         InitializeSystemWhenReady();
      if(init_status==SYSTEM_INIT_WAITING)
         return;

      if(init_status==SYSTEM_INIT_FAILED)
        {
         g_initialization_failed=true;
         g_initialization_started=false;
         g_dashboard.ShowStatus("SYSTEM INITIALIZATION FAILED");
         return;
        }
     }

   InitializePendingRuntimes();

   bool risk_state_ready=RefreshTradingState();

   // Refresh the chart-bound dashboard independently from signal-bar logic.
   UpdateDashboardForChart();

   // Multi-symbol runtime must not depend on the chart symbol's ticks.
   g_position_manager.Update();

   if(!risk_state_ready)
      return;

   for(int i=0;i<3;i++)
      ProcessRuntime(g_runtime[i]);
  }

//==================================================================
// OnDeinit
//==================================================================
void OnDeinit(const int reason)
  {
   if(g_system_ready)
     {
      g_logger.MaybeWriteSummary(true);
      g_logger.Event(
         LOG_INFO,"SYSTEM","SYSTEM_STOP",
         _Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),"","",
         "STOP","DEINIT",
         "OnDeinit reason="+IntegerToString(reason));
     }

   EventKillTimer();
   g_dashboard.Clear();
   g_logger.Shutdown();
   g_system_ready=false;
  }

//==================================================================
// Strategy Tester custom criterion
//==================================================================
double OnTester()
  {
   return g_tester_fitness.Calculate();
  }

//==================================================================
// Optimization initialization
//==================================================================
int OnTesterInit()
  {
   // Small, controlled optimization surface. Do not expand blindly.
   ParameterSetRange("InpEMA_Fast",true,(double)InpEMA_Fast,10.0,5.0,40.0);
   ParameterSetRange("InpEMA_Slow",true,(double)InpEMA_Slow,30.0,10.0,100.0);
   ParameterSetRange("InpADXTrendThreshold",true,(double)InpADXTrendThreshold,15.0,5.0,35.0);
   ParameterSetRange("InpBreakoutLookback",true,(double)InpBreakoutLookback,10.0,5.0,40.0);

   return INIT_SUCCEEDED;
  }

void OnTesterDeinit()
  {
   // Detailed pass aggregation is intentionally deferred to the
   // explicit WFO/robustness orchestration layer.
  }
