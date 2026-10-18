#ifndef __ALGOSYSTEM_LIQUIDITY_MQH__
#define __ALGOSYSTEM_LIQUIDITY_MQH__

#include "HybridTypes.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Liquidity and Market Structure Engine                             |
//|                                                                  |
//| Tracks confirmed swing highs/lows, equal highs/lows,             |
//| BOS/CHoCH, and liquidity sweep events.                           |
//+------------------------------------------------------------------+
class CLiquidityStructureEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;

   int                m_swing_lookback;
   int                m_equal_tolerance_points;
   int                m_max_level_age_bars;
   int                m_sweep_confirm_bars;

   double             m_tick_size;
   double             m_point;
   int                m_digits;

   bool               m_initialized;

   datetime           m_last_bar_time;
   bool               m_bar_processed;

   double             m_prev_equal_high;
   double             m_prev_equal_low;
   datetime           m_prev_equal_high_time;
   datetime           m_prev_equal_low_time;

   double             m_daily_high;
   double             m_daily_low;
   datetime           m_daily_session_time;

   double             m_weekly_high;
   double             m_weekly_low;
   datetime           m_weekly_session_time;

   ENUM_LIQUIDITY_EVENT m_last_event;
   datetime           m_event_time;
   double             m_event_level;
   datetime           m_event_expiry;
   bool               m_event_consumed;

   datetime           m_last_bos_time;
   bool               m_last_bos_long;
   bool               m_last_bos_short;
   datetime           m_last_choch_time;
   bool               m_current_choch;

public:
   CLiquidityStructureEngine()
     {
      m_symbol="";
      m_timeframe=PERIOD_H1;
      m_swing_lookback=5;
      m_equal_tolerance_points=3;
      m_max_level_age_bars=100;
      m_sweep_confirm_bars=3;
      m_tick_size=0;
      m_point=0;
      m_digits=0;
      m_initialized=false;
      m_last_bar_time=0;
      m_bar_processed=false;
      m_prev_equal_high=0;
      m_prev_equal_low=0;
      m_prev_equal_high_time=0;
      m_prev_equal_low_time=0;
      m_daily_high=0;
      m_daily_low=0;
      m_daily_session_time=0;
      m_weekly_high=0;
      m_weekly_low=0;
      m_weekly_session_time=0;
      m_last_event=LIQ_EVENT_NONE;
      m_event_time=0;
      m_event_level=0;
      m_event_expiry=0;
      m_event_consumed=false;
      m_last_bos_time=0;
      m_last_bos_long=false;
      m_last_bos_short=false;
      m_last_choch_time=0;
      m_current_choch=false;
     }

   void SetParameters(int swing_lookback,
                      int equal_tolerance_points,
                      int max_level_age_bars,
                      int sweep_confirm_bars)
     {
      m_swing_lookback=MathMax(swing_lookback, 3);
      m_equal_tolerance_points=MathMax(equal_tolerance_points, 1);
      m_max_level_age_bars=MathMax(max_level_age_bars, 50);
      m_sweep_confirm_bars=MathMax(sweep_confirm_bars, 1);
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_initialized=true;
      m_last_bar_time=0;
      m_bar_processed=false;

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
    bool LoadRates(string symbol,
                   ENUM_TIMEFRAMES timeframe,
                   int count,
                   MqlRates& rates[])
      {
       ResetLastError();
       int copied=CopyRates(symbol, timeframe, 0, count, rates);
       if(copied<=0)
          return false;

       return true;
      }

    bool LoadRatesFrom(string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       int start_pos,
                       int count,
                       MqlRates& rates[])
      {
       ResetLastError();
       int copied=CopyRates(symbol, timeframe, start_pos, count, rates);
       if(copied<=0)
          return false;

       return true;
      }

public:
   struct SwingPoint
     {
      datetime time;
      double   price;
      bool     is_high;
     };

   bool FindSwingHigh(const MqlRates& rates[],
                      int center_idx,
                      int lookback,
                      SwingPoint& swing) const
     {
      int size=ArraySize(rates);
      if(center_idx<0 || center_idx>=size ||
         center_idx-lookback<0 ||
         center_idx+lookback>=size)
         return false;

      double center_high=rates[center_idx].high;
      for(int i=1; i<=lookback; i++)
        {
         if(rates[center_idx-i].high > center_high ||
            rates[center_idx+i].high > center_high)
            return false;
        }

      swing.time=rates[center_idx].time;
      swing.price=center_high;
      swing.is_high=true;
      return true;
     }

   bool FindSwingLow(const MqlRates& rates[],
                     int center_idx,
                     int lookback,
                     SwingPoint& swing) const
     {
      int size=ArraySize(rates);
      if(center_idx<0 || center_idx>=size ||
         center_idx-lookback<0 ||
         center_idx+lookback>=size)
         return false;

      double center_low=rates[center_idx].low;
      for(int i=1; i<=lookback; i++)
        {
         if(rates[center_idx-i].low < center_low ||
            rates[center_idx+i].low < center_low)
            return false;
        }

      swing.time=rates[center_idx].time;
      swing.price=center_low;
      swing.is_high=false;
      return true;
     }

   bool IsConfirmedSwingHigh(const MqlRates& rates[],
                             int idx,
                             int lookback) const
     {
      int size=ArraySize(rates);
      if(idx<0 || idx>=size)
         return false;

      if(idx-lookback<0 || idx+lookback>=size)
         return false;

      double high=rates[idx].high;
      for(int i=1; i<=lookback; i++)
        {
         if(rates[idx-i].high > high ||
            rates[idx+i].high > high)
            return false;
        }
      return true;
     }

   bool IsConfirmedSwingLow(const MqlRates& rates[],
                            int idx,
                            int lookback) const
     {
      int size=ArraySize(rates);
      if(idx<0 || idx>=size)
         return false;

      if(idx-lookback<0 || idx+lookback>=size)
         return false;

      double low=rates[idx].low;
      for(int i=1; i<=lookback; i++)
        {
         if(rates[idx-i].low < low ||
            rates[idx+i].low < low)
            return false;
        }
      return true;
     }

   bool DetectEqualHigh(const MqlRates& rates[],
                        int recent_idx,
                        double tolerance,
                        double& equal_high,
                        datetime& equal_high_time) const
     {
      int size=ArraySize(rates);
      if(recent_idx<0 || recent_idx>=size)
         return false;

      double level=rates[recent_idx].high;
      for(int i=recent_idx+1; i<size; i++)
        {
         if(MathAbs(rates[i].high - level) <= tolerance)
           {
            equal_high=level;
            equal_high_time=rates[i].time;
            return true;
           }
        }
      return false;
     }

   bool DetectEqualLow(const MqlRates& rates[],
                       int recent_idx,
                       double tolerance,
                       double& equal_low,
                       datetime& equal_low_time) const
     {
      int size=ArraySize(rates);
      if(recent_idx<0 || recent_idx>=size)
         return false;

      double level=rates[recent_idx].low;
      for(int i=recent_idx+1; i<size; i++)
        {
         if(MathAbs(rates[i].low - level) <= tolerance)
           {
            equal_low=level;
            equal_low_time=rates[i].time;
            return true;
           }
        }
      return false;
     }

   bool UpdatePreviousDayLevel()
     {
      MqlRates daily[];
      ResetLastError();
      int copied=CopyRates(m_symbol, PERIOD_D1, 0, 3, daily);
      if(copied<2)
         return false;

       datetime today_session=StringToTime(TimeToString(daily[0].time, TIME_DATE));

      if(m_daily_session_time != today_session)
        {
         m_daily_session_time=today_session;
         m_daily_high=daily[1].high;
         m_daily_low=daily[1].low;
        }

      return true;
     }

   bool UpdatePreviousWeekLevel()
     {
      MqlRates weekly[];
      ResetLastError();
      int copied=CopyRates(m_symbol, PERIOD_W1, 0, 3, weekly);
      if(copied<2)
         return false;

      if(m_weekly_session_time != weekly[1].time)
        {
         m_weekly_session_time=weekly[1].time;
         m_weekly_high=weekly[1].high;
         m_weekly_low=weekly[1].low;
        }

      return true;
     }

   bool DetectBOS(const MqlRates& rates[],
                  int idx,
                  int lookback,
                  bool& bos_long,
                  bool& bos_short,
                  datetime& bos_time) const
     {
      int size=ArraySize(rates);
      if(idx<0 || idx+lookback>=size)
         return false;

      double ref_low=rates[idx].low;
      double ref_high=rates[idx].high;

      for(int i=1; i<=lookback; i++)
        {
         if(rates[idx+i].high > ref_high)
            bos_long=true;
         if(rates[idx+i].low < ref_low)
            bos_short=true;
        }

      bos_time=rates[idx].time;
      return bos_long || bos_short;
     }

   bool DetectChoCH(const MqlRates& rates[],
                    int idx,
                    int lookback,
                    bool& choch) const
     {
      if(idx<lookback || idx>=ArraySize(rates))
         return false;

      bool found_high=false;
      bool found_low=false;
      double peak=0;
      double trough=DBL_MAX;

      for(int i=0; i<lookback && i<10; i++)
        {
         if(!found_high)
           {
            SwingPoint swing;
            if(FindSwingHigh(rates, idx-i, 1, swing))
              {
               found_high=true;
               peak=swing.price;
              }
           }
         if(!found_low)
           {
            SwingPoint swing;
            if(FindSwingLow(rates, idx-i, 1, swing))
              {
               found_low=true;
               trough=swing.price;
              }
           }
        }

      choch = found_high && found_low && peak > trough;
      return choch;
     }

   void CheckSweepEvent(const MqlRates& rates[],
                        const LiquidityFeatures& current_features,
                        datetime current_bar_time)
     {
      if(!current_features.valid)
         return;

      int size=ArraySize(rates);
      if(size<3)
         return;

      if(m_event_consumed || m_last_event==LIQ_EVENT_NONE)
         return;

      if(!m_event_consumed && m_last_event!=LIQ_EVENT_NONE)
        {
         datetime event_age_bars=0;
         for(int i=0; i<size; i++)
           {
            if(rates[i].time > m_event_time)
              {
               event_age_bars++;
              }
           }

         if(event_age_bars >= m_max_level_age_bars)
           {
            m_last_event=LIQ_EVENT_NONE;
            m_event_consumed=true;
            m_event_expiry=0;
           }
        }
     }

   bool CheckLiquiditySweepLong(const MqlRates& rates[],
                                double equal_low_level,
                                int confirm_bars)
     {
      int size=ArraySize(rates);
      if(size<confirm_bars+2)
         return false;

      double tolerance=m_equal_tolerance_points * GetPoint();

      for(int i=size-1; i>=0; i--)
        {
         if(MathAbs(rates[i].low - equal_low_level) <= tolerance &&
            rates[i].low < equal_low_level)
           {
            if(i > 0)
              {
               bool closed_back=false;
               for(int j=i-1; j>=0 && j>i-confirm_bars-1; j--)
                 {
                  if(rates[j].close > equal_low_level)
                    {
                     closed_back=true;
                     break;
                    }
                 }

               if(closed_back)
                 {
                  m_last_event=LIQ_EVENT_LONG_SWEEP;
                  m_event_time=rates[i].time;
                  m_event_level=equal_low_level;
                  m_event_expiry=rates[i].time + confirm_bars * PeriodSeconds(m_timeframe);
                  m_event_consumed=false;
                  return true;
                 }
              }
           }
        }

      return false;
     }

   bool CheckLiquiditySweepShort(const MqlRates& rates[],
                                 double equal_high_level,
                                 int confirm_bars)
     {
      int size=ArraySize(rates);
      if(size<confirm_bars+2)
         return false;

      double tolerance=m_equal_tolerance_points * GetPoint();

      for(int i=size-1; i>=0; i--)
        {
         if(MathAbs(rates[i].high - equal_high_level) <= tolerance &&
            rates[i].high > equal_high_level)
           {
            if(i > 0)
              {
               bool closed_back=false;
               for(int j=i-1; j>=0 && j>i-confirm_bars-1; j--)
                 {
                  if(rates[j].close < equal_high_level)
                    {
                     closed_back=true;
                     break;
                    }
                 }

               if(closed_back)
                 {
                  m_last_event=LIQ_EVENT_SHORT_SWEEP;
                  m_event_time=rates[i].time;
                  m_event_level=equal_high_level;
                  m_event_expiry=rates[i].time + confirm_bars * PeriodSeconds(m_timeframe);
                  m_event_consumed=false;
                  return true;
                 }
              }
           }
        }

      return false;
     }

   LiquidityFeatures Calculate(const FeatureContext& context)
     {
      LiquidityFeatures result;
      result.valid=false;
      result.equal_high=0;
      result.equal_low=0;
      result.equal_high_time=0;
      result.equal_low_time=0;
      result.prev_day_high=0;
      result.prev_day_low=0;
      result.prev_week_high=0;
      result.prev_week_low=0;
      result.recent_event=LIQ_EVENT_NONE;
      result.event_time=0;
      result.event_level=0;
      result.event_expiry=0;
      result.event_consumed=false;
      result.symbol=m_symbol;
      result.timeframe=m_timeframe;
      result.bar_time=context.signal_market.closed_bar_time;
      result.reason="";

      if(!m_initialized)
        {
         result.reason="Engine not initialized";
         return result;
        }

      MqlRates rates[];
      if(!LoadRates(m_symbol, m_timeframe, 200, rates))
        {
         result.reason="No market data for liquidity";
         return result;
        }

      int size=ArraySize(rates);
      if(size<10)
        {
         result.reason="Insufficient bars for liquidity ("+
                       IntegerToString(size)+")";
         return result;
        }

      UpdatePreviousDayLevel();
      UpdatePreviousWeekLevel();

      result.prev_day_high=m_daily_high;
      result.prev_day_low=m_daily_low;
      result.prev_week_high=m_weekly_high;
      result.prev_week_low=m_weekly_low;

      m_prev_equal_high=0;
      m_prev_equal_low=0;
      m_prev_equal_high_time=0;
      m_prev_equal_low_time=0;

      double tolerance=m_equal_tolerance_points * GetPoint();

      for(int i=size-2; i>=1 && i<size-22; i--)
        {
         if(IsConfirmedSwingHigh(rates, i, m_swing_lookback))
           {
            bool found_equal=false;
            for(int j=i-1; j>=0; j--)
              {
               if(MathAbs(rates[j].high - rates[i].high) <= tolerance)
                 {
                  m_prev_equal_high=rates[i].high;
                  m_prev_equal_high_time=rates[i].time;
                  found_equal=true;
                  break;
                 }
              }
            if(found_equal)
               break;
           }
         if(IsConfirmedSwingLow(rates, i, m_swing_lookback))
           {
            bool found_equal=false;
            for(int j=i-1; j>=0; j--)
              {
               if(MathAbs(rates[j].low - rates[i].low) <= tolerance)
                 {
                  m_prev_equal_low=rates[i].low;
                  m_prev_equal_low_time=rates[i].time;
                  found_equal=true;
                  break;
                 }
              }
            if(found_equal)
               break;
           }
        }

      result.equal_high=m_prev_equal_high;
      result.equal_low=m_prev_equal_low;
      result.equal_high_time=m_prev_equal_high_time;
      result.equal_low_time=m_prev_equal_low_time;

      if(m_prev_equal_low>0)
        {
         CheckLiquiditySweepLong(rates, m_prev_equal_low, m_sweep_confirm_bars);
        }

      if(m_prev_equal_high>0)
        {
         CheckLiquiditySweepShort(rates, m_prev_equal_high, m_sweep_confirm_bars);
        }

      bool bos_long=false;
      bool bos_short=false;
      datetime bos_time=0;

      if(size>=m_swing_lookback*2+2)
        {
         DetectBOS(rates, size-2, m_swing_lookback, bos_long, bos_short, bos_time);

         if(bos_long)
           {
            m_last_bos_long=true;
            m_last_bos_short=false;
            m_last_bos_time=bos_time;
           }
         else if(bos_short)
           {
            m_last_bos_short=true;
            m_last_bos_long=false;
            m_last_bos_time=bos_time;
           }
        }

      bool choch=false;
      if(size>=m_swing_lookback*2+2)
        {
         DetectChoCH(rates, size-2, m_swing_lookback, choch);
         if(choch)
           {
            m_current_choch=true;
            m_last_choch_time=rates[size-2].time;
           }
        }

      result.recent_event=m_last_event;
      result.event_time=m_event_time;
      result.event_level=m_event_level;
      result.event_expiry=m_event_expiry;
      result.event_consumed=m_event_consumed;

      CheckSweepEvent(rates, result, result.bar_time);

      if(m_event_consumed && m_last_event==LIQ_EVENT_NONE)
         result.recent_event=LIQ_EVENT_NONE;

      result.valid=true;
      result.reason="OK";

      m_last_bar_time=result.bar_time;
      m_bar_processed=true;

      return result;
     }

   bool HasValidSweep(const LiquidityFeatures& features,
                      ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!features.valid || features.recent_event==LIQ_EVENT_NONE)
         return false;

      if(features.event_consumed)
         return false;

      if(direction==SIGNAL_LONG && features.recent_event==LIQ_EVENT_LONG_SWEEP)
         return true;

      if(direction==SIGNAL_SHORT && features.recent_event==LIQ_EVENT_SHORT_SWEEP)
         return true;

      return false;
     }

   bool IsLevelInvalidated(const LiquidityFeatures& features,
                           double price,
                           ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!features.valid)
         return false;

      double tolerance=GetPoint();

      if(direction==SIGNAL_LONG && features.equal_low>0)
         return price < features.equal_low - tolerance;

      if(direction==SIGNAL_SHORT && features.equal_high>0)
         return price > features.equal_high + tolerance;

      return false;
     }
  };

#endif