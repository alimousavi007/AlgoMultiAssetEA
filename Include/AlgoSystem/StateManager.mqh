#ifndef __ALGOSYSTEM_STATEMANAGER_MQH__
#define __ALGOSYSTEM_STATEMANAGER_MQH__

#include "Interfaces.mqh"

class CAlgoStateManager : public IStateManager
  {
private:
   PortfolioState m_state;
   datetime       m_last_reconstruct;

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

   double DealNetResult(const ulong ticket) const
     {
      return HistoryDealGetDouble(ticket,DEAL_PROFIT)+
             HistoryDealGetDouble(ticket,DEAL_SWAP)+
             HistoryDealGetDouble(ticket,DEAL_COMMISSION)+
             HistoryDealGetDouble(ticket,DEAL_FEE);
     }

   double NetDealsSince(const datetime from,const datetime to) const
     {
      if(!HistorySelect(from,to))
         return 0.0;

      int total=HistoryDealsTotal();
      double net=0.0;

      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
            continue;

         long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
         if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT)
            continue;

         net+=DealNetResult(ticket);
        }

      return net;
     }

   int ConsecutiveLosses() const
     {
      datetime now=TimeCurrent();
      datetime from=now-(datetime)365*86400;

      if(!HistorySelect(from,now))
         return 0;

      int total=HistoryDealsTotal();
      int losses=0;

      for(int i=total-1;i>=0;i--)
        {
         ulong ticket=HistoryDealGetTicket(i);
         long magic=
            HistoryDealGetInteger(
               ticket,
               DEAL_MAGIC);
      
         if(!IsManagedMagic(magic))
         continue;
         if(ticket==0)
            continue;

         long entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry!=DEAL_ENTRY_OUT &&
            entry!=DEAL_ENTRY_OUT_BY &&
            entry!=DEAL_ENTRY_INOUT)
            continue;

         long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
         if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT)
            continue;

         double result=DealNetResult(ticket);

         if(result<0.0)
            losses++;
         else if(result>0.0)
            break;
        }


      return losses;
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

      double day_net=NetDealsSince(day_start,now);
      double month_net=NetDealsSince(month_start,now);

      // Reference values are reconstructed from current balance and
      // realized trading results. Floating P/L is reflected through
      // current equity. Deposit/withdrawal events are excluded.
      m_state.daily_start_equity=
         m_state.balance-day_net;

      m_state.monthly_start_equity=
         m_state.balance-month_net;

      RefreshCurrentMetrics();

      m_state.consecutive_losses=ConsecutiveLosses();
      m_last_reconstruct=now;

      return true;
     }

   void RefreshCurrentMetrics()
     {
      m_state.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_state.balance=AccountInfoDouble(ACCOUNT_BALANCE);
      m_state.total_positions=ManagedPositions();

      if(m_state.daily_start_equity>0.0)
         m_state.daily_loss_percent=
            MathMax(0.0,
                    (m_state.daily_start_equity-m_state.equity)/
                    m_state.daily_start_equity*100.0);

      if(m_state.monthly_start_equity>0.0)
         m_state.monthly_loss_percent=
            MathMax(0.0,
                    (m_state.monthly_start_equity-m_state.equity)/
                    m_state.monthly_start_equity*100.0);
     }

   void ApplyLocks(const double daily_limit,
                   const double monthly_limit,
                   const int max_consecutive_losses)
     {
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
