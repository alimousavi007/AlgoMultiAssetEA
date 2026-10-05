#ifndef __ALGOSYSTEM_RELATIVEVALUESTRATEGY_MQH__
#define __ALGOSYSTEM_RELATIVEVALUESTRATEGY_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

struct RelativeValueOpportunity
  {
   bool valid;

   string primary_symbol;
   string secondary_symbol;

   double ratio;
   double ratio_mean;
   double ratio_stddev;
   double zscore;

   double target_zscore;

   bool stable;

   ENUM_SIGNAL_DIRECTION primary_direction;
   ENUM_SIGNAL_DIRECTION secondary_direction;

   double score;

   string reason;
  };

//+------------------------------------------------------------------+
//| Gold / Silver Relative Value                                    |
//|                                                                  |
//| Analytical V2 module.                                            |
//| Multi-leg execution is intentionally deferred to Phase 20.       |
//+------------------------------------------------------------------+
class CRelativeValueStrategy : public IStrategy
  {
private:

   string m_primary_symbol;
   string m_secondary_symbol;

   int m_lookback;

   double m_entry_zscore;
   double m_exit_zscore;

   double m_max_zscore;

   double m_min_stability_ratio;

   double m_min_score;

   bool m_initialized;

   //+----------------------------------------------------------------+
   void ResetOpportunity(
      RelativeValueOpportunity &opportunity) const
     {
      opportunity.valid=false;

      opportunity.primary_symbol="";
      opportunity.secondary_symbol="";

      opportunity.ratio=0.0;
      opportunity.ratio_mean=0.0;
      opportunity.ratio_stddev=0.0;
      opportunity.zscore=0.0;

      opportunity.target_zscore=0.0;

      opportunity.stable=false;

      opportunity.primary_direction=SIGNAL_NONE;
      opportunity.secondary_direction=SIGNAL_NONE;

      opportunity.score=0.0;

      opportunity.reason="";
     }

   //+----------------------------------------------------------------+
   bool ValidateParameters() const
     {
      if(m_primary_symbol=="")
         return false;

      if(m_secondary_symbol=="")
         return false;

      if(m_primary_symbol==m_secondary_symbol)
         return false;

      if(m_lookback<20)
         return false;

      if(m_entry_zscore<=0.0)
         return false;

      if(m_exit_zscore<0.0)
         return false;

      if(m_entry_zscore<=m_exit_zscore)
         return false;

      if(m_max_zscore<=m_entry_zscore)
         return false;

      if(m_min_stability_ratio<=0.0)
         return false;

      if(m_min_score<0.0 ||
         m_min_score>100.0)
         return false;

      return true;
     }

   //+----------------------------------------------------------------+
   bool CalculatePair(
      ENUM_TIMEFRAMES timeframe,
      double &ratio,
      double &mean,
      double &stddev,
      double &zscore,
      double &stability) const
     {
      ratio=0.0;
      mean=0.0;
      stddev=0.0;
      zscore=0.0;
      stability=0.0;

      bool custom1=false;
      bool custom2=false;

      if(!SymbolExist(
            m_primary_symbol,
            custom1))
         return false;

      if(!SymbolExist(
            m_secondary_symbol,
            custom2))
         return false;

      if(!SymbolSelect(
            m_primary_symbol,
            true))
         return false;

      if(!SymbolSelect(
            m_secondary_symbol,
            true))
         return false;

      if(!SymbolIsSynchronized(
            m_primary_symbol) ||
         !SymbolIsSynchronized(
            m_secondary_symbol))
         return false;

      MqlRates primary[];
      MqlRates secondary[];

      ArrayResize(
         primary,
         m_lookback);

      ArrayResize(
         secondary,
         m_lookback);

      int copied1=
         CopyRates(
            m_primary_symbol,
            timeframe,
            1,
            m_lookback,
            primary);

      int copied2=
         CopyRates(
            m_secondary_symbol,
            timeframe,
            1,
            m_lookback,
            secondary);

      if(copied1!=m_lookback ||
         copied2!=m_lookback)
         return false;

      double ratios[];

      ArrayResize(
         ratios,
         m_lookback);

      double sum=0.0;

      for(int i=0;
          i<m_lookback;
          i++)
        {
         if(secondary[i].close<=0.0 ||
            primary[i].close<=0.0)
            return false;

         ratios[i]=
            primary[i].close/
            secondary[i].close;

         sum+=ratios[i];
        }

      mean=
         sum/(double)m_lookback;

      double variance=0.0;

      for(int i=0;
          i<m_lookback;
          i++)
        {
         double delta=
            ratios[i]-mean;

         variance+=delta*delta;
        }

      variance/=
         (double)m_lookback;

      stddev=MathSqrt(variance);

      if(stddev<=0.0)
         return false;

      ratio=ratios[m_lookback-1];

      zscore=
         (ratio-mean)/stddev;

      // Simple stability proxy:
      // ratio of observations that stay within +/- 3 standard
      // deviations of the rolling relationship.
      int stable_count=0;

      for(int i=0;
          i<m_lookback;
          i++)
        {
         double normalized=
            MathAbs(
               ratios[i]-mean)/
            stddev;

         if(normalized<=3.0)
            stable_count++;
        }

      stability=
         (double)stable_count/
         (double)m_lookback;

      return MathIsValidNumber(
                ratio) &&
             MathIsValidNumber(
                zscore);
     }

   //+----------------------------------------------------------------+
   double Score(
      const RelativeValueOpportunity &opportunity) const
     {
      double abs_z=
         MathAbs(
            opportunity.zscore);

      double score=0.0;

      if(abs_z>=m_entry_zscore)
         score+=30.0;

      if(abs_z>=2.0)
         score+=20.0;
      else if(abs_z>=1.5)
         score+=10.0;

      if(opportunity.stable)
         score+=25.0;

      double stability_score=
         CAlgoUtils::Clamp(
            opportunity.stable ?
            1.0 :
            0.0,
            0.0,
            1.0);

      score+=
         stability_score*15.0;

      // Avoid pathological extensions.
      if(abs_z<m_max_zscore)
         score+=10.0;

      return CAlgoUtils::Clamp(
         score,
         0.0,
         100.0);
     }

public:

   CRelativeValueStrategy()
     {
      m_primary_symbol="";
      m_secondary_symbol="";

      m_lookback=60;

      m_entry_zscore=2.0;
      m_exit_zscore=0.5;

      m_max_zscore=4.0;

      m_min_stability_ratio=0.80;

      m_min_score=70.0;

      m_initialized=false;
     }

   void SetPair(
      const string primary_symbol,
      const string secondary_symbol)
     {
      m_primary_symbol=primary_symbol;
      m_secondary_symbol=secondary_symbol;
      m_initialized=false;
     }

   void SetParameters(
      const int lookback,
      const double entry_zscore,
      const double exit_zscore,
      const double max_zscore,
      const double minimum_stability,
      const double minimum_score)
     {
      m_lookback=lookback;

      m_entry_zscore=entry_zscore;
      m_exit_zscore=exit_zscore;
      m_max_zscore=max_zscore;

      m_min_stability_ratio=
         minimum_stability;

      m_min_score=minimum_score;

      m_initialized=false;
     }

   virtual bool Initialize() override
     {
      if(!ValidateParameters())
         return false;

      m_initialized=true;

      return true;
     }

   virtual ENUM_STRATEGY_ID Id() const override
     {
      return STRATEGY_RELATIVE_VALUE;
     }

   //+----------------------------------------------------------------+
   //| Analytical opportunity                                        |
   //+----------------------------------------------------------------+
   bool EvaluatePair(
      ENUM_TIMEFRAMES timeframe,
      RelativeValueOpportunity &opportunity) const
     {
      ResetOpportunity(
         opportunity);

      if(!m_initialized)
         return false;

      double ratio;
      double mean;
      double stddev;
      double zscore;
      double stability;

      if(!CalculatePair(
            timeframe,
            ratio,
            mean,
            stddev,
            zscore,
            stability))
         return false;

      opportunity.primary_symbol=
         m_primary_symbol;

      opportunity.secondary_symbol=
         m_secondary_symbol;

      opportunity.ratio=ratio;
      opportunity.ratio_mean=mean;
      opportunity.ratio_stddev=stddev;
      opportunity.zscore=zscore;

      opportunity.target_zscore=
         m_exit_zscore;

      opportunity.stable=
         stability>=m_min_stability_ratio;

      if(zscore>=m_entry_zscore &&
         zscore<m_max_zscore &&
         opportunity.stable)
        {
         // Primary is relatively expensive.
         opportunity.primary_direction=
            SIGNAL_SHORT;

         opportunity.secondary_direction=
            SIGNAL_LONG;

         opportunity.reason=
            "XAU/XAG ratio high: short primary / long secondary";
        }
      else if(zscore<=-m_entry_zscore &&
              MathAbs(zscore)<m_max_zscore &&
              opportunity.stable)
        {
         // Primary is relatively cheap.
         opportunity.primary_direction=
            SIGNAL_LONG;

         opportunity.secondary_direction=
            SIGNAL_SHORT;

         opportunity.reason=
            "XAU/XAG ratio low: long primary / short secondary";
        }
      else
        {
         opportunity.reason=
            "No valid relative-value deviation";
         return false;
        }

      opportunity.score=
         Score(opportunity);

      if(opportunity.score<
         m_min_score)
         return false;

      opportunity.valid=true;

      return true;
     }

   //+----------------------------------------------------------------+
   //| IStrategy                                                      |
   //|                                                                  |
   //| Deliberately disabled for single-leg execution.                |
   //+----------------------------------------------------------------+
   virtual bool Evaluate(
      const StrategyContext &context,
      StrategySignal &signal) override
     {
      signal.valid=false;
      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_RELATIVE_VALUE;

      // A two-leg trade cannot safely be expressed as the existing
      // single-position StrategySignal. Phase 20 will add the
      // MultiLeg Execution path.
      return false;
     }
  };

#endif