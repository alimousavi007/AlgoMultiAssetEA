#ifndef __ALGOSYSTEM_RISKENGINE_MQH__
#define __ALGOSYSTEM_RISKENGINE_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Risk Engine                                                      |
//|                                                                  |
//| Responsibility:                                                 |
//| - account risk calculation                                       |
//| - stop / target validation                                       |
//| - risk-per-lot calculation                                       |
//| - broker volume normalization                                   |
//| - margin pre-check                                               |
//| - external risk lock                                            |
//|                                                                  |
//| Portfolio-level risk and historical state reconstruction are     |
//| intentionally handled by later modules.                         |
//+------------------------------------------------------------------+
class CRiskEngine : public IRiskEngine
  {
private:

   double m_risk_percent;
   double m_min_rr;

   double m_margin_safety_fraction;

   bool   m_external_lock;
   string m_external_lock_reason;

   bool   m_initialized;
   
   ENUM_REJECTION_REASON m_external_lock_reason_code;

   //+----------------------------------------------------------------+
   //| Reset decision                                                 |
   //+----------------------------------------------------------------+
   void ResetDecision(
      RiskDecision &decision) const
     {
      decision.decision=RISK_UNDEFINED;

      decision.rejection_reason=REJECT_NONE;

      decision.symbol="";

      decision.risk_percent=0.0;
      decision.risk_amount=0.0;

      decision.stop_distance=0.0;
      decision.calculated_volume=0.0;

      decision.portfolio_risk_after=0.0;

      decision.reason="";
     }

   //+----------------------------------------------------------------+
   //| Reject                                                         |
   //+----------------------------------------------------------------+
   bool Reject(
      RiskDecision &decision,
      ENUM_REJECTION_REASON reason,
      const string message) const
     {
      decision.decision=RISK_REJECTED;
      decision.rejection_reason=reason;
      decision.reason=message;

      return false;
     }

   //+----------------------------------------------------------------+
   //| Determine order type                                           |
   //+----------------------------------------------------------------+
   bool GetOrderType(
      const ENUM_SIGNAL_DIRECTION direction,
      ENUM_ORDER_TYPE &order_type) const
     {
      if(direction==SIGNAL_LONG)
        {
         order_type=ORDER_TYPE_BUY;
         return true;
        }

      if(direction==SIGNAL_SHORT)
        {
         order_type=ORDER_TYPE_SELL;
         return true;
        }

      return false;
     }

   //+----------------------------------------------------------------+
   //| Trade mode validation                                          |
   //+----------------------------------------------------------------+
   bool IsDirectionAllowed(
      const string symbol,
      const ENUM_SIGNAL_DIRECTION direction) const
     {
      long mode=0;

      if(!SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_MODE,
            mode))
         return false;

      ENUM_SYMBOL_TRADE_MODE trade_mode=
         (ENUM_SYMBOL_TRADE_MODE)mode;

      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
         return false;

      if(direction==SIGNAL_LONG)
        {
         if(trade_mode==SYMBOL_TRADE_MODE_SHORTONLY ||
            trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
            return false;
        }

      if(direction==SIGNAL_SHORT)
        {
         if(trade_mode==SYMBOL_TRADE_MODE_LONGONLY ||
            trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
            return false;
        }

      return true;
     }

   //+----------------------------------------------------------------+
   //| Normalize volume without exceeding risk                       |
   //+----------------------------------------------------------------+
   double NormalizeRiskVolume(
      const double raw_volume,
      const double minimum,
      const double maximum,
      const double step) const
     {
      if(raw_volume<=0.0)
         return 0.0;

      if(step<=0.0 ||
         minimum<=0.0 ||
         maximum<=0.0)
         return 0.0;

      double volume=
         MathFloor(
            raw_volume/step)*step;

      volume=
         NormalizeDouble(
            volume,
            8);

      if(volume<minimum)
         return 0.0;

      if(volume>maximum)
         volume=maximum;

      return volume;
     }

public:

   //+----------------------------------------------------------------+
   //| Constructor                                                    |
   //+----------------------------------------------------------------+
   CRiskEngine()
     {
      m_risk_percent=1.0;
      m_min_rr=1.50;

      m_margin_safety_fraction=0.80;

      m_external_lock=false;
      m_external_lock_reason="";

      m_initialized=false;
      
      m_external_lock_reason_code=REJECT_NONE;
     }

   //+----------------------------------------------------------------+
   //| Configure                                                      |
   //+----------------------------------------------------------------+
   void SetParameters(
      const double risk_percent,
      const double min_rr,
      const double margin_safety_fraction)
     {
      m_risk_percent=risk_percent;
      m_min_rr=min_rr;

      m_margin_safety_fraction=
         margin_safety_fraction;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| External risk lock                                             |
   //+----------------------------------------------------------------+
   void SetExternalLock(
      const bool locked,
      const ENUM_REJECTION_REASON reason_code,
      const string reason)
     {
      m_external_lock=locked;
      m_external_lock_reason_code=reason_code;
      m_external_lock_reason=reason;
     }

   //+----------------------------------------------------------------+
   //| IDiscount? initialize                                          |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(m_risk_percent<=0.0)
         return false;

      if(m_min_rr<=0.0)
         return false;

      if(m_margin_safety_fraction<=0.0 ||
         m_margin_safety_fraction>1.0)
         return false;

      m_initialized=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Evaluate risk                                                  |
   //+----------------------------------------------------------------+
   virtual bool Evaluate(
      const StrategySignal &signal,
      RiskDecision &decision) override
     {
      ResetDecision(decision);

      decision.symbol=signal.symbol;
      decision.risk_percent=m_risk_percent;

      return Reject(
         decision,
         m_external_lock_reason_code,
         m_external_lock_reason);

      if(!signal.valid)
         return Reject(
            decision,
            REJECT_INVALID_SIGNAL,
            "Invalid strategy signal");

      if(m_external_lock)
         return Reject(
            decision,
            REJECT_DAILY_LOSS,
            m_external_lock_reason);

      if(!IsDirectionAllowed(
            signal.symbol,
            signal.direction))
         return Reject(
            decision,
            REJECT_EXECUTION,
            "Symbol direction is not allowed");

      MqlTick tick;

      ResetLastError();

      if(!SymbolInfoTick(
            signal.symbol,
            tick))
         return Reject(
            decision,
            REJECT_EXECUTION,
            "SymbolInfoTick failed");

      double point=
         SymbolInfoDouble(
            signal.symbol,
            SYMBOL_POINT);

      if(point<=0.0)
         return Reject(
            decision,
            REJECT_EXECUTION,
            "Invalid symbol point");

      long stops_level=0;

      if(!SymbolInfoInteger(
            signal.symbol,
            SYMBOL_TRADE_STOPS_LEVEL,
            stops_level))
         return Reject(
            decision,
            REJECT_EXECUTION,
            "Cannot read stops level");

      double minimum_stop_distance=
         (double)stops_level*point;

      ENUM_ORDER_TYPE order_type;

      if(!GetOrderType(
            signal.direction,
            order_type))
         return Reject(
            decision,
            REJECT_INVALID_SIGNAL,
            "Invalid signal direction");

      double entry_price;

      if(signal.direction==SIGNAL_LONG)
         entry_price=tick.ask;
      else
         entry_price=tick.bid;

      if(entry_price<=0.0)
         return Reject(
            decision,
            REJECT_EXECUTION,
            "Invalid current market price");

      //--- stop/target side validation
      if(signal.direction==SIGNAL_LONG)
        {
         if(signal.stop<=0.0 ||
            signal.stop>=entry_price)
            return Reject(
               decision,
               REJECT_INVALID_STOP,
               "Long stop is invalid");

         if(signal.target<=entry_price)
            return Reject(
               decision,
               REJECT_INVALID_TARGET,
               "Long target is invalid");

         if(minimum_stop_distance>0.0)
           {
            if(entry_price-signal.stop<
               minimum_stop_distance)
               return Reject(
                  decision,
                  REJECT_INVALID_STOP,
                  "Long stop violates broker stop distance");

            if(signal.target-entry_price<
               minimum_stop_distance)
               return Reject(
                  decision,
                  REJECT_INVALID_TARGET,
                  "Long target violates broker stop distance");
           }
        }
      else
        {
         if(signal.stop<=entry_price)
            return Reject(
               decision,
               REJECT_INVALID_STOP,
               "Short stop is invalid");

         if(signal.target<=0.0 ||
            signal.target>=entry_price)
            return Reject(
               decision,
               REJECT_INVALID_TARGET,
               "Short target is invalid");

         if(minimum_stop_distance>0.0)
           {
            if(signal.stop-entry_price<
               minimum_stop_distance)
               return Reject(
                  decision,
                  REJECT_INVALID_STOP,
                  "Short stop violates broker stop distance");

            if(entry_price-signal.target<
               minimum_stop_distance)
               return Reject(
                  decision,
                  REJECT_INVALID_TARGET,
                  "Short target violates broker stop distance");
           }
        }

      //--- RR calculated from current market price
      double reward=0.0;
      double risk_distance=0.0;

      if(signal.direction==SIGNAL_LONG)
        {
         reward=
            signal.target-entry_price;

         risk_distance=
            entry_price-signal.stop;
        }
      else
        {
         reward=
            entry_price-signal.target;

         risk_distance=
            signal.stop-entry_price;
        }

      if(risk_distance<=0.0)
         return Reject(
            decision,
            REJECT_INVALID_STOP,
            "Zero or negative risk distance");

      double rr=
         CAlgoUtils::SafeDivide(
            reward,
            risk_distance,
            0.0);

      if(rr<m_min_rr)
         return Reject(
            decision,
            REJECT_LOW_RR,
            "Risk/Reward below minimum");

      //--- account equity
      double equity=
         AccountInfoDouble(
            ACCOUNT_EQUITY);

      if(equity<=0.0)
         return Reject(
            decision,
            REJECT_MARGIN,
            "Invalid account equity");

      decision.risk_amount=
         equity*m_risk_percent/100.0;

      //--- calculate account-currency loss for 1 lot
      double one_lot_result=0.0;

      ResetLastError();

      if(!OrderCalcProfit(
            order_type,
            signal.symbol,
            1.0,
            entry_price,
            signal.stop,
            one_lot_result))
         return Reject(
            decision,
            REJECT_EXECUTION,
            "OrderCalcProfit failed");

      double loss_per_lot=
         MathAbs(one_lot_result);

      if(loss_per_lot<=0.0)
         return Reject(
            decision,
            REJECT_EXECUTION,
            "Invalid loss per lot");

      //--- risk-based raw volume
      double raw_volume=
         decision.risk_amount/
         loss_per_lot;

      double volume_min=
         SymbolInfoDouble(
            signal.symbol,
            SYMBOL_VOLUME_MIN);

      double volume_max=
         SymbolInfoDouble(
            signal.symbol,
            SYMBOL_VOLUME_MAX);

      double volume_step=
         SymbolInfoDouble(
            signal.symbol,
            SYMBOL_VOLUME_STEP);

      if(volume_min<=0.0 ||
         volume_max<=0.0 ||
         volume_step<=0.0)
         return Reject(
            decision,
            REJECT_INVALID_VOLUME,
            "Invalid broker volume specification");

      double volume=
         NormalizeRiskVolume(
            raw_volume,
            volume_min,
            volume_max,
            volume_step);

      // Never round upward to minimum volume if that would
      // exceed the calculated risk budget.
      if(volume<=0.0)
         return Reject(
            decision,
            REJECT_INVALID_VOLUME,
            "Risk budget is below broker minimum volume");

      //--- margin check
      double margin_required=0.0;

      ResetLastError();

      if(!OrderCalcMargin(
            order_type,
            signal.symbol,
            volume,
            entry_price,
            margin_required))
         return Reject(
            decision,
            REJECT_MARGIN,
            "OrderCalcMargin failed");

      double free_margin=
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE);

      if(free_margin<=0.0)
         return Reject(
            decision,
            REJECT_MARGIN,
            "No free margin");

      if(margin_required>
         free_margin*m_margin_safety_fraction)
         return Reject(
            decision,
            REJECT_MARGIN,
            "Margin requirement exceeds safety limit");

      decision.stop_distance=
         risk_distance;

      decision.calculated_volume=
         volume;

      // PortfolioRisk will refine this value later.
      decision.portfolio_risk_after=
         m_risk_percent;

      decision.decision=
         RISK_APPROVED;

      decision.rejection_reason=REJECT_NONE;

      decision.reason=
         "Risk approved";

      return true;
     }

   bool IsInitialized() const
     {
      return m_initialized;
     }

   double RiskPercent() const
     {
      return m_risk_percent;
     }
  };

#endif