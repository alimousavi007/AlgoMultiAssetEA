#ifndef __ALGOSYSTEM_DIVERGENCE_MQH__
#define __ALGOSYSTEM_DIVERGENCE_MQH__

#include "HybridTypes.mqh"
#include "Indicators.mqh"

//+------------------------------------------------------------------+
//| Divergence Engine                                                 |
//|                                                                  |
//| Detects regular and hidden divergence using confirmed pivots.    |
//| Uses RSI and MACD histogram as divergence sources.               |
//+------------------------------------------------------------------+
class CDivergenceEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;

    int                m_rsi_period;
    int                m_macd_fast;
    int                m_macd_slow;
    int                m_macd_signal_period;
   int                m_lookback;
   double             m_pivot_tolerance_percent;
   int                m_max_age_bars;

   bool               m_initialized;
   datetime           m_last_bar_time;

   ENUM_DIVERGENCE_TYPE m_last_divergence;
   datetime            m_last_divergence_time;
   datetime            m_last_pivot_time;

   int m_rsi_handle;
   int m_macd_main_handle;
   int m_macd_signal_handle;

   double m_rsi[];
   double m_macd_main[];
   double m_macd_signal[];
   double m_macd_hist[];

private:
   bool CreateHandles()
     {
      ResetLastError();

       m_rsi_handle=iRSI(
           m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      if(m_rsi_handle==INVALID_HANDLE)
         return false;

       m_macd_main_handle=iMACD(
          m_symbol, m_timeframe,
          m_macd_fast, m_macd_slow, m_macd_signal_period,
          PRICE_CLOSE);
      if(m_macd_main_handle==INVALID_HANDLE)
         return false;

      return true;
     }

   void ReleaseHandles()
     {
      if(m_rsi_handle!=INVALID_HANDLE)
         IndicatorRelease(m_rsi_handle);
      if(m_macd_main_handle!=INVALID_HANDLE)
         IndicatorRelease(m_macd_main_handle);

      m_rsi_handle=INVALID_HANDLE;
      m_macd_main_handle=INVALID_HANDLE;
     }

   bool CopyIndicatorData(int lookback)
     {
      if(m_rsi_handle==INVALID_HANDLE || m_macd_main_handle==INVALID_HANDLE)
         return false;

      ResetLastError();

      int copied_rsi=CopyBuffer(m_rsi_handle, 0, 0, lookback, m_rsi);
      if(copied_rsi<=0)
         return false;

      double macd_main[], macd_signal[], macd_hist[];
      int copied_macd=CopyBuffer(m_macd_main_handle, 0, 0, lookback, macd_main);
      int copied_signal=CopyBuffer(m_macd_main_handle, 1, 0, lookback, macd_signal);
      int copied_hist=CopyBuffer(m_macd_main_handle, 2, 0, lookback, macd_hist);

      if(copied_macd<=0 || copied_signal<=0 || copied_hist<=0)
         return false;

      ArrayCopy(m_macd_main, macd_main);
      ArrayCopy(m_macd_signal, macd_signal);
      ArrayCopy(m_macd_hist, macd_hist);

      ArraySetAsSeries(m_rsi, true);
      ArraySetAsSeries(m_macd_main, true);
      ArraySetAsSeries(m_macd_signal, true);
      ArraySetAsSeries(m_macd_hist, true);

      return true;
     }

   bool FindPivotHigh(const double& array[],
                      int center,
                      int left,
                      int right,
                      int& out_idx) const
     {
      int size=ArraySize(array);
      if(center<left || center+right>=size)
         return false;

      double val=array[center];
      for(int i=1; i<=left; i++)
        {
         if(array[center-i] > val + 1e-10)
            return false;
        }
      for(int i=1; i<=right; i++)
        {
         if(array[center+i] > val + 1e-10)
            return false;
        }

      out_idx=center;
      return true;
     }

   bool FindPivotLow(const double& array[],
                     int center,
                     int left,
                     int right,
                     int& out_idx) const
     {
      int size=ArraySize(array);
      if(center<left || center+right>=size)
         return false;

      double val=array[center];
      for(int i=1; i<=left; i++)
        {
         if(array[center-i] < val - 1e-10)
            return false;
        }
      for(int i=1; i<=right; i++)
        {
         if(array[center+i] < val - 1e-10)
            return false;
        }

      out_idx=center;
      return true;
     }

   bool FindRsiPivotLow(int start_idx,
                        int left,
                        int right,
                        int& pivot_idx) const
     {
      int size=ArraySize(m_rsi);
      for(int i=start_idx; i<size; i++)
        {
         if(FindPivotLow(m_rsi, i, left, right, pivot_idx))
            return true;
        }
      return false;
     }

   bool FindRsiPivotHigh(int start_idx,
                        int left,
                        int right,
                        int& pivot_idx) const
     {
      int size=ArraySize(m_rsi);
      for(int i=start_idx; i<size; i++)
        {
         if(FindPivotHigh(m_rsi, i, left, right, pivot_idx))
            return true;
        }
      return false;
     }

public:
   CDivergenceEngine()
     {
      m_symbol="";
      m_timeframe=PERIOD_H1;
      m_rsi_period=14;
      m_macd_fast=12;
      m_macd_slow=26;
      m_macd_signal_period=9;
      m_lookback=100;
      m_pivot_tolerance_percent=0.02;
      m_max_age_bars=30;
      m_initialized=false;
      m_last_bar_time=0;
      m_last_divergence=DIVERGENCE_NONE;
      m_last_divergence_time=0;
      m_last_pivot_time=0;
      m_rsi_handle=INVALID_HANDLE;
      m_macd_main_handle=INVALID_HANDLE;
     }

   void SetParameters(int rsi_period,
                      int macd_fast,
                      int macd_slow,
                      int macd_signal,
                      double pivot_tolerance_percent,
                      int max_age_bars)
     {
      m_rsi_period=rsi_period;
      m_macd_fast=macd_fast;
      m_macd_slow=macd_slow;
      m_macd_signal_period=macd_signal;
      m_pivot_tolerance_percent=pivot_tolerance_percent;
      m_max_age_bars=max_age_bars;
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_initialized=true;
      m_last_bar_time=0;

      ReleaseHandles();

      if(!CreateHandles())
        {
         m_initialized=false;
         return false;
        }

      return true;
     }

   ~CDivergenceEngine()
     {
      ReleaseHandles();
     }

   DivergenceFeatures Calculate(const MarketSnapshot& market,
                                const MqlRates& rates[])
     {
      DivergenceFeatures result;
      result.valid=false;
      result.divergence=DIVERGENCE_NONE;
      result.pivot_time=0;
      result.bar_time=market.closed_bar_time;
      result.symbol=market.symbol;
      result.timeframe=market.timeframe;
      result.reason="";

      if(!m_initialized)
        {
         result.reason="Engine not initialized";
         return result;
        }

      int lookback=MathMax(m_lookback, 50);
      if(!CopyIndicatorData(lookback))
        {
         result.reason="Could not copy indicator data";
         return result;
        }

      int rsi_size=ArraySize(m_rsi);
      int price_size=ArraySize(rates);
      int min_size=MathMin(rsi_size, price_size);
      min_size=MathMin(min_size, lookback);

      if(min_size<10)
        {
         result.reason="Insufficient data for divergence ("+
                       IntegerToString(min_size)+")";
         return result;
        }

      double tolerance = market.properties.point *
                         m_pivot_tolerance_percent * 100;

      int pivot_left=3;
      int pivot_right=3;

      result.divergence=DIVERGENCE_NONE;

      for(int i=min_size-1; i>=pivot_right+2; i--)
        {
         int idx1, idx2;
         if(FindRsiPivotLow(i+1, pivot_left, pivot_right, idx1) &&
            FindRsiPivotLow(idx1+1, pivot_left, pivot_right, idx2))
           {
            if(idx2 < min_size && idx1 < min_size &&
               idx2 > idx1)
              {
               double price_low1=rates[min_size-1-idx1].low;
               double price_low2=rates[min_size-1-idx2].low;

               if(price_low2 > price_low1 &&
                  m_rsi[idx2] < m_rsi[idx1])
                 {
                  if(rates[min_size-1-idx2].time >=
                     market.closed_bar_time - m_max_age_bars * PeriodSeconds(m_timeframe))
                    {
                     result.divergence=DIVERGENCE_REGULAR_BULLISH;
                     result.pivot_time=rates[min_size-1-idx2].time;
                     break;
                    }
                 }
              }
           }
        }

      if(result.divergence==DIVERGENCE_NONE)
        {
         for(int i=min_size-1; i>=pivot_right+2; i--)
           {
            int idx1, idx2;
            if(FindRsiPivotHigh(i+1, pivot_left, pivot_right, idx1) &&
               FindRsiPivotHigh(idx1+1, pivot_left, pivot_right, idx2))
              {
               if(idx2 < min_size && idx1 < min_size &&
                  idx2 > idx1)
                 {
                  double price_high1=rates[min_size-1-idx1].high;
                  double price_high2=rates[min_size-1-idx2].high;

                  if(price_high2 < price_high1 &&
                     m_rsi[idx2] > m_rsi[idx1])
                    {
                     if(rates[min_size-1-idx2].time >=
                        market.closed_bar_time - m_max_age_bars * PeriodSeconds(m_timeframe))
                       {
                        result.divergence=DIVERGENCE_REGULAR_BEARISH;
                        result.pivot_time=rates[min_size-1-idx2].time;
                        break;
                       }
                    }
                 }
              }
           }
        }

      if(result.divergence==DIVERGENCE_NONE)
        {
         for(int i=min_size-1; i>=pivot_right+2; i--)
           {
            int idx1, idx2;
            if(FindRsiPivotHigh(i+1, pivot_left, pivot_right, idx1) &&
               FindRsiPivotLow(idx1+1, pivot_left, pivot_right, idx2))
              {
               if(idx2 < min_size &&
                  idx2 > idx1)
                 {
                  double price_high=rates[min_size-1-idx1].high;
                  double price_low=rates[min_size-1-idx2].low;

                  if(price_low < price_high &&
                     m_rsi[idx2] > m_rsi[idx1])
                    {
                     if(rates[min_size-1-idx2].time >=
                        market.closed_bar_time - m_max_age_bars * PeriodSeconds(m_timeframe))
                       {
                        result.divergence=DIVERGENCE_HIDDEN_BULLISH;
                        result.pivot_time=rates[min_size-1-idx2].time;
                        break;
                       }
                    }
                 }
              }
           }
        }

      if(result.divergence==DIVERGENCE_NONE)
        {
         for(int i=min_size-1; i>=pivot_right+2; i--)
           {
            int idx1, idx2;
            if(FindRsiPivotLow(i+1, pivot_left, pivot_right, idx1) &&
               FindRsiPivotHigh(idx1+1, pivot_left, pivot_right, idx2))
              {
               if(idx2 < min_size &&
                  idx2 > idx1)
                 {
                  double price_low=rates[min_size-1-idx1].low;
                  double price_high=rates[min_size-1-idx2].high;

                  if(price_high > price_low &&
                     m_rsi[idx2] < m_rsi[idx1])
                    {
                     if(rates[min_size-1-idx2].time >=
                        market.closed_bar_time - m_max_age_bars * PeriodSeconds(m_timeframe))
                       {
                        result.divergence=DIVERGENCE_HIDDEN_BEARISH;
                        result.pivot_time=rates[min_size-1-idx2].time;
                        break;
                       }
                    }
                 }
              }
           }
        }

      if(result.divergence==DIVERGENCE_NONE)
        {
         result.reason="No valid divergence found";
        }
      else
        {
         result.reason="Divergence detected: "+EnumToString(result.divergence);
        }

      result.valid=true;
      m_last_bar_time=result.bar_time;
      m_last_divergence=result.divergence;
      m_last_divergence_time=result.pivot_time;
      m_last_pivot_time=result.pivot_time;

      return result;
     }

   bool IsStale(const datetime current_time,
                int bars_expiry) const
     {
      if(m_last_divergence_time==0)
         return true;

      return (current_time - m_last_divergence_time) >
             (datetime)(bars_expiry * PeriodSeconds(m_timeframe));
     }
  };

#endif