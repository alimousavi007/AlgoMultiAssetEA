//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __ALGOSYSTEM_HYBRID_ENGINE_MQH__
#define __ALGOSYSTEM_HYBRID_ENGINE_MQH__

#include "HybridTypes.mqh"
#include "VolumeProfile.mqh"
#include "LiquidityEngine.mqh"
#include "HybridRegime.mqh"
#include "DivergenceEngine.mqh"
#include "MomentumEngine.mqh"
#include "NewsRiskService.mqh"
#include "BiasEngine.mqh"
#include "Utilities.mqh"
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Hybrid Signal Engine                                              |
//|                                                                  |
//| Single decision point combining Volume Profile, liquidity/       |
//| structure, regime, divergence, momentum, and news.             |
//| Produces a structured HybridDecision with explainable output.   |
//+------------------------------------------------------------------+
class CHybridSignalEngine
  {
private:
   string             m_symbol;
   ENUM_TRADING_STYLE m_style;

    ENUM_TIMEFRAMES    m_context_tf;
    ENUM_TIMEFRAMES    m_structure_tf;
    ENUM_TIMEFRAMES    m_setup_tf;
    ENUM_TIMEFRAMES    m_entry_tf;

   int                m_lookback;

   double             m_tick_size;
   double             m_point;
   bool               m_use_spread_filter;
   double             m_max_spread_points;
   int                m_digits;
   double             m_min_rr;
   double             m_min_score;
   double             m_conflict_threshold;

     int                m_freshness_context_seconds;
     int                m_freshness_structure_seconds;
     int                m_freshness_setup_seconds;
     int                m_freshness_entry_seconds;
     bool               m_freshness_valid;
   datetime           m_last_bar_time;

   CVolumeProfileEngine m_profile_engine;
   CLiquidityStructureEngine m_liquidity_engine;
   CHybridRegimeEngine m_regime_engine;
   CDivergenceEngine m_divergence_engine;
   CMomentumEngine   m_momentum_engine;
   CNewsRiskService  m_news_service;
   CBiasEngine       m_bias_engine;

    string             m_setup_id_counter_symbol;
    int                m_setup_sequence;
    datetime           m_last_setup_bar_time;
    string             m_last_setup_key;

   datetime           m_last_signal_time;
   ENUM_SIGNAL_DIRECTION m_last_signal_direction;
   bool               m_last_signal_consumed;

   ENUM_TRADING_STYLE m_active_style;

public:
                     CHybridSignalEngine()
     {
      m_symbol="";
      m_style=STYLE_DAY_TRADING;
       m_context_tf=PERIOD_H4;
       m_structure_tf=PERIOD_H1;
       m_setup_tf=PERIOD_H1;
       m_entry_tf=PERIOD_M15;
      m_lookback=100;
      m_tick_size=0;
      m_point=0;
      m_use_spread_filter=true;
      m_max_spread_points=0;

      m_digits=0;
      m_min_rr=1.5;
      m_min_score=70.0;
      m_conflict_threshold=15.0;
       m_freshness_context_seconds=300;
       m_freshness_structure_seconds=300;
       m_freshness_setup_seconds=300;
        m_freshness_entry_seconds=60;
        m_freshness_valid=true;
      m_last_bar_time=0;
       m_setup_id_counter_symbol="";
       m_setup_sequence=0;
       m_last_setup_bar_time=0;
       m_last_setup_key="";
      m_last_signal_time=0;
      m_last_signal_direction=SIGNAL_NONE;
      m_last_signal_consumed=false;
      m_active_style=STYLE_DAY_TRADING;
     }

    void              SetParameters(ENUM_TRADING_STYLE style,
                                    ENUM_TIMEFRAMES context_tf,
                                    ENUM_TIMEFRAMES structure_tf,
                                    ENUM_TIMEFRAMES setup_tf,
                                    ENUM_TIMEFRAMES entry_tf,
                                    double min_rr,
                                    double min_score,
                                    double conflict_threshold,
                                    int lookback)
      {
       m_style=style;
       m_context_tf=context_tf;
       m_structure_tf=structure_tf;
       m_setup_tf=setup_tf;
       m_entry_tf=entry_tf;
      m_min_rr=min_rr;
      m_min_score=min_score;
      m_conflict_threshold=conflict_threshold;
      m_lookback=lookback;
      m_active_style=style;
     }

   void              SetVolumeProfileParams(int session_bars,
         int rolling_bars,
         double va_percent)
     {
      m_profile_engine.SetParameters(session_bars, rolling_bars, va_percent);
     }

   void              SetLiquidityParams(int swing_lookback,
                                        int equal_tolerance_points,
                                        int max_level_age_bars,
                                        int sweep_confirm_bars)
     {
      m_liquidity_engine.SetParameters(
         swing_lookback, equal_tolerance_points,
         max_level_age_bars, sweep_confirm_bars);
     }

   void              SetRegimeParams(int adx_period,
                                     double trend_threshold,
                                     double high_vol_ratio,
                                     double low_vol_ratio,
                                     int range_lookback,
                                     int hysteresis_bars)
     {
      m_regime_engine.SetParameters(
         adx_period, trend_threshold,
         high_vol_ratio, low_vol_ratio,
         range_lookback, hysteresis_bars);
     }

   void              SetDivergenceParams(int rsi_period,
                                         int macd_fast,
                                         int macd_slow,
                                         int macd_signal,
                                         double pivot_tolerance_percent,
                                         int max_age_bars)
     {
      m_divergence_engine.SetParameters(
         rsi_period, macd_fast, macd_slow, macd_signal,
         pivot_tolerance_percent, max_age_bars);
     }

   void              SetMomentumParams(int atr_period,
                                       int roc_period,
                                       int lookback)
     {
      m_momentum_engine.SetParameters(atr_period, roc_period, lookback);
     }

   void              SetNewsParams(int blackout_before,
                                   int blackout_after,
                                   int cooldown,
                                   int impact_threshold,
                                   bool prevent_entries,
                                   bool close_on_news)
     {
      m_news_service.SetParameters(
         blackout_before, blackout_after,
         cooldown, impact_threshold,
         prevent_entries, close_on_news);
     }

   void              SetNewsEnabled(bool enabled)
     {
      m_news_service.SetEnabled(enabled);
     }

   void              SetSpreadFilterParams(bool use_filter, double max_spread_points)
     {
      m_use_spread_filter=use_filter;
      m_max_spread_points=max_spread_points;
     }


   void              SetBiasParams(int swings_required, int lookback)
     {
      m_bias_engine.SetParameters(swings_required, lookback);
     }

   void              SetMinScore(double min_score) { m_min_score = min_score; }
   void              SetConflictThreshold(double threshold) { m_conflict_threshold = threshold; }
    void              SetFreshnessParams(int context_seconds,
                                         int structure_seconds,
                                         int setup_seconds,
                                         int entry_seconds)
      {
       m_freshness_valid = (context_seconds>0 && structure_seconds>0 &&
                            setup_seconds>0 && entry_seconds>0);
       if(m_freshness_valid)
         {
          m_freshness_context_seconds=context_seconds;
          m_freshness_structure_seconds=structure_seconds;
          m_freshness_setup_seconds=setup_seconds;
          m_freshness_entry_seconds=entry_seconds;
         }
      }
    bool              IsFreshnessValid() const { return m_freshness_valid; }

   void              SetLookback(int lookback) { m_lookback = lookback; }

    bool              Initialize(const string symbol,
                                 ENUM_TRADING_STYLE style,
                                 ENUM_TIMEFRAMES context_tf,
                                 ENUM_TIMEFRAMES structure_tf,
                                 ENUM_TIMEFRAMES setup_tf,
                                 ENUM_TIMEFRAMES entry_tf)
      {
       m_symbol=symbol;
       m_style=style;
       m_context_tf=context_tf;
       m_structure_tf=structure_tf;
       m_setup_tf=setup_tf;
       m_entry_tf=entry_tf;
      m_active_style=style;
       m_setup_id_counter_symbol=symbol;
       m_setup_sequence=0;
       m_last_setup_bar_time=0;
       m_last_setup_key="";

      ResetLastError();
      m_tick_size=SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(m_tick_size<=0)
         m_tick_size=SymbolInfoDouble(symbol, SYMBOL_POINT);
      SymbolInfoDouble(symbol, SYMBOL_POINT, m_point);
      long digits=0;
      SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits);
      m_digits=(int)digits;

      if(m_tick_size<=0 || m_point<=0 || m_digits<=0)
         return false;

      if(!m_profile_engine.Initialize(symbol, setup_tf))
         return false;

      if(!m_liquidity_engine.Initialize(symbol, structure_tf))
         return false;

      if(!m_regime_engine.Initialize(symbol, context_tf))
         return false;

      if(!m_divergence_engine.Initialize(symbol, entry_tf))
         return false;

      if(!m_momentum_engine.Initialize(symbol, entry_tf))
         return false;

      if(!m_bias_engine.Initialize(symbol, structure_tf))
         return false;

      if(!m_news_service.Initialize())
         return false;

      m_initialized=true;
      m_last_bar_time=0;

      return true;
     }

   void              SetNewsProvider(INewsProvider* provider, bool take_ownership=false)
     {
      m_news_service.SetProvider(provider, take_ownership);
     }

   bool              IsInitialized() const
     {
      return m_initialized;
     }

   double            GetTickSize() const { return m_tick_size; }
   double            GetPoint() const { return m_point; }
   int               GetDigits() const { return m_digits; }

private:
   datetime          GetCurrentTicket()
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string ticket_str=IntegerToString(dt.year)+
                        IntegerToString(dt.mon)+
                        IntegerToString(dt.day)+
                        IntegerToString(dt.hour)+
                        IntegerToString(dt.min)+
                        IntegerToString(dt.sec);
      return (datetime)StringToInteger(ticket_str);
     }

public:
    string            GenerateSetupID(datetime bar_time,
                                       ENUM_SIGNAL_DIRECTION direction,
                                       double entry_price)
      {
       m_setup_sequence++;
       string entry_key=DoubleToString(NormalizeDouble(entry_price, m_digits), m_digits);
       string key=IntegerToString((long)bar_time)+"_"+IntegerToString((int)direction)+"_"+entry_key;
       if(m_last_setup_key==key && m_last_setup_bar_time==bar_time)
         {
          return m_setup_id_counter_symbol + "_" + key;
         }
       m_last_setup_key=key;
       m_last_setup_bar_time=bar_time;
       return m_setup_id_counter_symbol + "_" + key + "_" + IntegerToString(m_setup_sequence);
      }

   bool              LoadMarketSnapshot(const string symbol,
                                        ENUM_TIMEFRAMES tf,
                                        MarketSnapshot& snapshot,
                                        string& reason)
     {
      MqlRates rates[];
      ResetLastError();
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick))
        {
         reason="Could not get tick for "+symbol;
         return false;
        }

      ArrayFree(rates);
      ResetLastError();
      int copied=CopyRates(symbol, tf, 0, 3, rates);
      if(copied<=0 || ArraySize(rates)<2)
        {
         reason="Insufficient bars for "+symbol+" on "+EnumToString(tf);
         return false;
        }

      snapshot.symbol=symbol;
      snapshot.timeframe=tf;
      snapshot.bid=tick.bid;
      snapshot.ask=tick.ask;
      snapshot.spread_points=tick.ask - tick.bid;
      snapshot.current_time=tick.time;
      snapshot.closed_bar_time=rates[0].time;
      snapshot.current_bar.time=rates[0].time;
      snapshot.current_bar.open=rates[0].open;
      snapshot.current_bar.high=rates[0].high;
      snapshot.current_bar.low=rates[0].low;
      snapshot.current_bar.close=rates[0].close;
      snapshot.current_bar.tick_volume=rates[0].tick_volume;
      snapshot.current_bar.real_volume=rates[0].real_volume;
      snapshot.current_bar.spread=rates[0].spread;

      snapshot.closed_bar.time=rates[1].time;
      snapshot.closed_bar.open=rates[1].open;
      snapshot.closed_bar.high=rates[1].high;
      snapshot.closed_bar.low=rates[1].low;
      snapshot.closed_bar.close=rates[1].close;
      snapshot.closed_bar.tick_volume=rates[1].tick_volume;
      snapshot.closed_bar.real_volume=rates[1].real_volume;
      snapshot.closed_bar.spread = (int)rates[1].spread;

      SymbolProperties props;
      ResetLastError();
      props.symbol=symbol;
      props.digits=m_digits;
      props.point=m_point;
      props.tick_size=m_tick_size;
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE, props.tick_value);
      props.tick_value_profit=props.tick_value;
      props.tick_value_loss=props.tick_value;
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN, props.volume_min);
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX, props.volume_max);
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP, props.volume_step);
      long stops_level=0, freeze_level=0;
      SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level);
      SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);
      props.stops_level=(int)stops_level;
      props.freeze_level=(int)freeze_level;
      props.trade_allowed=true;
      long selected_flag=0;
      SymbolInfoInteger(symbol, SYMBOL_SELECT, selected_flag);
      props.selected = (selected_flag != 0);
      snapshot.properties=props;
      snapshot.valid=true;

      reason="OK";
      return true;
     }

public:
    FeatureContext    BuildFeatureContext(const MarketSnapshot& context_market,
                                          const MarketSnapshot& structure_market,
                                          const MarketSnapshot& setup_market,
                                          const MarketSnapshot& entry_market,
                                          const FeatureSet& context_features,
                                          const FeatureSet& structure_features,
                                          const FeatureSet& setup_features,
                                          const FeatureSet& entry_features,
                                          const PortfolioState& portfolio_state,
                                          bool& ok)
     {
      FeatureContext ctx;
      ctx.valid=false;
      ctx.symbol=m_symbol;
      ctx.style=m_active_style;
       ctx.context_tf=m_context_tf;
       ctx.structure_tf=m_structure_tf;
       ctx.setup_tf=m_setup_tf;
       ctx.entry_tf=m_entry_tf;
      ctx.evaluation_time=TimeCurrent();
      ctx.reason="";
      ok=false;

      if(!m_initialized)
        {
         ctx.reason="Engine not initialized";
         return ctx;
        }

       ctx.context_market=context_market;
       ctx.structure_market=structure_market;
       ctx.setup_market=setup_market;
       ctx.entry_market=entry_market;
       ctx.context_features=context_features;
       ctx.structure_features=structure_features;
       ctx.setup_features=setup_features;
       ctx.entry_features=entry_features;
      ctx.portfolio_state=portfolio_state;

       if(!context_market.valid || !structure_market.valid || !setup_market.valid || !entry_market.valid)
         {
          ctx.reason="Invalid market snapshot";
          return ctx;
         }
       if(!context_features.valid || !structure_features.valid || !setup_features.valid || !entry_features.valid)
         {
          ctx.reason="Required feature set invalid";
          return ctx;
         }

       if(context_features.symbol!=m_symbol ||
          structure_features.symbol!=m_symbol ||
          setup_features.symbol!=m_symbol ||
          entry_features.symbol!=m_symbol ||
          context_features.timeframe!=m_context_tf ||
          structure_features.timeframe!=m_structure_tf ||
          setup_features.timeframe!=m_setup_tf ||
          entry_features.timeframe!=m_entry_tf ||
          context_features.bar_time!=context_market.closed_bar_time ||
          structure_features.bar_time!=structure_market.closed_bar_time ||
          setup_features.bar_time!=setup_market.closed_bar_time ||
          entry_features.bar_time!=entry_market.closed_bar_time)
         {
          ctx.reason="Feature set symbol/timeframe/bar mismatch";
          return ctx;
         }

      MqlRates context_rates[];
      if(!LoadRates(m_symbol, m_context_tf, m_lookback+10, context_rates))
        {
         ctx.reason="Could not load signal rates";
         return ctx;
        }

      if(setup_market.valid) ctx.profile=m_profile_engine.Calculate(setup_market, true); else { ctx.profile.valid=false; ctx.profile.reason="SETUP_MARKET_INVALID"; }

      if(structure_market.valid) ctx.liquidity=m_liquidity_engine.Calculate(structure_market, ctx); else { ctx.liquidity.valid=false; ctx.liquidity.reason="STRUCTURE_MARKET_INVALID"; }

      if(context_market.valid && ctx.context_features.valid) ctx.regime=m_regime_engine.Calculate(context_market, ctx.context_features); else { ctx.regime.valid=false; ctx.regime.reason="CONTEXT_INVALID"; }

      MqlRates divergence_rates[];
      if(ArrayResize(divergence_rates, ArraySize(context_rates)) > 0)
         ArrayCopy(divergence_rates, context_rates);
      if(entry_market.valid) { MqlRates divergence_rates2[]; if(ArrayResize(divergence_rates2, ArraySize(context_rates))>0) ArrayCopy(divergence_rates2, context_rates); ctx.divergence=m_divergence_engine.Calculate(entry_market, divergence_rates2); } else { ctx.divergence.valid=false; ctx.divergence.reason="ENTRY_MARKET_INVALID"; }

      if(entry_market.valid) ctx.momentum=m_momentum_engine.Calculate(entry_market); else { ctx.momentum.valid=false; ctx.momentum.reason="ENTRY_MARKET_INVALID"; }

      // Economic-calendar timestamps use trade-server time; a closed bar's
      // timestamp can be behind the actual news window.
      ctx.news=m_news_service.Evaluate(m_symbol, TimeTradeServer(), portfolio_state); // gate only

      ctx.structure=m_bias_engine.Calculate(ctx, structure_market, ctx.profile);

      ctx.valid=true;
      ctx.reason="OK";
      ok=true;

      return ctx;
     }

private:
   bool              LoadRates(string symbol,
                               ENUM_TIMEFRAMES timeframe,
                               int count,
                               MqlRates& rates[])
     {
      ArrayFree(rates);
      ResetLastError();
      int copied=CopyRates(symbol, timeframe, 0, count, rates);
      if(copied <= 0)
         return false;

      return true;
     }

   bool              CheckHardGates(const FeatureContext& ctx,
                                    GateResults& gates,
                                    string& failure_reason) const
     {
      gates.data_sufficient=true;
      gates.data_fresh=true;
      gates.setup_valid=true;
      gates.setup_not_expired=true;
      gates.regime_compatible=true;
      gates.news_clear=true;
      gates.spread_acceptable=true;
      gates.entry_distance_ok=true;
      gates.stop_valid=true;
      gates.target_valid=true;
      gates.rr_acceptable=true;
      gates.volume_valid=true;
      gates.not_duplicate=true;
      gates.no_conflict=true;
      gates.first_failure_reason="";
      gates.details="";

      string reasons="";

       if(!ctx.context_market.valid ||
          !ctx.structure_market.valid ||
          !ctx.setup_market.valid ||
          !ctx.entry_market.valid)
        {
         gates.data_sufficient=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="INVALID_MARKET_DATA";
         reasons += " invalid_market_data";
        }

      if(!ctx.context_market.valid)
        {
         gates.data_sufficient=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="SIGNAL_MARKET_INVALID";
         reasons += " context_market_invalid";
        }

       if(!m_freshness_valid)
         {
          gates.data_fresh=false;
          if(gates.first_failure_reason=="")
             gates.first_failure_reason="FRESHNESS_CONFIG_INVALID";
          reasons += " freshness_config_invalid";
         }

       // Context role freshness (closed bar)
       if(m_freshness_valid &&
          ctx.context_market.valid &&
          (TimeCurrent() - ctx.context_market.closed_bar_time) >
          (datetime)m_freshness_context_seconds)
         {
          gates.data_fresh=false;
          if(gates.first_failure_reason=="")
             gates.first_failure_reason="STALE_CONTEXT_DATA";
          reasons += " stale_context";
         }

       // Structure role freshness (closed bar)
       if(m_freshness_valid &&
          ctx.structure_market.valid &&
          (TimeCurrent() - ctx.structure_market.closed_bar_time) >
          (datetime)m_freshness_structure_seconds)
         {
          gates.data_fresh=false;
          if(gates.first_failure_reason=="")
             gates.first_failure_reason="STALE_STRUCTURE_DATA";
          reasons += " stale_structure";
         }

       // Setup role freshness (closed bar)
       if(m_freshness_valid &&
          ctx.setup_market.valid &&
          (TimeCurrent() - ctx.setup_market.closed_bar_time) >
          (datetime)m_freshness_setup_seconds)
         {
          gates.data_fresh=false;
          if(gates.first_failure_reason=="")
             gates.first_failure_reason="STALE_SETUP_DATA";
          reasons += " stale_setup";
         }

       // Entry role freshness
       if(m_freshness_valid && ctx.entry_market.valid)
         {
          datetime entry_source_time = ctx.entry_market.closed_bar_time;
          // Scalp uses live tick timestamp for entry
          if(m_active_style == STYLE_SCALPING)
             entry_source_time = ctx.entry_market.current_time;
          if((TimeCurrent() - entry_source_time) >
             (datetime)m_freshness_entry_seconds)
            {
             gates.data_fresh=false;
             if(gates.first_failure_reason=="")
                gates.first_failure_reason="STALE_ENTRY_DATA";
             reasons += " stale_entry";
            }
         }

       // Legacy single stale check removed; per-role checks above.

      if(ctx.profile.valid==false)
        {
         gates.setup_valid=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="PROFILE_UNAVAILABLE";
         reasons += " profile_unavailable";
        }

      if(!ctx.regime.valid ||
         ctx.regime.regime==HYBRID_REGIME_INSUFFICIENT_DATA)
        {
         gates.regime_compatible=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="REGIME_INSUFFICIENT_DATA";
         reasons += " regime_insufficient";
        }

      if(m_news_service.ShouldBlockEntry(ctx.news, m_symbol))
        {
         gates.news_clear=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="NEWS_BLOCKED";
         reasons += " news_blocked";
        }

      if(!ctx.context_market.properties.trade_allowed)
        {
         gates.setup_valid=false;
         if(gates.first_failure_reason=="")
            gates.first_failure_reason="TRADE_NOT_ALLOWED";
         reasons += " trade_not_allowed";
        }

      if(m_use_spread_filter && ctx.context_market.spread_points > 0)
        {
         double spread_points = ctx.context_market.spread_points;
         double max_spread=0;

         if(m_max_spread_points>0)
            max_spread=m_max_spread_points;
         else
            if(m_style==STYLE_SCALPING)
               max_spread=20.0;
            else
               if(m_style==STYLE_DAY_TRADING)
                  max_spread=50.0;
               else
                  max_spread=100.0;

         if(spread_points > max_spread)
           {
            gates.spread_acceptable=false;
            if(gates.first_failure_reason=="")
               gates.first_failure_reason="SPREAD_TOO_HIGH";
            reasons += " spread="+DoubleToString(spread_points,1);
           }
        }


      gates.details=reasons;
      gates.data_sufficient = gates.data_sufficient && gates.data_fresh;

      return gates.data_sufficient &&
             gates.setup_valid &&
             gates.regime_compatible &&
             gates.news_clear &&
             gates.spread_acceptable;
     }

   double            CalculateBiasScore(const StructureFeatures& structure,
                                        const FeatureContext& ctx) const
     {
      if(!structure.valid)
         return 0.0;

      switch(structure.bias)
        {
         case BIAS_BULLISH:
            return 1.0;
         case BIAS_BEARISH:
            return -1.0;
         case BIAS_NEUTRAL:
            return 0.0;
         case BIAS_CONFLICTED:
            return 0.0;
         case BIAS_INSUFFICIENT_DATA:
         default:
            return 0.0;
        }
     }

   double            CalculateLiquidityScore(const LiquidityFeatures& liquidity,
         ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!liquidity.valid)
         return 0.0;

      if(direction==SIGNAL_LONG)
        {
         if(liquidity.recent_event==LIQ_EVENT_LONG_SWEEP &&
            !liquidity.event_consumed)
            return 1.0;
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            if(liquidity.recent_event==LIQ_EVENT_SHORT_SWEEP &&
               !liquidity.event_consumed)
               return 1.0;
           }

      return 0.0;
     }

   double            CalculateProfileScore(const ProfileFeatures& profile,
                                           ENUM_SIGNAL_DIRECTION direction,
                                           double price) const
     {
      if(!profile.valid || profile.poc<=0)
         return 0.0;

      double score=0.0;

      if(direction==SIGNAL_LONG)
        {
         if(price > profile.vah)
            score=1.0;
         else
            if(price > profile.poc && price <= profile.vah)
               score=0.7;
            else
               if(price >= profile.val && price <= profile.vah)
                  score=0.3;
               else
                  score=-0.2;
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            if(price < profile.val)
               score=1.0;
            else
               if(price < profile.poc && price >= profile.val)
                  score=0.7;
               else
                  if(price >= profile.val && price <= profile.vah)
                     score=0.3;
                  else
                     score=-0.2;
           }

      return score;
     }

   double            CalculateRegimeScore(const RegimeFeatures& regime,
                                          ENUM_TRADING_STYLE style) const
     {
      if(!regime.valid)
         return 0.0;

      switch(regime.regime)
        {
         case HYBRID_REGIME_TRENDING:
            return style==STYLE_SWING_TRADING ? 1.0 : 0.8;
         case HYBRID_REGIME_RANGING:
            return style==STYLE_SCALPING ? 0.7 : 0.5;
         case HYBRID_REGIME_VOLATILITY_EXPANSION:
            return 0.6;
         case HYBRID_REGIME_COMPRESSION:
            return style==STYLE_SWING_TRADING ? 0.3 : 0.2;
         case HYBRID_REGIME_TRANSITION:
            return 0.1;
         case HYBRID_REGIME_INSUFFICIENT_DATA:
         default:
            return 0.0;
        }
     }

   double            CalculateMomentumScore(const MomentumFeatures& momentum,
         ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!momentum.valid)
         return 0.0;

      if(direction==SIGNAL_LONG)
        {
         switch(momentum.state)
           {
            case MOMENTUM_BULLISH:
               return 0.9;
            case MOMENTUM_EXHAUSTING:
               return 0.3;
            case MOMENTUM_WEAK:
               return 0.2;
            case MOMENTUM_CONFLICTED:
               return 0.0;
            case MOMENTUM_BEARISH:
               return -0.5;
            default:
               return 0.0;
           }
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            switch(momentum.state)
              {
               case MOMENTUM_BEARISH:
                  return 0.9;
               case MOMENTUM_EXHAUSTING:
                  return 0.3;
               case MOMENTUM_WEAK:
                  return 0.2;
               case MOMENTUM_CONFLICTED:
                  return 0.0;
               case MOMENTUM_BULLISH:
                  return -0.5;
               default:
                  return 0.0;
              }
           }

      return 0.0;
     }

   double            CalculateDivergenceScore(const DivergenceFeatures& divergence,
         ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!divergence.valid || divergence.divergence==DIVERGENCE_NONE)
         return 0.0;

      if(direction==SIGNAL_LONG)
        {
         if(divergence.divergence==DIVERGENCE_REGULAR_BULLISH ||
            divergence.divergence==DIVERGENCE_HIDDEN_BULLISH)
            return 0.8;
         if(divergence.divergence==DIVERGENCE_REGULAR_BEARISH ||
            divergence.divergence==DIVERGENCE_HIDDEN_BEARISH)
            return -0.5;
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            if(divergence.divergence==DIVERGENCE_REGULAR_BEARISH ||
               divergence.divergence==DIVERGENCE_HIDDEN_BEARISH)
               return 0.8;
            if(divergence.divergence==DIVERGENCE_REGULAR_BULLISH ||
               divergence.divergence==DIVERGENCE_HIDDEN_BULLISH)
               return -0.5;
           }

      return 0.0;
     }

   double            CalculateEntryScore(double entry_price,
                                         double stop,
                                         double target,
                                         ENUM_SIGNAL_DIRECTION direction,
                                         const FeatureContext& ctx) const
     {
      if(!ctx.context_market.valid ||
         !ctx.entry_market.valid ||
         !ctx.entry_features.valid)
         return 0.0;

      double bid=ctx.context_market.bid;
      double ask=ctx.context_market.ask;
      // Entry-TF EMA alignment is a soft confirmation, not a hard veto.
      double alignment=0.5;
      if(direction==SIGNAL_LONG &&
         ctx.entry_features.ema_fast>ctx.entry_features.ema_slow)
         alignment=1.0;
      else
         if(direction==SIGNAL_SHORT &&
            ctx.entry_features.ema_fast<ctx.entry_features.ema_slow)
            alignment=1.0;
      if(direction==SIGNAL_LONG)
        {
         double distance=MathAbs(entry_price - ask);
         double max_distance=getEntryTolerance(m_style);

         if(distance <= max_distance)
            return alignment;
         else
            if(distance <= max_distance * 2)
               return alignment * 0.5;
            else
               return 0.0;
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            double distance=MathAbs(entry_price - bid);
            double max_distance=getEntryTolerance(m_style);

            if(distance <= max_distance)
               return alignment;
            else
               if(distance <= max_distance * 2)
                  return alignment * 0.5;
               else
                  return 0.0;
           }

      return 0.0;
     }

   double            getEntryTolerance(ENUM_TRADING_STYLE style) const
     {
      switch(style)
        {
         case STYLE_SCALPING:
            return m_point * 5.0;
         case STYLE_DAY_TRADING:
            return m_point * 20.0;
         case STYLE_SWING_TRADING:
            return m_point * 50.0;
         default:
            return m_point * 10.0;
        }
     }

public:
   HybridDecision    Evaluate(const string symbol,
                              const FeatureContext& ctx,
                              const MarketSnapshot& context_market,
                              bool& ok)
     {
      HybridDecision decision;
      decision.valid=false;
      decision.status=DECISION_NO_TRADE;
      decision.symbol=symbol;
      decision.style=m_active_style;
      decision.regime=HYBRID_REGIME_INSUFFICIENT_DATA;
      decision.bias=BIAS_INSUFFICIENT_DATA;
      decision.long_score=0;
      decision.short_score=0;
      decision.context=ctx;
      decision.plan.valid=false;
      decision.gates.data_sufficient=true;
      decision.gates.data_fresh=true;
      decision.evidence_summary="";
      decision.main_reason="";
      decision.decision_time=TimeCurrent();
      ok=false;

      if(!ctx.valid)
        {
         decision.status=DECISION_DATA_UNAVAILABLE;
         decision.main_reason=ctx.reason;
         decision.valid=true;
         ok=true;
         return decision;
        }

      GateResults gates;
      string gate_failure="";

      if(!CheckHardGates(ctx, gates, gate_failure))
        {
         decision.status=DECISION_DATA_UNAVAILABLE;
         decision.gates=gates;
         decision.main_reason=gates.first_failure_reason;
         decision.evidence_summary=gates.details;
         decision.valid=true;
         ok=true;
         return decision;
        }

       if(!ctx.regime.valid)
         {
          decision.status=DECISION_NO_TRADE;
          decision.main_reason="REGIME_INVALID";
          decision.valid=true;
          ok=true;
          return decision;
         }
       if(!ctx.structure.valid || !ctx.profile.valid)
         {
          decision.status=DECISION_NO_TRADE;
          decision.main_reason="SETUP_STRUCTURE_INVALID";
          decision.valid=true;
          ok=true;
          return decision;
         }
       if(!ctx.liquidity.valid)
         {
          decision.status=DECISION_NO_TRADE;
          decision.main_reason="LIQUIDITY_INVALID";
          decision.valid=true;
          ok=true;
          return decision;
         }
       double bias_score=CalculateBiasScore(ctx.structure, ctx);

      double entry_price=ctx.context_market.closed_bar.close;

      double profile_long_score=CalculateProfileScore(ctx.profile, SIGNAL_LONG, entry_price);
      double profile_short_score=CalculateProfileScore(ctx.profile, SIGNAL_SHORT, entry_price);

      double liquidity_long_score=CalculateLiquidityScore(ctx.liquidity, SIGNAL_LONG);
      double liquidity_short_score=CalculateLiquidityScore(ctx.liquidity, SIGNAL_SHORT);

      double regime_score=CalculateRegimeScore(ctx.regime, m_active_style);

      double momentum_long_score=CalculateMomentumScore(ctx.momentum, SIGNAL_LONG);
      double momentum_short_score=CalculateMomentumScore(ctx.momentum, SIGNAL_SHORT);

      double divergence_long_score=CalculateDivergenceScore(ctx.divergence, SIGNAL_LONG);
      double divergence_short_score=CalculateDivergenceScore(ctx.divergence, SIGNAL_SHORT);

      if(!ctx.entry_market.valid || !ctx.entry_features.valid)
        {
         decision.status=DECISION_NO_TRADE;
         decision.main_reason="ENTRY_INVALID";
         decision.valid=true;
         ok=true;
         return decision;
        }
      if(m_active_style == STYLE_SCALPING)
        {
         if(ctx.entry_market.current_time <= 0)
           {
            decision.status=DECISION_NO_TRADE;
            decision.main_reason="ENTRY_TICK_INVALID";
            decision.valid=true;
            ok=true;
            return decision;
           }
        }
      double entry_short_score=CalculateEntryScore(entry_price, 0, 0, SIGNAL_SHORT, ctx);

      double bias_weight=0.20;
      double liquidity_weight=0.20;
      double profile_weight=0.15;
      double regime_weight=0.10;
      double momentum_weight=0.15;
      double divergence_weight=0.10;
      double entry_weight=0.10;

      double long_score =
         (bias_score > 0 ? bias_score * bias_weight : 0) +
         (liquidity_long_score * liquidity_weight) +
         (profile_long_score * profile_weight) +
         (regime_score * regime_weight) +
         (momentum_long_score * momentum_weight) +
         (divergence_long_score * divergence_weight) +
         (entry_long_score * entry_weight);

      double short_score =
         (bias_score < 0 ? -bias_score * bias_weight : 0) +
         (liquidity_short_score * liquidity_weight) +
         (profile_short_score * profile_weight) +
         (regime_score * regime_weight) +
         (momentum_short_score * momentum_weight) +
         (divergence_short_score * divergence_weight) +
         (entry_short_score * entry_weight);

      long_score = long_score * 100.0;
      short_score = short_score * 100.0;

      decision.regime=ctx.regime.regime;
      decision.bias=ctx.structure.bias;
      decision.long_score=long_score;
      decision.short_score=short_score;
      decision.evidence_summary=
         "bias="+DoubleToString(bias_score,2)+
         " profile_L="+DoubleToString(profile_long_score,2)+
         " profile_S="+DoubleToString(profile_short_score,2)+
         " liq_L="+DoubleToString(liquidity_long_score,2)+
         " liq_S="+DoubleToString(liquidity_short_score,2)+
         " reg="+DoubleToString(regime_score,2)+
         " mom_L="+DoubleToString(momentum_long_score,2)+
         " mom_S="+DoubleToString(momentum_short_score,2)+
         " div_L="+DoubleToString(divergence_long_score,2)+
         " div_S="+DoubleToString(divergence_short_score,2)+
         " entry_L="+DoubleToString(entry_long_score,2)+
         " entry_S="+DoubleToString(entry_short_score,2);

      if(m_news_service.ShouldBlockEntry(ctx.news, symbol) ||
         !gates.news_clear)
        {
         decision.status=DECISION_NEWS_BLOCKED;
         decision.gates=gates;
         decision.main_reason=gates.first_failure_reason;
         decision.valid=true;
         ok=true;
         return decision;
        }

      bool is_duplicate =
         (m_last_signal_direction != SIGNAL_NONE) &&
         (m_last_signal_time == ctx.context_market.closed_bar_time) &&
         (m_last_signal_consumed);

       if(plan.consumed)
         {
          decision.status=DECISION_NO_TRADE;
          decision.gates=gates;
          decision.main_reason="DUPLICATE_SIGNAL";
          decision.evidence_summary += " duplicate_signal_detected";
          decision.valid=true;
          ok=true;
          return decision;
         }

      ENUM_SIGNAL_DIRECTION selected_direction=SIGNAL_NONE;
      double selected_score=0;

      double score_diff=long_score - short_score;

      if(long_score >= m_min_score &&
         long_score >= short_score + m_conflict_threshold)
        {
         selected_direction=SIGNAL_LONG;
         selected_score=long_score;
        }
      else
         if(short_score >= m_min_score &&
            short_score >= long_score + m_conflict_threshold)
           {
            selected_direction=SIGNAL_SHORT;
            selected_score=short_score;
           }
         else
            if(MathAbs(score_diff) < m_conflict_threshold)
              {
               decision.status=DECISION_CONFLICTED_SIGNAL;
               decision.gates=gates;
               decision.main_reason="LONG_SHORT_CONFLICT";
               decision.evidence_summary +=
                  " score_diff="+DoubleToString(score_diff,1)+
                  " below threshold="+DoubleToString(m_conflict_threshold,1);
               decision.valid=true;
               ok=true;
               return decision;
              }
            else
               if(long_score < m_min_score && short_score < m_min_score)
                 {
                  decision.status=DECISION_NO_TRADE;
                  decision.gates=gates;
                  decision.main_reason="SCORE_BELOW_THRESHOLD";
                  decision.evidence_summary +=
                     " long="+DoubleToString(long_score,1)+
                     " short="+DoubleToString(short_score,1)+
                     " min="+DoubleToString(m_min_score,1);
                  decision.valid=true;
                  ok=true;
                  return decision;
                 }

       if(selected_direction==SIGNAL_NONE)
         {
          decision.status=DECISION_NO_TRADE;
          decision.gates=gates;
          decision.main_reason="NO_VALID_DIRECTION";
          decision.valid=true;
          ok=true;
          return decision;
         }

       if(!ctx.entry_market.valid)
         {
          decision.status=DECISION_NO_TRADE;
          decision.gates=gates;
          decision.main_reason="ENTRY_INVALID";
          decision.valid=true;
          ok=true;
          return decision;
         }
       if(m_active_style == STYLE_SCALPING && ctx.entry_market.current_time <= 0)
         {
          decision.status=DECISION_NO_TRADE;
          decision.gates=gates;
          decision.main_reason="ENTRY_TICK_INVALID";
          decision.valid=true;
          ok=true;
          return decision;
         }

      double stop=0;
      double target=0;
      double rr=0;

      if(!BuildTradePlan(selected_direction,
                         ctx,
                         entry_price,
                         stop,
                         target,
                         rr,
                         gate_failure))
        {
         decision.status=DECISION_NO_TRADE;
         decision.gates=gates;
         decision.main_reason=gate_failure;
         decision.evidence_summary += " tradeplan_failed="+gate_failure;
         decision.valid=true;
         ok=true;
         return decision;
        }

      if(rr < m_min_rr)
        {
         decision.status=DECISION_NO_TRADE;
         decision.gates=gates;
         decision.main_reason="RR_BELOW_MINIMUM";
         decision.evidence_summary +=
            " rr="+DoubleToString(rr,2)+
            " min_rr="+DoubleToString(m_min_rr,2);
         decision.valid=true;
         ok=true;
         return decision;
        }

      if(!ValidateSLTP(stop, target, entry_price, selected_direction, gate_failure))
        {
         decision.status=DECISION_NO_TRADE;
         decision.gates=gates;
         decision.main_reason=gate_failure;
         decision.evidence_summary += " sltp_invalid="+gate_failure;
         decision.valid=true;
         ok=true;
         return decision;
        }

       TradePlan plan;
       plan.valid=true;
       plan.status = (selected_direction==SIGNAL_LONG ?
                      DECISION_BUY_CANDIDATE : DECISION_SELL_CANDIDATE);
       plan.symbol=symbol;
       plan.style=m_active_style;
       plan.direction=selected_direction;
       plan.score_long=long_score;
       plan.score_short=short_score;
       plan.setup_id=GenerateSetupID(ctx.setup_market.closed_bar_time, selected_direction, entry_price);
       plan.signal_time=ctx.setup_market.closed_bar_time;
       plan.entry=entry_price;
       plan.stop=stop;
       plan.target=target;
       plan.reward_to_risk=rr;
       plan.expiry_time=GetSetupExpiry(ctx.setup_market.closed_bar_time);
       plan.invalidation_time=GetSetupInvalidation(ctx.setup_market.closed_bar_time);
       plan.consumed=false;
       plan.reason="OK";
       plan.rejection_reason="";
       plan.evidence_summary=decision.evidence_summary;
       plan.profile_used=ctx.profile;
       plan.liquidity_used=ctx.liquidity;
       plan.structure_used=ctx.structure;
       plan.regime_used=ctx.regime;
       plan.divergence_used=ctx.divergence;
       plan.momentum_used=ctx.momentum;
       plan.news_used=ctx.news;
       plan.state=SETUP_STATE_DETECTED;
       plan.detected_time=TimeCurrent();
       plan.last_revalidated=TimeCurrent();
       plan.structural_invalidated=false;
       plan.liquidity_used=ctx.liquidity;
       plan.state=SETUP_STATE_DETECTED;
       plan.detected_time=TimeCurrent();
       plan.last_revalidated=TimeCurrent();
       plan.structural_invalidated=false;

      decision.plan=plan;
      decision.gates=gates;
      decision.status=plan.status;
      decision.main_reason="OK";
      decision.valid=true;
      ok=true;

      m_last_signal_direction=selected_direction;
      m_last_signal_time=ctx.context_market.closed_bar_time;
      m_last_signal_consumed=false;

      return decision;
     }

private:
   datetime          GetSetupExpiry(datetime bar_time) const
     {
      switch(m_active_style)
        {
         case STYLE_SCALPING:
            return bar_time + 15 * 60;
         case STYLE_DAY_TRADING:
            return bar_time + 4 * 3600;
         case STYLE_SWING_TRADING:
            return bar_time + 24 * 3600;
         default:
            return bar_time + 3600;
        }
     }

   datetime          GetSetupInvalidation(datetime bar_time) const
     {
      switch(m_active_style)
        {
         case STYLE_SCALPING:
            return bar_time + 30 * 60;
         case STYLE_DAY_TRADING:
            return bar_time + 8 * 3600;
         case STYLE_SWING_TRADING:
            return bar_time + 48 * 3600;
         default:
            return bar_time + 4 * 3600;
        }
     }

   double            GetStopBuffer(ENUM_TRADING_STYLE style) const
     {
      switch(style)
        {
         case STYLE_SCALPING:
            return 1.0;
         case STYLE_DAY_TRADING:
            return 1.5;
         case STYLE_SWING_TRADING:
            return 2.0;
         default:
            return 1.0;
        }
     }

   double            GetTargetBuffer(ENUM_TRADING_STYLE style) const
     {
      switch(style)
        {
         case STYLE_SCALPING:
            return 1.0;
         case STYLE_DAY_TRADING:
            return 2.0;
         case STYLE_SWING_TRADING:
            return 3.0;
         default:
            return 1.0;
        }
     }

   bool              BuildTradePlan(ENUM_SIGNAL_DIRECTION direction,
                                    const FeatureContext& ctx,
                                    double entry,
                                    double& stop,
                                    double& target,
                                    double& rr,
                                    string& reason)
     {
      stop=0;
      target=0;
      rr=0;
      reason="";

      if(entry<=0.0 || !MathIsValidNumber(entry))
        {
         reason="Invalid entry price";
         return false;
        }

      double buffer_atr = 0.0;
      if(ctx.momentum.valid && ctx.momentum.atr > 0)
         buffer_atr = ctx.momentum.atr;
      if(buffer_atr <= 0)
         buffer_atr = ctx.context_market.closed_bar.high -
                      ctx.context_market.closed_bar.low;
      if(buffer_atr <= 0)
         buffer_atr = ctx.structure_market.closed_bar.high -
                      ctx.structure_market.closed_bar.low;
      if(buffer_atr <= 0)
         buffer_atr = GetTickSize() * 10;

      if(buffer_atr <= 0 || !MathIsValidNumber(buffer_atr))
        {
         reason="Invalid volatility input for trade plan";
         return false;
        }
      double stop_buffer_points = GetStopBuffer(m_active_style) * buffer_atr;
      double target_buffer_points = GetTargetBuffer(m_active_style) * buffer_atr;

      if(direction==SIGNAL_LONG)
        {
         stop = NormalizeDouble(
                   ctx.context_market.closed_bar.low - stop_buffer_points,
                   m_digits);
         target = NormalizeDouble(
                     entry + target_buffer_points,
                     m_digits);
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            stop = NormalizeDouble(
                      ctx.context_market.closed_bar.high + stop_buffer_points,
                      m_digits);
            target = NormalizeDouble(
                        entry - target_buffer_points,
                        m_digits);
           }
         else
           {
            reason="Invalid direction for trade plan";
            return false;
           }

      stop=CAlgoUtils::NormalizePriceToTick(
              stop, m_tick_size,
              (direction==SIGNAL_SHORT),
              m_digits);

      target=CAlgoUtils::NormalizePriceToTick(
                target, m_tick_size,
                (direction==SIGNAL_LONG),
                m_digits);

      if(stop<=0 || target<=0)
        {
         reason="Normalized stop/target is invalid";
         return false;
        }

      double risk=0;
      double reward=0;

      if(direction==SIGNAL_LONG)
        {
         risk=entry - stop;
         reward=target - entry;
        }
      else
        {
         risk=stop - entry;
         reward=entry - target;
        }

      if(risk<=0 || reward<=0)
        {
         reason="Invalid RR after trade plan construction";
         return false;
        }

      rr=reward / risk;

      if(rr <= 0)
        {
         reason="Invalid RR calculation";
         return false;
        }

      return true;
     }

   bool              ValidateSLTP(double stop,
                                  double target,
                                  double entry,
                                  ENUM_SIGNAL_DIRECTION direction,
                                  string& reason)
     {
      reason="";

      if(stop<=0 || target<=0 || entry<=0)
        {
         reason="Invalid price values";
         return false;
        }

      if(!MathIsValidNumber(stop) ||
         !MathIsValidNumber(target) ||
         !MathIsValidNumber(entry))
        {
         reason="NaN price values";
         return false;
        }

      if(direction==SIGNAL_LONG)
        {
         if(stop >= entry)
           {
            reason="Long stop at or above entry";
            return false;
           }
         if(target <= entry)
           {
            reason="Long target at or below entry";
            return false;
           }
        }
      else
         if(direction==SIGNAL_SHORT)
           {
            if(stop <= entry)
              {
               reason="Short stop at or below entry";
               return false;
              }
            if(target >= entry)
              {
               reason="Short target at or above entry";
               return false;
              }
           }
         else
           {
            reason="Invalid direction";
            return false;
           }

      double point=m_point > 0 ? m_point : m_tick_size;
      if(point<=0)
        {
         reason="Invalid point/tick size";
         return false;
        }

      long stops_level=0;
      SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level);
      if(stops_level>0)
        {
         double min_distance = (double)stops_level * point;
         double current_bid=ctx_bid();
         double current_ask=ctx_ask();

         if(direction==SIGNAL_LONG)
           {
            if(entry - stop < min_distance)
              {
               reason="Stop too close to entry for broker minimum";
               return false;
              }
            if(target - entry < min_distance)
              {
               reason="Target too close to entry for broker minimum";
               return false;
              }
           }
         else
           {
            if(stop - entry < min_distance)
              {
               reason="Stop too close to entry for broker minimum";
               return false;
              }
            if(entry - target < min_distance)
              {
               reason="Target too close to entry for broker minimum";
               return false;
              }
           }
        }

      return true;
     }

   double            ctx_bid() const
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
         return 0;
      return tick.bid;
     }

   double            ctx_ask() const
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
         return 0;
      return tick.ask;
     }

public:
   bool              NormalizeSignalStopsToTick(TradePlan& plan)
     {
      if(!plan.valid || plan.stop<=0 || plan.target<=0 || plan.entry<=0)
         return false;

      plan.stop=CAlgoUtils::NormalizePriceToTick(
                   plan.stop, m_tick_size,
                   (plan.direction==SIGNAL_SHORT),
                   m_digits);

      plan.target=CAlgoUtils::NormalizePriceToTick(
                     plan.target, m_tick_size,
                     (plan.direction==SIGNAL_LONG),
                     m_digits);

      return plan.stop > 0 && plan.target > 0;
     }

    void              MarkPlanConsumed(TradePlan& plan)
      {
       if(plan.consumed || plan.state==SETUP_STATE_CONSUMED)
          return;
       if(plan.state==SETUP_STATE_EXPIRED || plan.state==SETUP_STATE_INVALIDATED || plan.state==SETUP_STATE_REJECTED)
          return;
       plan.consumed=true;
       plan.state=SETUP_STATE_CONSUMED;
       m_last_signal_consumed=true;
      }

   bool              IsPlanConsumed(const TradePlan& plan) const
     {
      return plan.consumed;
     }

    bool              IsSetupFresh(datetime setup_time) const
      {
       if(!m_freshness_valid || setup_time<=0)
          return false;
       return (TimeCurrent() - setup_time) <= (datetime)m_freshness_setup_seconds;
      }

    bool              IsPlanExpired(const TradePlan& plan, datetime current_time) const
      {
       if(plan.expiry_time <= 0)
          return false;
       return current_time > plan.expiry_time;
      }

    ENUM_STRUCTURAL_EVIDENCE_RESULT EvaluateStructuralEvidence(const TradePlan& plan, double &out_price) const
      {
       out_price = plan.entry;
       if(!plan.valid)
          return EVIDENCE_INVALID_PLAN;
       if(plan.structural_invalidated)
          return EVIDENCE_STRUCTURAL_INVALIDATION_CONFIRMED;
       if(!plan.liquidity_used.valid)
          return EVIDENCE_INSUFFICIENT_EVIDENCE;
       if(!plan.liquidity_used.symbol.IsEmpty() && plan.liquidity_used.symbol != m_symbol)
          return EVIDENCE_SYMBOL_OR_TIMEFRAME_MISMATCH;
       if(!plan.symbol.IsEmpty() && plan.symbol != m_symbol)
          return EVIDENCE_SYMBOL_OR_TIMEFRAME_MISMATCH;
       if(plan.liquidity_used.timeframe != PERIOD_CURRENT)
          {
           // require match with structure timeframe when known
           if(m_structure_tf != PERIOD_CURRENT && plan.liquidity_used.timeframe != m_structure_tf)
              return EVIDENCE_SYMBOL_OR_TIMEFRAME_MISMATCH;
          }
       MqlTick tick_check;
       if(!SymbolInfoTick(m_symbol, tick_check))
          return EVIDENCE_TICK_UNAVAILABLE;
       if(tick_check.bid <= 0.0 && tick_check.ask <= 0.0)
          return EVIDENCE_TICK_UNAVAILABLE;
       // Tick freshness: time_msc preferred if available, fallback to time; if unprovenable -> stale/unverified
       if(plan.direction == SIGNAL_LONG)
         {
          if(tick_check.bid <= 0.0)
             return EVIDENCE_TICK_UNAVAILABLE;
          out_price = tick_check.bid;
         }
       else if(plan.direction == SIGNAL_SHORT)
         {
          if(tick_check.ask <= 0.0)
             return EVIDENCE_TICK_UNAVAILABLE;
          out_price = tick_check.ask;
         }
       else
         {
          if(tick_check.bid > 0.0)
             out_price = tick_check.bid;
          else if(tick_check.ask > 0.0)
             out_price = tick_check.ask;
          else
             return EVIDENCE_TICK_UNAVAILABLE;
         }
       if((plan.direction == SIGNAL_LONG && plan.liquidity_used.equal_low <= 0.0) ||
          (plan.direction == SIGNAL_SHORT && plan.liquidity_used.equal_high <= 0.0))
          return EVIDENCE_LEVEL_MISSING;
       if(m_liquidity_engine.IsLevelInvalidated(plan.liquidity_used, out_price, plan.direction))
          return EVIDENCE_STRUCTURAL_INVALIDATION_CONFIRMED;
       return EVIDENCE_SUFFICIENT_NO_INVALIDATION;
      }

    bool              IsStructuralInvalidated(const TradePlan& plan) const
      {
       double price = plan.entry;
       ENUM_STRUCTURAL_EVIDENCE_RESULT res = EvaluateStructuralEvidence(plan, price);
       return (res == EVIDENCE_STRUCTURAL_INVALIDATION_CONFIRMED);
      }

   ENUM_TRADING_STYLE GetActiveStyle() const
     {
      return m_active_style;
     }

   string            GetStyleName() const
     {
      switch(m_active_style)
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
  };

#endif
//+------------------------------------------------------------------+
