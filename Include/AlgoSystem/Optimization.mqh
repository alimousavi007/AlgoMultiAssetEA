#ifndef __ALGOSYSTEM_OPTIMIZATION_MQH__
#define __ALGOSYSTEM_OPTIMIZATION_MQH__

#include "Utilities.mqh"

enum ENUM_OPTIMIZATION_GROUP
  {
   OPT_GROUP_NONE=0,
   OPT_GROUP_TREND,
   OPT_GROUP_BREAKOUT,
   OPT_GROUP_MOMENTUM,
   OPT_GROUP_RISK,
   OPT_GROUP_EXITS,
   OPT_GROUP_REGIME
  };

struct OptimizationParameter
  {
   string name;
   ENUM_OPTIMIZATION_GROUP group;
   bool enabled;

   bool integer_type;

   double current;
   double start;
   double step;
   double stop;
  };

struct OptimizationPass
  {
   bool valid;

   double fitness;
   double net_profit;
   double profit_factor;
   double drawdown_percent;
   double sharpe;
   double recovery;

   int trades;
  };

class COptimizationController
  {
private:

   int m_max_parameters;

   ENUM_OPTIMIZATION_GROUP m_active_group;

public:

   COptimizationController()
     {
      m_max_parameters=7;
      m_active_group=OPT_GROUP_NONE;
     }

   void SetMaxParameters(
      const int maximum)
     {
      m_max_parameters=maximum;
     }

   void SetActiveGroup(
      ENUM_OPTIMIZATION_GROUP group)
     {
      m_active_group=group;
     }

   bool ValidateParameterSet(
      const OptimizationParameter &parameters[],
      const int count) const
     {
     
      if(count<=0)
         return false;

      int enabled_count=0;

      for(int i=0;
          i<count;
          i++)
        {
         if(parameters[i].integer_type)
           {
            if(parameters[i].current!=(long)parameters[i].current ||
               parameters[i].start!=(long)parameters[i].start ||
               parameters[i].step!=(long)parameters[i].step ||
               parameters[i].stop!=(long)parameters[i].stop)
               return false;
           }
         if(!parameters[i].enabled)
            continue;

         if(parameters[i].name=="")
            return false;

         if(parameters[i].step<=0.0)
            return false;

         if(parameters[i].stop<
            parameters[i].start)
            return false;

         enabled_count++;
        }

      // Complexity budget.
      if(enabled_count>
         m_max_parameters)
         return false;

      return true;
     }

   bool ApplyParameterRanges(
      OptimizationParameter &parameters[],
      const int count) const
     {
      if(!MQLInfoInteger(MQL_OPTIMIZATION))
         return false;

      if(!ValidateParameterSet(
            parameters,
            count))
         return false;

      for(int i=0;
          i<count;
          i++)
        {
        
         if(!parameters[i].enabled)
            continue;

         bool ok=false;
         
         if(parameters[i].integer_type)
           {
            ok=ParameterSetRange(
               parameters[i].name,
               true,
               (long)parameters[i].current,
               (long)parameters[i].start,
               (long)parameters[i].step,
               (long)parameters[i].stop);
           }
         else
           {
            ok=ParameterSetRange(
               parameters[i].name,
               true,
               parameters[i].current,
               parameters[i].start,
               parameters[i].step,
               parameters[i].stop);
           }
         
         if(!ok)
            return false;
        }

      return true;
     }

   bool IsStableRegion(
      const OptimizationPass &passes[],
      const int count,
      const double minimum_fitness) const
     {
      if(count<3)
         return false;

      int valid_count=0;
      int passing_count=0;

      for(int i=0;
          i<count;
          i++)
        {
         if(!passes[i].valid)
            continue;

         valid_count++;

         if(passes[i].fitness>=minimum_fitness)
            passing_count++;
        }

      if(valid_count<3)
         return false;

      double ratio=
         (double)passing_count/
         (double)valid_count;

      return ratio>=0.50;
     }
  };

#endif