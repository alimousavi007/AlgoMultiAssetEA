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
input group "01. General & Trading Mode"
input(name="Trading Style")                ENUM_TRADING_STYLE
InpTradingStyle=STYLE_DAY_TRADING;
input(name="Strategy Group Key")            string InpStrategyGroupKey="ALGO_MULTI_ASSET_EA_DEFAULT";
input(name="Execution Mode")               ENUM_TRADING_MODE  InpMode=MODE_SIGNAL_ONLY;
input(name="Confirm Live Automatic Trading") bool               InpLiveAutoConfirm=false;

enum ENUM_DASHBOARD_VIEW_MODE { DASHBOARD_COMPACT, DASHBOARD_NORMAL, DASHBOARD_FULL };
input(name="Dashboard View Mode")          ENUM_DASHBOARD_VIEW_MODE InpDashboardViewMode=DASHBOARD_FULL;
input(name="Enable Dashboard")             bool               InpDashboard=true;
input(name="Log Level")                    ENUM_LOG_LEVEL     InpLogLevel=LOG_INFO;
input(name="Log to File")                  bool               InpLogFile=true;
input(name="Flush Log on Each Write")      bool               InpLogFlushEachWrite=true;
input(name="Log Summary Interval (Seconds)") int              InpLogSummarySeconds=60;

input group "02. Trading Symbols"
input(name="Use Dynamic Forex Universe")   bool               InpUseDynamicForex=true;
input(name="Forex Universe Max Symbols")   int                InpForexMaxSymbols=80;
input(name="Include Gold/Silver/Crypto")   bool               InpIncludeMetalsCrypto=false;
input(name="Gold Symbol")                  string             InpGoldSymbol="XAUUSDb";
input(name="Silver Symbol")                string             InpSilverSymbol="XAGUSDb";
input(name="Bitcoin Symbol")               string             InpBitcoinSymbol="BTCUSD";

input group "03. Hybrid Decision"
input(name="Minimum Reward/Risk Ratio")    double             InpMinRR=1.50;
input(name="Minimum Signal Score")         double             InpMinScore=70.0;
input(name="Signal Conflict Threshold")    double             InpConflictThreshold=15.0;
input(name="Entry Tolerance - Scalping (Points)") double       InpEntryToleranceScalp=5.0;
input(name="Entry Tolerance - Day Trading (Points)") double    InpEntryToleranceDay=20.0;
input(name="Entry Tolerance - Swing (Points)") double          InpEntryToleranceSwing=50.0;
input(name="Allow Mean Reversion")         bool               InpAllowMeanReversion=false;

input group "04. Volume Profile"
input(name="Volume Profile Session Bars")  int                InpProfileSessionBars=78;
input(name="Volume Profile Rolling Bars")  int                InpProfileRollingBars=156;
input(name="Value Area Percent")           double             InpValueAreaPercent=0.68;
input(name="Enable Volume Profile")        bool               InpProfileEnabled=true;

input group "05. Liquidity & Market Structure"
input(name="Swing Lookback (Bars)")        int                InpSwingLookback=5;
input(name="Equal Level Tolerance (Points)") int              InpEqualTolerancePoints=3;
input(name="Max Level Age (Bars)")         int                InpMaxLevelAgeBars=100;
input(name="Sweep Confirmation Bars")      int                InpSweepConfirmBars=3;

input group "06. Divergence & Momentum"
input(name="RSI Period")                   int                InpRSIPeriod=14;
input(name="MACD Fast EMA")                int                InpMACD_Fast=12;
input(name="MACD Slow EMA")                int                InpMACD_Slow=26;
input(name="MACD Signal EMA")              int                InpMACD_Signal=9;
input(name="Pivot Tolerance (%)")          double             InpPivotTolerancePercent=0.02;
input(name="Max Divergence Age (Bars)")    int                InpMaxDivergenceAgeBars=30;
input(name="Momentum Lookback (Bars)")     int                InpMomentumLookback=50;

input group "07. Market Regime"
input(name="ADX Period")                   int                InpADXPeriod=14;
input(name="ADX Trend Threshold")          int                InpADXTrendThreshold=25;
input(name="High Volatility Ratio")        double             InpHighVolatilityRatio=1.50;
input(name="Low Volatility Ratio")         double             InpLowVolatilityRatio=0.70;
input(name="Range Lookback (Bars)")        int                InpRangeLookback=20;
input(name="Hysteresis Bars")              int                InpHysteresisBars=3;

input group "08. News Filter"
input(name="Enable News Filter")           bool               InpNewsEnabled=false;
input(name="Prevent New Entries on News")  bool               InpNewsPreventNewEntries=true;
input(name="News Blackout Before (Minutes)") int             InpNewsBlackoutMinutesBefore=30;
input(name="News Blackout After (Minutes)") int              InpNewsBlackoutMinutesAfter=30;
input(name="News Cooldown (Minutes)")      int                InpNewsCooldownMinutes=60;
input(name="News Impact Threshold")        int                InpNewsImpactThreshold=3;
input(name="Close Positions on News")      bool               InpNewsClosePositions=false;

input group "09. Risk Management & Execution"
input(name="Risk Per Trade (%)")           double             InpRiskPercent=1.0;
input(name="Daily Loss Limit (%)")         double             InpDailyLossLimit=3.0;
input(name="Monthly Loss Limit (%)")       double             InpMonthlyLossLimit=10.0;
input(name="Max Consecutive Losses")       int                InpMaxConsecutiveLosses=3;
input(name="Max Total Open Positions")     int                InpMaxPositionsTotal=3;
input(name="Max Positions Per Symbol")     int                InpMaxPositionsPerSymbol=1;
input(name="Max Positions Per Strategy")   int                InpMaxPositionsPerStrategy=1;
input(name="Max Portfolio Risk (%)")       double             InpMaxPortfolioRisk=3.0;
input(name="Max Precious Metals Risk (%)") double             InpMaxPreciousMetalsRisk=2.0;
input(name="Margin Safety Fraction")       double             InpMarginSafetyFraction=0.80;
input(name="Maximum Execution Deviation (Points)") ulong      InpDeviationPoints=20;

input group "10. Trading Sessions & Market Filters"
input(name="Enable Session Filter")        bool               InpSessionFilter=true;
input(name="Session Start Hour (Server)")  int                InpSessionStartHour=0;
input(name="Session End Hour (Server)")    int                InpSessionEndHour=24;
input(name="Enable Spread Filter")         bool               InpUseSpreadFilter=true;
input(name="Max Spread (Points)")          int                InpMaxSpreadPoints=50;

input group "11. Dashboard & Diagnostics"
input(name="Compact Dashboard View")       bool               InpDashboardCompact=true;
input(name="Show Diagnostics")             bool               InpDashboardDiagnostics=false;
input(name="Show Overlay")                 bool               InpDashboardOverlay=true;

input group "12. Position Management"
input(name="Enable Break-Even")            bool               InpBreakEven=false;
input(name="Break-Even Trigger (R)")       double             InpBreakEvenTriggerR=1.0;
input(name="Break-Even Offset (Points)")   double             InpBreakEvenOffsetPoints=0.0;
input(name="Enable Trailing Stop")         bool               InpTrailing=false;
input(name="Trailing Timeframe")           ENUM_TIMEFRAMES    InpTrailingTF=PERIOD_H1;
input(name="Trailing ATR Period")          int                InpTrailingATRPeriod=14;
input(name="Trailing ATR Multiplier")      double             InpTrailingATRMultiplier=2.0;
input(name="Enable Time Exit")             bool               InpTimeExit=false;
input(name="Max Holding Time (Minutes)")   int                InpMaxHoldingMinutes=240;

input group "13. Data Freshness"
input(name="Context Data Maximum Age (Seconds)") int           InpFreshnessContextSeconds=300;
input(name="Structure Data Maximum Age (Seconds)") int         InpFreshnessStructureSeconds=300;
input(name="Setup Data Maximum Age (Seconds)") int             InpFreshnessSetupSeconds=300;
input(name="Entry Data Maximum Age (Seconds)") int              InpFreshnessEntrySeconds=60;
input(name="Freshness Overrides")          string             InpFreshnessOverrides="";
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
      if(key=="CONTEXT" ||key=="C")
        { if(has_ctx) return false; ctx_sec=v; has_ctx=true; }
      else if(key=="STRUCTURE" ||key=="S")
        { if(has_struct) return false; struct_sec=v; has_struct=true; }
      else if(key=="SETUP" ||key=="U")
        { if(has_setup) return false; setup_sec=v; has_setup=true; }
      else if(key=="ENTRY" ||key=="E")
        { if(has_entry) return false; entry_sec=v; has_entry=true; }
      else
        return false; // unknown role
     }
   if(!has_ctx || !has_struct || !has_setup || !has_entry)
      return false; // incomplete
   return true;
  }

bool ValidInputSet()
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

   if(InpMinScore<0.0 ||InpMinScore>100.0)
      return false;

   if(InpConflictThreshold<0.0)
      return false;

   if(InpSessionStartHour<0 ||InpSessionStartHour>23 ||
      InpSessionEndHour<0 ||InpSessionEndHour>24)
      return false;

   if(InpValueAreaPercent<=0.0 ||InpValueAreaPercent>=1.0)
      return false;

    if(InpProfileSessionBars<=0 ||InpProfileRollingBars<=0)
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

   if(!plan.valid ||plan.entry<=0.0)
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

   if(stop<=0.0 ||target<=0.0)
     {
      reason="Normalized stop/target is invalid";
      return false;
     }

   if(plan.direction==SIGNAL_LONG &&
      (stop>=plan.entry ||target<=plan.entry))
     {
      reason="Long stop/target invalid after normalization";
      return false;
     }

   if(plan.direction==SIGNAL_SHORT &&
      (stop<=plan.entry ||target>=plan.entry))
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
enum ESnapshotFieldState
  {
   SNAP_NOT_EVALUATED = 0,
   SNAP_VALID = 1,
   SNAP_NO_SIGNAL = 2,
   SNAP_BLOCKED = 3,
   SNAP_DATA_UNAVAILABLE = 4,
   SNAP_STALE = 5,
   SNAP_CALCULATION_FAILED = 6
  };

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

   // D1: Runtime snapshot contract (typed, per-runtime, no fabrication)
// (enum moved to global scope before class)
     struct RuntimeSnapshot
     {
      int               generation;
      datetime          snapshot_time;
      datetime          last_success_time;
      string            current_stage;
      string            last_block_reason;

      ENUM_TRADING_STYLE configured_style;
      string            regime_text;
      string            bias_text;
      string            long_text;
      string            short_text;

      ESnapshotFieldState regime_state;
      ESnapshotFieldState bias_state;
      ESnapshotFieldState long_state;
      ESnapshotFieldState short_state;
     };

   RuntimeSnapshot      snapshot;
   int                 snapshot_generation;

    // Runtime gate visibility
    string            last_gate_status;
    string            last_gate_reason;
    datetime          last_gate_time;

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
       last_gate_status="";
       last_gate_reason="";
       last_gate_time=0;

       snapshot_generation=0;
       snapshot.generation=0;
       snapshot.snapshot_time=0;
       snapshot.last_success_time=0;
       snapshot.current_stage="NOT_EVALUATED";
       snapshot.last_block_reason="";
       snapshot.configured_style=STYLE_DAY_TRADING;
       snapshot.regime_text="NOT EVALUATED";
       snapshot.bias_text="NOT EVALUATED";
       snapshot.long_text="NOT EVALUATED";
       snapshot.short_text="NOT EVALUATED";
       snapshot.regime_state=SNAP_NOT_EVALUATED;
       snapshot.bias_state=SNAP_NOT_EVALUATED;
       snapshot.long_state=SNAP_NOT_EVALUATED;
       snapshot.short_state=SNAP_NOT_EVALUATED;
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
        snapshot.configured_style=in_style;
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

       last_gate_status="";
       last_gate_reason="";
       last_gate_time=0;

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
CSymbolRuntime g_runtime[256];
// E2.3-RD: Chart Context Registration events (custom event base)
#define CHARTREG_DISCOVERY  1001
#define CHARTREG_REGISTER   1002
#define CHARTREG_ACK        1003
#define CHARTREG_UNREGISTER 1004
#define CHARTREG_PROTOCOL_VERSION 1
#define SNAPREG_NOTIFY 1005
#define SNAPREG_ACK    1006
long   g_snapshot_sequence = 0;
enum ENUM_COORDINATOR_MODE { COORD_MODE_UNINITIALIZED, COORD_MODE_COORDINATOR, COORD_MODE_CHART_CONTEXT, COORD_MODE_UNAVAILABLE };
ENUM_COORDINATOR_MODE g_coordinator_mode = COORD_MODE_UNINITIALIZED;
string g_owner_instance_token = "";
long   g_authority_epoch = 0;
// Registration state for Chart Context
enum ENUM_REG_STATE { REG_STATE_UNREGISTERED, REG_STATE_PENDING, REG_STATE_REGISTERED, REG_STATE_REJECTED };
ENUM_REG_STATE g_reg_state = REG_STATE_UNREGISTERED;
string g_pending_nonce = "";
long   g_pending_coord_chart = 0;
long   g_pending_coord_epoch = 0;
datetime g_last_reg_request = 0;
int    g_reg_retry_count = 0;
#define REG_RETRY_MAX 3
#define REG_RETRY_INTERVAL 10
// E2.3-RD: subscriber registry (in-memory, Coordinator-only)
struct SubscriberRecord
  {
   long   chart_id;
   string owner_token;
   string strategy_group_key;
   string config_fingerprint;
   bool   registered;
  };
SubscriberRecord g_subscribers[64];
int g_subscriber_count = 0;
// E2.1: Strategy Group identity and Config Fingerprint (single-instance only;
// cross-instance durable arbitration requires later Ledger/Gateway packages)
string g_strategy_group_key = "";
string g_config_fingerprint = "";
string g_runtime_wait_state[256];
string g_runtime_init_failure[256];
int g_runtime_count_max=256;

CAlgoStateManager   g_state;
CRiskEngine         g_risk_engine;
CAlgoPortfolioRisk  g_portfolio_risk;
CTradeExecutor      g_executor;
CExecutionLedger    g_execution_ledger;
CPositionManager    g_position_manager;
CAlgoLogger         g_logger;
CHybridDashboard    g_dashboard;
CSessionFilter      g_session_filter;
CTesterFitness      g_tester_fitness;
COptimizationController g_optimizer;
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

   for(int i=0;i<256;i++)
     {
      if(!g_runtime[i].valid ||
         g_runtime[i].symbol!=chart_symbol)
         continue;

      MarketSnapshot market;
      ResetLastError();

      if(!g_runtime[i].market_context.GetSnapshot(
           g_runtime[i].symbol,
           g_runtime[i].context_tf,
           market))
      {
       g_dashboard.ShowStatus(
            "WAITING FOR MARKET DATA | "+chart_symbol);
         ResetLastError();
         return;
        }

      g_dashboard.SetRuntimeSnapshot(
         EnumToString(g_runtime[i].snapshot.configured_style),
         g_runtime[i].snapshot.regime_text,
         g_runtime[i].snapshot.bias_text,
         g_runtime[i].snapshot.long_text,
         g_runtime[i].snapshot.short_text,
         g_runtime[i].snapshot.current_stage,
         g_runtime[i].snapshot.last_block_reason,
         g_runtime[i].snapshot.snapshot_time,
         g_runtime[i].snapshot.last_success_time,
         (g_runtime[i].snapshot.regime_state==SNAP_VALID));

      g_dashboard.RenderMarketView(market);
      return;
     }

   g_dashboard.ShowStatus(
      "CHART SYMBOL NOT CONFIGURED | "+chart_symbol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeText(ENUM_TIMEFRAMES tf)
  {
   string ts=EnumToString(tf);
   StringReplace(ts,"PERIOD_","");
   return ts;
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

void LogRuntimeGate(CSymbolRuntime &runtime,
                    const string phase,
                    const string gate,
                    const string result,
                    const string reason)
  {
   if(runtime.symbol=="")
      return;
   if(runtime.last_gate_status==phase &&
      runtime.last_gate_reason==reason)
     {
      return;
     }
   runtime.last_gate_status=phase;
   runtime.last_gate_reason=reason;
   runtime.last_gate_time=TimeCurrent();
   g_logger.Event(
      LOG_DEBUG, "RUNTIME", phase,
      runtime.symbol, "", "",
      gate, result, reason);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessHybridDecision(CSymbolRuntime& runtime,
                           HybridDecision& decision,
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

    if(runtime.hybrid_engine.IsPlanConsumed(decision.plan) ||decision.plan.state==SETUP_STATE_CONSUMED)
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

   // All pre-submit revalidation checks passed — setup is valid and ready for execution
   decision.plan.state = SETUP_STATE_VALID;

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

    // RS-01/E2.6: acquire durable claim + initial intent in ONE transaction (no claim-without-intent window).
    // On any failure, neither durable claim nor intent is committed. Legacy claim-only records remain fail-closed.
    if(normalized_plan.logical_setup_key == "" || g_strategy_group_key == "")
      {
       g_logger.Event(LOG_ERROR, "EXECUTION", "SETUP_CLAIM_BLOCKED", request.symbol, "", "", request.signal_id,
                      "REJECT", "CLAIM_IDENTITY", "Missing logical_setup_key or strategy_group_key - fail closed (no intent, no broker)");
       runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
       return;
      }
    ExecutionAttemptRecord attempt_rec;
    ZeroMemory(attempt_rec);
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
     // F-002: durable per-Attempt initial risk reservation (verified per-candidate monetary loss, account currency).
     // Atomic with durable Intent via CreateSetupClaimAndIntent; fail-closed if unknown/invalid.
     attempt_rec.risk_reserve_known = (risk.actual_monetary_risk > 0.0 && MathIsValidNumber(risk.actual_monetary_risk) && AccountInfoDouble(ACCOUNT_EQUITY) > 0.0);
     attempt_rec.risk_reserve_model_version = EXEC_RISK_RESERVE_MODEL_V1;
     attempt_rec.risk_reserve_state = EXEC_RISK_RESERVE_STATE_ACTIVE;
     attempt_rec.risk_reserve_initial_amount = risk.actual_monetary_risk;
     attempt_rec.risk_reserve_remaining_amount = risk.actual_monetary_risk;
     attempt_rec.risk_reserve_currency = AccountInfoString(ACCOUNT_CURRENCY);
     attempt_rec.risk_reserve_equity_snapshot = AccountInfoDouble(ACCOUNT_EQUITY);
     attempt_rec.risk_reserve_percent_snapshot = (attempt_rec.risk_reserve_equity_snapshot > 0.0 ? (attempt_rec.risk_reserve_initial_amount / attempt_rec.risk_reserve_equity_snapshot * 100.0) : 0.0);
     attempt_rec.risk_reserve_revision = 1;
     attempt_rec.risk_reserve_updated_at = TimeCurrent();
     attempt_rec.risk_reserve_release_reason = "";
     // E2.6/RS identity fields for atomic claim+intent (restart-stable; not setup_id/attempt_id)
     attempt_rec.strategy_group_key = g_strategy_group_key;
     attempt_rec.logical_setup_key = normalized_plan.logical_setup_key;
     attempt_rec.serialization_version = 2;
     attempt_rec.canonical_identity = CExecutionLedger::BuildStableCanonicalIdentity(
         g_strategy_group_key, normalized_plan.symbol, "DEFAULT_SETUP",
         (int)normalized_plan.direction, normalized_plan.signal_time, (int)runtime.setup_tf, 2);
    {
     // RS01-CANON-01: stable canonical identity (v2). Legacy v1 claims recognized by ledger compatibility.
     string claim_intent_err = "";
     CExecutionLedger::ENUM_CLAIM_RESULT claim_res = g_execution_ledger.CreateSetupClaimAndIntent(
         g_strategy_group_key, normalized_plan.logical_setup_key, attempt_rec.canonical_identity, 2, attempt_rec, claim_intent_err);
     if(claim_res != CExecutionLedger::CLAIM_CREATED)
       {
        string cmsg = (claim_res == CExecutionLedger::CLAIM_ALREADY_EXISTS) ? "Durable claim already exists for logical setup (restart-safe duplicate prevention)" :
                      (claim_res == CExecutionLedger::CLAIM_IDENTITY_COLLISION) ? "Claim identity collision for logical setup key (stable components differ or unsafe legacy)" :
                      "Atomic claim+intent acquisition failed (DB/error) - fail closed, no partial commit";
        g_logger.Event((claim_res == CExecutionLedger::CLAIM_ERROR ? LOG_ERROR : LOG_WARNING), "EXECUTION", "SETUP_CLAIM_BLOCKED", request.symbol, "", "", request.signal_id,
                       "REJECT", "CLAIM_BLOCKED", cmsg + " lsk=" + normalized_plan.logical_setup_key + " err=" + claim_intent_err);
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
       }
    }

    // Check ledger for blocking unresolved attempts
    string ledger_block = "";
    if(!g_execution_ledger.IsAvailable() ||g_execution_ledger.HasBlockingUnresolved(ledger_block))
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

      // E2.6: Execution authorization boundary (must run before submission-bound state)
      if(g_coordinator_mode != COORD_MODE_COORDINATOR)
        {
         g_logger.Event(LOG_ERROR, "EXECUTION", "AUTHORIZATION_DENIED", request.symbol, "", "", request.signal_id, "FAIL", "AUTHORITY", "Not Coordinator - execution denied");
         // F-E26-002: handle ResolveAttempt failure; do not claim durable ABORTED on ledger failure.
         if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Authorization denied: not coordinator"))
           {
            g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after coordinator denial - fail closed, no submit");
            string block_reason="";
            g_execution_ledger.HasBlockingUnresolved(block_reason);
           }
         runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
         return;
        }
      {
       string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
       g_executor.SyncAuthority(g_authority_epoch, (g_coordinator_mode == COORD_MODE_COORDINATOR));
       if(!g_execution_ledger.ValidateAuthority(authority_key, g_owner_instance_token, g_authority_epoch))
         {
          g_logger.Event(LOG_ERROR, "EXECUTION", "AUTHORIZATION_DENIED", request.symbol, "", "", request.signal_id, "FAIL", "AUTHORITY", "Authority validation failed - execution denied");
          // F-E26-002
          if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Authorization denied: authority validation failed"))
            {
             g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after authority denial - fail closed, no submit");
             string block_reason="";
             g_execution_ledger.HasBlockingUnresolved(block_reason);
            }
          runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
          return;
         }
      }

     // F-E26-001: bind durable intent (still non-ambiguous, no broker call), then CanSubmit, then enter
     // SUBMISSION_MAY_HAVE_OCCURRED immediately adjacent to the broker invocation. No unrelated work
     // between MarkSubmissionMayHaveOccurred and Execute.
     if(!g_execution_ledger.MarkSubmissionBound(request.attempt_id, "Pre-submit validation passed"))
       {
        g_logger.Event(
           LOG_ERROR, "EXECUTION", "SUBMISSION_BOUND_FAILED",
           request.symbol, "", "",
           request.signal_id,
           "FAIL", "LEDGER_ERROR", "Failed to mark submission bound");
        // Intent remains durable non-submitted (or ledger unavailable); fail closed.
        if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Submission binding failed - non-submission"))
          {
           g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after binding failure - fail closed, no submit");
           string block_reason="";
           g_execution_ledger.HasBlockingUnresolved(block_reason);
          }
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
        // Bound intent was never sent to broker in this flow; resolve as terminal non-submission.
        if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Submit not allowed: " + submit_reason))
          {
           g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after submit gate - fail closed, no submit");
           string block_reason="";
           g_execution_ledger.HasBlockingUnresolved(block_reason);
          }
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

     // Final durable transition immediately before broker API. If this fails, do not call broker.
     if(!g_execution_ledger.MarkSubmissionMayHaveOccurred(request.attempt_id, "Broker invocation boundary - submission may have occurred"))
       {
        g_logger.Event(LOG_ERROR, "EXECUTION", "SUBMISSION_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "Could not durably mark submission-may-have-occurred; broker call aborted (fail closed)");
        // State is still bound non-submitted; resolve terminally without broker call.
        if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Pre-broker ambiguity mark failed - no broker invocation"))
          {
           g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after submission-mark failure");
           string block_reason="";
           g_execution_ledger.HasBlockingUnresolved(block_reason);
          }
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
       }

     ExecutionResult result;
     bool execution_ok = g_executor.Execute(request, result);
      g_logger.Trade(result);

     // F-E26-003: confirmed pre-broker authorization denial by executor (no broker API invoked)
     // is a terminal non-submission outcome, not ambiguous submission/reconciliation.
     if(!result.success && result.failure_class == "AUTHORIZATION_DENIED" && !result.reconciliation_required)
       {
        if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Executor authorization denied - confirmed no broker invocation"))
          {
           g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed for confirmed non-submission denial; marking reconciliation required");
           g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "ResolveAttempt failed after confirmed executor auth denial - requires manual reconciliation");
          }
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
       }

     // Record result in ledger after API call/observation (authoritative state transition)
     bool result_recorded = g_execution_ledger.RecordResult(request.attempt_id, result, "Executor result");
     if(!result_recorded)
       {
        g_logger.Event(LOG_ERROR, "EXECUTION", "RECORD_RESULT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR",
                       "RecordResult failed after broker invocation/result observation; forcing reconciliation (no retry, no FINAL_FAILURE fabrication)");
        // Never fabricate FINAL_FAILURE. Broker may have been invoked; force safe reconciliation path.
        bool recon_ok = g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "RecordResult write failed after execution result - reconciliation required (no retry)");
        if(!recon_ok)
          {
           ENUM_EXEC_ATTEMPT_STATE st = EXEC_STATE_NONE;
           bool st_ok = g_execution_ledger.GetAttemptState(request.attempt_id, st);
           bool blocked = false; string block_reason="";
           if(st_ok)
              blocked = (st==EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED || st==EXEC_STATE_RECONCILIATION_REQUIRED || st==EXEC_STATE_PARTIAL_FILL || st==EXEC_STATE_SUBMITTED || st==EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED);
           else
              blocked = g_execution_ledger.HasBlockingUnresolved(block_reason);
           g_logger.Event(LOG_ERROR, "EXECUTION", "RECONCILIATION_MARK_FAILED_AFTER_RECORD_RESULT", request.symbol, "", "", request.attempt_id, "FAIL", "LEDGER_ERROR",
                          "MarkReconciliationRequired failed after RecordResult failure; state_readable="+(st_ok?"1":"0")+" state="+IntegerToString((int)st)+" blocking="+(blocked?"1":"0")+" reason="+block_reason+" (no retry, no FINAL_FAILURE)");
          }
       }

     {
        ENUM_EXEC_ATTEMPT_STATE st = EXEC_STATE_NONE;
        if(g_execution_ledger.GetAttemptState(request.attempt_id, st))
          {
           // Only flag reconciliation if the post-RecordResult state is still ambiguous/unsubmitted.
           // (Avoids spurious RECONCILIATION_REQUIRED when result was terminally recorded.)
           if(st == EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
              g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "Attempt not bound before execution - reconciliation required");
           else if(st == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
              g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "Submission state still ambiguous after recorded result - reconciliation required");
          }
        else if(!result_recorded)
          {
           // Ledger state unreadable after failed write: critical diagnostic; do not retry.
           g_logger.Event(LOG_ERROR, "EXECUTION", "LEDGER_STATE_UNREADABLE", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR",
                          "Attempt state unreadable after RecordResult failure - ledger trust degraded; further execution remains fail-closed by blocking-unresolved checks");
          }
     }

 // An executor call consumes this setup even when it fails. Automatic
 // retries need an explicit retry policy; do not resubmit the same setup
 // on the next entry bar after an ambiguous broker/transport result.
    runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);

     if(!execution_ok || !result.success)
         {
          // If result is ambiguous, ensure reconciliation required
          if(result.reconciliation_required || result.retcode == TRADE_RETCODE_TIMEOUT || result.retcode == TRADE_RETCODE_CONNECTION)
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
       LogRuntimeGate(runtime, "SESSION_FILTER", "SESSION", "BLOCK", "NOT_ALLOWED");
       return;
      }

    if(!runtime.market_entry.IsNewClosedBar(
          runtime.symbol,
          runtime.entry_tf))
      {
       ShowRuntimeGateStatus(runtime, "WAITING: ENTRY BAR");
       LogRuntimeGate(runtime, "ENTRY_BAR_WAIT", "ENTRY_BAR", "WAIT", "NO_NEW_CLOSED_BAR");
       runtime.snapshot.current_stage = "WAITING_FOR_NEW_ENTRY_BAR";
       runtime.snapshot.last_block_reason = "NO_NEW_CLOSED_BAR";
       runtime.snapshot.configured_style = runtime.style;
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
       LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "CONTEXT_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
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
       LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "STRUCTURE_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
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
        LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "SETUP_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
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
       LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "ENTRY_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
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
       LogRuntimeGate(runtime, "FEATURE_CALC", "CONTEXT_FEATURES", "FAIL", "CALC_FAILED");
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
       LogRuntimeGate(runtime, "FEATURE_CALC", "STRUCTURE_FEATURES", "FAIL", "CALC_FAILED");
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
        LogRuntimeGate(runtime, "FEATURE_CALC", "SETUP_FEATURES", "FAIL", "CALC_FAILED");
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
       LogRuntimeGate(runtime, "FEATURE_CALC", "ENTRY_FEATURES", "FAIL", "CALC_FAILED");
       return;
     }
    if(!runtime.market_context.IsNewClosedBar(
          runtime.symbol,
          runtime.context_tf))
      {
       ShowRuntimeGateStatus(runtime, "WAITING: SIGNAL BAR");
       LogRuntimeGate(runtime, "CONTEXT_BAR_WAIT", "CONTEXT_BAR", "WAIT", "NO_NEW_CLOSED_BAR");
       runtime.snapshot.configured_style = runtime.style;
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
       LogRuntimeGate(runtime, "RISK_STATE", "PORTFOLIO_STATE", "BLOCK", "UNAVAILABLE");
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
       LogRuntimeGate(runtime, "RISK_LOCK", "PORTFOLIO_RISK", "BLOCK", "TRADING_LOCKED");
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
       LogRuntimeGate(runtime, "CONTEXT_BUILD", "FEATURE_CONTEXT", "BLOCK", ctx.reason);
       return;
     }

   HybridDecision decision = runtime.hybrid_engine.Evaluate(
                                runtime.symbol, ctx, context_market, ok);

   ProcessHybridDecision(runtime, decision, portfolio_state);

   // D1.1: publish real engine outputs into the Runtime Snapshot
   runtime.snapshot_generation++;
   runtime.snapshot.generation = runtime.snapshot_generation;
   runtime.snapshot.snapshot_time = TimeCurrent();
   runtime.snapshot.last_success_time = (decision.valid ? decision.decision_time : runtime.snapshot.last_success_time);
   runtime.snapshot.current_stage = "EVALUATED";
   runtime.snapshot.last_block_reason = (decision.valid ? "" : decision.main_reason);
   runtime.snapshot.configured_style = runtime.style;
   runtime.snapshot.regime_text = EnumToString(decision.regime);
   runtime.snapshot.bias_text = EnumToString(decision.bias);
   runtime.snapshot.long_text = (decision.long_score > 0 ? "LONG CANDIDATE" : "NO LONG");
   runtime.snapshot.short_text = (decision.short_score > 0 ? "SHORT CANDIDATE" : "NO SHORT");
   runtime.snapshot.regime_state = (decision.valid ? SNAP_VALID : SNAP_CALCULATION_FAILED);
   runtime.snapshot.bias_state = (decision.valid ? SNAP_VALID : SNAP_CALCULATION_FAILED);
   runtime.snapshot.long_state = (decision.valid ? SNAP_VALID : SNAP_CALCULATION_FAILED);
   runtime.snapshot.short_state = (decision.valid ? SNAP_VALID : SNAP_CALCULATION_FAILED);
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
   string symbols[];
   DiscoverForexSymbols(symbols);

   string roles[];
   ArrayResize(roles,ArraySize(symbols));
   for(int r=0;r<ArraySize(roles);r++) roles[r]="FX";

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
    timeframes[3]=entry_tf;

   bool tester_single_symbol =
      (MQLInfoInteger(MQL_TESTER)!=0);
   int runtime_count=0;
   for(int i=0;i<256;i++)
     {
      if(g_runtime[i].valid) runtime_count++;
     }

   for(int i=0;i<ArraySize(symbols);i++)
     {
      if(i>=256) break;
      if(StringLen(symbols[i])==0)
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
      g_runtime[i].hybrid_engine.SetStrategyGroupKey(g_strategy_group_key);
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

    // E2.6: configure shared broker-mutation authorization context (fail-closed in executor)
    g_executor.ConfigureAuthority(GetPointer(g_execution_ledger),
                                  AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)),
                                  g_owner_instance_token);
    g_executor.SyncAuthority(g_authority_epoch, (g_coordinator_mode == COORD_MODE_COORDINATOR));

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
        string ledger_stage=g_execution_ledger.LastInitStage();
        if(ledger_stage=="")
           ledger_stage="ExecutionLedger.Initialize";
        string ledger_operation=g_execution_ledger.LastInitOperation();
        int ledger_error=g_execution_ledger.LastInitError();
        g_logger.Event(
           LOG_ERROR, "INIT", "INIT_FAILED",
           "", "", ledger_stage, "", "FAIL", "INIT",
           "operation="+ledger_operation+" LastError="+IntegerToString(ledger_error),
           ledger_error);
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
       // Attempt reconciliation for unresolved
       g_execution_ledger.ReconcileUnresolved(20);
       }
      // RS01-CLAIMORPHAN-01: bounded read-only claim observability (no auto-release/retry).
      {
       string claim_diag=""; int orphan_claims=0;
       int claim_rows = g_execution_ledger.InspectSetupClaims(claim_diag, orphan_claims, 20);
       if(claim_rows < 0)
          g_logger.Event(LOG_WARNING, "SYSTEM", "CLAIM_DIAG_FAILED", _Symbol, "", "", "", "WARNING", "CLAIM_DIAG", "Claim inspection query failed - fail closed (no auto-release)");
       else if(orphan_claims > 0)
          g_logger.Event(LOG_WARNING, "SYSTEM", "CLAIM_ORPHAN_DETECTED", _Symbol, "", "", "", "WARNING", "CLAIM_DIAG",
                         "orphan_claims=" + IntegerToString(orphan_claims) + " rows=" + IntegerToString(claim_rows) + " detail=" + claim_diag);
       else if(claim_rows > 0)
          g_logger.Event(LOG_INFO, "SYSTEM", "CLAIM_DIAG", _Symbol, "", "", "", "OK", "CLAIM_DIAG", "active_claims_checked=" + IntegerToString(claim_rows));
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

    g_position_manager.SetExecutor(GetPointer(g_executor));

    if(!g_position_manager.Initialize())
     {
      g_initialization_started=false;
      LogInitFailure("PositionManager.Initialize");
      return SYSTEM_INIT_FAILED;
     }

   int runtime_count=0;
   // E2.4: Coordinator election
   string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(g_execution_ledger.IsAvailable())
     {
      int astate = g_execution_ledger.GetAuthorityState(authority_key);
       if(astate == (int)GATEWAY_AUTHORITY_ORPHANED || astate == -1)
         {
          g_coordinator_mode = COORD_MODE_UNAVAILABLE;
          g_executor.SyncAuthority(g_authority_epoch, false);
          g_logger.Event(LOG_WARNING, "INIT", "COORDINATOR_UNAVAILABLE", _Symbol, "", "", "", "FAIL", "AUTHORITY", "Authority unavailable or orphaned");
         }
      else
        {
         long epoch = 0;
          if(g_execution_ledger.AcquireAuthority(authority_key, g_owner_instance_token, epoch))
            {
             g_coordinator_mode = COORD_MODE_COORDINATOR;
             g_authority_epoch = epoch;
             g_executor.SyncAuthority(g_authority_epoch, true);
             runtime_count = InitializePendingRuntimes();
            }
          else
            {
             g_coordinator_mode = COORD_MODE_CHART_CONTEXT;
             g_executor.SyncAuthority(g_authority_epoch, false);
             g_logger.Event(LOG_INFO, "INIT", "CHART_CONTEXT_ONLY", _Symbol, "", "", "", "INFO", "AUTHORITY", "Another coordinator owns authority");
            }
        }
     }
   else
      {
       // Ledger unavailable: fail-closed, no coordinator
       g_coordinator_mode = COORD_MODE_UNAVAILABLE;
       g_executor.SyncAuthority(g_authority_epoch, false);
      }

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

   g_dashboard.SetViewMode(InpDashboardViewMode==DASHBOARD_COMPACT?2:(InpDashboardViewMode==DASHBOARD_NORMAL?1:0));
   g_dashboard.ShowDiagnostics(InpDashboardDiagnostics);
   g_dashboard.ShowOverlay(InpDashboardOverlay);

   UpdateDashboardForChart();
   return SYSTEM_INIT_READY;
  }

//==================================================================
// OnInit
//==================================================================
//+------------------------------------------------------------------+
//| E2.1: Deterministic Config Fingerprint (v1)                      |
//+------------------------------------------------------------------+
string ComputeConfigFingerprint()
  {
   // Canonical serialization of trading-relevant settings.
   // Presentation-only settings (Dashboard, ViewMode, diagnostics) excluded.
   string s = "CFGV1|";
   s += "STYLE=" + IntegerToString((int)InpTradingStyle) + "|";
   s += "MODE=" + IntegerToString((int)InpMode) + "|";
   s += "LIVECONFIRM=" + (InpLiveAutoConfirm ? "1" : "0") + "|";
   s += "GROUP=" + InpStrategyGroupKey + "|";
   // Timeframe roles are global inputs; include if present as inputs (placeholder)
   s += "DEVIATION=" + IntegerToString(InpDeviationPoints) + "|";
   // Timeframe roles are resolved internally; include style-dependent policy via MagicForStyle
   s += "MAGIC=" + IntegerToString((int)MagicForStyle(InpTradingStyle)) + "|";
   // Simple deterministic hash (not cryptographic)
   uint h = 5381;
   for(int i = 0; i < StringLen(s); i++)
     {
      h = ((h << 5) + h) + (uint)StringGetCharacter(s, i);
     }
   return "FP_" + IntegerToString((long)h, 16);
  }

int OnInit()
  {
   g_logger.StartRun();
   // E2.4: Generate unique OwnerInstanceToken
   g_owner_instance_token = "OI_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
                            IntegerToString((long)TimeCurrent()) + "_" + IntegerToString(MathRand());
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

   g_strategy_group_key = (InpStrategyGroupKey == "" ? "ALGO_MULTI_ASSET_EA_DEFAULT" : InpStrategyGroupKey);
   g_config_fingerprint = ComputeConfigFingerprint();
   g_logger.Event(LOG_INFO, "INIT", "STRATEGY_GROUP_IDENTITY",
      _Symbol, "", "", "", "INFO", "CONFIG",
       "group=" + g_strategy_group_key + " fingerprint=" + g_config_fingerprint);

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

   if(g_coordinator_mode == COORD_MODE_COORDINATOR)
     {
      for(int i=0;i<256;i++)
         ProcessRuntime(g_runtime[i]);
     }
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

    if(g_coordinator_mode == COORD_MODE_COORDINATOR)
      {
       // Discovery: enumerate charts and send discovery probe
       long chart = ChartFirst();
       static datetime last_discovery = 0;
       if(TimeCurrent() - last_discovery < 5)
          return; // rate limit: 5 seconds
       last_discovery = TimeCurrent();
       string nonce = "N" + IntegerToString((long)TimeCurrent()) + IntegerToString((long)ChartID());
       g_pending_nonce = nonce;
       while(chart >= 0)
         {
          if(chart != ChartID())
            {
             string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
             string probe = "D|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + auth_key + "|" + IntegerToString((long)ChartID()) + "|" + IntegerToString(g_authority_epoch) + "|" + nonce;
             if(StringLen(probe) <= 63)
               {
                if(!EventChartCustom(chart, CHARTREG_DISCOVERY, (long)ChartID(), 0.0, probe))
                  {
                   // enqueue failed; retry next cycle
                  }
               }
            }
          chart = ChartNext(chart);
         }
        // Canonical state comparison based on time + subscriber count (placeholder for full dashboard hash)
        static string last_canonical = "";
        string canonical = IntegerToString((long)TimeCurrent()) + "_" + IntegerToString(g_subscriber_count) + "_" + IntegerToString(g_authority_epoch);
        if(canonical == last_canonical)
          {
           // unchanged; skip
          }
        else
          {
           last_canonical = canonical;
           g_snapshot_sequence++;
           for(int i = 0; i < g_subscriber_count; i++)
             {
              long target_chart = g_subscribers[i].chart_id;
              string obj_name = "AlgoEA_Dashboard";
              ObjectCreate(target_chart, obj_name, OBJ_LABEL, 0, 0, 0);
              ObjectSetInteger(target_chart, obj_name, OBJPROP_XDISTANCE, 10);
              ObjectSetInteger(target_chart, obj_name, OBJPROP_YDISTANCE, 20);
              ObjectSetString(target_chart, obj_name, OBJPROP_TEXT, "CoordSnap=" + IntegerToString(g_snapshot_sequence) + " Epoch=" + IntegerToString(g_authority_epoch));
              ChartRedraw(target_chart);
              string notify = "S|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + IntegerToString(g_authority_epoch) + "|" + IntegerToString(g_snapshot_sequence);
              if(StringLen(notify) <= 63)
                {
                 if(!EventChartCustom(target_chart, SNAPREG_NOTIFY, (long)ChartID(), 0.0, notify))
                   {
                    // enqueue failed
                   }
                }
             }
          }
       string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
        if(!g_execution_ledger.HeartbeatAuthority(authority_key, g_owner_instance_token, g_authority_epoch) ||
           !g_execution_ledger.ValidateAuthority(authority_key, g_owner_instance_token, g_authority_epoch))
          {
           g_coordinator_mode = COORD_MODE_UNAVAILABLE;
           g_executor.SyncAuthority(g_authority_epoch, false);
           g_logger.Event(LOG_WARNING, "SYSTEM", "COORDINATOR_LOST", _Symbol, "", "", "", "FAIL", "AUTHORITY", "Heartbeat/validation failed");
          }
      }

     // Chart Context registration retry
     if(g_coordinator_mode == COORD_MODE_CHART_CONTEXT && g_reg_state == REG_STATE_PENDING)
       {
        if(TimeCurrent() - g_last_reg_request >= REG_RETRY_INTERVAL && g_reg_retry_count < REG_RETRY_MAX)
          {
           // Resend same pending registration request
           string reg = "R|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "|" +
                        IntegerToString((long)ChartID()) + "|" + g_owner_instance_token + "|" +
                        g_strategy_group_key + "|" + g_config_fingerprint + "|" +
                        IntegerToString(g_pending_coord_chart) + "|" + IntegerToString(g_pending_coord_epoch) + "|" + g_pending_nonce;
           if(StringLen(reg) <= 63)
             {
              if(EventChartCustom(g_pending_coord_chart, CHARTREG_REGISTER, (long)ChartID(), 0.0, reg))
                {
                 g_last_reg_request = TimeCurrent();
                 g_reg_retry_count++;
                }
             }
          }
        if(g_reg_retry_count >= REG_RETRY_MAX)
          {
           g_reg_state = REG_STATE_REJECTED;
           g_pending_nonce = "";
          }
       }
        static datetime last_reconcile = 0;
        if(TimeCurrent() - last_reconcile > 60)
          {
          g_execution_ledger.ReconcileUnresolved(5);
         last_reconcile = TimeCurrent();
          }
        // E2.6: process explicit chart-confirmed retry handoff only in timer path (transient; no auto-retry on restart).
        // Handoff remains fail-closed before broker submission until full fresh-plan/LSK+gate revalidation binding is implemented.
        ProcessRetryPendingHandoff();
        // RS01-CLAIMORPHAN-01: bounded periodic claim-only observability (read-only, no auto-release).
        static datetime last_claim_diag = 0;
        if(TimeCurrent() - last_claim_diag > 300)
          {
           string claim_diag=""; int orphan_claims=0;
           int claim_rows = g_execution_ledger.InspectSetupClaims(claim_diag, orphan_claims, 10);
           if(claim_rows < 0)
              g_logger.Event(LOG_WARNING, "SYSTEM", "CLAIM_DIAG_FAILED", _Symbol, "", "", "", "WARNING", "CLAIM_DIAG", "Claim inspection query failed - fail closed");
           else if(orphan_claims > 0)
              g_logger.Event(LOG_WARNING, "SYSTEM", "CLAIM_ORPHAN_DETECTED", _Symbol, "", "", "", "WARNING", "CLAIM_DIAG",
                             "orphan_claims=" + IntegerToString(orphan_claims) + " rows=" + IntegerToString(claim_rows) + " detail=" + claim_diag);
           last_claim_diag = TimeCurrent();
          }

    bool risk_state_ready=RefreshTradingState();

   UpdateDashboardForChart();

   g_position_manager.Update();

   if(!risk_state_ready)
      return;

   if(g_coordinator_mode == COORD_MODE_COORDINATOR)
     {
      for(int i=0;i<256;i++)
        {
         if(g_runtime[i].valid)
            ProcessRuntime(g_runtime[i]);
        }
     }
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//|                                                                  |
//| Event-driven reconciliation of broker trade transactions.        |
//| Matches transactions to execution attempts using broker          |
//| identifiers and updates the ExecutionLedger. Does NOT auto-      |
//| retry on ambiguous outcomes; complement to timer-based           |
//| reconciliation in OnTimer.                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
   {
   if(!g_system_ready)
      return;

   // Only handle transactions for our managed magics
   bool is_managed_magic =
        request.magic==MAGIC_HYBRID_SCALP ||
        request.magic==MAGIC_HYBRID_DAY   ||
        request.magic==MAGIC_HYBRID_SWING ||
        request.magic==MAGIC_TREND ||
        request.magic==MAGIC_BREAKOUT ||
        request.magic==MAGIC_MOMENTUM ||
        request.magic==MAGIC_MEAN_REVERSION ||
        request.magic==MAGIC_RELATIVE_VALUE;

   if(!is_managed_magic)
      return;

   // Log transaction for auditability
   g_logger.Event(
      LOG_DEBUG, "TRADE", "TRADE_TRANSACTION",
      trans.symbol, "", "",
      "", "TXN", IntegerToString((int)trans.type),
      "order="+IntegerToString((long)trans.order)+
      " deal="+IntegerToString((long)trans.deal)+
      " position="+IntegerToString((long)trans.position)+
      " magic="+IntegerToString((long)request.magic));

   // Event-driven reconciliation: when a broker transaction related
   // to our EA occurs, reconcile unresolved attempts. Reduces the
   // fail-closed window for ambiguous submissions. Does NOT auto-
   // retry; ReconcileAttempt preserves identity_proof_required and
   // fail-closed-on-ambiguity constraints.
   g_execution_ledger.ReconcileUnresolved(10);
   }

//==================================================================
// E2.6: Local chart approval (minimal, EA-owned). No broker calls.
// Trust: LOCAL_TERMINAL_SESSION_CONTEXT_ONLY. No personal identity/auth.
// Review/Confirm are explicit; Cancel has no ledger side effect.
// Pending review is transient (in-memory) => no auto-retry on restart.
//==================================================================
#define E2E6_RETRY_OBJ_PREFIX "AlgoE2E6Retry_"
enum ENUM_E2E6_RETRY_UI_STATE { E2E6_UI_HIDDEN=0, E2E6_UI_REVIEW, E2E6_UI_CONFIRM_READY, E2E6_UI_BLOCKED, E2E6_UI_COMMITTED, E2E6_UI_INTERRUPTED_VIEW };
struct RetryReviewCandidate
  {
   bool   valid;
   // immutable durable identity/binding snapshot (reloaded from ledger at Review and Confirm)
   string claim_id;
   string strategy_group_key;
   string logical_setup_key;
   string canonical_identity;
   int    serialization_version;
   string symbol;
   int    direction;
   string prior_attempt_id;
   int    retry_sequence;
   int    claim_state;
   int    attempt_state;
   string failure_class;
   uint   retcode;
   double requested_volume;
   double executed_volume;
   double remaining_volume;
   ulong  broker_order_ticket;
   ulong  broker_deal_ticket;
   ulong  broker_position_ticket;
   string evidence_reason;
   string why_ineligible;
   // local chart/session context snapshot (must remain unchanged at Confirm)
   long   account_login;
   string account_server;
   long   chart_id;
   string chart_symbol;
   int    chart_period;
   string config_fingerprint;
   datetime reviewed_at;
  };
struct RetryPendingHandoff
  {
   bool   active;
   string action_id;
   string claim_id;
   string strategy_group_key;
   string logical_setup_key;
   string prior_attempt_id;
   string new_attempt_id;
   int    expected_retry_sequence;
   long   account_login;
   string account_server;
   string config_fingerprint;
   datetime created_at;
  };
ENUM_E2E6_RETRY_UI_STATE g_retry_ui_state = E2E6_UI_HIDDEN;
RetryReviewCandidate     g_retry_review;
CExecutionLedger::RetryEligibleCandidate g_retry_candidates[];
int                      g_retry_candidate_count = 0;
int                      g_retry_candidate_index = -1;
RetryPendingHandoff      g_retry_handoff;
string g_retry_ui_status = "";
string g_retry_ui_detail = "";
string g_retry_btn_review  = E2E6_RETRY_OBJ_PREFIX + "REVIEW";
string g_retry_btn_next    = E2E6_RETRY_OBJ_PREFIX + "NEXT";
string g_retry_btn_confirm = E2E6_RETRY_OBJ_PREFIX + "CONFIRM";
string g_retry_btn_cancel  = E2E6_RETRY_OBJ_PREFIX + "CANCEL";
string g_retry_lbl_status  = E2E6_RETRY_OBJ_PREFIX + "STATUS";
string g_retry_lbl_detail  = E2E6_RETRY_OBJ_PREFIX + "DETAIL";
string g_retry_btn_inspect = E2E6_RETRY_OBJ_PREFIX + "INSPECT";
CExecutionLedger::InterruptedRetryHandoff g_retry_interrupted[];
int g_retry_interrupted_count = 0;

void RetryUIClearCandidateList()
  {
   ArrayResize(g_retry_candidates,0);
   g_retry_candidate_count=0;
   g_retry_candidate_index=-1;
  }

void RetryUIInvalidate(const string reason="")
  {
   if(g_retry_ui_state == E2E6_UI_COMMITTED && g_retry_handoff.active)
     { g_retry_ui_status = "COMMITTED_NOT_SUBMITTED_PENDING_REVALIDATION"; }
   else
     { g_retry_ui_state = E2E6_UI_HIDDEN; ZeroMemory(g_retry_review); g_retry_review.valid=false; RetryUIClearCandidateList(); }
   if(reason!="") g_retry_ui_detail = reason;
  }

bool RetryUIEnsureButton(const string name,const string text,const int x,const int y,const int w,const int h,const color bg,const color fg)
  {
   long chart = ChartID();
   if(ObjectFind(chart,name) < 0)
     {
      if(!ObjectCreate(chart,name,OBJ_BUTTON,0,0,0))
         return false;
     }
   ObjectSetInteger(chart,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(chart,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(chart,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(chart,name,OBJPROP_YSIZE,h);
   ObjectSetString(chart,name,OBJPROP_TEXT,text);
   ObjectSetString(chart,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(chart,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(chart,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(chart,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(chart,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(chart,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chart,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(chart,name,OBJPROP_ZORDER,30);
   ObjectSetInteger(chart,name,OBJPROP_STATE,false);
   return true;
  }

bool RetryUIEnsureLabel(const string name,const string text,const int x,const int y,const color fg)
  {
   long chart = ChartID();
   if(ObjectFind(chart,name) < 0)
     {
      if(!ObjectCreate(chart,name,OBJ_LABEL,0,0,0))
         return false;
     }
   ObjectSetInteger(chart,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(chart,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(chart,name,OBJPROP_TEXT,text);
   ObjectSetString(chart,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(chart,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(chart,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(chart,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chart,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(chart,name,OBJPROP_ZORDER,30);
   return true;
  }

void RetryUIDeleteObject(const string name)
  {
   long chart = ChartID();
   if(ObjectFind(chart,name) >= 0)
      ObjectDelete(chart,name);
  }

void RetryUIClear()
  {
   RetryUIDeleteObject(g_retry_btn_review);
   RetryUIDeleteObject(g_retry_btn_next);
   RetryUIDeleteObject(g_retry_btn_confirm);
   RetryUIDeleteObject(g_retry_btn_cancel);
   RetryUIDeleteObject(g_retry_btn_inspect);
   RetryUIDeleteObject(g_retry_lbl_status);
   RetryUIDeleteObject(g_retry_lbl_detail);
   ArrayResize(g_retry_interrupted,0); g_retry_interrupted_count=0;
  }

bool RetryUIChartContextCurrent(const RetryReviewCandidate &c)
  {
   if(!c.valid) return false;
   if(c.chart_id != ChartID()) return false;
   if(c.account_login != AccountInfoInteger(ACCOUNT_LOGIN)) return false;
   if(c.account_server != AccountInfoString(ACCOUNT_SERVER)) return false;
   if(c.chart_symbol != ChartSymbol(0)) return false;
   if(c.chart_period != (int)Period()) return false;
   if(c.config_fingerprint != g_config_fingerprint) return false;
   return true;
  }

bool RetryUIFillReviewFromLedgerCandidate(const CExecutionLedger::RetryEligibleCandidate &src, RetryReviewCandidate &out, string &diag)
  {
   diag=""; ZeroMemory(out); out.valid=false;
   if(!src.valid) { diag="CANDIDATE_INVALID"; return false; }
   out.claim_id=src.claim_id; out.strategy_group_key=src.strategy_group_key; out.logical_setup_key=src.logical_setup_key;
   out.canonical_identity=src.canonical_identity; out.serialization_version=src.serialization_version;
   out.symbol=src.symbol; out.direction=src.direction; out.prior_attempt_id=src.prior_attempt_id; out.retry_sequence=src.retry_sequence;
   out.claim_state=src.claim_state; out.attempt_state=src.attempt_state; out.failure_class=src.failure_class; out.retcode=src.retcode;
   out.requested_volume=src.requested_volume; out.executed_volume=src.executed_volume; out.remaining_volume=src.remaining_volume;
   out.broker_order_ticket=src.broker_order_ticket; out.broker_deal_ticket=src.broker_deal_ticket; out.broker_position_ticket=src.broker_position_ticket;
   out.evidence_reason=src.evidence_summary;
   out.account_login=AccountInfoInteger(ACCOUNT_LOGIN); out.account_server=AccountInfoString(ACCOUNT_SERVER);
   out.chart_id=ChartID(); out.chart_symbol=ChartSymbol(0); out.chart_period=(int)Period();
   out.config_fingerprint=g_config_fingerprint; out.reviewed_at=TimeCurrent();
   out.valid=true;
   if(RetryUIChartContextCurrent(out))
      return true;
   diag="CHART_CONTEXT_INVALID";
   out.valid=false;
   return false;
  }

bool RetryUILoadCandidateList(string &diag)
  {
   diag=""; RetryUIClearCandidateList(); ZeroMemory(g_retry_review); g_retry_review.valid=false;
   if(!g_execution_ledger.IsAvailable()) { diag="LEDGER_UNAVAILABLE"; return false; }
   if(g_coordinator_mode != COORD_MODE_COORDINATOR) { diag="NOT_COORDINATOR"; return false; }
   string err="";
   int n = g_execution_ledger.GetRetryEligibleCandidates(g_retry_candidates, 10, err); // read-only, bounded, deterministic
   if(n < 0) { diag = (err=="" ? "CANDIDATE_DISCOVERY_FAILED" : err); RetryUIClearCandidateList(); return false; }
   g_retry_candidate_count = n;
   if(n <= 0) { diag="NO_ELIGIBLE_CANDIDATES"; g_retry_candidate_index=-1; return false; }
   g_retry_candidate_index = 0;
   return true;
  }

bool RetryUISameCandidateSnapshot(const RetryReviewCandidate &a, const RetryReviewCandidate &b)
  {
   if(!a.valid || !b.valid) return false;
   return (a.claim_id==b.claim_id && a.strategy_group_key==b.strategy_group_key && a.logical_setup_key==b.logical_setup_key &&
           a.canonical_identity==b.canonical_identity && a.serialization_version==b.serialization_version &&
           a.symbol==b.symbol && a.direction==b.direction && a.prior_attempt_id==b.prior_attempt_id && a.retry_sequence==b.retry_sequence &&
           a.claim_state==b.claim_state && a.attempt_state==b.attempt_state && a.failure_class==b.failure_class && a.retcode==b.retcode &&
           MathAbs(a.requested_volume-b.requested_volume)<=0.00000001 && MathAbs(a.executed_volume-b.executed_volume)<=0.00000001 &&
           MathAbs(a.remaining_volume-b.remaining_volume)<=0.00000001 && a.broker_order_ticket==b.broker_order_ticket &&
           a.broker_deal_ticket==b.broker_deal_ticket && a.broker_position_ticket==b.broker_position_ticket &&
           a.account_login==b.account_login && a.account_server==b.account_server && a.chart_id==b.chart_id &&
           a.chart_symbol==b.chart_symbol && a.chart_period==b.chart_period && a.config_fingerprint==b.config_fingerprint);
  }

bool RetryUIRefreshCandidate(RetryReviewCandidate &c, string &diag)
  {
   diag="";
   if(!c.valid) { diag="NO_CANDIDATE"; return false; }
   if(!RetryUIChartContextCurrent(c)) { diag="CHART_CONTEXT_CHANGED"; return false; }
   if(!g_execution_ledger.IsAvailable()) { diag="LEDGER_UNAVAILABLE"; return false; }
   // Read-only reload from durable ledger: find exact selected candidate in bounded eligible set.
   CExecutionLedger::RetryEligibleCandidate list[]; ArrayResize(list,0); string err="";
   int n = g_execution_ledger.GetRetryEligibleCandidates(list, 10, err);
   if(n < 0) { diag = (err=="" ? "CANDIDATE_RELOAD_FAILED" : err); return false; }
   for(int i=0;i<n;i++)
     {
       CExecutionLedger::RetryEligibleCandidate x = list[i];
       if(!x.valid) continue;
      if(x.claim_id==c.claim_id && x.strategy_group_key==c.strategy_group_key && x.logical_setup_key==c.logical_setup_key &&
         x.prior_attempt_id==c.prior_attempt_id && x.retry_sequence==c.retry_sequence)
        {
         RetryReviewCandidate fresh;
         if(!RetryUIFillReviewFromLedgerCandidate(x, fresh, diag)) { c.why_ineligible=diag; return false; }
         // preserve local context snapshot fields for comparison; fill helper sets current context.
         fresh.account_login=c.account_login; fresh.account_server=c.account_server; fresh.chart_id=c.chart_id;
         fresh.chart_symbol=c.chart_symbol; fresh.chart_period=c.chart_period; fresh.config_fingerprint=c.config_fingerprint;
         if(!RetryUIChartContextCurrent(fresh)) { diag="CHART_CONTEXT_CHANGED"; return false; }
         c = fresh; c.evidence_reason = x.evidence_summary; return true;
        }
     }
   diag="CANDIDATE_NO_LONGER_ELIGIBLE_OR_CHANGED";
   c.why_ineligible=diag;
   return false;
  }

void RetryUIRender()
  {
   if(!InpDashboard) { RetryUIClear(); return; }
   // EA-owned local controls only. Minimal bounded selection (Next cycles list). No broker calls.
   int x=16, y_base=140, bw=62, bh=20, gap=6;
   RetryUIEnsureLabel(g_retry_lbl_status, "E2.6 RETRY: " + g_retry_ui_status, x, y_base + bh*3 + gap*3 + 18, clrGold);
   string detail = g_retry_ui_detail;
   if(g_retry_review.valid)
     {
      detail = "cand[" + IntegerToString(g_retry_candidate_index+1) + "/" + IntegerToString(g_retry_candidate_count) + "] " +
               g_retry_review.symbol + " dir=" + IntegerToString(g_retry_review.direction) +
               " claim=" + g_retry_review.claim_id + " prior=" + g_retry_review.prior_attempt_id +
               " seq=" + IntegerToString(g_retry_review.retry_sequence) + " class=" + g_retry_review.failure_class +
               " ret=" + IntegerToString((int)g_retry_review.retcode) +
               " ord=" + IntegerToString((long)g_retry_review.broker_order_ticket) +
               " deal=" + IntegerToString((long)g_retry_review.broker_deal_ticket) +
               " pos=" + IntegerToString((long)g_retry_review.broker_position_ticket) +
               " ev=" + g_retry_review.evidence_reason + " | " + detail;
     }
   if(StringLen(detail)>160) detail = StringSubstr(detail,0,157)+"...";
   RetryUIEnsureLabel(g_retry_lbl_detail, detail, x, y_base + bh*3 + gap*3 + 4, clrSilver);
   RetryUIEnsureButton(g_retry_btn_review,  "Review",  x,                 y_base + bh + gap, bw, bh, clrDarkSlateGray, clrWhite);
   RetryUIEnsureButton(g_retry_btn_next,    "Next",    x + bw + gap,      y_base + bh + gap, bw, bh, (g_retry_candidate_count>1?clrSteelBlue:clrDimGray), clrWhite);
   bool can_confirm = (g_retry_ui_state == E2E6_UI_CONFIRM_READY && g_retry_review.valid);
   RetryUIEnsureButton(g_retry_btn_confirm, "Confirm", x + (bw+gap)*2,   y_base + bh + gap, bw, bh, can_confirm?clrDarkGreen:clrDimGray, clrWhite);
   RetryUIEnsureButton(g_retry_btn_cancel,  "Cancel",  x + (bw+gap)*3,   y_base + bh + gap, bw, bh, clrMaroon, clrWhite);
   RetryUIEnsureButton(g_retry_btn_inspect, "Inspect", x,                 y_base,             bw, bh, clrTeal, clrWhite);
   ChartRedraw(ChartID());
  }

void RetryUIEnsureObjects()
  {
   if(g_retry_ui_status=="") g_retry_ui_status="IDLE_NO_AUTO_RETRY";
   RetryUIRender();
  }

void RetryUISelectCurrentCandidate(bool advance)
  {
   string diag="";
   if(g_retry_candidate_count<=0 || ArraySize(g_retry_candidates)<=0)
     { RetryUIInvalidate("NO_ELIGIBLE_CANDIDATES"); g_retry_ui_state=E2E6_UI_BLOCKED; g_retry_ui_status="REVIEW_NO_CANDIDATES"; g_retry_ui_detail=(diag==""?"No eligible durable FINAL_FAILURE candidate.":diag); RetryUIRender(); return; }
   if(advance)
      g_retry_candidate_index = (g_retry_candidate_index + 1) % g_retry_candidate_count;
   if(g_retry_candidate_index < 0 || g_retry_candidate_index >= g_retry_candidate_count)
      g_retry_candidate_index = 0;
   RetryReviewCandidate sel;
   if(!RetryUIFillReviewFromLedgerCandidate(g_retry_candidates[g_retry_candidate_index], sel, diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED; g_retry_ui_status="REVIEW_CANDIDATE_INVALID"; g_retry_ui_detail=diag; RetryUIRender(); return; }
   // Reload selected exact candidate from durable ledger before confirmation-ready state.
   if(!RetryUIRefreshCandidate(sel, diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED; g_retry_ui_status="REVIEW_RELOAD_FAILED"; g_retry_ui_detail=diag; RetryUIRender(); return; }
   g_retry_review = sel;
   g_retry_ui_state = E2E6_UI_CONFIRM_READY;
   g_retry_ui_status = "REVIEW_READY_EXPLICIT_CONFIRM_REQUIRED";
   g_retry_ui_detail = "Durable candidate loaded from ledger; verify all safety fields before Confirm. No broker call.";
   RetryUIRender();
  }

void RetryUIHandleReviewClick()
  {
   if(g_retry_handoff.active)
     { g_retry_ui_status="REVIEW_BLOCKED_HANDOFF_ACTIVE"; g_retry_ui_detail="Transient committed handoff active (fail-closed, no auto-submit)."; RetryUIRender(); return; }
   RetryUIInvalidate("REVIEW_REQUESTED");
   g_retry_ui_state = E2E6_UI_BLOCKED;
   g_retry_ui_status = "REVIEW_LOADING";
   string diag="";
   if(!RetryUILoadCandidateList(diag))
     {
      g_retry_ui_status = "REVIEW_BLOCKED";
      g_retry_ui_detail = "Candidate discovery fail-closed: " + diag + ". No DB/broker mutation.";
      RetryUIRender();
      return;
     }
   RetryUISelectCurrentCandidate(false);
  }

void RetryUIHandleCancelClick()
  {
   // Cancel must have no ledger side effect.
   ZeroMemory(g_retry_review); g_retry_review.valid=false; RetryUIClearCandidateList();
   if(g_retry_handoff.active)
      g_retry_ui_detail = "Cancel UI only; committed-not-submitted handoff remains fail-closed (no auto-submit).";
   else
      g_retry_ui_detail = "Cancelled - no ledger side effect.";
   g_retry_ui_state = E2E6_UI_HIDDEN;
   g_retry_ui_status = "CANCELLED_NO_DB_MUTATION";
   RetryUIRender();
  }

bool RetryUIBuildLocalContext(CExecutionLedger::RetryLocalContext &ctx)
  {
   ZeroMemory(ctx);
   ctx.action_source = "LOCAL_CHART_OBJECT_CLICK";
   ctx.auth_model = "LOCAL_TERMINAL_SESSION_CONTEXT_ONLY";
   ctx.account_login = IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   ctx.account_server = AccountInfoString(ACCOUNT_SERVER);
   ctx.chart_id = ChartID();
   ctx.chart_symbol = ChartSymbol(0);
   ctx.chart_period = (int)Period();
   ctx.ea_program = MQLInfoString(MQL_PROGRAM_NAME);
   ctx.terminal_build = (int)TerminalInfoInteger(TERMINAL_BUILD);
   ctx.local_action_time = TimeCurrent();
   ctx.bounded_reason = "LOCAL_CHART_CONFIRM";
   return true;
  }

void RetryUIHandleConfirmClick()
  {
   // Double-click/repeated event protection and exact reviewed candidate required.
   if(g_retry_ui_state != E2E6_UI_CONFIRM_READY || !g_retry_review.valid)
     {
      g_retry_ui_status = "CONFIRM_REJECTED";
      g_retry_ui_detail = "No valid reviewed candidate; confirmation has no effect.";
      RetryUIRender();
      return;
     }
   RetryReviewCandidate reviewed_snapshot = g_retry_review; // immutable review snapshot
   if(!RetryUIChartContextCurrent(reviewed_snapshot))
     {
      RetryUIInvalidate("CONTEXT_CHANGED_BEFORE_CONFIRM");
      g_retry_ui_status = "INVALIDATED_CONTEXT_CHANGED";
      RetryUIRender();
      return;
     }
   string diag="";
   if(!RetryUIRefreshCandidate(g_retry_review, diag))
     {
      RetryUIInvalidate(diag);
      g_retry_ui_status = "INVALIDATED_BEFORE_CONFIRM";
      g_retry_ui_detail = diag;
      RetryUIRender();
      return;
     }
   // Confirm reload must compare complete immutable snapshot; no arbitrary caller IDs accepted.
   if(!RetryUISameCandidateSnapshot(reviewed_snapshot, g_retry_review))
     {
      RetryUIInvalidate("SNAPSHOT_CHANGED_AFTER_REVIEW");
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "CONFIRM_BLOCKED_SNAPSHOT_CHANGED";
      g_retry_ui_detail = "Durable candidate/evidence/context changed since Review; re-review required. No DB mutation.";
      RetryUIRender();
      return;
     }
   if(reviewed_snapshot.claim_id=="" || reviewed_snapshot.strategy_group_key=="" || reviewed_snapshot.logical_setup_key=="" || reviewed_snapshot.prior_attempt_id=="")
     {
      RetryUIInvalidate("MISSING_IMMUTABLE_IDS");
      g_retry_ui_status = "CONFIRM_BLOCKED_INVALID_IDS";
      RetryUIRender();
      return;
     }
   if(g_coordinator_mode != COORD_MODE_COORDINATOR)
     {
      g_retry_ui_status = "CONFIRM_BLOCKED_NOT_COORDINATOR"; RetryUIRender(); return;
     }
   string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(!g_execution_ledger.ValidateAuthority(auth_key, g_owner_instance_token, g_authority_epoch))
     {
      g_retry_ui_status = "CONFIRM_BLOCKED_AUTHORITY"; g_retry_ui_detail="Fresh durable authority validation failed."; RetryUIRender(); return;
     }
   g_executor.SyncAuthority(g_authority_epoch, true);

   CExecutionLedger::RetryLocalContext ctx;
   RetryUIBuildLocalContext(ctx);
   ExecutionAttemptRecord new_attempt; ZeroMemory(new_attempt);
   string action_id="", detail="";
   CExecutionLedger::ENUM_RETRY_APPROVE_RESULT res = g_execution_ledger.ApproveAndCreateRetry(
      g_retry_review.claim_id, g_retry_review.strategy_group_key, g_retry_review.logical_setup_key,
      g_retry_review.prior_attempt_id, g_retry_review.retry_sequence,
      ctx, g_retry_review.evidence_reason, new_attempt, action_id, detail);
   // No broker call from UI path.
   if(res == CExecutionLedger::RETRY_APPROVE_COMMITTED || res == CExecutionLedger::RETRY_APPROVE_ALREADY_CONSUMED)
     {
      ZeroMemory(g_retry_handoff); g_retry_handoff.active=true;
      g_retry_handoff.action_id = action_id;
      g_retry_handoff.claim_id = g_retry_review.claim_id;
      g_retry_handoff.strategy_group_key = g_retry_review.strategy_group_key;
      g_retry_handoff.logical_setup_key = g_retry_review.logical_setup_key;
      g_retry_handoff.prior_attempt_id = g_retry_review.prior_attempt_id;
      g_retry_handoff.new_attempt_id = new_attempt.attempt_id;
      g_retry_handoff.expected_retry_sequence = g_retry_review.retry_sequence;
      g_retry_handoff.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
      g_retry_handoff.account_server = AccountInfoString(ACCOUNT_SERVER);
      g_retry_handoff.config_fingerprint = g_config_fingerprint;
      g_retry_handoff.created_at = TimeCurrent();
      g_retry_ui_state = E2E6_UI_COMMITTED;
      g_retry_ui_status = (res==CExecutionLedger::RETRY_APPROVE_ALREADY_CONSUMED) ? "ALREADY_CONSUMED_READBACK_OK" : "COMMITTED_NOT_SUBMITTED";
      g_retry_ui_detail = detail + " | pending revalidation in timer; no broker call from UI; no auto-retry on restart.";
      ZeroMemory(g_retry_review); g_retry_review.valid=false;
     }
   else if(res == CExecutionLedger::RETRY_APPROVE_COMMIT_OUTCOME_UNKNOWN)
     {
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "COMMIT_OUTCOME_UNKNOWN";
      g_retry_ui_detail = detail + " | action_id="+action_id+" read-back required; same op blocked.";
     }
   else
     {
      RetryUIInvalidate(detail);
      g_retry_ui_status = "APPROVAL_REJECTED_FAIL_CLOSED";
      g_retry_ui_detail = detail;
     }
   RetryUIRender();
  }

void RetryUIHandleNextClick()
  {
   if(g_retry_handoff.active)
     { g_retry_ui_status="NEXT_BLOCKED_HANDOFF_ACTIVE"; RetryUIRender(); return; }
   if(g_retry_candidate_count <= 0)
     { RetryUIHandleReviewClick(); return; }
   // Re-load list and reselect next deterministically (bounded). No DB writes.
   int prev = g_retry_candidate_index; string diag="";
   if(!RetryUILoadCandidateList(diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED; g_retry_ui_status="NEXT_DISCOVERY_FAILED"; g_retry_ui_detail=diag; RetryUIRender(); return; }
   g_retry_candidate_index = (prev + 1) % g_retry_candidate_count;
   RetryUISelectCurrentCandidate(false);
  }


void RetryUILoadInterruptedList(bool render)
  {
   ArrayResize(g_retry_interrupted,0); g_retry_interrupted_count=0;
   if(!g_execution_ledger.IsAvailable())
     {
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "LEDGER_UNAVAILABLE_EXECUTION_BLOCKED";
      g_retry_ui_detail = "Cannot inspect durable retry handoffs: ledger unavailable (fail-closed). No auto-submit.";
      if(render) RetryUIRender();
      return;
     }
   string err="", login=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)), server=AccountInfoString(ACCOUNT_SERVER);
   int n = g_execution_ledger.GetInterruptedRetryHandoffs(login, server, g_strategy_group_key, g_retry_interrupted, 5, err);
   if(n < 0)
     {
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "INTERRUPTED_QUERY_FAILED_FAIL_CLOSED";
      g_retry_ui_detail = (err==""?"Interrupted retry query failed":err) + " - no auto-submit/restore.";
      if(render) RetryUIRender();
      return;
     }
   g_retry_interrupted_count = n;
   if(n <= 0)
     {
      if(g_retry_ui_state == E2E6_UI_INTERRUPTED_VIEW)
        { g_retry_ui_state = E2E6_UI_HIDDEN; g_retry_ui_status="NO_INTERRUPTED_RETRY_FOUND"; g_retry_ui_detail="Read-only inspection: no durable interrupted retry handoff records in current account/group context."; }
      if(render) RetryUIRender();
      return;
     }
   // Read-only visibility only. Never restore handoff, never submit, never create approval/retry.
   g_retry_ui_state = E2E6_UI_INTERRUPTED_VIEW;
   ZeroMemory(g_retry_review); g_retry_review.valid=false; RetryUIClearCandidateList();
   g_retry_ui_status = "INTERRUPTED_DURABLE_RETRY_" + g_retry_interrupted[0].status_code;
   g_retry_ui_detail = "claim=" + g_retry_interrupted[0].claim_id + " prior=" + g_retry_interrupted[0].prior_attempt_id + " new=" + g_retry_interrupted[0].new_attempt_id +
                       " seq=" + IntegerToString(g_retry_interrupted[0].retry_sequence_before) + "->" + IntegerToString(g_retry_interrupted[0].retry_sequence_after) +
                       " state=" + IntegerToString(g_retry_interrupted[0].new_attempt_state) +
                       " approval=" + (g_retry_interrupted[0].approval_event_exists?"1":"0") +
                       " submitted=" + (g_retry_interrupted[0].submitted_recorded?"1":"0") +
                       " may_have=" + (g_retry_interrupted[0].submission_may_have_occurred?"1":"0") +
                       " recon=" + (g_retry_interrupted[0].reconciliation_required?"1":"0") +
                       " | " + g_retry_interrupted[0].detail + " [rows="+IntegerToString(n)+" read-only,no restore,no auto-submit]";
   if(render) RetryUIRender();
  }

void RetryUIHandleInspectInterruptedClick()
  {
   // Read-only inspect/refresh. No handoff recreation, no approval reuse, no retry creation,
   // no attempt/claim state change, no claim release, no broker executor, no bypass.
   RetryUILoadInterruptedList(true);
  }

void RetryUIOnObjectClick(const string sparam)
  {
   if(StringFind(sparam, E2E6_RETRY_OBJ_PREFIX) != 0)
      return; // not our object
   // Only EA-owned exact prefix objects accepted; reset button state.
   if(ObjectFind(ChartID(),sparam) < 0)
      return;
   ObjectSetInteger(ChartID(),sparam,OBJPROP_STATE,false);
   if(sparam == g_retry_btn_review)       RetryUIHandleReviewClick();
   else if(sparam == g_retry_btn_next)    RetryUIHandleNextClick();
   else if(sparam == g_retry_btn_confirm) RetryUIHandleConfirmClick();
   else if(sparam == g_retry_btn_cancel)  RetryUIHandleCancelClick();
   else if(sparam == g_retry_btn_inspect) RetryUIHandleInspectInterruptedClick();
   // ignore other owned objects
  }

int RetryUIFindRuntimeForSymbol(const string symbol)
  {
   if(symbol=="") return -1;
   for(int i=0;i<ArraySize(g_runtime);i++)
      if(g_runtime[i].valid && g_runtime[i].symbol==symbol) return i;
   return -1;
  }

bool RetryUIBuildAttemptRecordFromFreshPlan(const string attempt_id,
                                            const string setup_id,
                                            const string symbol,
                                            ulong magic,
                                            const TradePlan &plan,
                                            const RiskDecision &risk,
                                            ExecutionAttemptRecord &out)
  {
   ZeroMemory(out);
   out.attempt_id = attempt_id; out.setup_id = setup_id; out.symbol = symbol; out.magic = magic;
   out.intent = (plan.direction==SIGNAL_LONG ? ORDER_INTENT_OPEN_LONG : ORDER_INTENT_OPEN_SHORT);
   out.direction = plan.direction; out.requested_volume = risk.calculated_volume;
   out.entry_price = plan.entry; out.stop_loss = plan.stop; out.take_profit = plan.target;
   out.state = EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED; out.submission_allowed=false;
   return (attempt_id!="" && setup_id!="" && symbol!="" && plan.valid);
  }

bool RetryUIBuildLegacySignal(const TradePlan &plan, const HybridDecision &decision, StrategySignal &legacy_signal)
  {
   ZeroMemory(legacy_signal);
   if(!plan.valid) return false;
   legacy_signal.valid=true; legacy_signal.direction=plan.direction; legacy_signal.strategy=STRATEGY_TREND_PULLBACK;
   legacy_signal.symbol=plan.symbol; legacy_signal.timeframe=PERIOD_CURRENT; legacy_signal.regime=(ENUM_REGIME_TYPE)decision.regime;
   legacy_signal.score=(plan.direction==SIGNAL_LONG)?decision.long_score:decision.short_score;
   legacy_signal.confidence=1.0; legacy_signal.entry=plan.entry; legacy_signal.stop=plan.stop; legacy_signal.target=plan.target;
   legacy_signal.timestamp=plan.signal_time; legacy_signal.signal_id=plan.setup_id; legacy_signal.reason=decision.main_reason;
   return true;
  }

bool RetryUIRevalidateFreshPlan(CSymbolRuntime &runtime,
                                const ExecutionAttemptRecord &new_att,
                                const string expected_group_key,
                                const string expected_lsk,
                                const string expected_config_fingerprint,
                                TradePlan &out_plan,
                                StrategySignal &out_legacy,
                                RiskDecision &out_risk,
                                string &reason)
  {
   reason="";
   if(!runtime.valid || runtime.symbol!=new_att.symbol) { reason="RUNTIME_SYMBOL_MISMATCH"; return false; }
   if(expected_group_key=="" || expected_lsk=="" || expected_group_key!=g_strategy_group_key) { reason="GROUP_KEY_MISMATCH"; return false; }
   if(expected_config_fingerprint!=g_config_fingerprint) { reason="CONFIG_FINGERPRINT_CHANGED"; return false; }
   if(!g_session_filter.IsAllowed(TimeCurrent())) { reason="SESSION_FILTER_BLOCKED"; return false; }

   MarketSnapshot context_market, structure_market, setup_market, entry_market;
   FeatureSet context_features, structure_features, setup_features, entry_features;
   ResetLastError();
   if(!runtime.market_context.GetSnapshot(runtime.symbol,runtime.context_tf,context_market) || !context_market.valid) { reason="FRESH_CONTEXT_SNAPSHOT_FAILED"; return false; }
   if(!runtime.market_structure.GetSnapshot(runtime.symbol,runtime.structure_tf,structure_market) || !structure_market.valid) { reason="FRESH_STRUCTURE_SNAPSHOT_FAILED"; return false; }
   if(!runtime.market_setup.GetSnapshot(runtime.symbol,runtime.setup_tf,setup_market) || !setup_market.valid) { reason="FRESH_SETUP_SNAPSHOT_FAILED"; return false; }
   if(!runtime.market_entry.GetSnapshot(runtime.symbol,runtime.entry_tf,entry_market) || !entry_market.valid) { reason="FRESH_ENTRY_SNAPSHOT_FAILED"; return false; }
   if(!runtime.feature_context.Calculate(context_market,context_features)) { reason="FRESH_CONTEXT_FEATURES_FAILED"; return false; }
   if(!runtime.feature_structure.Calculate(structure_market,structure_features)) { reason="FRESH_STRUCTURE_FEATURES_FAILED"; return false; }
   if(!runtime.feature_setup.Calculate(setup_market,setup_features)) { reason="FRESH_SETUP_FEATURES_FAILED"; return false; }
   if(!runtime.feature_entry.Calculate(entry_market,entry_features)) { reason="FRESH_ENTRY_FEATURES_FAILED"; return false; }

   PortfolioState portfolio_state;
   if(!RefreshTradingState() || !g_state.GetPortfolioState(portfolio_state)) { reason="RISK_STATE_UNAVAILABLE"; return false; }
   if(portfolio_state.trading_locked) { reason="RISK_LOCK_ACTIVE"; return false; }

   bool ok=false;
   FeatureContext ctx = runtime.hybrid_engine.BuildFeatureContext(context_market,structure_market,setup_market,entry_market,
                          context_features,structure_features,setup_features,entry_features,portfolio_state,ok);
   if(!ok || !ctx.valid) { reason="CONTEXT_BUILD_FAILED:"+ctx.reason; return false; }

   // Read-only binding probe: preserve engine duplicate-suppression state (Evaluate mutates it on candidate plans).
   datetime dup_t=0; ENUM_SIGNAL_DIRECTION dup_d=SIGNAL_NONE; bool dup_c=false;
   runtime.hybrid_engine.SaveDuplicateState(dup_t,dup_d,dup_c);
   HybridDecision decision = runtime.hybrid_engine.Evaluate(runtime.symbol, ctx, context_market, ok);
   runtime.hybrid_engine.RestoreDuplicateState(dup_t,dup_d,dup_c);
   if(!ok || !decision.valid) { reason="FRESH_EVALUATION_FAILED:"+decision.main_reason; return false; }
   if(decision.status != DECISION_BUY_CANDIDATE && decision.status != DECISION_SELL_CANDIDATE) { reason="FRESH_PLAN_NOT_CANDIDATE:"+decision.main_reason; return false; }
   if(!decision.plan.valid) { reason="FRESH_PLAN_INVALID"; return false; }

   TradePlan plan = decision.plan;
   // Exact logical-setup binding against durable claim + originating closed bar.
   string expected_binding = runtime.hybrid_engine.BuildBindingKey(setup_market.closed_bar_time, plan.direction);
   string fresh_lsk = runtime.hybrid_engine.ComputeLogicalSetupKey(setup_market.closed_bar_time, plan.direction, runtime.setup_tf);
   string fresh_can = CExecutionLedger::BuildStableCanonicalIdentity(g_strategy_group_key, runtime.symbol, "DEFAULT_SETUP",
                        (int)plan.direction, setup_market.closed_bar_time, (int)runtime.setup_tf, 2);
   // Claim canonical comparison uses stable components via ledger helper after DB lookup below.
   if(fresh_lsk != expected_lsk) { reason="LOGICAL_SETUP_KEY_MISMATCH fresh="+fresh_lsk+" expected="+expected_lsk; return false; }
   // Verify claim still exists and current attempt unchanged; canonical stable identity must match.
   string claim_id="", current_attempt=""; int claim_state=-1;
   if(!g_execution_ledger.GetSetupClaim(expected_group_key, expected_lsk, claim_id, claim_state, current_attempt)) { reason="CLAIM_LOOKUP_FAILED"; return false; }
   // GetSetupClaim does not return canonical; reuse bounded discovery read-back by exact ids not available here. Use GetClaimById for binding and rely on same LSK/group.
   int cs=-1, rs=-1; string ca="";
   if(!g_execution_ledger.GetClaimById(g_retry_handoff.claim_id, expected_group_key, expected_lsk, cs, ca, rs)) { reason="CLAIM_BY_ID_LOOKUP_FAILED"; return false; }
   if(ca != g_retry_handoff.new_attempt_id) { reason="CLAIM_CURRENT_ATTEMPT_CHANGED"; return false; }
   if(rs != g_retry_handoff.expected_retry_sequence + 1) { reason="CLAIM_RETRY_SEQUENCE_CHANGED"; return false; }
   if(cs != (int)SETUP_CLAIM_ACTIVE) { reason="CLAIM_NOT_ACTIVE"; return false; }

   if(plan.symbol!=runtime.symbol || plan.style!=runtime.style || plan.direction==SIGNAL_NONE || plan.setup_id=="" || plan.signal_time<=0 || plan.entry<=0.0 || plan.stop<=0.0 || plan.target<=0.0)
     { reason="FRESH_PLAN_CONSISTENCY_FAILED"; return false; }
   if(plan.signal_time != setup_market.closed_bar_time) { reason="SIGNAL_TIME_NOT_ORIGINATING_CLOSED_BAR"; return false; }
   if(expected_binding=="" || fresh_lsk=="") { reason="BINDING_KEY_EMPTY"; return false; }

   if(runtime.hybrid_engine.IsPlanExpired(plan, TimeCurrent())) { reason="FRESH_PLAN_EXPIRED"; return false; }
   double struct_price=plan.entry;
   ENUM_STRUCTURAL_EVIDENCE_RESULT struct_res = runtime.hybrid_engine.EvaluateStructuralEvidence(plan, struct_price);
   if(struct_res != EVIDENCE_SUFFICIENT_NO_INVALIDATION) { reason="STRUCTURAL_EVIDENCE_BLOCK:"+EnumToString(struct_res); return false; }
   if(!runtime.hybrid_engine.IsSetupFresh(plan.signal_time)) { reason="FRESH_SETUP_STALE"; return false; }

   TradePlan normalized_plan = plan; string norm_reason="";
   if(!NormalizeTradePlanStops(normalized_plan, norm_reason)) { reason="STOP_NORMALIZE_FAILED:"+norm_reason; return false; }
   MqlTick tick; if(!SymbolInfoTick(runtime.symbol,tick)) { reason="TICK_UNAVAILABLE"; return false; }
   double current_price = (normalized_plan.direction==SIGNAL_LONG ? tick.ask : tick.bid);
   double max_entry_dist = GetEntryDistanceTolerance(runtime.style, runtime.hybrid_engine.GetPoint());
   if(MathAbs(normalized_plan.entry-current_price) > max_entry_dist) { reason="ENTRY_TOO_FAR"; return false; }

   // Preserve normal Risk/Portfolio/News gate chain (shared logic path) without duplicating alternate policy.
   StrategySignal legacy_signal;
   if(!RetryUIBuildLegacySignal(normalized_plan, decision, legacy_signal)) { reason="LEGACY_SIGNAL_BUILD_FAILED"; return false; }
   RiskDecision risk;
   if(!g_risk_engine.Evaluate(legacy_signal, risk)) { reason="RISK_ENGINE_REJECT:"+EnumToString(risk.rejection_reason); return false; }
   if(!g_portfolio_risk.CanOpen(legacy_signal, risk)) { reason="PORTFOLIO_RISK_REJECT:"+g_portfolio_risk.LastRejectionReason(); return false; }
   // News gate is inside HybridEngine CheckHardGates for Evaluate; decision reached candidate => entry news clear.
   // We still fail closed if engine marked news block in decision status (defensive).
   if(decision.status == DECISION_NEWS_BLOCKED) { reason="NEWS_ENTRY_BLOCKED"; return false; }

   if(risk.calculated_volume <= 0.0) { reason="RISK_VOLUME_INVALID"; return false; }
   // Ensure fresh plan is not consumed marker in probe result.
   normalized_plan.consumed=false;
   out_plan = normalized_plan; out_legacy = legacy_signal; out_risk = risk;
   reason = "FRESH_REVALIDATION_OK binding="+expected_binding+" lsk="+fresh_lsk+" can="+fresh_can;
   return true;
  }

void ProcessRetryPendingHandoff()
  {
   // Transient handoff only; crash/restart loses it => no auto-retry.
   if(!g_retry_handoff.active) return;
   // Never broker-submit from chart event; run in timer path only.
   if(g_coordinator_mode != COORD_MODE_COORDINATOR) { g_retry_ui_status="HANDOFF_BLOCKED_NOT_COORDINATOR"; return; }
   if(g_retry_handoff.account_login != AccountInfoInteger(ACCOUNT_LOGIN) ||
      g_retry_handoff.account_server != AccountInfoString(ACCOUNT_SERVER) ||
      g_retry_handoff.config_fingerprint != g_config_fingerprint)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_INVALIDATED_CONTEXT"; g_retry_ui_detail="Context changed; transient handoff cleared; no submit."; return; }
   string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(!g_execution_ledger.ValidateAuthority(auth_key, g_owner_instance_token, g_authority_epoch))
     { g_retry_ui_status="HANDOFF_BLOCKED_AUTHORITY"; return; }
   g_executor.SyncAuthority(g_authority_epoch, true);

   // Read-back durable outcome by deterministic action id.
   string outcome="", rb_new="";
   if(!g_execution_ledger.GetRetryApprovalEventOutcome(g_retry_handoff.action_id, outcome, rb_new) || outcome=="")
     { g_retry_ui_status="HANDOFF_COMMIT_UNKNOWN_BLOCKED"; g_retry_ui_detail="Cannot verify approval event; blocked fail-closed."; return; }
   if(rb_new != "" && g_retry_handoff.new_attempt_id == "") g_retry_handoff.new_attempt_id = rb_new;
   if(rb_new != "" && rb_new != g_retry_handoff.new_attempt_id)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_IDENTITY_MISMATCH"; return; }

   int claim_state=-1, retry_seq=-1; string current_attempt="";
   if(!g_execution_ledger.GetClaimById(g_retry_handoff.claim_id,g_retry_handoff.strategy_group_key,g_retry_handoff.logical_setup_key,claim_state,current_attempt,retry_seq))
     { g_retry_ui_status="HANDOFF_CLAIM_RELOAD_FAILED"; return; }
   if(current_attempt != g_retry_handoff.new_attempt_id || retry_seq != g_retry_handoff.expected_retry_sequence + 1)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_CLAIM_ADVANCED_OR_CHANGED"; g_retry_ui_detail="Claim no longer points to committed new attempt; no submit."; return; }
   ExecutionAttemptRecord new_att;
   if(!g_execution_ledger.GetAttempt(g_retry_handoff.new_attempt_id, new_att))
     { g_retry_ui_status="HANDOFF_ATTEMPT_RELOAD_FAILED"; return; }
   if(new_att.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_ATTEMPT_NOT_SUBMITTABLE"; g_retry_ui_detail="Attempt state="+IntegerToString((int)new_att.state); return; }
   string submit_reason="";
   if(!g_execution_ledger.CanSubmit(g_retry_handoff.new_attempt_id, submit_reason))
     { g_retry_ui_status="HANDOFF_CANNOT_SUBMIT"; g_retry_ui_detail=submit_reason; return; }

   // P1-C: fresh runtime evaluation + exact binding + full pre-submit revalidation, then existing submission protocol.
   int rt_idx = RetryUIFindRuntimeForSymbol(new_att.symbol);
   if(rt_idx < 0) { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_RUNTIME_NOT_FOUND"; g_retry_ui_detail="No valid runtime for approved symbol; committed intent remains non-submitted/quarantined by operator workflow (no auto-retry)."; return; }
   TradePlan fresh_plan; StrategySignal fresh_signal; RiskDecision fresh_risk; string reval_reason="";
   if(!RetryUIRevalidateFreshPlan(g_runtime[rt_idx], new_att, g_retry_handoff.strategy_group_key, g_retry_handoff.logical_setup_key, g_retry_handoff.config_fingerprint,
                                  fresh_plan, fresh_signal, fresh_risk, reval_reason))
     {
      // One-shot handoff consumed on this explicit-confirm session attempt; do NOT auto-retry/reuse confirmation.
      // Committed new intent remains durable/non-submitted; not marked FINAL_FAILURE (no terminal failure evidence).
      g_retry_handoff.active=false;
      g_retry_ui_status = "HANDOFF_REVALIDATION_FAILED_FAIL_CLOSED";
      g_retry_ui_detail = "Fresh revalidation/binding failed: " + reval_reason + ". Intent committed durable, NOT submitted, NOT auto-retried; operator reconciliation required if blocked.";
      g_logger.Event(LOG_WARNING,"EXECUTION","RETRY_HANDOFF_REVALIDATION_FAILED", new_att.symbol,"",g_retry_handoff.logical_setup_key,g_retry_handoff.new_attempt_id,"BLOCKED","FRESH_REVALIDATION",reval_reason + " action="+g_retry_handoff.action_id);
      // Fail-closed visibility only: mark reconciliation required for this committed-not-submitted attempt (no broker call, no claim release).
      g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id, "E2.6 retry handoff revalidation failed (fail-closed, no submit, no auto-retry): " + reval_reason);
      return;
     }

   // Final context checks immediately before submission protocol (stale-after-validation => reject).
   if(g_coordinator_mode != COORD_MODE_COORDINATOR) { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_COORDINATOR_LOST"; return; }
   if(g_retry_handoff.account_login != AccountInfoInteger(ACCOUNT_LOGIN) || g_retry_handoff.account_server != AccountInfoString(ACCOUNT_SERVER) || g_retry_handoff.config_fingerprint != g_config_fingerprint)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_CONTEXT_CHANGED"; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Final context changed before submit"); return; }
   if(!g_execution_ledger.ValidateAuthority(auth_key, g_owner_instance_token, g_authority_epoch))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_AUTHORITY_FAILED"; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Final authority validation failed before submit"); return; }
   g_executor.SyncAuthority(g_authority_epoch, true);
   if(g_execution_ledger.HasBlockingUnresolved(g_retry_ui_detail) || g_execution_ledger.HasUnresolvedForSymbol(new_att.symbol, true))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_UNRESOLVED_BLOCK"; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Unresolved/ledger block before submit"); return; }
   // Re-read attempt immediately before bind/submit.
   if(!g_execution_ledger.GetAttempt(g_retry_handoff.new_attempt_id, new_att) || new_att.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_ATTEMPT_CHANGED"; return; }
   string final_submit_reason="";
   if(!g_execution_ledger.CanSubmit(g_retry_handoff.new_attempt_id, final_submit_reason))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_CANNOT_SUBMIT"; g_retry_ui_detail=final_submit_reason; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"CanSubmit failed before submit: "+final_submit_reason); return; }

   // Build fresh ExecutionRequest bound to new attempt ID (not old plan/request).
   ExecutionRequest request;
   request.intent = (fresh_plan.direction==SIGNAL_LONG ? ORDER_INTENT_OPEN_LONG : ORDER_INTENT_OPEN_SHORT);
   request.symbol = g_runtime[rt_idx].symbol;
   request.direction = fresh_plan.direction;
   request.strategy = STRATEGY_TREND_PULLBACK;
   request.volume = fresh_risk.calculated_volume;
   request.price = fresh_plan.entry;
   request.stop_loss = fresh_plan.stop;
   request.take_profit = fresh_plan.target;
   request.position_ticket = 0;
   request.magic = MagicForStyle(g_runtime[rt_idx].style);
   request.comment = "E26_RETRY|" + g_retry_handoff.action_id;
   request.signal_id = fresh_plan.setup_id;
   request.attempt_id = g_retry_handoff.new_attempt_id;

   if(!g_execution_ledger.MarkSubmissionBound(request.attempt_id, "E2.6 retry pre-submit revalidation passed action="+g_retry_handoff.action_id))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_BIND_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"MarkSubmissionBound failed (no broker call)"); return; }
   if(!g_execution_ledger.CanSubmit(request.attempt_id, final_submit_reason))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_SUBMIT_GATE_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"CanSubmit failed after bind: "+final_submit_reason); return; }
   if(!g_execution_ledger.MarkSubmissionMayHaveOccurred(request.attempt_id, "E2.6 retry broker boundary action="+g_retry_handoff.action_id))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_MAY_HAVE_OCCURRED_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"MarkSubmissionMayHaveOccurred failed; broker call aborted"); return; }

   ExecutionResult result; ZeroMemory(result);
   bool execution_ok = g_executor.Execute(request, result); // broker call only via executor (timer path)
   g_logger.Trade(result);
   if(!result.success && result.failure_class == "AUTHORIZATION_DENIED" && !result.reconciliation_required)
     {
      if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "E2.6 retry executor auth denied - confirmed no broker invocation"))
         g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "ResolveAttempt failed after confirmed executor auth denial");
      g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_SUBMIT_AUTH_DENIED"; return;
     }
   bool result_recorded = g_execution_ledger.RecordResult(request.attempt_id, result, "E2.6 retry executor result action="+g_retry_handoff.action_id);
   if(!result_recorded)
     {
      g_logger.Event(LOG_ERROR, "EXECUTION", "RETRY_RECORD_RESULT_FAILED", request.symbol, "", g_retry_handoff.logical_setup_key, request.attempt_id, "FAIL", "LEDGER_ERROR",
                     "RecordResult failed after retry broker/result observation; forcing reconciliation (no retry, no FINAL_FAILURE fabrication)");
      bool recon_ok = g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "E2.6 retry RecordResult write failed - reconciliation required (no retry)");
      if(!recon_ok)
        {
         ENUM_EXEC_ATTEMPT_STATE st = EXEC_STATE_NONE;
         bool st_ok = g_execution_ledger.GetAttemptState(request.attempt_id, st);
         bool blocked = false; string block_reason="";
         if(st_ok)
            blocked = (st==EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED || st==EXEC_STATE_RECONCILIATION_REQUIRED || st==EXEC_STATE_PARTIAL_FILL || st==EXEC_STATE_SUBMITTED || st==EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED);
         else
            blocked = g_execution_ledger.HasBlockingUnresolved(block_reason);
         g_logger.Event(LOG_ERROR, "EXECUTION", "RETRY_RECONCILIATION_MARK_FAILED_AFTER_RECORD_RESULT", request.symbol, "", g_retry_handoff.logical_setup_key, request.attempt_id, "FAIL", "LEDGER_ERROR",
                        "MarkReconciliationRequired failed after retry RecordResult failure; claim="+g_retry_handoff.claim_id+" state_readable="+(st_ok?"1":"0")+" state="+IntegerToString((int)st)+" blocking="+(blocked?"1":"0")+" reason="+block_reason+" (no retry, no FINAL_FAILURE)");
        }
     }
   {
    ENUM_EXEC_ATTEMPT_STATE st=EXEC_STATE_NONE;
    if(g_execution_ledger.GetAttemptState(request.attempt_id, st))
      {
       if(st==EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
          g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"Retry attempt not bound before execution");
       else if(st==EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED)
          g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"Retry submission still ambiguous after recorded result");
      }
    else if(!result_recorded)
      {
       g_logger.Event(LOG_ERROR, "EXECUTION", "RETRY_LEDGER_STATE_UNREADABLE", request.symbol, "", g_retry_handoff.logical_setup_key, request.attempt_id, "FAIL", "LEDGER_ERROR",
                      "Attempt state unreadable after retry RecordResult failure - ledger trust degraded; fail-closed by blocking checks");
      }
   }
   // Consume only this fresh plan's local engine duplicate-suppression marker for the same runtime context.
   // Do not consume stale historical plan; this is the fresh plan produced by revalidation.
   g_runtime[rt_idx].hybrid_engine.MarkPlanConsumed(fresh_plan);
   g_retry_handoff.active=false;
   g_retry_ui_status = (execution_ok && result.success) ? "HANDOFF_SUBMITTED" : "HANDOFF_SUBMIT_RECORDED_FAIL_OR_AMBIG";
   g_retry_ui_detail = reval_reason + " submit_ok=" + (execution_ok?"1":"0") + " ret=" + IntegerToString((int)result.retcode) + " recon=" + (result.reconciliation_required?"1":"0");
   g_logger.Event(execution_ok?LOG_INFO:LOG_WARNING,"EXECUTION","RETRY_HANDOFF_SUBMIT", request.symbol,"",g_retry_handoff.logical_setup_key,request.attempt_id,execution_ok?"SUBMIT":"FAIL_OR_AMBIG","E2.6_RETRY",g_retry_ui_detail);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // E2.6: invalidate local retry review on geometry/context-affecting events (no ledger/broker mutation).
   RetryUIInvalidate("CHART_GEOMETRY_CHANGED");
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      g_dashboard.HandleChartGeometryChange();
      RetryUIEnsureObjects();
     }
   // E2.6: local MT5 chart approval (OBJ_BUTTON). No broker calls. Only EA-owned objects.
   else if(id == CHARTEVENT_OBJECT_CLICK)
     {
      RetryUIOnObjectClick(sparam);
     }
   // E2.3-RD: Chart Context Registration protocol
   string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(id == CHARTEVENT_CUSTOM + CHARTREG_DISCOVERY)
     {
      // Chart Context receives discovery probe from Coordinator
      if(g_coordinator_mode != COORD_MODE_CHART_CONTEXT && g_coordinator_mode != COORD_MODE_UNINITIALIZED)
         return;
      string parts[];
      int n = StringSplit(sparam, '|', parts);
      if(n < 6)
         return;
      if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
         return;
      if(parts[2] != auth_key)
         return;
      long coord_chart = (long)StringToInteger(parts[3]);
      long coord_epoch = (long)StringToInteger(parts[4]);
      string disc_nonce = parts[5];
      g_pending_coord_chart = coord_chart;
      g_pending_coord_epoch = coord_epoch;
      g_pending_nonce = disc_nonce;
      g_reg_state = REG_STATE_PENDING;
      string reg = "R|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + auth_key + "|" +
                   IntegerToString((long)ChartID()) + "|" + g_owner_instance_token + "|" +
                   g_strategy_group_key + "|" + g_config_fingerprint + "|" +
                   IntegerToString(coord_chart) + "|" + IntegerToString(coord_epoch) + "|" + disc_nonce;
      if(StringLen(reg) <= 63)
        {
         if(!EventChartCustom(coord_chart, CHARTREG_REGISTER, (long)ChartID(), 0.0, reg))
           {
            // enqueue failed
           }
         else
           {
            g_last_reg_request = TimeCurrent();
            g_reg_retry_count = 0;
           }
        }
     }
   else if(id == CHARTEVENT_CUSTOM + CHARTREG_REGISTER)
     {
      // Coordinator receives registration request
      if(g_coordinator_mode != COORD_MODE_COORDINATOR)
         return;
      string parts[];
      int n = StringSplit(sparam, '|', parts);
      if(n < 10)
         return;
      if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
         return;
      if(parts[2] != auth_key)
         return;
      long req_chart = (long)StringToInteger(parts[3]);
      string req_token = parts[4];
      string req_group = parts[5];
      string req_fp = parts[6];
      long target_coord = (long)StringToInteger(parts[7]);
      long target_epoch = (long)StringToInteger(parts[8]);
      string req_nonce = parts[9];
      if(target_coord != ChartID())
         return;
      if(target_epoch != g_authority_epoch)
         return;
      // Group-level config conflict check
      bool conflict = false;
      for(int i = 0; i < g_subscriber_count; i++)
        {
         if(g_subscribers[i].strategy_group_key == req_group &&
            g_subscribers[i].config_fingerprint != req_fp)
           {
            conflict = true;
            break;
           }
        }
      if(conflict)
         return;
      // Idempotent registration
      bool found = false;
      for(int i = 0; i < g_subscriber_count; i++)
        {
         if(g_subscribers[i].chart_id == req_chart && g_subscribers[i].owner_token == req_token)
           {
            found = true;
            break;
           }
        }
      if(!found && g_subscriber_count < 64)
        {
         g_subscribers[g_subscriber_count].chart_id = req_chart;
         g_subscribers[g_subscriber_count].owner_token = req_token;
         g_subscribers[g_subscriber_count].strategy_group_key = req_group;
         g_subscribers[g_subscriber_count].config_fingerprint = req_fp;
         g_subscribers[g_subscriber_count].registered = true;
         g_subscriber_count++;
        }
      // Send ACK with nonce
      string ack = "A|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + auth_key + "|" +
                   IntegerToString((long)ChartID()) + "|" + g_owner_instance_token + "|" +
                   IntegerToString(g_authority_epoch) + "|" + IntegerToString(req_chart) + "|" +
                   req_token + "|" + req_nonce;
      if(StringLen(ack) <= 63)
        {
         if(!EventChartCustom(req_chart, CHARTREG_ACK, (long)ChartID(), 0.0, ack))
           {
            // enqueue failed
           }
        }
     }
   else if(id == CHARTEVENT_CUSTOM + CHARTREG_ACK)
     {
      // Chart Context receives ack - validate all fields
      string parts[];
      int n = StringSplit(sparam, '|', parts);
      if(n < 9)
         return;
      if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
         return;
      if(parts[2] != auth_key)
         return;
      long coord_chart = (long)StringToInteger(parts[3]);
      string coord_token = parts[4];
      long coord_epoch = (long)StringToInteger(parts[5]);
      long ack_chart = (long)StringToInteger(parts[6]);
      string ack_token = parts[7];
      string ack_nonce = parts[8];
      if(ack_chart != ChartID())
         return;
      if(ack_token != g_owner_instance_token)
         return;
      if(coord_chart != g_pending_coord_chart)
         return;
      if(coord_epoch != g_pending_coord_epoch)
         return;
      if(ack_nonce != g_pending_nonce)
         return;
      // All validated - transition to REGISTERED
      g_reg_state = REG_STATE_REGISTERED;
     }
   else if(id == CHARTEVENT_CUSTOM + SNAPREG_NOTIFY)
     {
      // Chart Context receives snapshot notification
      string parts[];
      int n = StringSplit(sparam, '|', parts);
      if(n < 4)
         return;
      if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
         return;
      long coord_epoch = (long)StringToInteger(parts[2]);
      long snap_seq = (long)StringToInteger(parts[3]);
      if(coord_epoch != g_pending_coord_epoch)
         return;
      // Acknowledge: K|ver|chart_id|snap_seq (bounded; coordinator may consume; no broker/DB mutation)
      string ack = "K|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + IntegerToString((long)ChartID()) + "|" + IntegerToString(snap_seq);
      if(StringLen(ack) <= 63)
        {
         if(!EventChartCustom(g_pending_coord_chart, SNAPREG_ACK, (long)ChartID(), 0.0, ack))
           {
            // enqueue failed (best-effort; no retry)
           }
        }
      }
    else if(id == CHARTEVENT_CUSTOM + SNAPREG_ACK)
      {
       // Coordinator receives bounded snapshot ACK. Read-only validation only; no DB/broker mutation.
       if(g_coordinator_mode != COORD_MODE_COORDINATOR)
          return;
       string parts[];
       int n = StringSplit(sparam, '|', parts);
       if(n < 4)
          return;
       if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
          return;
       long ack_chart = (long)StringToInteger(parts[2]);
       long ack_seq = (long)StringToInteger(parts[3]);
       if(ack_chart <= 0 || ack_seq < 0)
          return;
       // Validate sender is a known subscriber (or at minimum known chart token not required in payload).
       bool known = false;
       for(int i = 0; i < g_subscriber_count; i++)
         {
          if(g_subscribers[i].chart_id == ack_chart && g_subscribers[i].registered)
            { known = true; break; }
         }
       // Unknown sender ignored (fail-safe). Known ACK is accepted as protocol evidence only.
      }
    else if(id == CHARTEVENT_CUSTOM + CHARTREG_UNREGISTER)
      {
       // E2.3-RD: coordinator removes subscriber. Producer/consumer share version+auth contract.
       if(g_coordinator_mode != COORD_MODE_COORDINATOR)
          return;
       string parts[];
       int n = StringSplit(sparam, '|', parts);
       if(n < 5)
          return;
       if((int)StringToInteger(parts[1]) != CHARTREG_PROTOCOL_VERSION)
          return;
       if(parts[2] != auth_key)
          return;
       long req_chart = (long)StringToInteger(parts[3]);
       string req_token = parts[4];
       if(req_chart <= 0 || req_token == "")
          return;
       // Remove only matching registered subscriber (chart+token). Invalid/stale sender cannot remove others.
       for(int i = 0; i < g_subscriber_count; i++)
         {
          if(g_subscribers[i].chart_id == req_chart && g_subscribers[i].owner_token == req_token)
            {
             for(int j = i; j < g_subscriber_count - 1; j++)
                g_subscribers[j] = g_subscribers[j+1];
             g_subscriber_count--;
             break;
            }
         }
      }
   }

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

   if(g_coordinator_mode == COORD_MODE_COORDINATOR)
     {
      string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
      g_execution_ledger.ReleaseAuthority(authority_key, g_owner_instance_token, g_authority_epoch);
     }
   else if(g_coordinator_mode == COORD_MODE_CHART_CONTEXT)
     {
      // Best-effort unregister to all charts (idempotent). Contract: UNREG|ver|auth_key|req_chart|token
      string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
      long chart = ChartFirst();
      while(chart >= 0)
        {
         if(chart != ChartID())
           {
            string unreg = "UNREG|" + IntegerToString(CHARTREG_PROTOCOL_VERSION) + "|" + auth_key + "|" +
                           IntegerToString((long)ChartID()) + "|" + g_owner_instance_token;
            if(StringLen(unreg) <= 63)
               EventChartCustom(chart, CHARTREG_UNREGISTER, (long)ChartID(), 0.0, unreg);
           }
         chart = ChartNext(chart);
        }
     }

   EventKillTimer();
   RetryUIClear();
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
//+------------------------------------------------------------------
bool IsForexSymbol(const string symbol)
  {
   if(symbol=="")
      return false;
   if(StringFind(symbol,"=")>=0)
      return false;
   if(StringFind(symbol,"^")>=0)
      return false;
   string base="";
   string quote="";
   if(SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE,base) && SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT,quote))
     {
      StringToUpper(base);
      StringToUpper(quote);
      if(StringLen(base)==3 && StringLen(quote)==3 && base!=quote)
         return true;
     }
   if(StringLen(symbol)>=6)
     {
      string c1=StringSubstr(symbol,0,3);
      string c2=StringSubstr(symbol,3,3);
      StringToUpper(c1);
      StringToUpper(c2);
      if(c1==c2) return false;
      bool ok1=false, ok2=false;
      string fx[]={"EUR","USD","GBP","JPY","AUD","NZD","CAD","CHF","SEK","NOK","DKK","MXN","ZAR","TRY","SGD","HKD","PLN","HUF","CZK","RUB","CNH","THB"};
      for(int i=0;i<ArraySize(fx);i++) if(c1==fx[i]) { ok1=true; break; }
      for(int i=0;i<ArraySize(fx);i++) if(c2==fx[i]) { ok2=true; break; }
      if(ok1 && ok2) return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------
int DiscoverForexSymbols(string &symbols_out[])
  {
   ArrayResize(symbols_out,0);
   if(!InpUseDynamicForex)
     {
      if(InpGoldSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpGoldSymbol; }
      if(InpSilverSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpSilverSymbol; }
      if(InpBitcoinSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpBitcoinSymbol; }
      return ArraySize(symbols_out);
     }
   int total=SymbolsTotal(true);
   for(int i=0;i<total;i++)
     {
      string sn=SymbolName(i,true);
      if(sn=="") continue;
      if(!IsForexSymbol(sn)) continue;
      if(!InpIncludeMetalsCrypto)
        {
         string su=sn; StringToUpper(su);
         if(StringFind(su,"XAU")>=0 || StringFind(su,"XAG")>=0 || StringFind(su,"GOLD")>=0 || StringFind(su,"SILVER")>=0 || StringFind(su,"BTC")>=0 || StringFind(su,"ETH")>=0 || StringFind(su,"BITCOIN")>=0) continue;
        }
      bool exists=false;
      for(int j=0;j<ArraySize(symbols_out);j++) if(symbols_out[j]==sn) { exists=true; break; }
      if(exists) continue;
      int sz2=ArraySize(symbols_out);
      if(sz2>=InpForexMaxSymbols) break;
      ArrayResize(symbols_out,sz2+1);
      symbols_out[sz2]=sn;
     }
   if(ArraySize(symbols_out)==0)
     {
      if(InpGoldSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpGoldSymbol; }
      if(InpSilverSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpSilverSymbol; }
      if(InpBitcoinSymbol!="") { int sz=ArraySize(symbols_out); ArrayResize(symbols_out,sz+1); symbols_out[sz]=InpBitcoinSymbol; }
     }
   return ArraySize(symbols_out);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
  }
//+------------------------------------------------------------------+


