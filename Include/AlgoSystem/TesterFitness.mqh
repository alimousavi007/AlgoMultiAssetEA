#ifndef __ALGOSYSTEM_TESTERFITNESS_MQH__
#define __ALGOSYSTEM_TESTERFITNESS_MQH__

#include "Statistics.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Custom Tester Fitness                                           |
//|                                                                  |
//| Priority:                                                        |
//| Profitability                                                     |
//| × Risk Control                                                    |
//| × Consistency                                                    |
//| × Trade Sufficiency                                               |
//|                                                                  |
//| Hard rejection is applied before scoring.                        |
//+------------------------------------------------------------------+
class CTesterFitness
  {
private:

   int    m_minimum_trades;
   double m_maximum_allowed_dd_percent;
   double m_minimum_profit_factor;

   double m_dd_scale;
   double m_max_expected_pf;
   double m_max_expected_sharpe;
   double m_max_expected_recovery;

   //+----------------------------------------------------------------+
   //| Clamp score                                                    |
   //+----------------------------------------------------------------+
   double Normalize01(
      const double value,
      const double minimum,
      const double maximum) const
     {
      if(maximum<=minimum)
         return 0.0;

      double result=
         (value-minimum)/
         (maximum-minimum);

      return CAlgoUtils::Clamp(
         result,
         0.0,
         1.0);
     }

   //+----------------------------------------------------------------+
   //| Hard rejection                                                 |
   //+----------------------------------------------------------------+
   bool PassHardRules(
      const TesterMetrics &m) const
     {
      if(!m.valid)
         return false;

      if(m.initial_deposit<=0.0)
         return false;

      if(m.net_profit<=0.0)
         return false;

      if(m.trades<m_minimum_trades)
         return false;

      if(m.equity_dd_percent>
         m_maximum_allowed_dd_percent)
         return false;

      if(m.profit_factor<
         m_minimum_profit_factor)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   //| Calculate fitness                                              |
   //+----------------------------------------------------------------+
   double Score(
      const TesterMetrics &m) const
     {
      // ------------------------------------------------------------
      // Profit component
      // ------------------------------------------------------------
      double roi=
         m.net_profit/
         m.initial_deposit;

      if(roi<=0.0)
         return 0.0;

      // Cap extreme ROI influence. We do not want profit alone
      // to dominate all risk controls.
      double profit_score=
         Normalize01(
            roi,
            0.0,
            1.0);

      // ------------------------------------------------------------
      // Risk-control component
      // ------------------------------------------------------------
      double dd_penalty=
         1.0/
         (1.0+
          m.equity_dd_percent/
          m_dd_scale);

      dd_penalty=
         CAlgoUtils::Clamp(
            dd_penalty,
            0.0,
            1.0);

      // Penalize long consecutive-loss streaks.
      double streak_penalty=
         1.0/
         (1.0+
          (double)m.maximum_losing_streak*
          0.10);

      double risk_control=
         dd_penalty*
         streak_penalty;

      // ------------------------------------------------------------
      // Consistency component
      // ------------------------------------------------------------
      double pf_score=
         Normalize01(
            m.profit_factor,
            m_minimum_profit_factor,
            m_max_expected_pf);

      double sharpe_score=0.0;

      if(m.sharpe_ratio>0.0)
         sharpe_score=
            Normalize01(
               m.sharpe_ratio,
               0.0,
               m_max_expected_sharpe);

      double recovery_score=0.0;

      if(m.recovery_factor>0.0)
         recovery_score=
            Normalize01(
               m.recovery_factor,
               0.0,
               m_max_expected_recovery);

      double consistency=
         0.45*pf_score+
         0.30*sharpe_score+
         0.25*recovery_score;

      consistency=
         CAlgoUtils::Clamp(
            consistency,
            0.0,
            1.0);

      // ------------------------------------------------------------
      // Trade sufficiency
      // ------------------------------------------------------------
      double trade_sufficiency=
         CAlgoUtils::Clamp(
            (double)m.trades/
            ((double)m_minimum_trades*2.0),
            0.0,
            1.0);

      // ------------------------------------------------------------
      // Composite fitness
      // ------------------------------------------------------------
      double fitness=
         profit_score*
         risk_control*
         consistency*
         trade_sufficiency;

      if(!MathIsValidNumber(fitness) ||
         fitness<=0.0)
         return 0.0;

      return fitness*100000.0;
     }

public:

   CTesterFitness()
     {
      // These are acceptance thresholds, not optimized strategy
      // parameters.

      m_minimum_trades=100;

      m_maximum_allowed_dd_percent=20.0;

      m_minimum_profit_factor=1.10;

      m_dd_scale=10.0;

      m_max_expected_pf=3.0;
      m_max_expected_sharpe=3.0;
      m_max_expected_recovery=5.0;
     }

   void SetHardRules(
      const int minimum_trades,
      const double maximum_dd_percent,
      const double minimum_profit_factor)
     {
      m_minimum_trades=
         minimum_trades;

      m_maximum_allowed_dd_percent=
         maximum_dd_percent;

      m_minimum_profit_factor=
         minimum_profit_factor;
     }

   void SetScoringScale(
      const double dd_scale,
      const double max_expected_pf,
      const double max_expected_sharpe,
      const double max_expected_recovery)
     {
      m_dd_scale=dd_scale;
      m_max_expected_pf=max_expected_pf;
      m_max_expected_sharpe=max_expected_sharpe;
      m_max_expected_recovery=max_expected_recovery;
     }

   double Calculate()
     {
      if(!MQLInfoInteger(MQL_TESTER))
         return 0.0;

      CTesterStatistics statistics;

      TesterMetrics metrics;

      if(!statistics.Collect(metrics))
         return 0.0;

      if(!PassHardRules(metrics))
         return 0.0;

      return Score(metrics);
     }

   bool Evaluate(
      TesterMetrics &metrics,
      double &fitness)
     {
      fitness=0.0;

      if(!PassHardRules(metrics))
         return false;

      fitness=Score(metrics);

      return (fitness>0.0);
     }
  };

#endif