#ifndef __ALGOSYSTEM_MEANREVERSIONSTRATEGY_MQH__
#define __ALGOSYSTEM_MEANREVERSIONSTRATEGY_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Mean Reversion Strategy                                          |
//|                                                                  |
//| V2 strategy.                                                     |
//| Primary regime: RANGE                                            |
//|                                                                  |
//| Does NOT:                                                        |
//| - trade trend regimes                                            |
//| - send orders                                                     |
//| - calculate final position risk                                  |
//+------------------------------------------------------------------+
class CMeanReversionStrategy : public IStrategy
  {
private:

   double m_rsi_long_max;
   double m_rsi_short_min;

   double m_min_distance_atr;
   double m_max_distance_atr;

   double m_min_candle_strength;

   int    m_range_lookback;

   double m_stop_atr_multiplier;
   double m_structure_buffer_atr;
   double m_target_rr;

   double m_min_signal_score;

   bool m_initialized;

   //+----------------------------------------------------------------+
   void ResetSignal(
      StrategySignal &signal) const
     {
      signal.valid=false;

      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_MEAN_REVERSION;

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
   bool ValidateParameters() const
     {
      if(m_rsi_long_max<=0.0 ||
         m_rsi_long_max>=50.0)
         return false;

      if(m_rsi_short_min<=50.0 ||
         m_rsi_short_min>=100.0)
         return false;

      if(m_min_distance_atr<=0.0)
         return false;

      if(m_max_distance_atr<=m_min_distance_atr)
         return false;

      if(m_min_candle_strength<0.0 ||
         m_min_candle_strength>1.0)
         return false;

      if(m_range_lookback<5)
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
   bool GetRange(
      const StrategyContext &context,
      double &range_high,
      double &range_low) const
     {
      range_high=0.0;
      range_low=0.0;

      MqlRates rates[];

      ArrayResize(
         rates,
         m_range_lookback);

      ResetLastError();

      // Exclude signal candle itself.
      int copied=
         CopyRates(
            context.market.symbol,
            context.market.timeframe,
            2,
            m_range_lookback,
            rates);

      if(copied!=m_range_lookback)
         return false;

      range_high=rates[0].high;
      range_low=rates[0].low;

      for(int i=1;
          i<m_range_lookback;
          i++)
        {
         if(rates[i].high>range_high)
            range_high=rates[i].high;

         if(rates[i].low<range_low)
            range_low=rates[i].low;
        }

      return (
         range_high>range_low &&
         range_low>0.0);
     }

   //+----------------------------------------------------------------+
   bool IsLongSetup(
      const StrategyContext &context) const
     {
      if(context.regime!=REGIME_RANGE)
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.rsi>
         m_rsi_long_max)
         return false;

      double distance=
         context.features.ema_fast-
         context.market.closed_bar.close;

      if(distance<=0.0)
         return false;

      double distance_atr=
         distance/context.features.atr;

      if(distance_atr<m_min_distance_atr ||
         distance_atr>m_max_distance_atr)
         return false;

      // Reversal candle.
      if(context.market.closed_bar.close<=
         context.market.closed_bar.open)
         return false;

      if(context.features.candle_strength<
         m_min_candle_strength)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   bool IsShortSetup(
      const StrategyContext &context) const
     {
      if(context.regime!=REGIME_RANGE)
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.rsi<
         m_rsi_short_min)
         return false;

      double distance=
         context.market.closed_bar.close-
         context.features.ema_fast;

      if(distance<=0.0)
         return false;

      double distance_atr=
         distance/context.features.atr;

      if(distance_atr<m_min_distance_atr ||
         distance_atr>m_max_distance_atr)
         return false;

      // Reversal candle.
      if(context.market.closed_bar.close>=
         context.market.closed_bar.open)
         return false;

      if(context.features.candle_strength<
         m_min_candle_strength)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   double ScoreLong(
      const StrategyContext &context) const
     {
      double score=0.0;

      if(context.regime==REGIME_RANGE)
         score+=20.0;

      if(context.features.rsi<=25.0)
         score+=20.0;
      else if(context.features.rsi<=m_rsi_long_max)
         score+=15.0;

      double distance=
         CAlgoUtils::SafeDivide(
            context.features.ema_fast-
            context.market.closed_bar.close,
            context.features.atr,
            0.0);

      if(distance>=1.0)
         score+=20.0;
      else if(distance>=m_min_distance_atr)
         score+=15.0;

      score+=
         CAlgoUtils::Clamp(
            context.features.candle_strength,
            0.0,
            1.0)*15.0;

      if(context.features.macd_main>
         context.features.macd_signal)
         score+=10.0;

      if(context.features.roc>0.0)
         score+=15.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   double ScoreShort(
      const StrategyContext &context) const
     {
      double score=0.0;

      if(context.regime==REGIME_RANGE)
         score+=20.0;

      if(context.features.rsi>=75.0)
         score+=20.0;
      else if(context.features.rsi>=m_rsi_short_min)
         score+=15.0;

      double distance=
         CAlgoUtils::SafeDivide(
            context.market.closed_bar.close-
            context.features.ema_fast,
            context.features.atr,
            0.0);

      if(distance>=1.0)
         score+=20.0;
      else if(distance>=m_min_distance_atr)
         score+=15.0;

      score+=
         CAlgoUtils::Clamp(
            context.features.candle_strength,
            0.0,
            1.0)*15.0;

      if(context.features.macd_main<
         context.features.macd_signal)
         score+=10.0;

      if(context.features.roc<0.0)
         score+=15.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   bool BuildLongLevels(
      const StrategyContext &context,
      double &entry,
      double &stop,
      double &target) const
     {
      double range_high;
      double range_low;

      if(!GetRange(
            context,
            range_high,
            range_low))
         return false;

      entry=context.market.closed_bar.close;

      double atr_stop=
         entry-
         context.features.atr*
         m_stop_atr_multiplier;

      double structure_stop=
         range_low-
         context.features.atr*
         m_structure_buffer_atr;

      stop=MathMin(
         atr_stop,
         structure_stop);

      if(stop<=0.0 ||
         stop>=entry)
         return false;

      // Primary mean-reversion target is the EMA mean.
      target=context.features.ema_fast;

      if(target<=entry)
        {
         target=
            entry+
            (entry-stop)*m_target_rr;
        }

      double rr=
         CAlgoUtils::SafeDivide(
            target-entry,
            entry-stop,
            0.0);

      if(rr<m_target_rr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   bool BuildShortLevels(
      const StrategyContext &context,
      double &entry,
      double &stop,
      double &target) const
     {
      double range_high;
      double range_low;

      if(!GetRange(
            context,
            range_high,
            range_low))
         return false;

      entry=context.market.closed_bar.close;

      double atr_stop=
         entry+
         context.features.atr*
         m_stop_atr_multiplier;

      double structure_stop=
         range_high+
         context.features.atr*
         m_structure_buffer_atr;

      stop=MathMax(
         atr_stop,
         structure_stop);

      if(stop<=entry)
         return false;

      target=context.features.ema_fast;

      if(target>=entry)
        {
         target=
            entry-
            (stop-entry)*m_target_rr;
        }

      double rr=
         CAlgoUtils::SafeDivide(
            entry-target,
            stop-entry,
            0.0);

      if(rr<m_target_rr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   string BuildSignalId(
      const StrategyContext &context) const
     {
      return context.market.symbol+
             "|MEAN_REVERSION|"+
             IntegerToString(
                (int)context.market.timeframe)+
             "|"+
             TimeToString(
                context.market.closed_bar.time,
                TIME_DATE|TIME_MINUTES|TIME_SECONDS);
     }

public:

   CMeanReversionStrategy()
     {
      m_rsi_long_max=30.0;
      m_rsi_short_min=70.0;

      m_min_distance_atr=0.50;
      m_max_distance_atr=2.00;

      m_min_candle_strength=0.45;

      m_range_lookback=20;

      m_stop_atr_multiplier=1.50;
      m_structure_buffer_atr=0.20;

      m_target_rr=1.50;
      m_min_signal_score=70.0;

      m_initialized=false;
     }

   void SetMinimumSignalScore(const double score)
     {
      m_min_signal_score=score;
      m_initialized=false;
     }

   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;

      return true;
     }

   virtual ENUM_STRATEGY_ID Id() const override
     {
      return STRATEGY_MEAN_REVERSION;
     }

   virtual bool Evaluate(
      const StrategyContext &context,
      StrategySignal &signal) override
     {
      ResetSignal(signal);

      if(!m_initialized ||
         !context.trading_allowed ||
         !context.market.valid ||
         !context.features.valid)
         return false;

      if(IsLongSetup(context))
        {
         double score=ScoreLong(context);

         if(score<m_min_signal_score)
            return false;

         double entry;
         double stop;
         double target;

         if(!BuildLongLevels(
               context,
               entry,
               stop,
               target))
            return false;

         signal.valid=true;
         signal.direction=SIGNAL_LONG;
         signal.strategy=STRATEGY_MEAN_REVERSION;
         signal.symbol=context.market.symbol;
         signal.timeframe=context.market.timeframe;
         signal.regime=REGIME_RANGE;
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
            "Range + Oversold + Mean Reversion";

         return true;
        }

      if(IsShortSetup(context))
        {
         double score=ScoreShort(context);

         if(score<m_min_signal_score)
            return false;

         double entry;
         double stop;
         double target;

         if(!BuildShortLevels(
               context,
               entry,
               stop,
               target))
            return false;

         signal.valid=true;
         signal.direction=SIGNAL_SHORT;
         signal.strategy=STRATEGY_MEAN_REVERSION;
         signal.symbol=context.market.symbol;
         signal.timeframe=context.market.timeframe;
         signal.regime=REGIME_RANGE;
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
            "Range + Overbought + Mean Reversion";

         return true;
        }

      return false;
     }
  };

#endif