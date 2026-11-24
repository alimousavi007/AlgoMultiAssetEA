#ifndef __ALGOSYSTEM_INDICATORS_MQH__
#define __ALGOSYSTEM_INDICATORS_MQH__

#include "Interfaces.mqh"

//+------------------------------------------------------------------+
//| Indicator Handle Cache with Reference Counting                   |
//| Prevents duplicate handle creation for same symbol/timeframe/    |
//| parameter combination across multiple CFeatureEngine instances.  |
//+------------------------------------------------------------------+
class CIndicatorHandleCache
{
private:
   struct HandleEntry
   {
      int                handle;
      int                ref_count;
      string             symbol;
      ENUM_TIMEFRAMES    timeframe;
      int                indicator_type;  // 0=EMA, 1=ADX, 2=ATR, 3=RSI, 4=MACD
      int                period1;
      int                period2;
      int                period3;
      int                price_type;
      datetime           created_time;
   };

   HandleEntry          m_handles[128];
   int                  m_handle_count;

   // Instrumentation counters (static for process-wide aggregation)
   static ulong         s_handles_created;
   static ulong         s_handles_released;
   static ulong         s_handles_reused;
   static ulong         s_copybuffer_calls;
   static ulong         s_copybuffer_failures;
   static ulong         s_copyrates_calls;
   static ulong         s_copyrates_failures;

   int FindHandleIndex(const string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       int indicator_type,
                       int period1,
                       int period2,
                       int period3,
                       int price_type) const
   {
      for(int i=0; i<m_handle_count; i++)
      {
         if(m_handles[i].symbol==symbol &&
            m_handles[i].timeframe==timeframe &&
            m_handles[i].indicator_type==indicator_type &&
            m_handles[i].period1==period1 &&
            m_handles[i].period2==period2 &&
            m_handles[i].period3==period3 &&
            m_handles[i].price_type==price_type)
         {
            return i;
         }
      }
      return -1;
   }

   int AddHandleEntry(const string symbol,
                      ENUM_TIMEFRAMES timeframe,
                      int indicator_type,
                      int period1,
                      int period2,
                      int period3,
                      int price_type,
                      int handle)
   {
      if(m_handle_count >= 128)
         return -1;

      int idx = m_handle_count;
      m_handles[idx].handle = handle;
      m_handles[idx].ref_count = 1;
      m_handles[idx].symbol = symbol;
      m_handles[idx].timeframe = timeframe;
      m_handles[idx].indicator_type = indicator_type;
      m_handles[idx].period1 = period1;
      m_handles[idx].period2 = period2;
      m_handles[idx].period3 = period3;
      m_handles[idx].price_type = price_type;
      m_handles[idx].created_time = TimeCurrent();
      m_handle_count++;

      s_handles_created++;
      return idx;
   }

public:
   CIndicatorHandleCache()
   {
      m_handle_count = 0;
      ArrayInitialize(m_handles, 0);
   }

   ~CIndicatorHandleCache()
   {
      ReleaseAll();
   }

   // Get or create an indicator handle with reference counting
   int GetOrCreateHandle(const string symbol,
                         ENUM_TIMEFRAMES timeframe,
                         int indicator_type,
                         int period1,
                         int period2=0,
                         int period3=0,
                         int price_type=PRICE_CLOSE)
   {
      int idx = FindHandleIndex(symbol, timeframe, indicator_type, period1, period2, period3, price_type);
      if(idx >= 0)
      {
         m_handles[idx].ref_count++;
         s_handles_reused++;
         return m_handles[idx].handle;
      }

      int handle = INVALID_HANDLE;
      ResetLastError();

      switch(indicator_type)
      {
         case 0: // EMA
            handle = iMA(symbol, timeframe, period1, 0, MODE_EMA, price_type);
            break;
         case 1: // ADX
            handle = iADX(symbol, timeframe, period1);
            break;
         case 2: // ATR
            handle = iATR(symbol, timeframe, period1);
            break;
         case 3: // RSI
            handle = iRSI(symbol, timeframe, period1, price_type);
            break;
         case 4: // MACD
            handle = iMACD(symbol, timeframe, period1, period2, period3, price_type);
            break;
         default:
            return INVALID_HANDLE;
      }

      if(handle == INVALID_HANDLE)
         return INVALID_HANDLE;

      AddHandleEntry(symbol, timeframe, indicator_type, period1, period2, period3, price_type, handle);
      return handle;
   }

   // Release a handle reference; actual IndicatorRelease when ref_count reaches 0
   void ReleaseHandle(const string symbol,
                      ENUM_TIMEFRAMES timeframe,
                      int indicator_type,
                      int period1,
                      int period2=0,
                      int period3=0,
                      int price_type=PRICE_CLOSE)
   {
      int idx = FindHandleIndex(symbol, timeframe, indicator_type, period1, period2, period3, price_type);
      if(idx < 0)
         return;

      m_handles[idx].ref_count--;
      if(m_handles[idx].ref_count <= 0)
      {
         if(m_handles[idx].handle != INVALID_HANDLE)
         {
            IndicatorRelease(m_handles[idx].handle);
            s_handles_released++;
         }
         // Remove from array by shifting
         for(int i=idx; i<m_handle_count-1; i++)
            m_handles[i] = m_handles[i+1];
         m_handle_count--;
      }
   }

   // Release all handles (for cleanup)
   void ReleaseAll()
   {
      for(int i=0; i<m_handle_count; i++)
      {
         if(m_handles[i].handle != INVALID_HANDLE)
         {
            IndicatorRelease(m_handles[i].handle);
            s_handles_released++;
         }
      }
      m_handle_count = 0;
   }

   // Get active handle count for metrics
   int ActiveHandleCount() const { return m_handle_count; }

   // Instrumentation accessors (static)
   static ulong HandlesCreated() { return s_handles_created; }
   static ulong HandlesReleased() { return s_handles_released; }
   static ulong HandlesReused() { return s_handles_reused; }
   static ulong CopyBufferCalls() { return s_copybuffer_calls; }
   static ulong CopyBufferFailures() { return s_copybuffer_failures; }
   static ulong CopyRatesCalls() { return s_copyrates_calls; }
   static ulong CopyRatesFailures() { return s_copyrates_failures; }

   // Increment instrumentation counters
   static void IncCopyBufferCalls() { s_copybuffer_calls++; }
   static void IncCopyBufferFailures() { s_copybuffer_failures++; }
   static void IncCopyRatesCalls() { s_copyrates_calls++; }
   static void IncCopyRatesFailures() { s_copyrates_failures++; }

   // Reset all counters (for testing)
   static void ResetCounters()
   {
      s_handles_created = 0;
      s_handles_released = 0;
      s_handles_reused = 0;
      s_copybuffer_calls = 0;
      s_copybuffer_failures = 0;
      s_copyrates_calls = 0;
      s_copyrates_failures = 0;
   }
};

// Static member definitions
ulong CIndicatorHandleCache::s_handles_created = 0;
ulong CIndicatorHandleCache::s_handles_released = 0;
ulong CIndicatorHandleCache::s_handles_reused = 0;
ulong CIndicatorHandleCache::s_copybuffer_calls = 0;
ulong CIndicatorHandleCache::s_copybuffer_failures = 0;
ulong CIndicatorHandleCache::s_copyrates_calls = 0;
ulong CIndicatorHandleCache::s_copyrates_failures = 0;

// Global singleton instance
CIndicatorHandleCache g_indicator_cache;

//+------------------------------------------------------------------+
//| Indicator / Feature Engine                                       |
//|                                                                  |
//| Responsibility:                                                  |
//| - create and maintain indicator handles (via shared cache)       |
//| - read indicator values                                          |
//| - calculate price/volume features                                |
//| - use CLOSED BAR data by default                                 |
//|                                                                  |
//| Does NOT:                                                        |
//| - detect market regime                                           |
//| - generate trade signals                                         |
//| - calculate position size                                        |
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

   //--- indicator handle keys (for cache release)
   struct HandleKey
   {
      int indicator_type;
      int period1;
      int period2;
      int period3;
      int price_type;
   };

   HandleKey m_handle_keys[7];
   int m_handle_key_count;

   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Register a handle key for later release                        |
   //+----------------------------------------------------------------+
   void RegisterHandleKey(int indicator_type,
                          int period1,
                          int period2=0,
                          int period3=0,
                          int price_type=PRICE_CLOSE)
   {
      if(m_handle_key_count < 7)
      {
         m_handle_keys[m_handle_key_count].indicator_type = indicator_type;
         m_handle_keys[m_handle_key_count].period1 = period1;
         m_handle_keys[m_handle_key_count].period2 = period2;
         m_handle_keys[m_handle_key_count].period3 = period3;
         m_handle_keys[m_handle_key_count].price_type = price_type;
         m_handle_key_count++;
      }
   }

   //+----------------------------------------------------------------+
   //| Release all handles via cache                                  |
   //+----------------------------------------------------------------+
   void ReleaseAllHandles()
   {
      for(int i=0; i<m_handle_key_count; i++)
      {
         g_indicator_cache.ReleaseHandle(m_symbol,
                                         m_timeframe,
                                         m_handle_keys[i].indicator_type,
                                         m_handle_keys[i].period1,
                                         m_handle_keys[i].period2,
                                         m_handle_keys[i].period3,
                                         m_handle_keys[i].price_type);
      }
      m_handle_key_count = 0;
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
   //| Copy one value from an indicator buffer                        |
   //|                                                                  |
   //| shift = 1 => latest CLOSED bar                                 |
   //| shift = 0 => current/forming bar                               |
   //+----------------------------------------------------------------+
   bool CopyOne(const int handle,
                const int buffer_index,
                const int shift,
                double &value) const
   {
      value = EMPTY_VALUE;

      if(handle == INVALID_HANDLE)
         return false;

      if(BarsCalculated(handle) < shift+1)
         return false;

      double buffer[1];

      ResetLastError();

      CIndicatorHandleCache::IncCopyBufferCalls();

      int copied = CopyBuffer(handle,
                              buffer_index,
                              shift,
                              1,
                              buffer);

      if(copied != 1)
      {
         CIndicatorHandleCache::IncCopyBufferFailures();
         return false;
      }

      if(buffer[0] == EMPTY_VALUE ||
         !MathIsValidNumber(buffer[0]))
      {
         CIndicatorHandleCache::IncCopyBufferFailures();
         return false;
      }

      value = buffer[0];

      return true;
   }

   //+----------------------------------------------------------------+
   //| Calculate ROC from closed bars                                 |
   //+----------------------------------------------------------------+
   bool CalculateROC(const string symbol,
                     ENUM_TIMEFRAMES timeframe,
                     const int shift,
                     double &roc) const
   {
      roc = EMPTY_VALUE;

      if(m_roc_period <= 0)
         return false;

      // We need:
      // rates[0] = shift
      // rates[1] = shift + roc_period
      //
      // Therefore use CopyRates with an explicit starting position.
      int required = m_roc_period + 1;

      MqlRates history[];

      ArrayResize(history, required);

      ResetLastError();

      CIndicatorHandleCache::IncCopyRatesCalls();

      int copied = CopyRates(symbol,
                             timeframe,
                             shift,
                             required,
                             history);

      if(copied != required)
      {
         CIndicatorHandleCache::IncCopyRatesFailures();
         return false;
      }

      double old_close = history[0].close;
      double new_close = history[required-1].close;

      if(old_close <= 0.0)
      {
         CIndicatorHandleCache::IncCopyRatesFailures();
         return false;
      }

      roc = ((new_close - old_close) / old_close) * 100.0;

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
      ratio = EMPTY_VALUE;

      if(m_volume_period <= 0)
         return false;

      int required = m_volume_period + 1;

      MqlRates history[];

      ArrayResize(history, required);

      ResetLastError();

      CIndicatorHandleCache::IncCopyRatesCalls();

      int copied = CopyRates(symbol,
                             timeframe,
                             shift,
                             required,
                             history);

      if(copied != required)
      {
         CIndicatorHandleCache::IncCopyRatesFailures();
         return false;
      }

      double current_volume =
         (double)history[required-1].tick_volume;

      double average = 0.0;

      for(int i=0; i<m_volume_period; i++)
         average += (double)history[i].tick_volume;

      average /= (double)m_volume_period;

      if(average <= 0.0)
      {
         // No meaningful volume information.
         ratio = 0.0;
         return true;
      }

      ratio = current_volume / average;

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
      body = 0.0;
      range = 0.0;
      strength = 0.0;

      range = bar.high - bar.low;

      if(range <= 0.0)
         return false;

      body = MathAbs(bar.close - bar.open);

      strength = body / range;

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
      m_ema_fast_period = 20;
      m_ema_slow_period = 50;
      m_ema_long_period = 200;

      m_adx_period = 14;
      m_atr_period = 14;
      m_rsi_period = 14;

      m_macd_fast = 12;
      m_macd_slow = 26;
      m_macd_signal = 9;

      m_roc_period = 10;
      m_volume_period = 20;

      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;

      m_initialized = false;
      m_handle_key_count = 0;
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
      m_ema_fast_period = ema_fast;
      m_ema_slow_period = ema_slow;
      m_ema_long_period = ema_long;

      m_adx_period = adx_period;
      m_atr_period = atr_period;
      m_rsi_period = rsi_period;

      m_macd_fast = macd_fast;
      m_macd_slow = macd_slow;
      m_macd_signal = macd_signal;

      m_roc_period = roc_period;
      m_volume_period = volume_period;
   }

   //+----------------------------------------------------------------+
   //| Initialize handles via shared cache                            |
   //+----------------------------------------------------------------+
   bool InitializeFor(const string symbol,
                      ENUM_TIMEFRAMES timeframe)
   {
      m_initialized = false;

      ReleaseAllHandles();

      if(StringLen(symbol) == 0)
         return false;

      if(timeframe == PERIOD_CURRENT)
         return false;

      if(!ValidateParameters())
         return false;

      bool custom = false;

      if(!SymbolExist(symbol, custom))
         return false;

      if(!SymbolSelect(symbol, true))
         return false;

      if(!SymbolIsSynchronized(symbol))
         return false;

      m_symbol = symbol;
      m_timeframe = timeframe;
      m_handle_key_count = 0;

      //--- EMA handles via cache
      int handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_fast_period, 0, 0, PRICE_CLOSE);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(0, m_ema_fast_period, 0, 0, PRICE_CLOSE);

      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_slow_period, 0, 0, PRICE_CLOSE);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(0, m_ema_slow_period, 0, 0, PRICE_CLOSE);

      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_long_period, 0, 0, PRICE_CLOSE);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(0, m_ema_long_period, 0, 0, PRICE_CLOSE);

      //--- ADX via cache
      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 1, m_adx_period);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(1, m_adx_period);

      //--- ATR via cache
      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 2, m_atr_period);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(2, m_atr_period);

      //--- RSI via cache
      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 3, m_rsi_period, 0, 0, PRICE_CLOSE);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(3, m_rsi_period, 0, 0, PRICE_CLOSE);

      //--- MACD via cache
      handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 4, m_macd_fast, m_macd_slow, m_macd_signal, PRICE_CLOSE);
      if(handle == INVALID_HANDLE)
      {
         ReleaseAllHandles();
         return false;
      }
      RegisterHandleKey(4, m_macd_fast, m_macd_slow, m_macd_signal, PRICE_CLOSE);

      m_initialized = true;

      return true;
   }

   //+----------------------------------------------------------------+
   //| IFeatureEngine initialization                                  |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
   {
      if(StringLen(m_symbol) == 0 ||
         m_timeframe == PERIOD_CURRENT)
         return false;

      return InitializeFor(m_symbol, m_timeframe);
   }

   //+----------------------------------------------------------------+
   //| Calculate complete FeatureSet                                  |
   //+----------------------------------------------------------------+
   virtual bool Calculate(const MarketSnapshot &market,
                          FeatureSet &features) override
   {
      features.symbol = market.symbol;
      features.timeframe = market.timeframe;
      features.bar_time = market.closed_bar.time;

      features.ema_fast = EMPTY_VALUE;
      features.ema_slow = EMPTY_VALUE;
      features.ema_long = EMPTY_VALUE;

      features.adx = EMPTY_VALUE;
      features.atr = EMPTY_VALUE;
      features.rsi = EMPTY_VALUE;
      features.roc = EMPTY_VALUE;

      features.macd_main = EMPTY_VALUE;
      features.macd_signal = EMPTY_VALUE;

      features.volume_ratio = EMPTY_VALUE;

      features.candle_body = EMPTY_VALUE;
      features.candle_range = EMPTY_VALUE;
      features.candle_strength = EMPTY_VALUE;

      features.volatility = EMPTY_VALUE;

      features.valid = false;

      if(!market.valid)
         return false;

      if(!m_initialized)
         return false;

      if(market.symbol != m_symbol ||
         market.timeframe != m_timeframe)
         return false;

      if(Bars(m_symbol, m_timeframe) < MinimumBarsRequired())
         return false;

      // IMPORTANT:
      // shift=1 means latest CLOSED bar.
      // Get handles from cache for CopyOne
      int ema_fast_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_fast_period, 0, 0, PRICE_CLOSE);
      int ema_slow_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_slow_period, 0, 0, PRICE_CLOSE);
      int ema_long_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 0, m_ema_long_period, 0, 0, PRICE_CLOSE);
      int adx_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 1, m_adx_period);
      int atr_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 2, m_atr_period);
      int rsi_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 3, m_rsi_period, 0, 0, PRICE_CLOSE);
      int macd_handle = g_indicator_cache.GetOrCreateHandle(m_symbol, m_timeframe, 4, m_macd_fast, m_macd_slow, m_macd_signal, PRICE_CLOSE);

      if(!CopyOne(ema_fast_handle, 0, 1, features.ema_fast))
         return false;

      if(!CopyOne(ema_slow_handle, 0, 1, features.ema_slow))
         return false;

      if(!CopyOne(ema_long_handle, 0, 1, features.ema_long))
         return false;

      // ADX buffer 0 = ADX main line.
      if(!CopyOne(adx_handle, 0, 1, features.adx))
         return false;

      if(!CopyOne(atr_handle, 0, 1, features.atr))
         return false;

      if(!CopyOne(rsi_handle, 0, 1, features.rsi))
         return false;

      // MACD buffer 0 = MAIN_LINE.
      if(!CopyOne(macd_handle, 0, 1, features.macd_main))
         return false;

      // MACD buffer 1 = SIGNAL_LINE.
      if(!CopyOne(macd_handle, 1, 1, features.macd_signal))
         return false;

      if(!CalculateROC(market.symbol, market.timeframe, 1, features.roc))
         return false;

      if(!CalculateVolumeRatio(market.symbol, market.timeframe, 1, features.volume_ratio))
         return false;

      if(!CalculateCandleFeatures(market.closed_bar, features.candle_body, features.candle_range, features.candle_strength))
         return false;

      if(features.atr <= 0.0)
         return false;

      // ATR relative to closing price as a normalized volatility measure.
      if(market.closed_bar.close <= 0.0)
         return false;

      features.volatility = features.atr / market.closed_bar.close;

      if(!MathIsValidNumber(features.volatility))
         return false;

      features.valid = true;

      return true;
   }

   //+----------------------------------------------------------------+
   //| Minimum bars required                                          |
   //+----------------------------------------------------------------+
   int MinimumBarsRequired() const
   {
      int minimum = m_ema_long_period;

      if(m_adx_period > minimum)
         minimum = m_adx_period;

      if(m_atr_period > minimum)
         minimum = m_atr_period;

      if(m_rsi_period > minimum)
         minimum = m_rsi_period;

      if(m_macd_slow + m_macd_signal > minimum)
         minimum = m_macd_slow + m_macd_signal;

      if(m_roc_period > minimum)
         minimum = m_roc_period;

      if(m_volume_period > minimum)
         minimum = m_volume_period;

      // Add safety margin for initialization/calculation.
      return minimum + 10;
   }

   //+----------------------------------------------------------------+
   //| Accessors                                                      |
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

   //--- Static accessors for instrumentation ---
   static ulong GetHandlesCreated() { return CIndicatorHandleCache::HandlesCreated(); }
   static ulong GetHandlesReleased() { return CIndicatorHandleCache::HandlesReleased(); }
   static ulong GetHandlesReused() { return CIndicatorHandleCache::HandlesReused(); }
   static ulong GetCopyBufferCalls() { return CIndicatorHandleCache::CopyBufferCalls(); }
   static ulong GetCopyBufferFailures() { return CIndicatorHandleCache::CopyBufferFailures(); }
   static ulong GetCopyRatesCalls() { return CIndicatorHandleCache::CopyRatesCalls(); }
   static ulong GetCopyRatesFailures() { return CIndicatorHandleCache::CopyRatesFailures(); }
   static int GetActiveHandleCount() { return g_indicator_cache.ActiveHandleCount(); }
   static void ResetInstrumentation() { CIndicatorHandleCache::ResetCounters(); }
};

#endif