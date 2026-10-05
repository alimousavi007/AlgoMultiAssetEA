#ifndef __ALGOSYSTEM_BREAKOUTSTRATEGY_MQH__
#define __ALGOSYSTEM_BREAKOUTSTRATEGY_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Breakout Strategy                                                |
//|                                                                  |
//| Responsibility:                                                 |
//| - detect directional breakout against PRE-BREAKOUT range        |
//| - measure breakout quality                                       |
//| - validate expansion / candle / momentum / volume               |
//| - create StrategySignal                                          |
//|                                                                  |
//| Does NOT:                                                        |
//| - calculate position size                                        |
//| - send orders                                                    |
//| - modify positions                                               |
//| - manage open trades                                             |
//+------------------------------------------------------------------+
class CBreakoutStrategy : public IStrategy
  {
private:

   //--- structure
   int    m_range_lookback;
   double m_breakout_buffer_atr;
   double m_max_range_width_atr;

   //--- expansion
   double m_min_breakout_range_atr;

   //--- volume
   double m_min_volume_ratio;

   //--- candle
   double m_min_candle_strength;

   //--- momentum
   double m_min_roc_long;
   double m_max_roc_long;

   double m_min_roc_short;
   double m_max_roc_short;

   //--- risk reference
   double m_stop_atr_multiplier;
   double m_structure_buffer_atr;
   double m_target_rr;

   //--- scoring
   double m_min_breakout_score;

   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Reset signal                                                   |
   //+----------------------------------------------------------------+
   void ResetSignal(StrategySignal &signal) const
     {
      signal.valid=false;

      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_BREAKOUT;

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
   //| Validate parameters                                            |
   //+----------------------------------------------------------------+
   bool ValidateParameters() const
     {
      if(m_range_lookback<5)
         return false;

      if(m_breakout_buffer_atr<0.0)
         return false;

      if(m_max_range_width_atr<=0.0)
         return false;

      if(m_min_breakout_range_atr<=0.0)
         return false;

      if(m_min_volume_ratio<=0.0)
         return false;

      if(m_min_candle_strength<0.0 ||
         m_min_candle_strength>1.0)
         return false;

      if(m_stop_atr_multiplier<=0.0)
         return false;

      if(m_structure_buffer_atr<0.0)
         return false;

      if(m_target_rr<=0.0)
         return false;

      if(m_min_breakout_score<0.0 ||
         m_min_breakout_score>100.0)
         return false;

      if(m_min_roc_long>m_max_roc_long)
         return false;

      if(m_min_roc_short>m_max_roc_short)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Load PRE-BREAKOUT range                                        |
   //|                                                                  |
   //| shift 1 = signal candle                                       |
   //| shift 2..N = candles used for the prior consolidation/range   |
   //+----------------------------------------------------------------+
   bool GetPreBreakoutRange(const string symbol,
                            ENUM_TIMEFRAMES timeframe,
                            double &range_high,
                            double &range_low,
                            double &range_width) const
     {
      range_high=0.0;
      range_low=0.0;
      range_width=0.0;

      if(m_range_lookback<5)
         return false;

      MqlRates history[];

      ArrayResize(history,
                  m_range_lookback);

      ResetLastError();

      // Start at shift=2.
      // Therefore the signal candle (shift=1) cannot contaminate
      // the range calculation.
      int copied=CopyRates(
         symbol,
         timeframe,
         2,
         m_range_lookback,
         history);

      if(copied!=m_range_lookback)
         return false;

      range_high=history[0].high;
      range_low=history[0].low;

      for(int i=1;
          i<m_range_lookback;
          i++)
        {
         if(history[i].high>range_high)
            range_high=history[i].high;

         if(history[i].low<range_low)
            range_low=history[i].low;
        }

      range_width=range_high-range_low;

      if(range_high<=range_low)
         return false;

      if(range_width<=0.0)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect long breakout                                           |
   //+----------------------------------------------------------------+
   bool IsLongBreakout(const StrategyContext &context,
                       const double range_high) const
     {
      if(context.regime!=REGIME_BREAKOUT)
         return false;

      if(context.features.atr<=0.0)
         return false;

      double breakout_level=
         range_high+
         context.features.atr*m_breakout_buffer_atr;

      if(context.market.closed_bar.close<=breakout_level)
         return false;

      // Require meaningful candle expansion.
      double candle_range=
         context.market.closed_bar.high-
         context.market.closed_bar.low;

      if(candle_range<
         context.features.atr*m_min_breakout_range_atr)
         return false;

      // Bullish close.
      if(context.market.closed_bar.close<=
         context.market.closed_bar.open)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect short breakout                                          |
   //+----------------------------------------------------------------+
   bool IsShortBreakout(const StrategyContext &context,
                        const double range_low) const
     {
      if(context.regime!=REGIME_BREAKOUT)
         return false;

      if(context.features.atr<=0.0)
         return false;

      double breakout_level=
         range_low-
         context.features.atr*m_breakout_buffer_atr;

      if(context.market.closed_bar.close>=breakout_level)
         return false;

      // Require meaningful candle expansion.
      double candle_range=
         context.market.closed_bar.high-
         context.market.closed_bar.low;

      if(candle_range<
         context.features.atr*m_min_breakout_range_atr)
         return false;

      // Bearish close.
      if(context.market.closed_bar.close>=
         context.market.closed_bar.open)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Score range compression                                        |
   //+----------------------------------------------------------------+
   double ScoreRangeCompression(
      const double range_width,
      const double atr) const
     {
      if(range_width<=0.0 ||
         atr<=0.0)
         return 0.0;

      double ratio=range_width/atr;

      if(ratio<=1.50)
         return 20.0;

      if(ratio<=2.00)
         return 17.0;

      if(ratio<=2.50)
         return 14.0;

      if(ratio<=3.00)
         return 10.0;

      if(ratio<=m_max_range_width_atr)
         return 5.0;

      return 0.0;
     }

   //+----------------------------------------------------------------+
   //| Score breakout distance                                        |
   //+----------------------------------------------------------------+
   double ScoreBreakDistance(
      const double close_price,
      const double range_boundary,
      const double atr,
      const bool long_breakout) const
     {
      if(atr<=0.0)
         return 0.0;

      double distance=0.0;

      if(long_breakout)
         distance=close_price-range_boundary;
      else
         distance=range_boundary-close_price;

      if(distance<=0.0)
         return 0.0;

      double normalized=distance/atr;

      if(normalized>=1.00)
         return 20.0;

      if(normalized>=0.75)
         return 17.0;

      if(normalized>=0.50)
         return 14.0;

      if(normalized>=0.25)
         return 10.0;

      return 5.0;
     }

   //+----------------------------------------------------------------+
   //| Score candle expansion                                         |
   //+----------------------------------------------------------------+
   double ScoreCandleExpansion(
      const double candle_range,
      const double atr) const
     {
      if(candle_range<=0.0 ||
         atr<=0.0)
         return 0.0;

      double ratio=candle_range/atr;

      if(ratio>=1.50)
         return 20.0;

      if(ratio>=1.25)
         return 17.0;

      if(ratio>=1.00)
         return 14.0;

      if(ratio>=m_min_breakout_range_atr)
         return 10.0;

      return 0.0;
     }

   //+----------------------------------------------------------------+
   //| Score candle body quality                                      |
   //+----------------------------------------------------------------+
   double ScoreCandleStrength(
      const double candle_strength) const
     {
      if(candle_strength<=0.0)
         return 0.0;

      if(candle_strength>=0.80)
         return 10.0;

      if(candle_strength>=0.65)
         return 8.0;

      if(candle_strength>=0.50)
         return 6.0;

      if(candle_strength>=m_min_candle_strength)
         return 4.0;

      return 0.0;
     }

   //+----------------------------------------------------------------+
   //| Score volume confirmation                                      |
   //+----------------------------------------------------------------+
   double ScoreVolume(
      const double volume_ratio) const
     {
      if(volume_ratio<=0.0)
         return 0.0;

      if(volume_ratio>=2.00)
         return 15.0;

      if(volume_ratio>=1.50)
         return 13.0;

      if(volume_ratio>=1.25)
         return 11.0;

      if(volume_ratio>=m_min_volume_ratio)
         return 8.0;

      return 0.0;
     }

   //+----------------------------------------------------------------+
   //| Score directional momentum                                     |
   //+----------------------------------------------------------------+
   double ScoreMomentumLong(
      const StrategyContext &context) const
     {
      double score=0.0;

      if(context.features.macd_main>
         context.features.macd_signal)
         score+=7.5;

      if(context.features.roc>=m_min_roc_long &&
         context.features.roc<=m_max_roc_long)
         score+=7.5;

      return score;
     }

   //+----------------------------------------------------------------+
   //| Score directional momentum                                     |
   //+----------------------------------------------------------------+
   double ScoreMomentumShort(
      const StrategyContext &context) const
     {
      double score=0.0;

      if(context.features.macd_main<
         context.features.macd_signal)
         score+=7.5;

      if(context.features.roc>=m_min_roc_short &&
         context.features.roc<=m_max_roc_short)
         score+=7.5;

      return score;
     }

   //+----------------------------------------------------------------+
   //| Score EMA directional alignment                                |
   //+----------------------------------------------------------------+
   double ScoreDirectionalAlignmentLong(
      const StrategyContext &context) const
     {
      if(context.features.ema_fast>
         context.features.ema_slow)
         return 5.0;

      return 0.0;
     }

   double ScoreDirectionalAlignmentShort(
      const StrategyContext &context) const
     {
      if(context.features.ema_fast<
         context.features.ema_slow)
         return 5.0;

      return 0.0;
     }

   //+----------------------------------------------------------------+
   //| Long breakout quality                                          |
   //+----------------------------------------------------------------+
   double CalculateLongScore(
      const StrategyContext &context,
      const double range_high,
      const double range_low) const
     {
      double score=0.0;

      double range_width=
         range_high-range_low;

      double candle_range=
         context.market.closed_bar.high-
         context.market.closed_bar.low;

      // 20: range compression
      score+=ScoreRangeCompression(
         range_width,
         context.features.atr);

      // 20: distance beyond range
      score+=ScoreBreakDistance(
         context.market.closed_bar.close,
         range_high,
         context.features.atr,
         true);

      // 20: candle expansion
      score+=ScoreCandleExpansion(
         candle_range,
         context.features.atr);

      // 10: candle body quality
      score+=ScoreCandleStrength(
         context.features.candle_strength);

      // 15: volume
      score+=ScoreVolume(
         context.features.volume_ratio);

      // 15: momentum
      score+=ScoreMomentumLong(context);

      // Keep score bounded.
      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Short breakout quality                                         |
   //+----------------------------------------------------------------+
   double CalculateShortScore(
      const StrategyContext &context,
      const double range_high,
      const double range_low) const
     {
      double score=0.0;

      double range_width=
         range_high-range_low;

      double candle_range=
         context.market.closed_bar.high-
         context.market.closed_bar.low;

      // 20: range compression
      score+=ScoreRangeCompression(
         range_width,
         context.features.atr);

      // 20: distance beyond range
      score+=ScoreBreakDistance(
         context.market.closed_bar.close,
         range_low,
         context.features.atr,
         false);

      // 20: candle expansion
      score+=ScoreCandleExpansion(
         candle_range,
         context.features.atr);

      // 10: candle body quality
      score+=ScoreCandleStrength(
         context.features.candle_strength);

      // 15: volume
      score+=ScoreVolume(
         context.features.volume_ratio);

      // 15: momentum
      score+=ScoreMomentumShort(context);

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Build long levels                                              |
   //+----------------------------------------------------------------+
   bool BuildLongLevels(
      const StrategyContext &context,
      const double range_low,
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
         range_low-
         context.features.atr*m_structure_buffer_atr;

      // Choose the wider protective boundary.
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
   //| Build short levels                                             |
   //+----------------------------------------------------------------+
   bool BuildShortLevels(
      const StrategyContext &context,
      const double range_high,
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
         range_high+
         context.features.atr*m_structure_buffer_atr;

      // Choose the wider protective boundary.
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
   //| Build signal ID                                                |
   //+----------------------------------------------------------------+
   string BuildSignalId(
      const StrategyContext &context) const
     {
      return context.market.symbol+
             "|BREAKOUT|"+
             IntegerToString(
                (int)context.market.timeframe)+
             "|"+
             TimeToString(
                context.market.closed_bar.time,
                TIME_DATE|TIME_MINUTES|TIME_SECONDS);
     }

   //+----------------------------------------------------------------+
   //| Build long signal                                              |
   //+----------------------------------------------------------------+
   bool BuildLongSignal(
      const StrategyContext &context,
      const double range_high,
      const double range_low,
      StrategySignal &signal) const
     {
      double score=
         CalculateLongScore(
            context,
            range_high,
            range_low);

      if(score<m_min_breakout_score)
         return false;

      double entry;
      double stop;
      double target;

      if(!BuildLongLevels(
            context,
            range_low,
            entry,
            stop,
            target))
         return false;

      signal.valid=true;

      signal.direction=SIGNAL_LONG;
      signal.strategy=STRATEGY_BREAKOUT;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=REGIME_BREAKOUT;

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
         "RangeBreak + Expansion + Momentum";

      return true;
     }

   //+----------------------------------------------------------------+
   //| Build short signal                                             |
   //+----------------------------------------------------------------+
   bool BuildShortSignal(
      const StrategyContext &context,
      const double range_high,
      const double range_low,
      StrategySignal &signal) const
     {
      double score=
         CalculateShortScore(
            context,
            range_high,
            range_low);

      if(score<m_min_breakout_score)
         return false;

      double entry;
      double stop;
      double target;

      if(!BuildShortLevels(
            context,
            range_high,
            entry,
            stop,
            target))
         return false;

      signal.valid=true;

      signal.direction=SIGNAL_SHORT;
      signal.strategy=STRATEGY_BREAKOUT;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=REGIME_BREAKOUT;

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
         "RangeBreak + Expansion + Momentum";

      return true;
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CBreakoutStrategy()
     {
      // Initial defaults only.
      // They are NOT optimized parameters.

      m_range_lookback=20;

      m_breakout_buffer_atr=0.10;

      m_max_range_width_atr=4.0;

      m_min_breakout_range_atr=0.80;

      m_min_volume_ratio=1.20;

      m_min_candle_strength=0.50;

      m_min_roc_long=0.0;
      m_max_roc_long=6.0;

      m_min_roc_short=-6.0;
      m_max_roc_short=0.0;

      m_stop_atr_multiplier=1.50;

      m_structure_buffer_atr=0.20;

      m_target_rr=1.50;

      m_min_breakout_score=70.0;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Configuration                                                  |
   //+----------------------------------------------------------------+
   void SetParameters(
      const int range_lookback,
      const double breakout_buffer_atr,
      const double max_range_width_atr,
      const double min_breakout_range_atr,
      const double min_volume_ratio,
      const double min_candle_strength,
      const double min_roc_long,
      const double max_roc_long,
      const double min_roc_short,
      const double max_roc_short,
      const double stop_atr_multiplier,
      const double structure_buffer_atr,
      const double target_rr,
      const double min_breakout_score)
     {
      m_range_lookback=
         range_lookback;

      m_breakout_buffer_atr=
         breakout_buffer_atr;

      m_max_range_width_atr=
         max_range_width_atr;

      m_min_breakout_range_atr=
         min_breakout_range_atr;

      m_min_volume_ratio=
         min_volume_ratio;

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

      m_stop_atr_multiplier=
         stop_atr_multiplier;

      m_structure_buffer_atr=
         structure_buffer_atr;

      m_target_rr=
         target_rr;

      m_min_breakout_score=
         min_breakout_score;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Initialize                                                    |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Strategy ID                                                    |
   //+----------------------------------------------------------------+
   virtual ENUM_STRATEGY_ID Id() const override
     {
      return STRATEGY_BREAKOUT;
     }

   //+----------------------------------------------------------------+
   //| Evaluate                                                       |
   //+----------------------------------------------------------------+
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

      if(context.regime!=REGIME_BREAKOUT)
         return false;

      double range_high;
      double range_low;
      double range_width;

      if(!GetPreBreakoutRange(
            context.market.symbol,
            context.market.timeframe,
            range_high,
            range_low,
            range_width))
         return false;

      // Reject excessively wide pre-breakout structures.
      if(range_width>
         context.features.atr*m_max_range_width_atr)
         return false;

      if(IsLongBreakout(
            context,
            range_high))
        {
         return BuildLongSignal(
            context,
            range_high,
            range_low,
            signal);
        }

      if(IsShortBreakout(
            context,
            range_low))
        {
         return BuildShortSignal(
            context,
            range_high,
            range_low,
            signal);
        }

      return false;
     }

   //+----------------------------------------------------------------+
   //| Accessors                                                     |
   //+----------------------------------------------------------------+
   bool IsInitialized() const
     {
      return m_initialized;
     }

   double MinimumScore() const
     {
      return m_min_breakout_score;
     }

   double TargetRR() const
     {
      return m_target_rr;
     }

   int RangeLookback() const
     {
      return m_range_lookback;
     }
  };

#endif