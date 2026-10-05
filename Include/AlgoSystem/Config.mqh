#ifndef __ALGOSYSTEM_CONFIG_MQH__
#define __ALGOSYSTEM_CONFIG_MQH__

#include "Constants.mqh"

class CAlgoConfig
  {
public:

   ENUM_TRADING_PROFILE Profile;
   ENUM_TRADING_MODE    Mode;

   double RiskPercent;

   double DailyLossLimitPercent;
   double MonthlyLossLimitPercent;

   int MaxPositionsTotal;
   int MaxPositionsPerSymbol;
   int MaxPositionsPerStrategy;

   double MaxPortfolioRiskPercent;

   double MinRiskReward;

   double SignalScoreThreshold;
   double ConflictThreshold;

   bool AllowUncertainRegime;
   bool AllowMeanReversion;
   bool AllowRelativeValue;

   bool UseSessionFilter;
   bool UseSpreadFilter;

   bool UseBreakEven;
   bool UseTrailingStop;
   bool UsePartialClose;
   bool UseTimeExit;

   int MaxConsecutiveLosses;

   ENUM_TIMEFRAMES ScalpStructureTF;
   ENUM_TIMEFRAMES ScalpSignalTF;
   ENUM_TIMEFRAMES ScalpEntryTF;

   ENUM_TIMEFRAMES DayStructureTF;
   ENUM_TIMEFRAMES DaySignalTF;
   ENUM_TIMEFRAMES DayEntryTF;

   ENUM_TIMEFRAMES SwingStructureTF;
   ENUM_TIMEFRAMES SwingSignalTF;
   ENUM_TIMEFRAMES SwingEntryTF;

   CAlgoConfig()
     {
      Profile = PROFILE_DAY;
      Mode    = MODE_SIGNAL_ONLY;

      RiskPercent = DEFAULT_RISK_PERCENT;

      DailyLossLimitPercent   = DEFAULT_DAILY_LOSS_LIMIT;
      MonthlyLossLimitPercent = DEFAULT_MONTHLY_LOSS_LIMIT;

      MaxPositionsTotal        = 3;
      MaxPositionsPerSymbol    = 1;
      MaxPositionsPerStrategy  = 1;

      MaxPortfolioRiskPercent = 3.0;

      MinRiskReward          = DEFAULT_MIN_RR;
      SignalScoreThreshold   = DEFAULT_SIGNAL_SCORE_THRESHOLD;
      ConflictThreshold      = 5.0;

      AllowUncertainRegime = false;
      AllowMeanReversion  = false;
      AllowRelativeValue  = false;

      UseSessionFilter = true;
      UseSpreadFilter  = true;

      UseBreakEven    = false;
      UseTrailingStop = false;
      UsePartialClose = false;
      UseTimeExit     = false;

      MaxConsecutiveLosses = 3;

      ScalpStructureTF = PERIOD_M15;
      ScalpSignalTF    = PERIOD_M5;
      ScalpEntryTF     = PERIOD_M1;

      DayStructureTF = PERIOD_H4;
      DaySignalTF    = PERIOD_H1;
      DayEntryTF     = PERIOD_M15;

      SwingStructureTF = PERIOD_D1;
      SwingSignalTF    = PERIOD_H4;
      SwingEntryTF     = PERIOD_H1;
     }
  };

#endif