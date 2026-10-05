#ifndef __ALGOSYSTEM_TRENDSTRATEGY_MQH__
#define __ALGOSYSTEM_TRENDSTRATEGY_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Trend / Pullback Strategy                                        |
//|                                                                  |
//| Purpose:                                                         |
//| - trade only in established directional regimes                 |
//| - detect controlled pullback toward fast EMA                    |
//| - require price reclaim / rejection                             |
//| - score setup quality                                            |
//| - calculate reference SL/TP                                     |
//|                                                                  |
//| Does NOT:                                                        |
//| - calculate position volume                                      |
//| - send orders                                                    |
//| - modify positions                                               |
//| - manage open trades                                             |
//+------------------------------------------------------------------+
class CTrendPullbackStrategy : public IStrategy
  {
private:

   double m_pullback_zone_atr;
   double m_max_reclaim_distance_atr;

   double m_min_candle_strength;

   double m_min_roc_long;
   double m_max_roc_long;

   double m_min_roc_short;
   double m_max_roc_short;

   double m_rsi_long_min;
   double m_rsi_long_max;

   double m_rsi_short_min;
   double m_rsi_short_max;

   double m_stop_atr_multiplier;
   double m_structure_buffer_atr;
   double m_target_rr;

   double m_min_signal_score;
   int m_adx_score_threshold;
   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Reset signal                                                   |
   //+----------------------------------------------------------------+
   void ResetSignal(StrategySignal &signal) const
     {
      signal.valid=false;

      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_TREND_PULLBACK;

      signal.symbol="";
      signal.timeframe=PERIOD_CURRENT;

      signal.regime=REGIME_UNKNOWN;

      signal.score=0.0;
      signal.confidence=0.0;

      signal.entry=0.0;
      signal.stop=0.0;
      signal.target=0.0;

      signal.timestamp=0;

      signal.signal_id="";
      signal.reason="";
     }

   //+----------------------------------------------------------------+
   //| Validate configuration                                         |
   //+----------------------------------------------------------------+
   bool ValidateParameters() const
     {
      if(m_adx_score_threshold<=0)
         return false;
      if(m_pullback_zone_atr<=0.0)
         return false;

      if(m_max_reclaim_distance_atr<=0.0)
         return false;

      if(m_min_candle_strength<0.0 ||
         m_min_candle_strength>1.0)
         return false;

      if(m_rsi_long_min<0.0 ||
         m_rsi_long_min>100.0)
         return false;

      if(m_rsi_long_max<0.0 ||
         m_rsi_long_max>100.0)
         return false;

      if(m_rsi_short_min<0.0 ||
         m_rsi_short_min>100.0)
         return false;

      if(m_rsi_short_max<0.0 ||
         m_rsi_short_max>100.0)
         return false;

      if(m_rsi_long_min>=m_rsi_long_max)
         return false;

      if(m_rsi_short_min>=m_rsi_short_max)
         return false;

      if(m_stop_atr_multiplier<=0.0)
         return false;

      if(m_structure_buffer_atr<0.0)
         return false;

      if(m_target_rr<=0.0)
         return false;

      if(m_min_signal_score<0.0 ||
         m_min_signal_score>100.0)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Check long pullback                                            |
   //+----------------------------------------------------------------+
   bool IsLongPullback(const StrategyContext &context) const
     {
      if(context.regime!=REGIME_TREND_UP)
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.ema_fast<=0.0 ||
         context.features.ema_slow<=0.0 ||
         context.features.ema_long<=0.0)
         return false;

      // Price must remain structurally above the slow EMA.
      if(context.market.closed_bar.close<=context.features.ema_slow)
         return false;

      // Pullback must reach the fast EMA zone.
      double pullback_upper=
         context.features.ema_fast+
         context.features.atr*m_pullback_zone_atr;

      if(context.market.closed_bar.low>pullback_upper)
         return false;

      // Candle must reclaim / close above fast EMA.
      if(context.market.closed_bar.close<
         context.features.ema_fast)
         return false;

      // Bullish candle.
      if(context.market.closed_bar.close<=
         context.market.closed_bar.open)
         return false;

      // Avoid excessively extended close.
      double extension=
         CAlgoUtils::SafeDivide(
            context.market.closed_bar.close-
            context.features.ema_fast,
            context.features.atr,
            DBL_MAX);

      if(extension>m_max_reclaim_distance_atr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Check short pullback                                           |
   //+----------------------------------------------------------------+
   bool IsShortPullback(const StrategyContext &context) const
     {
      if(context.regime!=REGIME_TREND_DOWN)
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.ema_fast<=0.0 ||
         context.features.ema_slow<=0.0 ||
         context.features.ema_long<=0.0)
         return false;

      // Price must remain structurally below the slow EMA.
      if(context.market.closed_bar.close>=
         context.features.ema_slow)
         return false;

      // Pullback must reach the fast EMA zone.
      double pullback_lower=
         context.features.ema_fast-
         context.features.atr*m_pullback_zone_atr;

      if(context.market.closed_bar.high<pullback_lower)
         return false;

      // Candle must reject and close below fast EMA.
      if(context.market.closed_bar.close>
         context.features.ema_fast)
         return false;

      // Bearish candle.
      if(context.market.closed_bar.close>=
         context.market.closed_bar.open)
         return false;

      // Avoid excessively extended close.
      double extension=
         CAlgoUtils::SafeDivide(
            context.features.ema_fast-
            context.market.closed_bar.close,
            context.features.atr,
            DBL_MAX);

      if(extension>m_max_reclaim_distance_atr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Score long setup                                               |
   //+----------------------------------------------------------------+
   double ScoreLong(const StrategyContext &context) const
     {
      double score=0.0;

      // 1. Trend alignment: 25
      if(context.features.ema_fast>
         context.features.ema_slow &&
         context.features.ema_slow>
         context.features.ema_long)
         score+=25.0;

      // 2. Pullback proximity: 25
      double distance=
         CAlgoUtils::SafeDivide(
            MathAbs(
               context.market.closed_bar.close-
               context.features.ema_fast),
            context.features.atr,
            DBL_MAX);

      if(distance<=0.25)
         score+=25.0;
      else if(distance<=0.50)
         score+=20.0;
      else if(distance<=0.75)
         score+=15.0;

      // 3. Candle quality: 15
      if(context.features.candle_strength>=
         m_min_candle_strength)
        {
         double candle_score=
            CAlgoUtils::Clamp(
               context.features.candle_strength,
               0.0,
               1.0)*15.0;

         score+=candle_score;
        }

      // 4. Momentum: 15
      if(context.features.macd_main>
         context.features.macd_signal)
         score+=7.5;

      if(context.features.roc>=m_min_roc_long &&
         context.features.roc<=m_max_roc_long)
         score+=7.5;

      // 5. RSI condition: 10
      if(context.features.rsi>=m_rsi_long_min &&
         context.features.rsi<=m_rsi_long_max)
         score+=10.0;

      // 6. ADX confirmation: 10
      if(context.features.adx>=(double)m_adx_score_threshold)
         score+=10.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Score short setup                                              |
   //+----------------------------------------------------------------+
   double ScoreShort(const StrategyContext &context) const
     {
      double score=0.0;

      // 1. Trend alignment: 25
      if(context.features.ema_fast<
         context.features.ema_slow &&
         context.features.ema_slow<
         context.features.ema_long)
         score+=25.0;

      // 2. Pullback proximity: 25
      double distance=
         CAlgoUtils::SafeDivide(
            MathAbs(
               context.market.closed_bar.close-
               context.features.ema_fast),
            context.features.atr,
            DBL_MAX);

      if(distance<=0.25)
         score+=25.0;
      else if(distance<=0.50)
         score+=20.0;
      else if(distance<=0.75)
         score+=15.0;

      // 3. Candle quality: 15
      if(context.features.candle_strength>=
         m_min_candle_strength)
        {
         double candle_score=
            CAlgoUtils::Clamp(
               context.features.candle_strength,
               0.0,
               1.0)*15.0;

         score+=candle_score;
        }

      // 4. Momentum: 15
      if(context.features.macd_main<
         context.features.macd_signal)
         score+=7.5;

      if(context.features.roc<=m_max_roc_short &&
         context.features.roc>=m_min_roc_short)
         score+=7.5;

      // 5. RSI condition: 10
      if(context.features.rsi>=m_rsi_short_min &&
         context.features.rsi<=m_rsi_short_max)
         score+=10.0;

      // 6. ADX confirmation: 10
      if(context.features.adx>=(double)m_adx_score_threshold)
         score+=10.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Build long SL/TP                                               |
   //+----------------------------------------------------------------+
   bool BuildLongLevels(const StrategyContext &context,
                        double &entry,
                        double &stop,
                        double &target) const
     {
      entry=context.market.closed_bar.close;

      if(entry<=0.0 ||
         context.features.atr<=0.0)
         return false;

      double atr_stop=
         entry-
         context.features.atr*m_stop_atr_multiplier;

      double structural_stop=
         context.market.closed_bar.low-
         context.features.atr*m_structure_buffer_atr;

      stop=MathMin(
         atr_stop,
         structural_stop);

      if(stop<=0.0 ||
         stop>=entry)
         return false;

      double distance=entry-stop;

      target=
         entry+
         distance*m_target_rr;

      if(target<=entry)
         return false;

      double actual_rr=
         CAlgoUtils::SafeDivide(
            target-entry,
            entry-stop,
            0.0);

      if(actual_rr<m_target_rr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Build short SL/TP                                              |
   //+----------------------------------------------------------------+
   bool BuildShortLevels(const StrategyContext &context,
                         double &entry,
                         double &stop,
                         double &target) const
     {
      entry=context.market.closed_bar.close;

      if(entry<=0.0 ||
         context.features.atr<=0.0)
         return false;

      double atr_stop=
         entry+
         context.features.atr*m_stop_atr_multiplier;

      double structural_stop=
         context.market.closed_bar.high+
         context.features.atr*m_structure_buffer_atr;

      stop=MathMax(
         atr_stop,
         structural_stop);

      if(stop<=entry)
         return false;

      double distance=stop-entry;

      target=
         entry-
         distance*m_target_rr;

      if(target<=0.0 ||
         target>=entry)
         return false;

      double actual_rr=
         CAlgoUtils::SafeDivide(
            entry-target,
            stop-entry,
            0.0);

      if(actual_rr<m_target_rr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Build deterministic signal ID                                  |
   //+----------------------------------------------------------------+
   string BuildSignalId(const StrategyContext &context) const
     {
      return context.market.symbol+
             "|TREND_PULLBACK|"+
             IntegerToString(
                (long)context.market.timeframe)+
             "|"+
             TimeToString(
                context.market.closed_bar.time,
                TIME_DATE|TIME_MINUTES|TIME_SECONDS);
     }

   //+----------------------------------------------------------------+
   //| Finalize long signal                                           |
   //+----------------------------------------------------------------+
   bool BuildLongSignal(const StrategyContext &context,
                        StrategySignal &signal) const
     {
      double entry;
      double stop;
      double target;

      if(!BuildLongLevels(
            context,
            entry,
            stop,
            target))
         return false;

      double score=ScoreLong(context);

      if(score<m_min_signal_score)
         return false;

      signal.valid=true;

      signal.direction=SIGNAL_LONG;
      signal.strategy=STRATEGY_TREND_PULLBACK;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=REGIME_TREND_UP;

      signal.score=score;
      signal.confidence=score/100.0;

      signal.entry=entry;
      signal.stop=stop;
      signal.target=target;

      signal.timestamp=
         context.market.closed_bar.time;

      signal.signal_id=
         BuildSignalId(context);

      signal.reason=
         "TrendUp + Pullback + Reclaim";

      return true;
     }

   //+----------------------------------------------------------------+
   //| Finalize short signal                                          |
   //+----------------------------------------------------------------+
   bool BuildShortSignal(const StrategyContext &context,
                         StrategySignal &signal) const
     {
      double entry;
      double stop;
      double target;

      if(!BuildShortLevels(
            context,
            entry,
            stop,
            target))
         return false;

      double score=ScoreShort(context);

      if(score<m_min_signal_score)
         return false;

      signal.valid=true;

      signal.direction=SIGNAL_SHORT;
      signal.strategy=STRATEGY_TREND_PULLBACK;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=REGIME_TREND_DOWN;

      signal.score=score;
      signal.confidence=score/100.0;

      signal.entry=entry;
      signal.stop=stop;
      signal.target=target;

      signal.timestamp=
         context.market.closed_bar.time;

      signal.signal_id=
         BuildSignalId(context);

      signal.reason=
         "TrendDown + Pullback + Reclaim";

      return true;
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CTrendPullbackStrategy()
     {
      m_adx_score_threshold=25;
      m_pullback_zone_atr=0.30;
      m_max_reclaim_distance_atr=0.75;

      m_min_candle_strength=0.50;

      m_min_roc_long=0.0;
      m_max_roc_long=5.0;

      m_min_roc_short=-5.0;
      m_max_roc_short=0.0;

      m_rsi_long_min=50.0;
      m_rsi_long_max=70.0;

      m_rsi_short_min=30.0;
      m_rsi_short_max=50.0;

      m_stop_atr_multiplier=1.50;
      m_structure_buffer_atr=0.20;

      m_target_rr=1.50;

      m_min_signal_score=70.0;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Configure parameters                                           |
   //+----------------------------------------------------------------+
   void SetParameters(
      const double pullback_zone_atr,
      const double max_reclaim_distance_atr,
      const double min_candle_strength,
      const double min_roc_long,
      const double max_roc_long,
      const double min_roc_short,
      const double max_roc_short,
      const double rsi_long_min,
      const double rsi_long_max,
      const double rsi_short_min,
      const double rsi_short_max,
      const double stop_atr_multiplier,
      const double structure_buffer_atr,
      const double target_rr,
      const double min_signal_score,
      const int adx_score_threshold)
     {
      m_pullback_zone_atr=
         pullback_zone_atr;

      m_max_reclaim_distance_atr=
         max_reclaim_distance_atr;

      m_min_candle_strength=
         min_candle_strength;

      m_min_roc_long=
         min_roc_long;

      m_max_roc_long=
         max_roc_long;

      m_min_roc_short=
         min_roc_short;

      m_max_roc_short=
         max_roc_short;

      m_rsi_long_min=
         rsi_long_min;

      m_rsi_long_max=
         rsi_long_max;

      m_rsi_short_min=
         rsi_short_min;

      m_rsi_short_max=
         rsi_short_max;

      m_stop_atr_multiplier=
         stop_atr_multiplier;

      m_structure_buffer_atr=
         structure_buffer_atr;

      m_target_rr=
         target_rr;

      m_min_signal_score=
         min_signal_score;

      m_adx_score_threshold=
         adx_score_threshold;

      m_initialized=false;
     }
     
     /*void SetADXScoreThreshold(const int threshold)
      {
         m_adx_score_threshold=threshold;
      }*/

   //+----------------------------------------------------------------+
   //| IStrategy                                                      |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;

      return true;
     }

   virtual ENUM_STRATEGY_ID Id() const override
     {
      return STRATEGY_TREND_PULLBACK;
     }

   virtual bool Evaluate(
      const StrategyContext &context,
      StrategySignal &signal) override
     {
      ResetSignal(signal);

      if(!m_initialized)
         return false;

      if(!context.trading_allowed)
         return false;

      if(!context.market.valid)
         return false;

      if(!context.features.valid)
         return false;

      if(context.regime==REGIME_TREND_UP)
        {
         if(!IsLongPullback(context))
            return false;

         return BuildLongSignal(
            context,
            signal);
        }

      if(context.regime==REGIME_TREND_DOWN)
        {
         if(!IsShortPullback(context))
            return false;

         return BuildShortSignal(
            context,
            signal);
        }

      return false;
     }

   //+----------------------------------------------------------------+
   //| Status                                                         |
   //+----------------------------------------------------------------+
   bool IsInitialized() const
     {
      return m_initialized;
     }

   double TargetRR() const
     {
      return m_target_rr;
     }

   double MinimumScore() const
     {
      return m_min_signal_score;
     }
  };

#endif