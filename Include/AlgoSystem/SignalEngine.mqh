#ifndef __ALGOSYSTEM_SIGNALENGINE_MQH__
#define __ALGOSYSTEM_SIGNALENGINE_MQH__

#include "Interfaces.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Signal Engine                                                    |
//|                                                                  |
//| Responsibility:                                                 |
//| - validate strategy signals                                     |
//| - reject incompatible regime/strategy combinations               |
//| - resolve same-direction candidates                              |
//| - resolve opposite-direction conflicts                           |
//| - return one deterministic selected signal                       |
//|                                                                  |
//| Does NOT:                                                        |
//| - calculate risk                                                 |
//| - send orders                                                    |
//+------------------------------------------------------------------+
class CSignalEngine : public ISignalEngine
  {
private:

   double m_conflict_threshold;
   double m_min_score;

   bool m_initialized;

   //+----------------------------------------------------------------+
   //| Reset signal                                                   |
   //+----------------------------------------------------------------+
   void ResetSignal(
      StrategySignal &signal) const
     {
      signal.valid=false;

      signal.direction=SIGNAL_NONE;
      signal.strategy=STRATEGY_NONE;

      signal.symbol="";
      signal.timeframe=PERIOD_CURRENT;

      signal.regime=REGIME_UNKNOWN;

      signal.score=0.0;
      signal.confidence=0.0;

      signal.entry=0.0;
      signal.stop=0.0;
      signal.target=0.0;

      signal.timestamp=0;

      signal.signal_id="";
      signal.reason="";
     }

   //+----------------------------------------------------------------+
   //| Strategy/regime compatibility                                  |
   //+----------------------------------------------------------------+
   string CompatibilityRejection(
      const StrategySignal &signal) const
     {
      if(!signal.valid)
         return "INVALID_SIGNAL";

      if(signal.direction==SIGNAL_NONE)
         return "NO_DIRECTION";

      if(signal.score<m_min_score)
         return "SCORE_BELOW_MINIMUM";

      if(signal.strategy==STRATEGY_TREND_PULLBACK)
        {
         if(signal.regime==REGIME_TREND_UP ||
            signal.regime==REGIME_TREND_DOWN)
            return "";

         return "REGIME_INCOMPATIBLE";
        }

      if(signal.strategy==STRATEGY_BREAKOUT)
         return signal.regime==REGIME_BREAKOUT ?
                "" : "REGIME_INCOMPATIBLE";

      if(signal.strategy==STRATEGY_MOMENTUM)
        {
         if(signal.regime==REGIME_TREND_UP ||
            signal.regime==REGIME_TREND_DOWN ||
            signal.regime==REGIME_BREAKOUT)
            return "";

         return "REGIME_INCOMPATIBLE";
        }

      if(signal.strategy==STRATEGY_MEAN_REVERSION)
         return signal.regime==REGIME_RANGE ?
                "" : "REGIME_INCOMPATIBLE";

      if(signal.strategy==STRATEGY_RELATIVE_VALUE)
         return signal.regime!=REGIME_UNCERTAIN ?
                "" : "REGIME_INCOMPATIBLE";

      return "UNSUPPORTED_STRATEGY";
     }

   bool IsCompatible(
      const StrategySignal &signal) const
     {
      return CompatibilityRejection(signal)=="";
     }

   //+----------------------------------------------------------------+
   //| Prefer a candidate                                            |
   //+----------------------------------------------------------------+
   bool BetterCandidate(
      const StrategySignal &candidate,
      const StrategySignal &current) const
     {
      if(!current.valid)
         return true;

      if(candidate.score>
         current.score)
         return true;

      if(candidate.score<
         current.score)
         return false;

      // Same score:
      // prefer higher timeframe structure.
      if((int)candidate.timeframe>
         (int)current.timeframe)
         return true;

      if((int)candidate.timeframe<
         (int)current.timeframe)
         return false;

      // Deterministic final tie-breaker:
      // lower enum strategy ID wins.
      return
         (int)candidate.strategy<
         (int)current.strategy;
     }

   //+----------------------------------------------------------------+
   //| Select highest scored direction                                |
   //+----------------------------------------------------------------+
   bool SelectDirection(
      const StrategySignal &signals[],
      const int count,
      const ENUM_SIGNAL_DIRECTION direction,
      StrategySignal &best) const
     {
      ResetSignal(best);

      for(int i=0; i<count; i++)
        {
         if(!IsCompatible(signals[i]))
            continue;

         if(signals[i].direction!=direction)
            continue;

         if(BetterCandidate(
               signals[i],
               best))
           {
            best=signals[i];
         }
        }

      return best.valid;
     }

public:

   CSignalEngine()
     {
      m_conflict_threshold=5.0;
      m_min_score=0.0;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Parameters                                                     |
   //+----------------------------------------------------------------+
   void SetParameters(
      const double conflict_threshold,
      const double minimum_score)
     {
      m_conflict_threshold=
         conflict_threshold;

      m_min_score=
         minimum_score;

      m_initialized=false;
     }

   //+----------------------------------------------------------------+
   //| Initialize                                                     |
   //+----------------------------------------------------------------+
   virtual bool Initialize() override
     {
      if(m_conflict_threshold<0.0)
         return false;

      if(m_min_score<0.0 ||
         m_min_score>100.0)
         return false;

      m_initialized=true;

      return true;
     }

   bool CountCompatible(
      const StrategySignal &signals[],
      const int count,
      int &compatible_count,
      string &rejection_summary) const
     {
      compatible_count=0;
      rejection_summary="";

      if(!m_initialized ||
         count<0 ||
         count>ArraySize(signals))
         return false;

      for(int i=0;i<count;i++)
        {
         string rejection=CompatibilityRejection(signals[i]);
         if(rejection=="")
            compatible_count++;
         else
           {
            if(rejection_summary!="")
               rejection_summary+=",";

            rejection_summary+=
               EnumToString(signals[i].strategy)+":"+rejection;
           }
        }

      return true;
     }

   //+----------------------------------------------------------------+
   //| Resolve signals                                                |
   //+----------------------------------------------------------------+
   virtual bool Evaluate(
      const StrategySignal &signals[],
      const int count,
      StrategySignal &selected_signal) override
     {
      ResetSignal(selected_signal);

      if(!m_initialized)
         return false;

      if(count<=0)
         return false;

      StrategySignal best_long;
      StrategySignal best_short;

      ResetSignal(best_long);
      ResetSignal(best_short);

      // ------------------------------------------------------------
      // First pass: select best candidate per direction.
      // ------------------------------------------------------------
      for(int i=0; i<count; i++)
        {
         if(!IsCompatible(signals[i]))
            continue;

         if(signals[i].direction==SIGNAL_LONG)
           {
            if(BetterCandidate(
                  signals[i],
                  best_long))
               best_long=signals[i];
           }

         if(signals[i].direction==SIGNAL_SHORT)
           {
            if(BetterCandidate(
                  signals[i],
                  best_short))
               best_short=signals[i];
           }
        }

      bool has_long=best_long.valid;
      bool has_short=best_short.valid;

      if(!has_long && !has_short)
         return false;

      // ------------------------------------------------------------
      // Only Long candidates exist.
      // ------------------------------------------------------------
      if(has_long && !has_short)
        {
         selected_signal=best_long;
         return true;
        }

      // ------------------------------------------------------------
      // Only Short candidates exist.
      // ------------------------------------------------------------
      if(has_short && !has_long)
        {
         selected_signal=best_short;
         return true;
        }

      // ------------------------------------------------------------
      // Opposite-direction conflict.
      // ------------------------------------------------------------
      double difference=
         MathAbs(
            best_long.score-
            best_short.score);

      if(difference<=m_conflict_threshold)
        {
         // Near tie => NO TRADE.
         ResetSignal(selected_signal);

         return false;
        }

      if(best_long.score>
         best_short.score)
        {
         selected_signal=best_long;
         selected_signal.reason=
            "Conflict resolved: Long score dominant";

         return true;
        }

      selected_signal=best_short;

      selected_signal.reason=
         "Conflict resolved: Short score dominant";

      return true;
     }

   //+----------------------------------------------------------------+
   //| Accessors                                                     |
   //+----------------------------------------------------------------+
   double ConflictThreshold() const
     {
      return m_conflict_threshold;
     }

   bool IsInitialized() const
     {
      return m_initialized;
     }
  };

#endif