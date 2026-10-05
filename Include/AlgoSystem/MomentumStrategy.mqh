#ifndef __ALGOSYSTEM_MOMENTUMSTRATEGY_MQH__
#define __ALGOSYSTEM_MOMENTUMSTRATEGY_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Momentum Strategy                                                |
//|                                                                  |
//| Responsibility:                                                 |
//| - detect directional momentum                                    |
//| - confirm momentum with MACD / RSI / ROC                        |
//| - confirm candle expansion / strength                            |
//| - use volume participation                                       |
//| - reject excessive extension                                     |
//| - produce StrategySignal                                         |
//|                                                                  |
//| Does NOT:                                                        |
//| - calculate final portfolio risk                                 |
//| - send orders                                                    |
//| - manage open positions                                          |
//+------------------------------------------------------------------+
class CMomentumStrategy : public IStrategy
  {
private:

   double m_min_rsi_long;
   double m_max_rsi_long;

   double m_min_rsi_short;
   double m_max_rsi_short;

   double m_min_roc_long;
   double m_max_roc_long;

   double m_min_roc_short;
   double m_max_roc_short;

   double m_min_volume_ratio;
   double m_min_candle_strength;

   double m_min_range_atr;
   double m_max_extension_atr;

   double m_stop_atr_multiplier;
   double m_structure_buffer_atr;
   double m_target_rr;

   double m_min_signal_score;

   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Reset signal                                                   |
   //+----------------------------------------------------------------+
   void ResetSignal(StrategySignal &signal) const
     {
      signal.valid=false;

      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_MOMENTUM;

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
      if(m_min_rsi_long<0.0 ||
         m_max_rsi_long>100.0 ||
         m_min_rsi_long>=m_max_rsi_long)
         return false;

      if(m_min_rsi_short<0.0 ||
         m_max_rsi_short>100.0 ||
         m_min_rsi_short>=m_max_rsi_short)
         return false;

      if(m_min_roc_long>m_max_roc_long)
         return false;

      if(m_min_roc_short>m_max_roc_short)
         return false;

      if(m_min_volume_ratio<=0.0)
         return false;

      if(m_min_candle_strength<0.0 ||
         m_min_candle_strength>1.0)
         return false;

      if(m_min_range_atr<=0.0)
         return false;

      if(m_max_extension_atr<=0.0)
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
   //| Check directional regime                                      |
   //+----------------------------------------------------------------+
   bool IsLongRegime(const StrategyContext &context) const
     {
      if(context.regime==REGIME_TREND_UP)
         return true;

      if(context.regime==REGIME_BREAKOUT &&
         context.features.ema_fast>
         context.features.ema_slow)
         return true;

      return false;
     }

   bool IsShortRegime(const StrategyContext &context) const
     {
      if(context.regime==REGIME_TREND_DOWN)
         return true;

      if(context.regime==REGIME_BREAKOUT &&
         context.features.ema_fast<
         context.features.ema_slow)
         return true;

      return false;
     }

   //+----------------------------------------------------------------+
   //| Candle direction/strength                                      |
   //+----------------------------------------------------------------+
   bool IsBullishMomentumCandle(
      const StrategyContext &context) const
     {
      if(context.market.closed_bar.close<=
         context.market.closed_bar.open)
         return false;

      if(context.features.candle_strength<
         m_min_candle_strength)
         return false;

      if(context.features.candle_range<=0.0)
         return false;

      double close_position=
         (context.market.closed_bar.close-
          context.market.closed_bar.low)/
         context.features.candle_range;

      return (close_position>=0.70);
     }

   bool IsBearishMomentumCandle(
      const StrategyContext &context) const
     {
      if(context.market.closed_bar.close>=
         context.market.closed_bar.open)
         return false;

      if(context.features.candle_strength<
         m_min_candle_strength)
         return false;

      if(context.features.candle_range<=0.0)
         return false;

      double close_position=
         (context.market.closed_bar.high-
          context.market.closed_bar.close)/
         context.features.candle_range;

      return (close_position>=0.70);
     }

   //+----------------------------------------------------------------+
   //| Avoid excessive extension                                      |
   //+----------------------------------------------------------------+
   bool IsLongTooExtended(
      const StrategyContext &context) const
     {
      if(context.features.atr<=0.0)
         return true;

      double extension=
         (context.market.closed_bar.close-
          context.features.ema_fast)/
         context.features.atr;

      return (extension>m_max_extension_atr);
     }

   bool IsShortTooExtended(
      const StrategyContext &context) const
     {
      if(context.features.atr<=0.0)
         return true;

      double extension=
         (context.features.ema_fast-
          context.market.closed_bar.close)/
         context.features.atr;

      return (extension>m_max_extension_atr);
     }

   //+----------------------------------------------------------------+
   //| Long momentum setup                                            |
   //+----------------------------------------------------------------+
   bool IsLongSetup(
      const StrategyContext &context) const
     {
      if(!IsLongRegime(context))
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.ema_fast<=
         context.features.ema_slow)
         return false;

      if(context.features.macd_main<=
         context.features.macd_signal)
         return false;

      if(context.features.rsi<m_min_rsi_long ||
         context.features.rsi>m_max_rsi_long)
         return false;

      if(context.features.roc<m_min_roc_long ||
         context.features.roc>m_max_roc_long)
         return false;

      if(context.features.volume_ratio<
         m_min_volume_ratio)
         return false;

      if(context.features.candle_range<
         context.features.atr*m_min_range_atr)
         return false;

      if(!IsBullishMomentumCandle(context))
         return false;

      if(IsLongTooExtended(context))
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Short momentum setup                                           |
   //+----------------------------------------------------------------+
   bool IsShortSetup(
      const StrategyContext &context) const
     {
      if(!IsShortRegime(context))
         return false;

      if(context.features.atr<=0.0)
         return false;

      if(context.features.ema_fast>=
         context.features.ema_slow)
         return false;

      if(context.features.macd_main>=
         context.features.macd_signal)
         return false;

      if(context.features.rsi<m_min_rsi_short ||
         context.features.rsi>m_max_rsi_short)
         return false;

      if(context.features.roc<m_min_roc_short ||
         context.features.roc>m_max_roc_short)
         return false;

      if(context.features.volume_ratio<
         m_min_volume_ratio)
         return false;

      if(context.features.candle_range<
         context.features.atr*m_min_range_atr)
         return false;

      if(!IsBearishMomentumCandle(context))
         return false;

      if(IsShortTooExtended(context))
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Long score                                                     |
   //+----------------------------------------------------------------+
   double ScoreLong(
      const StrategyContext &context) const
     {
      double score=0.0;

      // Trend alignment: 20
      if(context.features.ema_fast>
         context.features.ema_slow &&
         context.features.ema_slow>
         context.features.ema_long)
         score+=20.0;
      else if(context.features.ema_fast>
              context.features.ema_slow)
         score+=12.0;

      // MACD: 15
      if(context.features.macd_main>
         context.features.macd_signal)
         score+=15.0;

      // RSI: 15
      if(context.features.rsi>=55.0 &&
         context.features.rsi<=65.0)
         score+=15.0;
      else if(context.features.rsi>=m_min_rsi_long &&
              context.features.rsi<=m_max_rsi_long)
         score+=10.0;

      // ROC: 15
      if(context.features.roc>=1.0)
         score+=15.0;
      else if(context.features.roc>0.0)
         score+=10.0;

      // ATR expansion / candle range: 10
      double range_ratio=
         CAlgoUtils::SafeDivide(
            context.features.candle_range,
            context.features.atr,
            0.0);

      if(range_ratio>=1.50)
         score+=10.0;
      else if(range_ratio>=1.00)
         score+=7.0;

      // Volume: 10
      if(context.features.volume_ratio>=1.50)
         score+=10.0;
      else if(context.features.volume_ratio>=1.20)
         score+=7.0;

      // Candle strength: 15
      score+=
         CAlgoUtils::Clamp(
            context.features.candle_strength,
            0.0,
            1.0)*15.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Short score                                                    |
   //+----------------------------------------------------------------+
   double ScoreShort(
      const StrategyContext &context) const
     {
      double score=0.0;

      if(context.features.ema_fast<
         context.features.ema_slow &&
         context.features.ema_slow<
         context.features.ema_long)
         score+=20.0;
      else if(context.features.ema_fast<
              context.features.ema_slow)
         score+=12.0;

      if(context.features.macd_main<
         context.features.macd_signal)
         score+=15.0;

      if(context.features.rsi>=35.0 &&
         context.features.rsi<=45.0)
         score+=15.0;
      else if(context.features.rsi>=m_min_rsi_short &&
              context.features.rsi<=m_max_rsi_short)
         score+=10.0;

      if(context.features.roc<=-1.0)
         score+=15.0;
      else if(context.features.roc<0.0)
         score+=10.0;

      double range_ratio=
         CAlgoUtils::SafeDivide(
            context.features.candle_range,
            context.features.atr,
            0.0);

      if(range_ratio>=1.50)
         score+=10.0;
      else if(range_ratio>=1.00)
         score+=7.0;

      if(context.features.volume_ratio>=1.50)
         score+=10.0;
      else if(context.features.volume_ratio>=1.20)
         score+=7.0;

      score+=
         CAlgoUtils::Clamp(
            context.features.candle_strength,
            0.0,
            1.0)*15.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

   //+----------------------------------------------------------------+
   //| Build Long levels                                              |
   //+----------------------------------------------------------------+
   bool BuildLongLevels(
      const StrategyContext &context,
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

      return (target>entry);
     }

   //+----------------------------------------------------------------+
   //| Build Short levels                                             |
   //+----------------------------------------------------------------+
   bool BuildShortLevels(
      const StrategyContext &context,
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

      return (target>0.0 &&
              target<entry);
     }

   //+----------------------------------------------------------------+
   //| Signal ID                                                      |
   //+----------------------------------------------------------------+
   string BuildSignalId(
      const StrategyContext &context) const
     {
      return context.market.symbol+
             "|MOMENTUM|"+
             IntegerToString(
                (int)context.market.timeframe)+
             "|"+
             TimeToString(
                context.market.closed_bar.time,
                TIME_DATE|TIME_MINUTES|TIME_SECONDS);
     }

   //+----------------------------------------------------------------+
   //| Long signal                                                    |
   //+----------------------------------------------------------------+
   bool BuildLongSignal(
      const StrategyContext &context,
      StrategySignal &signal) const
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
      signal.strategy=STRATEGY_MOMENTUM;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=context.regime;

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
         "Momentum + MACD + RSI + ROC + Volume";

      return true;
     }

   //+----------------------------------------------------------------+
   //| Short signal                                                   |
   //+----------------------------------------------------------------+
   bool BuildShortSignal(
      const StrategyContext &context,
      StrategySignal &signal) const
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
      signal.strategy=STRATEGY_MOMENTUM;

      signal.symbol=context.market.symbol;
      signal.timeframe=context.market.timeframe;

      signal.regime=context.regime;

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
         "Momentum + MACD + RSI + ROC + Volume";

      return true;
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CMomentumStrategy()
     {
      m_min_rsi_long=55.0;
      m_max_rsi_long=75.0;

      m_min_rsi_short=25.0;
      m_max_rsi_short=45.0;

      m_min_roc_long=0.0;
      m_max_roc_long=6.0;

      m_min_roc_short=-6.0;
      m_max_roc_short=0.0;

      m_min_volume_ratio=1.20;
      m_min_candle_strength=0.55;

      m_min_range_atr=0.80;
      m_max_extension_atr=1.50;

      m_stop_atr_multiplier=1.50;
      m_structure_buffer_atr=0.20;

      m_target_rr=1.50;
      m_min_signal_score=70.0;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Initialize                                                     |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;
      return true;
     }

   //+----------------------------------------------------------------+
   //| ID                                                             |
   //+----------------------------------------------------------------+
   virtual ENUM_STRATEGY_ID Id() const override
     {
      return STRATEGY_MOMENTUM;
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

      if(!context.market.valid ||
         !context.features.valid)
         return false;

      if(IsLongSetup(context))
         return BuildLongSignal(
            context,
            signal);

      if(IsShortSetup(context))
         return BuildShortSignal(
            context,
            signal);

      return false;
     }

   bool IsInitialized() const
     {
      return m_initialized;
     }

   double MinimumScore() const
     {
      return m_min_signal_score;
     }

   double TargetRR() const
     {
      return m_target_rr;
     }
  };

#endif