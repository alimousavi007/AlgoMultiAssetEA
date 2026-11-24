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
#include "../Include/AlgoSystem/MetricsExporter.mqh"
#include "../Include/AlgoSystem/DashboardDiag.mqh"

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>

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
input(name="Dashboard View Mode")          ENUM_DASHBOARD_VIEW_MODE InpDashboardViewMode=DASHBOARD_NORMAL;
input(name="Enable Dashboard")             bool               InpDashboard=true;
input(name="Enable Dashboard Diagnostics")  bool               InpDashboardDiagnostics=false;
input(name="Log Level")                    ENUM_LOG_LEVEL     InpLogLevel=LOG_INFO;
input(name="Log to File")                  bool               InpLogFile=true;
input(name="Flush Log on Each Write")      bool               InpLogFlushEachWrite=true;
input(name="Log Summary Interval (Seconds)") int              InpLogSummarySeconds=60;

input group "02. Trading Symbols"
input(name="Symbol Universe (comma-separated)") string  InpSymbolUniverse="EURUSD,GBPUSD,XAUUSD";
input(name="Symbol Suffix Map (JSON)")             string  InpSymbolSuffixMap="{}";
// Format: {"EURUSD":["EURUSD.pro","EURUSD.ecn"],"GBPUSD":["GBPUSD.pro"]}
// When empty "{}", exact broker match is required for each configured symbol.

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
input(name="Margin Safety Fraction")       double             InpMarginSafetyFraction=0.80;
input(name="Maximum Execution Deviation (Points)") ulong      InpDeviationPoints=20;

input group "09b. External Risk Lock"
input(name="Enable External Risk Lock")    bool               InpExternalRiskLockEnabled=false;
input(name="External Risk Lock GV Prefix") string             InpExternalRiskLockGVPrefix="ALGO_EXT_RISK_LOCK";
input(name="External Risk Lock TTL (Sec)") int                InpExternalRiskLockTTL=60;
input(name="Fail Closed on Stale/Unavail") bool               InpExternalRiskLockFailClosed=true;
input(name="Authority Lease (Seconds)")    int                InpAuthorityLeaseSeconds=30;

input group "10. Trading Sessions & Market Filters"
input(name="Enable Session Filter")        bool               InpSessionFilter=true;
input(name="Session Start Hour (Server)")  int                InpSessionStartHour=0;
input(name="Session End Hour (Server)")    int                InpSessionEndHour=24;
input(name="Enable Spread Filter")         bool               InpUseSpreadFilter=true;
input(name="Max Spread (Points)")          int                InpMaxSpreadPoints=50;

input group "11. Dashboard & Diagnostics"
input(name="Safe Dashboard-Only Mode")     bool               InpDashboardSafeMode=false;
input(name="Enforce Safe Mode in Tester")  bool               InpEnforceSafeModeInTester=true;

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
   return CAlgoUtils::StyleToString(style);
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

//+------------------------------------------------------------------+
//| Parse comma-separated symbol universe string                     |
//| Format: "SYM1,SYM2,SYM3"                                         |
//| Returns true if valid (no empty, no duplicates after normalization)|
//+------------------------------------------------------------------+
bool ParseSymbolUniverse(const string universe_str,
                         string &symbols_out[])
{
    ArrayResize(symbols_out, 0);
    if(universe_str == "")
        return false;

    string parts[];
    int n = StringSplit(universe_str, ',', parts);
    if(n == 0)
        return false;

    // Track configured names for duplicate detection.
    // Comparison is exact after trim + case folding ONLY: no suffix/prefix collapsing.
    // "EURUSD" and "EURUSD.pro" are distinct configured symbols and must NOT be merged here;
    // broker resolution happens explicitly (and fail-closed) in ResolveBrokerSymbol.
    string seen[];
    for(int i = 0; i < n; i++)
    {
        string s = parts[i];
        StringTrimLeft(s);
        StringTrimRight(s);
        if(s == "")
            return false; // empty entry -> malformed

        string s_key = s;
        StringToUpper(s_key); // case-insensitive duplicate detection only; no suffix/prefix collapsing

        for(int j = 0; j < ArraySize(seen); j++)
        {
            if(seen[j] == s_key)
                return false; // duplicate configured symbol
        }

        int sz = ArraySize(symbols_out);
        ArrayResize(symbols_out, sz + 1);
        symbols_out[sz] = s; // store original configured form
        ArrayResize(seen, sz + 1);
        seen[sz] = s_key;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Parse symbol suffix mapping JSON                                 |
//| Format: {"SYM":["broker1","broker2"],"SYM2":["broker3"]}       |
//| Returns true if valid JSON structure                             |
//+------------------------------------------------------------------+
bool ParseSymbolSuffixMap(const string json_str,
                          string &configured_symbols[],
                          string &broker_symbols_out[])
{
    ArrayResize(configured_symbols, 0);
    ArrayResize(broker_symbols_out, 0);

    if(json_str == "" || json_str == "{}")
        return true; // no mapping - exact match only

    // Simple JSON parser for our specific format
    // Expected: {"SYM":["b1","b2"],"SYM2":["b3"]}
    string content = json_str;
    StringTrimLeft(content);
    StringTrimRight(content);
    if(StringLen(content) < 2 || StringGetCharacter(content, 0) != '{' || StringGetCharacter(content, StringLen(content) - 1) != '}')
        return false;

    // Remove outer braces
    content = StringSubstr(content, 1, StringLen(content) - 2);
    StringTrimLeft(content);
    StringTrimRight(content);
    if(content == "")
        return true;

    // Split by '},' to get each symbol entry
    // This is a simplified parser - handles our specific format
    int pos = 0;
    while(pos < StringLen(content))
    {
        StringTrimLeft(content);
        StringTrimRight(content);
        if(content == "")
            break;

        // Find the key (before ':')
        int colon = StringFind(content, ":");
        if(colon < 0)
            return false;

        string key = StringSubstr(content, 0, colon);
        StringTrimLeft(key);
        StringTrimRight(key);
        // Remove quotes
        if(StringLen(key) >= 2 && StringGetCharacter(key, 0) == '"' && StringGetCharacter(key, StringLen(key) - 1) == '"')
            key = StringSubstr(key, 1, StringLen(key) - 2);
        else
            return false;

        // Find the array [...]
        int array_start = StringFind(content, "[");
        int array_end = StringFind(content, "]");
        if(array_start < 0 || array_end < 0 || array_end <= array_start)
            return false;

        string array_content = StringSubstr(content, array_start + 1, array_end - array_start - 1);
        // Split by ','
        string broker_symbols[];
        int bs_count = 0;
        if(array_content != "")
        {
            bs_count = StringSplit(array_content, ',', broker_symbols);
            for(int i = 0; i < bs_count; i++)
            {
                string bs = broker_symbols[i];
                StringTrimLeft(bs);
                StringTrimRight(bs);
                // Remove quotes
                if(StringLen(bs) >= 2 && StringGetCharacter(bs, 0) == '"' && StringGetCharacter(bs, StringLen(bs) - 1) == '"')
                    bs = StringSubstr(bs, 1, StringLen(bs) - 2);
                else
                    return false;

                int sz = ArraySize(configured_symbols);
                ArrayResize(configured_symbols, sz + 1);
                configured_symbols[sz] = key;
                ArrayResize(broker_symbols_out, sz + 1);
                broker_symbols_out[sz] = bs;
            }
        }

        // Move past this entry
        int next_comma = StringFind(content, ",", array_end);
        if(next_comma < 0)
            break;
        content = StringSubstr(content, next_comma + 1);
    }
    return true;
}

//+------------------------------------------------------------------+
//| Resolve configured symbol to actual broker symbol                |
//| Priority: 1) Exact broker match, 2) Explicit suffix map,        |
//| 3) Fail-closed on ambiguous/unresolved                           |
//+------------------------------------------------------------------+
bool ResolveBrokerSymbol(const string configured_symbol,
                         const string &broker_symbols[],
                         const string &mapped_configured[],
                         const string &mapped_broker[],
                         string &resolved_broker_symbol)
{
    // 1. Check if configured symbol exists exactly in broker symbols
    for(int i = 0; i < ArraySize(broker_symbols); i++)
    {
        if(broker_symbols[i] == configured_symbol)
        {
            resolved_broker_symbol = configured_symbol;
            return true;
        }
    }

    // 2. Check explicit suffix map
    string candidates[];
    for(int i = 0; i < ArraySize(mapped_configured); i++)
    {
        if(mapped_configured[i] == configured_symbol)
        {
            int sz = ArraySize(candidates);
            ArrayResize(candidates, sz + 1);
            candidates[sz] = mapped_broker[i];
        }
    }

    if(ArraySize(candidates) == 0)
    {
        // No explicit mapping and no exact match
        resolved_broker_symbol = "";
        return false;
    }

    // 3. Verify candidates exist on broker
    string valid_candidates[];
    for(int i = 0; i < ArraySize(candidates); i++)
    {
        bool custom = false;
        if(SymbolExist(candidates[i], custom))
        {
            // Deduplicate: skip if already in valid_candidates
            bool already = false;
            for(int k = 0; k < ArraySize(valid_candidates); k++)
            {
                if(valid_candidates[k] == candidates[i])
                {
                    already = true;
                    break;
                }
            }
            if(!already)
            {
                int sz = ArraySize(valid_candidates);
                ArrayResize(valid_candidates, sz + 1);
                valid_candidates[sz] = candidates[i];
            }
        }
    }

    if(ArraySize(valid_candidates) == 0)
    {
        // None of the mapped symbols exist
        resolved_broker_symbol = "";
        return false;
    }

    if(ArraySize(valid_candidates) > 1)
    {
        // Ambiguous - multiple mapped symbols exist
        string diag = "";
        for(int i = 0; i < ArraySize(valid_candidates); i++)
        {
            if(diag != "") diag += ", ";
            diag += valid_candidates[i];
        }
        g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_AMBIGUOUS",
                       configured_symbol, "", "", "",
                       "FAIL", "AMBIGUOUS_MAPPING",
                       "Multiple broker symbols match configured symbol: " + diag);
        resolved_broker_symbol = "";
        return false;
    }

    resolved_broker_symbol = valid_candidates[0];
    return true;
}

bool ValidInputSet()
  {
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

// WS-2: Runtime Readiness State Machine
enum ENUM_RUNTIME_STATE
  {
   RUNTIME_UNINITIALIZED     = 0,  // Not yet initialized
   RUNTIME_INITIALIZING      = 1,  // Initialize() in progress
   RUNTIME_INIT_FAILED       = 2,  // Initialize() failed (terminal)
   RUNTIME_READY             = 3,  // Initialized, waiting for entry bar
   RUNTIME_WAIT_ENTRY_BAR    = 4,  // Waiting for new closed entry bar
   RUNTIME_WAIT_SIGNAL_BAR   = 5,  // Waiting for new closed signal/context bar
   RUNTIME_FETCHING_DATA     = 6,  // Fetching market snapshots
   RUNTIME_CALCULATING       = 7,  // Calculating features
   RUNTIME_EVALUATING        = 8,  // Running hybrid engine evaluation
   RUNTIME_EVALUATED         = 9,  // Evaluation complete, signal generated
   RUNTIME_BLOCKED_SESSION   = 10, // Blocked by session filter
   RUNTIME_BLOCKED_DATA      = 11, // Blocked by missing/invalid market data
   RUNTIME_BLOCKED_FEATURES  = 12, // Blocked by feature calculation failure
   RUNTIME_BLOCKED_RISK      = 13, // Blocked by risk/portfolio lock
   RUNTIME_BLOCKED_NEWS      = 14, // Blocked by news filter
   RUNTIME_BLOCKED_AUTHORITY = 15, // Blocked by authority/coordinator
   RUNTIME_BLOCKED_SYSTEM    = 16, // Blocked by system not ready
   RUNTIME_ERROR             = 17  // Unexpected error (non-terminal, retryable)
  };

// WS-2: Transition reason codes for audit trail
enum ENUM_RUNTIME_TRANSITION_REASON
  {
   REASON_NONE                    = 0,
   REASON_INIT_SUCCESS            = 1,
   REASON_INIT_FAILED             = 2,
   REASON_SYSTEM_NOT_READY        = 3,
   REASON_SESSION_FILTER          = 4,
   REASON_NO_ENTRY_BAR            = 5,
   REASON_ENTRY_BAR_READY         = 6,
   REASON_DATA_FETCH_START        = 7,
   REASON_DATA_FETCH_OK           = 8,
   REASON_DATA_FETCH_FAILED       = 9,
   REASON_FEATURE_CALC_START      = 10,
   REASON_FEATURE_CALC_OK         = 11,
   REASON_FEATURE_CALC_FAILED     = 12,
   REASON_NO_SIGNAL_BAR           = 13,
   REASON_SIGNAL_BAR_READY        = 14,
   REASON_EVALUATION_START        = 15,
   REASON_EVALUATION_OK           = 16,
   REASON_EVALUATION_NO_SIGNAL    = 17,
   REASON_EVALUATION_FAILED       = 18,
   REASON_RISK_LOCK               = 19,
   REASON_NEWS_BLOCK              = 20,
   REASON_AUTHORITY_BLOCK         = 21,
   REASON_CONDITION_RESOLVED      = 22,
   REASON_ERROR_RECOVERY          = 23,
   REASON_MAX_RETRIES_EXCEEDED    = 24
  };

class CSymbolRuntime : public CObject
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

   // Per-runtime state (replaces parallel arrays g_runtime_wait_state, g_runtime_init_failure)
   string            wait_state;
   string            init_failure;

// D1: Runtime snapshot contract (typed, per-runtime, no fabrication)
   // (enum moved to global scope before class)
   struct RuntimeSnapshot
   {
    int               generation;
    datetime          snapshot_time;
    datetime          last_success_time;
    int               current_stage_code;        // 0=NOT_EVALUATED, 1=WAITING_FOR_NEW_ENTRY_BAR, 2=WAITING_FOR_SIGNAL_BAR, 3=EVALUATED, 4=BLOCKED
    int               last_block_reason_code;    // 0=NONE, 1=NO_NEW_CLOSED_BAR, 2=SIGNAL_MARKET_INVALID, etc.
    ENUM_TRADING_STYLE configured_style;
    int               regime_code;               // ENUM_REGIME_TYPE value
    int               bias_code;                 // ENUM_BIAS_DIRECTION value
    int               long_code;                 // 0=NO_LONG, 1=LONG_CANDIDATE
    int               short_code;                // 0=NO_SHORT, 1=SHORT_CANDIDATE
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

    // WS-2: Runtime Readiness State Machine
    ENUM_RUNTIME_STATE runtime_state;
    int                last_transition_reason;
    datetime           state_entered_time;
    int                retry_count;

// Signal pipeline caching - avoids redundant data fetching
    MarketSnapshot     cached_context_market;
    MarketSnapshot     cached_structure_market;
    MarketSnapshot     cached_setup_market;
    MarketSnapshot     cached_entry_market;
    bool               cache_valid;

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
     wait_state="";
     init_failure="";

     // WS-2: Initialize state machine fields
     runtime_state = RUNTIME_UNINITIALIZED;
     last_transition_reason = REASON_NONE;
     state_entered_time = 0;
     retry_count = 0;

snapshot_generation=0;
      snapshot.generation=0;
      snapshot.snapshot_time=0;
      snapshot.last_success_time=0;
      snapshot.current_stage_code=0;
      snapshot.last_block_reason_code=0;
      snapshot.configured_style=STYLE_DAY_TRADING;
      snapshot.regime_code=0;
      snapshot.bias_code=0;
      snapshot.long_code=0;
      snapshot.short_code=0;
      snapshot.regime_state=SNAP_NOT_EVALUATED;
      snapshot.bias_state=SNAP_NOT_EVALUATED;
      snapshot.long_state=SNAP_NOT_EVALUATED;
      snapshot.short_state=SNAP_NOT_EVALUATED;

      // Initialize signal pipeline cache
      cache_valid = false;
     }

// CObject interface
    virtual int Type(void) const { return 0x7778; } // Custom type ID for CSymbolRuntime

    // WS-2: State transition with audit logging
    bool TransitionTo(ENUM_RUNTIME_STATE new_state, int reason_code = REASON_NONE)
    {
     if(runtime_state == new_state)
        return true; // Idempotent - no transition needed

     // Log transition for audit trail
     g_logger.Event(LOG_INFO, "RUNTIME", "STATE_TRANSITION",
                    symbol, "", "", "",
                    "INFO", "RUNTIME",
                    "State: " + EnumToString(runtime_state) +
                    " -> " + EnumToString(new_state) +
                    " reason=" + IntegerToString(reason_code));

     runtime_state = new_state;
     last_transition_reason = reason_code;
     state_entered_time = TimeCurrent();
     return true;
    }

    // WS-2: Readiness query methods
    bool IsReadyForEvaluation() const
    {
     return runtime_state == RUNTIME_READY ||
            runtime_state == RUNTIME_WAIT_ENTRY_BAR ||
            runtime_state == RUNTIME_WAIT_SIGNAL_BAR;
    }

    bool IsBlocked() const
    {
     return runtime_state >= RUNTIME_BLOCKED_SESSION &&
            runtime_state <= RUNTIME_BLOCKED_SYSTEM;
    }

    bool IsTerminal() const
    {
     return runtime_state == RUNTIME_INIT_FAILED;
    }

    bool IsError() const
    {
     return runtime_state == RUNTIME_ERROR;
    }

    string GetStateDescription() const
    {
     switch(runtime_state)
       {
        case RUNTIME_UNINITIALIZED:     return "UNINITIALIZED";
        case RUNTIME_INITIALIZING:      return "INITIALIZING";
        case RUNTIME_INIT_FAILED:       return "INIT_FAILED";
        case RUNTIME_READY:             return "READY";
        case RUNTIME_WAIT_ENTRY_BAR:    return "WAIT_ENTRY_BAR";
        case RUNTIME_WAIT_SIGNAL_BAR:   return "WAIT_SIGNAL_BAR";
        case RUNTIME_FETCHING_DATA:     return "FETCHING_DATA";
        case RUNTIME_CALCULATING:       return "CALCULATING";
        case RUNTIME_EVALUATING:        return "EVALUATING";
        case RUNTIME_EVALUATED:         return "EVALUATED";
        case RUNTIME_BLOCKED_SESSION:   return "BLOCKED_SESSION";
        case RUNTIME_BLOCKED_DATA:      return "BLOCKED_DATA";
        case RUNTIME_BLOCKED_FEATURES:  return "BLOCKED_FEATURES";
        case RUNTIME_BLOCKED_RISK:      return "BLOCKED_RISK";
        case RUNTIME_BLOCKED_NEWS:      return "BLOCKED_NEWS";
        case RUNTIME_BLOCKED_AUTHORITY: return "BLOCKED_AUTHORITY";
        case RUNTIME_BLOCKED_SYSTEM:    return "BLOCKED_SYSTEM";
        case RUNTIME_ERROR:             return "ERROR";
        default:                        return "UNKNOWN(" + IntegerToString((int)runtime_state) + ")";
       }
    }

    //+------------------------------------------------------------------+
    //| Check per-timeframe series synchronization                       |
    //| Returns true if all four role timeframes are synchronized        |
    //+------------------------------------------------------------------+
    bool CheckSeriesSynchronized()
    {
     // Check Context timeframe
     long synchronized = 0;
     ResetLastError();
     if(!SeriesInfoInteger(symbol, context_tf, SERIES_SYNCHRONIZED, synchronized) || synchronized == 0)
       {
        last_failure = "Context timeframe series not synchronized: " + EnumToString(context_tf);
        return false;
       }

     // Check Structure timeframe
     ResetLastError();
     if(!SeriesInfoInteger(symbol, structure_tf, SERIES_SYNCHRONIZED, synchronized) || synchronized == 0)
       {
        last_failure = "Structure timeframe series not synchronized: " + EnumToString(structure_tf);
        return false;
       }

     // Check Setup timeframe
     ResetLastError();
     if(!SeriesInfoInteger(symbol, setup_tf, SERIES_SYNCHRONIZED, synchronized) || synchronized == 0)
       {
        last_failure = "Setup timeframe series not synchronized: " + EnumToString(setup_tf);
        return false;
       }

     // Check Entry timeframe
     ResetLastError();
     if(!SeriesInfoInteger(symbol, entry_tf, SERIES_SYNCHRONIZED, synchronized) || synchronized == 0)
       {
        last_failure = "Entry timeframe series not synchronized: " + EnumToString(entry_tf);
        return false;
       }

     return true;
    }

    //+------------------------------------------------------------------+
    //| Check history depth for all four roles using FeatureEngine       |
    //| Returns true if each timeframe has sufficient bars               |
    //+------------------------------------------------------------------+
    bool CheckHistoryDepth()
    {
     // Context timeframe
     int required = feature_context.MinimumBarsRequired();
     if(Bars(symbol, context_tf) < required)
       {
        last_failure = "Insufficient history for Context timeframe: " + EnumToString(context_tf) +
                       " (have=" + IntegerToString(Bars(symbol, context_tf)) +
                       " need=" + IntegerToString(required) + ")";
        return false;
       }

     // Structure timeframe
     required = feature_structure.MinimumBarsRequired();
     if(Bars(symbol, structure_tf) < required)
       {
        last_failure = "Insufficient history for Structure timeframe: " + EnumToString(structure_tf) +
                       " (have=" + IntegerToString(Bars(symbol, structure_tf)) +
                       " need=" + IntegerToString(required) + ")";
        return false;
       }

     // Setup timeframe
     required = feature_setup.MinimumBarsRequired();
     if(Bars(symbol, setup_tf) < required)
       {
        last_failure = "Insufficient history for Setup timeframe: " + EnumToString(setup_tf) +
                       " (have=" + IntegerToString(Bars(symbol, setup_tf)) +
                       " need=" + IntegerToString(required) + ")";
        return false;
       }

     // Entry timeframe
     required = feature_entry.MinimumBarsRequired();
     if(Bars(symbol, entry_tf) < required)
       {
        last_failure = "Insufficient history for Entry timeframe: " + EnumToString(entry_tf) +
                       " (have=" + IntegerToString(Bars(symbol, entry_tf)) +
                       " need=" + IntegerToString(required) + ")";
        return false;
       }

     return true;
    }

    //+------------------------------------------------------------------+
    //| Check quote readiness using resolved broker symbol               |
    //| Returns true if valid bid/ask tick is available                  |
    //+------------------------------------------------------------------+
    bool CheckQuoteReadiness()
    {
     MqlTick tick;
     ResetLastError();
     if(!SymbolInfoTick(symbol, tick))
       {
        last_failure = "SymbolInfoTick failed for " + symbol + " error=" + IntegerToString(GetLastError());
        return false;
       }

     if(tick.bid <= 0 || tick.ask <= 0)
       {
        last_failure = "Invalid bid/ask for " + symbol + " bid=" + DoubleToString(tick.bid) + " ask=" + DoubleToString(tick.ask);
        return false;
       }

     // Check tick freshness using freshness policy
     datetime now = TimeCurrent();
     if(now - tick.time > InpFreshnessEntrySeconds)
       {
        last_failure = "Stale tick for " + symbol + " age=" + IntegerToString(now - tick.time) + "s";
        return false;
       }

     return true;
    }

    //+------------------------------------------------------------------+
    //| Combined readiness check for all layers                          |
    //| Returns true if symbol is fully ready for data fetching          |
    //+------------------------------------------------------------------+
    bool CheckReadiness()
    {
     if(!CheckSeriesSynchronized())
       {
        TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
        ShowRuntimeGateStatus(*this, "BLOCKED: SERIES NOT SYNC");
        LogRuntimeGate(*this, "READINESS_CHECK", "SERIES_SYNC", "FAIL", last_failure);
        return false;
       }

     if(!CheckHistoryDepth())
       {
        TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
        ShowRuntimeGateStatus(*this, "BLOCKED: INSUFFICIENT HISTORY");
        LogRuntimeGate(*this, "READINESS_CHECK", "HISTORY_DEPTH", "FAIL", last_failure);
        return false;
       }

     if(!CheckQuoteReadiness())
       {
        TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
        ShowRuntimeGateStatus(*this, "BLOCKED: QUOTE NOT READY");
        LogRuntimeGate(*this, "READINESS_CHECK", "QUOTE", "FAIL", last_failure);
        return false;
       }

     return true;
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
        // WS-2: Transition to INITIALIZING
        TransitionTo(RUNTIME_INITIALIZING, REASON_INIT_SUCCESS);

        valid=false;
        last_failure="";
        retry_count = 0;

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
           TransitionTo(RUNTIME_INIT_FAILED, REASON_INIT_FAILED);
           return false;
          }

         if(!market_context.Initialize() ||
            !market_structure.Initialize() ||
            !market_setup.Initialize() ||
            !market_entry.Initialize())
           {
            last_failure="MarketData.Initialize failed";
            TransitionTo(RUNTIME_INIT_FAILED, REASON_INIT_FAILED);
            return false;
           }

         if(!feature_context.InitializeFor(symbol, context_tf) ||
            !feature_structure.InitializeFor(symbol, structure_tf) ||
            !feature_setup.InitializeFor(symbol, setup_tf) ||
            !feature_entry.InitializeFor(symbol, entry_tf))
           {
            last_failure="FeatureEngine.Initialize failed";
            TransitionTo(RUNTIME_INIT_FAILED, REASON_INIT_FAILED);
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
           TransitionTo(RUNTIME_INIT_FAILED, REASON_INIT_FAILED);
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
       // WS-2: Transition to READY on successful initialization
       TransitionTo(RUNTIME_READY, REASON_INIT_SUCCESS);
       return true;
      }
   };

//==================================================================
// Globals
//==================================================================
CArrayObj g_runtime;
// P2.2: Central multi-asset scheduler state (cooperative, single-threaded)
int    g_sched_cursor = 0;              // round-robin cursor across g_runtime
int    g_sched_step_budget = 8;         // max runtime steps per invocation
int    g_sched_time_budget_us = 5000;   // max microseconds per invocation
int    g_sched_invocations = 0;
int    g_sched_time_exhausted = 0;
int    g_sched_step_exhausted = 0;
int    g_sched_deferred = 0;
int    g_sched_rotation_count = 0;
// E2.3-RD: Chart Context Registration events (custom event base)
#define CHARTREG_DISCOVERY  1001
#define CHARTREG_REGISTER   1002
#define CHARTREG_ACK        1003
#define CHARTREG_UNREGISTER 1004
#define CHARTREG_PROTOCOL_VERSION 1
#define SNAPREG_NOTIFY 1005
#define SNAPREG_ACK    1006
long   g_snapshot_sequence = 0;
// F3: process-local monotonic counter for collision-resistant attempt_id (restart-safe with GetTickCount).
long   g_attempt_counter = 0;
enum ENUM_COORDINATOR_MODE { COORD_MODE_UNINITIALIZED, COORD_MODE_COORDINATOR, COORD_MODE_CHART_CONTEXT, COORD_MODE_UNAVAILABLE };
ENUM_COORDINATOR_MODE g_coordinator_mode = COORD_MODE_UNINITIALIZED;
string g_coordinator_unavailable_reason = "";
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
// E2.1: Strategy Group identity and Config Fingerprint (single-instance only;
 // cross-instance durable arbitration requires later Ledger/Gateway packages)
 string g_strategy_group_key = "";
 string g_config_fingerprint = "";
 int g_runtime_count_max=256;

 // Dashboard Diagnostics
 CDashboardDiag g_dashboard_diag;
 bool g_dashboard_diag_enabled = false;

//==================================================================
 // Concurrency Engine (WP-05)
 //==================================================================
 // Fair Lock using Global Variables (ticket-based FIFO) — atomic via GlobalVariableSetOnCondition
 // F01/F06: Improved atomicity, bounded waiting, owner-safe release
 struct CFairLock
   {
    string lock_name;
    long   my_ticket;
    bool   acquired;

                       CFairLock(): lock_name(""), my_ticket(0), acquired(false) {}
                       CFairLock(const string name): lock_name(name), my_ticket(0), acquired(false) {}

    // Atomic ticket allocation using GlobalVariableSetOnCondition (CAS loop with exponential backoff)
    bool AllocateTicket(string &ticket_key, long &out_ticket)
      {
       // Ensure variable exists before CAS (GlobalVariableSetOnCondition requires pre-existing variable)
       if(!GlobalVariableCheck(ticket_key))
         {
          ResetLastError();
          if(!GlobalVariableSet(ticket_key, 0.0))
            {
             return false; // Creation failed
            }
         }
       long expected = 0;
       long desired = 1;
       if(GlobalVariableCheck(ticket_key))
         {
          expected = (long)GlobalVariableGet(ticket_key);
          desired = expected + 1;
         }
       // CAS loop with exponential backoff: max 20 attempts
       int base_sleep_ms = 1;
       for(int attempt = 0; attempt < 20; attempt++)
         {
          if(GlobalVariableSetOnCondition(ticket_key, (double)desired, (double)expected))
            {
             out_ticket = desired;
             return true;
            }
          // Failed: value changed, re-read and retry
          if(GlobalVariableCheck(ticket_key))
            {
             expected = (long)GlobalVariableGet(ticket_key);
             desired = expected + 1;
            }
          else
            {
             expected = 0;
             desired = 1;
            }
          // Exponential backoff: 1, 2, 4, 8, 16, 32... max 100ms
          int sleep_ms = base_sleep_ms * (1 << attempt);
          if(sleep_ms > 100) sleep_ms = 100;
          Sleep(sleep_ms);
         }
       return false;
      }

    bool Acquire(const int timeout_ms=5000)
      {
       if(lock_name=="") return false;
       string ticket_key = lock_name + "_ticket";
       string serving_key = lock_name + "_serving";
       string owner_key = lock_name + "_owner";

// 1) Atomically allocate our ticket
        long ticket = 0;
        if(!AllocateTicket(ticket_key, ticket))
          {
           ResetLastError();
           return false; // allocation failed (race)
          }
        my_ticket = ticket;

        // Ensure serving_key and owner_key exist before CAS (GlobalVariableSetOnCondition requires pre-existing variables)
        if(!GlobalVariableCheck(serving_key))
          {
           ResetLastError();
           GlobalVariableSet(serving_key, 0.0);
          }
        if(!GlobalVariableCheck(owner_key))
          {
           ResetLastError();
           GlobalVariableSet(owner_key, 0.0);
          }

        // 2) Wait for our turn using GetTickCount64 for accurate timeout
       ulong start_tick = GetTickCount64();
       int backoff_ms = 1;

       while((int)(GetTickCount64() - start_tick) < timeout_ms)
         {
          long serving = 0;
          if(GlobalVariableCheck(serving_key))
             serving = (long)GlobalVariableGet(serving_key);

          if(serving + 1 == my_ticket)
            {
             // 3) Atomically claim ownership: set serving to my_ticket only if still serving+1
             long expected_serving = my_ticket - 1;
             long new_serving = my_ticket;
             if(GlobalVariableSetOnCondition(serving_key, (double)new_serving, (double)expected_serving))
               {
                // 4) Atomically set owner only if unowned (owner_key == 0 or empty)
                double my_chart_id = (double)ChartID();
                if(GlobalVariableSetOnCondition(owner_key, my_chart_id, 0.0))
                  {
                   acquired = true;
                   return true;
                  }
                // If owner_key exists but has our chart_id, we already own it
                if(GlobalVariableCheck(owner_key))
                  {
                   double current_owner = GlobalVariableGet(owner_key);
                   if((long)current_owner == ChartID())
                     {
                      acquired = true;
                      return true;
                     }
                  }
                // Failed to claim owner — rollback serving (best effort CAS)
                GlobalVariableSetOnCondition(serving_key, (double)expected_serving, (double)new_serving);
                // Fall through to retry
               }
             // CAS failed: another owner slipped in, re-read serving and retry
            }

          // Exponential backoff with jitter: 1, 2, 4, 8, 16... max 50ms
          Sleep(backoff_ms);
          backoff_ms = backoff_ms * 2;
          if(backoff_ms > 50) backoff_ms = 50;
         }

       // Timeout: ticket gap is harmless (FIFO order preserved), no cleanup needed
       return false;
      }

    // F06: Owner-safe release with double-check CAS and serving verification
    void Release()
      {
       if(!acquired || lock_name=="") return;
       string serving_key = lock_name + "_serving";
       string owner_key = lock_name + "_owner";

       // Atomically verify we're still the owner and release
       double my_chart_id = (double)ChartID();

       // Double-check CAS: only clear owner if we still own it
       if(GlobalVariableSetOnCondition(owner_key, 0.0, my_chart_id))
         {
          // We successfully cleared owner; now verify serving before advancing
          long current_serving = 0;
          if(GlobalVariableCheck(serving_key))
            current_serving = (long)GlobalVariableGet(serving_key);

          // Only advance serving if it's still our ticket (prevents stale restart from skipping real holder)
          if(current_serving == my_ticket)
            {
             GlobalVariableSetOnCondition(serving_key, (double)(my_ticket + 1), (double)my_ticket);
            }
         }
       // If CAS failed, another owner took over - do not advance serving

       acquired = false;
       my_ticket = 0;
      }

    bool IsOwner() const
      {
       if(lock_name=="") return false;
       string owner_key = lock_name + "_owner";
       if(!GlobalVariableCheck(owner_key)) return false;
       return ((long)GlobalVariableGet(owner_key) == ChartID());
      }
   };

// Chart Message Queue
class ChartMessage : public CObject
  {
public:
   int        msg_type;
   long       from_chart;
   long       to_chart;
   string     payload;
   datetime   timestamp;
   int        priority; // 0=high, 1=normal, 2=low

                      ChartMessage(): msg_type(0), from_chart(0), to_chart(0), payload(""), timestamp(0), priority(1) {}
                      ChartMessage(int type, long from, long to, const string& p, int pri=1):
                        msg_type(type), from_chart(from), to_chart(to), payload(p), timestamp(TimeCurrent()), priority(pri) {}

virtual int Type(void) const { return 0x777B; }

    // Copy constructor for queue operations
    ChartMessage(const ChartMessage& src):
      msg_type(src.msg_type), from_chart(src.from_chart), to_chart(src.to_chart),
      payload(src.payload), timestamp(src.timestamp), priority(src.priority) {}
  };

class CChartMessageQueue : public CObject
  {
private:
   CArrayObj    m_queue;
   CFairLock    m_lock;
   int          m_max_size;

public:
                     CChartMessageQueue(): m_max_size(1000)
     {
      m_lock = CFairLock("ALGO_MSG_QUEUE_" + IntegerToString((long)ChartID()));
     }
                    ~CChartMessageQueue()
     {
      Clear();
     }

bool Enqueue(const ChartMessage& msg)
      {
       if(m_queue.Total() >= m_max_size) return false;
       if(!m_lock.Acquire(100)) return false; // quick lock for queue ops

       ChartMessage *m = new ChartMessage(msg);
       if(m == NULL) { m_lock.Release(); return false; }

       // Insert by priority (0=high first), maintaining FIFO for equal priority
       // Scan from front to find first position where existing priority > new priority
       int insert_idx = m_queue.Total(); // default: append at end (lowest priority)
       for(int i = 0; i < m_queue.Total(); i++)
         {
          ChartMessage *existing = (ChartMessage*)m_queue.At(i);
          if(existing && existing.priority > msg.priority)
            {
             insert_idx = i;
             break;
            }
         }
       bool ok = m_queue.Insert(m, insert_idx);
       if(!ok) delete m;
       m_lock.Release();
       return ok;
      }

   bool Dequeue(ChartMessage& out)
     {
      if(m_queue.Total() == 0) return false;
      if(!m_lock.Acquire(100)) return false;

      ChartMessage *m = (ChartMessage*)m_queue.At(0);
      if(m)
        {
         out = *m;
         m_queue.Delete(0);
         delete m;
         m_lock.Release();
         return true;
        }
      m_lock.Release();
      return false;
     }

   int Size() const { return m_queue.Total(); }

   void Clear()
     {
      for(int i = 0; i < m_queue.Total(); i++)
        {
         ChartMessage *m = (ChartMessage*)m_queue.At(i);
         if(m) delete m;
        }
      m_queue.Clear();
     }

   virtual int Type(void) const { return 0x7779; }
  };

// Thread-safe Subscriber Registry (extends fixed array with fair lock)
class CSubscriberRegistry : public CObject
  {
 private:
   SubscriberRecord m_subscribers[64];
   int              m_count;
   CFairLock        m_lock;

 public:
                       CSubscriberRegistry(): m_count(0), m_lock("ALGO_SUB_REGISTRY") {}

   // Internal: acquire lock with retries for read operations
   bool AcquireReadLock(const int timeout_ms=1000)
     {
      ulong start = GetTickCount64();
      int backoff = 1;
      while((int)(GetTickCount64() - start) < timeout_ms)
        {
         int remaining = timeout_ms - (int)(GetTickCount64() - start);
         if(remaining <= 0) break;
         if(m_lock.Acquire(remaining)) return true;
         Sleep(backoff);
         backoff = backoff * 2;
         if(backoff > 50) backoff = 50;
        }
      return false;
     }

   bool Register(const long chart_id, const string& owner_token, const string& group_key, const string& config_fp)
     {
      if(!m_lock.Acquire(1000)) return false;

      // Check for conflicts
      for(int i = 0; i < m_count; i++)
        {
         if(m_subscribers[i].strategy_group_key == group_key &&
            m_subscribers[i].config_fingerprint != config_fp)
           {
            m_lock.Release();
            return false; // config conflict
           }
        }

      // Check if already registered
      for(int i = 0; i < m_count; i++)
        {
         if(m_subscribers[i].chart_id == chart_id && m_subscribers[i].owner_token == owner_token)
           {
            m_lock.Release();
            return true; // idempotent
           }
        }

      if(m_count >= 64) { m_lock.Release(); return false; }

      m_subscribers[m_count].chart_id = chart_id;
      m_subscribers[m_count].owner_token = owner_token;
      m_subscribers[m_count].strategy_group_key = group_key;
      m_subscribers[m_count].config_fingerprint = config_fp;
      m_subscribers[m_count].registered = true;
      m_count++;

      m_lock.Release();
      return true;
     }

   bool Unregister(const long chart_id, const string& owner_token)
     {
      if(!m_lock.Acquire(1000)) return false;

      for(int i = 0; i < m_count; i++)
        {
         if(m_subscribers[i].chart_id == chart_id && m_subscribers[i].owner_token == owner_token)
           {
            // Shift remaining
            for(int j = i; j < m_count - 1; j++)
               m_subscribers[j] = m_subscribers[j + 1];
            m_count--;
            m_lock.Release();
            return true;
           }
        }
      m_lock.Release();
      return false;
     }

 bool IsRegistered(const long chart_id)
     {
      // Use read lock with retry for fail-safe: if lock fails, return false (conservative)
      if(!AcquireReadLock(100)) return false;

      bool result = false;
      for(int i = 0; i < m_count; i++)
        {
         if(m_subscribers[i].chart_id == chart_id && m_subscribers[i].registered)
           {
            result = true;
            break;
           }
         }
      m_lock.Release();
      return result;
     }

   int GetSubscribers(SubscriberRecord& out[])
     {
      // Use read lock with retry
      if(!AcquireReadLock(500)) return 0;

      // Caller must allocate array of at least 64
      int copied = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_subscribers[i].registered)
            out[copied++] = m_subscribers[i];
         }
      m_lock.Release();
      return copied;
     }

   int Count()
     {
      // Use read lock with retry
      if(!AcquireReadLock(500)) return 0;
      int result = m_count;
      m_lock.Release();
      return result;
     }

   virtual int Type(void) const { return 0x777A; }
  };

// Global concurrency primitives
CFairLock       g_runtime_lock("ALGO_RUNTIME_LOCK");
CChartMessageQueue g_chart_msg_queue;
CSubscriberRegistry g_subscriber_registry;


//==================================================================
// Risk Engine Optimization (WP-06)
//==================================================================
// Unified Exposure Calculator - combines positions, pending orders, ledger reservations
class CUnifiedExposureCalculator
  {
private:
   CAlgoPortfolioRisk *m_portfolio_risk;
   CExecutionLedger   *m_ledger;
   string              m_account_key;
   double              m_equity_cache;
   datetime            m_equity_cache_time;
   int                 m_equity_cache_ttl_sec;

public:
   struct UnifiedExposure
     {
      double positions_risk_pct;        // broker positions risk
      double pending_risk_pct;          // pending orders estimated risk
      double reserved_risk_pct;         // ledger reservations (ACTIVE + PARTIALLY_COVERED)
      double total_exposure_pct;        // sum of all three
      double equity;                    // current account equity
      string currency;                  // account currency
      bool   unknown_exposure;          // any unknown/ambiguous position
      bool   valid;                     // calculation succeeded
      datetime timestamp;               // when calculated

                      UnifiedExposure(): positions_risk_pct(0), pending_risk_pct(0), reserved_risk_pct(0),
                          total_exposure_pct(0), equity(0), currency(""), unknown_exposure(false), valid(false), timestamp(0) {}
     };

CUnifiedExposureCalculator(): m_portfolio_risk(NULL), m_ledger(NULL),
                           m_equity_cache(0), m_equity_cache_time(0), m_equity_cache_ttl_sec(1) {} // F10: Reduced TTL to 1s; admission uses fresh equity via PortfolioRisk.GetExposureSnapshot()

    void SetDependencies(CAlgoPortfolioRisk *portfolio_risk, CExecutionLedger *ledger, const string& account_key)
      {
       m_portfolio_risk = portfolio_risk; m_ledger = ledger; m_account_key = account_key;
      }

    // F10: Get fresh equity (bypasses cache) - for authoritative risk calculations
    double GetFreshEquity()
      {
       double eq = AccountInfoDouble(ACCOUNT_EQUITY);
       if(eq > 0) { m_equity_cache = eq; m_equity_cache_time = TimeCurrent(); }
       return eq;
      }

    // GetCachedEquity: for UI/stress testing only - NOT for admission decisions
    // Admission uses PortfolioRisk.GetExposureSnapshot() which calls env.GetAccountEquity() directly
    double GetCachedEquity()
      {
       if(TimeCurrent() - m_equity_cache_time <= m_equity_cache_ttl_sec && m_equity_cache > 0)
          return m_equity_cache;
       return GetFreshEquity();
      }

   UnifiedExposure Calculate()
     {
      UnifiedExposure result;
      result.timestamp = TimeCurrent();

      double equity = GetCachedEquity();
      if(equity <= 0) { result.valid = false; return result; }
      result.equity = equity;
      result.currency = AccountInfoString(ACCOUNT_CURRENCY);

      // 1. Broker positions risk (managed + unknown) - compute directly from positions
      double pos_risk = 0;
      bool unknown = false;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

double pl = PositionGetDouble(POSITION_PROFIT);
           double swap = PositionGetDouble(POSITION_SWAP);
           // POSITION_COMMISSION is deprecated; commission is obtained from deal history via HistorySelectByPosition().
           // For unrealized risk estimation, commission on open positions is typically minimal or not yet charged.
           // Using 0 here avoids expensive history selection on every risk calculation.
           double commission = 0.0;
           double volume = PositionGetDouble(POSITION_VOLUME);
          string sym = PositionGetString(POSITION_SYMBOL);
          long magic = PositionGetInteger(POSITION_MAGIC);

          // For now, count all positions as risk (simplified)
          // Risk = unrealized P&L + swap + commission (negative = risk)
          double position_risk = -(pl + swap + commission); // positive = at risk
          if(position_risk > 0)
             pos_risk += position_risk;

          // Mark unknown if we can't verify magic ownership (simplified)
          unknown = true; // Conservative: assume some unknown exposure
         }
      result.positions_risk_pct = (equity > 0) ? (pos_risk / equity * 100.0) : 0;
      result.unknown_exposure = unknown;

      // 2. Pending orders estimated risk (simplified: count pending orders)
      double pending_risk = 0;
      int orders_total = OrdersTotal();
      for(int i = 0; i < orders_total; i++)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         // Simplified: each pending order adds small risk estimate
         pending_risk += equity * 0.001; // 0.1% per pending order
        }
      result.pending_risk_pct = (equity > 0) ? (pending_risk / equity * 100.0) : 0;

      // 3. Ledger reservations (durable intent before execution)
      double reserved_risk = 0;
      if(m_portfolio_risk)
        {
         CAlgoPortfolioRisk::ReservationAggregate agg;
         if(m_portfolio_risk.GetReservationAggregate(agg) && agg.valid)
            reserved_risk = agg.total_reserved_pct;
        }
      result.reserved_risk_pct = reserved_risk;

      // Total unified exposure
      result.total_exposure_pct = result.positions_risk_pct + result.pending_risk_pct + result.reserved_risk_pct;
      result.valid = true;
      return result;
     }

   // Stress test: project exposure under adverse conditions
   UnifiedExposure StressTest(const double equity_shock_pct, const double volatility_multiplier)
     {
      UnifiedExposure base = Calculate();
      if(!base.valid) return base;

      UnifiedExposure stressed = base;
      stressed.equity = base.equity * (1.0 - equity_shock_pct / 100.0);
      if(stressed.equity <= 0) { stressed.valid = false; return stressed; }

      // Positions risk increases with equity drop (same absolute risk, higher %)
      stressed.positions_risk_pct = (base.equity > 0) ? (base.positions_risk_pct * base.equity / stressed.equity * volatility_multiplier) : 0;
      stressed.pending_risk_pct *= volatility_multiplier;
      stressed.reserved_risk_pct *= volatility_multiplier;
      stressed.total_exposure_pct = stressed.positions_risk_pct + stressed.pending_risk_pct + stressed.reserved_risk_pct;

      return stressed;
     }
   };

// Dynamic Margin Calculator - adjusts margin requirements based on market conditions
class CDynamicMarginCalculator
  {
private:
   double m_base_margin_pct;
   double m_volatility_lookback;
   double m_max_margin_pct;
   double m_min_margin_pct;

public:
                      CDynamicMarginCalculator(): m_base_margin_pct(2.0), m_volatility_lookback(20),
                          m_max_margin_pct(10.0), m_min_margin_pct(0.5) {}

   void SetParams(double base_pct, int lookback, double max_pct, double min_pct)
     {
      m_base_margin_pct = base_pct;
      m_volatility_lookback = lookback;
      m_max_margin_pct = max_pct;
      m_min_margin_pct = min_pct;
     }

   // Calculate required margin for a position based on current volatility
   double CalculateMargin(const string symbol, const double volume, const ENUM_ORDER_TYPE order_type) const
     {
      // Get symbol specs
      double margin_rate = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
      if(margin_rate <= 0)
        {
         // Fallback: use contract size and price
         double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
         margin_rate = contract * price * m_base_margin_pct / 100.0;
        }

      // Apply volatility adjustment
      double atr = 0;
      // Simple ATR proxy using daily range
      MqlRates rates[];
      int copied = CopyRates(symbol, PERIOD_D1, 0, (int)m_volatility_lookback, rates);
      if(copied > 10)
        {
         double sum_range = 0;
         for(int i = 0; i < copied; i++)
            sum_range += rates[i].high - rates[i].low;
         double avg_range = sum_range / copied;
         double current_price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
         double atr_pct = (current_price > 0) ? (avg_range / current_price * 100.0) : 0;

         // Scale margin: higher ATR = higher margin requirement
         double vol_factor = 1.0 + atr_pct * 2.0; // 2x ATR as multiplier
         vol_factor = MathMin(vol_factor, m_max_margin_pct / m_base_margin_pct);
         vol_factor = MathMax(vol_factor, m_min_margin_pct / m_base_margin_pct);
         margin_rate *= vol_factor;
        }

      return margin_rate * volume;
     }

   // Check if account has sufficient free margin for new position
   bool HasFreeMargin(const double required_margin) const
     {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      return free_margin >= required_margin * 1.1; // 10% buffer
     }
  };

// Stress Test Framework
class CRiskStressTest
  {
public:
   struct StressScenario
     {
      string name;
      double equity_drop_pct;        // e.g., 10 = 10% equity drop
      double volatility_multiplier;  // e.g., 2.0 = 2x normal volatility
      double correlation_spike;      // 0-1, increases cross-asset correlation
      int    max_concurrent_positions; // position limit under stress
     };

   struct StressResult
     {
      string scenario_name;
      bool   passed;
      double pre_stress_exposure_pct;
      double post_stress_exposure_pct;
      double margin_surplus_pct;     // free margin / required margin - 1
      int    positions_liquidated;   // estimated positions to close
      string details;
     };

private:
   CUnifiedExposureCalculator *m_exposure_calc;
   CDynamicMarginCalculator   *m_margin_calc;

public:
                      CRiskStressTest(): m_exposure_calc(NULL), m_margin_calc(NULL) {}

   void SetDependencies(CUnifiedExposureCalculator *exp, CDynamicMarginCalculator *mar)
     {
      m_exposure_calc = exp; m_margin_calc = mar;
     }

void RunScenario(const StressScenario& scenario, StressResult& result) const
     {
      result.scenario_name = scenario.name;
      result.passed = true;

      if(!m_exposure_calc || !m_margin_calc)
        {
         result.passed = false;
         result.details = "Dependencies not set";
         return;
        }

      // Baseline
      CUnifiedExposureCalculator::UnifiedExposure base = m_exposure_calc.Calculate();
      if(!base.valid)
        {
         result.passed = false;
         result.details = "Baseline exposure calculation failed";
         return;
        }

      result.pre_stress_exposure_pct = base.total_exposure_pct;

      // Apply stress
      CUnifiedExposureCalculator::UnifiedExposure stressed = m_exposure_calc.StressTest(scenario.equity_drop_pct, scenario.volatility_multiplier);
      if(!stressed.valid)
        {
         result.passed = false;
         result.details = "Stress test calculation failed";
         return;
        }

      result.post_stress_exposure_pct = stressed.total_exposure_pct;

      // Check margin
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double required_margin = stressed.total_exposure_pct / 100.0 * stressed.equity;
      if(required_margin > 0)
         result.margin_surplus_pct = (free_margin / required_margin) - 1.0;
      else
         result.margin_surplus_pct = 100.0; // no margin needed

      // Check limits
      if(stressed.total_exposure_pct > 100.0) // > 100% equity at risk
        {
         result.passed = false;
         result.details = "Exposure exceeds equity under stress";
        }

      if(result.margin_surplus_pct < 0.1) // less than 10% margin buffer
        {
         result.passed = false;
         result.details = "Insufficient margin buffer: " + DoubleToString(result.margin_surplus_pct * 100, 1) + "%";
        }

      // Estimate liquidations needed
      double excess = MathMax(0, stressed.total_exposure_pct - 80.0); // target 80% max
      if(excess > 0 && base.positions_risk_pct > 0)
        {
         result.positions_liquidated = (int)MathCeil(excess / base.positions_risk_pct * 10); // rough estimate
        }

      result.details = "Equity shock: " + DoubleToString(scenario.equity_drop_pct, 1) + "%, Vol mult: " +
                       DoubleToString(scenario.volatility_multiplier, 1) + "x, Margin buffer: " +
                       DoubleToString(result.margin_surplus_pct * 100, 1) + "%";
     }

    // Run standard stress test suite
    void RunStandardSuite(StressResult& out[]) const
      {
       StressScenario scenarios[5];
       scenarios[0].name = "Mild"; scenarios[0].equity_drop_pct = 5.0; scenarios[0].volatility_multiplier = 1.5; scenarios[0].correlation_spike = 0.2; scenarios[0].max_concurrent_positions = 20;
       scenarios[1].name = "Moderate"; scenarios[1].equity_drop_pct = 10.0; scenarios[1].volatility_multiplier = 2.0; scenarios[1].correlation_spike = 0.4; scenarios[1].max_concurrent_positions = 15;
       scenarios[2].name = "Severe"; scenarios[2].equity_drop_pct = 20.0; scenarios[2].volatility_multiplier = 3.0; scenarios[2].correlation_spike = 0.6; scenarios[2].max_concurrent_positions = 10;
       scenarios[3].name = "FlashCrash"; scenarios[3].equity_drop_pct = 30.0; scenarios[3].volatility_multiplier = 5.0; scenarios[3].correlation_spike = 0.8; scenarios[3].max_concurrent_positions = 5;
       scenarios[4].name = "BlackSwan"; scenarios[4].equity_drop_pct = 50.0; scenarios[4].volatility_multiplier = 10.0; scenarios[4].correlation_spike = 1.0; scenarios[4].max_concurrent_positions = 0;

       for(int i = 0; i < 5; i++)
          RunScenario(scenarios[i], out[i]);
      }
  };

// Global risk optimization instances
CUnifiedExposureCalculator g_unified_exposure;
CDynamicMarginCalculator   g_dynamic_margin;
CRiskStressTest            g_risk_stress_test;


CAlgoStateManager   g_state;
CRiskEngine         g_risk_engine;
CAlgoPortfolioRisk  g_portfolio_risk;
CTradeExecutor      g_executor;
CExecutionLedger    g_execution_ledger;
CPositionManager    g_position_manager;
CAlgoLogger         g_logger;
CHybridDashboard    g_dashboard;
CSessionFilter      g_session_filter;
CMetricsExporter    g_metrics_exporter;
CAlertManager       g_alert_manager;
CTesterFitness      g_tester_fitness;
COptimizationController g_optimizer;
bool g_system_ready=false;
bool g_initialization_started=false;
bool g_initialization_failed=false;
bool g_last_trading_locked=false;
string g_last_runtime_dashboard_status="";
datetime g_ea_start_time=0;

// Safe Dashboard-Only Mode: blocks all broker mutation paths
// Enforcement (IsSafeModeEnforced):
//   - Live (outside Tester): ALWAYS enforced if InpDashboardSafeMode=true (fail-closed)
//   - Visual Tester: enforced if InpDashboardSafeMode=true
//   - Non-Visual Tester: enforced if InpDashboardSafeMode=true AND InpEnforceSafeModeInTester=true (default)
// Active dashboard display (IsSafeModeActive): only MQL_TESTER && MQL_VISUAL_MODE && InpDashboardSafeMode
int g_blocked_mutation_count = 0;
int g_executed_mutation_count = 0;

bool IsSafeModeActive()
{
   return (MQLInfoInteger(MQL_TESTER) != 0) &&
          (MQLInfoInteger(MQL_VISUAL_MODE) != 0) &&
          InpDashboardSafeMode;
}

bool IsSafeModeEnforced()
{
   // Safe Mode is fail-closed outside Tester or when not in Visual Mode
   // If InpEnforceSafeModeInTester is true, also enforce in Tester without Visual Mode
   bool in_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   bool in_visual = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);

   // Outside Tester: Safe Mode enforced if enabled (fail-closed)
   if(!in_tester)
      return InpDashboardSafeMode;

   // Inside Visual Tester: Safe Mode enforced if enabled
   if(in_visual)
      return InpDashboardSafeMode;

   // Inside non-Visual Tester: Safe Mode enforced only if both enabled AND Enforce flag set
   return InpDashboardSafeMode && InpEnforceSafeModeInTester;
}

//==================================================================
// P0-2: External Risk Lock via Global Variables
//==================================================================
// State codes for External Risk Lock
#define EXT_RISK_LOCK_DISABLED         0
#define EXT_RISK_LOCK_UNLOCKED         1
#define EXT_RISK_LOCK_LOCKED           2
#define EXT_RISK_LOCK_UNKNOWN          3
// Additional states for detailed tracking (not used in switch, mapped to UNKNOWN)
#define EXT_RISK_LOCK_SOURCE_UNAVAILABLE  4
#define EXT_RISK_LOCK_STALE               5
#define EXT_RISK_LOCK_SCOPE_MISMATCH      6

// External Risk Lock reason codes (stored as int in Global Variables)
enum ENUM_EXT_RISK_LOCK_REASON
  {
   EXT_RISK_LOCK_REASON_NONE = 0,
   EXT_RISK_LOCK_REASON_MANUAL = 1,
   EXT_RISK_LOCK_REASON_AUTO = 2,
   EXT_RISK_LOCK_REASON_RISK_MGR = 3,
   EXT_RISK_LOCK_REASON_TTL_EXPIRED = 4,
   EXT_RISK_LOCK_REASON_STALE = 5,
   EXT_RISK_LOCK_REASON_SCOPE_MISMATCH = 6,
   EXT_RISK_LOCK_REASON_DISABLED = 7,
   EXT_RISK_LOCK_REASON_GV_NOT_FOUND = 8,
   EXT_RISK_LOCK_REASON_GV_READ_FAILED = 9,
   EXT_RISK_LOCK_REASON_GV_READ_PENDING = 10,
   EXT_RISK_LOCK_REASON_UNKNOWN = 11
   };

// External Risk Lock source codes (stored as int in Global Variables)
enum ENUM_EXT_RISK_LOCK_SOURCE
  {
   EXT_RISK_LOCK_SRC_NONE = 0,
   EXT_RISK_LOCK_SRC_MANUAL = 1,
   EXT_RISK_LOCK_SRC_RISK_MGR = 2,
   EXT_RISK_LOCK_SRC_AUTO = 3,
   EXT_RISK_LOCK_SRC_EXTERNAL_TOOL = 4,
   EXT_RISK_LOCK_SRC_SYSTEM = 5
  };

// Convert reason code to human-readable string
string ExtRiskLockReasonToString(const int reason_code)
  {
   switch(reason_code)
     {
      case EXT_RISK_LOCK_REASON_NONE:           return "None";
      case EXT_RISK_LOCK_REASON_MANUAL:         return "Manual lock";
      case EXT_RISK_LOCK_REASON_AUTO:           return "Automatic lock";
      case EXT_RISK_LOCK_REASON_RISK_MGR:       return "Risk Manager";
      case EXT_RISK_LOCK_REASON_TTL_EXPIRED:    return "TTL expired";
      case EXT_RISK_LOCK_REASON_STALE:          return "State stale";
      case EXT_RISK_LOCK_REASON_SCOPE_MISMATCH: return "Scope mismatch";
      case EXT_RISK_LOCK_REASON_DISABLED:       return "Disabled by configuration";
      case EXT_RISK_LOCK_REASON_GV_NOT_FOUND:   return "GV not found";
case EXT_RISK_LOCK_REASON_GV_READ_FAILED: return "GV read failed";
       case EXT_RISK_LOCK_REASON_GV_READ_PENDING: return "GV read pending (retry)";
       case EXT_RISK_LOCK_REASON_UNKNOWN:        return "Unknown";
       default:                                  return "Invalid code (" + IntegerToString(reason_code) + ")";
      }
    }

// Convert source code to human-readable string
string ExtRiskLockSourceToString(const int source_code)
  {
   switch(source_code)
     {
      case EXT_RISK_LOCK_SRC_NONE:          return "None";
      case EXT_RISK_LOCK_SRC_MANUAL:        return "MANUAL";
      case EXT_RISK_LOCK_SRC_RISK_MGR:      return "RISK_MGR";
      case EXT_RISK_LOCK_SRC_AUTO:          return "AUTO";
      case EXT_RISK_LOCK_SRC_EXTERNAL_TOOL: return "EXTERNAL_TOOL";
      case EXT_RISK_LOCK_SRC_SYSTEM:        return "SYSTEM";
      default:                              return "INVALID(" + IntegerToString(source_code) + ")";
     }
  }

struct ExtRiskLockState
  {
   int        state;              // EXT_RISK_LOCK_DISABLED/UNLOCKED/LOCKED/UNKNOWN
   int        reason_code;        // ENUM_EXT_RISK_LOCK_REASON
   int        source_code;        // ENUM_EXT_RISK_LOCK_SOURCE
   datetime   updated_at;         // Last update timestamp
   datetime   expiry;             // Expiry timestamp (0 = no expiry)
   int        revision;           // Revision counter for change detection
   bool       valid;              // True if state was successfully read
   bool       read_complete;      // True if all fields read and validated
   bool       stale;              // True if timestamp/expiry policy detected stale data
  };

// P0-2: Global storage for External Risk Lock state (updated in RefreshTradingState)
ExtRiskLockState g_ext_risk_lock_state;
bool g_ext_risk_lock_state_valid=false;

//==================================================================
// Dashboard helpers
//==================================================================
// F11: Snapshot sharing via Global Variables for multi-chart Dashboard
// P0 FIX: Key length must not exceed 63 chars (MQL5 Global Variable limit).
// Original format: "ALGO_HYBRID_SNAPSHOT_<group_key>_<symbol>_<field>" could exceed 63 chars.
// New format: "AHSS_<hash8>_<field_short>" where hash8 = first 8 chars of hash(group_key + "|" + symbol)
// Field names shortened: generation→gen, snapshot_time→sn_t, last_success_time→ls_t,
// current_stage→stg, last_block_reason→blk, configured_style→cfg, regime_code→reg,
// bias_code→bis, long_code→lng, short_code→sht, regime_state→rs, bias_state→bs, long_state→ls, short_state→ss

string SnapshotGVKey(const string symbol, const string field)
  {
   // Build compact key: AHSS_<hash8>_<field_short>
   // Normalize symbol to handle broker suffixes/prefixes (e.g., EURUSD.pro vs EURUSD)
   // This ensures Coordinator and Chart Context generate identical GV keys for the same logical symbol.
   string norm_symbol = NormalizeSymbolForComparison(symbol);
   string combined = g_strategy_group_key + "|" + norm_symbol;
   uint h = 5381;
   for(int i = 0; i < StringLen(combined); i++)
     {
      h = ((h << 5) + h) + (uint)StringGetCharacter(combined, i);
     }
   string hash8 = IntegerToString((long)h, 16);
   if(StringLen(hash8) > 8) hash8 = StringSubstr(hash8, 0, 8);

   // Map field names to short versions
   string field_short = field;
   if(field == "generation") field_short = "gen";
   else if(field == "snapshot_time") field_short = "sn_t";
   else if(field == "last_success_time") field_short = "ls_t";
   else if(field == "current_stage") field_short = "stg";
   else if(field == "last_block_reason") field_short = "blk";
   else if(field == "configured_style") field_short = "cfg";
   else if(field == "regime_code") field_short = "reg";
   else if(field == "bias_code") field_short = "bis";
   else if(field == "long_code") field_short = "lng";
   else if(field == "short_code") field_short = "sht";
   else if(field == "regime_state") field_short = "rs";
   else if(field == "bias_state") field_short = "bs";
   else if(field == "long_state") field_short = "ls";
   else if(field == "short_state") field_short = "ss";

string key = "AHSS_" + hash8 + "_" + field_short;
    // Safety: ensure key <= 63 chars (should be ~20 chars with new format)
    if(StringLen(key) > 63)
      {
       key = StringSubstr(key, 0, 63);
      }
    // NOTE: 32-bit hash (8 hex chars) has collision risk (~1 in 4 billion per pair).
    // Accepted for expected cardinality (few dozen symbols/groups). If higher
    // cardinality is needed, extend hash length within 63-char limit.
    return key;
  }

// WriteSnapshotToGV: returns true if all 14 GlobalVariableSet calls succeed
bool WriteSnapshotToGV(const string symbol,
                         const int generation,
                         const datetime snapshot_time,
                         const datetime last_success_time,
                         const int current_stage_code,
                         const int last_block_reason_code,
                         const int configured_style,
                         const int regime_code,
                         const int bias_code,
                         const int long_code,
                         const int short_code,
                         const int regime_state,
                         const int bias_state,
                         const int long_state,
                         const int short_state)
  {
   bool all_ok = true;
   string err_details = "";

   // Diagnostics: collect keys for logging
   string gv_keys_written[];
   string gv_keys_failed[];
   int written_count = 0;
   int failed_count = 0;

   // Check each GlobalVariableSet call individually
   string key;
   datetime result;
   int err;

   key = SnapshotGVKey(symbol, "generation");
   result = GlobalVariableSet(key, generation);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "gen key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "snapshot_time");
   result = GlobalVariableSet(key, snapshot_time);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "sn_t key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "last_success_time");
   result = GlobalVariableSet(key, last_success_time);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "ls_t key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "current_stage");
   result = GlobalVariableSet(key, current_stage_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "stg key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "last_block_reason");
   result = GlobalVariableSet(key, last_block_reason_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "blk key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "configured_style");
   result = GlobalVariableSet(key, configured_style);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "cfg key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "regime_code");
   result = GlobalVariableSet(key, regime_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "reg key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "bias_code");
   result = GlobalVariableSet(key, bias_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "bis key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "long_code");
   result = GlobalVariableSet(key, long_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "lng key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "short_code");
   result = GlobalVariableSet(key, short_code);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "sht key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "regime_state");
   result = GlobalVariableSet(key, regime_state);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "rs key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "bias_state");
   result = GlobalVariableSet(key, bias_state);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "bs key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "long_state");
   result = GlobalVariableSet(key, long_state);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "ls key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   key = SnapshotGVKey(symbol, "short_state");
   result = GlobalVariableSet(key, short_state);
   if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "ss key=" + key + " err=" + IntegerToString(err); ResetLastError(); ArrayResize(gv_keys_failed, failed_count + 1); gv_keys_failed[failed_count] = key; failed_count++; }
   else { ArrayResize(gv_keys_written, written_count + 1); gv_keys_written[written_count] = key; written_count++; }

   if(!all_ok)
     {
      g_logger.Event(LOG_ERROR, "DASHBOARD", "SNAPSHOT_GV_WRITE_FAILED", symbol, "", "", "", "FAIL", "GV_WRITE",
                     "One or more GlobalVariableSet failed: " + err_details);
     }

// Diagnostics logging
    if(g_dashboard_diag_enabled)
      {
       // Pass max key length and a summary
       int max_key_len = 0;
       for(int k = 0; k < written_count; k++)
         {
          if(StringLen(gv_keys_written[k]) > max_key_len)
             max_key_len = StringLen(gv_keys_written[k]);
         }
       for(int k = 0; k < failed_count; k++)
         {
          if(StringLen(gv_keys_failed[k]) > max_key_len)
             max_key_len = StringLen(gv_keys_failed[k]);
         }
       string written_summary = "";
       for(int k = 0; k < written_count && k < 3; k++)
         {
          if(written_summary != "") written_summary += ",";
          written_summary += gv_keys_written[k];
         }
       string failed_summary = "";
       for(int k = 0; k < failed_count && k < 3; k++)
         {
          if(failed_summary != "") failed_summary += ",";
          failed_summary += gv_keys_failed[k];
         }
       g_dashboard_diag.LogSnapshotWrite(symbol, generation, all_ok, err_details, written_summary, failed_summary, max_key_len);
      }

   return all_ok;
  }

//==================================================================
// P0-2: External Risk Lock via Global Variables
//==================================================================
// DJB2 hash for compact GV key generation (used by both Snapshot and ExtRiskLock)
uint DJB2Hash8(const string str)
  {
   uint hash = 5381;
   for(int i = 0; i < StringLen(str); ++i)
     {
      hash = ((hash << 5) + hash) + (ushort)StringGetCharacter(str, i);
     }
   return hash & 0xFFFFFFFF;
  }

// Compact External Risk Lock GV Key: "AERL_<hash8>_<field_short>"
// hash8 = DJB2 hash of account_key (server_login), 8 hex chars
// field_short: state→st, reason→rsn, source→src, updated_at→upd, expiry→exp, revision→rev
// Max length: 5 + 1 + 8 + 1 + 4 = 19 chars (well under 63-char MQL5 GV limit)
string ExtRiskLockGVKey(const string field)
  {
   string account_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   uint hash = DJB2Hash8(account_key);
   string hash8 = IntegerToString((long)hash, 16);
   if(StringLen(hash8) > 8) hash8 = StringSubstr(hash8, 0, 8);
   else if(StringLen(hash8) < 8)
     {
      string zeros = "";
      for(int z = 0; z < 8 - StringLen(hash8); ++z) zeros += "0";
      hash8 = zeros + hash8;
     }

   string field_short;
   if(field == "state") field_short = "st";
   else if(field == "reason") field_short = "rsn";
   else if(field == "source") field_short = "src";
   else if(field == "updated_at") field_short = "upd";
   else if(field == "expiry") field_short = "exp";
   else if(field == "revision") field_short = "rev";
   else field_short = field; // fallback for unknown fields

   string key = "AERL_" + hash8 + "_" + field_short;
   if(StringLen(key) > 63) key = StringSubstr(key, 0, 63);
   return key;
  }

// Non-blocking retry state for External Risk Lock GV reads
// Persists across OnTick/OnTimer calls to spread retries without Sleep()
static int s_erl_retry_attempt = 0;
static bool s_erl_reads_ok[6];           // Tracks which of 6 fields read successfully
static double s_erl_cached_vals[6];      // Caches successfully read values
static datetime s_erl_last_retry_time = 0;
static const int ERL_MAX_READ_RETRIES = 3;
static const int ERL_RETRY_DELAY_MS = 100;

// Read External Risk Lock state from Global Variables
// Returns state struct with valid=false if disabled, unavailable, or stale
// Non-blocking bounded retry: spreads retries across event calls (no Sleep)
// Returns read_complete=false while retries in progress; fail-closed after max retries
  ExtRiskLockState ReadExtRiskLockState()
    {
    ExtRiskLockState state;
    state.state = EXT_RISK_LOCK_UNKNOWN;
    state.reason_code = EXT_RISK_LOCK_REASON_NONE;
    state.source_code = EXT_RISK_LOCK_SRC_NONE;
    state.updated_at = 0;
    state.expiry = 0;
    state.revision = 0;
    state.valid = false;
    state.read_complete = false;
    state.stale = false;

    if(!InpExternalRiskLockEnabled)
      {
      state.state = EXT_RISK_LOCK_DISABLED;
      state.reason_code = EXT_RISK_LOCK_REASON_DISABLED;
      state.valid = true;
      state.read_complete = true;
      state.stale = false;
      // Reset retry state on disabled
      s_erl_retry_attempt = 0;
      return state;
      }

    string state_key = ExtRiskLockGVKey("state");
    if(!GlobalVariableCheck(state_key))
      {
      state.reason_code = EXT_RISK_LOCK_REASON_GV_NOT_FOUND;
      if(InpExternalRiskLockFailClosed)
        {
        state.state = EXT_RISK_LOCK_UNKNOWN; // Fail-closed
        }
      else
        {
        state.state = EXT_RISK_LOCK_UNLOCKED; // Permissive (not recommended)
        }
      state.valid = true;
      state.read_complete = true;
      state.stale = false;
      // Reset retry state on GV not found
      s_erl_retry_attempt = 0;
      return state;
      }

    // Non-blocking bounded retry: attempt one read cycle per call
    // Field indices: 0=state, 1=reason, 2=source, 3=updated_at, 4=expiry, 5=revision
    bool all_reads_ok = true;
    string gv_keys[6];
    gv_keys[0] = state_key;
    gv_keys[1] = ExtRiskLockGVKey("reason");
    gv_keys[2] = ExtRiskLockGVKey("source");
    gv_keys[3] = ExtRiskLockGVKey("updated_at");
    gv_keys[4] = ExtRiskLockGVKey("expiry");
    gv_keys[5] = ExtRiskLockGVKey("revision");

    // Initialize retry state on first attempt
    if(s_erl_retry_attempt == 0)
      {
      for(int i = 0; i < 6; i++) { s_erl_reads_ok[i] = false; s_erl_cached_vals[i] = 0; }
      s_erl_retry_attempt = 1;
      s_erl_last_retry_time = TimeCurrent();
      }

    // Attempt to read any fields not yet successfully read
    for(int i = 0; i < 6; i++)
      {
      if(!s_erl_reads_ok[i])
        {
        double val = 0;
        if(GlobalVariableGet(gv_keys[i], val))
          {
          s_erl_reads_ok[i] = true;
          s_erl_cached_vals[i] = val;
          }
        else
          {
          all_reads_ok = false;
          }
        }
      else
        {
        // Use cached value
        }

      // Check if all reads succeeded
      if(s_erl_reads_ok[i]) continue;
      all_reads_ok = false;
      }

    // If all reads succeeded, build complete state
    if(all_reads_ok)
      {
      state.state = (int)s_erl_cached_vals[0];
      state.reason_code = (int)s_erl_cached_vals[1];
      state.source_code = (int)s_erl_cached_vals[2];
      state.updated_at = (datetime)s_erl_cached_vals[3];
      state.expiry = (datetime)s_erl_cached_vals[4];
      state.revision = (int)s_erl_cached_vals[5];

      // Check TTL/staleness
      datetime now = TimeCurrent();
      if(state.expiry > 0 && now > state.expiry)
        {
        state.reason_code = EXT_RISK_LOCK_REASON_TTL_EXPIRED;
        if(InpExternalRiskLockFailClosed)
          state.state = EXT_RISK_LOCK_UNKNOWN; // Fail-closed on stale
        else
          state.state = EXT_RISK_LOCK_UNLOCKED;
        state.stale = true;
        }
      else if(InpExternalRiskLockTTL > 0 && (now - state.updated_at) > InpExternalRiskLockTTL)
        {
        state.reason_code = EXT_RISK_LOCK_REASON_STALE;
        if(InpExternalRiskLockFailClosed)
          state.state = EXT_RISK_LOCK_UNKNOWN; // Fail-closed on stale
        else
          state.state = EXT_RISK_LOCK_UNLOCKED;
        state.stale = true;
        }

      state.valid = true;
      state.read_complete = true;
      // Reset retry state for next call
      s_erl_retry_attempt = 0;
      return state;
      }

    // Not all reads succeeded yet
    if(s_erl_retry_attempt < ERL_MAX_READ_RETRIES)
      {
      // Increment attempt counter for next call
      s_erl_retry_attempt++;
      // Return incomplete state (read_complete=false) - caller handles fail-closed
      state.reason_code = EXT_RISK_LOCK_REASON_GV_READ_PENDING;
      state.valid = false;
      state.read_complete = false;
      state.stale = false;
      return state;
      }

    // Max retries exhausted - fail-closed
    state.reason_code = EXT_RISK_LOCK_REASON_GV_READ_FAILED;
    state.valid = false;
    state.read_complete = false; // Explicitly incomplete after retries
    state.stale = false;
    // Reset retry state for next call
    s_erl_retry_attempt = 0;
    return state;
    }

// Write External Risk Lock state to Global Variables (for external control tools/scripts)
 // Returns true if all 6 GlobalVariableSet calls succeed
 bool WriteExtRiskLockState(const int state_code,
                            const int reason_code,
                            const int source_code,
                            const datetime expiry,
                            const int revision)
   {
    if(!InpExternalRiskLockEnabled)
      {
       g_logger.Event(LOG_INFO, "RISK", "EXT_RISK_LOCK_WRITE_SKIPPED", "", "", "", "", "SKIP", "EXT_LOCK",
                      "External Risk Lock disabled by configuration");
       return false;
      }
    bool all_ok = true;
    string err_details = "";
    string key;
    datetime result;
    int err;

    key = ExtRiskLockGVKey("state");
    result = GlobalVariableSet(key, state_code);
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "st key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    key = ExtRiskLockGVKey("reason");
    result = GlobalVariableSet(key, reason_code);
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "rsn key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    key = ExtRiskLockGVKey("source");
    result = GlobalVariableSet(key, source_code);
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "src key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    key = ExtRiskLockGVKey("updated_at");
    result = GlobalVariableSet(key, TimeCurrent());
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "upd key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    key = ExtRiskLockGVKey("expiry");
    result = GlobalVariableSet(key, expiry);
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "exp key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    key = ExtRiskLockGVKey("revision");
    result = GlobalVariableSet(key, revision);
    if(result == 0) { err = GetLastError(); all_ok = false; if(err_details != "") err_details += ", "; err_details += "rev key=" + key + " err=" + IntegerToString(err); ResetLastError(); }

    if(!all_ok)
      {
       g_logger.Event(LOG_ERROR, "RISK", "EXT_RISK_LOCK_GV_WRITE_FAILED", "", "", "", "", "FAIL", "GV_WRITE",
                      "One or more GlobalVariableSet failed: " + err_details);
      }

    return all_ok;
   }

// P0-2: Convert EA's ExtRiskLockState to PortfolioRisk's ExtRiskLockState
 CAlgoPortfolioRisk::ExtRiskLockState ToPortfolioRiskLockState(const ExtRiskLockState &src)
   {
    CAlgoPortfolioRisk::ExtRiskLockState dst;
    dst.state = src.state;
    dst.reason = ExtRiskLockReasonToString(src.reason_code);
    dst.source = ExtRiskLockSourceToString(src.source_code);
    dst.updated_at = src.updated_at;
    dst.expiry = src.expiry;
    dst.revision = src.revision;
    dst.valid = src.valid;
    dst.read_complete = src.read_complete;
    dst.stale = src.stale;
    dst.fail_closed = InpExternalRiskLockFailClosed;
    return dst;
   }

// P0-2: Fresh read of External Risk Lock state (for final submission gate)
ExtRiskLockState ReadExtRiskLockStateFresh()
{
   return ReadExtRiskLockState();
  }

//+------------------------------------------------------------------+
//| Helper: Read snapshot from Global Variables                      |
//+------------------------------------------------------------------+
struct GVSnapshotData
  {
   int generation;
   datetime snapshot_time;
   datetime last_success_time;
   int current_stage_code;
   int last_block_reason_code;
   int configured_style;
   int regime_code;
   int bias_code;
   int long_code;
   int short_code;
   int regime_state;
   int bias_state;
   int long_state;
   int short_state;
bool valid;
   };

//+------------------------------------------------------------------+
//| Read snapshot from GV for a symbol                               |
//+------------------------------------------------------------------+
bool ReadGVSnapshot(const string symbol, GVSnapshotData &snap)
  {
   string gen_key = SnapshotGVKey(symbol, "generation");
   if(!GlobalVariableCheck(gen_key))
     {
      snap.valid = false;
      // Diagnostics logging
      if(g_dashboard_diag_enabled)
        {
         g_dashboard_diag.LogSnapshotRead(symbol, false, 0, 0, "GV generation key not found: " + gen_key);
        }
      return false;
     }
   snap.generation = (int)GlobalVariableGet(gen_key);
   snap.snapshot_time = (datetime)GlobalVariableGet(SnapshotGVKey(symbol, "snapshot_time"));
   snap.last_success_time = (datetime)GlobalVariableGet(SnapshotGVKey(symbol, "last_success_time"));
   snap.current_stage_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "current_stage"));
   snap.last_block_reason_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "last_block_reason"));
   snap.configured_style = (int)GlobalVariableGet(SnapshotGVKey(symbol, "configured_style"));
   snap.regime_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "regime_code"));
   snap.bias_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "bias_code"));
   snap.long_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "long_code"));
   snap.short_code = (int)GlobalVariableGet(SnapshotGVKey(symbol, "short_code"));
   snap.regime_state = (int)GlobalVariableGet(SnapshotGVKey(symbol, "regime_state"));
   snap.bias_state = (int)GlobalVariableGet(SnapshotGVKey(symbol, "bias_state"));
   snap.long_state = (int)GlobalVariableGet(SnapshotGVKey(symbol, "long_state"));
   snap.short_state = (int)GlobalVariableGet(SnapshotGVKey(symbol, "short_state"));
   snap.valid = true;

   // Diagnostics logging
   if(g_dashboard_diag_enabled)
     {
      g_dashboard_diag.LogSnapshotRead(symbol, true, snap.generation, snap.snapshot_time, "");
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Apply GV snapshot to dashboard display                   |
//+------------------------------------------------------------------+
void ApplySnapshotToDashboard(const string symbol, const GVSnapshotData &snap)
  {
   string regime_text = EnumToString((ENUM_REGIME_TYPE)snap.regime_code);
   string bias_text = EnumToString((ENUM_BIAS_DIRECTION)snap.bias_code);
   string long_text = (snap.long_code == 1 ? "LONG CANDIDATE" : "NO LONG");
   string short_text = (snap.short_code == 1 ? "SHORT CANDIDATE" : "NO SHORT");
   string current_stage_text;
   switch(snap.current_stage_code)
     {
      case 1: current_stage_text = "WAITING_FOR_NEW_ENTRY_BAR"; break;
      case 2: current_stage_text = "WAITING_FOR_SIGNAL_BAR"; break;
      case 3: current_stage_text = "EVALUATED"; break;
      case 4: current_stage_text = "BLOCKED"; break;
      default: current_stage_text = "NOT_EVALUATED"; break;
     }
   string last_block_reason_text;
   switch(snap.last_block_reason_code)
     {
      case 1: last_block_reason_text = "NO_NEW_CLOSED_BAR"; break;
      case 2: last_block_reason_text = "SIGNAL_MARKET_INVALID"; break;
      default: last_block_reason_text = (snap.last_block_reason_code == 0 ? "" : "UNKNOWN"); break;
     }

   g_dashboard.SetRuntimeSnapshot(
      EnumToString((ENUM_TRADING_STYLE)snap.configured_style),
      regime_text,
      bias_text,
      long_text,
      short_text,
      current_stage_text,
      last_block_reason_text,
      snap.snapshot_time,
      snap.last_success_time,
      (snap.regime_state == SNAP_VALID));

   // Diagnostics logging
   if(g_dashboard_diag_enabled)
     {
      g_dashboard_diag.LogDashboardApply(symbol, true, current_stage_text, regime_text, bias_text,
                                         long_text, short_text, (snap.regime_state == SNAP_VALID), snap.generation);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboardForChart()
  {
   if(!InpDashboard)
      return;

   g_dashboard.ResetDiagnosticsFields();

   g_last_runtime_dashboard_status="";
   string chart_symbol=ChartSymbol(0);

   // First: try to find local runtime for this chart symbol
   for(int i=0;i<g_runtime.Total();i++)
     {
      CSymbolRuntime *runtime = g_runtime.At(i);
      if(!runtime || !runtime.valid || runtime.symbol!=chart_symbol)
         continue;

// F11: If local snapshot not evaluated, try reading from Global Variables (shared by Coordinator)
        if(runtime.snapshot.generation == 0)
          {
           GVSnapshotData gv_snap;
           if(ReadGVSnapshot(chart_symbol, gv_snap))
             {
              runtime.snapshot.generation = gv_snap.generation;
              runtime.snapshot.snapshot_time = gv_snap.snapshot_time;
              runtime.snapshot.last_success_time = gv_snap.last_success_time;
              runtime.snapshot.current_stage_code = gv_snap.current_stage_code;
              runtime.snapshot.last_block_reason_code = gv_snap.last_block_reason_code;
              runtime.snapshot.configured_style = (ENUM_TRADING_STYLE)gv_snap.configured_style;
              runtime.snapshot.regime_code = gv_snap.regime_code;
              runtime.snapshot.bias_code = gv_snap.bias_code;
              runtime.snapshot.long_code = gv_snap.long_code;
              runtime.snapshot.short_code = gv_snap.short_code;
              runtime.snapshot.regime_state = (ESnapshotFieldState)gv_snap.regime_state;
              runtime.snapshot.bias_state = (ESnapshotFieldState)gv_snap.bias_state;
              runtime.snapshot.long_state = (ESnapshotFieldState)gv_snap.long_state;
              runtime.snapshot.short_state = (ESnapshotFieldState)gv_snap.short_state;
             }
          }

// Diagnostics: Log runtime state
        if(g_dashboard_diag_enabled)
          {
           // Use snapshot_time for missing timestamp fields
           datetime snapshot_time = runtime.snapshot.snapshot_time;
           g_dashboard_diag.LogRuntimeState(
              runtime.symbol, i, runtime.valid,
              runtime.snapshot.generation,
              snapshot_time,      // last_process_time (use snapshot_time as proxy)
              snapshot_time,      // last_data_time
              snapshot_time,      // last_feature_time
              snapshot_time,      // last_evaluation_time
              snapshot_time,      // last_snapshot_time
              runtime.snapshot.current_stage_code,
              runtime.snapshot.regime_code,
              runtime.snapshot.bias_code,
              runtime.snapshot.long_code,
              runtime.snapshot.short_code);
          }

       MarketSnapshot market;
      ResetLastError();

if(!runtime.market_context.GetSnapshot(
            runtime.symbol,
            runtime.context_tf,
            market))
         {
          // Set System Health for market data unavailable
          g_dashboard.SetCoordinatorState("NO DATA", "MarketContext", false, "Market data freshness");
          g_dashboard.SetSnapshotState("NO DATA", "MarketContext", false, "Context: 300s");
          g_dashboard.SetBlockingSubsystem("MARKET_DATA", "MarketContext", true, "");
          g_dashboard.SetFailureReason("No market data available", "MarketContext", true, "");
          g_dashboard.SetActionRequired("Wait for market data", "MarketContext", true, "");
          g_dashboard.ShowStatus("WAITING FOR MARKET DATA | "+chart_symbol);
          g_dashboard.Render();
          ResetLastError();
          return;
         }

      // Apply snapshot to dashboard (reads from runtime.snapshot which now has GV data if available)
      GVSnapshotData snap;
      snap.generation = runtime.snapshot.generation;
      snap.snapshot_time = runtime.snapshot.snapshot_time;
      snap.last_success_time = runtime.snapshot.last_success_time;
      snap.current_stage_code = runtime.snapshot.current_stage_code;
      snap.last_block_reason_code = runtime.snapshot.last_block_reason_code;
      snap.configured_style = (int)runtime.snapshot.configured_style;
      snap.regime_code = runtime.snapshot.regime_code;
snap.bias_code = runtime.snapshot.bias_code;
      snap.long_code = runtime.snapshot.long_code;
      snap.short_code = runtime.snapshot.short_code;
      snap.regime_state = (int)runtime.snapshot.regime_state;
      snap.bias_state = (int)runtime.snapshot.bias_state;
      snap.long_state = (int)runtime.snapshot.long_state;
      snap.short_state = (int)runtime.snapshot.short_state;
       ApplySnapshotToDashboard(chart_symbol, snap);

      g_dashboard.Render();
      return;
     }

// Fix 1: Chart Context mode - read Coordinator-published GV snapshots directly
    // when no local runtime exists but we're registered with a Coordinator
    if(g_coordinator_mode == COORD_MODE_CHART_CONTEXT && g_reg_state == REG_STATE_REGISTERED)
      {
       GVSnapshotData gv_snap;
 if(ReadGVSnapshot(chart_symbol, gv_snap))
           {
            ApplySnapshotToDashboard(chart_symbol, gv_snap);
            g_dashboard.Render();
            // Explicit cleanup: deselect symbol to avoid leaving it selected in market watch
            SymbolSelect(chart_symbol, false);
            return;
          }
else
           {
            // Registered but no snapshot yet from Coordinator
            // Set System Health for waiting for Coordinator snapshot
            g_dashboard.SetCoordinatorState("CONNECTED", "Coordinator", true, "Lease: 30s");
            g_dashboard.SetAuthorityState("VALID", "Coordinator", true, "Epoch: "+IntegerToString(g_authority_epoch));
            g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
            g_dashboard.SetChartRegistrationState("REGISTERED", "ChartReg", true, "Protocol: v1");
            g_dashboard.SetSnapshotState("NO SNAPSHOT", "Coordinator", false, "Snapshot: pending");
            g_dashboard.SetBlockingSubsystem("COORDINATOR", "ChartReg", true, "");
            g_dashboard.SetFailureReason("Waiting for Coordinator snapshot", "ChartReg", true, "");
            g_dashboard.SetActionRequired("Wait for snapshot", "ChartReg", true, "");
            g_dashboard.ShowStatus("WAITING FOR COORDINATOR SNAPSHOT | " + chart_symbol);
            g_dashboard.Render();
            return;
           }
       }

    // No local runtime for chart symbol and no coordinator snapshot path available.
    // Report truthful readiness/registration state instead of a misleading configuration error.
    bool chart_symbol_in_universe=false;
    string discovered_symbols[];
    DiscoverTradableSymbols(discovered_symbols);
    // discovered_symbols[] holds resolved broker symbols; compare exactly (no heuristic
    // normalization) so broker suffix/prefix variants are never incorrectly matched.
    for(int di=0; di<ArraySize(discovered_symbols); di++)
      {
      if(discovered_symbols[di] == chart_symbol)
        {
        chart_symbol_in_universe=true;
        break;
        }
      }

if(g_coordinator_mode == COORD_MODE_CHART_CONTEXT)
       {
        if(g_reg_state == REG_STATE_PENDING || g_reg_state == REG_STATE_UNREGISTERED)
          {
           // Set System Health for pending/unregistered state
           g_dashboard.SetCoordinatorState("CONNECTED", "Coordinator", true, "Lease: 30s");
           g_dashboard.SetAuthorityState("VALID", "Coordinator", true, "Epoch: "+IntegerToString(g_authority_epoch));
           g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
           g_dashboard.SetChartRegistrationState((g_reg_state == REG_STATE_PENDING ? "PENDING" : "UNREGISTERED"), "ChartReg", false, "Protocol: v1");
           g_dashboard.SetSnapshotState("NO SNAPSHOT", "ChartReg", false, "Snapshot: pending registration");
           g_dashboard.SetBlockingSubsystem("REGISTRATION", "ChartReg", true, "");
           g_dashboard.SetFailureReason("Waiting for Coordinator registration", "ChartReg", true, "");
           g_dashboard.SetActionRequired("Wait for registration", "ChartReg", true, "");
           g_dashboard.ShowStatus("WAITING FOR COORDINATOR REGISTRATION | "+chart_symbol);
           g_dashboard.Render();
           return;
          }
        if(g_reg_state == REG_STATE_REJECTED)
          {
           // Set System Health for rejected registration
           g_dashboard.SetCoordinatorState("CONNECTED", "Coordinator", true, "Lease: 30s");
           g_dashboard.SetAuthorityState("VALID", "Coordinator", true, "Epoch: "+IntegerToString(g_authority_epoch));
           g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
           g_dashboard.SetChartRegistrationState("REJECTED", "ChartReg", false, "Protocol: v1");
           g_dashboard.SetSnapshotState("NO SNAPSHOT", "ChartReg", false, "Snapshot: registration rejected");
           g_dashboard.SetBlockingSubsystem("REGISTRATION", "ChartReg", true, "");
           g_dashboard.SetFailureReason("Registration rejected by Coordinator", "ChartReg", true, "");
           g_dashboard.SetActionRequired("Re-register or contact admin", "ChartReg", true, "");
           g_dashboard.ShowStatus("CHART CONTEXT REGISTRATION REJECTED | "+chart_symbol);
           g_dashboard.Render();
           return;
          }
        if(g_reg_state == REG_STATE_REGISTERED)
          {
           // Set System Health for registered but no snapshot
           g_dashboard.SetCoordinatorState("CONNECTED", "Coordinator", true, "Lease: 30s");
           g_dashboard.SetAuthorityState("VALID", "Coordinator", true, "Epoch: "+IntegerToString(g_authority_epoch));
           g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
           g_dashboard.SetChartRegistrationState("REGISTERED", "ChartReg", true, "Protocol: v1");
           g_dashboard.SetSnapshotState("NO SNAPSHOT", "Coordinator", false, "Snapshot: pending");
           g_dashboard.SetBlockingSubsystem("COORDINATOR", "ChartReg", true, "");
           g_dashboard.SetFailureReason("Waiting for Coordinator snapshot", "ChartReg", true, "");
           g_dashboard.SetActionRequired("Wait for snapshot", "ChartReg", true, "");
           g_dashboard.ShowStatus("WAITING FOR COORDINATOR SNAPSHOT | "+chart_symbol);
           g_dashboard.Render();
           return;
          }
        }

if(g_coordinator_mode == COORD_MODE_UNAVAILABLE)
       {
        string reason = g_coordinator_unavailable_reason;
        if(reason=="") reason = "UNKNOWN";
        // Set System Health for unavailable Coordinator
        g_dashboard.SetCoordinatorState("UNAVAILABLE", "Coordinator", false, "Lease: expired");
        g_dashboard.SetAuthorityState("UNKNOWN", "Coordinator", false, "Epoch: N/A");
        g_dashboard.SetLedgerState("UNKNOWN", "ExecutionLedger", false, "DB: unavailable");
        g_dashboard.SetChartRegistrationState("N/A", "ChartReg", false, "Protocol: N/A");
        g_dashboard.SetSnapshotState("NO SNAPSHOT", "Coordinator", false, "Snapshot: coordinator unavailable");
        g_dashboard.SetBlockingSubsystem("COORDINATOR", "Coordinator", true, "");
        g_dashboard.SetFailureReason(reason, "Coordinator", true, "");
        g_dashboard.SetActionRequired("Check Coordinator availability", "Coordinator", true, "");
        g_dashboard.ShowStatus("COORDINATOR UNAVAILABLE | "+reason+" | "+chart_symbol);
        g_dashboard.Render();
        return;
       }

if(g_coordinator_mode == COORD_MODE_UNINITIALIZED)
       {
        // Set System Health for uninitialized system
        g_dashboard.SetCoordinatorState("INITIALIZING", "Coordinator", false, "Lease: N/A");
        g_dashboard.SetAuthorityState("UNKNOWN", "Coordinator", false, "Epoch: N/A");
        g_dashboard.SetLedgerState("UNKNOWN", "ExecutionLedger", false, "DB: initializing");
        g_dashboard.SetChartRegistrationState("N/A", "ChartReg", false, "Protocol: N/A");
        g_dashboard.SetSnapshotState("NO SNAPSHOT", "Coordinator", false, "Snapshot: system initializing");
        g_dashboard.SetBlockingSubsystem("INIT", "Coordinator", true, "");
        g_dashboard.SetFailureReason("System initializing", "Coordinator", true, "");
        g_dashboard.SetActionRequired("Wait for initialization", "Coordinator", true, "");
        g_dashboard.ShowStatus("SYSTEM INITIALIZING | "+chart_symbol);
        g_dashboard.Render();
        return;
       }

if(chart_symbol_in_universe)
       {
        // Set System Health for waiting for symbol runtime
        g_dashboard.SetCoordinatorState((g_coordinator_mode == COORD_MODE_COORDINATOR ? "COORDINATOR" : "CHART_CONTEXT"), "Runtime", true, "");
        g_dashboard.SetAuthorityState("VALID", "Authority", true, "Epoch: "+IntegerToString(g_authority_epoch));
        g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
        g_dashboard.SetChartRegistrationState((g_reg_state == REG_STATE_REGISTERED ? "REGISTERED" : "N/A"), "ChartReg", g_reg_state == REG_STATE_REGISTERED, "");
        g_dashboard.SetSnapshotState("NO RUNTIME", "Runtime", false, "Runtime: initializing");
        g_dashboard.SetBlockingSubsystem("RUNTIME", "Runtime", true, "");
        g_dashboard.SetFailureReason("Symbol runtime not initialized", "Runtime", true, "");
        g_dashboard.SetActionRequired("Wait for runtime initialization", "Runtime", true, "");
g_dashboard.ShowStatus("WAITING FOR SYMBOL RUNTIME | "+chart_symbol);
        g_dashboard.Render();
        return;
       }

    // Set System Health for symbol not in universe (final fallback) - BEFORE Render()
    g_dashboard.SetCoordinatorState((g_coordinator_mode == COORD_MODE_COORDINATOR ? "COORDINATOR" : "CHART_CONTEXT"), "Config", true, "");
    g_dashboard.SetAuthorityState("VALID", "Authority", true, "Epoch: "+IntegerToString(g_authority_epoch));
    g_dashboard.SetLedgerState("VALID", "ExecutionLedger", true, "DB: available");
    g_dashboard.SetChartRegistrationState((g_reg_state == REG_STATE_REGISTERED ? "REGISTERED" : "N/A"), "ChartReg", g_reg_state == REG_STATE_REGISTERED, "");
    g_dashboard.SetSnapshotState("NOT IN UNIVERSE", "Config", false, "Snapshot: symbol not configured");
    g_dashboard.SetBlockingSubsystem("CONFIG", "Config", true, "");
    g_dashboard.SetFailureReason("Chart symbol not in discovered universe", "Config", true, "");
    g_dashboard.SetActionRequired("Check symbol configuration", "Config", true, "");

    g_dashboard.ShowStatus("CHART SYMBOL NOT DISCOVERED | "+chart_symbol);
    g_dashboard.Render();
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeText(ENUM_TIMEFRAMES tf)
  {
   return CAlgoUtils::TimeframeToString(tf);
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
   g_dashboard.Render();
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
                           const PortfolioState& portfolio_state,
                           bool portfolio_state_available)
  {
   g_logger.Signal(decision);

   if(decision.status != DECISION_BUY_CANDIDATE &&
      decision.status != DECISION_SELL_CANDIDATE)
     {

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

    // P0-2: External Risk Lock check before RiskEngine.Evaluate (redundant but defense in depth)
    if(g_ext_risk_lock_state_valid && InpExternalRiskLockEnabled)
      {
      string rejection_code, rejection_reason;
      CAlgoPortfolioRisk::ExtRiskLockState pr_lock_state = ToPortfolioRiskLockState(g_ext_risk_lock_state);

      if(!g_portfolio_risk.CheckExternalRiskLock(pr_lock_state, rejection_code, rejection_reason))
        {
        risk.decision = RISK_REJECTED;
        risk.rejection_reason = REJECT_EXTERNAL_RISK_LOCKED;
        risk.reason = rejection_reason;
        g_logger.Event(
          LOG_WARNING, "RISK", "EXTERNAL_RISK_LOCK_BLOCK",
          legacy_signal.symbol, "", "", legacy_signal.signal_id,
          "REJECT", "EXT_RISK_LOCK", rejection_reason);
        g_logger.Risk(risk);

// Update Dashboard with ERL blocked state
         if(InpDashboard)
           {
            g_dashboard.SetExternalRiskLockState("BLOCKED", "ExternalRiskLock", true, "TTL=" + IntegerToString(InpExternalRiskLockTTL) + "s");
            g_dashboard.SetBlockingSubsystem("EXTERNAL_RISK_LOCK", "ExternalRiskLock", true, "");
            g_dashboard.SetFailureReason(rejection_reason, "ExternalRiskLock", true, "");
            g_dashboard.SetActionRequired("Clear external risk lock", "ExternalRiskLock", true, "");
           }
        return;
        }
      }

    // SP-01R.1: Fail-closed risk admission gate - before any risk calculation
    if(!portfolio_state_available)
      {
       g_logger.Event(LOG_WARNING, "RISK", "RISK_STATE_UNAVAILABLE_ADMISSION",
                      legacy_signal.symbol, "", "", legacy_signal.signal_id,
                      "REJECT", "RISK_UNAVAILABLE",
                      "Portfolio state unavailable; admission blocked before RiskEngine");
       risk.decision = RISK_REJECTED;
       risk.rejection_reason = REJECT_PORTFOLIO_RISK;
       g_logger.Risk(risk);
       // TEMPORARY BLOCK: portfolio state unavailable - do not consume
       return;
      }

    if(portfolio_state.trading_locked)
      {
       g_logger.Event(LOG_WARNING, "RISK", "RISK_LOCK_ADMISSION",
                      legacy_signal.symbol, "", "", legacy_signal.signal_id,
                      "REJECT", "RISK_LOCKED",
                      "Trading locked; admission blocked before RiskEngine");
       risk.decision = RISK_REJECTED;
       risk.rejection_reason = REJECT_PORTFOLIO_RISK;
       g_logger.Risk(risk);
       // TEMPORARY BLOCK: trading locked - do not consume
       return;
      }

    if(!g_risk_engine.Evaluate(legacy_signal, risk))
      {
      g_logger.Risk(risk);
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
      return;
     }

// P0-2: External Risk Lock check before CanAdmit (independent of RiskEngine)
    if(g_ext_risk_lock_state_valid && InpExternalRiskLockEnabled)
      {
      string rejection_code, rejection_reason;
      CAlgoPortfolioRisk::ExtRiskLockState pr_lock_state = ToPortfolioRiskLockState(g_ext_risk_lock_state);

      if(!g_portfolio_risk.CheckExternalRiskLock(pr_lock_state, rejection_code, rejection_reason))
        {
        risk.decision = RISK_REJECTED;
        risk.rejection_reason = REJECT_EXTERNAL_RISK_LOCKED;
        risk.reason = rejection_reason;

        g_logger.Event(
          LOG_WARNING, "PORTFOLIO", "EXTERNAL_RISK_LOCK_BLOCK_ADMIT",
          legacy_signal.symbol, "", "", legacy_signal.signal_id,
          "REJECT", "EXT_RISK_LOCK", rejection_reason);
        g_logger.Risk(risk);
        return;
        }
      }

    // F-002: Centralized admission with durable reservation aggregation (initial check).
    // This runs after PortfolioRisk.CanOpen and before durable intent creation.
    CAlgoPortfolioRisk::AdmissionDecision admission_decision;
    if(!g_portfolio_risk.CanAdmit(legacy_signal, risk, admission_decision))
      {
      risk.decision=RISK_REJECTED;
      risk.rejection_reason=REJECT_PORTFOLIO_RISK;
      risk.reason=admission_decision.rejection_reason;

      g_logger.Event(
         LOG_WARNING, "PORTFOLIO", "ADMISSION_REJECTED",
         legacy_signal.symbol,
         "",
         "",
         legacy_signal.signal_id,
         "REJECT",
         admission_decision.rejection_code,
         admission_decision.rejection_reason,
         0, 0,
         (double)risk.risk_percent,
         g_portfolio_risk.CurrentRiskPercent(),
         (double)portfolio_state.total_positions);

      g_logger.Risk(risk);
      return;
      }

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
    // F3: attempt_id must be collision-resistant across charts/instances/restart.
    // Combine the logical setup id with second+ms time and a process-local monotonic counter;
    // the ledger PRIMARY KEY rejects any residual collision (fail-closed).
    request.attempt_id = normalized_plan.setup_id + "_" + IntegerToString((long)TimeCurrent()) + "_" +
                         IntegerToString((long)GetTickCount()) + "_" + IntegerToString(++g_attempt_counter);

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
     // F-002: Validate risk reservation amount before creating durable intent (fail-closed).
      if(!(risk.actual_monetary_risk > 0.0 && MathIsValidNumber(risk.actual_monetary_risk)))
         {
         g_logger.Event(LOG_ERROR, "EXECUTION", "RISK_RESERVE_INVALID", request.symbol, "", "", request.signal_id,
                        "REJECT", "RISK_RESERVE", "RiskEngine did not provide valid actual_monetary_risk for reservation");
         runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
         return;
         }

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
      // F-005.2.2: Account scope for ownership resolution (schema v5).
      attempt_rec.account_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
     // SP-01R: Risk admission gate - must be before durable claim/intent
     if(!portfolio_state_available)
       {
        g_logger.Event(LOG_WARNING, "RISK", "RISK_STATE_UNAVAILABLE_ADMISSION", runtime.symbol, "", "",
                       decision.plan.setup_id, "REJECT", "RISK_UNAVAILABLE",
                       "Portfolio state unavailable; admission blocked");
        // TEMPORARY BLOCK: portfolio state unavailable - do not consume
        return;
       }

     if(portfolio_state.trading_locked)
       {
        g_logger.Event(LOG_WARNING, "RISK", "RISK_LOCK_ADMISSION", runtime.symbol, "", "",
                       decision.plan.setup_id, "REJECT", "RISK_LOCKED",
                       "Trading locked; admission blocked");
        // TEMPORARY BLOCK: trading locked - do not consume
        return;
       }

     // SP-01R.1: Defensive pre-intent boundary - non-Coordinator cannot create intent
     if(g_coordinator_mode != COORD_MODE_COORDINATOR)
       {
        g_logger.Event(LOG_WARNING, "AUTHORITY", "NON_COORDINATOR_BLOCK", runtime.symbol, "", "",
                       decision.plan.setup_id, "REJECT", "NON_COORDINATOR",
                       "Non-coordinator instance cannot create durable intent");
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
       }

     // SP-01R: Authority must be validated BEFORE durable claim/intent creation
     if(g_coordinator_mode == COORD_MODE_COORDINATOR)
       {
        string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
        if(!g_execution_ledger.ValidateAuthority(authority_key, g_owner_instance_token, g_authority_epoch))
          {
           g_logger.Event(LOG_WARNING, "AUTHORITY", "AUTHORITY_BLOCK_BEFORE_CLAIM", runtime.symbol, "", "",
                          decision.plan.setup_id, "REJECT", "AUTHORITY_INVALID",
                          "Authority invalid before durable claim; no intent created");
           // TEMPORARY BLOCK: authority invalid - do not consume
           return;
          }
       }

     {
     // RS01-CANON-01: stable canonical identity (v2). Legacy v1 claims recognized by ledger compatibility.
     string claim_intent_err = "";
     CExecutionLedger::ENUM_CLAIM_RESULT claim_res = g_execution_ledger.CreateSetupClaimAndIntent(
         g_strategy_group_key, normalized_plan.logical_setup_key, attempt_rec.canonical_identity, 2, attempt_rec, claim_intent_err);
     if(claim_res == CExecutionLedger::CLAIM_ALREADY_EXISTS)
        {
        // DUPLICATE: durable claim already exists (restart-safe duplicate prevention).
        // Verify existing claim & attempt status (Action 9); do not create a new attempt.
        g_logger.Event(LOG_WARNING, "EXECUTION", "SETUP_CLAIM_ALREADY_EXISTS", request.symbol, "", "", request.signal_id,
                       "REJECT", "CLAIM_ALREADY_EXISTS", "Durable claim already exists for logical setup; duplicate suppressed, no new attempt. lsk=" + normalized_plan.logical_setup_key + " err=" + claim_intent_err);
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
        }
     if(claim_res == CExecutionLedger::CLAIM_IDENTITY_COLLISION)
        {
        // AMBIGUOUS identity collision: stable components differ; no auto-resubmit, reconciliation required.
        g_logger.Event(LOG_ERROR, "EXECUTION", "SETUP_CLAIM_IDENTITY_COLLISION", request.symbol, "", "", request.signal_id,
                       "FAIL", "CLAIM_IDENTITY_COLLISION", "Claim identity collision for logical setup key; reconciliation required, no auto-resubmit. lsk=" + normalized_plan.logical_setup_key + " err=" + claim_intent_err);
        g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "Claim identity collision");
        runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
        return;
        }
     if(claim_res == CExecutionLedger::CLAIM_ERROR)
        {
        // LEDGER ERROR: atomic claim+intent failed (DB/error); fail-closed, temporary block, recovery via scheduler/freshness.
        // No durable intent was committed; nothing to reconcile yet. Do not MarkPlanConsumed terminally.
        g_logger.Event(LOG_ERROR, "EXECUTION", "SETUP_CLAIM_ERROR", request.symbol, "", "", request.signal_id,
                       "FAIL", "CLAIM_ERROR", "Atomic claim+intent acquisition failed (DB/error) - fail closed, no partial commit. lsk=" + normalized_plan.logical_setup_key + " err=" + claim_intent_err);
        return;
        }
}

     // F-005.2: Ledger allocates attempt_magic atomically with Intent.
     // Copy to request so TradeExecutor uses it for broker-visible Magic.
     request.attempt_magic = attempt_rec.attempt_magic;

      // Check ledger for blocking unresolved attempts
     string ledger_block = "";
     if(!g_execution_ledger.IsAvailable())
       {
        // Ledger unavailable: temporary block; recoverable when ledger returns.
        // Do not MarkPlanConsumed terminally — keep setup recoverable for Temporary Recovery (Scheduler + Freshness).
        g_logger.Event(
           LOG_WARNING, "EXECUTION", "EXECUTION_BLOCKED_LEDGER_UNAVAILABLE",
           request.symbol, "", "",
           request.signal_id,
           "REJECT", "LEDGER_UNAVAILABLE", "Execution ledger unavailable; temporary block, recovery via scheduler/freshness");
        return;
       }
     if(g_execution_ledger.HasBlockingUnresolved(ledger_block))
       {
        // Blocking unresolved attempt: reconciliation required, fail-closed, no auto-resubmit.
        g_logger.Event(
           LOG_WARNING, "EXECUTION", "EXECUTION_BLOCKED_UNRESOLVED",
           request.symbol, "", "",
           request.signal_id,
           "REJECT", "UNRESOLVED_ATTEMPT", "Blocking unresolved attempt; reconciliation required, no auto-resubmit");
        g_execution_ledger.MarkReconciliationRequired(request.attempt_id, "Blocking unresolved attempt before submit");
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
         // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
         {
         ExecutionAttemptRecord abort_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
            {
            string release_reason = "ABORTED_NON_SUBMISSION:NotCoordinator";
            string rel_reason = "";
            if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
               {
               g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
               }
            }
         }
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
           // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
           {
           ExecutionAttemptRecord abort_rec;
           if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
              {
              string release_reason = "ABORTED_NON_SUBMISSION:AuthorityValidation";
              string rel_reason = "";
              if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
                 {
                 g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
                 }
              }
           }
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
         // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
         {
         ExecutionAttemptRecord abort_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
            {
            string release_reason = "ABORTED_NON_SUBMISSION:SubmissionBoundFailed";
            string rel_reason = "";
            if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
               {
               g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
               }
            }
         }
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
         // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
         {
         ExecutionAttemptRecord abort_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
            {
            string release_reason = "ABORTED_NON_SUBMISSION:CanSubmitFailed:" + submit_reason;
            string rel_reason = "";
            if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
               {
               g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
               }
            }
         }
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

      // P0-2: External Risk Lock check at SUBMISSION_MAY_HAVE_OCCURRED boundary (critical - final gate before broker)
      if(g_ext_risk_lock_state_valid && InpExternalRiskLockEnabled)
        {
        string rejection_code, rejection_reason;
        CAlgoPortfolioRisk::ExtRiskLockState pr_lock_state = ToPortfolioRiskLockState(g_ext_risk_lock_state);

        if(!g_portfolio_risk.CheckExternalRiskLock(pr_lock_state, rejection_code, rejection_reason))
          {
          g_logger.Event(LOG_ERROR, "EXECUTION", "EXTERNAL_RISK_LOCK_BLOCK_REVALIDATE",
                         request.symbol, "", "", request.signal_id,
                         "FAIL", "EXT_RISK_LOCK", rejection_reason);
          // Bound intent was never sent to broker; resolve as terminal non-submission.
          // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
          {
          ExecutionAttemptRecord abort_rec;
          if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
             {
             string release_reason = "ABORTED_NON_SUBMISSION:ExternalRiskLock:" + rejection_reason;
             string rel_reason = "";
             if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
                {
                g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
                }
             }
          }
          if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "External Risk Lock block at revalidation: " + rejection_reason))
             {
             g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after external risk lock block");
             string block_reason="";
             g_execution_ledger.HasBlockingUnresolved(block_reason);
             }
          runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
          return;
          }
        }

      // F-002: Final pre-submit revalidation at SUBMISSION_MAY_HAVE_OCCURRED boundary.
      // Verifies nothing changed since CanAdmit: equity, positions, pending orders, reservations.
      // F-002-P0: Exclude current attempt's own reservation to avoid double-counting.
      string reval_reason = "";
      if(!g_portfolio_risk.RevalidateAdmission(legacy_signal, risk, admission_decision, reval_reason, request.attempt_id))
         {
         g_logger.Event(LOG_ERROR, "EXECUTION", "READMISSION_FAILED", request.symbol, "", "", request.signal_id,
                        "FAIL", "READMISSION_FAILED", reval_reason);
         // Bound intent was never sent to broker; resolve as terminal non-submission.
         // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
         {
         ExecutionAttemptRecord abort_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
            {
            string release_reason = "ABORTED_NON_SUBMISSION:RevalidationFailed:" + reval_reason;
            string rel_reason = "";
            if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
               {
               g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
               }
            }
         }
         if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Revalidation failed: " + reval_reason))
            {
            g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after revalidation failure");
            string block_reason="";
            g_execution_ledger.HasBlockingUnresolved(block_reason);
            }
         runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
         return;
         }

// Final durable transition immediately before broker API. If this fails, do not call broker.
      if(!g_execution_ledger.MarkSubmissionMayHaveOccurred(request.attempt_id, "Broker invocation boundary - submission may have occurred"))
        {
         g_logger.Event(LOG_ERROR, "EXECUTION", "SUBMISSION_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "Could not durably mark submission-may-have-occurred; broker call aborted (fail closed)");
         // State is still bound non-submitted; resolve terminally without broker call.
         // F-002-R2: Release durable reservation on confirmed non-submission abort (no broker call).
         {
         ExecutionAttemptRecord abort_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
            {
            string release_reason = "ABORTED_NON_SUBMISSION:SubmissionMarkFailed";
            string rel_reason = "";
            if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
               {
               g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
               }
            }
         }
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

      // P0-2: Fresh External Risk Lock read at final broker boundary (closes intra-tick race)
      if(InpExternalRiskLockEnabled)
        {
        string fresh_rejection_code, fresh_rejection_reason;
        ExtRiskLockState fresh_lock = ReadExtRiskLockStateFresh();
        CAlgoPortfolioRisk::ExtRiskLockState pr_fresh_lock = ToPortfolioRiskLockState(fresh_lock);
        if(!g_portfolio_risk.CheckExternalRiskLock(pr_fresh_lock, fresh_rejection_code, fresh_rejection_reason))
          {
          g_logger.Event(LOG_ERROR, "EXECUTION", "EXTERNAL_RISK_LOCK_BLOCK_FINAL",
                         request.symbol, "", "", request.signal_id,
                         "FAIL", "EXT_RISK_LOCK", fresh_rejection_reason);
          // Bound intent was never sent to broker; resolve as terminal non-submission.
          {
          ExecutionAttemptRecord abort_rec;
          if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
             {
             string release_reason = "ABORTED_NON_SUBMISSION:ExternalRiskLock:" + fresh_rejection_reason;
             string rel_reason = "";
             if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
                {
                g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
                }
             }
          }
          if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "External Risk Lock block at final gate: " + fresh_rejection_reason))
            {
            g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after final gate block");
            string block_reason="";
            g_execution_ledger.HasBlockingUnresolved(block_reason);
            }
          runtime.hybrid_engine.MarkPlanConsumed(normalized_plan);
          return;
          }
}

// SAFE MODE: Block all broker mutations when active
    // Only allows Visual Tester execution; fail-closed elsewhere
    if(IsSafeModeEnforced() && !IsSafeModeActive())
      {
      g_blocked_mutation_count++;
      g_logger.Event(LOG_INFO, "SAFE_MODE", "MUTATION_BLOCKED",
                     request.symbol, "", "", request.signal_id,
                     "BLOCK", "SAFE_MODE",
                     "Safe Dashboard-Only Mode: broker mutation blocked (blocked=" + IntegerToString(g_blocked_mutation_count) + " executed=" + IntegerToString(g_executed_mutation_count) + ")");
      // Resolve attempt as ABORTED (non-submission) without broker call
      if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Safe Dashboard-Only Mode: broker mutation blocked"))
        {
        g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after Safe Mode block");
        string block_reason="";
        g_execution_ledger.HasBlockingUnresolved(block_reason);
        }
g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_SAFE_MODE_BLOCKED"; return;
      }

      bool execution_ok = g_executor.Execute(request, result);
      g_executed_mutation_count++;
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
         // R-04: Also mark reservation as requiring reconciliation
         ExecutionAttemptRecord attempt_rec_rec;
         if(g_execution_ledger.GetAttempt(request.attempt_id, attempt_rec_rec))
           {
string reserve_reason_rec = "";
            string recon_reason_rec = "RecordResult failed - reservation marked for reconciliation";
            bool reserve_recon_ok = g_execution_ledger.MarkReservationReconciliationRequired(request.attempt_id, attempt_rec_rec.risk_reserve_revision, recon_reason_rec, reserve_reason_rec);
            if(!reserve_recon_ok)
              {
              g_logger.Event(LOG_ERROR, "EXECUTION", "RESERVATION_RECONCILE_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "RESERVATION",
                             "MarkReservationReconciliationRequired failed after RecordResult failure; reservation state unknown (update failed)");
              }
           }
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
      else
          {
           // CR-01: Advance reservation lifecycle on successful execution result
           // Get the attempt record to access risk_reserve_revision for CAS
           ExecutionAttemptRecord attempt_rec;
           if(g_execution_ledger.GetAttempt(request.attempt_id, attempt_rec))
             {
              string reserve_reason = "";
              if(result.partial_fill)
                {
                 // Partial fill: ACTIVE -> PARTIALLY_COVERED (or PARTIALLY_COVERED refresh)
                 // R-01: Only advance if attempt state is PARTIAL_FILL (not RECONCILIATION_REQUIRED)
                 ENUM_EXEC_ATTEMPT_STATE attempt_state = EXEC_STATE_NONE;
                 if(g_execution_ledger.GetAttemptState(request.attempt_id, attempt_state) && attempt_state == EXEC_STATE_PARTIAL_FILL)
                   {
double executed_vol = result.executed_volume; // F3: executed_volume is the volume filled in THIS attempt (single order submission).
                     // Each attempt_id = one order submission. Remaining = requested - executed.
                     double remaining_vol = MathMax(0.0, attempt_rec.requested_volume - executed_vol);
                    // Compute remaining risk amount proportionally
                    double remaining_amount = 0.0;
                    if(attempt_rec.requested_volume > 0.0 && attempt_rec.risk_reserve_initial_amount > 0.0)
                       remaining_amount = attempt_rec.risk_reserve_initial_amount * (remaining_vol / attempt_rec.requested_volume);

                    // P3: Bounded retry on CAS revision mismatch
                    CExecutionLedger::ENUM_RESERVATION_LIFECYCLE_RESULT res = CExecutionLedger::RESERVATION_LIFECYCLE_DB_ERROR;
                    for(int retry = 0; retry < 3; retry++)
                       {
                       res = g_execution_ledger.UpdateReservationToPartiallyCovered(
                           request.attempt_id, attempt_rec.risk_reserve_revision, executed_vol, remaining_amount, remaining_vol, reserve_reason);
                       if(res != CExecutionLedger::RESERVATION_LIFECYCLE_REVISION_MISMATCH)
                          break;
                       // Re-read attempt to get current revision and retry
                       if(!g_execution_ledger.GetAttempt(request.attempt_id, attempt_rec))
                          {
                          res = CExecutionLedger::RESERVATION_LIFECYCLE_DB_ERROR;
                          break;
                          }
                       }
if(res != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
                       {
                       g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_PARTIAL_UPDATE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION",
                                       "UpdateReservationToPartiallyCovered failed: " + reserve_reason + " rev=" + IntegerToString(attempt_rec.risk_reserve_revision));
// R-04: Mark reservation as requiring reconciliation on CAS exhaustion
                        string recon_reason = "CAS exhaustion after partial fill: " + reserve_reason;
                        bool recon_ok = g_execution_ledger.MarkReservationReconciliationRequired(request.attempt_id, attempt_rec.risk_reserve_revision, recon_reason, reserve_reason);
                        if(!recon_ok)
                          {
                          g_logger.Event(LOG_ERROR, "EXECUTION", "RESERVATION_RECONCILE_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "RESERVATION",
                                         "MarkReservationReconciliationRequired failed after CAS exhaustion (partial fill); reservation state unknown (update failed)");
                          }
                       }
                    else
                       {
                       g_logger.Event(LOG_INFO, "EXECUTION", "RESERVATION_PARTIALLY_COVERED", request.symbol, "", "", request.signal_id, "INFO", "RESERVATION",
                                      "Reservation advanced to PARTIALLY_COVERED rev=" + IntegerToString(attempt_rec.risk_reserve_revision + 1));
                       }
                   }
                 else
                   {
                   // Attempt state is not PARTIAL_FILL (e.g., RECONCILIATION_REQUIRED) - do not advance reservation
                   g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_PARTIAL_SKIPPED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION",
                                  "Partial fill but attempt state is " + IntegerToString((int)attempt_state) + " - reservation not advanced");
                   }
                }
              else if(result.success)
                {
                 // R-01: Only advance to EXPOSURE_RECONCILED if attempt state is COMPLETED and not reconciliation_required
                 ENUM_EXEC_ATTEMPT_STATE attempt_state = EXEC_STATE_NONE;
                 if(g_execution_ledger.GetAttemptState(request.attempt_id, attempt_state) && attempt_state == EXEC_STATE_COMPLETED && !result.reconciliation_required)
                   {
                    // Full fill: ACTIVE/PARTIALLY_COVERED -> EXPOSURE_RECONCILED
                    CExecutionLedger::ENUM_RESERVATION_LIFECYCLE_RESULT res = CExecutionLedger::RESERVATION_LIFECYCLE_DB_ERROR;
                    for(int retry = 0; retry < 3; retry++)
                       {
                       res = g_execution_ledger.UpdateReservationToExposureReconciled(
                           request.attempt_id, attempt_rec.risk_reserve_revision, reserve_reason);
                       if(res != CExecutionLedger::RESERVATION_LIFECYCLE_REVISION_MISMATCH)
                          break;
                       // Re-read attempt to get current revision and retry
                       if(!g_execution_ledger.GetAttempt(request.attempt_id, attempt_rec))
                          {
                          res = CExecutionLedger::RESERVATION_LIFECYCLE_DB_ERROR;
                          break;
                          }
                       }
if(res != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
                        {
                        g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RECONCILE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION",
                                       "UpdateReservationToExposureReconciled failed: " + reserve_reason + " rev=" + IntegerToString(attempt_rec.risk_reserve_revision));
                        // R-04: Mark reservation as requiring reconciliation on CAS exhaustion
                        string recon_reason = "CAS exhaustion after full fill: " + reserve_reason;
                        bool recon_ok = g_execution_ledger.MarkReservationReconciliationRequired(request.attempt_id, attempt_rec.risk_reserve_revision, recon_reason, reserve_reason);
                        if(!recon_ok)
                          {
                          g_logger.Event(LOG_ERROR, "EXECUTION", "RESERVATION_RECONCILE_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "RESERVATION",
                                         "MarkReservationReconciliationRequired failed after CAS exhaustion (full fill); reservation state unknown (update failed)");
                          }
                        }
                    else
                       {
                       g_logger.Event(LOG_INFO, "EXECUTION", "RESERVATION_EXPOSURE_RECONCILED", request.symbol, "", "", request.signal_id, "INFO", "RESERVATION",
                                      "Reservation advanced to EXPOSURE_RECONCILED rev=" + IntegerToString(attempt_rec.risk_reserve_revision + 1));
                       }
                   }
else
                    {
                    // Attempt state is not COMPLETED or reconciliation_required is true - do not advance reservation
                    g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RECONCILE_SKIPPED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION",
                                   "Full fill but attempt state is " + IntegerToString((int)attempt_state) + " reconciliation_required=" + (result.reconciliation_required?"1":"0") + " - reservation not advanced");
                    // R-04: If reconciliation_required, ensure reservation is marked for reconciliation
                    if(result.reconciliation_required || attempt_state == EXEC_STATE_RECONCILIATION_REQUIRED)
                      {
                      string recon_reason = "Result has reconciliation_required or attempt state is RECONCILIATION_REQUIRED";
                      bool reserve_recon_ok = g_execution_ledger.MarkReservationReconciliationRequired(request.attempt_id, attempt_rec.risk_reserve_revision, recon_reason, reserve_reason);
                      if(!reserve_recon_ok)
                        {
                        g_logger.Event(LOG_ERROR, "EXECUTION", "RESERVATION_RECONCILE_MARK_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "RESERVATION",
                                       "MarkReservationReconciliationRequired failed for reconciliation_required path; reservation state unknown (update failed)");
                        }
                      }
                    }
                }
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
   }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessRuntime(CSymbolRuntime& runtime)
  {
   // WS-2: Handle terminal states - no processing
   if(runtime.runtime_state == RUNTIME_UNINITIALIZED ||
      runtime.runtime_state == RUNTIME_INITIALIZING ||
      runtime.runtime_state == RUNTIME_INIT_FAILED)
     {
      return;
     }

   // WS-2: Handle ERROR state - attempt recovery
   if(runtime.runtime_state == RUNTIME_ERROR)
     {
      if(AttemptRuntimeRecovery(runtime))
         {
          runtime.TransitionTo(RUNTIME_READY, REASON_ERROR_RECOVERY);
         }
      return;
     }

   // WS-2: System readiness gate
   if(!g_system_ready)
     {
      runtime.TransitionTo(RUNTIME_BLOCKED_SYSTEM, REASON_SYSTEM_NOT_READY);
      UpdateRuntimeSnapshot(runtime);
      return;
     }

   // WS-2: Session filter gate
   if(!g_session_filter.IsAllowed(TimeCurrent()))
     {
      runtime.TransitionTo(RUNTIME_BLOCKED_SESSION, REASON_SESSION_FILTER);
      UpdateRuntimeSnapshot(runtime);
      ShowRuntimeGateStatus(runtime, "BLOCKED: SESSION FILTER");
      LogRuntimeGate(runtime, "SESSION_FILTER", "SESSION", "BLOCK", "NOT_ALLOWED");
      return;
     }

   // WS-2: State machine processing
   switch(runtime.runtime_state)
     {
      case RUNTIME_READY:
      case RUNTIME_WAIT_ENTRY_BAR:
         ProcessEntryBarWait(runtime);
         break;

      case RUNTIME_FETCHING_DATA:
         ProcessDataFetch(runtime);
         break;

      case RUNTIME_CALCULATING:
         ProcessFeatureCalculation(runtime);
         break;

      case RUNTIME_WAIT_SIGNAL_BAR:
         ProcessSignalBarWait(runtime);
         break;

      case RUNTIME_EVALUATING:
         ProcessEvaluation(runtime);
         break;

      case RUNTIME_EVALUATED:
         // Cycle complete, reset for next cycle
         runtime.TransitionTo(RUNTIME_READY, REASON_EVALUATION_OK);
         break;

      case RUNTIME_BLOCKED_SESSION:
      case RUNTIME_BLOCKED_DATA:
      case RUNTIME_BLOCKED_FEATURES:
      case RUNTIME_BLOCKED_RISK:
      case RUNTIME_BLOCKED_NEWS:
      case RUNTIME_BLOCKED_AUTHORITY:
      case RUNTIME_BLOCKED_SYSTEM:
         CheckBlockedConditionResolution(runtime);
         break;
     }

   // WS-2: Update snapshot for dashboard
   UpdateRuntimeSnapshot(runtime);
  }

// WS-2: Process entry bar wait state
void ProcessEntryBarWait(CSymbolRuntime& runtime)
  {
   if(!runtime.market_entry.IsNewClosedBar(runtime.symbol, runtime.entry_tf))
     {
      runtime.TransitionTo(RUNTIME_WAIT_ENTRY_BAR, REASON_NO_ENTRY_BAR);
      ShowRuntimeGateStatus(runtime, "WAITING: ENTRY BAR");
      LogRuntimeGate(runtime, "ENTRY_BAR_WAIT", "ENTRY_BAR", "WAIT", "NO_NEW_CLOSED_BAR");
      return;
     }

   // New entry bar available - transition to data fetch
   runtime.TransitionTo(RUNTIME_FETCHING_DATA, REASON_ENTRY_BAR_READY);
   ShowRuntimeGateStatus(runtime, "FETCHING: MARKET DATA");
   LogRuntimeGate(runtime, "ENTRY_BAR_READY", "ENTRY_BAR", "READY", "NEW_CLOSED_BAR");
  }

// WS-2: Process market data fetching
void ProcessDataFetch(CSymbolRuntime& runtime)
   {
    // Per-symbol readiness check (series sync, history depth, quote)
    if(!runtime.CheckReadiness())
      {
       // CheckReadiness already logs and transitions state
       return;
      }

    // Invalidate cache at start of new data fetch cycle
    runtime.cache_valid = false;

    MarketSnapshot context_market;
    MarketSnapshot structure_market;
    MarketSnapshot setup_market;
    MarketSnapshot entry_market;
    string reason = "";

   ResetLastError();
   if(!runtime.market_context.GetSnapshot(runtime.symbol, runtime.context_tf, context_market))
     {
      int err=GetLastError();
      g_logger.Event(LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
                     runtime.symbol, EnumToString(runtime.context_tf), "", "", "FAIL", "SIGNAL_SNAPSHOT",
                     "Context snapshot failed: "+runtime.market_context.LastValidationDetail()+
                     " (result="+IntegerToString((int)runtime.market_context.LastValidationResult())+
                     ", LastError="+IntegerToString(err)+")", err);
      ResetLastError();
      runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
      ShowRuntimeGateStatus(runtime, "BLOCKED: SIGNAL DATA");
      LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "CONTEXT_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
      return;
     }

   ResetLastError();
   if(!runtime.market_structure.GetSnapshot(runtime.symbol, runtime.structure_tf, structure_market))
     {
      int err=GetLastError();
      g_logger.Event(LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
                     runtime.symbol, EnumToString(runtime.structure_tf), "", "", "FAIL", "STRUCTURE_SNAPSHOT",
                     "Structure snapshot failed: "+runtime.market_structure.LastValidationDetail()+
                     " (result="+IntegerToString((int)runtime.market_structure.LastValidationResult())+
                     ", LastError="+IntegerToString(err)+")", err);
      ResetLastError();
      runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
      ShowRuntimeGateStatus(runtime, "BLOCKED: STRUCTURE DATA");
      LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "STRUCTURE_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
      return;
     }

   ResetLastError();
   if(!runtime.market_setup.GetSnapshot(runtime.symbol, runtime.setup_tf, setup_market))
     {
      int err=GetLastError();
      g_logger.Event(LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
                     runtime.symbol, EnumToString(runtime.setup_tf), "", "", "FAIL", "SETUP_SNAPSHOT",
                     "Setup snapshot failed: "+runtime.market_setup.LastValidationDetail()+
                     " (result="+IntegerToString((int)runtime.market_setup.LastValidationResult())+
                     ", LastError="+IntegerToString(err)+")", err);
      ResetLastError();
      runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
      ShowRuntimeGateStatus(runtime, "BLOCKED: SETUP DATA");
      LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "SETUP_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
      return;
     }

   if(!runtime.market_entry.GetSnapshot(runtime.symbol, runtime.entry_tf, entry_market))
     {
      int err=GetLastError();
      g_logger.Event(LOG_ERROR, "MARKET", "MARKET_SNAPSHOT_FAILED",
                     runtime.symbol, EnumToString(runtime.entry_tf), "", "", "FAIL", "ENTRY_SNAPSHOT",
                     "Entry snapshot failed: "+runtime.market_entry.LastValidationDetail()+
                     " (result="+IntegerToString((int)runtime.market_entry.LastValidationResult())+
                     ", LastError="+IntegerToString(err)+")", err);
      ResetLastError();
      runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
      ShowRuntimeGateStatus(runtime, "BLOCKED: ENTRY DATA");
      LogRuntimeGate(runtime, "MARKET_SNAPSHOT", "ENTRY_SNAPSHOT", "FAIL", "SNAPSHOT_FAILED");
      return;
     }

// All snapshots fetched successfully - validate and store for feature calculation
    // Validate each cached snapshot against expected symbol, timeframe, validity, and freshness
    if(context_market.symbol != runtime.symbol || context_market.timeframe != runtime.context_tf || !context_market.valid ||
       structure_market.symbol != runtime.symbol || structure_market.timeframe != runtime.structure_tf || !structure_market.valid ||
       setup_market.symbol != runtime.symbol || setup_market.timeframe != runtime.setup_tf || !setup_market.valid ||
       entry_market.symbol != runtime.symbol || entry_market.timeframe != runtime.entry_tf || !entry_market.valid)
      {
       g_logger.Event(LOG_ERROR, "MARKET", "CACHE_VALIDATION_FAILED",
                      runtime.symbol, "", "", "", "FAIL", "SNAPSHOT_VALIDATION",
                      "Cached snapshot symbol/timeframe/validity mismatch");
       ResetLastError();
       runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
       ShowRuntimeGateStatus(runtime, "BLOCKED: SNAPSHOT MISMATCH");
       LogRuntimeGate(runtime, "CACHE_VALIDATION", "SNAPSHOTS", "FAIL", "SYMBOL_TF_MISMATCH");
       return;
      }

    // All four roles must be successfully fetched - partial dataset is never valid
    // Cache snapshots in runtime for reuse in feature calculation and evaluation
    runtime.cached_context_market = context_market;
    runtime.cached_structure_market = structure_market;
    runtime.cached_setup_market = setup_market;
    runtime.cached_entry_market = entry_market;
    runtime.cache_valid = true;

    runtime.TransitionTo(RUNTIME_CALCULATING, REASON_DATA_FETCH_OK);
    ShowRuntimeGateStatus(runtime, "CALCULATING: FEATURES");
    LogRuntimeGate(runtime, "DATA_FETCH_OK", "MARKET_DATA", "OK", "ALL_SNAPSHOTS");
   }

// WS-2: Process feature calculation (cache validation only - authoritative calculation at evaluation)
void ProcessFeatureCalculation(CSymbolRuntime& runtime)
   {
    // Validate cached market snapshots from ProcessDataFetch
    if(!runtime.cache_valid)
      {
       g_logger.Event(LOG_ERROR, "FEATURE", "CACHE_INVALID",
                      runtime.symbol, "", "", "", "FAIL", "SIGNAL_FEATURES",
                      "Market data cache invalid; re-fetch required");
       ResetLastError();
       runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
       ShowRuntimeGateStatus(runtime, "BLOCKED: CACHE INVALID");
       LogRuntimeGate(runtime, "FEATURE_CALC", "CACHE_CHECK", "FAIL", "CACHE_INVALID");
       return;
      }

    // Feature calculation is deferred to ProcessEvaluation where it uses
    // fresh snapshots for the new signal bar. This state validates cache
    // readiness and transitions to signal bar wait.

    runtime.TransitionTo(RUNTIME_WAIT_SIGNAL_BAR, REASON_FEATURE_CALC_OK);
    ShowRuntimeGateStatus(runtime, "WAITING FOR SIGNAL BAR");
    LogRuntimeGate(runtime, "FEATURE_CALC_OK", "CACHE_VALIDATED", "OK", "READY_FOR_SIGNAL");
   }

// WS-2: Process signal bar wait
void ProcessSignalBarWait(CSymbolRuntime& runtime)
  {
   if(!runtime.market_context.IsNewClosedBar(runtime.symbol, runtime.context_tf))
     {
      runtime.TransitionTo(RUNTIME_WAIT_SIGNAL_BAR, REASON_NO_SIGNAL_BAR);
      ShowRuntimeGateStatus(runtime, "WAITING: SIGNAL BAR");
      LogRuntimeGate(runtime, "CONTEXT_BAR_WAIT", "CONTEXT_BAR", "WAIT", "NO_NEW_CLOSED_BAR");
      return;
     }

   // Signal bar ready - transition to evaluation
   runtime.TransitionTo(RUNTIME_EVALUATING, REASON_SIGNAL_BAR_READY);
   ShowRuntimeGateStatus(runtime, "EVALUATING: HYBRID ENGINE");
   LogRuntimeGate(runtime, "SIGNAL_BAR_READY", "CONTEXT_BAR", "READY", "NEW_CLOSED_BAR");
  }

// WS-2: Process hybrid engine evaluation
void ProcessEvaluation(CSymbolRuntime& runtime)
   {
    // Re-fetch data for the new signal bar (detected in ProcessSignalBarWait)
    // The cached data from ProcessDataFetch/ProcessFeatureCalculation is for the previous bar
    MarketSnapshot context_market;
    MarketSnapshot structure_market;
    MarketSnapshot setup_market;
    MarketSnapshot entry_market;
    FeatureSet context_features;
    FeatureSet structure_features;
    FeatureSet setup_features;
    FeatureSet entry_features;

    // Fetch all data for the new signal bar
    if(!runtime.market_context.GetSnapshot(runtime.symbol, runtime.context_tf, context_market) ||
       !runtime.market_structure.GetSnapshot(runtime.symbol, runtime.structure_tf, structure_market) ||
       !runtime.market_setup.GetSnapshot(runtime.symbol, runtime.setup_tf, setup_market) ||
       !runtime.market_entry.GetSnapshot(runtime.symbol, runtime.entry_tf, entry_market))
      {
       runtime.TransitionTo(RUNTIME_BLOCKED_DATA, REASON_DATA_FETCH_FAILED);
       return;
      }

    if(!runtime.feature_context.Calculate(context_market, context_features) ||
       !runtime.feature_structure.Calculate(structure_market, structure_features) ||
       !runtime.feature_setup.Calculate(setup_market, setup_features) ||
       !runtime.feature_entry.Calculate(entry_market, entry_features))
      {
       runtime.TransitionTo(RUNTIME_BLOCKED_FEATURES, REASON_FEATURE_CALC_FAILED);
       return;
      }

    // Portfolio state check (SP-01: signal calc proceeds regardless; risk admission at boundary)
    PortfolioState portfolio_state;
    bool portfolio_available = g_state.GetPortfolioState(portfolio_state);
    if(!portfolio_available)
      {
       g_logger.Event(LOG_WARNING, "RISK", "RISK_STATE_UNAVAILABLE",
                      runtime.symbol, "", "", "", "INFO", "RISK_STATE",
                      "Portfolio state unavailable; signal still calculated, execution blocked");
      }

    if(portfolio_available)
      LogRiskLockTransition(portfolio_state);

    // Authority check (coordinator only) - moved to signal-to-execution boundary
    // (signal calculation proceeds; authority enforced before durable intent)
   runtime.TransitionTo(RUNTIME_EVALUATING, REASON_EVALUATION_START);

   bool ok = false;
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
      g_logger.Event(LOG_WARNING, "HYBRID", "CONTEXT_BUILD_FAILED",
                     runtime.symbol, "", "", "", "WARN", "CONTEXT_INVALID", ctx.reason);
      runtime.TransitionTo(RUNTIME_BLOCKED_FEATURES, REASON_EVALUATION_FAILED);
      ShowRuntimeGateStatus(runtime, "BLOCKED: CONTEXT INVALID");
      LogRuntimeGate(runtime, "CONTEXT_BUILD", "FEATURE_CONTEXT", "BLOCK", ctx.reason);
      return;
     }

HybridDecision decision = runtime.hybrid_engine.Evaluate(
                                runtime.symbol, ctx, context_market, ok);

    // SP-01: Handle Evaluate failure explicitly
    if(!ok)
      {
       g_logger.Event(LOG_WARNING, "HYBRID", "EVALUATE_FAILED",
                      runtime.symbol, "", "", "", "WARN", "EVALUATE_FAIL",
                       "HybridEngine.Evaluate returned false; reason=" + decision.main_reason);
       runtime.TransitionTo(RUNTIME_BLOCKED_FEATURES, REASON_EVALUATION_FAILED);
       ShowRuntimeGateStatus(runtime, "BLOCKED: EVALUATE FAILED");
        LogRuntimeGate(runtime, "HYBRID_EVAL", "EVALUATE", "FAIL", decision.main_reason);
       return;
      }

    // SP-01: Handle invalid decision explicitly
    if(!decision.valid)
      {
       g_logger.Event(LOG_INFO, "HYBRID", "DECISION_INVALID",
                      runtime.symbol, "", "", "", "INFO", "NO_VALID_DECISION",
                      "Hybrid decision invalid: " + decision.main_reason);
      }

    // Populate runtime snapshot with decision data for dashboard
    if(decision.valid)
      {
       runtime.snapshot.regime_code = (int)decision.regime;
       runtime.snapshot.bias_code = (int)decision.bias;
       runtime.snapshot.long_code = (decision.long_score > 0.0 ? 1 : 0);
       runtime.snapshot.short_code = (decision.short_score > 0.0 ? 1 : 0);
       runtime.snapshot.regime_state = SNAP_VALID;
       runtime.snapshot.bias_state = SNAP_VALID;
       runtime.snapshot.long_state = (decision.long_score > 0.0 ? SNAP_VALID : SNAP_NO_SIGNAL);
       runtime.snapshot.short_state = (decision.short_score > 0.0 ? SNAP_VALID : SNAP_NO_SIGNAL);
      }
    else
      {
       // No valid decision - mark as no signal
       runtime.snapshot.regime_code = (int)decision.regime;
       runtime.snapshot.bias_code = (int)decision.bias;
       runtime.snapshot.long_code = 0;
       runtime.snapshot.short_code = 0;
       runtime.snapshot.regime_state = SNAP_NO_SIGNAL;
       runtime.snapshot.bias_state = SNAP_NO_SIGNAL;
       runtime.snapshot.long_state = SNAP_NO_SIGNAL;
       runtime.snapshot.short_state = SNAP_NO_SIGNAL;
      }

    ProcessHybridDecision(runtime, decision, portfolio_state, portfolio_available);

    if(decision.valid)
      {
       runtime.TransitionTo(RUNTIME_EVALUATED, REASON_EVALUATION_OK);
      }
    else
      {
       // Check if blocked by news (engine's internal evaluation is single source of truth)
       if(decision.status == DECISION_NEWS_BLOCKED)
         {
          runtime.TransitionTo(RUNTIME_BLOCKED_NEWS, REASON_NEWS_BLOCK);
         }
       else
         {
          // No signal - cycle complete, return to READY
          runtime.TransitionTo(RUNTIME_READY, REASON_EVALUATION_NO_SIGNAL);
         }
      }
   }

// WS-2: Check if blocked condition has resolved
void CheckBlockedConditionResolution(CSymbolRuntime& runtime)
  {
   PortfolioState portfolio_state;
   g_state.GetPortfolioState(portfolio_state); // Best effort - use cached if available

   // System readiness
   if(runtime.runtime_state == RUNTIME_BLOCKED_SYSTEM && g_system_ready)
     {
      runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
      return;
     }

   // Session filter
   if(runtime.runtime_state == RUNTIME_BLOCKED_SESSION && g_session_filter.IsAllowed(TimeCurrent()))
     {
      runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
      return;
     }

   // Data availability - try to fetch
   if(runtime.runtime_state == RUNTIME_BLOCKED_DATA)
     {
      MarketSnapshot test_snapshot;
      if(runtime.market_context.GetSnapshot(runtime.symbol, runtime.context_tf, test_snapshot))
        {
         runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
         return;
        }
      }

   // Features - try to calculate
   if(runtime.runtime_state == RUNTIME_BLOCKED_FEATURES)
     {
      MarketSnapshot test_snapshot;
      FeatureSet test_features;
      if(runtime.market_context.GetSnapshot(runtime.symbol, runtime.context_tf, test_snapshot) &&
         runtime.feature_context.Calculate(test_snapshot, test_features))
        {
         runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
         return;
        }
      }

   // Risk lock
   if(runtime.runtime_state == RUNTIME_BLOCKED_RISK)
     {
      if(!portfolio_state.trading_locked)
        {
         runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
         return;
        }
      }

   // News filter
   if(runtime.runtime_state == RUNTIME_BLOCKED_NEWS)
     {
      if(!IsNewsBlockActive(runtime, portfolio_state))
        {
         runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
         return;
        }
      }

   // Authority
   if(runtime.runtime_state == RUNTIME_BLOCKED_AUTHORITY)
     {
      string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
      if(g_execution_ledger.ValidateAuthority(authority_key, g_owner_instance_token, g_authority_epoch))
        {
         runtime.TransitionTo(RUNTIME_READY, REASON_CONDITION_RESOLVED);
         return;
        }
      }
   }

// WS-2: Attempt recovery from ERROR state
bool AttemptRuntimeRecovery(CSymbolRuntime& runtime)
  {
   if(runtime.retry_count >= 3)
     {
      g_logger.Event(LOG_ERROR, "RUNTIME", "MAX_RETRIES_EXCEEDED",
                     runtime.symbol, "", "", "",
                     "FAIL", "RUNTIME_RECOVERY",
                     "Max retries exceeded for runtime " + runtime.symbol);
      runtime.TransitionTo(RUNTIME_INIT_FAILED, REASON_MAX_RETRIES_EXCEEDED);
      return false;
     }

   runtime.retry_count++;

   // Try to re-validate basic requirements
   MarketSnapshot test_snapshot;
   if(!runtime.market_context.GetSnapshot(runtime.symbol, runtime.context_tf, test_snapshot))
     {
      return false; // Will retry on next call
     }

   FeatureSet test_features;
   if(!runtime.feature_context.Calculate(test_snapshot, test_features))
     {
      return false;
     }

   PortfolioState portfolio_state;
   if(!g_state.GetPortfolioState(portfolio_state) || portfolio_state.trading_locked)
     {
      return false;
     }

   return true;
  }

// WS-2: Update runtime snapshot for dashboard
void UpdateRuntimeSnapshot(CSymbolRuntime& runtime)
  {
   runtime.snapshot_generation++;
   runtime.snapshot.generation = runtime.snapshot_generation;
   runtime.snapshot.snapshot_time = TimeCurrent();
   runtime.snapshot.configured_style = runtime.style;

   switch(runtime.runtime_state)
     {
      case RUNTIME_WAIT_ENTRY_BAR:
         runtime.snapshot.current_stage_code = 1; // WAITING_FOR_NEW_ENTRY_BAR
         runtime.snapshot.last_block_reason_code = 1; // NO_NEW_CLOSED_BAR
         break;
      case RUNTIME_WAIT_SIGNAL_BAR:
         runtime.snapshot.current_stage_code = 2; // WAITING_FOR_SIGNAL_BAR
         runtime.snapshot.last_block_reason_code = 1; // NO_NEW_CLOSED_BAR
         break;
      case RUNTIME_EVALUATED:
         runtime.snapshot.current_stage_code = 3; // EVALUATED
         runtime.snapshot.last_block_reason_code = 0; // NONE
         runtime.snapshot.last_success_time = TimeCurrent();
         break;
      case RUNTIME_BLOCKED_SESSION:
      case RUNTIME_BLOCKED_DATA:
      case RUNTIME_BLOCKED_FEATURES:
      case RUNTIME_BLOCKED_RISK:
      case RUNTIME_BLOCKED_NEWS:
      case RUNTIME_BLOCKED_AUTHORITY:
      case RUNTIME_BLOCKED_SYSTEM:
         runtime.snapshot.current_stage_code = 4; // BLOCKED
         // Map specific block reason
         runtime.snapshot.last_block_reason_code = MapBlockReasonToCode(runtime.runtime_state);
         break;
      case RUNTIME_ERROR:
         runtime.snapshot.current_stage_code = 4; // BLOCKED
         runtime.snapshot.last_block_reason_code = 99; // ERROR
         break;
      case RUNTIME_INIT_FAILED:
         runtime.snapshot.current_stage_code = 4; // BLOCKED
         runtime.snapshot.last_block_reason_code = 98; // INIT_FAILED
         break;
      default:
         runtime.snapshot.current_stage_code = 0; // NOT_EVALUATED
         runtime.snapshot.last_block_reason_code = 0; // NONE
     }

   // F11: Share snapshot via Global Variables for multi-chart Dashboard
   bool gv_write_ok = WriteSnapshotToGV(
      runtime.symbol,
      runtime.snapshot.generation,
      runtime.snapshot.snapshot_time,
      runtime.snapshot.last_success_time,
      runtime.snapshot.current_stage_code,
      runtime.snapshot.last_block_reason_code,
      (int)runtime.snapshot.configured_style,
      runtime.snapshot.regime_code,
      runtime.snapshot.bias_code,
      runtime.snapshot.long_code,
      runtime.snapshot.short_code,
      (int)runtime.snapshot.regime_state,
      (int)runtime.snapshot.bias_state,
      (int)runtime.snapshot.long_state,
      (int)runtime.snapshot.short_state
   );
   if(!gv_write_ok)
     {
      g_logger.Event(LOG_WARNING, "DASHBOARD", "GV_WRITE_FAILED",
                     runtime.symbol, "", "", "",
                     "WARN", "SNAPSHOT_PUBLISH",
                     "Failed to write runtime snapshot to Global Variables");
     }
  }

// WS-2: Map block state to reason code for snapshot
int MapBlockReasonToCode(ENUM_RUNTIME_STATE state)
  {
   switch(state)
     {
      case RUNTIME_BLOCKED_SESSION:   return 10; // SESSION_FILTER
      case RUNTIME_BLOCKED_DATA:      return 11; // MARKET_DATA
      case RUNTIME_BLOCKED_FEATURES:  return 12; // FEATURES
      case RUNTIME_BLOCKED_RISK:      return 13; // RISK_LOCK
      case RUNTIME_BLOCKED_NEWS:      return 14; // NEWS_FILTER
      case RUNTIME_BLOCKED_AUTHORITY: return 15; // AUTHORITY
      case RUNTIME_BLOCKED_SYSTEM:    return 16; // SYSTEM_NOT_READY
      default:                        return 99; // UNKNOWN
     }
  }

// WS-2: Check if news block is active for symbol (uses runtime's news service)
  bool IsNewsBlockActive(CSymbolRuntime& runtime, const PortfolioState& portfolio_state)
    {
     // Fail-closed: if news is enabled, we MUST evaluate; only skip if explicitly disabled
     if(!InpNewsEnabled)
        return false; // Feature explicitly disabled - no block

     // When news is enabled but prevent entries is false, we still evaluate
     // but the service will return false for ShouldBlockEntry (config choice)
     // Do NOT short-circuit on InpNewsPreventNewEntries - that defeats fail-closed

     // Use the runtime's hybrid engine news service
     NewsFeatures news = runtime.hybrid_engine.EvaluateNews(runtime.symbol, TimeTradeServer(), portfolio_state);

     // Check if entry should be blocked based on news (service handles fail-closed for UNAVAILABLE)
     return runtime.hybrid_engine.ShouldBlockEntry(news, runtime.symbol);
    }

//==================================================================
// Shared bounded retry for pending runtime initialization (idempotent)
//==================================================================
datetime g_last_runtime_init_retry = 0;
const int RUNTIME_INIT_RETRY_SECONDS = 30;

void TryInitializePendingRuntimesBounded(const string source)
  {
   datetime now = TimeCurrent();
   if(g_last_runtime_init_retry != 0 && (now - g_last_runtime_init_retry) < RUNTIME_INIT_RETRY_SECONDS)
      return;
   g_last_runtime_init_retry = now;
   int initialized = InitializePendingRuntimes();
   if(initialized > 0)
     {
      g_logger.Event(LOG_INFO,"INIT","RUNTIME_INIT_RETRY", "", "", source, "", "OK", "PENDING_RUNTIMES",
                     "Initialized pending runtimes count=" + IntegerToString(initialized));
     }
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
   DiscoverTradableSymbols(symbols);

   string roles[];
   ArrayResize(roles,ArraySize(symbols));
   for(int r=0;r<ArraySize(roles);r++) roles[r]="SYM";

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
   for(int i=0;i<g_runtime.Total();i++)
     {
      CSymbolRuntime *runtime = g_runtime.At(i);
      if(runtime && runtime.valid) runtime_count++;
     }

   for(int i=0;i<ArraySize(symbols);i++)
     {
      if(StringLen(symbols[i])==0)
         continue;

      if(tester_single_symbol &&
         symbols[i]!=_Symbol)
        {
         // In tester single-symbol mode, skip symbols not on the chart
         continue;
        }

      bool custom_symbol=false;
      if(!SymbolExist(symbols[i], custom_symbol))
        {
         g_logger.Event(
            LOG_WARNING, "INIT", "INIT_SYMBOL_UNAVAILABLE",
            symbols[i], "", roles[i], "",
            "SKIP", "SYMBOL_MISSING",
            "Configured symbol is unavailable; other symbols remain active");
         continue;
        }

      ResetLastError();
      if(!SymbolSelect(symbols[i], true))
        {
         int select_error=GetLastError();
         g_logger.Event(
            LOG_WARNING, "INIT", "INIT_SYMBOL_UNAVAILABLE",
            symbols[i], "", roles[i], "",
            "WAIT", "SYMBOL_SELECT",
            "Unable to select configured symbol; other symbols remain active",
            select_error);
         ResetLastError();
         continue;
        }

      // Find existing runtime for this symbol
      CSymbolRuntime *runtime = NULL;
      for(int j=0;j<g_runtime.Total();j++)
        {
         CSymbolRuntime *r = g_runtime.At(j);
         if(r && r.valid && r.symbol == symbols[i])
           {
            runtime = r;
            break;
           }
        }

      if(runtime)
        {
         runtime_count++;
         continue;
        }

      // Asset-agnostic runtime setup: rely on MarketData/indicator initialization and sync checks.
      // No forex/asset-family assumptions here; unsupported or unsynchronized symbols remain pending.

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

         g_logger.Event(
            LOG_INFO, "INIT", "INIT_SYMBOL_WAITING",
            symbols[i], "", roles[i], "",
            "WAIT", "SYMBOL_SYNC",
            "Waiting for this symbol only: "+wait_state);
         continue;
        }

      // Create new runtime for this symbol
      CSymbolRuntime *new_runtime = new CSymbolRuntime();
      if(new_runtime == NULL)
        {
         g_logger.Event(
            LOG_ERROR, "INIT", "INIT_RUNTIME_ALLOC_FAILED",
            symbols[i], "", roles[i], "",
            "FAIL", "MEMORY", "Failed to allocate CSymbolRuntime");
         continue;
        }

      int rt_ctx=0, rt_struct=0, rt_setup=0, rt_entry=0;
      bool rt_override=false;
      if(!ResolveFreshnessForSymbol(symbols[i], rt_ctx, rt_struct, rt_setup, rt_entry, rt_override))
        {
         g_logger.Event(
            LOG_WARNING, "INIT", "INIT_FRESHNESS_INVALID",
            symbols[i], "", roles[i], "",
            "FAIL", "FRESHNESS_CONFIG",
            "Invalid freshness override; new entries blocked");
         delete new_runtime;
         continue;
        }

      if(!new_runtime.Initialize(
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
         string failure=new_runtime.last_failure;
         g_logger.Event(
            LOG_WARNING, "INIT", "INIT_RUNTIME_PENDING",
            symbols[i], "", roles[i], "",
            "WAIT", "RUNTIME_INIT",
            "Runtime initialization failed; other symbols remain active: "+
            failure,
            GetLastError());
         ResetLastError();
         delete new_runtime;
         continue;
        }

      new_runtime.hybrid_engine.SetStrategyGroupKey(g_strategy_group_key);
      g_runtime.Add(new_runtime);
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
      InpMaxPositionsPerStrategy);

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

    // F-005.2.2: Wire execution ledger to consumers for ownership resolution
    string account_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
    g_position_manager.SetExecutionLedger(GetPointer(g_execution_ledger), account_key);
    g_portfolio_risk.SetExecutionLedger(GetPointer(g_execution_ledger), account_key);
    g_state.SetExecutionLedger(GetPointer(g_execution_ledger), account_key);

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
       // CR-02: Expire stale authority lease before election (configurable lease)
       string expire_reason = "";
       // R-03: Pass owner_token to prevent self-expiry during init (consistent with OnTimer)
       g_execution_ledger.ExpireStaleAuthority(authority_key, InpAuthorityLeaseSeconds, expire_reason, g_owner_instance_token);
       if(expire_reason != "")
         {
         if(expire_reason == "LEDGER_UNAVAILABLE")
           {
           g_logger.Event(LOG_WARNING, "INIT", "AUTHORITY_EXPIRE_SKIPPED", _Symbol, "", "", "", "WARNING", "AUTHORITY", "Authority lease expiry skipped: " + expire_reason);
           }
         else
           {
           g_logger.Event(LOG_INFO, "INIT", "AUTHORITY_EXPIRED", _Symbol, "", "", "", "INFO", "AUTHORITY", "Authority lease expired during election: " + expire_reason);
           }
         }
       int astate = g_execution_ledger.GetAuthorityState(authority_key);
       // CR-02 / Architecture Decision: No Automatic Takeover
       // ORPHANED is a BLOCKING state. Do NOT auto-reacquire on init/election.
       // Recovery requires explicit operator/orchestrator action (separate path, auditable, fenced).
       if(astate == (int)GATEWAY_AUTHORITY_ORPHANED)
         {
         g_coordinator_mode = COORD_MODE_UNAVAILABLE;
         g_coordinator_unavailable_reason = "AUTHORITY_ORPHANED";
         g_executor.SyncAuthority(g_authority_epoch, false);
         g_logger.Event(LOG_WARNING, "INIT", "COORDINATOR_UNAVAILABLE", _Symbol, "", "", "", "FAIL", "AUTHORITY", "Authority is ORPHANED (expired lease) - blocking state, no automatic re-acquisition. Explicit recovery required.");
         }
       else
         {
          // Unclaimed/released/missing row: let ledger provision+acquire atomically (fail-closed on contention).
          // If another instance currently owns CLAIMED authority, acquisition fails and this becomes CHART_CONTEXT.
          long epoch = 0;
           if(g_execution_ledger.AcquireAuthority(authority_key, g_owner_instance_token, epoch))
             {
              g_coordinator_mode = COORD_MODE_COORDINATOR;
              g_authority_epoch = epoch;
              g_coordinator_unavailable_reason = "";
              g_executor.SyncAuthority(g_authority_epoch, true);
              runtime_count = InitializePendingRuntimes();
             }
           else
             {
              int astate_after = g_execution_ledger.GetAuthorityState(authority_key);
              if(astate_after == (int)GATEWAY_AUTHORITY_ORPHANED)
                {
                 g_coordinator_mode = COORD_MODE_UNAVAILABLE;
                 g_coordinator_unavailable_reason = "AUTHORITY_ORPHANED";
                 g_executor.SyncAuthority(g_authority_epoch, false);
                 g_logger.Event(LOG_WARNING, "INIT", "COORDINATOR_UNAVAILABLE", _Symbol, "", "", "", "FAIL", "AUTHORITY", "Authority became ORPHANED; explicit recovery required.");
                }
              else if(astate_after == -1)
                {
                 g_coordinator_mode = COORD_MODE_UNAVAILABLE;
                 g_coordinator_unavailable_reason = "AUTHORITY_UNAVAILABLE";
                 g_executor.SyncAuthority(g_authority_epoch, false);
                 g_logger.Event(LOG_WARNING, "INIT", "COORDINATOR_UNAVAILABLE", _Symbol, "", "", "", "FAIL", "AUTHORITY", "Authority provisioning/acquisition failed (no authority state)");
                }
              else
                {
                 g_coordinator_mode = COORD_MODE_CHART_CONTEXT;
                 g_coordinator_unavailable_reason = "";
                 g_executor.SyncAuthority(g_authority_epoch, false);
                 g_logger.Event(LOG_INFO, "INIT", "CHART_CONTEXT_ONLY", _Symbol, "", "", "", "INFO", "AUTHORITY", "Another coordinator owns authority");
                }
             }
         }
      }
   else
      {
       // Ledger unavailable: fail-closed, no coordinator
       g_coordinator_mode = COORD_MODE_UNAVAILABLE;
       g_coordinator_unavailable_reason = "LEDGER_UNAVAILABLE";
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

   // Mark EA initialization as complete for dashboard state synchronization
   g_dashboard.SetEAInitialized();

   g_logger.Event(
      LOG_INFO, "SYSTEM", "SYSTEM_READY",
      _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), "", "",
      "READY", "INIT_COMPLETE",
"AlgoMultiAssetEA Hybrid version="+
       ALGO_SYSTEM_VERSION+
       " style="+StyleName(InpTradingStyle)+
       " mode="+IntegerToString((int)InpMode)+
       " runtimes_ready="+IntegerToString(runtime_count));

    UpdateDashboardForChart();
    return SYSTEM_INIT_READY;
   }

//==================================================================
// OnInit
//==================================================================
//+------------------------------------------------------------------+
//| E2.1: Deterministic Config Fingerprint (v2)                      |
//+------------------------------------------------------------------+
string ComputeConfigFingerprint()
  {
   // Canonical serialization of trading-relevant settings.
   // Presentation-only settings (Dashboard, ViewMode, diagnostics) excluded.
   // Version CFGV2: includes risk params, position management, timeframe roles, freshness, universe, news, session, spread, hybrid thresholds, volume profile, liquidity, divergence, regime
   string s = "CFGV2|";
   s += "STYLE=" + IntegerToString((int)InpTradingStyle) + "|";
   s += "MODE=" + IntegerToString((int)InpMode) + "|";
   s += "LIVECONFIRM=" + (InpLiveAutoConfirm ? "1" : "0") + "|";
   s += "GROUP=" + InpStrategyGroupKey + "|";

   // Fix 3: Include timeframe roles (resolved from style)
   ENUM_TIMEFRAMES ctx_tf, struct_tf, setup_tf, entry_tf;
   SelectStyleTimeframes(InpTradingStyle, ctx_tf, struct_tf, setup_tf, entry_tf);
   s += "CTX_TF=" + IntegerToString((int)ctx_tf) + "|";
   s += "STRUCT_TF=" + IntegerToString((int)struct_tf) + "|";
   s += "SETUP_TF=" + IntegerToString((int)setup_tf) + "|";
   s += "ENTRY_TF=" + IntegerToString((int)entry_tf) + "|";

   // Fix 3: Include risk parameters (group 09)
   s += "RISK_PCT=" + DoubleToString(InpRiskPercent, 2) + "|";
   s += "DAILY_LOSS_LIM=" + DoubleToString(InpDailyLossLimit, 2) + "|";
   s += "MONTHLY_LOSS_LIM=" + DoubleToString(InpMonthlyLossLimit, 2) + "|";
   s += "MAX_CONSEC_LOSSES=" + IntegerToString(InpMaxConsecutiveLosses) + "|";
   s += "MAX_POS_TOTAL=" + IntegerToString(InpMaxPositionsTotal) + "|";
   s += "MAX_POS_PER_SYM=" + IntegerToString(InpMaxPositionsPerSymbol) + "|";
   s += "MAX_POS_PER_STRAT=" + IntegerToString(InpMaxPositionsPerStrategy) + "|";
   s += "MAX_PORTF_RISK=" + DoubleToString(InpMaxPortfolioRisk, 2) + "|";
   s += "MARGIN_SAFETY=" + DoubleToString(InpMarginSafetyFraction, 2) + "|";
   s += "DEVIATION=" + IntegerToString(InpDeviationPoints) + "|";

   // P2-1: Include missing position management params (group 12)
   s += "BE_ENABLED=" + (InpBreakEven ? "1" : "0") + "|";
   s += "BE_TRIGGER_R=" + DoubleToString(InpBreakEvenTriggerR, 2) + "|";
   s += "BE_OFFSET_PTS=" + DoubleToString(InpBreakEvenOffsetPoints, 1) + "|";
   s += "TRAIL_ENABLED=" + (InpTrailing ? "1" : "0") + "|";
   s += "TRAIL_TF=" + IntegerToString((int)InpTrailingTF) + "|";
   s += "TRAIL_ATR_PERIOD=" + IntegerToString(InpTrailingATRPeriod) + "|";
   s += "TRAIL_ATR_MULT=" + DoubleToString(InpTrailingATRMultiplier, 2) + "|";
   s += "TIME_EXIT_ENABLED=" + (InpTimeExit ? "1" : "0") + "|";
   s += "MAX_HOLD_MIN=" + IntegerToString(InpMaxHoldingMinutes) + "|";

   // Fix 3: Include hybrid decision thresholds (group 03)
   s += "MIN_RR=" + DoubleToString(InpMinRR, 2) + "|";
   s += "MIN_SCORE=" + DoubleToString(InpMinScore, 1) + "|";
   s += "CONFLICT_THRESH=" + DoubleToString(InpConflictThreshold, 1) + "|";
   s += "ENTRY_TOL_SCALP=" + DoubleToString(InpEntryToleranceScalp, 1) + "|";
   s += "ENTRY_TOL_DAY=" + DoubleToString(InpEntryToleranceDay, 1) + "|";
   s += "ENTRY_TOL_SWING=" + DoubleToString(InpEntryToleranceSwing, 1) + "|";
   s += "ALLOW_MEAN_REV=" + (InpAllowMeanReversion ? "1" : "0") + "|";

   // Fix 3: Include volume profile params (group 04)
   s += "PROF_ENABLED=" + (InpProfileEnabled ? "1" : "0") + "|";
   s += "PROF_SESS_BARS=" + IntegerToString(InpProfileSessionBars) + "|";
   s += "PROF_ROLL_BARS=" + IntegerToString(InpProfileRollingBars) + "|";
   s += "PROF_VA_PCT=" + DoubleToString(InpValueAreaPercent, 2) + "|";

   // Fix 3: Include liquidity/structure params (group 05)
   s += "SWING_LOOKBACK=" + IntegerToString(InpSwingLookback) + "|";
   s += "EQUAL_TOL_PTS=" + IntegerToString(InpEqualTolerancePoints) + "|";
   s += "MAX_LVL_AGE=" + IntegerToString(InpMaxLevelAgeBars) + "|";
   s += "SWEEP_CONF_BARS=" + IntegerToString(InpSweepConfirmBars) + "|";

// Fix 3: Include divergence/momentum params (group 06)
    s += "RSI_PERIOD=" + IntegerToString(InpRSIPeriod) + "|";
    s += "PIVOT_TOL_PCT=" + DoubleToString(InpPivotTolerancePercent, 3) + "|";
    s += "MAX_DIV_AGE=" + IntegerToString(InpMaxDivergenceAgeBars) + "|";
    s += "MOM_LOOKBACK=" + IntegerToString(InpMomentumLookback) + "|";

   // Fix 3: Include regime params (group 07)
   s += "ADX_PERIOD=" + IntegerToString(InpADXPeriod) + "|";
   s += "ADX_TREND_THRESH=" + IntegerToString(InpADXTrendThreshold) + "|";
   s += "HIGH_VOL_RATIO=" + DoubleToString(InpHighVolatilityRatio, 2) + "|";
   s += "LOW_VOL_RATIO=" + DoubleToString(InpLowVolatilityRatio, 2) + "|";
   s += "RANGE_LOOKBACK=" + IntegerToString(InpRangeLookback) + "|";
   s += "HYST_BARS=" + IntegerToString(InpHysteresisBars) + "|";

   // Fix 3: Include news filter params (group 08)
   s += "NEWS_ENABLED=" + (InpNewsEnabled ? "1" : "0") + "|";
   s += "NEWS_PREVENT=" + (InpNewsPreventNewEntries ? "1" : "0") + "|";
   s += "NEWS_BEFORE=" + IntegerToString(InpNewsBlackoutMinutesBefore) + "|";
   s += "NEWS_AFTER=" + IntegerToString(InpNewsBlackoutMinutesAfter) + "|";
   s += "NEWS_COOLDOWN=" + IntegerToString(InpNewsCooldownMinutes) + "|";
   s += "NEWS_IMPACT=" + IntegerToString(InpNewsImpactThreshold) + "|";
   // P2-1: Include missing news close positions param
   s += "NEWS_CLOSE_POS=" + (InpNewsClosePositions ? "1" : "0") + "|";

   // Fix 3: Include session/spread filters (group 10)
   s += "SESS_ENABLED=" + (InpSessionFilter ? "1" : "0") + "|";
   s += "SESS_START=" + IntegerToString(InpSessionStartHour) + "|";
   s += "SESS_END=" + IntegerToString(InpSessionEndHour) + "|";
   s += "SPREAD_FILTER=" + (InpUseSpreadFilter ? "1" : "0") + "|";
   s += "MAX_SPREAD=" + IntegerToString(InpMaxSpreadPoints) + "|";

   // Fix 3: Include freshness params (group 13)
   s += "FRESH_CTX=" + IntegerToString(InpFreshnessContextSeconds) + "|";
   s += "FRESH_STRUCT=" + IntegerToString(InpFreshnessStructureSeconds) + "|";
   s += "FRESH_SETUP=" + IntegerToString(InpFreshnessSetupSeconds) + "|";
   s += "FRESH_ENTRY=" + IntegerToString(InpFreshnessEntrySeconds) + "|";
   // P2-1: Include freshness overrides
   s += "FRESH_OVERRIDES=" + InpFreshnessOverrides + "|";

   // Symbol universe: automatic broker-discovered discovery (no user toggle in fingerprint).

   // Magic for style
   s += "MAGIC=" + IntegerToString((int)MagicForStyle(InpTradingStyle)) + "|";

   // Simple deterministic hash (not cryptographic)
   uint h = 5381;
   for(int i = 0; i < StringLen(s); i++)
     {
      h = ((h << 5) + h) + (uint)StringGetCharacter(s, i);
     }
   return "FP_" + IntegerToString((long)h, 16);
  }

// Convert external Dashboard ViewMode enum to internal m_view_mode
// External: DASHBOARD_COMPACT=0, DASHBOARD_NORMAL=1, DASHBOARD_FULL=2
// Internal: 0=FULL, 1=NORMAL, 2=COMPACT
int DashboardViewModeToInternal(const ENUM_DASHBOARD_VIEW_MODE mode)
  {
   switch(mode)
     {
      case DASHBOARD_COMPACT:  return 2;
      case DASHBOARD_NORMAL:   return 1;
      case DASHBOARD_FULL:     return 0;
      default:
       // Invalid enum value - log error and default to FULL (0) with explicit diagnostic
       g_logger.Event(LOG_ERROR, "INIT", "INVALID_DASHBOARD_VIEW_MODE",
          _Symbol, "", "", "", "ERROR", "CONFIG",
          "Invalid InpDashboardViewMode value: " + IntegerToString((int)mode) + ", defaulting to FULL");
       return 0;
     }
  }

int OnInit()
  {
   g_logger.StartRun();
   // F3: Set unique instance identifier for multi-chart log separation
   g_logger.SetInstanceId(IntegerToString((long)ChartID()));
   // E2.4: Generate unique OwnerInstanceToken.
    // F3: MathSrand is mandatory (MQL5 MathRand is deterministic across runs without it);
    // combine independently grounded instance data (login, chart id, tick count) with the RNG.
    MathSrand((int)GetTickCount());
    g_owner_instance_token = "OI_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
                             IntegerToString((long)ChartID()) + "_" +
                             IntegerToString((long)GetTickCount()) + "_" + IntegerToString(MathRand());
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

 g_dashboard.Enable(InpDashboard);
    g_dashboard.SetTitle("ALGO HYBRID");
    // Apply dashboard config early so it persists even if initialization later fails
    int effective_view_mode = DashboardViewModeToInternal(InpDashboardViewMode);
    g_dashboard.SetViewMode(effective_view_mode);
    g_dashboard.ShowDiagnostics(InpDashboardDiagnostics);
    g_dashboard.SetSafeMode(InpDashboardSafeMode);
    g_logger.Event(LOG_INFO, "INIT", "DASHBOARD_CONFIG",
       _Symbol, "", "", "", "INFO", "CONFIG",
       "enabled=" + (InpDashboard?"true":"false") +
       " view_mode=" + IntegerToString(effective_view_mode) +
       " diagnostics=" + (InpDashboardDiagnostics?"true":"false") +
       " safe_mode=" + (InpDashboardSafeMode?"true":"false"));
    g_ea_start_time = TimeCurrent();

// Initialize Metrics Exporter (WP-07)
    g_metrics_exporter.Initialize(&g_logger, IntegerToString((long)ChartID()), 10);

    // Initialize Alert Manager (WP-07)
    g_alert_manager.Initialize(&g_logger, &g_metrics_exporter);
    g_alert_manager.SetThresholds(
       150.0, 200.0,    // Margin level: critical 150%, warning 200%
       5.0, 3.0,        // Daily loss: critical 5%, warning 3%
       10.0, 5.0,       // Drawdown: critical 10%, warning 5%
       3.0,             // Spread warning multiplier: 3x normal
       8, 10,           // Positions: warning at 8, critical at 10
       60               // Alert cooldown: 60 seconds
    );

    // Initialize Dashboard Diagnostics
    // Enable in Strategy Tester Visual mode or when explicitly configured
    bool is_tester_visual = (MQLInfoInteger(MQL_TESTER) != 0 && MQLInfoInteger(MQL_VISUAL_MODE) != 0);
    g_dashboard_diag_enabled = InpDashboard && (is_tester_visual || InpDashboardDiagnostics);
    if(g_dashboard_diag_enabled)
      {
       if(g_dashboard_diag.Initialize(&g_logger, DIAG_MODE_FULL))
         {
          // Set run info - use local struct (MQL5 requires pass-by-reference for structs)
          DiagRunInfo run_info;
          run_info.run_id = g_dashboard_diag.GenerateRunId(); // Will be overwritten by Initialize
          run_info.source_sha256 = ""; // TODO: compute from source
          run_info.ex5_sha256 = "";    // TODO: compute from EX5
          run_info.terminal_build = (int)TerminalInfoInteger(TERMINAL_BUILD);
          run_info.ea_version = "1.002";
          run_info.runtime_mode = MQLInfoInteger(MQL_TESTER) ? (MQLInfoInteger(MQL_VISUAL_MODE) ? 2 : 1) : 0;
          run_info.chart_id = ChartID();
          run_info.chart_symbol = ChartSymbol(0);
          run_info.strategy_group_key = g_strategy_group_key;
          run_info.config_fingerprint = g_config_fingerprint;
          run_info.coordinator_mode = (int)g_coordinator_mode;
          run_info.authority_epoch = (int)g_authority_epoch;
          run_info.runtime_count = 0; // Will be updated after runtime init
          g_dashboard_diag.SetRunInfo(run_info);
          g_logger.Event(LOG_INFO, "INIT", "DIAG_INITIALIZED", "", "", "", "", "OK", "DIAG",
                         "Dashboard Diagnostics enabled (TesterVisual=" + (is_tester_visual ? "true" : "false") + ")");
         }
       else
         {
          g_logger.Event(LOG_WARNING, "INIT", "DIAG_INIT_FAILED", "", "", "", "", "WARN", "DIAG",
                         "Dashboard Diagnostics initialization failed");
          g_dashboard_diag_enabled = false;
         }
}

// Safe Dashboard-Only Mode status
    bool safe_mode_active = IsSafeModeActive();
    bool safe_mode_enforced = IsSafeModeEnforced();
    g_logger.Event(LOG_INFO, "INIT", "SAFE_MODE_STATUS", "", "", "", "",
                   InpDashboardSafeMode ? (safe_mode_active ? "ACTIVE" : "ENFORCED") : "DISABLED", "SAFE_MODE",
                   "Safe Dashboard-Only Mode: InpDashboardSafeMode=" + (InpDashboardSafeMode ? "true" : "false") +
                   " MQL_TESTER=" + (MQLInfoInteger(MQL_TESTER) ? "true" : "false") +
                   " MQL_VISUAL_MODE=" + (MQLInfoInteger(MQL_VISUAL_MODE) ? "true" : "false") +
                   " Enforced=" + (safe_mode_enforced ? "true" : "false") +
                   " Active=" + (safe_mode_active ? "true" : "false"));

    // Initial dashboard render after config applied
    if(InpDashboard)
      {
       g_dashboard.ShowStatus("SYSTEM INITIALIZING");
       g_dashboard.Render();
      }

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

// P0-2: Read External Risk Lock state and apply to RiskEngine
    ExtRiskLockState ext_lock_state = ReadExtRiskLockState();
    if(ext_lock_state.valid)
      {
      ENUM_REJECTION_REASON lock_reason_code = REJECT_NONE;
      string lock_reason = "";

      switch(ext_lock_state.state)
        {
        case EXT_RISK_LOCK_LOCKED:
          lock_reason_code = REJECT_EXTERNAL_RISK_LOCKED;
          lock_reason = "External Risk Lock active: " + ExtRiskLockReasonToString(ext_lock_state.reason_code);
          break;
        case EXT_RISK_LOCK_UNKNOWN:
          if(InpExternalRiskLockFailClosed)
            {
            lock_reason_code = REJECT_EXTERNAL_RISK_STATE_UNKNOWN;
            lock_reason = "External Risk Lock state unknown/unavailable (fail-closed): " + ExtRiskLockReasonToString(ext_lock_state.reason_code);
            }
          else
            {
            lock_reason_code = REJECT_EXTERNAL_RISK_SOURCE_UNAVAILABLE;
            lock_reason = "External Risk Lock source unavailable: " + ExtRiskLockReasonToString(ext_lock_state.reason_code);
            }
          break;
        case EXT_RISK_LOCK_DISABLED:
        case EXT_RISK_LOCK_UNLOCKED:
        default:
          lock_reason_code = REJECT_NONE;
          lock_reason = "";
          break;
        }

      g_risk_engine.SetExternalLock(
        (lock_reason_code != REJECT_NONE),
        lock_reason_code,
        lock_reason);

// Store globally for PortfolioRisk checks in ProcessHybridDecision
       g_ext_risk_lock_state = ext_lock_state;
       g_ext_risk_lock_state_valid = true;

       // Update Dashboard with ERL state (valid unlocked/disabled state)
       if(InpDashboard)
         {
          if(ext_lock_state.state == EXT_RISK_LOCK_UNLOCKED)
            {
             g_dashboard.SetExternalRiskLockState("UNLOCKED", "ExternalRiskLock", true, "TTL=" + IntegerToString(InpExternalRiskLockTTL) + "s");
            }
          else if(ext_lock_state.state == EXT_RISK_LOCK_DISABLED)
            {
             g_dashboard.SetExternalRiskLockState("DISABLED", "ExternalRiskLock", true, "Feature disabled by configuration");
            }
         }

       // Log state changes
      static int s_last_ext_lock_revision = -1;
      if(ext_lock_state.revision != s_last_ext_lock_revision)
        {
        s_last_ext_lock_revision = ext_lock_state.revision;
        g_logger.Event(
          LOG_INFO, "RISK", "EXTERNAL_RISK_LOCK_UPDATE",
          "", "", "", "",
          "INFO", "EXT_RISK_LOCK",
          "External Risk Lock: state=" + IntegerToString(ext_lock_state.state) +
          " reason=" + ExtRiskLockReasonToString(ext_lock_state.reason_code) +
          " source=" + ExtRiskLockSourceToString(ext_lock_state.source_code) +
          " rev=" + IntegerToString(ext_lock_state.revision) +
          " applied_lock=" + (lock_reason_code != REJECT_NONE ? "true" : "false"));
        }
      }
    else
      {
      g_ext_risk_lock_state_valid = false;
      }

    PortfolioState current_state;
   if(!g_state.GetPortfolioState(current_state))
      return false;

   LogRiskLockTransition(current_state);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// P2.2: Central cooperative multi-asset scheduler.
// Both OnTick and OnTimer funnel through this entry point.
// Critical global services are handled by callers BEFORE invoking this.
void RunMultiAssetScheduler(string trigger_reason)
  {
   g_sched_invocations++;
   ulong start_us = GetMicrosecondCount();
   ulong time_budget_us = (ulong)g_sched_time_budget_us;
   int steps = 0;
   int scanned = 0;
   int total = g_runtime.Total();
   if(total <= 0)
      return;

   // Ensure cursor is in range (handles registry changes)
   if(g_sched_cursor < 0 || g_sched_cursor >= total)
      g_sched_cursor = 0;

   int idx = g_sched_cursor;
   while(steps < g_sched_step_budget && scanned < total)
     {
      // Time budget check between atomic slots (unsigned, monotonic)
      ulong now_us = GetMicrosecondCount();
      ulong elapsed = now_us - start_us;
      if(elapsed > time_budget_us)
        {
         g_sched_time_exhausted++;
         g_sched_deferred++;
         break;
        }

      if(idx >= total)
         idx = 0;

      CSymbolRuntime *runtime = g_runtime.At(idx);
      if(runtime && runtime.valid)
        {
         // One atomic runtime step per pass (no duplicate within same pass)
         ProcessRuntime(runtime);
         steps++;
        }

      scanned++;
      idx++;
      if(idx >= total)
        {
         idx = 0;
         g_sched_rotation_count++;
        }
     }

   // Step budget exhausted (only if work remains)
   if(steps >= g_sched_step_budget && scanned < total)
      g_sched_step_exhausted++;

   // Retain cursor for fair continuation on next invocation
   g_sched_cursor = idx;
   if(g_sched_cursor >= total)
      g_sched_cursor = 0;
  }

void OnTick()
  {
   if(!g_system_ready)
      return;

   bool risk_state_ready=RefreshTradingState();

g_logger.MaybeWriteSummary(false);

    // Safe Mode: Skip all position management mutations
    // Allow in Visual Tester (IsSafeModeActive), block elsewhere when enforced
    if(IsSafeModeEnforced() && !IsSafeModeActive())
      {
      g_blocked_mutation_count++;
      g_logger.Event(LOG_INFO, "SAFE_MODE", "MUTATION_BLOCKED", "", "", "", "",
                     "BLOCK", "SAFE_MODE",
                     "Safe Dashboard-Only Mode: position management blocked (blocked=" + IntegerToString(g_blocked_mutation_count) + " executed=" + IntegerToString(g_executed_mutation_count) + ")");
      }
    else
      {
      g_position_manager.Update();
      }

    if(!risk_state_ready)
      {
       // SP-01: Signal scheduling continues even when risk state is unavailable.
       // Risk admission is enforced at the signal-to-execution boundary.
      }

if(g_coordinator_mode == COORD_MODE_COORDINATOR)
      {
        // Periodically retry initialization of pending symbols (e.g., waiting for SymbolIsSynchronized)
        TryInitializePendingRuntimesBounded("OnTick");

        // P2.2: central scheduler replaces direct host-symbol loop
        RunMultiAssetScheduler("OnTick");
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
        {
         // Render dashboard during initialization waiting phase to show progress
         UpdateDashboardForChart();
         return;
        }

      if(init_status==SYSTEM_INIT_FAILED)
        {
         g_initialization_failed=true;
         g_initialization_started=false;
         g_dashboard.ShowStatus("SYSTEM INITIALIZATION FAILED");
         g_dashboard.Render();
         return;
         }
      }

if(g_coordinator_mode == COORD_MODE_COORDINATOR)
       {
        // F8: Discovery is rate-limited to 5s; the throttle must NOT gate heartbeat/authority
        // validation, reconciliation, retry handoff, position management or runtime processing.
        static datetime last_discovery = 0;
        if(TimeCurrent() - last_discovery >= 5)
          {
           last_discovery = TimeCurrent();
           // Discovery: enumerate charts and send discovery probe
           long chart = ChartFirst();
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
          int sub_count = g_subscriber_registry.Count();
          string canonical = IntegerToString((long)TimeCurrent()) + "_" + IntegerToString(sub_count) + "_" + IntegerToString(g_authority_epoch);
          if(canonical == last_canonical)
            {
             // unchanged; skip
            }
          else
            {
             last_canonical = canonical;
             g_snapshot_sequence++;
             // Use thread-safe subscriber registry (WP-05)
             SubscriberRecord subs[64];
             int count = g_subscriber_registry.GetSubscribers(subs);
             for(int i = 0; i < count; i++)
               {
                long target_chart = subs[i].chart_id;
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
 } // end rate-limited discovery block (F8)
        // Bounded retry for pending runtime initialization (e.g. waiting for history/sync).
// Timer-driven recovery does not rely on chart ticks and preserves idempotency.
        TryInitializePendingRuntimesBounded("OnTimer");
   string authority_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
          // CR-02: Expire stale authority lease before heartbeat/validation (configurable lease)
          // R-03: Pass owner_token to prevent coordinator from expiring its own lease
          string expire_reason = "";
          g_execution_ledger.ExpireStaleAuthority(authority_key, InpAuthorityLeaseSeconds, expire_reason, g_owner_instance_token);
          if(expire_reason != "")
            {
            if(expire_reason == "LEDGER_UNAVAILABLE")
              {
              g_logger.Event(LOG_WARNING, "SYSTEM", "AUTHORITY_EXPIRE_SKIPPED", _Symbol, "", "", "", "WARNING", "AUTHORITY", "Authority lease expiry skipped: " + expire_reason);
              }
            else
              {
              g_logger.Event(LOG_INFO, "SYSTEM", "AUTHORITY_EXPIRED", _Symbol, "", "", "", "INFO", "AUTHORITY", "Authority lease expired: " + expire_reason);
              }
            }
       if(!g_execution_ledger.HeartbeatAuthority(authority_key, g_owner_instance_token, g_authority_epoch) ||
             !g_execution_ledger.ValidateAuthority(authority_key, g_owner_instance_token, g_authority_epoch))
            {
             g_coordinator_mode = COORD_MODE_UNAVAILABLE;
             g_coordinator_unavailable_reason = "AUTHORITY_HEARTBEAT_FAILED";
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
           // CR-01: Idempotent reservation reconciliation for restart safety
           string res_reason = "";
           string account_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
int res_count = g_execution_ledger.ReconcileReservations(account_key, res_reason);
            if(res_count > 0)
              {
              g_logger.Event(LOG_INFO, "EXECUTION", "RESERVATION_RECONCILED", _Symbol, "", "", "", "INFO", "RESERVATION",
                             "Idempotent reservation reconciliation: " + IntegerToString(res_count) + " reservations advanced to EXPOSURE_RECONCILED");
              }
            else
              {
              g_logger.Event(LOG_INFO, "EXECUTION", "RESERVATION_RECONCILE_NONE", _Symbol, "", "", "", "INFO", "RESERVATION",
                             "Idempotent reservation reconciliation: 0 reservations reconciled. Reason: " + res_reason);
              }
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

   // WP-07: Metrics Exporter & Alert Manager periodic updates
   g_metrics_exporter.OnTimer();

   // Collect metrics for alerting
   double used_margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double margin_level = (used_margin > 0) ?
                         (AccountInfoDouble(ACCOUNT_EQUITY) / used_margin * 100.0) : 0;
   g_alert_manager.CheckMarginLevel(margin_level);

   PortfolioState pstate;
   if(g_state.GetPortfolioState(pstate))
   {
      g_alert_manager.CheckDailyLoss(pstate.daily_loss_percent * 100.0);
      // Note: PortfolioState doesn't have max_drawdown_pct, use total_open_risk_percent as proxy
      g_alert_manager.CheckDrawdown(pstate.total_open_risk_percent * 100.0);
      g_alert_manager.CheckPositionCount(pstate.total_positions);

      // Update metrics exporter with portfolio data
      // PortfolioState has: total_open_risk_percent (exposure), total_positions
      // No: unrealized_pnl, realized_pnl, pending_orders, max_drawdown_pct
      g_metrics_exporter.SetPortfolioMetrics(
         pstate.total_open_risk_percent,
         0, // unrealized_pnl - not available in PortfolioState
         0, // realized_pnl - not available in PortfolioState
         pstate.total_positions,
         0  // pending_orders - not available in PortfolioState
      );

      // Account metrics
      g_metrics_exporter.SetAccountMetrics(
         AccountInfoDouble(ACCOUNT_BALANCE),
         AccountInfoDouble(ACCOUNT_EQUITY),
         AccountInfoDouble(ACCOUNT_MARGIN),
         AccountInfoDouble(ACCOUNT_MARGIN_FREE),
         margin_level
      );
   }

   // News blackout check - simplified: check if any position has NEWS_BLOCKED status
   // We can't easily access HybridEngine's news service from here
   // SetNewsMetrics with 0 for now
   g_metrics_exporter.SetNewsMetrics(0, 0);

   // Engine metrics
g_metrics_exporter.SetEngineMetrics(
       TimeCurrent() - g_ea_start_time, // uptime in seconds
       0, // avg tick latency - would need more instrumentation
       g_runtime.Total()
    );

    // Safe Mode: Skip all position management mutations
    // Allow in Visual Tester (IsSafeModeActive), block elsewhere when enforced
    if(IsSafeModeEnforced() && !IsSafeModeActive())
      {
      g_blocked_mutation_count++;
      g_logger.Event(LOG_INFO, "SAFE_MODE", "MUTATION_BLOCKED", "", "", "", "",
                     "BLOCK", "SAFE_MODE",
                     "Safe Dashboard-Only Mode: position management blocked (blocked=" + IntegerToString(g_blocked_mutation_count) + " executed=" + IntegerToString(g_executed_mutation_count) + ")");
      }
    else
      {
      g_position_manager.Update();
      }

    if(!risk_state_ready)
      {
       // SP-01: Signal scheduling continues even when risk state is unavailable.
       // Risk admission is enforced at the signal-to-execution boundary.
      }

if(g_coordinator_mode == COORD_MODE_COORDINATOR)
      {
       // P2.2: central scheduler replaces direct host-symbol loop
       RunMultiAssetScheduler("OnTimer");
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
//| F-005.2.4: Event-type-specific handling per MQL5 semantics.      |
//| request/result only valid for TRADE_TRANSACTION_REQUEST.         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
   {
   if(!g_system_ready)
      return;

   // F-005.2.4: Process by transaction type - request/result only valid for REQUEST
   ENUM_TRADE_TRANSACTION_TYPE txn_type = trans.type;

   // Candidate Magic for filtering - use valid data per transaction type
   ulong candidate_magic = 0;
   bool  has_valid_magic = false;

   switch(txn_type)
     {
      case TRADE_TRANSACTION_REQUEST:
         // request/result are valid for this type
         candidate_magic = request.magic;
         has_valid_magic = true;
         break;

      case TRADE_TRANSACTION_ORDER_ADD:
      case TRADE_TRANSACTION_ORDER_UPDATE:
      case TRADE_TRANSACTION_ORDER_DELETE:
         // Use order Magic from history
         if(trans.order > 0 && HistoryOrderSelect(trans.order))
           {
            long order_magic = 0;
            if(HistoryOrderGetInteger(trans.order, ORDER_MAGIC, order_magic))
              {
               candidate_magic = (ulong)order_magic;
               has_valid_magic = true;
              }
           }
         break;

      case TRADE_TRANSACTION_DEAL_ADD:
      case TRADE_TRANSACTION_DEAL_UPDATE:
         // Use deal Magic from history
         if(trans.deal > 0 && HistoryDealSelect(trans.deal))
           {
            long deal_magic = 0;
            if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC, deal_magic))
              {
               candidate_magic = (ulong)deal_magic;
               has_valid_magic = true;
              }
           }
         break;

      case TRADE_TRANSACTION_HISTORY_ADD:
      case TRADE_TRANSACTION_HISTORY_UPDATE:
      case TRADE_TRANSACTION_HISTORY_DELETE:
         // History events - use deal/order Magic if available
         if(trans.deal > 0 && HistoryDealSelect(trans.deal))
           {
            long deal_magic = 0;
            if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC, deal_magic))
              {
               candidate_magic = (ulong)deal_magic;
               has_valid_magic = true;
              }
           }
         else if(trans.order > 0 && HistoryOrderSelect(trans.order))
           {
            long order_magic = 0;
            if(HistoryOrderGetInteger(trans.order, ORDER_MAGIC, order_magic))
              {
               candidate_magic = (ulong)order_magic;
               has_valid_magic = true;
              }
           }
         break;

      case TRADE_TRANSACTION_POSITION:
         // Position events - use position Magic
         if(trans.position > 0 && PositionSelectByTicket(trans.position))
           {
            long pos_magic = 0;
            if(PositionGetInteger(POSITION_MAGIC, pos_magic))
              {
               candidate_magic = (ulong)pos_magic;
               has_valid_magic = true;
              }
           }
         break;

      default:
         // Unknown transaction type - no valid Magic available
         break;
     }

   // Filter: only process if we have a valid candidate Magic in our managed namespace
   bool is_managed_candidate = false;
   if(has_valid_magic)
     {
      // Strategy/style Magic (legacy ownership)
      if(candidate_magic==MAGIC_TREND ||
         candidate_magic==MAGIC_BREAKOUT ||
         candidate_magic==MAGIC_MOMENTUM ||
         candidate_magic==MAGIC_MEAN_REVERSION ||
         candidate_magic==MAGIC_RELATIVE_VALUE ||
         candidate_magic==MAGIC_HYBRID_SCALP ||
         candidate_magic==MAGIC_HYBRID_DAY ||
         candidate_magic==MAGIC_HYBRID_SWING)
         is_managed_candidate = true;
      // Attempt Magic range - candidate only, exact ownership requires ledger
      else if(candidate_magic >= MAGIC_ATTEMPT_BASE && candidate_magic <= MAGIC_ATTEMPT_MAX)
         is_managed_candidate = true;
     }

   if(!is_managed_candidate)
      return;

   // Log transaction for auditability
   g_logger.Event(
      LOG_DEBUG, "TRADE", "TRADE_TRANSACTION",
      trans.symbol, "", "",
      "", "TXN", IntegerToString((int)txn_type),
      "order="+IntegerToString((long)trans.order)+
      " deal="+IntegerToString((long)trans.deal)+
      " position="+IntegerToString((long)trans.position)+
      (has_valid_magic ? " magic="+IntegerToString((long)candidate_magic) : " magic=UNKNOWN"));

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

void RetryUIEnsureObjects()
  {
   if(g_retry_ui_status=="") g_retry_ui_status="IDLE_NO_AUTO_RETRY";
   g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
  }

void RetryUISelectCurrentCandidate(bool advance)
  {
   string diag="";
   if(g_retry_candidate_count<=0 || ArraySize(g_retry_candidates)<=0)
     { RetryUIInvalidate("NO_ELIGIBLE_CANDIDATES"); g_retry_ui_state=E2E6_UI_BLOCKED;
    g_retry_ui_status="REVIEW_NO_CANDIDATES";
    g_retry_ui_detail=(diag==""?"No eligible durable FINAL_FAILURE candidate.":diag);
    g_dashboard.SetRetryUIState(E2E6_UI_BLOCKED, "REVIEW_NO_CANDIDATES", (diag==""?"No eligible durable FINAL_FAILURE candidate.":diag));
    g_dashboard.Render(); return; }
   if(advance)
      g_retry_candidate_index = (g_retry_candidate_index + 1) % g_retry_candidate_count;
   if(g_retry_candidate_index < 0 || g_retry_candidate_index >= g_retry_candidate_count)
      g_retry_candidate_index = 0;
   RetryReviewCandidate sel;
   if(!RetryUIFillReviewFromLedgerCandidate(g_retry_candidates[g_retry_candidate_index], sel, diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED;
    g_retry_ui_status="REVIEW_CANDIDATE_INVALID";
    g_retry_ui_detail=diag;
    g_dashboard.SetRetryUIState(E2E6_UI_BLOCKED, "REVIEW_CANDIDATE_INVALID", diag);
    g_dashboard.Render(); return; }
   // Reload selected exact candidate from durable ledger before confirmation-ready state.
   if(!RetryUIRefreshCandidate(sel, diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED;
    g_retry_ui_status="REVIEW_RELOAD_FAILED";
    g_retry_ui_detail=diag;
    g_dashboard.SetRetryUIState(E2E6_UI_BLOCKED, "REVIEW_RELOAD_FAILED", diag);
    g_dashboard.Render(); return; }
   g_retry_review = sel;
   g_retry_ui_state = E2E6_UI_CONFIRM_READY;
   g_retry_ui_status = "REVIEW_READY_EXPLICIT_CONFIRM_REQUIRED";
   g_retry_ui_detail = "Durable candidate loaded from ledger; verify all safety fields before Confirm. No broker call.";
   g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
  }

void RetryUIHandleReviewClick()
  {
   if(g_retry_handoff.active)
     { g_retry_ui_status="REVIEW_BLOCKED_HANDOFF_ACTIVE";
    g_retry_ui_detail="Transient committed handoff active (fail-closed, no auto-submit).";
    g_dashboard.SetRetryUIState(g_retry_ui_state, "REVIEW_BLOCKED_HANDOFF_ACTIVE", "Transient committed handoff active (fail-closed, no auto-submit).");
    g_dashboard.Render(); return; }
   RetryUIInvalidate("REVIEW_REQUESTED");
   g_retry_ui_state = E2E6_UI_BLOCKED;
   g_retry_ui_status = "REVIEW_LOADING";
   string diag="";
   if(!RetryUILoadCandidateList(diag))
     {
      g_retry_ui_status = "REVIEW_BLOCKED";
      g_retry_ui_detail = "Candidate discovery fail-closed: " + diag + ". No DB/broker mutation.";
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
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
   g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
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
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   RetryReviewCandidate reviewed_snapshot = g_retry_review; // immutable review snapshot
   if(!RetryUIChartContextCurrent(reviewed_snapshot))
     {
      RetryUIInvalidate("CONTEXT_CHANGED_BEFORE_CONFIRM");
      g_retry_ui_status = "INVALIDATED_CONTEXT_CHANGED";
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   string diag="";
   if(!RetryUIRefreshCandidate(g_retry_review, diag))
     {
      RetryUIInvalidate(diag);
      g_retry_ui_status = "INVALIDATED_BEFORE_CONFIRM";
      g_retry_ui_detail = diag;
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   // Confirm reload must compare complete immutable snapshot; no arbitrary caller IDs accepted.
   if(!RetryUISameCandidateSnapshot(reviewed_snapshot, g_retry_review))
     {
      RetryUIInvalidate("SNAPSHOT_CHANGED_AFTER_REVIEW");
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "CONFIRM_BLOCKED_SNAPSHOT_CHANGED";
      g_retry_ui_detail = "Durable candidate/evidence/context changed since Review; re-review required. No DB mutation.";
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   if(reviewed_snapshot.claim_id=="" || reviewed_snapshot.strategy_group_key=="" || reviewed_snapshot.logical_setup_key=="" || reviewed_snapshot.prior_attempt_id=="")
     {
      RetryUIInvalidate("MISSING_IMMUTABLE_IDS");
      g_retry_ui_status = "CONFIRM_BLOCKED_INVALID_IDS";
      g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   if(g_coordinator_mode != COORD_MODE_COORDINATOR)
     {
      g_retry_ui_status = "CONFIRM_BLOCKED_NOT_COORDINATOR"; g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
    return;
     }
   string auth_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(!g_execution_ledger.ValidateAuthority(auth_key, g_owner_instance_token, g_authority_epoch))
     {
      g_retry_ui_status = "CONFIRM_BLOCKED_AUTHORITY"; g_retry_ui_detail="Fresh durable authority validation failed."; g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
    return;
     }
   g_executor.SyncAuthority(g_authority_epoch, true);

   CExecutionLedger::RetryLocalContext ctx;
   RetryUIBuildLocalContext(ctx);
ExecutionAttemptRecord new_attempt; ZeroMemory(new_attempt);
    // F-005.2.2: Account scope for ownership resolution (schema v5).
    new_attempt.account_key = AccountInfoString(ACCOUNT_SERVER) + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
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
   g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
  }

void RetryUIHandleNextClick()
  {
   if(g_retry_handoff.active)
     { g_retry_ui_status="NEXT_BLOCKED_HANDOFF_ACTIVE"; g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
    return; }
   if(g_retry_candidate_count <= 0)
     { RetryUIHandleReviewClick(); return; }
   // Re-load list and reselect next deterministically (bounded). No DB writes.
   int prev = g_retry_candidate_index; string diag="";
   if(!RetryUILoadCandidateList(diag))
     { RetryUIInvalidate(diag); g_retry_ui_state=E2E6_UI_BLOCKED;
    g_retry_ui_status="NEXT_DISCOVERY_FAILED";
    g_retry_ui_detail=diag;
    g_dashboard.SetRetryUIState(E2E6_UI_BLOCKED, "NEXT_DISCOVERY_FAILED", diag);
    g_dashboard.Render(); return; }
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
      if(render) g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   string err="", login=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)), server=AccountInfoString(ACCOUNT_SERVER);
   int n = g_execution_ledger.GetInterruptedRetryHandoffs(login, server, g_strategy_group_key, g_retry_interrupted, 5, err);
   if(n < 0)
     {
      g_retry_ui_state = E2E6_UI_BLOCKED;
      g_retry_ui_status = "INTERRUPTED_QUERY_FAILED_FAIL_CLOSED";
      g_retry_ui_detail = (err==""?"Interrupted retry query failed":err) + " - no auto-submit/restore.";
      if(render) g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
      return;
     }
   g_retry_interrupted_count = n;
   if(n <= 0)
     {
      if(g_retry_ui_state == E2E6_UI_INTERRUPTED_VIEW)
        { g_retry_ui_state = E2E6_UI_HIDDEN; g_retry_ui_status="NO_INTERRUPTED_RETRY_FOUND"; g_retry_ui_detail="Read-only inspection: no durable interrupted retry handoff records in current account/group context."; }
      if(render) g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
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
   if(render) g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
    g_dashboard.Render();
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
   for(int i=0;i<g_runtime.Total();i++)
     {
      CSymbolRuntime *runtime = g_runtime.At(i);
      if(runtime && runtime.valid && runtime.symbol==symbol) return i;
     }
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
                                CAlgoPortfolioRisk::AdmissionDecision &out_admission,
                                string &reason)
  {
   reason="";
   ZeroMemory(out_admission);
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

   // P0-2: External Risk Lock check in retry validation path
   if(g_ext_risk_lock_state_valid && InpExternalRiskLockEnabled)
     {
     string rejection_code, rejection_reason;
     CAlgoPortfolioRisk::ExtRiskLockState pr_lock_state = ToPortfolioRiskLockState(g_ext_risk_lock_state);

     if(!g_portfolio_risk.CheckExternalRiskLock(pr_lock_state, rejection_code, rejection_reason))
       {
       reason = "EXTERNAL_RISK_LOCK_BLOCK_RETRY:" + rejection_reason;
       return false;
       }
     }

   if(!g_portfolio_risk.CanOpen(legacy_signal, risk)) { reason="PORTFOLIO_RISK_REJECT:"+g_portfolio_risk.LastRejectionReason(); return false; }

   // Fail-closed news gate: candidate evaluation reached a plan, but retry submission must not proceed if blocked.
   if(decision.status == DECISION_NEWS_BLOCKED) { reason="NEWS_ENTRY_BLOCKED"; return false; }

   // F-002/P2: full admission + pre-submit revalidation on fresh state before any retry submission (exclude own attempt reservation).
   CAlgoPortfolioRisk::AdmissionDecision admission_decision;
   ZeroMemory(admission_decision);
   if(!g_portfolio_risk.CanAdmit(legacy_signal, risk, admission_decision, new_att.attempt_id))
     { reason = "ADMISSION_REJECTED:" + admission_decision.rejection_code + ":" + admission_decision.rejection_reason; return false; }
   string reval_admission_reason="";
   if(!g_portfolio_risk.RevalidateAdmission(legacy_signal, risk, admission_decision, reval_admission_reason, new_att.attempt_id))
     { reason = "ADMISSION_REVALIDATION_FAILED:" + reval_admission_reason; return false; }

   if(risk.calculated_volume <= 0.0 || !MathIsValidNumber(risk.calculated_volume)) { reason="RISK_VOLUME_INVALID"; return false; }
   // Ensure fresh plan is not consumed marker in probe result.
   normalized_plan.consumed=false;
   out_plan = normalized_plan; out_legacy = legacy_signal; out_risk = risk; out_admission = admission_decision;
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
    CSymbolRuntime *runtime = g_runtime.At(rt_idx);
    if(!runtime) { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_RUNTIME_NOT_FOUND"; return; }

    // P2: fail-closed terminal-failure proof for prior attempt before any retry submission path.
    ExecutionAttemptRecord prior_att;
    ZeroMemory(prior_att);
    if(g_retry_handoff.prior_attempt_id == "" || !g_execution_ledger.GetAttempt(g_retry_handoff.prior_attempt_id, prior_att))
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_PRIOR_ATTEMPT_UNAVAILABLE"; g_retry_ui_detail="Cannot prove prior terminal failure; no submit."; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Prior attempt unavailable for retry proof"); return; }
    string prior_why="";
    if(!g_execution_ledger.IsRetryEligibleFinalFailure(prior_att, prior_why))
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_PRIOR_NOT_TERMINAL_PROVEN"; g_retry_ui_detail="Prior attempt not proven terminal non-execution: "+prior_why; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Prior attempt not proven terminal failure: "+prior_why); return; }
    if(prior_att.state == EXEC_STATE_SUBMISSION_MAY_HAVE_OCCURRED || prior_att.state == EXEC_STATE_RECONCILIATION_REQUIRED || prior_att.state == EXEC_STATE_PARTIAL_FILL || prior_att.state == EXEC_STATE_SUBMITTED || prior_att.state == EXEC_STATE_COMPLETED)
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_PRIOR_AMBIGUOUS_OR_EXECUTED"; g_retry_ui_detail="Prior attempt ambiguous/executed; retry forbidden."; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Prior attempt ambiguous/executed"); return; }

    TradePlan fresh_plan; StrategySignal fresh_signal; RiskDecision fresh_risk; CAlgoPortfolioRisk::AdmissionDecision fresh_admission; string reval_reason="";
    ZeroMemory(fresh_admission);
    if(!RetryUIRevalidateFreshPlan(runtime, new_att, g_retry_handoff.strategy_group_key, g_retry_handoff.logical_setup_key, g_retry_handoff.config_fingerprint,
                                   fresh_plan, fresh_signal, fresh_risk, fresh_admission, reval_reason))
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

   // P2: final admission revalidation immediately before submit boundary (fresh state drift protection).
   {
    string final_reval_admission="";
    if(!g_portfolio_risk.RevalidateAdmission(fresh_signal, fresh_risk, fresh_admission, final_reval_admission, g_retry_handoff.new_attempt_id))
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_ADMISSION_FAILED"; g_retry_ui_detail=final_reval_admission; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Final admission revalidation failed: "+final_reval_admission); return; }
   }

   if(g_execution_ledger.HasBlockingUnresolved(g_retry_ui_detail) || g_execution_ledger.HasUnresolvedForSymbol(new_att.symbol, true))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_UNRESOLVED_BLOCK"; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"Unresolved/ledger block before submit"); return; }
// Re-read attempt immediately before bind/submit.
    if(!g_execution_ledger.GetAttempt(g_retry_handoff.new_attempt_id, new_att) || new_att.state != EXEC_STATE_INTENT_DURABLE_NOT_SUBMITTED)
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_ATTEMPT_CHANGED"; return; }

    // F-005.2: Get attempt_magic allocated by ledger for this retry attempt.
    // Ledger allocates atomically in ApproveAndCreateRetry/CreateIntentInTx.
    ulong attempt_magic = new_att.attempt_magic;
   string final_submit_reason="";
   if(!g_execution_ledger.CanSubmit(g_retry_handoff.new_attempt_id, final_submit_reason))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_FINAL_CANNOT_SUBMIT"; g_retry_ui_detail=final_submit_reason; g_execution_ledger.MarkReconciliationRequired(g_retry_handoff.new_attempt_id,"CanSubmit failed before submit: "+final_submit_reason); return; }

// Build fresh ExecutionRequest bound to new attempt ID (not old plan/request).
    ExecutionRequest request;
    request.intent = (fresh_plan.direction==SIGNAL_LONG ? ORDER_INTENT_OPEN_LONG : ORDER_INTENT_OPEN_SHORT);
    request.symbol = runtime.symbol;
    request.direction = fresh_plan.direction;
    request.strategy = STRATEGY_TREND_PULLBACK;
    request.volume = fresh_risk.calculated_volume;
    request.price = fresh_plan.entry;
    request.stop_loss = fresh_plan.stop;
    request.take_profit = fresh_plan.target;
    request.position_ticket = 0;
    request.magic = MagicForStyle(runtime.style);
    request.comment = "E26_RETRY|" + g_retry_handoff.action_id;
    request.signal_id = fresh_plan.setup_id;
    request.attempt_id = g_retry_handoff.new_attempt_id;
    request.attempt_magic = attempt_magic;

   if(!g_execution_ledger.MarkSubmissionBound(request.attempt_id, "E2.6 retry pre-submit revalidation passed action="+g_retry_handoff.action_id))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_BIND_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"MarkSubmissionBound failed (no broker call)"); return; }
   if(!g_execution_ledger.CanSubmit(request.attempt_id, final_submit_reason))
     { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_SUBMIT_GATE_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"CanSubmit failed after bind: "+final_submit_reason); return; }
if(!g_execution_ledger.MarkSubmissionMayHaveOccurred(request.attempt_id, "E2.6 retry broker boundary action="+g_retry_handoff.action_id))
      { g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_MAY_HAVE_OCCURRED_FAILED"; g_execution_ledger.MarkReconciliationRequired(request.attempt_id,"MarkSubmissionMayHaveOccurred failed; broker call aborted"); return; }

    ExecutionResult result; ZeroMemory(result);

    // P0-2: Fresh External Risk Lock read at final broker boundary (closes intra-tick race)
    if(InpExternalRiskLockEnabled)
      {
      string fresh_rejection_code, fresh_rejection_reason;
      ExtRiskLockState fresh_lock = ReadExtRiskLockStateFresh();
      CAlgoPortfolioRisk::ExtRiskLockState pr_fresh_lock = ToPortfolioRiskLockState(fresh_lock);
      if(!g_portfolio_risk.CheckExternalRiskLock(pr_fresh_lock, fresh_rejection_code, fresh_rejection_reason))
        {
        g_logger.Event(LOG_ERROR, "EXECUTION", "EXTERNAL_RISK_LOCK_BLOCK_FINAL_RETRY",
                       request.symbol, "", "", request.signal_id,
                       "FAIL", "EXT_RISK_LOCK", fresh_rejection_reason);
        // Bound intent was never sent to broker; resolve as terminal non-submission.
        {
        ExecutionAttemptRecord abort_rec;
        if(g_execution_ledger.GetAttempt(request.attempt_id, abort_rec))
           {
           string release_reason = "ABORTED_NON_SUBMISSION:ExternalRiskLock:" + fresh_rejection_reason;
           string rel_reason = "";
           if(g_execution_ledger.ReleaseReservation(request.attempt_id, abort_rec.risk_reserve_revision, release_reason, rel_reason) != CExecutionLedger::RESERVATION_LIFECYCLE_OK)
              {
              g_logger.Event(LOG_WARNING, "EXECUTION", "RESERVATION_RELEASE_FAILED", request.symbol, "", "", request.signal_id, "WARN", "RESERVATION", "ReleaseReservation failed: " + rel_reason);
              }
           }
        }
        if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "External Risk Lock block at final retry gate: " + fresh_rejection_reason))
          {
          g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after final retry gate block");
          string block_reason="";
          g_execution_ledger.HasBlockingUnresolved(block_reason);
          }
        g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_EXT_RISK_LOCK"; return;
        }
}

    // SAFE MODE: Block all broker mutations when active
    // Only allows Visual Tester execution; fail-closed elsewhere
    if(IsSafeModeEnforced() && !IsSafeModeActive())
      {
      g_blocked_mutation_count++;
      g_logger.Event(LOG_INFO, "SAFE_MODE", "MUTATION_BLOCKED",
                     request.symbol, "", "", request.signal_id,
                     "BLOCK", "SAFE_MODE",
                     "Safe Dashboard-Only Mode: broker mutation blocked (blocked=" + IntegerToString(g_blocked_mutation_count) + " executed=" + IntegerToString(g_executed_mutation_count) + ")");
      // Resolve attempt as ABORTED (non-submission) without broker call
      if(!g_execution_ledger.ResolveAttempt(request.attempt_id, EXEC_STATE_ABORTED, "Safe Dashboard-Only Mode: broker mutation blocked"))
        {
        g_logger.Event(LOG_ERROR, "EXECUTION", "RESOLVE_ATTEMPT_FAILED", request.symbol, "", "", request.signal_id, "FAIL", "LEDGER_ERROR", "ResolveAttempt(ABORTED) failed after Safe Mode block");
        string block_reason="";
        g_execution_ledger.HasBlockingUnresolved(block_reason);
        }
      g_retry_handoff.active=false; g_retry_ui_status="HANDOFF_SAFE_MODE_BLOCKED"; return;
      }

    bool execution_ok = g_executor.Execute(request, result); // broker call only via executor (timer path)
   g_executed_mutation_count++;
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
    runtime.hybrid_engine.MarkPlanConsumed(fresh_plan);
   g_retry_handoff.active=false;
   g_retry_ui_status = (execution_ok && result.success) ? "HANDOFF_SUBMITTED" : "HANDOFF_SUBMIT_RECORDED_FAIL_OR_AMBIG";
   g_retry_ui_detail = reval_reason + " submit_ok=" + (execution_ok?"1":"0") + " ret=" + IntegerToString((int)result.retcode) + " recon=" + (result.reconciliation_required?"1":"0");
   g_logger.Event(execution_ok?LOG_INFO:LOG_WARNING,"EXECUTION","RETRY_HANDOFF_SUBMIT", request.symbol,"",g_retry_handoff.logical_setup_key,request.attempt_id,execution_ok?"SUBMIT":"FAIL_OR_AMBIG","E2.6_RETRY",g_retry_ui_detail);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
    // F1: invalidate the local retry review ONLY on a real chart geometry change.
    // Unrelated custom events (CHARTREG_*, SNAPREG_*) must not reset an open retry review.
    if(id == CHARTEVENT_CHART_CHANGE)
      {
       RetryUIInvalidate("CHART_GEOMETRY_CHANGED");
       g_dashboard.HandleChartGeometryChange();
       g_dashboard.SetRetryUIState(g_retry_ui_state, g_retry_ui_status, g_retry_ui_detail);
       g_dashboard.Render();
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
       // Use thread-safe subscriber registry (WP-05)
       bool ok = g_subscriber_registry.Register(req_chart, req_token, req_group, req_fp);
       if(!ok)
          return; // conflict or capacity exceeded
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
       // Validate sender is a known subscriber using thread-safe registry (WP-05)
       bool known = g_subscriber_registry.IsRegistered(ack_chart);
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
       // Remove only matching registered subscriber (chart+token) using thread-safe registry (WP-05)
       g_subscriber_registry.Unregister(req_chart, req_token);
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
      bool released = g_execution_ledger.ReleaseAuthority(authority_key, g_owner_instance_token, g_authority_epoch);
      if(!released)
        {
         g_logger.Event(LOG_WARNING, "SYSTEM", "AUTHORITY_RELEASE_FAILED", _Symbol, "", "", "", "WARNING", "AUTHORITY", "ReleaseAuthority failed on deinit; epoch=" + IntegerToString(g_authority_epoch));
        }
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

   // F18: Clean up runtime objects (CArrayObj ownership - delete all elements)
   for(int i = g_runtime.Total() - 1; i >= 0; i--)
     {
      CSymbolRuntime *runtime = g_runtime.At(i);
      if(runtime != NULL)
        {
         delete runtime;
        }
     }
   g_runtime.Clear();

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

//+------------------------------------------------------------------+
//| Normalize symbol for comparison (remove suffixes/prefixes, upper) |
//| F14: improved to handle multiple/complex broker suffixes/prefixes |
//|      and provide consistent normalization for broker<->config map  |
//+------------------------------------------------------------------+
string NormalizeSymbolForComparison(const string symbol)
  {
   if(symbol=="") return "";
   string s = symbol;
   // Remove ALL matching suffixes (not just first) - iterate until no change
   string suffixes[] = {".pro", ".ecn", ".raw", ".std", ".m", ".demo", "#", "+", "_"};
   bool changed = true;
   while(changed)
     {
      changed = false;
      for(int i=0; i<ArraySize(suffixes); i++)
        {
         string suffix = suffixes[i];
         int pos = StringFind(s, suffix);
         if(pos >= 0 && pos == StringLen(s) - StringLen(suffix)) // suffix at end
           {
            s = StringSubstr(s, 0, pos);
            changed = true;
            break; // restart loop after modification
           }
        }
     }
   // Remove ALL matching prefixes (not just first)
   string prefixes[] = {"m.", "raw.", "ecn.", "pro."};
   changed = true;
   while(changed)
     {
      changed = false;
      for(int i=0; i<ArraySize(prefixes); i++)
        {
         string prefix = prefixes[i];
         if(StringFind(s, prefix) == 0)
           {
            s = StringSubstr(s, StringLen(prefix));
            changed = true;
            break; // restart loop after modification
           }
        }
     }
   StringToUpper(s);
   return s;
  }

//+------------------------------------------------------------------+
//| Asset-agnostic broker-discovered candidate check                 |
//+------------------------------------------------------------------+
bool IsSymbolTradableCandidate(const string symbol)
  {
   if(symbol=="") return false;
   ENUM_SYMBOL_TRADE_MODE trade_mode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Discover and resolve configured symbol universe                  |
//| Uses explicit InpSymbolUniverse and optional InpSymbolSuffixMap  |
//+------------------------------------------------------------------+
int DiscoverTradableSymbols(string &symbols_out[])
{
    ArrayResize(symbols_out, 0);

    // 1. Parse configured symbol universe
    string configured_symbols[];
    if(!ParseSymbolUniverse(InpSymbolUniverse, configured_symbols))
    {
        g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_UNIVERSE_INVALID",
                       "", "", "", "",
                       "FAIL", "CONFIG",
                       "InpSymbolUniverse is empty or malformed (empty entries or duplicates after normalization)");
        return 0;
    }

    // 2. Parse suffix map
    string mapped_configured[];
    string mapped_broker[];
    if(!ParseSymbolSuffixMap(InpSymbolSuffixMap, mapped_configured, mapped_broker))
    {
        g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_SUFFIX_MAP_INVALID",
                       "", "", "", "",
                       "FAIL", "CONFIG",
                       "InpSymbolSuffixMap is malformed JSON");
        return 0;
    }

    // 3. Get all broker symbols for exact match checking
    string all_broker_symbols[];
    int total = SymbolsTotal(false);
    for(int i = 0; i < total; i++)
    {
        string sn = SymbolName(i, false);
        if(sn != "")
        {
            ArrayResize(all_broker_symbols, ArraySize(all_broker_symbols) + 1);
            all_broker_symbols[ArraySize(all_broker_symbols) - 1] = sn;
        }
    }

    // 4. Resolve each configured symbol to a broker symbol
    int resolved_count = 0;
    for(int i = 0; i < ArraySize(configured_symbols); i++)
    {
        string resolved_broker;
        if(!ResolveBrokerSymbol(configured_symbols[i], all_broker_symbols, mapped_configured, mapped_broker, resolved_broker))
        {
            // ResolveBrokerSymbol logs the specific failure
            g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_UNRESOLVED",
                           configured_symbols[i], "", "", "",
                           "SKIP", "UNRESOLVED",
                           "Configured symbol cannot be resolved to a broker symbol; other symbols continue");
            continue;
        }

        // Check for duplicate resolved broker symbols
        bool duplicate = false;
        for(int j = 0; j < resolved_count; j++)
        {
            if(symbols_out[j] == resolved_broker)
            {
                duplicate = true;
                break;
            }
        }

        if(duplicate)
        {
            g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_DUPLICATE_RESOLVED",
                           configured_symbols[i], "", "", "",
                           "SKIP", "DUPLICATE",
                           "Multiple configured symbols resolve to the same broker symbol: " + resolved_broker);
            continue;
        }

        int sz = ArraySize(symbols_out);
        ArrayResize(symbols_out, sz + 1);
        symbols_out[sz] = resolved_broker;
        resolved_count++;

        g_logger.Event(LOG_INFO, "INIT", "SYMBOL_RESOLVED",
                       configured_symbols[i], "", "", "",
                       "OK", "RESOLVED",
                       "Configured symbol resolved to broker symbol: " + resolved_broker);
    }

    // 5. NO automatic chart symbol inclusion - chart symbol is for display only
    // 6. NO fallback to chart symbol when empty - empty universe is explicit failure

    if(resolved_count == 0)
    {
        g_logger.Event(LOG_ERROR, "INIT", "SYMBOL_UNIVERSE_EMPTY",
                       "", "", "", "",
                       "FAIL", "EMPTY_UNIVERSE",
                       "No configured symbols could be resolved; strategy will not run");
    }

    return resolved_count;
}

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
  }
//+------------------------------------------------------------------+

