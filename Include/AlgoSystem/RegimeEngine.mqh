#ifndef __ALGOSYSTEM_REGIMEENGINE_MQH__
#define __ALGOSYSTEM_REGIMEENGINE_MQH__

#include "Interfaces.mqh"

//+------------------------------------------------------------------+
//| Regime Engine                                                    |
//|                                                                  |
//| Detects market state from CLOSED-BAR features and recent price  |
//| structure.                                                      |
//|                                                                  |
//| Does NOT:                                                        |
//| - generate trade signals                                         |
//| - calculate position size                                        |
//| - send orders                                                    |
//| - modify positions                                               |
//+------------------------------------------------------------------+
class CRegimeEngine : public IRegimeEngine
  {
private:

   int    m_adx_trend_threshold;

   double m_high_volatility_ratio;
   double m_low_volatility_ratio;

   int    m_range_lookback;
   double m_breakout_buffer_atr;

   double m_range_width_atr_multiplier;

   double m_min_trend_ema_separation_atr;

   bool   m_initialized;

   //+----------------------------------------------------------------+
   //| Validate configuration                                         |
   //+----------------------------------------------------------------+
   bool ValidateParameters() const
     {
      if(m_adx_trend_threshold<=0)
         return false;

      if(m_high_volatility_ratio<=0.0)
         return false;

      if(m_low_volatility_ratio<=0.0)
         return false;

      if(m_low_volatility_ratio>=m_high_volatility_ratio)
         return false;

      if(m_range_lookback<5)
         return false;

      if(m_breakout_buffer_atr<0.0)
         return false;

      if(m_range_width_atr_multiplier<=0.0)
         return false;

      if(m_min_trend_ema_separation_atr<0.0)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Calculate average ATR over recent CLOSED bars                 |
   //+----------------------------------------------------------------+
   bool GetAverageATR(const string symbol,
                      ENUM_TIMEFRAMES timeframe,
                      const int shift,
                      const int period,
                      double &average_atr) const
     {
      average_atr=0.0;

      if(period<=0)
         return false;

      // The Feature Engine already provides current ATR.
      // Here we intentionally calculate historical ATR from
      // true range so Regime Engine does not own another indicator
      // handle.

      int required=period+1;

      MqlRates rates[];

      ArrayResize(rates,required);

      ResetLastError();

      int copied=CopyRates(symbol,
                           timeframe,
                           shift,
                           required,
                           rates);

      if(copied!=required)
         return false;

      double sum=0.0;
      int count=0;

      for(int i=1; i<required; i++)
        {
         double high=rates[i].high;
         double low=rates[i].low;
         double previous_close=rates[i-1].close;

         if(high<=0.0 ||
            low<=0.0 ||
            previous_close<=0.0)
            return false;

         double tr1=high-low;
         double tr2=MathAbs(high-previous_close);
         double tr3=MathAbs(low-previous_close);

         double true_range=MathMax(tr1,
                             MathMax(tr2,tr3));

         if(true_range<=0.0)
            return false;

         sum+=true_range;
         count++;
        }

      if(count<=0)
         return false;

      average_atr=sum/(double)count;

      return (MathIsValidNumber(average_atr) &&
              average_atr>0.0);
     }

   //+----------------------------------------------------------------+
   //| Calculate recent price range                                   |
   //+----------------------------------------------------------------+
   bool GetRecentRange(const string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       const int lookback,
                       double &range_high,
                       double &range_low) const
     {
      range_high=0.0;
      range_low=0.0;

      if(lookback<2)
         return false;

      MqlRates rates[];

      ArrayResize(rates,lookback);

      ResetLastError();

      // shift=2 excludes both the current/forming bar and
      // the latest closed signal bar from the range.
      int copied=CopyRates(symbol,
                           timeframe,
                           2,
                           lookback,
                           rates);

      if(copied!=lookback)
         return false;

      range_high=rates[0].high;
      range_low=rates[0].low;

      for(int i=1; i<lookback; i++)
        {
         if(rates[i].high>range_high)
            range_high=rates[i].high;

         if(rates[i].low<range_low)
            range_low=rates[i].low;
        }

      if(range_high<=range_low)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect breakout                                                 |
   //+----------------------------------------------------------------+
bool IsBreakout(const MarketSnapshot &market,
                const FeatureSet &features) const
  {
   if(!market.valid || !features.valid)
      return false;

   if(features.atr<=0.0 || m_range_lookback<5)
      return false;

   MqlRates previous[];
   ArrayResize(previous,m_range_lookback);

   ResetLastError();

   // shift=2:
   // only bars BEFORE the signal/breakout candle
   int copied=CopyRates(
      market.symbol,
      market.timeframe,
      2,
      m_range_lookback,
      previous);

   if(copied!=m_range_lookback)
      return false;

   double prior_high=previous[0].high;
   double prior_low=previous[0].low;

   for(int i=1;i<m_range_lookback;i++)
     {
      if(previous[i].high>prior_high)
         prior_high=previous[i].high;

      if(previous[i].low<prior_low)
         prior_low=previous[i].low;
     }

   double buffer=
      features.atr*m_breakout_buffer_atr;

   double close=market.closed_bar.close;

   bool upside_break=
      close>prior_high+buffer;

   bool downside_break=
      close<prior_low-buffer;

   if(!upside_break && !downside_break)
      return false;

   double candle_range=
      market.closed_bar.high-
      market.closed_bar.low;

   if(candle_range<features.atr)
      return false;

   return true;
  }

   //+----------------------------------------------------------------+
   //| Detect range                                                    |
   //+----------------------------------------------------------------+
   bool IsRange(const MarketSnapshot &market,
                const FeatureSet &features) const
     {
      if(!market.valid ||
         !features.valid)
         return false;

      if(features.atr<=0.0)
         return false;

      double high;
      double low;

      if(!GetRecentRange(market.symbol,
                         market.timeframe,
                         m_range_lookback,
                         high,
                         low))
         return false;

      double width=high-low;

      if(width<=0.0)
         return false;

      // A relatively compressed structure combined with
      // weak trend strength is treated as a range.
      bool compressed=
         (width<=
          features.atr*m_range_width_atr_multiplier);

      bool weak_trend=
         (features.adx<
          (double)m_adx_trend_threshold);

      return compressed && weak_trend;
     }

   //+----------------------------------------------------------------+
   //| Detect trend up                                                |
   //+----------------------------------------------------------------+
   bool IsTrendUp(const FeatureSet &features) const
     {
      if(!features.valid)
         return false;

      if(features.adx<
         (double)m_adx_trend_threshold)
         return false;

      if(features.ema_fast<=features.ema_slow)
         return false;

      if(features.ema_slow<=features.ema_long)
         return false;

      if(features.atr<=0.0)
         return false;

      double separation=
         features.ema_fast-features.ema_slow;

      if(separation<
         features.atr*m_min_trend_ema_separation_atr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect trend down                                              |
   //+----------------------------------------------------------------+
   bool IsTrendDown(const FeatureSet &features) const
     {
      if(!features.valid)
         return false;

      if(features.adx<
         (double)m_adx_trend_threshold)
         return false;

      if(features.ema_fast>=features.ema_slow)
         return false;

      if(features.ema_slow>=features.ema_long)
         return false;

      if(features.atr<=0.0)
         return false;

      double separation=
         features.ema_slow-features.ema_fast;

      if(separation<
         features.atr*m_min_trend_ema_separation_atr)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect volatility regime                                       |
   //+----------------------------------------------------------------+
   ENUM_REGIME_TYPE DetectVolatility(const MarketSnapshot &market,
                                      const FeatureSet &features) const
     {
      if(!market.valid ||
         !features.valid)
         return REGIME_UNCERTAIN;

      if(features.atr<=0.0)
         return REGIME_UNCERTAIN;

      double average_atr;

      if(!GetAverageATR(market.symbol,
                        market.timeframe,
                        2,
                        m_range_lookback,
                        average_atr))
         return REGIME_UNCERTAIN;

      if(average_atr<=0.0)
         return REGIME_UNCERTAIN;

      double ratio=
         features.atr/average_atr;

      if(ratio>=m_high_volatility_ratio)
         return REGIME_HIGH_VOLATILITY;

      if(ratio<=m_low_volatility_ratio)
         return REGIME_LOW_VOLATILITY;

      return REGIME_UNKNOWN;
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CRegimeEngine()
     {
      m_adx_trend_threshold=25;

      m_high_volatility_ratio=1.50;
      m_low_volatility_ratio=0.70;

      m_range_lookback=20;

      m_breakout_buffer_atr=0.10;

      m_range_width_atr_multiplier=4.0;

      m_min_trend_ema_separation_atr=0.25;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Configuration                                                  |
   //+----------------------------------------------------------------+
   void SetParameters(const int adx_threshold,
                      const double high_volatility_ratio,
                      const double low_volatility_ratio,
                      const int range_lookback,
                      const double breakout_buffer_atr,
                      const double range_width_atr_multiplier,
                      const double min_trend_ema_separation_atr)
     {
      m_adx_trend_threshold=adx_threshold;

      m_high_volatility_ratio=
         high_volatility_ratio;

      m_low_volatility_ratio=
         low_volatility_ratio;

      m_range_lookback=
         range_lookback;

      m_breakout_buffer_atr=
         breakout_buffer_atr;

      m_range_width_atr_multiplier=
         range_width_atr_multiplier;

      m_min_trend_ema_separation_atr=
         min_trend_ema_separation_atr;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| IRegimeEngine initialization                                  |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Detect regime                                                  |
   //+----------------------------------------------------------------+
   virtual ENUM_REGIME_TYPE Detect(
      const MarketSnapshot &market,
      const FeatureSet &features) override
     {
      if(!m_initialized)
         return REGIME_UNCERTAIN;

      if(!market.valid ||
         !features.valid)
         return REGIME_UNCERTAIN;

      if(features.atr<=0.0 ||
         features.adx<0.0)
         return REGIME_UNCERTAIN;

      // ------------------------------------------------------------
      // Priority 1: structural breakout
      // ------------------------------------------------------------
      if(IsBreakout(market,features))
         return REGIME_BREAKOUT;

      // ------------------------------------------------------------
      // Priority 2: strong trend
      // ------------------------------------------------------------
      bool trend_up=
         IsTrendUp(features);

      bool trend_down=
         IsTrendDown(features);

      if(trend_up && !trend_down)
         return REGIME_TREND_UP;

      if(trend_down && !trend_up)
         return REGIME_TREND_DOWN;

      // ------------------------------------------------------------
      // Priority 3: compressed range
      // ------------------------------------------------------------
      if(IsRange(market,features))
         return REGIME_RANGE;

      // ------------------------------------------------------------
      // Priority 4: abnormal volatility
      // ------------------------------------------------------------
      ENUM_REGIME_TYPE volatility=
         DetectVolatility(market,features);

      if(volatility==REGIME_HIGH_VOLATILITY)
         return REGIME_HIGH_VOLATILITY;

      if(volatility==REGIME_LOW_VOLATILITY)
         return REGIME_LOW_VOLATILITY;

      // ------------------------------------------------------------
      // Anything ambiguous becomes UNCERTAIN.
      // Conservative by design.
      // ------------------------------------------------------------
      return REGIME_UNCERTAIN;
     }

   //+----------------------------------------------------------------+
   //| Accessors                                                     |
   //+----------------------------------------------------------------+
   int ADXThreshold() const
     {
      return m_adx_trend_threshold;
     }

   double HighVolatilityRatio() const
     {
      return m_high_volatility_ratio;
     }

   double LowVolatilityRatio() const
     {
      return m_low_volatility_ratio;
     }

   int RangeLookback() const
     {
      return m_range_lookback;
     }

   bool IsInitialized() const
     {
      return m_initialized;
     }
  };

#endif