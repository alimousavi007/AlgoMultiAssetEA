#ifndef __ALGOSYSTEM_TRADEEXECUTOR_MQH__
#define __ALGOSYSTEM_TRADEEXECUTOR_MQH__

#include <Trade/Trade.mqh>
#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Trade Executor                                                   |
//|                                                                  |
//| The ONLY module in V1 allowed to execute trading operations.     |
//+------------------------------------------------------------------+
class CTradeExecutor : public ITradeExecutor
  {
private:

   CTrade m_trade;

   ulong m_deviation_points;

   bool m_initialized;
   string m_last_validation_reason;

   bool RejectOpenValidation(string &reason,
                             const string detail) const
     {
      reason=detail;
      return false;
     }

   //+----------------------------------------------------------------+
   //| Check account trade permission                                 |
   //+----------------------------------------------------------------+
   bool IsAccountTradingAllowed() const
     {
      if(!AccountInfoInteger(
            ACCOUNT_TRADE_ALLOWED))
         return false;

      if(!AccountInfoInteger(
            ACCOUNT_TRADE_EXPERT))
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Symbol existence/selection                                    |
   //+----------------------------------------------------------------+
   bool IsSymbolReady(
      const string symbol) const
     {
      if(StringLen(symbol)==0)
         return false;

      bool custom=false;

      if(!SymbolExist(
            symbol,
            custom))
         return false;

      if(!SymbolSelect(
            symbol,
            true))
         return false;

      if(!SymbolIsSynchronized(symbol))
         return false;

      return true;
     }
   bool IsTickAligned(const string symbol,
                   const double price) const
     {
      if(price<=0.0)
         return false;
   
      double tick_size=
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE);
   
      if(tick_size<=0.0)
         return false;
   
      double steps=price/tick_size;
      double nearest=MathRound(steps);
   
      return MathAbs(
                steps-nearest)<=1e-7;
     }

   //+----------------------------------------------------------------+
   //| Get trade mode                                                 |
   //+----------------------------------------------------------------+
   bool GetTradeMode(
      const string symbol,
      ENUM_SYMBOL_TRADE_MODE &trade_mode) const
     {
      long mode=0;

      if(!SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_MODE,
            mode))
         return false;

      trade_mode=
         (ENUM_SYMBOL_TRADE_MODE)mode;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Direction permitted                                             |
   //+----------------------------------------------------------------+
   bool IsOpenDirectionAllowed(
      const string symbol,
      const ENUM_ORDER_TYPE order_type) const
     {
      ENUM_SYMBOL_TRADE_MODE trade_mode;

      if(!GetTradeMode(
            symbol,
            trade_mode))
         return false;

      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED ||
         trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
         return false;

      if(order_type==ORDER_TYPE_BUY)
        {
         if(trade_mode==SYMBOL_TRADE_MODE_SHORTONLY)
            return false;
        }

      if(order_type==ORDER_TYPE_SELL)
        {
         if(trade_mode==SYMBOL_TRADE_MODE_LONGONLY)
            return false;
        }

      return true;
     }

   //+----------------------------------------------------------------+
   //| Stop/Target validation                                         |
   //+----------------------------------------------------------------+
   bool ValidateOpenLevels(
      const string symbol,
      const ENUM_ORDER_TYPE order_type,
      const double sl,
      const double tp,
      const MqlTick &tick,
      string &reason) const
     {
      reason="";
      if(sl<=0.0 ||
         tp<=0.0)
         return RejectOpenValidation(reason,"Stop or target is not positive");
         
      if(!IsTickAligned(symbol,sl) ||
         !IsTickAligned(symbol,tp))
         return RejectOpenValidation(reason,"Stop or target is not aligned to symbol tick size");

      double point=
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT);

      if(point<=0.0)
         return RejectOpenValidation(reason,"Symbol point size is invalid");

      long stops_level=0;
      long freeze_level=0;

      if(!SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_STOPS_LEVEL,
            stops_level))
         return RejectOpenValidation(reason,"Unable to read symbol stops level");

      if(!SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_FREEZE_LEVEL,
            freeze_level))
         return RejectOpenValidation(reason,"Unable to read symbol freeze level");

      double minimum_distance=
         (double)MathMax(
            stops_level,
            freeze_level)*point;

      if(order_type==ORDER_TYPE_BUY)
        {
         if(sl>=tick.bid)
            return RejectOpenValidation(reason,"Long stop is not below current bid");

         if(tp<=tick.bid)
            return RejectOpenValidation(reason,"Long target is not above current bid");

         if(minimum_distance>0.0)
           {
            if(tick.bid-sl<
               minimum_distance)
               return RejectOpenValidation(reason,"Long stop violates symbol stop/freeze distance");

            if(tp-tick.bid<
               minimum_distance)
               return RejectOpenValidation(reason,"Long target violates symbol stop/freeze distance");
           }
        }
      else
        {
         if(sl<=tick.ask)
            return RejectOpenValidation(reason,"Short stop is not above current ask");

         if(tp>=tick.ask)
            return RejectOpenValidation(reason,"Short target is not below current ask");

         if(minimum_distance>0.0)
           {
            if(sl-tick.ask<
               minimum_distance)
               return RejectOpenValidation(reason,"Short stop violates symbol stop/freeze distance");

            if(tick.ask-tp<
               minimum_distance)
               return RejectOpenValidation(reason,"Short target violates symbol stop/freeze distance");
           }
        }

      return true;
     }

   //+----------------------------------------------------------------+
   //| Validate request                                               |
   //+----------------------------------------------------------------+
   bool ValidateOpen(
      const ExecutionRequest &request,
      string &reason) const
     {
      reason="";
      if(!IsAccountTradingAllowed())
         return RejectOpenValidation(reason,"Account or expert trading permission is disabled");

      if(!IsSymbolReady(request.symbol))
         return RejectOpenValidation(reason,"Symbol is missing, unselected or unsynchronized");

      if(request.volume<=0.0)
         return RejectOpenValidation(reason,"Requested volume is not positive");

      ENUM_ORDER_TYPE order_type;

      if(request.intent==ORDER_INTENT_OPEN_LONG)
         order_type=ORDER_TYPE_BUY;
      else if(request.intent==ORDER_INTENT_OPEN_SHORT)
         order_type=ORDER_TYPE_SELL;
      else
         return RejectOpenValidation(reason,"Unsupported order intent");

      if(!IsOpenDirectionAllowed(
            request.symbol,
            order_type))
         return RejectOpenValidation(reason,"Requested direction is disabled for this symbol");

      MqlTick tick;

      if(!SymbolInfoTick(
            request.symbol,
            tick))
         return RejectOpenValidation(reason,"Unable to read current symbol tick");

      if(tick.bid<=0.0 ||
         tick.ask<=0.0)
         return RejectOpenValidation(reason,"Current bid or ask is invalid");

      if(request.stop_loss<=0.0 ||
         request.take_profit<=0.0)
         return RejectOpenValidation(reason,"Requested stop or target is not positive");

      if(!ValidateOpenLevels(
            request.symbol,
            order_type,
            request.stop_loss,
            request.take_profit,
            tick,
            reason))
         return false;

      //--- Broker volume constraints
      double volume_min=
         SymbolInfoDouble(
            request.symbol,
            SYMBOL_VOLUME_MIN);

      double volume_max=
         SymbolInfoDouble(
            request.symbol,
            SYMBOL_VOLUME_MAX);

      double volume_step=
         SymbolInfoDouble(
            request.symbol,
            SYMBOL_VOLUME_STEP);

      if(volume_min<=0.0 ||
         volume_max<=0.0 ||
         volume_step<=0.0)
         return RejectOpenValidation(reason,"Symbol volume constraints are invalid");

      if(request.volume<volume_min ||
         request.volume>volume_max)
         return RejectOpenValidation(reason,"Requested volume is outside symbol limits");

      double steps=
         request.volume/volume_step;

      double nearest=
         MathRound(steps);

      if(MathAbs(steps-nearest)>0.000001)
         return RejectOpenValidation(reason,"Requested volume is not aligned to volume step");

      //--- Margin check
      double execution_price;

      if(order_type==ORDER_TYPE_BUY)
         execution_price=tick.ask;
      else
         execution_price=tick.bid;

      double margin=0.0;

      if(!OrderCalcMargin(
            order_type,
            request.symbol,
            request.volume,
            execution_price,
            margin))
         return RejectOpenValidation(reason,"OrderCalcMargin failed");

      double free_margin=
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE);

      if(free_margin<=0.0)
         return RejectOpenValidation(reason,"Free margin is not positive");

      if(margin>free_margin)
         return RejectOpenValidation(reason,"Required margin exceeds free margin");

      return true;
     }

   //+----------------------------------------------------------------+
   //| Validate close                                                 |
   //+----------------------------------------------------------------+
   bool ValidateClose(
      const ExecutionRequest &request) const
     {
      if(!IsAccountTradingAllowed())
         return false;

      if(request.position_ticket==0)
         return false;

      if(!PositionSelectByTicket(
            request.position_ticket))
         return false;
      
      long position_magic=
         PositionGetInteger(
            POSITION_MAGIC);
      
      if(request.magic<=0 ||
         position_magic!=request.magic)
         return false;
      
      return true;
     }

   //+----------------------------------------------------------------+
   //| Validate modification                                         |
   //+----------------------------------------------------------------+
   bool ValidateModify(
      const ExecutionRequest &request) const
     {
      if(!IsAccountTradingAllowed())
         return false;

      if(request.position_ticket==0)
         return false;

      if(!PositionSelectByTicket(
            request.position_ticket))
         return false;
      long position_magic=
         PositionGetInteger(
            POSITION_MAGIC);
      
      if(request.magic<=0 ||
         position_magic!=request.magic)
         return false;

      string symbol=
         PositionGetString(
            POSITION_SYMBOL);

      if(!IsSymbolReady(symbol))
         return false;

      MqlTick tick;

      if(!SymbolInfoTick(
            symbol,
            tick))
         return false;

      double sl=request.stop_loss;
      double tp=request.take_profit;

      if(sl<=0.0 &&
         tp<=0.0)
         return false;
         
      if(sl>0.0 &&
         !IsTickAligned(symbol,sl))
         return false;

      if(tp>0.0 &&
         !IsTickAligned(symbol,tp))
         return false;

      ENUM_POSITION_TYPE position_type=
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE);

      double point=
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT);

      if(point<=0.0)
         return false;

      long stops_level=0;

      if(!SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_STOPS_LEVEL,
            stops_level))
         return false;

      double minimum_distance=
         (double)stops_level*point;

      if(position_type==POSITION_TYPE_BUY)
        {
         if(sl>0.0 &&
            sl>=tick.bid)
            return false;

         if(tp>0.0 &&
            tp<=tick.bid)
            return false;

         if(sl>0.0 &&
            minimum_distance>0.0 &&
            tick.bid-sl<minimum_distance)
            return false;

         if(tp>0.0 &&
            minimum_distance>0.0 &&
            tp-tick.bid<minimum_distance)
            return false;
        }
      else
        {
         if(sl>0.0 &&
            sl<=tick.ask)
            return false;

         if(tp>0.0 &&
            tp>=tick.ask)
            return false;

         if(sl>0.0 &&
            minimum_distance>0.0 &&
            sl-tick.ask<minimum_distance)
            return false;

         if(tp>0.0 &&
            minimum_distance>0.0 &&
            tick.ask-tp<minimum_distance)
            return false;
        }

      return true;
     }

   //+----------------------------------------------------------------+
   //| Retcode is execution success                                   |
   //+----------------------------------------------------------------+
   bool IsSuccessfulRetcode(
      const uint retcode) const
     {
      if(retcode==TRADE_RETCODE_DONE)
         return true;

      if(retcode==TRADE_RETCODE_DONE_PARTIAL)
         return true;

      if(retcode==TRADE_RETCODE_PLACED)
         return true;

      if(retcode==TRADE_RETCODE_NO_CHANGES)
         return true;

      return false;
     }

   //+----------------------------------------------------------------+
   //| Copy CTrade result                                             |
   //+----------------------------------------------------------------+
   void FillExecutionResult(
      ExecutionResult &result) const
     {
      result.retcode=
         m_trade.ResultRetcode();

      result.order_ticket=
         m_trade.ResultOrder();

      result.deal_ticket=
         m_trade.ResultDeal();

      result.executed_price=
         m_trade.ResultPrice();

      result.executed_volume=
         m_trade.ResultVolume();

      result.message=
         m_trade.ResultRetcodeDescription();

      result.success=
         IsSuccessfulRetcode(
            result.retcode);
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CTradeExecutor()
     {
      m_deviation_points=20;
      m_initialized=false;
      m_last_validation_reason="";
     }

   //+----------------------------------------------------------------+
   //| Configuration                                                  |
   //+----------------------------------------------------------------+
   void SetDeviationPoints(
      const ulong deviation_points)
     {
      m_deviation_points=
         deviation_points;
     }

   //+----------------------------------------------------------------+
   //| Initialize                                                     |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      m_trade.SetAsyncMode(false);

      m_trade.SetDeviationInPoints(
         m_deviation_points);

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Validate generic request                                       |
   //+----------------------------------------------------------------+
   virtual bool Validate(
      const ExecutionRequest &request) override
     {
      m_last_validation_reason="";
      if(!m_initialized)
        {
         m_last_validation_reason="Trade executor is not initialized";
         return false;
        }

      if(request.intent==ORDER_INTENT_OPEN_LONG ||
         request.intent==ORDER_INTENT_OPEN_SHORT)
         return ValidateOpen(
            request,
            m_last_validation_reason);

      if(request.intent==ORDER_INTENT_CLOSE)
         return ValidateClose(request);

      if(request.intent==ORDER_INTENT_MODIFY_SL ||
         request.intent==ORDER_INTENT_MODIFY_TP)
         return ValidateModify(request);

      return false;
     }

   //+----------------------------------------------------------------+
   //| Execute                                                        |
   //+----------------------------------------------------------------+
   virtual bool Execute(
      const ExecutionRequest &request,
      ExecutionResult &result) override
     {
      result.success=false;

      result.retcode=0;

      result.order_ticket=0;
      result.deal_ticket=0;
      result.position_ticket=0;

      result.executed_price=0.0;
      result.executed_volume=0.0;

      result.message="";

      if(!Validate(request))
        {
         result.message="Execution validation failed";
         if(m_last_validation_reason!="")
            result.message+=": "+m_last_validation_reason;

         return false;
        }

      //--- open long/short
      if(request.intent==ORDER_INTENT_OPEN_LONG ||
         request.intent==ORDER_INTENT_OPEN_SHORT)
        {
         ENUM_ORDER_TYPE order_type;

         if(request.intent==ORDER_INTENT_OPEN_LONG)
            order_type=ORDER_TYPE_BUY;
         else
            order_type=ORDER_TYPE_SELL;

         m_trade.SetExpertMagicNumber(
            (ulong)request.magic);

         m_trade.SetDeviationInPoints(
            m_deviation_points);

         m_trade.SetTypeFillingBySymbol(
            request.symbol);

         MqlTick tick;

         if(!SymbolInfoTick(
               request.symbol,
               tick))
           {
            result.message=
               "SymbolInfoTick failed";

            return false;
           }

         double price;

         if(order_type==ORDER_TYPE_BUY)
            price=tick.ask;
         else
            price=tick.bid;

         ResetLastError();

         bool request_result=
            m_trade.PositionOpen(
               request.symbol,
               order_type,
               request.volume,
               price,
               request.stop_loss,
               request.take_profit,
               request.comment);

         FillExecutionResult(result);

         if(!request_result &&
            result.retcode==0)
           {
            result.message=
               "PositionOpen failed before server execution";

            return false;
           }

         return result.success;
        }

      //--- close
      if(request.intent==ORDER_INTENT_CLOSE)
        {
         ResetLastError();

         bool request_result=
            m_trade.PositionClose(
               request.position_ticket,
               m_deviation_points);

         FillExecutionResult(result);

         if(!request_result &&
            result.retcode==0)
           {
            result.message=
               "PositionClose failed before server execution";

            return false;
           }

         result.position_ticket=
            request.position_ticket;

         return result.success;
        }

      //--- modify
      if(request.intent==ORDER_INTENT_MODIFY_SL ||
         request.intent==ORDER_INTENT_MODIFY_TP)
        {
         double sl=0.0;
         double tp=0.0;

         if(!PositionSelectByTicket(
               request.position_ticket))
           {
            result.message=
               "PositionSelectByTicket failed";

            return false;
           }

         sl=
            PositionGetDouble(
               POSITION_SL);

         tp=
            PositionGetDouble(
               POSITION_TP);

         if(request.intent==ORDER_INTENT_MODIFY_SL)
            sl=request.stop_loss;

         if(request.intent==ORDER_INTENT_MODIFY_TP)
            tp=request.take_profit;

         ResetLastError();

         bool request_result=
            m_trade.PositionModify(
               request.position_ticket,
               sl,
               tp);

         FillExecutionResult(result);

         result.position_ticket=
            request.position_ticket;

         if(!request_result &&
            result.retcode==0)
           {
            result.message=
               "PositionModify failed before server execution";

            return false;
           }

         return result.success;
        }

      result.message=
         "Unsupported execution intent";

      return false;
     }
  };

#endif