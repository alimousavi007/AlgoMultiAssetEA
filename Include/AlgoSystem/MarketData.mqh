#ifndef __ALGOSYSTEM_MARKETDATA_MQH__
#define __ALGOSYSTEM_MARKETDATA_MQH__

#include "Interfaces.mqh"

//+------------------------------------------------------------------+
//| Market Data Engine                                               |
//| Responsibility:                                                 |
//| - symbol validation                                              |
//| - Market Watch selection                                         |
//| - synchronization validation                                    |
//| - symbol contract properties                                    |
//| - current tick                                                   |
//| - current/closed bars                                            |
//| - new closed-bar detection                                      |
//|                                                                  |
//| This class DOES NOT:                                            |
//| - calculate indicators                                          |
//| - generate signals                                               |
//| - calculate risk                                                 |
//| - send orders                                                    |
//+------------------------------------------------------------------+
class CMarketDataEngine : public IMarketDataProvider
  {
public:
   //+------------------------------------------------------------------+
   //| Symbol validation result codes                                   |
   //| Precise diagnostics for disabled / missing / stale / inaccessible  |
   //| symbols (WP-02 item 7).                                            |
   //+------------------------------------------------------------------+
   enum EMarketDataValidateResult
     {
      MARKET_DATA_VALID_OK                = 0,  // Symbol fully valid for data access
      MARKET_DATA_VALID_EMPTY_SYMBOL      = 1,  // Symbol string is empty
      MARKET_DATA_VALID_NOT_EXIST         = 2,  // SymbolExist returned false (missing symbol)
      MARKET_DATA_VALID_NOT_SELECTABLE    = 3,  // SymbolSelect failed (inaccessible / not in Market Watch)
      MARKET_DATA_VALID_NOT_SYNCHRONIZED  = 4,  // SymbolIsSynchronized returned false (stale / history not ready)
      MARKET_DATA_VALID_TRADE_DISABLED    = 5,  // SYMBOL_TRADE_MODE_DISABLED (data accessible, trading blocked)
      MARKET_DATA_VALID_INVALID_TIMEFRAME = 6,  // PERIOD_CURRENT or invalid timeframe
      MARKET_DATA_VALID_LOOKUP_ERROR      = 7   // Underlying API/lookup error (tick/bar read failed)
     };

private:

   string                              m_symbols[];
   ENUM_TIMEFRAMES                     m_timeframes[];
   datetime                            m_last_closed_bar[];

   EMarketDataValidateResult           m_last_validation_result;
   string                              m_last_validation_detail;

   int FindRegistration(const string symbol,
                        const ENUM_TIMEFRAMES timeframe) const
     {
      int count=ArraySize(m_symbols);

      for(int i=0; i<count; i++)
        {
         if(m_symbols[i]==symbol &&
            m_timeframes[i]==timeframe)
            return i;
        }

      return -1;
     }

   //+------------------------------------------------------------------+
   //| Detailed symbol validation.                                      |
   //| Returns true only when the symbol is usable for data access.     |
   //| The detailed result/detail are always populated so callers can   |
   //| report exactly WHY a symbol is disabled / missing / stale /      |
   //| inaccessible instead of a generic "invalid symbol".              |
   //+------------------------------------------------------------------+
   bool ValidateSymbol(const string symbol)
     {
      m_last_validation_result = MARKET_DATA_VALID_LOOKUP_ERROR;
      m_last_validation_detail = "";

      if(StringLen(symbol)==0)
        {
         m_last_validation_result = MARKET_DATA_VALID_EMPTY_SYMBOL;
         m_last_validation_detail = "Symbol string is empty";
         return false;
        }

      bool is_custom=false;
      ResetLastError();
      if(!SymbolExist(symbol,is_custom))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_NOT_EXIST;
         m_last_validation_detail = "Symbol does not exist"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      ResetLastError();
      if(!SymbolSelect(symbol,true))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_NOT_SELECTABLE;
         m_last_validation_detail = "SymbolSelect failed (inaccessible / not in Market Watch)"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      ResetLastError();
      if(!SymbolIsSynchronized(symbol))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_NOT_SYNCHRONIZED;
         m_last_validation_detail = "Symbol not synchronized (stale / history not ready)"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      // Trade mode is reported for diagnostics but does NOT block data access:
      // a symbol can be present and synchronized yet not tradable (e.g. close-only).
      long trade_mode=0;
      if(SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,trade_mode) && trade_mode==SYMBOL_TRADE_MODE_DISABLED)
        {
         m_last_validation_result = MARKET_DATA_VALID_TRADE_DISABLED;
         m_last_validation_detail = "Symbol trade mode disabled (data accessible, trading blocked)";
         return true;
        }

      m_last_validation_result = MARKET_DATA_VALID_OK;
      m_last_validation_detail = "Symbol valid";
      return true;
     }

   //+------------------------------------------------------------------+
   //| Timeframe validation                                             |
   //+------------------------------------------------------------------+

   bool ValidateTimeframe(const ENUM_TIMEFRAMES timeframe)
     {
     if(timeframe==PERIOD_CURRENT)
       {
       m_last_validation_result = MARKET_DATA_VALID_INVALID_TIMEFRAME;
       m_last_validation_detail = "Invalid timeframe (PERIOD_CURRENT)";
       return false;
       }

     m_last_validation_result = MARKET_DATA_VALID_OK;
     m_last_validation_detail = "Timeframe valid";
     return true;
     }

   //+------------------------------------------------------------------+
   //| Last validation result accessors (for caller-side diagnostics)   |
   //+------------------------------------------------------------------+

   EMarketDataValidateResult LastValidationResult() const { return m_last_validation_result; }

   string LastValidationDetail() const { return m_last_validation_detail; }

   bool LoadBar(const string symbol,
                const ENUM_TIMEFRAMES timeframe,
                const int shift,
                BarData &bar)
     {
      MqlRates rates[1];

      ResetLastError();

      int copied=CopyRates(symbol,
                           timeframe,
                           shift,
                           1,
                           rates);

      if(copied!=1)
         return false;

      bar.time        = rates[0].time;
      bar.open        = rates[0].open;
      bar.high        = rates[0].high;
      bar.low         = rates[0].low;
      bar.close       = rates[0].close;
      bar.tick_volume = rates[0].tick_volume;
      bar.real_volume = rates[0].real_volume;
      bar.spread      = rates[0].spread;

      return true;
     }

   bool LoadSymbolProperties(const string symbol,
                             SymbolProperties &properties)
     {
      properties.symbol=symbol;

      long digits=0;
      long stops_level=0;
      long freeze_level=0;
      long trade_mode=0;
      long selected=0;

      if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,digits))
         return false;

      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,
                            stops_level))
         return false;

      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,
                            freeze_level))
         return false;

      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,
                            trade_mode))
         return false;

      if(!SymbolInfoInteger(symbol,SYMBOL_SELECT,
                            selected))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_POINT,
                           properties.point))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_TRADE_TICK_SIZE,
                           properties.tick_size))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_TRADE_TICK_VALUE,
                           properties.tick_value))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_TRADE_TICK_VALUE_PROFIT,
                           properties.tick_value_profit))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_TRADE_TICK_VALUE_LOSS,
                           properties.tick_value_loss))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_VOLUME_MIN,
                           properties.volume_min))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_VOLUME_MAX,
                           properties.volume_max))
         return false;

      if(!SymbolInfoDouble(symbol,
                           SYMBOL_VOLUME_STEP,
                           properties.volume_step))
         return false;

      properties.digits=(int)digits;
      properties.stops_level=(int)stops_level;
      properties.freeze_level=(int)freeze_level;

      properties.trade_allowed=
         (trade_mode!=SYMBOL_TRADE_MODE_DISABLED);

      properties.selected=(selected!=0);

      return true;
     }

public:

   CMarketDataEngine()
     {
      ArrayResize(m_symbols,0);
      ArrayResize(m_timeframes,0);
      ArrayResize(m_last_closed_bar,0);
      m_last_validation_result=MARKET_DATA_VALID_OK;
      m_last_validation_detail="";
     }

   //+---------------------------------------------------------------+
   //| IMarketDataProvider                                           |
   //+---------------------------------------------------------------+

   virtual bool Initialize() override
     {
      ArrayResize(m_symbols,0);
      ArrayResize(m_timeframes,0);
      ArrayResize(m_last_closed_bar,0);
      m_last_validation_result=MARKET_DATA_VALID_OK;
      m_last_validation_detail="";

      return true;
     }

   virtual bool Update(const string symbol,
                       ENUM_TIMEFRAMES timeframe) override
     {
      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      MarketSnapshot snapshot;

      return GetSnapshot(symbol,
                         timeframe,
                         snapshot);
     }

   virtual bool GetSnapshot(const string symbol,
                            ENUM_TIMEFRAMES timeframe,
                            MarketSnapshot &snapshot) override
     {
      snapshot.valid=false;

      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      MqlTick tick;

      ResetLastError();

      if(!SymbolInfoTick(symbol,tick))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_LOOKUP_ERROR;
         m_last_validation_detail = "SymbolInfoTick failed"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      SymbolProperties properties;

      if(!LoadSymbolProperties(symbol,
                               properties))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_LOOKUP_ERROR;
         m_last_validation_detail = "LoadSymbolProperties failed"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      BarData current_bar;
      BarData closed_bar;

      // shift 0 = current/forming bar
      if(!LoadBar(symbol,
                  timeframe,
                  0,
                  current_bar))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_LOOKUP_ERROR;
         m_last_validation_detail = "LoadBar(shift=0/current) failed"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      // shift 1 = latest completed/closed bar
      if(!LoadBar(symbol,
                  timeframe,
                  1,
                  closed_bar))
        {
         int err=GetLastError();
         m_last_validation_result = MARKET_DATA_VALID_LOOKUP_ERROR;
         m_last_validation_detail = "LoadBar(shift=1/closed) failed"+(err>0 ? " error="+IntegerToString(err) : "");
         return false;
        }

      snapshot.symbol=symbol;
      snapshot.timeframe=timeframe;

      snapshot.current_time=tick.time;
      snapshot.closed_bar_time=closed_bar.time;

      snapshot.bid=tick.bid;
      snapshot.ask=tick.ask;

      if(properties.point>0.0)
         snapshot.spread_points=
            (tick.ask-tick.bid)/properties.point;
      else
         snapshot.spread_points=0.0;

      snapshot.current_bar=current_bar;
      snapshot.closed_bar=closed_bar;

      snapshot.properties=properties;

      snapshot.valid=true;

      return true;
     }

   virtual bool IsNewClosedBar(const string symbol,
                               ENUM_TIMEFRAMES timeframe) override
     {
      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      BarData closed_bar;

      if(!LoadBar(symbol,
                  timeframe,
                  1,
                  closed_bar))
         return false;

      int index=FindRegistration(symbol,timeframe);

      if(index<0)
        {
         int new_size=ArraySize(m_symbols)+1;

         ArrayResize(m_symbols,new_size);
         ArrayResize(m_timeframes,new_size);
         ArrayResize(m_last_closed_bar,new_size);

         index=new_size-1;

         m_symbols[index]=symbol;
         m_timeframes[index]=timeframe;

         // First observation is initialization, not a signal event.
         m_last_closed_bar[index]=closed_bar.time;

         return false;
        }

      if(m_last_closed_bar[index]==closed_bar.time)
         return false;

      m_last_closed_bar[index]=closed_bar.time;

      return true;
     }

   //+---------------------------------------------------------------+
   //| Explicit registration                                         |
   //+---------------------------------------------------------------+

   bool Register(const string symbol,
                 ENUM_TIMEFRAMES timeframe)
     {
      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      if(FindRegistration(symbol,timeframe)>=0)
         return true;

      int new_size=ArraySize(m_symbols)+1;

      ArrayResize(m_symbols,new_size);
      ArrayResize(m_timeframes,new_size);
      ArrayResize(m_last_closed_bar,new_size);

      int index=new_size-1;

     /*m_symbols[index]=symbol;
      m_timeframes[index]=timeframe;
      m_last_closed_bar[index]=0;*/
      
      BarData closed_bar;
      
      if(!LoadBar(symbol,
                  timeframe,
                  1,
                  closed_bar))
         return false;
      
      m_symbols[index]=symbol;
      m_timeframes[index]=timeframe;
      m_last_closed_bar[index]=closed_bar.time;

      return true;
     }

   //+---------------------------------------------------------------+
   //| History availability check                                    |
   //+---------------------------------------------------------------+

   bool HasEnoughBars(const string symbol,
                      ENUM_TIMEFRAMES timeframe,
                      const int minimum_bars) const
     {
      if(minimum_bars<=0)
         return true;

      int bars=Bars(symbol,timeframe);

      return (bars>=minimum_bars);
     }

   //+---------------------------------------------------------------+
   //| Synchronization check                                         |
   //+---------------------------------------------------------------+

   bool IsSynchronized(const string symbol) const
     {
      if(StringLen(symbol)==0)
         return false;

      return SymbolIsSynchronized(symbol);
     }

   //+---------------------------------------------------------------+
   //| Return symbol properties                                      |
   //+---------------------------------------------------------------+

   bool GetSymbolProperties(const string symbol,
                            SymbolProperties &properties)
     {
      if(!ValidateSymbol(symbol))
         return false;

      return LoadSymbolProperties(symbol,
                                  properties);
     }

   //+---------------------------------------------------------------+
   //| Return current tick                                           |
   //+---------------------------------------------------------------+

   bool GetTick(const string symbol,
                MqlTick &tick)
     {
      if(!ValidateSymbol(symbol))
         return false;

      ResetLastError();

      return SymbolInfoTick(symbol,tick);
     }

   //+---------------------------------------------------------------+
   //| Return one closed bar                                         |
   //+---------------------------------------------------------------+

   bool GetClosedBar(const string symbol,
                     ENUM_TIMEFRAMES timeframe,
                     BarData &bar)
     {
      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      return LoadBar(symbol,
                     timeframe,
                     1,
                     bar);
     }

   //+---------------------------------------------------------------+
   //| Return one current/forming bar                                |
   //+---------------------------------------------------------------+

   bool GetCurrentBar(const string symbol,
                      ENUM_TIMEFRAMES timeframe,
                      BarData &bar)
     {
      if(!ValidateTimeframe(timeframe))
         return false;

      if(!ValidateSymbol(symbol))
         return false;

      return LoadBar(symbol,
                     timeframe,
                     0,
                     bar);
     }

   //+---------------------------------------------------------------+
   //| Registered data stream count                                  |
   //+---------------------------------------------------------------+

    int GetSymbolDigits(const string symbol) const
     {
      long digits=0;
      if(!SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits))
         return 0;
      return (int)digits;
     }

    int RegistrationCount() const
     {
      return ArraySize(m_symbols);
     }
  };

#endif