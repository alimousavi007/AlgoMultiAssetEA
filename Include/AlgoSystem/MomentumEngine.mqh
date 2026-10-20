#ifndef __ALGOSYSTEM_MOMENTUM_MQH__
#define __ALGOSYSTEM_MOMENTUM_MQH__

#include "HybridTypes.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Momentum Engine                                                   |
//|                                                                  |
//| Provides explainable momentum classification using candle body |
//| relative to ATR, close location, ROC, and directional strength. |
//+------------------------------------------------------------------+
class CMomentumEngine
  {
private:
   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;

   int                m_atr_period;
   int                m_roc_period;
   int                m_lookback;

   double             m_tick_size;
   double             m_point;
   int                m_digits;

   bool               m_initialized;
   datetime           m_last_bar_time;

   MqlRates           m_cached_rates[];
   int                m_cached_count;

public:
   CMomentumEngine()
     {
      m_symbol="";
      m_timeframe=PERIOD_H1;
      m_atr_period=14;
      m_roc_period=10;
      m_lookback=50;
      m_tick_size=0;
      m_point=0;
      m_digits=0;
      m_initialized=false;
      m_last_bar_time=0;
      m_cached_count=0;
     }

   void SetParameters(int atr_period,
                      int roc_period,
                      int lookback)
     {
      m_atr_period=atr_period;
      m_roc_period=roc_period;
      m_lookback=lookback;
     }

   bool Initialize(const string symbol,
                   ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;
      m_initialized=true;
      m_last_bar_time=0;
      m_cached_count=0;

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
    bool LoadRates(int count, MqlRates& rates[])
      {
       ResetLastError();
        int copied=CopyRates(m_symbol, m_timeframe, 0, count, rates);
        if(copied<=0)
           return false;

        ArraySetAsSeries(rates, true);
        return true;
      }

    double CalculateATR(const MqlRates& rates[], int period) const
      {
       int size=ArraySize(rates);
       if(size<period || period<=0)
          return 0;

       double sum=0;
       for(int i=0; i<period && i<size; i++)
         {
          int next_idx=MathMin(i+1, size-1);
          double tr1=rates[i].high - rates[i].low;
          double tr2=MathAbs(rates[i].high - rates[next_idx].close);
          double tr3=MathAbs(rates[i].low - rates[next_idx].close);
          double tr=MathMax(tr1, MathMax(tr2, tr3));
          sum += tr;
         }

       return sum / (double)period;
      }

    double CalculateROC(const MqlRates& rates[], int period) const
     {
      int size=ArraySize(rates);
      if(size < period+1 || period<=0)
         return 0;

      double current_close=rates[0].close;
      double prev_close=rates[period].close;

      if(prev_close<=0)
         return 0;

      return ((current_close - prev_close) / prev_close) * 100.0;
     }

public:
   MomentumFeatures Calculate(const MarketSnapshot& market)
     {
      MomentumFeatures result;
      result.valid=false;
      result.state=MOMENTUM_INSUFFICIENT_DATA;
      result.state_reason="";
      result.roc=0;
      result.body_ratio=0;
      result.close_location=0;
      result.momentum_score=50.0;
      result.bar_time=market.closed_bar_time;
      result.symbol=market.symbol;
      result.timeframe=market.timeframe;
      result.reason="";

       if(!m_initialized)
         {
          result.reason="Engine not initialized";
          return result;
         }

       if(!market.valid)
         {
          result.reason="Invalid market snapshot";
          return result;
         }

      int count=MathMax(m_lookback, m_roc_period+5);
      count=MathMax(count, m_atr_period+5);

      MqlRates rates[];
      if(!LoadRates(count, rates))
        {
         result.reason="No market data for momentum";
         return result;
        }

      int size=ArraySize(rates);
      if(size < MathMax(m_lookback, m_roc_period+2))
        {
         result.reason="Insufficient bars for momentum ("+
                       IntegerToString(size)+")";
         return result;
        }

       double atr=CalculateATR(rates, m_atr_period);
       if(atr<=0 || !MathIsValidNumber(atr))
         {
          result.reason="ATR is zero or invalid";
          return result;
         }

      double roc=CalculateROC(rates, m_roc_period);
       result.roc=roc;
       result.atr=atr;

      MqlRates current=rates[0];
      MqlRates prev=rates[1];

      double body=MathAbs(current.close - current.open);
      double range=current.high - current.low;

      if(range > 0)
        {
         result.body_ratio=body / range;

         if(current.close > current.open)
            result.close_location=(current.close - current.low) / range;
         else
            result.close_location=(current.low - current.close) / range;
        }
      else
         result.body_ratio=0;

      double momentum_score=50.0;

       double roc_normalized = MathMax(-10.0, MathMin(10.0, roc));
      double roc_score = 50.0 + (roc_normalized / 10.0) * 50.0;

      double body_score=50.0;
      if(range > 0 && body > 0)
        {
         body_score=50.0 + (body / range) * 50.0;
        }

      double close_loc_score=result.close_location * 100.0;

      momentum_score = (roc_score * 0.4) +
                       (body_score * 0.3) +
                       (close_loc_score * 0.3);

      result.momentum_score=momentum_score;

      double bullish_threshold=60.0;
      double bearish_threshold=40.0;
      double weak_threshold=55.0;
      double strong_threshold=45.0;
      double exhaustion_threshold=70.0;
      double collapse_threshold=30.0;

      double roc_abs=MathAbs(roc);
      bool strong_roc = roc_abs > 0.5;

      if(momentum_score > bullish_threshold && roc > 0 && strong_roc)
        {
         if(momentum_score > exhaustion_threshold)
            result.state=MOMENTUM_EXHAUSTING;
         else
            result.state=MOMENTUM_BULLISH;
         result.state_reason="Score="+DoubleToString(momentum_score,1)+
                              " ROC="+DoubleToString(roc,1);
        }
      else if(momentum_score < bearish_threshold && roc < 0 && strong_roc)
        {
         if(momentum_score < collapse_threshold)
            result.state=MOMENTUM_EXHAUSTING;
         else
            result.state=MOMENTUM_BEARISH;
         result.state_reason="Score="+DoubleToString(momentum_score,1)+
                              " ROC="+DoubleToString(roc,1);
        }
      else if(momentum_score > strong_threshold-5 && momentum_score < weak_threshold)
        {
         result.state=MOMENTUM_WEAK;
         result.state_reason="Momentum weak, score="+DoubleToString(momentum_score,1);
        }
      else
        {
         result.state=MOMENTUM_CONFLICTED;
         result.state_reason="Conflicting momentum signals, score="+
                              DoubleToString(momentum_score,1);
        }

      result.valid=true;
      result.reason="OK";
      m_last_bar_time=result.bar_time;
      m_cached_count=count;

      ArrayFree(m_cached_rates);
      ArrayCopy(m_cached_rates, rates);

      return result;
     }

   bool ShouldReduceExposure(const MomentumFeatures& momentum,
                             ENUM_SIGNAL_DIRECTION direction) const
     {
      if(!momentum.valid)
         return false;

      if(direction==SIGNAL_LONG && momentum.state==MOMENTUM_BEARISH)
         return true;

      if(direction==SIGNAL_SHORT && momentum.state==MOMENTUM_BULLISH)
         return true;

      if(momentum.state==MOMENTUM_WEAK ||
         momentum.state==MOMENTUM_CONFLICTED)
         return true;

      return false;
     }

   bool IsExhaustion(const MomentumFeatures& momentum) const
     {
      if(!momentum.valid)
         return false;

      return momentum.state==MOMENTUM_EXHAUSTING;
     }

   double ScoreToProbability(double score) const
     {
       score=CAlgoUtils::Clamp(score, 0.0, 100.0);
      return score / 100.0;
     }
  };

#endif