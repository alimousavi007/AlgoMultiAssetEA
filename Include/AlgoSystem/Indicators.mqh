#ifndef __ALGOSYSTEM_INDICATORS_MQH__
#define __ALGOSYSTEM_INDICATORS_MQH__

#include "Interfaces.mqh"

//+------------------------------------------------------------------+
//| Indicator / Feature Engine                                      |
//|                                                                  |
//| Responsibility:                                                 |
//| - create and maintain indicator handles                         |
//| - read indicator values                                         |
//| - calculate price/volume features                               |
//| - use CLOSED BAR data by default                                |
//|                                                                  |
//| Does NOT:                                                        |
//| - detect market regime                                          |
//| - generate trade signals                                        |
//| - calculate position size                                       |
//| - send orders                                                    |
//+------------------------------------------------------------------+
class CFeatureEngine : public IFeatureEngine
  {
private:

   //--- configuration
   int m_ema_fast_period;
   int m_ema_slow_period;
   int m_ema_long_period;

   int m_adx_period;
   int m_atr_period;
   int m_rsi_period;

   int m_macd_fast;
   int m_macd_slow;
   int m_macd_signal;

   int m_roc_period;
   int m_volume_period;

   //--- indicator handles
   int m_ema_fast_handle;
   int m_ema_slow_handle;
   int m_ema_long_handle;

   int m_adx_handle;
   int m_atr_handle;
   int m_rsi_handle;
   int m_macd_handle;

   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Release one handle                                             |
   //+----------------------------------------------------------------+
   void ReleaseHandle(int &handle)
     {
      if(handle!=INVALID_HANDLE)
        {
         IndicatorRelease(handle);
         handle=INVALID_HANDLE;
        }
     }

   //+----------------------------------------------------------------+
   //| Release all handles                                            |
   //+----------------------------------------------------------------+
   void ReleaseAllHandles()
     {
      ReleaseHandle(m_ema_fast_handle);
      ReleaseHandle(m_ema_slow_handle);
      ReleaseHandle(m_ema_long_handle);

      ReleaseHandle(m_adx_handle);
      ReleaseHandle(m_atr_handle);
      ReleaseHandle(m_rsi_handle);
      ReleaseHandle(m_macd_handle);
     }

   //+----------------------------------------------------------------+
   //| Validate configuration                                         |
   //+----------------------------------------------------------------+
   bool ValidateParameters() const
     {
      if(m_ema_fast_period<=0)
         return false;

      if(m_ema_slow_period<=0)
         return false;

      if(m_ema_long_period<=0)
         return false;

      if(m_ema_fast_period>=m_ema_slow_period)
         return false;

      if(m_ema_slow_period>=m_ema_long_period)
         return false;

      if(m_adx_period<=0)
         return false;

      if(m_atr_period<=0)
         return false;

      if(m_rsi_period<=0)
         return false;

      if(m_macd_fast<=0 ||
         m_macd_slow<=0 ||
         m_macd_signal<=0)
         return false;

      if(m_macd_fast>=m_macd_slow)
         return false;

      if(m_roc_period<=0)
         return false;

      if(m_volume_period<=0)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Copy one value from an indicator buffer                       |
   //|                                                                  |
   //| shift = 1 => latest CLOSED bar                                |
   //| shift = 0 => current/forming bar                              |
   //+----------------------------------------------------------------+
   bool CopyOne(const int handle,
                const int buffer_index,
                const int shift,
                double &value) const
     {
      value=EMPTY_VALUE;

      if(handle==INVALID_HANDLE)
         return false;
      
      if(BarsCalculated(handle)<shift+1)
         return false;
      
      double buffer[1];
      
      ResetLastError();

      int copied=CopyBuffer(handle,
                            buffer_index,
                            shift,
                            1,
                            buffer);

      if(copied!=1)
         return false;

      if(buffer[0]==EMPTY_VALUE ||
         !MathIsValidNumber(buffer[0]))
         return false;

      value=buffer[0];

      return true;
     }

   //+----------------------------------------------------------------+
   //| Calculate ROC from closed bars                                |
   //+----------------------------------------------------------------+
   bool CalculateROC(const string symbol,
                     ENUM_TIMEFRAMES timeframe,
                     const int shift,
                     double &roc) const
     {
      roc=EMPTY_VALUE;

      if(m_roc_period<=0)
         return false;

      //MqlRates rates[2];

      ResetLastError();

      // We need:
      // rates[0] = shift
      // rates[1] = shift + roc_period
      //
      // Therefore use CopyRates with an explicit starting position.
      int required=m_roc_period+1;

      MqlRates history[];

      ArrayResize(history,required);

      int copied=CopyRates(symbol,
                           timeframe,
                           shift,
                           required,
                           history);

      if(copied!=required)
         return false;

      double old_close=history[0].close;
      double new_close=history[required-1].close;

      if(old_close<=0.0)
         return false;

      roc=((new_close-old_close)/old_close)*100.0;

      return MathIsValidNumber(roc);
     }

   //+----------------------------------------------------------------+
   //| Calculate average tick volume                                  |
   //+----------------------------------------------------------------+
   bool CalculateVolumeRatio(const string symbol,
                             ENUM_TIMEFRAMES timeframe,
                             const int shift,
                             double &ratio) const
     {
      ratio=EMPTY_VALUE;

      if(m_volume_period<=0)
         return false;

      int required=m_volume_period+1;

      MqlRates history[];

      ArrayResize(history,required);

      ResetLastError();

      int copied=CopyRates(symbol,
                           timeframe,
                           shift,
                           required,
                           history);

      if(copied!=required)
         return false;

      double current_volume=
         (double)history[required-1].tick_volume;

      double average=0.0;

      for(int i=0; i<m_volume_period; i++)
         average+=(double)history[i].tick_volume;

      average/=(double)m_volume_period;

      if(average<=0.0)
        {
         // No meaningful volume information.
         ratio=0.0;
         return true;
        }

      ratio=current_volume/average;

      return MathIsValidNumber(ratio);
     }

   //+----------------------------------------------------------------+
   //| Calculate candle features                                      |
   //+----------------------------------------------------------------+
   bool CalculateCandleFeatures(const BarData &bar,
                                double &body,
                                double &range,
                                double &strength) const
     {
      body=0.0;
      range=0.0;
      strength=0.0;

      range=bar.high-bar.low;

      if(range<=0.0)
         return false;

      body=MathAbs(bar.close-bar.open);

      strength=body/range;

      return MathIsValidNumber(body) &&
             MathIsValidNumber(range) &&
             MathIsValidNumber(strength);
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CFeatureEngine()
     {
      m_ema_fast_period=20;
      m_ema_slow_period=50;
      m_ema_long_period=200;

      m_adx_period=14;
      m_atr_period=14;
      m_rsi_period=14;

      m_macd_fast=12;
      m_macd_slow=26;
      m_macd_signal=9;

      m_roc_period=10;
      m_volume_period=20;

      m_ema_fast_handle=INVALID_HANDLE;
      m_ema_slow_handle=INVALID_HANDLE;
      m_ema_long_handle=INVALID_HANDLE;

      m_adx_handle=INVALID_HANDLE;
      m_atr_handle=INVALID_HANDLE;
      m_rsi_handle=INVALID_HANDLE;
      m_macd_handle=INVALID_HANDLE;

      m_symbol="";
      m_timeframe=PERIOD_CURRENT;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Destructor                                                     |
   //+----------------------------------------------------------------+
   ~CFeatureEngine()
     {
      ReleaseAllHandles();
     }

   //+----------------------------------------------------------------+
   //| Configuration                                                  |
   //+----------------------------------------------------------------+
   void SetParameters(const int ema_fast,
                      const int ema_slow,
                      const int ema_long,
                      const int adx_period,
                      const int atr_period,
                      const int rsi_period,
                      const int macd_fast,
                      const int macd_slow,
                      const int macd_signal,
                      const int roc_period,
                      const int volume_period)
     {
      m_ema_fast_period=ema_fast;
      m_ema_slow_period=ema_slow;
      m_ema_long_period=ema_long;

      m_adx_period=adx_period;
      m_atr_period=atr_period;
      m_rsi_period=rsi_period;

      m_macd_fast=macd_fast;
      m_macd_slow=macd_slow;
      m_macd_signal=macd_signal;

      m_roc_period=roc_period;
      m_volume_period=volume_period;
     }

   //+----------------------------------------------------------------+
   //| Initialize handles                                            |
   //+----------------------------------------------------------------+
   bool InitializeFor(const string symbol,
                      ENUM_TIMEFRAMES timeframe)
     {
      m_initialized=false;

      ReleaseAllHandles();

      if(StringLen(symbol)==0)
         return false;

      if(timeframe==PERIOD_CURRENT)
         return false;

      if(!ValidateParameters())
         return false;

      bool custom=false;

      if(!SymbolExist(symbol,custom))
         return false;

      if(!SymbolSelect(symbol,true))
         return false;

      if(!SymbolIsSynchronized(symbol))
         return false;

      m_symbol=symbol;
      m_timeframe=timeframe;

      //--- EMA handles
      m_ema_fast_handle=
         iMA(m_symbol,
             m_timeframe,
             m_ema_fast_period,
             0,
             MODE_EMA,
             PRICE_CLOSE);

      if(m_ema_fast_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      m_ema_slow_handle=
         iMA(m_symbol,
             m_timeframe,
             m_ema_slow_period,
             0,
             MODE_EMA,
             PRICE_CLOSE);

      if(m_ema_slow_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      m_ema_long_handle=
         iMA(m_symbol,
             m_timeframe,
             m_ema_long_period,
             0,
             MODE_EMA,
             PRICE_CLOSE);

      if(m_ema_long_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      //--- ADX
      m_adx_handle=
         iADX(m_symbol,
              m_timeframe,
              m_adx_period);

      if(m_adx_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      //--- ATR
      m_atr_handle=
         iATR(m_symbol,
              m_timeframe,
              m_atr_period);

      if(m_atr_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      //--- RSI
      m_rsi_handle=
         iRSI(m_symbol,
              m_timeframe,
              m_rsi_period,
              PRICE_CLOSE);

      if(m_rsi_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      //--- MACD
      m_macd_handle=
         iMACD(m_symbol,
               m_timeframe,
               m_macd_fast,
               m_macd_slow,
               m_macd_signal,
               PRICE_CLOSE);

      if(m_macd_handle==INVALID_HANDLE)
        {
         ReleaseAllHandles();
         return false;
        }

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| IFeatureEngine initialization                                 |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(StringLen(m_symbol)==0 ||
         m_timeframe==PERIOD_CURRENT)
         return false;

      return InitializeFor(m_symbol,
                           m_timeframe);
     }

   //+----------------------------------------------------------------+
   //| Calculate complete FeatureSet                                 |
   //+----------------------------------------------------------------+
   virtual bool Calculate(const MarketSnapshot &market,
                          FeatureSet &features) override
     {
      features.symbol=market.symbol;
      features.timeframe=market.timeframe;
      features.bar_time=market.closed_bar.time;

      features.ema_fast=EMPTY_VALUE;
      features.ema_slow=EMPTY_VALUE;
      features.ema_long=EMPTY_VALUE;

      features.adx=EMPTY_VALUE;
      features.atr=EMPTY_VALUE;
      features.rsi=EMPTY_VALUE;
      features.roc=EMPTY_VALUE;

      features.macd_main=EMPTY_VALUE;
      features.macd_signal=EMPTY_VALUE;

      features.volume_ratio=EMPTY_VALUE;

      features.candle_body=EMPTY_VALUE;
      features.candle_range=EMPTY_VALUE;
      features.candle_strength=EMPTY_VALUE;

      features.volatility=EMPTY_VALUE;

      features.valid=false;

      if(!market.valid)
         return false;

      if(!m_initialized)
         return false;

      if(market.symbol!=m_symbol ||
         market.timeframe!=m_timeframe)
         return false;
         
      if(Bars(m_symbol,m_timeframe)<
         MinimumBarsRequired())
         return false;

      // IMPORTANT:
      // shift=1 means latest CLOSED bar.
      if(!CopyOne(m_ema_fast_handle,
                  0,
                  1,
                  features.ema_fast))
         return false;

      if(!CopyOne(m_ema_slow_handle,
                  0,
                  1,
                  features.ema_slow))
         return false;

      if(!CopyOne(m_ema_long_handle,
                  0,
                  1,
                  features.ema_long))
         return false;

      // ADX buffer 0 = ADX main line.
      if(!CopyOne(m_adx_handle,
                  0,
                  1,
                  features.adx))
         return false;

      if(!CopyOne(m_atr_handle,
                  0,
                  1,
                  features.atr))
         return false;

      if(!CopyOne(m_rsi_handle,
                  0,
                  1,
                  features.rsi))
         return false;

      // MACD buffer 0 = MAIN_LINE.
      if(!CopyOne(m_macd_handle,
                  0,
                  1,
                  features.macd_main))
         return false;

      // MACD buffer 1 = SIGNAL_LINE.
      if(!CopyOne(m_macd_handle,
                  1,
                  1,
                  features.macd_signal))
         return false;

      if(!CalculateROC(market.symbol,
                       market.timeframe,
                       1,
                       features.roc))
         return false;

      if(!CalculateVolumeRatio(market.symbol,
                               market.timeframe,
                               1,
                               features.volume_ratio))
         return false;

      if(!CalculateCandleFeatures(market.closed_bar,
                                  features.candle_body,
                                  features.candle_range,
                                  features.candle_strength))
         return false;

      if(features.atr<=0.0)
         return false;

      // ATR relative to closing price as a normalized
      // volatility measure.
      if(market.closed_bar.close<=0.0)
         return false;

      features.volatility=
         features.atr/market.closed_bar.close;

      if(!MathIsValidNumber(features.volatility))
         return false;

      features.valid=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Minimum bars required                                         |
   //+----------------------------------------------------------------+
   int MinimumBarsRequired() const
     {
      int minimum=m_ema_long_period;

      if(m_adx_period>minimum)
         minimum=m_adx_period;

      if(m_atr_period>minimum)
         minimum=m_atr_period;

      if(m_rsi_period>minimum)
         minimum=m_rsi_period;

      if(m_macd_slow+m_macd_signal>minimum)
         minimum=m_macd_slow+m_macd_signal;

      if(m_roc_period>minimum)
         minimum=m_roc_period;

      if(m_volume_period>minimum)
         minimum=m_volume_period;

      // Add safety margin for initialization/calculation.
      return minimum+10;
     }

   //+----------------------------------------------------------------+
   //| Accessors                                                     |
   //+----------------------------------------------------------------+
   string Symbol() const
     {
      return m_symbol;
     }

   ENUM_TIMEFRAMES Timeframe() const
     {
      return m_timeframe;
     }

   bool IsInitialized() const
     {
      return m_initialized;
     }
  };

#endif