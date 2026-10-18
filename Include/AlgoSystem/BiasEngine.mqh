#ifndef __ALGOSYSTEM_BIAS_ENGINE_MQH__
#define __ALGOSYSTEM_BIAS_ENGINE_MQH__

#include "HybridTypes.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Directional Bias Engine                                           |
//|                                                                  |
//| Combines higher-timeframe swings, structure, BOS/CHoCH,       |
//| profile location, and directional momentum to determine bias.   |
//+------------------------------------------------------------------+
class CBiasEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_structure_tf;
   ENUM_TIMEFRAMES    m_signal_tf;

   int                m_swings_required;
   int                m_lookback;

   double             m_tick_size;
   double             m_point;
   int                m_digits;

   bool               m_initialized;
   datetime           m_last_bar_time;

   ENUM_BIAS_DIRECTION m_last_bias;
   string             m_last_bias_reason;

public:
   CBiasEngine()
     {
      m_symbol="";
      m_structure_tf=PERIOD_H4;
      m_signal_tf=PERIOD_H1;
      m_swings_required=2;
      m_lookback=50;
      m_tick_size=0;
      m_point=0;
      m_digits=0;
      m_initialized=false;
      m_last_bar_time=0;
      m_last_bias=BIAS_INSUFFICIENT_DATA;
      m_last_bias_reason="";
     }

   void SetParameters(int swings_required, int lookback)
     {
      m_swings_required=swings_required;
      m_lookback=lookback;
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES structure_tf,
                   ENUM_TIMEFRAMES signal_tf)
     {
      m_symbol=symbol;
      m_structure_tf=structure_tf;
      m_signal_tf=signal_tf;
      m_initialized=true;

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
                   ENUM_TIMEFRAMES tf,
                   int count,
                   MqlRates& rates[])
      {
       ResetLastError();
       int copied=CopyRates(symbol, tf, 0, count, rates);
       if(copied<=0)
          return false;
       return true;
      }

    bool FindHigherTimeframeSwings(const MqlRates& rates[],
                                  int lookback,
                                  double& bull_bias,
                                  double& bear_bias,
                                  string& reason) const
     {
      int size=ArraySize(rates);
      if(size < 5)
         return false;

      int swings_to_check=MathMin(lookback, size-2);

      for(int i=size-2; i>=size-2-swings_to_check && i>0; i--)
        {
         if(i >= 2 && i < size-1)
           {
            if(rates[i].high > rates[i-1].high &&
               rates[i].high > rates[i+1].high &&
               rates[i].high > rates[i-2].high)
              {
               bear_bias += 1.0;
              }

            if(rates[i].low < rates[i-1].low &&
               rates[i].low < rates[i+1].low &&
               rates[i].low < rates[i-2].low)
              {
               bull_bias += 1.0;
              }
           }
        }

      reason="Analyzed "+IntegerToString(swings_to_check)+" recent swings";
      return true;
     }

    bool DetectBOS(const MqlRates& rates[],
                  bool& bos_up,
                  bool& bos_down) const
     {
      int size=ArraySize(rates);
      if(size < 5)
         return false;

      double recent_high=rates[1].high;

      for(int i=2; i<size && i<size-10; i++)
        {
         if(rates[i].high < recent_high - GetPoint())
           {
            bos_up=true;
            return true;
           }
         if(rates[i].high > recent_high + GetPoint())
            break;
        }

      double recent_low=rates[1].low;

      for(int i=2; i<size && i<size-10; i++)
        {
         if(rates[i].low > recent_low + GetPoint())
           {
            bos_down=true;
            return true;
           }
         if(rates[i].low < recent_low - GetPoint())
            break;
        }

      return bos_up || bos_down;
     }

public:
   StructureFeatures Calculate(const FeatureContext& context,
                               const MarketSnapshot& structure_market,
                               const ProfileFeatures& profile)
     {
      StructureFeatures result;
      result.valid=false;
      result.bias=BIAS_INSUFFICIENT_DATA;
      result.bias_reason="";
      result.bos_long=false;
      result.bos_short=false;
      result.choch=false;
      result.bar_time=context.signal_market.closed_bar_time;
      result.symbol=m_symbol;
      result.timeframe=m_structure_tf;
      result.reason="";

      if(!m_initialized)
        {
         result.reason="Bias engine not initialized";
         return result;
        }

      MqlRates struct_rates[];
      if(!LoadRates(m_symbol, m_structure_tf, m_lookback+10, struct_rates))
        {
         result.reason="No structure timeframe data";
         return result;
        }

      int struct_size=ArraySize(struct_rates);
      if(struct_size < 10)
        {
         result.reason="Insufficient structure bars";
         return result;
        }

      double bull_bias=0;
      double bear_bias=0;
      string swing_reason="";

      if(!FindHigherTimeframeSwings(struct_rates, m_lookback, bull_bias, bear_bias, swing_reason))
        {
         result.reason="Could not analyze higher-timeframe swings";
         return result;
        }

      bool bos_up=false;
      bool bos_down=false;
      if(!DetectBOS(struct_rates, bos_up, bos_down))
        {
        }

      result.bos_long=bos_up;
      result.bos_short=bos_down;

      result.choch = (bos_up && !bos_down) || (!bos_up && bos_down);

      double total_votes=bull_bias + bear_bias;
      double bias_ratio = 0;
      if(total_votes > 0)
         bias_ratio = (bull_bias - bear_bias) / total_votes;

      if(total_votes < 1)
        {
         result.bias=BIAS_INSUFFICIENT_DATA;
         result.bias_reason="Insufficient swing votes";
        }
      else if(bias_ratio > 0.25)
        {
         result.bias=BIAS_BULLISH;
         result.bias_reason="Bullish structure with swing votes "+
                            DoubleToString(bias_ratio,2);
        }
      else if(bias_ratio < -0.25)
        {
         result.bias=BIAS_BEARISH;
         result.bias_reason="Bearish structure with swing votes "+
                            DoubleToString(bias_ratio,2);
        }
      else if(MathAbs(bias_ratio) < 0.1)
        {
         result.bias=BIAS_CONFLICTED;
         result.bias_reason="Balanced swing votes, conflicted bias";
        }
      else
        {
         result.bias=BIAS_NEUTRAL;
         result.bias_reason="Neutral/weak bias ratio="+DoubleToString(bias_ratio,2);
        }

      if(profile.valid && profile.poc > 0)
        {
         double close=context.signal_market.closed_bar.close;
         if(close > profile.vah)
           {
            if(result.bias==BIAS_BEARISH || result.bias==BIAS_CONFLICTED)
               result.bias=BIAS_CONFLICTED;
           }
         else if(close < profile.val)
           {
            if(result.bias==BIAS_BULLISH || result.bias==BIAS_CONFLICTED)
               result.bias=BIAS_CONFLICTED;
           }
        }

      result.valid=true;
      result.reason="OK";
      m_last_bias=result.bias;
      m_last_bias_reason=result.bias_reason;
      m_last_bar_time=result.bar_time;

      return result;
     }

   ENUM_BIAS_DIRECTION GetCurrentBias() const
     {
      return m_last_bias;
     }
  };

#endif