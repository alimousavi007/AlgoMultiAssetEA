#ifndef __ALGOSYSTEM_STATISTICS_MQH__
#define __ALGOSYSTEM_STATISTICS_MQH__

struct TesterMetrics
  {
   bool valid;

   double initial_deposit;
   double net_profit;

   double gross_profit;
   double gross_loss;

   double profit_factor;
   double expected_payoff;

   double balance_dd_money;
   double balance_dd_percent;

   double equity_dd_money;
   double equity_dd_percent;

   double recovery_factor;
   double sharpe_ratio;

   double minimum_margin_level;

   int deals;
   int trades;

   int profit_trades;
   int loss_trades;

   int long_trades;
   int short_trades;

   int maximum_losing_streak;
   int maximum_winning_streak;

   string error;
  };

class CTesterStatistics
  {
private:

   void Reset(
      TesterMetrics &metrics) const
     {
      metrics.valid=false;

      metrics.initial_deposit=0.0;
      metrics.net_profit=0.0;

      metrics.gross_profit=0.0;
      metrics.gross_loss=0.0;

      metrics.profit_factor=0.0;
      metrics.expected_payoff=0.0;

      metrics.balance_dd_money=0.0;
      metrics.balance_dd_percent=0.0;

      metrics.equity_dd_money=0.0;
      metrics.equity_dd_percent=0.0;

      metrics.recovery_factor=0.0;
      metrics.sharpe_ratio=0.0;

      metrics.minimum_margin_level=0.0;

      metrics.deals=0;
      metrics.trades=0;

      metrics.profit_trades=0;
      metrics.loss_trades=0;

      metrics.long_trades=0;
      metrics.short_trades=0;

      metrics.maximum_losing_streak=0;
      metrics.maximum_winning_streak=0;

      metrics.error="";
     }

public:

   bool Collect(
      TesterMetrics &metrics) const
     {
      Reset(metrics);

      if(!MQLInfoInteger(MQL_TESTER))
        {
         metrics.error=
            "TesterStatistics called outside Strategy Tester";

         return false;
        }

      metrics.initial_deposit=
         TesterStatistics(
            STAT_INITIAL_DEPOSIT);

      metrics.net_profit=
         TesterStatistics(
            STAT_PROFIT);

      metrics.gross_profit=
         TesterStatistics(
            STAT_GROSS_PROFIT);

      metrics.gross_loss=
         TesterStatistics(
            STAT_GROSS_LOSS);

      metrics.profit_factor=
         TesterStatistics(
            STAT_PROFIT_FACTOR);

      metrics.expected_payoff=
         TesterStatistics(
            STAT_EXPECTED_PAYOFF);

      metrics.balance_dd_money=
         TesterStatistics(
            STAT_BALANCE_DD);

      metrics.balance_dd_percent=
         TesterStatistics(
            STAT_BALANCEDD_PERCENT);

      metrics.equity_dd_money=
         TesterStatistics(
            STAT_EQUITY_DD);

      metrics.equity_dd_percent=
         TesterStatistics(
            STAT_EQUITYDD_PERCENT);

      metrics.recovery_factor=
         TesterStatistics(
            STAT_RECOVERY_FACTOR);

      metrics.sharpe_ratio=
         TesterStatistics(
            STAT_SHARPE_RATIO);

      metrics.minimum_margin_level=
         TesterStatistics(
            STAT_MIN_MARGINLEVEL);

      metrics.deals=
         (int)TesterStatistics(
            STAT_DEALS);

      metrics.trades=
         (int)TesterStatistics(
            STAT_TRADES);

      metrics.profit_trades=
         (int)TesterStatistics(
            STAT_PROFIT_TRADES);

      metrics.loss_trades=
         (int)TesterStatistics(
            STAT_LOSS_TRADES);

      metrics.long_trades=
         (int)TesterStatistics(
            STAT_LONG_TRADES);

      metrics.short_trades=
         (int)TesterStatistics(
            STAT_SHORT_TRADES);

      metrics.maximum_losing_streak=
         (int)TesterStatistics(
            STAT_MAX_CONLOSS_TRADES);

      metrics.maximum_winning_streak=
         (int)TesterStatistics(
            STAT_MAX_CONPROFIT_TRADES);

      if(!MathIsValidNumber(
            metrics.net_profit))
        {
         metrics.error=
            "Invalid tester statistics";

         return false;
        }

      metrics.valid=true;

      return true;
     }

   string Summary(
      const TesterMetrics &m) const
     {
      if(!m.valid)
         return "TesterMetrics INVALID: "+m.error;

      return
         "Profit="+
         DoubleToString(
            m.net_profit,2)+
         " PF="+
         DoubleToString(
            m.profit_factor,2)+
         " DD="+
         DoubleToString(
            m.equity_dd_percent,2)+
         "% Trades="+
         IntegerToString(
            m.trades)+
         " Sharpe="+
         DoubleToString(
            m.sharpe_ratio,2)+
         " Recovery="+
         DoubleToString(
            m.recovery_factor,2);
     }
  };

#endif