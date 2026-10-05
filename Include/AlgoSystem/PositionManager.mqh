#ifndef __ALGOSYSTEM_POSITIONMANAGER_MQH__
#define __ALGOSYSTEM_POSITIONMANAGER_MQH__

#include "Interfaces.mqh"
#include "TradeExecutor.mqh"

//+------------------------------------------------------------------+
//| Position Manager                                                 |
//|                                                                  |
//| Responsibility:                                                 |
//| - discover managed positions                                    |
//| - break-even                                                     |
//| - ATR trailing                                                   |
//| - time exit                                                      |
//| - controlled emergency close                                    |
//| - never increase position risk                                  |
//|                                                                  |
//| Does NOT:                                                        |
//| - generate entry signals                                        |
//| - calculate entry volume                                         |
//+------------------------------------------------------------------+
class CPositionManager : public IPositionManager
  {
private:

   ITradeExecutor *m_executor;

   bool   m_initialized;

   bool   m_use_break_even;
   bool   m_use_trailing;
   bool   m_use_time_exit;

   double m_break_even_trigger_r;
   double m_break_even_offset_points;

   ENUM_TIMEFRAMES m_trailing_timeframe;
   int    m_atr_period;
   double m_trailing_atr_multiplier;

   int    m_max_holding_minutes;

   bool   m_emergency_close;

   //+----------------------------------------------------------------+
   //| Check whether magic belongs to this EA                        |
   //+----------------------------------------------------------------+
   bool IsManagedMagic(const long magic) const
     {
      return
         magic==MAGIC_TREND ||
         magic==MAGIC_BREAKOUT ||
         magic==MAGIC_MOMENTUM ||
         magic==MAGIC_MEAN_REVERSION ||
         magic==MAGIC_RELATIVE_VALUE;
     }
   
   bool NormalizeSLToTick(
   const string symbol,
   const ENUM_POSITION_TYPE type,
   const double price,
   double &normalized) const
  {
      double tick_size=
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE);
   
      int digits=
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS);
   
      if(tick_size<=0.0 ||
         digits<0 ||
         price<=0.0)
         return false;
   
      if(type==POSITION_TYPE_BUY)
         normalized=
            MathFloor(
               price/tick_size+1e-12)*
            tick_size;
      else
         normalized=
            MathCeil(
               price/tick_size-1e-12)*
            tick_size;
   
      normalized=
         NormalizeDouble(
            normalized,
            digits);
   
      return normalized>0.0;
     }
   //+----------------------------------------------------------------+
   //| Strategy from magic                                           |
   //+----------------------------------------------------------------+
   ENUM_STRATEGY_ID StrategyFromMagic(
      const long magic) const
     {
      if(magic==MAGIC_TREND)
         return STRATEGY_TREND_PULLBACK;

      if(magic==MAGIC_BREAKOUT)
         return STRATEGY_BREAKOUT;

      if(magic==MAGIC_MOMENTUM)
         return STRATEGY_MOMENTUM;

      if(magic==MAGIC_MEAN_REVERSION)
         return STRATEGY_MEAN_REVERSION;

      if(magic==MAGIC_RELATIVE_VALUE)
         return STRATEGY_RELATIVE_VALUE;

      return STRATEGY_NONE;
     }

   //+----------------------------------------------------------------+
   //| Select position safely                                         |
   //+----------------------------------------------------------------+
   bool SelectPosition(const ulong ticket) const
     {
      if(ticket==0)
         return false;

      return PositionSelectByTicket(ticket);
     }

   //+----------------------------------------------------------------+
   //| Calculate current R                                            |
   //+----------------------------------------------------------------+
   double CurrentR(
      const ENUM_POSITION_TYPE type,
      const double open_price,
      const double stop_loss,
      const double current_price) const
     {
      if(open_price<=0.0 ||
         stop_loss<=0.0 ||
         current_price<=0.0)
         return 0.0;

      double initial_risk=0.0;
      double current_reward=0.0;

      if(type==POSITION_TYPE_BUY)
        {
         initial_risk=open_price-stop_loss;
         current_reward=current_price-open_price;
        }
      else
        {
         initial_risk=stop_loss-open_price;
         current_reward=open_price-current_price;
        }

      if(initial_risk<=0.0 ||
         current_reward<=0.0)
         return 0.0;

      return current_reward/initial_risk;
     }

   //+----------------------------------------------------------------+
   //| Modify SL through executor                                     |
   //+----------------------------------------------------------------+
   bool ModifySL(
      const ulong ticket,
      const double new_sl,
      const double current_tp) const
     {
      if(m_executor==NULL)
         return false;

      ExecutionRequest request;

      request.intent=ORDER_INTENT_MODIFY_SL;
      request.symbol="";
      request.direction=SIGNAL_NONE;
      

      request.volume=0.0;
      request.price=0.0;

      request.stop_loss=new_sl;
      request.take_profit=current_tp;

      request.position_ticket=ticket;
      if(!PositionSelectByTicket(ticket))
         return false;

      request.magic=
         PositionGetInteger(
         POSITION_MAGIC);
   
      request.strategy=
         StrategyFromMagic(
         request.magic);


      request.comment="PositionManager";
      request.signal_id="";

      ExecutionResult result;

      if(!m_executor.Validate(request))
         return false;

      return m_executor.Execute(
         request,
         result);
     }

   //+----------------------------------------------------------------+
   //| Close position through executor                                |
   //+----------------------------------------------------------------+
   bool ClosePosition(
      const ulong ticket,
      const long magic) const
     {
      if(m_executor==NULL)
         return false;

      ExecutionRequest request;

      request.intent=ORDER_INTENT_CLOSE;
      request.symbol="";
      request.direction=SIGNAL_NONE;
      request.strategy=StrategyFromMagic(magic);

      request.volume=0.0;
      request.price=0.0;

      request.stop_loss=0.0;
      request.take_profit=0.0;

      request.position_ticket=ticket;
      request.magic=magic;

      request.comment="PositionManager Close";
      request.signal_id="";

      ExecutionResult result;

      if(!m_executor.Validate(request))
         return false;

      return m_executor.Execute(
         request,
         result);
     }

   //+----------------------------------------------------------------+
   //| Break-even                                                     |
   //+----------------------------------------------------------------+
   bool TryBreakEven(
      const ulong ticket) const
     {
      if(!m_use_break_even)
         return false;

      if(!SelectPosition(ticket))
         return false;

      ENUM_POSITION_TYPE type=
         (ENUM_POSITION_TYPE)
         PositionGetInteger(POSITION_TYPE);

      string symbol=
         PositionGetString(POSITION_SYMBOL);

      double open_price=
         PositionGetDouble(POSITION_PRICE_OPEN);

      double current_sl=
         PositionGetDouble(POSITION_SL);

      double current_tp=
         PositionGetDouble(POSITION_TP);

      if(open_price<=0.0)
         return false;

      MqlTick tick;

      if(!SymbolInfoTick(symbol,tick))
         return false;

      double current_price;

      if(type==POSITION_TYPE_BUY)
         current_price=tick.bid;
      else
         current_price=tick.ask;

      double r=
         CurrentR(
            type,
            open_price,
            current_sl,
            current_price);

      if(r<m_break_even_trigger_r)
         return false;

      double point=
         SymbolInfoDouble(symbol,SYMBOL_POINT);

      if(point<=0.0)
         return false;

      double offset=
         m_break_even_offset_points*point;

      double new_sl;

      if(type==POSITION_TYPE_BUY)
        {
         new_sl=open_price+offset;

         // Never worsen an existing SL.
         if(current_sl>0.0 &&
            new_sl<=current_sl)
            return false;

         if(new_sl>=current_price)
            return false;
        }
      else
        {
         new_sl=open_price-offset;

         if(current_sl>0.0 &&
            new_sl>=current_sl)
            return false;

         if(new_sl<=current_price)
            return false;
        }

      double normalized_sl;

      if(!NormalizeSLToTick(
         symbol,
         type,
         new_sl,
         normalized_sl))
         return false;

      new_sl=normalized_sl;

      return ModifySL(
         ticket,
         new_sl,
         current_tp);
     }

   //+----------------------------------------------------------------+
   //| ATR trailing                                                   |
   //+----------------------------------------------------------------+
   bool TryTrailing(
      const ulong ticket) const
     {
      if(!m_use_trailing)
         return false;

      if(!SelectPosition(ticket))
         return false;

      string symbol=
         PositionGetString(POSITION_SYMBOL);

      ENUM_POSITION_TYPE type=
         (ENUM_POSITION_TYPE)
         PositionGetInteger(POSITION_TYPE);

      double current_sl=
         PositionGetDouble(POSITION_SL);

      double current_tp=
         PositionGetDouble(POSITION_TP);

      MqlTick tick;

      if(!SymbolInfoTick(symbol,tick))
         return false;

      double current_price;

      if(type==POSITION_TYPE_BUY)
         current_price=tick.bid;
      else
         current_price=tick.ask;

      if(current_price<=0.0)
         return false;

      int handle=
         iATR(
            symbol,
            m_trailing_timeframe,
            m_atr_period);

      if(handle==INVALID_HANDLE)
         return false;

      double buffer[1];

      int copied=
         CopyBuffer(
            handle,
            0,
            1,
            1,
            buffer);

      IndicatorRelease(handle);

      if(copied!=1)
         return false;

      if(!MathIsValidNumber(buffer[0]) ||
         buffer[0]<=0.0)
         return false;

      double atr=buffer[0];

      double new_sl;

      if(type==POSITION_TYPE_BUY)
        {
         new_sl=
            current_price-
            atr*m_trailing_atr_multiplier;

         if(current_sl>0.0 &&
            new_sl<=current_sl)
            return false;

         if(new_sl>=current_price)
            return false;
        }
      else
        {
         new_sl=
            current_price+
            atr*m_trailing_atr_multiplier;

         if(current_sl>0.0 &&
            new_sl>=current_sl)
            return false;

         if(new_sl<=current_price)
            return false;
        }

      double normalized_sl;
      
      if(!NormalizeSLToTick(
            symbol,
            type,
            new_sl,
            normalized_sl))
         return false;
      
      new_sl=normalized_sl;

      return ModifySL(
         ticket,
         new_sl,
         current_tp);
     }

   //+----------------------------------------------------------------+
   //| Time exit                                                      |
   //+----------------------------------------------------------------+
   bool TryTimeExit(
      const ulong ticket) const
     {
      if(!m_use_time_exit ||
         m_max_holding_minutes<=0)
         return false;

      if(!SelectPosition(ticket))
         return false;

      datetime open_time=
         (datetime)
         PositionGetInteger(
            POSITION_TIME);

      if(open_time<=0)
         return false;

      datetime now=
         TimeCurrent();

      long holding_seconds=
         (long)(now-open_time);

      if(holding_seconds<
         (long)m_max_holding_minutes*60)
         return false;

      long magic=
         PositionGetInteger(
            POSITION_MAGIC);

      return ClosePosition(
         ticket,
         magic);
     }

   //+----------------------------------------------------------------+
   //| Emergency close                                               |
   //+----------------------------------------------------------------+
   bool TryEmergencyClose(
      const ulong ticket) const
     {
      if(!m_emergency_close)
         return false;

      if(!SelectPosition(ticket))
         return false;

      long magic=
         PositionGetInteger(
            POSITION_MAGIC);

      return ClosePosition(
         ticket,
         magic);
     }

   //+----------------------------------------------------------------+
   //| Manage one position                                            |
   //+----------------------------------------------------------------+
   bool ManageOne(
      const ulong ticket)
     {
      if(!SelectPosition(ticket))
         return false;

      if(TryEmergencyClose(ticket))
         return true;

      // A successful time exit ends management for this position.
      if(TryTimeExit(ticket))
         return true;

      // Break-even and trailing can both be enabled, but trailing
      // is only allowed to move SL in the risk-reducing direction.
      TryBreakEven(ticket);
      TryTrailing(ticket);

      return true;
     }

public:

   CPositionManager()
     {
      m_executor=NULL;

      m_initialized=false;

      m_use_break_even=false;
      m_use_trailing=false;
      m_use_time_exit=false;

      m_break_even_trigger_r=1.0;
      m_break_even_offset_points=0.0;

      m_trailing_timeframe=PERIOD_H1;
      m_atr_period=14;
      m_trailing_atr_multiplier=2.0;

      m_max_holding_minutes=240;

      m_emergency_close=false;
     }

   //+----------------------------------------------------------------+
   //| Attach executor                                                |
   //+----------------------------------------------------------------+
   void SetExecutor(ITradeExecutor *executor)
     {
      m_executor=executor;
     }

   //+----------------------------------------------------------------+
   //| Configure break-even                                           |
   //+----------------------------------------------------------------+
   void SetBreakEven(
      const bool enabled,
      const double trigger_r,
      const double offset_points)
     {
      m_use_break_even=enabled;
      m_break_even_trigger_r=trigger_r;
      m_break_even_offset_points=offset_points;
     }

   //+----------------------------------------------------------------+
   //| Configure trailing                                             |
   //+----------------------------------------------------------------+
   void SetTrailing(
      const bool enabled,
      ENUM_TIMEFRAMES timeframe,
      const int atr_period,
      const double atr_multiplier)
     {
      m_use_trailing=enabled;
      m_trailing_timeframe=timeframe;
      m_atr_period=atr_period;
      m_trailing_atr_multiplier=atr_multiplier;
     }

   //+----------------------------------------------------------------+
   //| Configure time exit                                            |
   //+----------------------------------------------------------------+
   void SetTimeExit(
      const bool enabled,
      const int max_holding_minutes)
     {
      m_use_time_exit=enabled;
      m_max_holding_minutes=max_holding_minutes;
     }

   //+----------------------------------------------------------------+
   //| Emergency mode                                                  |
   //+----------------------------------------------------------------+
   void SetEmergencyClose(
      const bool enabled)
     {
      m_emergency_close=enabled;
     }

   //+----------------------------------------------------------------+
   //| Initialize                                                     |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(m_executor==NULL)
         return false;

      if(m_break_even_trigger_r<0.0)
         return false;

      if(m_break_even_offset_points<0.0)
         return false;

      if(m_atr_period<=0)
         return false;

      if(m_trailing_atr_multiplier<=0.0)
         return false;

      if(m_max_holding_minutes<0)
         return false;

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Update                                                         |
   //+----------------------------------------------------------------+
   virtual void Update() override
     {
      if(!m_initialized)
         return;

      ManagePositions();
     }

   //+----------------------------------------------------------------+
   //| Manage all EA positions                                        |
   //+----------------------------------------------------------------+
   virtual bool ManagePositions() override
     {
      if(!m_initialized)
         return false;

      int total=PositionsTotal();

      bool success=true;

      // Iterate backwards because positions can disappear during
      // time/emergency exits.
      for(int i=total-1; i>=0; i--)
        {
         ulong ticket=
            PositionGetTicket(i);

         if(ticket==0)
            continue;

         long magic=
            PositionGetInteger(
               POSITION_MAGIC);

         if(!IsManagedMagic(magic))
            continue;

         if(!ManageOne(ticket))
            success=false;
        }

      return success;
     }

   //+----------------------------------------------------------------+
   //| Has position for strategy                                     |
   //+----------------------------------------------------------------+
   virtual bool HasPosition(
      const string symbol,
      ENUM_STRATEGY_ID strategy) override
     {
      if(!m_initialized)
         return false;

      int total=PositionsTotal();

      for(int i=0; i<total; i++)
        {
         ulong ticket=
            PositionGetTicket(i);

         if(ticket==0)
            continue;

         string position_symbol=
            PositionGetString(
               POSITION_SYMBOL);

         if(position_symbol!=symbol)
            continue;

         long magic=
            PositionGetInteger(
               POSITION_MAGIC);

         if(StrategyFromMagic(magic)==strategy)
            return true;
        }

      return false;
     }
  };

#endif