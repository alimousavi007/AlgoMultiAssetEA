#ifndef __ALGOSYSTEM_VOLUME_PROFILE_MQH__
#define __ALGOSYSTEM_VOLUME_PROFILE_MQH__

#include "HybridTypes.mqh"
#include "Utilities.mqh"
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Volume Profile Engine                                             |
//|                                                                  |
//| Computes POC, VAH, VAL from tick volume or real volume.          |
//| Uses bar-based volume allocation with explicit conservation rule. |
//+------------------------------------------------------------------+
class CVolumeProfileEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;

   int                m_session_bars;
   int                m_rolling_bars;
   double             m_value_area_percent;

   double             m_tick_size;
   double             m_point;
   int                m_digits;

   bool               m_initialized;

   int                m_poc_shift_cache;
   datetime           m_last_bar_time;
   double             m_last_poc;
   double             m_last_vah;
   double             m_last_val;
   double             m_last_concentration;
   datetime           m_last_poc_time;

public:
   CVolumeProfileEngine()
     {
      m_symbol="";
      m_timeframe=PERIOD_H1;
      m_session_bars=78;
      m_rolling_bars=156;
      m_value_area_percent=0.68;
      m_tick_size=0;
      m_point=0;
      m_digits=0;
      m_initialized=false;
      m_poc_shift_cache=-1;
      m_last_bar_time=0;
      m_last_poc=0;
      m_last_vah=0;
      m_last_val=0;
      m_last_concentration=0;
      m_last_poc_time=0;
     }

   void SetParameters(int session_bars,
                      int rolling_bars,
                      double va_percent)
     {
      m_session_bars=session_bars;
      m_rolling_bars=rolling_bars;
      m_value_area_percent=va_percent;
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_initialized=true;
      m_last_bar_time=0;
      return true;
     }

    ENUM_VOLUME_DATA_MODE DetectVolumeMode(long& volume_array[])
     {
      int total_bars=ArraySize(volume_array);
      if(total_bars<=0)
         return VOLUME_MODE_INSUFFICIENT;

      int with_real_volume=0;
      for(int i=0; i<total_bars && i<50; i++)
        {
         if(volume_array[i]>0)
             with_real_volume++;
        }

      if(with_real_volume > total_bars / 2)
         return VOLUME_MODE_REAL_VOLUME;

      return VOLUME_MODE_TICK_VOLUME_PROXY;
     }

   bool GetSymbolSpecs(string symbol)
     {
      ResetLastError();
      if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, m_tick_size))
        {
         m_tick_size=SymbolInfoDouble(symbol, SYMBOL_POINT);
        }

      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, m_point))
         m_point=0;

      long digits=0;
      if(!SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits))
         digits=0;

      m_digits=(int)digits;

      if(m_tick_size<=0)
         return false;

      return true;
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
       ArrayFree(rates);
       ResetLastError();
       int copied=CopyRates(symbol, timeframe, 0, count, rates);
       if(copied <= 0)
          return false;

       return true;
     }

public:
   ProfileFeatures Calculate(const MarketSnapshot& market,
                             bool use_session_profile=true)
     {
      ProfileFeatures result;
      result.valid=false;
      result.symbol=market.symbol;
      result.timeframe=market.timeframe;
      result.bar_time=market.closed_bar_time;
      result.data_mode=VOLUME_MODE_INSUFFICIENT;
      result.poc=0;
      result.vah=0;
      result.val=0;
      result.price_location_in_value_area=0.5;
      result.profile_concentration=0;
      result.poc_time=0;
      result.reason="";

      string symbol=market.symbol;
      ENUM_TIMEFRAMES tf=market.timeframe;

      int lookback=use_session_profile ?
         MathMax(m_session_bars, m_rolling_bars) : m_rolling_bars;

      lookback = MathMax(lookback, 50);

      MqlRates rates[];
      ResetLastError();
      if(!LoadRates(symbol, tf, lookback, rates))
        {
         result.reason="No historical data for profile";
         result.data_mode=VOLUME_MODE_INSUFFICIENT;
         return result;
        }

      int loaded=ArraySize(rates);
      if(loaded<10)
        {
         result.reason="Insufficient bars for profile ("+
                       IntegerToString(loaded)+")";
         result.data_mode=VOLUME_MODE_INSUFFICIENT;
         return result;
        }

      if(!GetSymbolSpecs(symbol))
        {
         result.reason="Could not read symbol specs for profile";
         result.data_mode=VOLUME_MODE_INSUFFICIENT;
         return result;
        }

      long tick_volumes[];
      long real_volumes[];
      ArrayResize(tick_volumes, loaded);
      ArrayResize(real_volumes, loaded);

      for(int i=0; i<loaded; i++)
        {
         tick_volumes[i]=rates[i].tick_volume;
         real_volumes[i]=rates[i].real_volume;
        }

      ENUM_VOLUME_DATA_MODE mode=DetectVolumeMode(real_volumes);
      result.data_mode=mode;

      long volumes[];
      if(mode==VOLUME_MODE_REAL_VOLUME)
         ArrayCopy(volumes, real_volumes);
      else
         ArrayCopy(volumes, tick_volumes);

      for(int i=0; i<loaded; i++)
        {
         if(volumes[i]<=0)
            volumes[i]=1;
        }

      double price_min=rates[0].low;
      double price_max=rates[0].high;
      for(int i=1; i<loaded; i++)
        {
         if(rates[i].low < price_min) price_min=rates[i].low;
         if(rates[i].high > price_max) price_max=rates[i].high;
        }

      double tick_size = GetTickSize();
      if(tick_size<=0 || price_max<=price_min)
        {
         result.reason="Invalid tick size or price range for profile";
         return result;
        }

      int bins=(int)((price_max - price_min) / tick_size) + 1;
      if(bins<=0 || bins>50000)
         bins=5000;

      double bin_size=NormalizeDouble((price_max - price_min) / bins, m_digits);
      if(bin_size<=0)
         bin_size=tick_size;

      double bin_edges[];
      long   bin_volumes[];
      ArrayResize(bin_edges, bins+1);
      ArrayResize(bin_volumes, bins);
      ArrayInitialize(bin_volumes, 0);

      bin_edges[0]=price_min;
      for(int i=0; i<bins; i++)
         bin_edges[i+1]=bin_edges[i]+bin_size;

      long total_volume=0;
      for(int b=0; b<bins; b++)
        {
         bin_volumes[b]=0;
        }

      for(int i=0; i<loaded; i++)
        {
         double bar_volume=(double)volumes[i];
         if(bar_volume<=0)
            continue;

         double low=rates[i].low;
         double high=rates[i].high;
         double range=high-low;
         if(range<=0)
            range=bin_size;

         int bins_touched=0;
         for(int b=0; b<bins; b++)
           {
            if(bin_edges[b+1] >= low && bin_edges[b] <= high)
               bins_touched++;
           }

         if(bins_touched<=0)
            bins_touched=1;

         double vol_per_bin=bar_volume / bins_touched;

         for(int b=0; b<bins; b++)
           {
            if(bin_edges[b+1] >= low && bin_edges[b] <= high)
              {
               bin_volumes[b] += (long)vol_per_bin;
              }
           }
         total_volume += (long)bar_volume;
        }

      if(total_volume<=0)
        {
         result.reason="Zero total volume";
         return result;
        }

      int poc_bin=0;
      long max_vol=bin_volumes[0];
      for(int b=1; b<bins; b++)
        {
         if(bin_volumes[b] > max_vol)
           {
            max_vol=bin_volumes[b];
            poc_bin=b;
           }
        }

      double poc_price=(bin_edges[poc_bin]+bin_edges[poc_bin+1]) / 2.0;
      result.poc=poc_price;
      result.poc_time=rates[loaded-1-poc_bin < 0 ? 0 : loaded-1].time;

      int va_threshold=(int)(total_volume * m_value_area_percent);

      int va_low_bin=poc_bin;
      int va_high_bin=poc_bin;
      long va_volume=bin_volumes[poc_bin];

      while(va_volume < va_threshold)
        {
         bool expanded=false;

         long next_up_vol=-1;
         int next_up_bin=-1;
         if(va_high_bin+1 < bins)
           {
            next_up_vol=bin_volumes[va_high_bin+1];
            next_up_bin=va_high_bin+1;
           }

         long next_down_vol=-1;
         int next_down_bin=-1;
         if(va_low_bin-1 >= 0)
           {
            next_down_vol=bin_volumes[va_low_bin-1];
            next_down_bin=va_low_bin-1;
           }

         if(next_up_bin==-1 && next_down_bin==-1)
            break;

         if(next_up_bin!=-1 &&
            (next_down_bin==-1 || next_up_vol >= next_down_vol))
           {
            if(va_volume + next_up_vol <= va_threshold)
              {
               va_volume += next_up_vol;
               va_high_bin++;
               expanded=true;
              }
           }

         if(!expanded && next_down_bin!=-1 &&
            (next_up_bin==-1 || next_down_vol > next_up_vol))
           {
            if(va_volume + next_down_vol <= va_threshold)
              {
               va_volume += next_down_vol;
               va_low_bin--;
               expanded=true;
              }
           }

         if(!expanded)
           {
             if(next_up_bin!=-1 && va_volume + next_up_vol <= va_threshold)
              {
               va_volume += next_up_vol;
               va_high_bin++;
               expanded=true;
              }
            else if(next_down_bin!=-1)
              {
               va_volume += next_down_vol;
               va_low_bin--;
               expanded=true;
              }
            else
               break;
           }

         if(!expanded)
            break;
        }

      result.vah=bin_edges[va_high_bin+1];
      result.val=bin_edges[va_low_bin];

      result.profile_concentration=(double)poc_bin / (double)bins;

      double close=market.closed_bar.close;
      if(result.vah > result.val)
        {
         if(close > result.vah)
            result.price_location_in_value_area=1.0;
         else if(close < result.val)
            result.price_location_in_value_area=0.0;
         else
            result.price_location_in_value_area=
               (close - result.val) / (result.vah - result.val);
        }
      else
         result.price_location_in_value_area=0.5;

      m_last_bar_time=result.bar_time;
      m_last_poc=result.poc;
      m_last_vah=result.vah;
      m_last_val=result.val;
      m_last_concentration=result.profile_concentration;
      m_last_poc_time=result.poc_time;

      result.valid=true;
      result.reason="OK";

      return result;
     }

   bool IsPriceAboveValueArea(const double price,
                              const ProfileFeatures& profile) const
     {
      if(!profile.valid)
         return false;
      return price > profile.vah;
     }

   bool IsPriceBelowValueArea(const double price,
                              const ProfileFeatures& profile) const
     {
      if(!profile.valid)
         return false;
      return price < profile.val;
     }

   bool IsPriceInValueArea(const double price,
                           const ProfileFeatures& profile) const
     {
      if(!profile.valid)
         return false;
      return price >= profile.val && price <= profile.vah;
     }

   bool IsNearPOC(const double price,
                  const ProfileFeatures& profile,
                  int tolerance_multiples) const
     {
      if(!profile.valid || profile.poc<=0)
         return false;

      double tolerance=tolerance_multiples * GetTickSize();
      return MathAbs(price - profile.poc) <= tolerance;
     }

   bool HasPOCMigrated(const ProfileFeatures& current,
                       const ProfileFeatures& previous) const
     {
      if(!current.valid || !previous.valid)
         return false;
      if(current.poc_time==previous.poc_time &&
         current.bar_time==previous.bar_time)
         return false;

      return MathAbs(current.poc - previous.poc) > GetTickSize();
     }
  };

#endif