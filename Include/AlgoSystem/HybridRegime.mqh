#ifndef __ALGOSYSTEM_HYBRID_REGIME_MQH__
#define __ALGOSYSTEM_HYBRID_REGIME_MQH__

#include "HybridTypes.mqh"
#include "Indicators.mqh"

//+------------------------------------------------------------------+
//| Hybrid Regime Engine                                             |
//|                                                                  |
//| Classifies market regime using ADX, volatility ratio,          |
//| directional efficiency, and structural persistence.            |
//| Implements hysteresis to avoid excessive state switching.       |
//+------------------------------------------------------------------+
class CHybridRegimeEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;

   int                m_adx_period;
   double             m_trend_threshold;
   double             m_high_vol_ratio;
   double             m_low_vol_ratio;
   int                m_range_lookback;
   int                m_hysteresis_bars;

   double             m_tick_size;
   double             m_point;
   int                m_digits;

   bool               m_initialized;

   ENUM_HYBRID_REGIME m_current_regime;
   int                m_regime_stable_count;
   datetime           m_last_bar_time;

   int m_adx_handle;
   int m_atr_handle;

   double m_adx_buf[];
   double m_atr_buf[];
   double m_ema_buf[];

public:
   CHybridRegimeEngine()
     {
      m_symbol="";
      m_timeframe=PERIOD_H1;
      m_adx_period=14;
      m_trend_threshold=25.0;
      m_high_vol_ratio=1.50;
      m_low_vol_ratio=0.70;
      m_range_lookback=20;
      m_hysteresis_bars=3;
      m_tick_size=0;
      m_point=0;
      m_digits=0;
      m_initialized=false;
      m_current_regime=HYBRID_REGIME_INSUFFICIENT_DATA;
      m_regime_stable_count=0;
      m_last_bar_time=0;
      m_adx_handle=INVALID_HANDLE;
      m_atr_handle=INVALID_HANDLE;
     }

   ~CHybridRegimeEngine()
     {
      ReleaseHandles();
     }

   void SetParameters(int adx_period,
                      double trend_threshold,
                      double high_vol_ratio,
                      double low_vol_ratio,
                      int range_lookback,
                      int hysteresis_bars)
     {
      m_adx_period=adx_period;
      m_trend_threshold=trend_threshold;
      m_high_vol_ratio=high_vol_ratio;
      m_low_vol_ratio=low_vol_ratio;
      m_range_lookback=range_lookback;
      m_hysteresis_bars=hysteresis_bars;
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_initialized=true;

      ReleaseHandles();

      ResetLastError();
      m_adx_handle=iADX(symbol, timeframe, m_adx_period);
      if(m_adx_handle==INVALID_HANDLE)
         return false;

      m_atr_handle=iATR(symbol, timeframe, m_adx_period);
      if(m_atr_handle==INVALID_HANDLE)
         {
          ReleaseHandles();
          return false;
         }

      ResetLastError();
      m_tick_size=SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(m_tick_size<=0)
         m_tick_size=SymbolInfoDouble(symbol, SYMBOL_POINT);
      SymbolInfoDouble(symbol, SYMBOL_POINT, m_point);
      long digits=0;
      SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits);
      m_digits=(int)digits;

      return m_tick_size > 0;
     }

   double GetTickSize() const { return m_tick_size; }
   double GetPoint() const { return m_point; }
   int    GetDigits() const { return m_digits; }

private:
   void ReleaseHandles()
     {
      if(m_adx_handle!=INVALID_HANDLE)
         IndicatorRelease(m_adx_handle);
      if(m_atr_handle!=INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);

      m_adx_handle=INVALID_HANDLE;
      m_atr_handle=INVALID_HANDLE;
     }

   double GetADXValue() const
     {
      if(m_adx_handle==INVALID_HANDLE)
         return 0;

      double adx[];
      ResetLastError();
      int copied=CopyBuffer(m_adx_handle, 0, 0, 3, adx);
      if(copied<=0 || ArraySize(adx)==0)
         return 0;

      ArraySetAsSeries(adx, true);
      return adx[0];
     }

   double GetATRValue() const
     {
      if(m_atr_handle==INVALID_HANDLE)
         return 0;

      double atr[];
      ResetLastError();
      int copied=CopyBuffer(m_atr_handle, 0, 0, 3, atr);
      if(copied<=0 || ArraySize(atr)==0)
         return 0;

      ArraySetAsSeries(atr, true);
      return atr[0];
     }

    double CalculateEfficiency(const MqlRates& rates[], int lookback) const
     {
      int size=ArraySize(rates);
      if(size < lookback+1 || lookback<=0)
         return 0;

      double net_distance=MathAbs(rates[0].close - rates[lookback].close);
      double total_distance=0;

      for(int i=0; i<lookback; i++)
        {
         total_distance += MathAbs(rates[i].close - rates[i+1].close);
        }

      if(total_distance<=0)
         return 0;

      return net_distance / total_distance;
     }

    double CalculateVolatilityRatio(const MqlRates& rates[],
                                   double current_atr,
                                   int lookback) const
     {
      int size=ArraySize(rates);
      if(size < lookback+1 || lookback<=0 || current_atr<=0)
         return 1.0;

      double lookback_atr=0;
      for(int i=0; i<lookback && i<size-1; i++)
        {
         double tr1=rates[i].high - rates[i].low;
         double tr2=MathAbs(rates[i].high - rates[i+1].close);
         double tr3=MathAbs(rates[i].low - rates[i+1].close);
         double tr=MathMax(tr1, MathMax(tr2, tr3));
         lookback_atr += tr;
        }

      lookback_atr /= (double)lookback;

      if(lookback_atr<=0)
         return 1.0;

      return current_atr / lookback_atr;
     }

   ENUM_HYBRID_REGIME ClassifyRegime(double adx,
                                    double vol_ratio,
                                    double efficiency) const
     {
      if(adx > m_trend_threshold)
        {
         if(vol_ratio > m_high_vol_ratio && efficiency < 0.33)
            return HYBRID_REGIME_VOLATILITY_EXPANSION;
         return HYBRID_REGIME_TRENDING;
        }

      if(efficiency < 0.25)
        {
         if(vol_ratio < m_low_vol_ratio)
            return HYBRID_REGIME_COMPRESSION;
         return HYBRID_REGIME_RANGING;
        }

      if(vol_ratio < m_low_vol_ratio)
         return HYBRID_REGIME_TRANSITION;

      return HYBRID_REGIME_RANGING;
     }

public:
   RegimeFeatures Calculate(const MarketSnapshot& market,
                            const FeatureSet& features)
     {
      RegimeFeatures result;
      result.valid=false;
      result.regime=HYBRID_REGIME_INSUFFICIENT_DATA;
      result.regime_reason="";
      result.adx=0;
      result.volatility_ratio=0;
      result.range_width_atr=0;
      result.efficiency=0;
      result.bar_time=market.closed_bar_time;
      result.symbol=market.symbol;
      result.timeframe=market.timeframe;
      result.reason="";

      if(!m_initialized)
        {
         result.reason="Regime engine not initialized";
         return result;
        }

      if(market.closed_bar_time != m_last_bar_time)
        {
         m_last_bar_time=market.closed_bar_time;
         m_regime_stable_count=0;
        }

      double adx=GetADXValue();
      double atr=GetATRValue();

      if(adx<=0 || atr<=0)
        {
         result.reason="ADX or ATR unavailable";
         return result;
        }

      MqlRates rates[];
      ResetLastError();
       int copied=CopyRates(market.symbol, market.timeframe, 0, m_range_lookback+5, rates);
       if(copied<=0 || ArraySize(rates)<m_range_lookback+1)
         {
          result.reason="Insufficient bars for regime efficiency calculation";
          return result;
         }

       ArraySetAsSeries(rates, true);

      double efficiency=CalculateEfficiency(rates, m_range_lookback);
      double vol_ratio=CalculateVolatilityRatio(rates, atr, m_range_lookback);

      ENUM_HYBRID_REGIME new_regime=ClassifyRegime(adx, vol_ratio, efficiency);

      if(new_regime == m_current_regime)
        {
         m_regime_stable_count++;
        }
      else
        {
         m_current_regime=new_regime;
         m_regime_stable_count=0;
        }

      bool regime_confirmed = m_regime_stable_count >= m_hysteresis_bars ||
                              m_regime_stable_count == 0;

      result.regime=new_regime;
      result.adx=adx;
      result.volatility_ratio=vol_ratio;
      result.range_width_atr=vol_ratio;
      result.efficiency=efficiency;
      result.regime_reason="ADX="+DoubleToString(adx,1)+
                            " VR="+DoubleToString(vol_ratio,2)+
                            " EFF="+DoubleToString(efficiency,2);

      if(m_current_regime != new_regime)
         result.regime_reason += " [TRANSITIONING]";

      result.valid=true;
      result.reason="OK";

      return result;
     }

   ENUM_HYBRID_REGIME GetCurrentRegime() const
     {
      return m_current_regime;
     }

   void OnBarUpdate()
     {
      m_regime_stable_count++;
     }
  };

#endif