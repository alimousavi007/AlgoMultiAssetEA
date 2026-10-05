#ifndef __ALGOSYSTEM_PORTFOLIORISK_MQH__
#define __ALGOSYSTEM_PORTFOLIORISK_MQH__

#include "Interfaces.mqh"

class CAlgoPortfolioRisk : public IPortfolioRisk
  {
private:
   double m_max_portfolio_risk;
   int    m_max_positions_total;
   int    m_max_positions_symbol;
   int    m_max_positions_strategy;
   double m_max_precious_metals_risk;
   string m_gold_symbol;
   string m_silver_symbol;

   string m_last_rejection_code;
   string m_last_rejection_reason;

   bool IsManagedMagic(const long magic) const
     {
      return magic==MAGIC_TREND ||
             magic==MAGIC_BREAKOUT ||
             magic==MAGIC_MOMENTUM ||
             magic==MAGIC_MEAN_REVERSION ||
             magic==MAGIC_RELATIVE_VALUE;
     }

   bool IsPrecious(const string symbol) const
     {
      return symbol==m_gold_symbol || symbol==m_silver_symbol;
     }

   ENUM_STRATEGY_ID StrategyFromMagic(const long magic) const
     {
      if(magic==MAGIC_TREND) return STRATEGY_TREND_PULLBACK;
      if(magic==MAGIC_BREAKOUT) return STRATEGY_BREAKOUT;
      if(magic==MAGIC_MOMENTUM) return STRATEGY_MOMENTUM;
      if(magic==MAGIC_MEAN_REVERSION) return STRATEGY_MEAN_REVERSION;
      if(magic==MAGIC_RELATIVE_VALUE) return STRATEGY_RELATIVE_VALUE;
      return STRATEGY_NONE;
     }

   double PositionRiskPercent(const ulong ticket) const
     {
      if(!PositionSelectByTicket(ticket))
         return 0.0;

      string symbol=PositionGetString(POSITION_SYMBOL);
      long magic=PositionGetInteger(POSITION_MAGIC);

      if(!IsManagedMagic(magic))
         return 0.0;

      double sl=PositionGetDouble(POSITION_SL);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE type=
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(sl<=0.0 || volume<=0.0 || open_price<=0.0)
         return DBL_MAX;

      ENUM_ORDER_TYPE order_type=
         (type==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

      double loss=0.0;

      if(!OrderCalcProfit(
            order_type,
            symbol,
            volume,
            open_price,
            sl,
            loss))
         return DBL_MAX;

      double equity=AccountInfoDouble(ACCOUNT_EQUITY);

      if(equity<=0.0)
         return DBL_MAX;

      return MathAbs(loss)/equity*100.0;
     }

   void Reject(const string code,const string reason)
     {
      m_last_rejection_code=code;
      m_last_rejection_reason=reason;
     }

public:
   CAlgoPortfolioRisk()
     {
      m_max_portfolio_risk=3.0;
      m_max_positions_total=3;
      m_max_positions_symbol=1;
      m_max_positions_strategy=1;
      m_max_precious_metals_risk=2.0;
      m_gold_symbol="XAUUSD";
      m_silver_symbol="XAGUSD";
      m_last_rejection_code="";
      m_last_rejection_reason="";
     }

   void SetParameters(const double max_portfolio_risk,
                      const int max_positions_total,
                      const int max_positions_symbol,
                      const int max_positions_strategy,
                      const double max_precious_metals_risk,
                      const string gold_symbol,
                      const string silver_symbol)
     {
      m_max_portfolio_risk=max_portfolio_risk;
      m_max_positions_total=max_positions_total;
      m_max_positions_symbol=max_positions_symbol;
      m_max_positions_strategy=max_positions_strategy;
      m_max_precious_metals_risk=max_precious_metals_risk;
      m_gold_symbol=gold_symbol;
      m_silver_symbol=silver_symbol;
      m_last_rejection_code="";
      m_last_rejection_reason="";
     }

   virtual bool Initialize() override
     {
      if(m_max_portfolio_risk<=0.0 ||
         m_max_positions_total<=0 ||
         m_max_positions_symbol<=0 ||
         m_max_positions_strategy<=0 ||
         m_max_precious_metals_risk<=0.0)
        {
         Reject("INVALID_CONFIG","Invalid portfolio risk configuration");
         return false;
        }

      return true;
     }

   virtual bool CanOpen(const StrategySignal &signal,
                        const RiskDecision &risk) override
     {
      m_last_rejection_code="";
      m_last_rejection_reason="";

      if(!signal.valid)
        {
         Reject("INVALID_SIGNAL","Strategy signal is invalid");
         return false;
        }

      if(risk.decision!=RISK_APPROVED)
        {
         Reject("RISK_NOT_APPROVED","Risk engine did not approve the trade");
         return false;
        }

      if(PositionsTotal()>=m_max_positions_total)
        {
         Reject("MAX_POSITIONS_TOTAL","Total managed position limit reached");
         return false;
        }

      int symbol_count=0;
      int strategy_count=0;
      double current_risk=0.0;
      double precious_risk=0.0;

      for(int i=0;i<PositionsTotal();i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;

         string symbol=PositionGetString(POSITION_SYMBOL);
         long magic=PositionGetInteger(POSITION_MAGIC);

         if(!IsManagedMagic(magic))
            continue;

         if(symbol==signal.symbol)
            symbol_count++;

         if(StrategyFromMagic(magic)==signal.strategy)
            strategy_count++;

         double pr=PositionRiskPercent(ticket);

         if(pr==DBL_MAX)
           {
            Reject("INVALID_OPEN_POSITION_RISK",
                   "Cannot calculate existing managed position risk");
            return false;
           }

         current_risk+=pr;

         if(IsPrecious(symbol))
            precious_risk+=pr;
        }

      if(symbol_count>=m_max_positions_symbol)
        {
         Reject("MAX_POSITIONS_SYMBOL","Per-symbol position limit reached");
         return false;
        }

      if(strategy_count>=m_max_positions_strategy)
        {
         Reject("MAX_POSITIONS_STRATEGY","Per-strategy position limit reached");
         return false;
        }

      if(current_risk+risk.risk_percent>m_max_portfolio_risk)
        {
         Reject("MAX_PORTFOLIO_RISK","Portfolio risk limit exceeded");
         return false;
        }

      if(IsPrecious(signal.symbol) &&
         precious_risk+risk.risk_percent>m_max_precious_metals_risk)
        {
         Reject("MAX_PRECIOUS_METALS_RISK",
                "Precious-metals concentration risk limit exceeded");
         return false;
        }

      return true;
     }

   string LastRejectionCode() const
     {
      return m_last_rejection_code;
     }

   string LastRejectionReason() const
     {
      return m_last_rejection_reason;
     }

   virtual double CurrentRiskPercent() const override
     {
      double total=0.0;

      for(int i=0;i<PositionsTotal();i++)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0)
            continue;

         double risk=PositionRiskPercent(ticket);
         if(risk==DBL_MAX)
            return DBL_MAX;

         total+=risk;
        }

      return total;
     }
  };

#endif
