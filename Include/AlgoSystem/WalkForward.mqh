#ifndef __ALGOSYSTEM_WALKFORWARD_MQH__
#define __ALGOSYSTEM_WALKFORWARD_MQH__

#include "Utilities.mqh"

struct WalkForwardWindow
  {
   bool valid;

   datetime train_start;
   datetime train_end;

   datetime forward_start;
   datetime forward_end;

   int index;
  };

struct WalkForwardResult
  {
   bool valid;

   int window_index;

   double in_sample_fitness;
   double out_of_sample_fitness;

   double in_sample_profit;
   double out_of_sample_profit;

   double in_sample_dd;
   double out_of_sample_dd;

   double in_sample_pf;
   double out_of_sample_pf;

   int out_of_sample_trades;

   bool passed;
  };

class CWalkForwardValidator
  {
private:

   int m_train_days;
   int m_forward_days;

   int m_step_days;

   double m_min_oos_fitness_ratio;
   double m_min_oos_pf;
   
   int m_min_oos_trades;

public:

   CWalkForwardValidator()
     {
      // 24 months / 6 months approximate default.
      // Exact calendar scheduling can be configured by caller.

      m_train_days=730;
      m_forward_days=182;

      m_step_days=182;

      m_min_oos_fitness_ratio=0.50;
      m_min_oos_pf=1.00;
      m_min_oos_trades=30;
     }
   void SetMinimumOOSTrades(
      const int minimum_trades)
     {
      m_min_oos_trades=minimum_trades;
     }

   void SetSchedule(
      const int train_days,
      const int forward_days,
      const int step_days)
     {
      m_train_days=train_days;
      m_forward_days=forward_days;
      m_step_days=step_days;
     }

   void SetAcceptance(
      const double minimum_oos_fitness_ratio,
      const double minimum_oos_pf)
     {
      m_min_oos_fitness_ratio=
         minimum_oos_fitness_ratio;

      m_min_oos_pf=
         minimum_oos_pf;
     }

   int BuildWindows(
      const datetime overall_start,
      const datetime overall_end,
      WalkForwardWindow &windows[]) const
     {
      ArrayResize(windows,0);

      if(overall_start<=0 ||
         overall_end<=overall_start)
         return 0;

      if(m_train_days<=0 ||
         m_forward_days<=0 ||
         m_step_days<=0)
         return 0;

      datetime cursor=
         overall_start;

      int index=0;

      while(true)
        {
         datetime train_start=cursor;

         datetime train_end=
            train_start+
            (datetime)m_train_days*86400;

         datetime forward_start=
            train_end;

         datetime forward_end=
            forward_start+
            (datetime)m_forward_days*86400;

         if(forward_end>overall_end)
            break;

         int size=
            ArraySize(windows)+1;

         ArrayResize(
            windows,
            size);

         windows[size-1].valid=true;

         windows[size-1].train_start=
            train_start;

         windows[size-1].train_end=
            train_end;

         windows[size-1].forward_start=
            forward_start;

         windows[size-1].forward_end=
            forward_end;

         windows[size-1].index=index;

         index++;

         cursor=
            cursor+
            (datetime)m_step_days*86400;
        }

      return ArraySize(windows);
     }

   bool EvaluateWindow(
      WalkForwardResult &result) const
     {
      if(!result.valid)
         return false;

      if(result.in_sample_fitness<=0.0)
        {
         result.passed=false;
         return false;
        }

      double fitness_ratio=
         result.out_of_sample_fitness/
         result.in_sample_fitness;

      bool fitness_ok=
         fitness_ratio>=
         m_min_oos_fitness_ratio;

      bool pf_ok=
         result.out_of_sample_pf>=
         m_min_oos_pf;

      bool trades_ok=
         result.out_of_sample_trades>=
         m_min_oos_trades;

      result.passed=
         fitness_ok &&
         pf_ok &&
         trades_ok;

      return result.passed;
     }

   double OOSFitnessRetention(
      const WalkForwardResult &result) const
     {
      if(result.in_sample_fitness<=0.0)
         return 0.0;

      return CAlgoUtils::Clamp(
         result.out_of_sample_fitness/
         result.in_sample_fitness,
         0.0,
         1.0);
     }
  };

#endif