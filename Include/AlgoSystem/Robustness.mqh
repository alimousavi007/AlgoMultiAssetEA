#ifndef __ALGOSYSTEM_ROBUSTNESS_MQH__
#define __ALGOSYSTEM_ROBUSTNESS_MQH__

#include "Utilities.mqh"

enum ENUM_ROBUSTNESS_SCENARIO
  {
   ROBUST_BASELINE=0,
   ROBUST_SPREAD_STRESS,
   ROBUST_SLIPPAGE_STRESS,
   ROBUST_ENTRY_DELAY,
   ROBUST_SL_VARIATION,
   ROBUST_TP_VARIATION,
   ROBUST_PARAMETER_PERTURBATION,
   ROBUST_TRADE_ORDER_VARIATION
  };

struct RobustnessScenario
  {
   ENUM_ROBUSTNESS_SCENARIO type;

   double spread_multiplier;
   double slippage_multiplier;

   int entry_delay_bars;

   double sl_multiplier;
   double tp_multiplier;

   double parameter_perturbation_percent;

   bool randomize_trade_order;
  };

struct RobustnessScenarioResult
  {
   bool valid;

   ENUM_ROBUSTNESS_SCENARIO type;

   double fitness;

   double net_profit;
   double profit_factor;

   double drawdown_percent;

   int trades;

   bool passed;
  };

struct RobustnessReport
  {
   bool valid;

   double baseline_fitness;

   double minimum_stressed_fitness;
   double average_stressed_fitness;

   double fitness_retention;

   double pass_ratio;

   int scenarios;
   int passed_scenarios;

   bool robust;
   double minimum_fitness_retention;
  };

class CRobustnessEngine
  {
private:

   double m_min_retention;
   double m_min_pass_ratio;

public:

   CRobustnessEngine()
     {
      m_min_retention=0.60;
      m_min_pass_ratio=0.70;
     }

   void SetAcceptance(
      const double minimum_retention,
      const double minimum_pass_ratio)
     {
      m_min_retention=minimum_retention;
      m_min_pass_ratio=minimum_pass_ratio;
     }

   int BuildDefaultScenarios(
      RobustnessScenario &scenarios[]) const
     {
      ArrayResize(
         scenarios,
         0);

      // Baseline
      AddScenario(
         scenarios,
         ROBUST_BASELINE,
         1.0,
         1.0,
         0,
         1.0,
         1.0,
         0.0,
         false);

      // Spread stress
      AddScenario(
         scenarios,
         ROBUST_SPREAD_STRESS,
         1.50,
         1.0,
         0,
         1.0,
         1.0,
         0.0,
         false);

      // Slippage stress
      AddScenario(
         scenarios,
         ROBUST_SLIPPAGE_STRESS,
         1.0,
         2.0,
         0,
         1.0,
         1.0,
         0.0,
         false);

      // Entry delay
      AddScenario(
         scenarios,
         ROBUST_ENTRY_DELAY,
         1.0,
         1.0,
         1,
         1.0,
         1.0,
         0.0,
         false);

      // SL variation
      AddScenario(
         scenarios,
         ROBUST_SL_VARIATION,
         1.0,
         1.0,
         0,
         1.10,
         1.0,
         0.0,
         false);

      // TP variation
      AddScenario(
         scenarios,
         ROBUST_TP_VARIATION,
         1.0,
         1.0,
         0,
         1.0,
         0.90,
         0.0,
         false);

      // Parameter perturbation
      AddScenario(
         scenarios,
         ROBUST_PARAMETER_PERTURBATION,
         1.0,
         1.0,
         0,
         1.0,
         1.0,
         5.0,
         false);

      // Trade-order variation
      AddScenario(
         scenarios,
         ROBUST_TRADE_ORDER_VARIATION,
         1.0,
         1.0,
         0,
         1.0,
         1.0,
         0.0,
         true);

      return ArraySize(scenarios);
     }

   void AddScenario(
      RobustnessScenario &scenarios[],
      ENUM_ROBUSTNESS_SCENARIO type,
      const double spread_multiplier,
      const double slippage_multiplier,
      const int entry_delay_bars,
      const double sl_multiplier,
      const double tp_multiplier,
      const double parameter_perturbation,
      const bool randomize_trade_order) const
     {
      int size=
         ArraySize(scenarios)+1;

      ArrayResize(
         scenarios,
         size);

      scenarios[size-1].type=type;

      scenarios[size-1].spread_multiplier=
         spread_multiplier;

      scenarios[size-1].slippage_multiplier=
         slippage_multiplier;

      scenarios[size-1].entry_delay_bars=
         entry_delay_bars;

      scenarios[size-1].sl_multiplier=
         sl_multiplier;

      scenarios[size-1].tp_multiplier=
         tp_multiplier;

      scenarios[size-1].parameter_perturbation_percent=
         parameter_perturbation;

      scenarios[size-1].randomize_trade_order=
         randomize_trade_order;
     }

   bool EvaluateScenario(
      const RobustnessScenarioResult &result,
      const double baseline_fitness) const
     {
      if(!result.valid ||
         baseline_fitness<=0.0)
         return false;

      double retention=
         result.fitness/
         baseline_fitness;

      if(result.trades<=0)
         return false;

      if(result.profit_factor<=1.0)
         return false;

      return retention>=m_min_retention;
     }

   bool BuildReport(
      const RobustnessScenarioResult &results[],
      const int count,
      RobustnessReport &report) const
     {
      report.valid=false;

      report.baseline_fitness=0.0;
      report.minimum_stressed_fitness=0.0;
      report.average_stressed_fitness=0.0;
      report.fitness_retention=0.0;
      report.pass_ratio=0.0;

      report.scenarios=count;
      report.passed_scenarios=0;
      report.robust=false;

      if(count<=0)
         return false;

      double baseline=0.0;
      double sum=0.0;
      double minimum=DBL_MAX;

      int stressed=0;
      int passed=0;

      for(int i=0;
          i<count;
          i++)
        {
         if(!results[i].valid)
            return false;

         if(results[i].type==
            ROBUST_BASELINE)
           {
            baseline=
               results[i].fitness;
            continue;
           }

         stressed++;

         sum+=results[i].fitness;

         if(results[i].fitness<minimum)
            minimum=results[i].fitness;

         if(EvaluateScenario(
               results[i],
               baseline))
            passed++;
        }

      if(baseline<=0.0 ||
         stressed<=0)
         return false;

      report.baseline_fitness=baseline;

      report.minimum_stressed_fitness=
         minimum;

      report.average_stressed_fitness=
         sum/(double)stressed;

      report.fitness_retention=
         report.average_stressed_fitness/
         baseline;
         
      report.minimum_fitness_retention=
         report.minimum_stressed_fitness/
         baseline;

      report.pass_ratio=
         (double)passed/
         (double)stressed;

      report.passed_scenarios=passed;

      report.robust=
         report.fitness_retention>=m_min_retention &&
         report.minimum_fitness_retention>=m_min_retention &&
         report.pass_ratio>=m_min_pass_ratio;

      report.valid=true;

      return true;
     }
  };

#endif