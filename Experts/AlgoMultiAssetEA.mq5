//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict
#property version   "1.002"
#property description "Multi-Asset Algorithmic EA: Forex | Scalp/Day/Swing | Hybrid Signal Engine | Signal-only by default"

#include "../Include/AlgoSystem/Constants.mqh"
#include "../Include/AlgoSystem/Types.mqh"
#include "../Include/AlgoSystem/Interfaces.mqh"
#include "../Include/AlgoSystem/HybridTypes.mqh"
#include "../Include/AlgoSystem/Config.mqh"
#include "../Include/AlgoSystem/Utilities.mqh"
#include "../Include/AlgoSystem/MarketData.mqh"
#include "../Include/AlgoSystem/Indicators.mqh"
#include "../Include/AlgoSystem/HybridEngine.mqh"
#include "../Include/AlgoSystem/HybridDashboard.mqh"
#include "../Include/AlgoSystem/RiskEngine.mqh"
#include "../Include/AlgoSystem/PortfolioRisk.mqh"
#include "../Include/AlgoSystem/TradeExecutor.mqh"
#include "../Include/AlgoSystem/ExecutionLedger.mqh"
#include "../Include/AlgoSystem/PositionManager.mqh"
#include "../Include/AlgoSystem/Logger.mqh"
#include "../Include/AlgoSystem/Statistics.mqh"
#include "../Include/AlgoSystem/TesterFitness.mqh"
#include "../Include/AlgoSystem/Optimization.mqh"
#include "../Include/AlgoSystem/StateManager.mqh"
#include "../Include/AlgoSystem/SessionFilter.mqh"

//==================================================================
// Inputs — Reorganized into logical groups
//==================================================================
input group "01 — General"
input ENUM_TRADING_STYLE InpTradingStyle=STYLE_DAY_TRADING;
input ENUM_TRADING_MODE  InpMode=MODE_SIGNAL_ONLY;
input bool               InpLiveAutoConfirm=false;
input bool               InpDashboard=true;
input ENUM_LOG_LEVEL     InpLogLevel=LOG_INFO;
input bool               InpLogFile=true;
input bool               InpLogFlushEachWrite=true;
input int                InpLogSummarySeconds=60;

input group "02 — Symbols and Timeframes"
input string InpGoldSymbol="XAUUSDb";
input string InpSilverSymbol="XAGUSDb";
input string InpBitcoinSymbol="BTCUSD";

input group "03 — Hybrid Decision"
input double InpMinRR=1.50;
input double InpMinScore=70.0;
input double InpConflictThreshold=15.0;
input double InpEntryToleranceScalp=5.0;
input double InpEntryToleranceDay=20.0;
input double InpEntryToleranceSwing=50.0;
input bool   InpAllowMeanReversion=false;

input group "04 — Volume Profile"
input int    InpProfileSessionBars=78;
input int    InpProfileRollingBars=156;
input double InpValueAreaPercent=0.68;
input bool   InpProfileEnabled=true;

input group "05 — Liquidity and Structure"
input int    InpSwingLookback=5;
input int    InpEqualTolerancePoints=3;
input int    InpMaxLevelAgeBars=100;
input int    InpSweepConfirmBars=3;

input group "06 — Divergence and Momentum"
input int    InpRSIPeriod=14;
input int    InpMACD_Fast=12;
input int    InpMACD_Slow=26;
input int    InpMACD_Signal=9;
input double InpPivotTolerancePercent=0.02;
input int    InpMaxDivergenceAgeBars=30;
input int    InpMomentumLookback=50;

input group "07 — Regime"
input int    InpADXPeriod=14;
input int    InpADXTrendThreshold=25;
input double InpHighVolatilityRatio=1.50;
input double InpLowVolatilityRatio=0.70;
input int    InpRangeLookback=20;
input int    InpHysteresisBars=3;

input group "08 — News and Event Risk"
input bool   InpNewsEnabled=false;
input bool   InpNewsPreventNewEntries=true;
input int    InpNewsBlackoutMinutesBefore=30;
input int    InpNewsBlackoutMinutesAfter=30;
input int    InpNewsCooldownMinutes=60;
input int    InpNewsImpactThreshold=3;
input bool   InpNewsClosePositions=false;

input group "09 — Risk and Execution"
input double InpRiskPercent=1.0;
input double InpDailyLossLimit=3.0;
input double InpMonthlyLossLimit=10.0;
input int    InpMaxConsecutiveLosses=3;
input int    InpMaxPositionsTotal=3;
input int    InpMaxPositionsPerSymbol=1;
input int    InpMaxPositionsPerStrategy=1;
input double InpMaxPortfolioRisk=3.0;
input double InpMaxPreciousMetalsRisk=2.0;
input double InpMarginSafetyFraction=0.80;
input ulong  InpDeviationPoints=20;

input group "10 — Sessions and Filters"
input bool InpSessionFilter=true;
input int  InpSessionStartHour=0;
input int  InpSessionEndHour=24;
input bool InpUseSpreadFilter=true;
input int  InpMaxSpreadPoints=50;

input group "11 — Dashboard"
input bool InpDashboardCompact=true;
input bool InpDashboardDiagnostics=false;
input bool InpDashboardOverlay=true;

input group "12 — Position Management"
input bool   InpBreakEven=false;
input double InpBreakEvenTriggerR=1.0;
input double InpBreakEvenOffsetPoints=0.0;
input bool   InpTrailing=false;
input ENUM_TIMEFRAMES InpTrailingTF=PERIOD_H1;
input int    InpTrailingATRPeriod=14;
input double InpTrailingATRMultiplier=2.0;
input bool   InpTimeExit=false;
input int    InpMaxHoldingMinutes=240;

input int    InpFreshnessContextSeconds=300;
input int    InpFreshnessStructureSeconds=300;
input int    InpFreshnessSetupSeconds=300;
input int    InpFreshnessEntrySeconds=60;
input string InpFreshnessOverrides="";
#define InpMinimumSignalScore InpMinScore

//==================================================================
// Helpers
//==================================================================
string StyleName(ENUM_TRADING_STYLE style)
  {
   switch(style)
     {
      case STYLE_SCALPING:
         return "SCALPING";
      case STYLE_DAY_TRADING:
         return "DAY TRADING";
      case STYLE_SWING_TRADING:
         return "SWING TRADING";
      default:
         return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeText(ENUM_TIMEFRAMES tf)
  {
   string s=EnumToString(tf);
   StringReplace(s,"PERIOD_","");
   return s;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SelectStyleTimeframes(ENUM_TRADING_STYLE style,
                           ENUM_TIMEFRAMES &context_tf,
                           ENUM_TIMEFRAMES &structure_tf,
                           ENUM_TIMEFRAMES &setup_tf,
                           ENUM_TIMEFRAMES &entry_tf)
   {
    if(style==STYLE_SCALPING)
      {
       context_tf=PERIOD_M15;
       structure_tf=PERIOD_M5;
       setup_tf=PERIOD_M5;
       entry_tf=PERIOD_M1;
       return;
      }

    if(style==STYLE_SWING_TRADING)
      {
       context_tf=PERIOD_D1;
       structure_tf=PERIOD_H4;
       setup_tf=PERIOD_H4;
       entry_tf=PERIOD_H1;
       return;
      }

    context_tf=PERIOD_H4;
    structure_tf=PERIOD_H1;
    setup_tf=PERIOD_H1;
    entry_tf=PERIOD_M15;
   }

//+------------------------------------------------------------------+
//| Resolve per-symbol freshness override                             |
//| Format: "SYM:CONTEXT=sec,STRUCTURE=sec,SETUP=sec,ENTRY=sec;..."   |
//| Returns true if valid (defaults or valid override).               |
//+------------------------------------------------------------------+
bool ResolveFreshnessForSymbol(const string symbol,
                               int &ctx_sec,
                               int &struct_sec,
                               int &setup_sec,
                               int &entry_sec,
                               bool &is_override)
  {
   ctx_sec=InpFreshnessContextSeconds;
   struct_sec=InpFreshnessStructureSeconds;
   setup_sec=InpFreshnessSetupSeconds;
   entry_sec=InpFreshnessEntrySeconds;
   is_override=false;

   if(InpFreshnessOverrides=="")
      return true;

   // find block for symbol
   string blocks[];
   int n=StringSplit(InpFreshnessOverrides, ';', blocks);
   string found_block="";
   int found_count=0;
   for(int i=0;i<n;i++)
     {
      string b=blocks[i];
      // trim
      StringTrimLeft(b);
      StringTrimRight(b);
      if(b=="")
         continue;
      // split symbol and rest at first ':'
      int colon=StringFind(b, ":");
      if(colon<0)
         continue;
      string sym=StringSubstr(b,0,colon);
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym==symbol)
        {
         found_count++;
         found_block=StringSubstr(b,colon+1);
        }
     }
   if(found_count==0)
      return true; // defaults
   if(found_count>1)
      return false; // duplicate override -> fail-closed

   is_override=true;
   // parse role entries
   string entries[];
   int en=StringSplit(found_block, ',', entries);
   bool has_ctx=false, has_struct=false, has_setup=false, has_entry=false;
   for(int i=0;i<en;i++)
     {
      string e=entries[i];
      StringTrimLeft(e);
      StringTrimRight(e);
      if(e=="")
         continue;
      int eq=StringFind(e, "=");
      if(eq<0)
         return false;
      string key=StringSubstr(e,0,eq);
      string val=StringSubstr(e,eq+1);
      StringTrimLeft(key); StringTrimRight(key);
      StringTrimLeft(val); StringTrimRight(val);
      int v=(int)StringToInteger(val);
      if(v<=0)
         return false;
      if(key=="CONTEXT" || key=="C")
        { if(has_ctx) return false; ctx_sec=v; has_ctx=true; }
      else if(key=="STRUCTURE" || key=="S")
        { if(has_struct) return false; struct_sec=v; has_struct=true; }
      else if(key=="SETUP" || key=="U")
        { if(has_setup) return false; setup_sec=v; has_setup=true; }
      else if(key=="ENTRY" || key=="E")
        { if(has_entry) return false; entry_sec=v; has_entry=true; }
      else
        return false; // unknown role
     }
   if(!has_ctx || !has_struct || !has_setup || !has_entry)
      return false; // incomplete
   return true;
  }

  {
   if(InpGoldSymbol=="" &&
      InpSilverSymbol=="" &&
      InpBitcoinSymbol=="")
      return false;

   if(InpRiskPercent<=0.0 ||
      InpDailyLossLimit<=0.0 ||
      InpMonthlyLossLimit<=0.0 ||
      InpMinRR<=0.0)
      return false;

   if(InpMinScore<0.0 || InpMinScore>100.0)
      return false;

   if(InpConflictThreshold<0.0)
      return false;

   if(InpSessionStartHour<0 || InpSessionStartHour>23 ||
      InpSessionEndHour<0 || InpSessionEndHour>24)
      return false;

   if(InpValueAreaPercent<=0.0 || InpValueAreaPercent>=1.0)
      return false;

    if(InpProfileSessionBars<=0 || InpProfileRollingBars<=0)
       return false;

    if(InpFreshnessContextSeconds<=0 ||
       InpFreshnessStructureSeconds<=0 ||
       InpFreshnessSetupSeconds<=0 ||
       InpFreshnessEntrySeconds<=0)
       return false;

    return true;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong MagicForStyle(ENUM_TRADING_STYLE style)
  {
   switch(style)
     {
      case STYLE_SCALPING:
         return MAGIC_HYBRID_SCALP;
      case STYLE_DAY_TRADING:
         return MAGIC_HYBRID_DAY;
      case STYLE_SWING_TRADING:
         return MAGIC_HYBRID_SWING;
      default:
         return MAGIC_BASE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetEntryDistanceTolerance(ENUM_TRADING_STYLE style,
                                 double point)
  {
   switch(style)
     {
      case STYLE_SCALPING:
         return point * InpEntryToleranceScalp;
      case STYLE_DAY_TRADING:
         return point * InpEntryToleranceDay;
      case STYLE_SWING_TRADING:
         return point * InpEntryToleranceSwing;
      default:
         return point * 10.0;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NormalizeTradePlanStops(TradePlan& plan,
                             string& reason)
  {
   reason="";

   if(!plan.valid || plan.entry<=0.0)
     {
      reason="Invalid trade plan or entry";
      return false;
     }

   double tick_size=SymbolInfoDouble(plan.symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size<=0)
      tick_size=SymbolInfoDouble(plan.symbol, SYMBOL_POINT);

   long digits=0;
   if(!SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS, digits))
     {
      reason="Could not read digits";
      return false;
     }

   bool stop_round_up = (plan.direction==SIGNAL_SHORT);
   bool target_round_up = (plan.direction==SIGNAL_LONG);

   double stop=CAlgoUtils::NormalizePriceToTick(
                  plan.stop, tick_size, stop_round_up, (int)digits);
   double target=CAlgoUtils::NormalizePriceToTick(
                    plan.target, tick_size, target_round_up, (int)digits);

   if(stop<=0.0 || target<=0.0)
     {
      reason="Normalized stop/target is invalid";
      return false;
     }

   if(plan.direction==SIGNAL_LONG &&
      (stop>=plan.entry || target<=plan.entry))
     {
      reason="Long stop/target invalid after normalization";
      return false;
     }

   if(plan.direction==SIGNAL_SHORT &&
      (stop<=plan.entry || target>=plan.entry))
     {
      reason="Short stop/target invalid after normalization";
      return false;
     }

   plan.stop=stop;
   plan.target=target;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogInitFailure(const string stage, const string detail="")
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//==================================================================
// Runtime context — Hybrid
//==================================================================
class CSymbolRuntime
  {
public:
   string            symbol;
   ENUM_TRADING_STYLE style;
    ENUM_TIMEFRAMES   context_tf;
    ENUM_TIMEFRAMES   structure_tf;
    ENUM_TIMEFRAMES   setup_tf;
    ENUM_TIMEFRAMES   entry_tf;

    CMarketDataEngine market_context;
    CMarketDataEngine market_structure;
    CMarketDataEngine market_setup;
    CMarketDataEngine market_entry;

    CFeatureEngine    feature_context;
    CFeatureEngine    feature_structure;
    CFeatureEngine    feature_setup;
    CFeatureEngine    feature_entry;

   CHybridSignalEngine hybrid_engine;

   bool              valid;
   string            last_failure;

                     CSymbolRuntime()
     {
      symbol="";
      style=STYLE_DAY_TRADING;
       context_tf=PERIOD_CURRENT;
       structure_tf=PERIOD_CURRENT;
       setup_tf=PERIOD_CURRENT;
       entry_tf=PERIOD_CURRENT;
      valid=false;
      last_failure="";
     }

     bool              Initialize(const string in_symbol,
                     const ENUM_TRADING_STYLE in_style,
                     const ENUM_TIMEFRAMES in_context_tf,
                     const ENUM_TIMEFRAMES in_structure_tf,
                     const ENUM_TIMEFRAMES in_setup_tf,
                     const ENUM_TIMEFRAMES in_entry_tf,
                     const int in_freshness_context,
                     const int in_freshness_structure,
                     const int in_freshness_setup,
                     const int in_freshness_entry)
      {
       valid=false;
       last_failure="";

       symbol=in_symbol;
       style=in_style;
       context_tf=in_context_tf;
       structure_tf=in_structure_tf;
       setup_tf=in_setup_tf;
       entry_tf=in_entry_tf;

       if(symbol=="")
         {
          last_failure="Empty symbol";
          return false;
         }

        if(!market_context.Initialize() ||
           !market_structure.Initialize() ||
           !market_setup.Initialize() ||
           !market_entry.Initialize())
          {
           last_failure="MarketData.Initialize failed";
           return false;
          }

        if(!feature_context.InitializeFor(symbol, context_tf) ||
           !feature_structure.InitializeFor(symbol, structure_tf) ||
           !feature_setup.InitializeFor(symbol, setup_tf) ||
           !feature_entry.InitializeFor(symbol, entry_tf))
          {
           last_failure="FeatureEngine.Initialize failed";
           return false;
          }


       if(!hybrid_engine.Initialize(
             symbol,
             style,
             context_tf,
             structure_tf,
             setup_tf,
             entry_tf))
         {
          last_failure="HybridEngine.Initialize failed";
          return false;
         }

      hybrid_engine.SetVolumeProfileParams(
         InpProfileSessionBars,
         InpProfileRollingBars,
         InpValueAreaPercent);

      hybrid_engine.SetLiquidityParams(
         InpSwingLookback,
         InpEqualTolerancePoints,
         InpMaxLevelAgeBars,
         InpSweepConfirmBars);

      hybrid_engine.SetRegimeParams(
         InpADXPeriod,
         (double)InpADXTrendThreshold,
         InpHighVolatilityRatio,
         InpLowVolatilityRatio,
         InpRangeLookback,
         InpHysteresisBars);

      hybrid_engine.SetDivergenceParams(
         InpRSIPeriod,
         InpMACD_Fast,
         InpMACD_Slow,
         InpMACD_Signal,
         InpPivotTolerancePercent,
         InpMaxDivergenceAgeBars);

      hybrid_engine.SetMomentumParams(
         InpADXPeriod,
         10,
         InpMomentumLookback);

       hybrid_engine.SetNewsParams(
          InpNewsBlackoutMinutesBefore,
          InpNewsBlackoutMinutesAfter,
          InpNewsCooldownMinutes,
          InpNewsImpactThreshold,
          InpNewsPreventNewEntries,
          InpNewsClosePositions);
       hybrid_engine.SetNewsEnabled(InpNewsEnabled);
       hybrid_engine.SetSpreadFilterParams(InpUseSpreadFilter, (double)InpMaxSpreadPoints);


      hybrid_engine.SetBiasParams(2, 50);
      hybrid_engine.SetMinScore(InpMinScore);
      hybrid_engine.SetConflictThreshold(InpConflictThreshold);
       hybrid_engine.SetMinRR(InpMinRR);
       hybrid_engine.SetFreshnessParams(
          in_freshness_context,
          in_freshness_structure,
          in_freshness_setup,
          in_freshness_entry);

       market_entry.IsNewClosedBar(symbol,entry_tf);

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
CTradeExecutor      g_executor;
CExecutionLedger    g_execution_ledger;
CPositionManager    g_position_manager;
CAlgoLogger         g_logger;
CHybridDashboard    g_dashboard;
CSessionFilter      g_session_filter;
CTesterFitness      g_tester_fitness;
COptimizationController g_optimizer;

string g_runtime_wait_state[3];
string g_runtime_init_failure[3];
bool g_system_ready=false;
bool g_initialization_started=false;
bool g_initialization_failed=false;
bool g_last_trading_locked=false;
string g_last_runtime_dashboard_status="";

//==================================================================
// Dashboard helpers
//==================================================================
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

       if(!g_runtime[i].market_context.GetSnapshot(
            g_runtime[i].symbol,
            g_runtime[i].signal_tf,
            market))
        {
         g_dashboard.ShowStatus(
            "WAITING FOR MARKET DATA | "+chart_symbol);
         ResetLastError();
         return;
        }

      g_dashboard.RenderMarketView(market);
      return;
     }

   g_dashboard.ShowStatus(
      "CHART SYMBOL NOT CONFIGURED | "+chart_symbol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ShowRuntimeGateStatus(CSymbolRuntime &runtime,
                           const string status)
  {
   if(!InpDashboard ||
      runtime.symbol!=ChartSymbol(0))
      return;

    string signal_tf=TimeframeText(runtime.setup_tf);
   string entry_tf=TimeframeText(runtime.entry_tf);

   string dashboard_status=
      status+
      " | "+signal_tf+"/"+entry_tf;

   if(dashboard_status==g_last_runtime_dashboard_status)
      return;

   g_last_runtime_dashboard_status=dashboard_status;
   g_dashboard.ShowStatus(dashboard_status);
  }

//==================================================================
// Hybrid decision pipeline
//==================================================================
void ProcessHybridDecision(CSymbolRuntime& runtime,
                           const HybridDecision& decision,
                           const PortfolioState& portfolio_state)
  {
   g_logger.Signal(decision);

   if(decision.status != DECISION_BUY_CANDIDATE &&
      decision.status != DECISION_SELL_CANDIDATE)
     {
      g_dashboard.Update(decision, portfolio_state);

      if(decision.status==DECISION_NEWS_BLOCKED)
        {
         g_logger.Event(
            LOG_INFO, "HYBRID", "DECISION_NEWS_BLOCKED",
            runtime.symbol, "", "",
            "", "NEWS_BLOCKED", decision.main_reason);
        }
      else
         if(decision.status==DECISION_DATA_UNAVAILABLE)
           {
            g_logger.Event(
               LOG_DEBUG, "HYBRID", "DATA_UNAVAILABLE",
               runtime.symbol, "", "",
               "", "NO_DATA", decision.main_reason);
           }
         else
            if(decision.status==DECISION_NO_TRADE)
              {
               g_logger.Event(
                  LOG_DEBUG, "HYBRID", "NO_TRADE",
                  runtime.symbol, "", "",
                  "", "NO_TRADE", decision.main_reason +
                  " | L=" + DoubleToString(decision.long_score,1) +
                  " S=" + DoubleToString(decision.short_score,1));
              }
            else
               if(decision.status==DECISION_CONFLICTED_SIGNAL)
                 {
                  g_logger.Event(
                     LOG_INFO, "HYBRID", "CONFLICTED_SIGNAL",
                     runtime.symbol, "", "",
                     "", "CONFLICT", decision.main_reason +
                     " | L=" + DoubleToString(decision.long_score,1) +
                     " S=" + DoubleToString(decision.short_score,1));
                 }

      return;
     }

   if(!decision.plan.valid)
      return;

   if(decision.plan.symbol != runtime.symbol ||
      decision.plan.style != runtime.style ||
      (decision.plan.direction != SIGNAL_LONG && decision.plan.direction != SIGNAL_SHORT) ||
      decision.plan.setup_id == "" ||
      decision.plan.signal_time <= 0 ||
      decision.plan.entry <= 0.0 ||
      decision.plan.stop <= 0.0 ||
      decision.plan.target <= 0.0)
     {
      g_logger.Event(
         LOG_WARNING, "HYBRID", "INVALID_PLAN", runtime.symbol, "", "",
         decision.plan.setup_id, "REJECT", "INVALID_PLAN",
         "Plan consistency validation failed");
      return;
     }

    if(runtime.hybrid_engine.IsPlanExpired(decision.plan, TimeCurrent()))
      {
       decision.plan.state=SETUP_STATE_EXPIRED;
       g_logger.Event(
          LOG_WARNING, "HYBRID", "PLAN_EXPIRED", runtime.symbol, "", "",
          decision.plan.setup_id, "REJECT", "PLAN_EXPIRED",
          "Setup expired");
       return;
      }

    double struct_price = decision.plan.entry;
    ENUM_STRUCTURAL_EVIDENCE_RESULT struct_res = runtime.hybrid_engine.EvaluateStructuralEvidence(decision.plan, struct_price);
    if(struct_res == EVIDENCE_STRUCTURAL_INVALIDATION_CONFIRMED)
      {
       decision.plan.state=SETUP_STATE_INVALIDATED;
       decision.plan.structural_invalidated=true;
       g_logger.Event(
          LOG_WARNING, "HYBRID", "SETUP_INVALIDATED", runtime.symbol, "", "",
          decision.plan.setup_id, "REJECT", "SETUP_INVALIDATED",
          "Structural invalidation confirmed by evidence");
       return;
      }
    if(struct_res == EVIDENCE_INVALID_PLAN)
      {
       g_logger.Event(
          LOG_WARNING, "HYBRID", "INVALID_PLAN", runtime.symbol, "", "",
          decision.plan.setup_id, "REJECT", "INVALID_PLAN",
          "Plan invalid for structural evidence evaluation");
       return;
      }
if(struct_res != EVIDENCE_SUFFICIENT_NO_INVALIDATION)
        {
         g_logger.Event(
            LOG_WARNING, "HYBRID", "STRUCT_EVIDENCE_BLOCK", runtime.symbol, "", "",
            decision.plan.setup_id, "REJECT", EnumToString(struct_res),
            "Entry blocked by structural evidence: " + EnumToString(struct_res));
         return;
        }

     if(!runtime.hybrid_engine.IsSetupFresh(decision.plan.signal_time))
      {
       decision.plan.state=SETUP_STATE_REJECTED;
       g_logger.Event(
          LOG_WARNING, "HYBRID", "SETUP_STALE", runtime.symbol, "", "",
          decision.plan.setup_id, "REJECT", "STALE_SETUP",
          "Setup freshness revalidation failed");
       return;
      }

    if(runtime.hybrid_engine.IsPlanConsumed(decision.plan) || decision.plan.state==SETUP_STATE_CONSUMED)
      {
       g_logger.Event(
          LOG_DEBUG, "HYBRID", "PLAN_CONSUMED", runtime.symbol, "", "",
          decision.plan.setup_id, "NOOP", "CONSUMED",
          "Plan already consumed");
       return;
      }

   TradePlan normalized_plan = decision.plan;
   string norm_reason="";
   if(!NormalizeTradePlanStops(normalized_plan, norm_reason))
     {
      g_logger.Event(
         LOG_WARNING, "HYBRID", "PLAN_STOP_NORMALIZE_FAILED",
         runtime.symbol, "", "", decision.plan.setup_id,
         "REJECT", "INVALID_STOPS", norm_reason);
      return;
     }

   double entry=normalized_plan.entry;
   double current_price=0;

   MqlTick tick;
   if(!SymbolInfoTick(runtime.symbol, tick))
     {
      g_logger.Event(
         LOG_WARNING, "HYBRID", "TICK_UNAVAILABLE",
         runtime.symbol, "", "", decision.plan.setup_id,
         "REJECT", "NO_TICK", "Could not retrieve current tick");
      return;
     }

   current_price =
      (normalized_plan.direction==SIGNAL_LONG) ? tick.ask : tick.bid;

   double point=runtime.hybrid_engine.GetPoint();
   double max_entry_dist=GetEntryDistanceTolerance(runtime.style, point);

   if(MathAbs(entry - current_price) > max_entry_dist)
     {
      int digits=(int)runtime.market_context.GetSymbolDigits(runtime.symbol);
      g_logger.Event(
         LOG_WARNING, "HYBRID", "ENTRY_TOO_FAR",
         runtime.symbol, "", "", decision.plan.setup_id,
         "REJECT", "ENTRY_DISTANCE",
         "entry=" + DoubleToString(entry, digits) +
         " current=" + DoubleToString(current_price, digits) +
         " max_dist=" + DoubleToString(max_entry_dist, digits));
      return;
     }

   StrategySignal legacy_signal;
   legacy_signal.valid=true;
   legacy_signal.direction=normalized_plan.direction;
   legacy_signal.strategy=STRATEGY_TREND_PULLBACK;
   legacy_signal.symbol=runtime.symbol;
   legacy_signal.timeframe=runtime.context_tf;
   legacy_signal.regime=(ENUM_REGIME_TYPE)decision.regime;
   legacy_signal.score=(normalized_plan.direction==SIGNAL_LONG) ?
                       decision.long_score : decision.short_score;
   legacy_signal.confidence=1.0;
   legacy_signal.entry=normalized_plan.entry;
   legacy_signal.stop=normalized_plan.stop;
   legacy_signal.target=normalized_plan.target;
   legacy_signal.timestamp=normalized_plan.signal_time;
   legacy_signal.signal_id=normalized_plan.setup_id;
   legacy_signal.reason=decision.main_reason;

   g_logger.Signal(legacy_signal);

   RiskDecision risk;

   if(!g_risk_engine.Evaluate(legacy_signal, risk))
     {
      g_logger.Risk(risk);
      g_dashboard.Update(decision, portfolio_state);
      return;
     }

   if(!g_portfolio_risk.CanOpen(legacy_signal, risk))
     {
      risk.decision=RISK_REJECTED;
      risk.rejection_reason=REJECT_PORTFOLIO_RISK;
      risk.reason=g_portfolio_risk.LastRejectionReason();

      g_logger.Event(
         LOG_WARNING, "PORTFOLIO", "PORTFOLIO_REJECTED",
         legacy_signal.symbol,
         "",
         "",
         legacy_signal.signal_id,
         "REJECT",
         g_portfolio_risk.LastRejectionCode(),
         g_portfolio_risk.LastRejectionReason(),
         0, 0,
         (double)risk.risk_percent,
         g_portfolio_risk.CurrentRiskPercent(),
         (double)portfolio_state.total_positions);

      g_logger.Risk(risk);
      g_dashboard.Update(decision, portfolio_state);
      return;
     }

   g_dashboard.Update(decision, portfolio_state);

   bool execute=false;

   if(InpMode==MODE_AUTO)
      execute=true;

   if(InpMode==MODE_BACKTEST &&
      MQLInfoInteger(MQL_TESTER))
      execute=true;

   if(!execute)
     {
      g_logger.Event(
         LOG_DEBUG, "EXECUTION", "EXECUTION_SKIPPED",
         runtime.symbol, "", "",
         legacy_signal.signal_id,
         "NOOP", "SIGNAL_ONLY", "Execution disabled by mode");

      runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
      return;
     }

    ExecutionRequest request;
    request.intent =
       normalized_plan.direction==SIGNAL_LONG ?
       ORDER_INTENT_OPEN_LONG :
       ORDER_INTENT_OPEN_SHORT;
    request.symbol=runtime.symbol;
    request.direction=normalized_plan.direction;
    request.strategy=STRATEGY_TREND_PULLBACK;
    request.volume=risk.calculated_volume;
    request.price=normalized_plan.entry;
    request.stop_loss=normalized_plan.stop;
    request.take_profit=normalized_plan.target;
    request.position_ticket=0;
    request.magic=MagicForStyle(runtime.style);
    request.comment="AlgoMultiAssetEA_Hybrid";
    request.signal_id=normalized_plan.setup_id;
    request.attempt_id = normalized_plan.setup_id + "_" + IntegerToString(TimeCurrent()) + "_" + IntegerToString((int)MathRand());
    
    // Check ledger for blocking unresolved attempts
    string ledger_block = "";
    if(!g_execution_ledger.IsAvailable() || g_execution_ledger.HasBlockingUnresolved(ledger_block))
      {
       g_logger.Event(
          LOG_WARNING, "EXECUTION", "EXECUTION_BLOCKED_LEDGER",
          request.symbol, "", "",
          request.signal_id,
          "REJECT", "LEDGER_BLOCK", ledger_block);
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }
    
    if(g_execution_ledger.HasUnresolvedForSymbol(request.symbol, true))
      {
       g_logger.Event(
          LOG_WARNING, "EXECUTION", "EXECUTION_BLOCKED_UNRESOLVED",
          request.symbol, "", "",
          request.signal_id,
          "REJECT", "UNRESOLVED_ATTEMPT", "Unresolved attempt exists for symbol");
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }
    
    // Create intent in ledger
    ExecutionAttemptRecord attempt_rec;
    attempt_rec.attempt_id = request.attempt_id;
    attempt_rec.setup_id = normalized_plan.setup_id;
    attempt_rec.symbol = request.symbol;
    attempt_rec.magic = request.magic;
    attempt_rec.intent = request.intent;
    attempt_rec.direction = request.direction;
    attempt_rec.requested_volume = request.volume;
    attempt_rec.entry_price = request.price;
    attempt_rec.stop_loss = request.stop_loss;
    attempt_rec.take_profit = request.take_profit;
    
    if(!g_execution_ledger.CreateIntent(attempt_rec))
      {
       g_logger.Event(
          LOG_ERROR, "EXECUTION", "INTENT_CREATE_FAILED",
          request.symbol, "", "",
          request.signal_id,
          "FAIL", "LEDGER_ERROR", "Failed to create intent in ledger");
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }
    
    // Mark submission bound (after all validations passed)
    if(!g_execution_ledger.MarkSubmissionBound(request.attempt_id, "Pre-submit validation passed"))
      {
       g_logger.Event(
          LOG_ERROR, "EXECUTION", "SUBMISSION_BOUND_FAILED",
          request.symbol, "", "",
          request.signal_id,
          "FAIL", "LEDGER_ERROR", "Failed to mark submission bound");
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }
    
    string submit_reason = "";
    if(!g_execution_ledger.CanSubmit(request.attempt_id, submit_reason))
      {
       g_logger.Event(
          LOG_ERROR, "EXECUTION", "SUBMIT_NOT_ALLOWED",
          request.symbol, "", "",
          request.signal_id,
          "FAIL", "LEDGER_ERROR", submit_reason);
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }

    g_logger.Event(
       LOG_INFO, "EXECUTION", "EXECUTION_SUBMITTED",
       request.symbol, "", "",
       request.signal_id,
       "SUBMIT", "EXECUTION_READY", "Order execution request ready",
       0, 0,
       request.volume,
       request.stop_loss,
       request.take_profit);

    // Record submission in ledger
    g_execution_ledger.RecordSubmission(request.attempt_id);

    ExecutionResult result;
    bool execution_ok = g_executor.Execute(request, result);
     g_logger.Trade(result);

    // Record result in ledger
    g_execution_ledger.RecordResult(request.attempt_id, result, "Executor result");

// An executor call consumes this setup even when it fails. Automatic
// retries need an explicit retry policy; do not resubmit the same setup
// on the next entry bar after an ambiguous broker/transport result.
   runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);

    if(!execution_ok || !result.success)
        {
         // If result is ambiguous, ensure reconciliation required
         if(result.reconciliation_required || result.retcode == TRADE_RETCODE_TIMEOUT || 
            result.retcode == TRADE_RETCODE_CONNECTION)
            {
             g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "Ambiguous result after submit");
            }
         return;
        }
    if(!g_state.UpdateAfterTrade(result))
       g_logger.Event(
          LOG_ERROR, "STATE", "STATE_RECONSTRUCT_FAILED",
          runtime.symbol, "", "",
          legacy_signal.signal_id,
          "FAIL", "HISTORY_OR_ACCOUNT_STATE",
          "Post-trade state reconstruction failed; new entries blocked");

    runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessRuntime(CSymbolRuntime& runtime)
  {
   if(!runtime.valid || !g_system_ready)
      return;

   if(!g_session_filter.IsAllowed(TimeCurrent()))
     {
      ShowRuntimeGateStatus(runtime, "BLOCKED: SESSION FILTER");
      return;
     }

   if(!runtime.market_entry.IsNewClosedBar(
         runtime.symbol,
         runtime.entry_tf))
     {
      ShowRuntimeGateStatus(runtime, "WAITING: ENTRY BAR");
      return;
     }

    MarketSnapshot context_market;
    MarketSnapshot structure_market;
    MarketSnapshot setup_market;
    MarketSnapshot entry_market;
    FeatureSet context_features;
    FeatureSet structure_features;
    FeatureSet setup_features;
    FeatureSet entry_features;
   string reason="";

   ResetLastError();
    if(!runtime.market_context.GetSnapshot(
          runtime.symbol,
          runtime.context_tf,
          context_market))
     {
      g_logger.Event(
         LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "SIGNAL_SNAPSHOT",
         "Market signal snapshot failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: SIGNAL DATA");
      return;
     }

   ResetLastError();
   if(!runtime.market_structure.GetSnapshot(
         runtime.symbol,
         runtime.structure_tf,
         structure_market))
     {
      g_logger.Event(
         LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "STRUCTURE_SNAPSHOT",
         "Market structure snapshot failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: STRUCTURE DATA");
      return;
     }

   ResetLastError();
    if(!runtime.market_setup.GetSnapshot(
          runtime.symbol,
          runtime.setup_tf,
          setup_market))
      {
       g_logger.Event(
          LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
          runtime.symbol, "", "",
          "", "FAIL", "SETUP_SNAPSHOT",
          "Market setup snapshot failed", GetLastError());
       ResetLastError();
       ShowRuntimeGateStatus(runtime, "BLOCKED: SETUP DATA");
       return;
      }

    if(!runtime.market_entry.GetSnapshot(
         runtime.symbol,
         runtime.entry_tf,
         entry_market))
     {
      g_logger.Event(
         LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "ENTRY_SNAPSHOT",
         "Market entry snapshot failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: ENTRY DATA");
      return;
     }

   ResetLastError();
    if(!runtime.feature_context.Calculate(context_market, context_features))
     {
      g_logger.Event(
         LOG_ERROR, "FEATURE", "FEATURE_CALC_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "SIGNAL_FEATURES",
         "Signal feature calculation failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: FEATURES");
      return;
     }

   ResetLastError();
   if(!runtime.feature_structure.Calculate(structure_market, structure_features))
     {
      g_logger.Event(
         LOG_ERROR, "FEATURE", "FEATURE_CALC_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "STRUCTURE_FEATURES",
         "Structure feature calculation failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: FEATURES");
      return;
     }
   ResetLastError();
    if(!runtime.feature_setup.Calculate(setup_market, setup_features))
      {
       g_logger.Event(
          LOG_ERROR, "FEATURE", "FEATURE_CALC_FAILED",
          runtime.symbol, "", "",
          "", "FAIL", "SETUP_FEATURES",
          "Setup feature calculation failed", GetLastError());
       ResetLastError();
       ShowRuntimeGateStatus(runtime, "BLOCKED: FEATURES");
       return;
      }
    if(!runtime.feature_entry.Calculate(entry_market, entry_features))
     {
      g_logger.Event(
         LOG_ERROR, "FEATURE", "FEATURE_CALC_FAILED",
         runtime.symbol, "", "",
         "", "FAIL", "ENTRY_FEATURES",
         "Entry feature calculation failed", GetLastError());
      ResetLastError();
      ShowRuntimeGateStatus(runtime, "BLOCKED: FEATURES");
      return;
     }
   if(!runtime.market_context.IsNewClosedBar(
         runtime.symbol,
         runtime.context_tf))
     {
      ShowRuntimeGateStatus(runtime, "WAITING: SIGNAL BAR");
      return;
     }

   PortfolioState portfolio_state;
   if(!g_state.GetPortfolioState(portfolio_state))
     {
      g_logger.Event(
         LOG_ERROR, "RISK", "RISK_STATE_UNAVAILABLE",
         runtime.symbol, "", "",
         "", "REJECT", "RISK_STATE",
         "Portfolio state is unavailable; entry blocked");
      ShowRuntimeGateStatus(runtime, "BLOCKED: RISK STATE UNAVAILABLE");
      return;
     }

   LogRiskLockTransition(portfolio_state);

   if(portfolio_state.trading_locked)
     {
      g_logger.Event(
         LOG_WARNING, "RISK", "RISK_LOCK_ACTIVE",
         runtime.symbol, "", "",
         "", "REJECT", "RISK_LOCK",
         "Trading locked by portfolio state");
      ShowRuntimeGateStatus(runtime, "BLOCKED: RISK LOCK");
      return;
     }

   bool ok=false;
    FeatureContext ctx = runtime.hybrid_engine.BuildFeatureContext(
                            context_market,
                            structure_market,
                            setup_market,
                            entry_market,
                            context_features,
                            structure_features,
                            setup_features,
                            entry_features,
                            portfolio_state,
                            ok);

   if(!ok || !ctx.valid)
     {
      g_logger.Event(
         LOG_WARNING, "HYBRID", "CONTEXT_BUILD_FAILED",
         runtime.symbol, "", "",
         "", "WARN", "CONTEXT_INVALID", ctx.reason);
      ShowRuntimeGateStatus(runtime, "BLOCKED: CONTEXT INVALID");
      return;
     }

   HybridDecision decision = runtime.hybrid_engine.Evaluate(
                                runtime.symbol, ctx, context_market, ok);

   ProcessHybridDecision(runtime, decision, portfolio_state);
  }

//==================================================================
// Initialization
//==================================================================
bool ValidateConfiguredSymbol(const string role,
                              const string symbol)
  {
   if(symbol=="")
     {
      g_logger.Event(
         LOG_INFO, "INIT", "INIT_SYMBOL_DISABLED",
         "", "", role, "",
         "SKIP", "SYMBOL_DISABLED", "No symbol configured");
      return true;
     }

   bool custom=false;
   ResetLastError();
   if(!SymbolExist(symbol, custom))
      return true;

   ResetLastError();
   if(!SymbolSelect(symbol, true))
      return true;

   g_logger.Event(
      LOG_INFO, "INIT", "INIT_SYMBOL_SELECTED",
      symbol, "", role, "",
      "OK", "SYMBOL_SELECTED",
      "Configured symbol is selected; synchronization is checked asynchronously");
   return true;
  }

enum ENUM_SYSTEM_INIT_STATUS
  {
   SYSTEM_INIT_FAILED=-1,
   SYSTEM_INIT_WAITING=0,
   SYSTEM_INIT_READY=1
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

    ENUM_TIMEFRAMES context_tf;
    ENUM_TIMEFRAMES structure_tf;
    ENUM_TIMEFRAMES setup_tf;
    ENUM_TIMEFRAMES entry_tf;
    SelectStyleTimeframes(
       InpTradingStyle,
       context_tf,
       structure_tf,
       setup_tf,
       entry_tf);

    ENUM_TIMEFRAMES timeframes[4];
    timeframes[0]=context_tf;
    timeframes[1]=structure_tf;
    timeframes[2]=setup_tf;
    timeframes[3]=entry_tf;

   bool tester_single_symbol =
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
               LOG_INFO, "INIT", "INIT_TESTER_SYMBOL_SKIPPED",
               symbols[i], "", roles[i], "",
               "SKIP", "TESTER_SINGLE_SYMBOL",
               "Tester evaluates the chart symbol only");
            g_runtime_wait_state[i]="TESTER_SKIPPED";
           }
         continue;
        }

      bool custom_symbol=false;
      if(!SymbolExist(symbols[i], custom_symbol))
        {
         if(g_runtime_wait_state[i]!="SYMBOL_MISSING")
           {
            g_runtime_wait_state[i]="SYMBOL_MISSING";
            g_logger.Event(
               LOG_WARNING, "INIT", "INIT_SYMBOL_UNAVAILABLE",
               symbols[i], "", roles[i], "",
               "SKIP", "SYMBOL_MISSING",
               "Configured symbol is unavailable; other symbols remain active");
           }
         continue;
        }

      ResetLastError();
      if(!SymbolSelect(symbols[i], true))
        {
         int select_error=GetLastError();
         string select_state=
            "SYMBOL_SELECT_FAILED_"+IntegerToString(select_error);
         if(g_runtime_wait_state[i]!=select_state)
           {
            g_runtime_wait_state[i]=select_state;
            g_logger.Event(
               LOG_WARNING, "INIT", "INIT_SYMBOL_UNAVAILABLE",
               symbols[i], "", roles[i], "",
               "WAIT", "SYMBOL_SELECT",
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
                          0, 1,
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
               LOG_INFO, "INIT", "INIT_SYMBOL_WAITING",
               symbols[i], "", roles[i], "",
               "WAIT", "SYMBOL_SYNC",
               "Waiting for this symbol only: "+wait_state);
           }
         continue;
        }

       g_runtime_wait_state[i]="";
        int rt_ctx=0, rt_struct=0, rt_setup=0, rt_entry=0;
        bool rt_override=false;
        if(!ResolveFreshnessForSymbol(symbols[i], rt_ctx, rt_struct, rt_setup, rt_entry, rt_override))
          {
           g_logger.Event(
              LOG_WARNING, "INIT", "INIT_FRESHNESS_INVALID",
              symbols[i], "", roles[i], "",
              "FAIL", "FRESHNESS_CONFIG",
              "Invalid freshness override; new entries blocked");
           continue;
          }
        if(!g_runtime[i].Initialize(
              symbols[i],
              InpTradingStyle,
              context_tf,
              structure_tf,
              setup_tf,
              entry_tf,
              rt_ctx,
              rt_struct,
              rt_setup,
              rt_entry))
        {
         string failure=g_runtime[i].last_failure;
         if(failure!=g_runtime_init_failure[i])
           {
            g_runtime_init_failure[i]=failure;
            g_logger.Event(
               LOG_WARNING, "INIT", "INIT_RUNTIME_PENDING",
               symbols[i], "", roles[i], "",
               "WAIT", "RUNTIME_INIT",
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
         LOG_INFO, "INIT", "INIT_RUNTIME_READY",
         symbols[i], "", roles[i], "",
         "READY", "RUNTIME_INIT", "Symbol runtime initialized");
     }

   return runtime_count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
      LogInitFailure("StateManager.Initialize",
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
      LogInitFailure("RiskEngine.Initialize");
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
      LogInitFailure("PortfolioRisk.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   g_executor.SetDeviationPoints(InpDeviationPoints);

    if(!g_executor.Initialize())
      {
       g_initialization_started=false;
       LogInitFailure("TradeExecutor.Initialize");
       return SYSTEM_INIT_FAILED;
      }

    if(!g_execution_ledger.Initialize("AlgoMultiAssetEA_ExecutionLedger.sqlite"))
      {
       // Fail closed for new entries - ledger required for attempt tracking
       g_initialization_started=false;
       LogInitFailure("ExecutionLedger.Initialize");
       return SYSTEM_INIT_FAILED;
      }
    
    int unresolved_count = 0;
    int unresolved = g_execution_ledger.RecoverUnresolved(unresolved_count);
    if(unresolved > 0)
      {
       string block_reason = "";
       if(g_execution_ledger.HasBlockingUnresolved(block_reason))
         {
          g_logger.Event(
             LOG_WARNING, "SYSTEM", "UNRESOLVED_ATTEMPTS",
             _Symbol, "", "", "",
             "WARNING", "LEDGER_RECONCILE",
             block_reason + " count=" + IntegerToString(unresolved));
         }
      }

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
      LogInitFailure("PositionManager.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   int runtime_count=InitializePendingRuntimes();

   if(!g_state.Reconstruct())
     {
      g_initialization_started=false;
      LogInitFailure("StateManager.Reconstruct",
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
      LOG_INFO, "SYSTEM", "SYSTEM_READY",
      _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), "", "",
      "READY", "INIT_COMPLETE",
      "AlgoMultiAssetEA Hybrid version="+
      ALGO_SYSTEM_VERSION+
      " style="+StyleName(InpTradingStyle)+
      " mode="+IntegerToString((int)InpMode)+
      " runtimes_ready="+IntegerToString(runtime_count));

   g_dashboard.SetCompactView(InpDashboardCompact);
   g_dashboard.ShowDiagnostics(InpDashboardDiagnostics);
   g_dashboard.ShowOverlay(InpDashboardOverlay);

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
      LOG_INFO, "SYSTEM", "SYSTEM_START",
      _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), "", "",
      "START", "RUN",
      "AlgoMultiAssetEA Hybrid OnInit started RunID="+g_logger.RunId());

   if(!ValidInputSet())
     {
      g_logger.Event(
         LOG_ERROR, "INIT", "INIT_FAILED",
         "", "", "ValidInputSet", "",
         "FAIL", "INIT", "Invalid input parameters", 0);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpMode==MODE_AUTO &&
      !MQLInfoInteger(MQL_TESTER) &&
      !InpLiveAutoConfirm)
     {
      g_logger.Event(
         LOG_ERROR, "INIT", "INIT_FAILED",
         "", "", "LiveAutoConfirm", "",
         "FAIL", "INIT", "MODE_AUTO requires InpLiveAutoConfirm=true", 0);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpMode==MODE_BACKTEST &&
      !MQLInfoInteger(MQL_TESTER))
     {
      g_logger.Event(
         LOG_ERROR, "INIT", "INIT_FAILED",
         "", "", "BacktestMode", "",
         "FAIL", "INIT", "MODE_BACKTEST requires Strategy Tester", 0);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ValidateConfiguredSymbol("GOLD", InpGoldSymbol))
      return INIT_FAILED;

   if(!ValidateConfiguredSymbol("SILVER", InpSilverSymbol))
      return INIT_FAILED;

   if(!ValidateConfiguredSymbol("BITCOIN", InpBitcoinSymbol))
      return INIT_FAILED;

   g_dashboard.Enable(InpDashboard);
   g_dashboard.SetTitle("ALGO HYBRID");

   ResetLastError();
   if(!EventSetTimer(5))
     {
      g_logger.Event(
         LOG_ERROR, "INIT", "INIT_FAILED",
         "", "", "EventSetTimer", "",
         "FAIL", "INIT", "5-second timer setup failed", GetLastError());
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!g_system_ready)
      return;

   bool risk_state_ready=RefreshTradingState();

   g_logger.MaybeWriteSummary(false);

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

   UpdateDashboardForChart();

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
         LOG_INFO, "SYSTEM", "SYSTEM_STOP",
         _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), "", "",
         "STOP", "DEINIT",
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
   if(MQLInfoInteger(MQL_OPTIMIZATION))
     {
      string param_names[4]=
        {
         "InpMinScore",
         "InpConflictThreshold",
         "InpADXTrendThreshold",
         "InpRSIPeriod"
        };

      for(int i=0;i<ArraySize(param_names);i++)
        {
         string name=param_names[i];
         bool enabled=false;
         double current=0, start=0, step=0, stop=0;
         if(ParameterGetRange(
               name,
               enabled,
               current,
               start,
               step,
               stop))
           {
            string msg=
               name+
               " current="+DoubleToString(current,2)+
               " start="+DoubleToString(start,2)+
               " step="+DoubleToString(step,2)+
               " stop="+DoubleToString(stop,2);
            g_logger.Log(LOG_INFO, msg);
           }
         else
            g_logger.Log(
               LOG_WARNING,
               "OnTesterInit: could not read range for "+name);
        }
     }

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
  }
//+------------------------------------------------------------------+
