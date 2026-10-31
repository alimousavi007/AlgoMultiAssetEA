#ifndef __ALGOSYSTEM_HYBRID_TYPES_MQH__
#define __ALGOSYSTEM_HYBRID_TYPES_MQH__

#include "Constants.mqh"
#include "Types.mqh"

//+------------------------------------------------------------------+
//| Hybrid Trading Style                                              |
//+------------------------------------------------------------------+
enum ENUM_TRADING_STYLE
  {
   STYLE_SCALPING = 0,
   STYLE_DAY_TRADING,
   STYLE_SWING_TRADING
  };

//+------------------------------------------------------------------+
//| Directional Bias                                                  |
//+------------------------------------------------------------------+
enum ENUM_BIAS_DIRECTION
  {
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_CONFLICTED,
   BIAS_INSUFFICIENT_DATA
  };

//+------------------------------------------------------------------+
//| Market Regime (enhanced)                                          |
//+------------------------------------------------------------------+
enum ENUM_HYBRID_REGIME
  {
   HYBRID_REGIME_TRENDING = 0,
   HYBRID_REGIME_RANGING,
   HYBRID_REGIME_VOLATILITY_EXPANSION,
   HYBRID_REGIME_COMPRESSION,
   HYBRID_REGIME_TRANSITION,
   HYBRID_REGIME_INSUFFICIENT_DATA
  };

//+------------------------------------------------------------------+
//| Volume Data Mode                                                  |
//+------------------------------------------------------------------+
enum ENUM_VOLUME_DATA_MODE
  {
   VOLUME_MODE_REAL_VOLUME = 0,
   VOLUME_MODE_TICK_VOLUME_PROXY,
   VOLUME_MODE_INSUFFICIENT
  };

//+------------------------------------------------------------------+
//| Setup Lifecycle States                                            |
//+------------------------------------------------------------------+
enum ENUM_SETUP_STATE
  {
   SETUP_STATE_NONE = 0,
   SETUP_STATE_DETECTED,
   SETUP_STATE_VALID,
   SETUP_STATE_EXPIRED,
   SETUP_STATE_INVALIDATED,
   SETUP_STATE_CONSUMED,
   SETUP_STATE_REJECTED
  };

enum ENUM_STRUCTURAL_EVIDENCE_RESULT
  {
   EVIDENCE_NONE = 0,
   EVIDENCE_TICK_UNAVAILABLE,
   EVIDENCE_TICK_STALE_OR_UNVERIFIED,
   EVIDENCE_LEVEL_MISSING,
   EVIDENCE_LEVEL_STALE_OR_UNVERIFIED,
   EVIDENCE_SYMBOL_OR_TIMEFRAME_MISMATCH,
   EVIDENCE_INVALID_PLAN,
   EVIDENCE_INSUFFICIENT_EVIDENCE,
   EVIDENCE_STRUCTURAL_INVALIDATION_CONFIRMED,
   EVIDENCE_SUFFICIENT_NO_INVALIDATION
   };
enum ENUM_NEWS_STATE
   {
    NEWS_DISABLED = -1,
    NEWS_UNAVAILABLE = 0,
    NEWS_NO_EVENT_SCHEDULED,
    NEWS_BLACKOUT_ACTIVE,
    NEWS_COOLDOWN_ACTIVE,
    NEWS_EVENT_PASSED
   };


//+------------------------------------------------------------------+
//| Feature Validity                                                  |
//+------------------------------------------------------------------+
enum ENUM_FEATURE_VALIDITY
  {
   FEATURE_VALID = 0,
   FEATURE_INVALID,
   FEATURE_UNAVAILABLE,
   FEATURE_STALE
  };

//+------------------------------------------------------------------+
//| Decision Status                                                   |
//+------------------------------------------------------------------+
enum ENUM_DECISION_STATUS
  {
   DECISION_BUY_CANDIDATE = 0,
   DECISION_SELL_CANDIDATE,
   DECISION_NO_TRADE,
   DECISION_DATA_UNAVAILABLE,
   DECISION_NEWS_BLOCKED,
   DECISION_RISK_REJECTED,
   DECISION_CONFLICTED_SIGNAL,
   DECISION_SETUP_EXPIRED,
   DECISION_SETUP_INVALIDATED
  };

//+------------------------------------------------------------------+
//| Liquidity Sweep Type                                              |
//+------------------------------------------------------------------+
enum ENUM_LIQUIDITY_EVENT
  {
   LIQ_EVENT_NONE = 0,
   LIQ_EVENT_LONG_SWEEP,
   LIQ_EVENT_SHORT_SWEEP,
   LIQ_EVENT_REJECTION
  };

//+------------------------------------------------------------------+
//| Divergence Classification                                         |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
  {
   DIVERGENCE_NONE = 0,
   DIVERGENCE_REGULAR_BULLISH,
   DIVERGENCE_REGULAR_BEARISH,
   DIVERGENCE_HIDDEN_BULLISH,
   DIVERGENCE_HIDDEN_BEARISH
  };

//+------------------------------------------------------------------+
//| Momentum State                                                    |
//+------------------------------------------------------------------+
enum ENUM_MOMENTUM_STATE
  {
   MOMENTUM_BULLISH = 0,
   MOMENTUM_BEARISH,
   MOMENTUM_WEAK,
   MOMENTUM_EXHAUSTING,
   MOMENTUM_CONFLICTED,
   MOMENTUM_INSUFFICIENT_DATA
  };

//+------------------------------------------------------------------+
//| Feature with Validity                                             |
//+------------------------------------------------------------------+
struct ScoredFeature
  {
   double        value;
   ENUM_FEATURE_VALIDITY validity;
   string        symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime      timestamp;
   string        reason;
   bool          IsValid() const { return validity == FEATURE_VALID; }
  };

//+------------------------------------------------------------------+
//| Volume Profile Features                                            |
//+------------------------------------------------------------------+
struct ProfileFeatures
  {
   bool              valid;
   ENUM_VOLUME_DATA_MODE data_mode;

   double            poc;
   double            vah;
   double            val;

   double            price_location_in_value_area;
   double            profile_concentration;

   datetime          poc_time;
   datetime          bar_time;

   string            symbol;
   ENUM_TIMEFRAMES   timeframe;

   string            reason;
  };

//+------------------------------------------------------------------+
//| Liquidity/Structural Features                                    |
//+------------------------------------------------------------------+
struct LiquidityFeatures
  {
   bool              valid;

   double            equal_high;
   double            equal_low;
   datetime          equal_high_time;
   datetime          equal_low_time;

   double            prev_day_high;
   double            prev_day_low;

   double            prev_week_high;
   double            prev_week_low;

   ENUM_LIQUIDITY_EVENT recent_event;
   datetime            event_time;
   double               event_level;
   datetime            event_expiry;
   bool                event_consumed;

   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   datetime          bar_time;
   string            reason;
   string            snapshot_id;
   string            producer_role;
  };

//+------------------------------------------------------------------+
//| Structure Features                                                |
//+------------------------------------------------------------------+
struct StructureFeatures
  {
   bool              valid;

   ENUM_BIAS_DIRECTION bias;
   string            bias_reason;

   bool              bos_long;
   bool              bos_short;
   bool              choch;

   datetime          bar_time;
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   string            reason;
  };

//+------------------------------------------------------------------+
//| Regime Features                                                   |
//+------------------------------------------------------------------+
struct RegimeFeatures
  {
   bool              valid;
   ENUM_HYBRID_REGIME regime;
   string            regime_reason;

   double            adx;
   double            volatility_ratio;
   double            range_width_atr;
   double            efficiency;

   datetime          bar_time;
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   string            reason;
  };

//+------------------------------------------------------------------+
//| Divergence Features                                               |
//+------------------------------------------------------------------+
struct DivergenceFeatures
  {
   bool              valid;
   ENUM_DIVERGENCE_TYPE divergence;
   datetime            pivot_time;
   datetime            bar_time;
   string              symbol;
   ENUM_TIMEFRAMES    timeframe;
   string             reason;
  };

//+------------------------------------------------------------------+
//| Momentum Features                                                 |
//+------------------------------------------------------------------+
struct MomentumFeatures
  {
   bool              valid;
   ENUM_MOMENTUM_STATE state;
   string            state_reason;

   double            roc;
   double            atr;
   double            body_ratio;
   double            close_location;
   double            momentum_score;

   datetime          bar_time;
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   string            reason;
  };

//+------------------------------------------------------------------+
//| News Features                                                     |
//+------------------------------------------------------------------+
struct NewsFeatures
  {
   bool              valid;
   ENUM_NEWS_STATE   state;
   string            reason;

   datetime          next_event_time;
   string            next_event_currency;
   string            next_event_name;
   int               next_event_impact;

   datetime          bar_time;
   string            symbol;
   string            reason_detail;
  };

//+------------------------------------------------------------------+
//| Complete Feature Context                                          |
//+------------------------------------------------------------------+
struct FeatureContext
  {
   bool              valid;

   string            symbol;

   ENUM_TRADING_STYLE style;

    ENUM_TIMEFRAMES    context_tf;
    ENUM_TIMEFRAMES    structure_tf;
    ENUM_TIMEFRAMES    setup_tf;
    ENUM_TIMEFRAMES    entry_tf;

    MarketSnapshot     context_market;
    MarketSnapshot     structure_market;
    MarketSnapshot     setup_market;
    MarketSnapshot     entry_market;

    FeatureSet         context_features;
    FeatureSet         structure_features;
    FeatureSet         setup_features;
    FeatureSet         entry_features;

   ProfileFeatures    profile;
   LiquidityFeatures  liquidity;
   StructureFeatures  structure;
   RegimeFeatures     regime;
   DivergenceFeatures divergence;
   MomentumFeatures   momentum;
   NewsFeatures       news;

   PortfolioState     portfolio_state;

   datetime           evaluation_time;

   string             reason;
  };

//+------------------------------------------------------------------+
//| Trade Plan                                                        |
//+------------------------------------------------------------------+
struct TradePlan
  {
   bool              valid;
   ENUM_DECISION_STATUS status;

   string            symbol;
   ENUM_TRADING_STYLE style;

   ENUM_SIGNAL_DIRECTION direction;
   double            score_long;
   double            score_short;

   string            setup_id;
   datetime          signal_time;

   double            entry;
   double            stop;
   double            target;
   double            reward_to_risk;

   datetime          expiry_time;
   datetime          invalidation_time;
   bool              consumed;

   string            reason;
    string            rejection_reason;
    string            evidence_summary;

    ProfileFeatures    profile_used;
    LiquidityFeatures  liquidity_used;
    string             liquidity_snapshot_id;
    StructureFeatures  structure_used;
    RegimeFeatures     regime_used;
    DivergenceFeatures divergence_used;
    MomentumFeatures   momentum_used;
    NewsFeatures       news_used;

    ENUM_SETUP_STATE   state;
    datetime           detected_time;
    datetime           last_revalidated;
    bool               structural_invalidated;
   };

//+------------------------------------------------------------------+
//| Gate Results                                                      |
//+------------------------------------------------------------------+
struct GateResults
  {
   bool data_sufficient;
   bool data_fresh;
   bool setup_valid;
   bool setup_not_expired;
   bool regime_compatible;
   bool news_clear;
   bool spread_acceptable;
   bool entry_distance_ok;
   bool stop_valid;
   bool target_valid;
   bool rr_acceptable;
   bool volume_valid;
   bool not_duplicate;
   bool no_conflict;

   string first_failure_reason;
   string details;
  };

//+------------------------------------------------------------------+
//| Hybrid Decision (full diagnostics)                                |
//+------------------------------------------------------------------+
struct HybridDecision
  {
   bool              valid;
   ENUM_DECISION_STATUS status;

   string            symbol;
   ENUM_TRADING_STYLE style;
   ENUM_HYBRID_REGIME regime;
   ENUM_BIAS_DIRECTION bias;

   double            long_score;
   double            short_score;

   FeatureContext    context;

   TradePlan         plan;
   GateResults       gates;

   string            evidence_summary;
   string            main_reason;
   datetime          decision_time;
  };

#endif
