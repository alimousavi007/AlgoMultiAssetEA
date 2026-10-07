#ifndef __ALGOSYSTEM_STATEMANAGER_MQH__
#define __ALGOSYSTEM_STATEMANAGER_MQH__

#include "Interfaces.mqh"

class CAlgoStateManager : public IStateManager
  {
private:
   PortfolioState m_state;
   datetime       m_last_reconstruct;
   bool           m_state_valid;

   void Reset()
     {
      m_state.equity=0.0;
      m_state.balance=0.0;
      m_state.daily_start_equity=0.0;
      m_state.monthly_start_equity=0.0;
      m_state.daily_loss_percent=0.0;
      m_state.monthly_loss_percent=0.0;
      m_state.total_open_risk_percent=0.0;
      m_state.total_positions=0;
      m_state.consecutive_losses=0;
      m_state.daily_lock=false;
      m_state.monthly_lock=false;
      m_state.trading_locked=false;
      m_state_valid=false;
     }
      bool IsManagedMagic(const long magic) const
        {
         return
            magic==MAGIC_TREND ||
            magic==MAGIC_BREAKOUT ||
            magic==MAGIC_MOMENTUM ||
            magic==MAGIC_MEAN_REVERSION ||
            magic==MAGIC_RELATIVE_VALUE;
        }
   datetime DayStart(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t,dt);
      dt.hour=0;
      dt.min=0;
      dt.sec=0;
      return StructToTime(dt);
     }

   datetime MonthStart(const datetime t) const
     {
      MqlDateTime dt;
      TimeToStruct(t,dt);
      dt.day=1;
      dt.hour=0;
      dt.min=0;
      dt.sec=0;
      return StructToTime(dt);
     }

   bool DealNetResult(const ulong ticket,double &net) const
     {
      double profit=0.0;
      double swap=0.0;
      double commission=0.0;
      double fee=0.0;

      if(!HistoryDealGetDouble(ticket,DEAL_PROFIT,profit) ||
         !HistoryDealGetDouble(ticket,DEAL_SWAP,swap) ||
         !HistoryDealGetDouble(ticket,DEAL_COMMISSION,commission) ||
         !HistoryDealGetDouble(ticket,DEAL_FEE,fee))
         return false;

      net=profit+swap+commission+fee;
      return MathIsValidNumber(net);
     }

   bool NetDealsSince(const datetime from,
                      const datetime to,
                      double &net) const
     {
      net=0.0;
      if(!HistorySelect(from,to))
         return false;

      int total=HistoryDealsTotal();
      if(total<0)
         return false;

      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
            return false;

         long type=0;
         if(!HistoryDealGetInteger(ticket,DEAL_TYPE,type))
            return false;

         if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT)
            continue;

         double deal_net=0.0;
         if(!DealNetResult(ticket,deal_net))
            return false;

         net+=deal_net;
        }

      return MathIsValidNumber(net);
     }

   bool ConsecutiveLosses(int &losses) const
     {
      losses=0;
      datetime now=TimeCurrent();
      datetime from=now-(datetime)365*86400;

      if(!HistorySelect(from,now))
         return false;

      int total=HistoryDealsTotal();
      if(total<0)
         return false;

      for(int i=total-1;i>=0;i--)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
            return false;

         long magic=0;
         if(!HistoryDealGetInteger(ticket,DEAL_MAGIC,magic))
            return false;
      
         if(!IsManagedMagic(magic))
            continue;

         long entry=0;
         if(!HistoryDealGetInteger(ticket,DEAL_ENTRY,entry))
            return false;

         if(entry!=DEAL_ENTRY_OUT &&
            entry!=DEAL_ENTRY_OUT_BY &&
            entry!=DEAL_ENTRY_INOUT)
            continue;

         long type=0;
         if(!HistoryDealGetInteger(ticket,DEAL_TYPE,type))
            return false;

         if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT)
            continue;

         double result=0.0;
         if(!DealNetResult(ticket,result))
            return false;

         if(result<0.0)
            losses++;
         else if(result>0.0)
            break;
        }


      return true;
     }

public:
   CAlgoStateManager()
     {
      Reset();
      m_last_reconstruct=0;
     }

   virtual bool Initialize() override
     {
      return Reconstruct();
     }

   virtual bool Reconstruct() override
     {
      Reset();

      datetime now=TimeCurrent();
      datetime day_start=DayStart(now);
      datetime month_start=MonthStart(now);

      m_state.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_state.balance=AccountInfoDouble(ACCOUNT_BALANCE);

      if(!MathIsValidNumber(m_state.equity) ||
         !MathIsValidNumber(m_state.balance) ||
         m_state.equity<=0.0 ||
         m_state.balance<=0.0)
         return false;

      double day_net=0.0;
      if(!NetDealsSince(day_start,now,day_net))
         return false;

      double month_net=0.0;
      if(!NetDealsSince(month_start,now,month_net))
         return false;

      int consecutive_losses=0;
      if(!ConsecutiveLosses(consecutive_losses))
         return false;

      // Reference values are reconstructed from current balance and
      // realized trading results. Floating P/L is reflected through
      // current equity. Deposit/withdrawal events are excluded.
      m_state.daily_start_equity=
         m_state.balance-day_net;

      m_state.monthly_start_equity=
         m_state.balance-month_net;

      if(!MathIsValidNumber(m_state.daily_start_equity) ||
         !MathIsValidNumber(m_state.monthly_start_equity) ||
         m_state.daily_start_equity<=0.0 ||
         m_state.monthly_start_equity<=0.0)
         return false;

      m_state.consecutive_losses=consecutive_losses;

      if(!RefreshCurrentMetrics())
         return false;

      m_last_reconstruct=now;

      return true;
     }

   bool RefreshCurrentMetrics()
     {
      m_state.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_state.balance=AccountInfoDouble(ACCOUNT_BALANCE);

      if(!MathIsValidNumber(m_state.equity) ||
         !MathIsValidNumber(m_state.balance) ||
         m_state.equity<=0.0 ||
         m_state.balance<=0.0 ||
         m_state.daily_start_equity<=0.0 ||
         m_state.monthly_start_equity<=0.0)
        {
         m_state_valid=false;
         m_state.trading_locked=true;
         return false;
        }

      m_state.total_positions=ManagedPositions();

      m_state.daily_loss_percent=
         MathMax(0.0,
                 (m_state.daily_start_equity-m_state.equity)/
                 m_state.daily_start_equity*100.0);

      m_state.monthly_loss_percent=
         MathMax(0.0,
                 (m_state.monthly_start_equity-m_state.equity)/
                 m_state.monthly_start_equity*100.0);

      if(!MathIsValidNumber(m_state.daily_loss_percent) ||
         !MathIsValidNumber(m_state.monthly_loss_percent))
        {
         m_state_valid=false;
         m_state.trading_locked=true;
         return false;
        }

      m_state_valid=true;
      return true;
     }

   void ApplyLocks(const double daily_limit,
                   const double monthly_limit,
                   const int max_consecutive_losses)
     {
      if(!m_state_valid)
        {
         m_state.trading_locked=true;
         return;
        }

      m_state.daily_lock=(daily_limit>0.0 &&
                          m_state.daily_loss_percent>=daily_limit);

      m_state.monthly_lock=(monthly_limit>0.0 &&
                            m_state.monthly_loss_percent>=monthly_limit);

      bool consecutive_lock=(max_consecutive_losses>0 &&
                             m_state.consecutive_losses>=max_consecutive_losses);

      m_state.trading_locked=
         m_state.daily_lock ||
         m_state.monthly_lock ||
         consecutive_lock;
     }

   virtual bool GetPortfolioState(PortfolioState &state) override
     {
      if(!m_state_valid)
         return false;

      state=m_state;
      return true;
     }

   virtual bool UpdateAfterTrade(const ExecutionResult &result) override
     {
      if(!result.success)
         return true;

      return Reconstruct();
     }

   datetime LastReconstruct() const
     {
      return m_last_reconstruct;
     }
     int ManagedPositions() const
  {
   int count=0;

   for(int i=0;
       i<PositionsTotal();
       i++)
     {
      ulong ticket=
         PositionGetTicket(i);

      if(ticket==0)
         continue;

      long magic=
         PositionGetInteger(
            POSITION_MAGIC);

      if(IsManagedMagic(magic))
         count++;
     }

   return count;
  }
  };

#endif
