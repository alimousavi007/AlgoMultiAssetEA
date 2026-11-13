#ifndef __ALGOSYSTEM_UTILITIES_MQH__
#define __ALGOSYSTEM_UTILITIES_MQH__

class CAlgoUtils
  {
public:

   static double NormalizePriceToTick(
      const double price,
      const double tick_size,
      const bool round_up,
      const int digits)
     {
      if(price<=0.0 ||
         tick_size<=0.0 ||
         digits<0)
         return 0.0;
   
      double units=
         price/tick_size;
   
      double aligned=
         round_up ?
         MathCeil(units-1e-12)*tick_size :
         MathFloor(units+1e-12)*tick_size;
   
      return NormalizeDouble(
         aligned,
         digits);
     }
     
   static double SafeDivide(const double numerator,
                            const double denominator,
                            const double fallback = 0.0)
     {
      if(denominator == 0.0)
         return fallback;

      return numerator / denominator;
     }

   static double Clamp(const double value,
                       const double minimum,
                       const double maximum)
     {
      if(value < minimum)
         return minimum;

      if(value > maximum)
         return maximum;

      return value;
     }

   static bool IsValidPrice(const double price)
     {
      return (price > 0.0 && price != EMPTY_VALUE);
     }

   static bool IsValidVolume(const double volume)
     {
      return (volume > 0.0 && volume != EMPTY_VALUE);
     }

   static double NormalizeVolume(const double volume,
                                 const double minimum,
                                 const double maximum,
                                 const double step)
     {
      if(step <= 0.0)
         return 0.0;

      if(volume < minimum)
         return 0.0;

      double normalized = MathFloor(volume / step) * step;

      if(normalized > maximum)
         normalized = maximum;

      if(normalized < minimum)
         return 0.0;

      return normalized;
     }

   static double NormalizePrice(const double price,
                                const int digits)
     {
      return NormalizeDouble(price, digits);
     }

static bool IsFinite(const double value)
      {
       return MathIsValidNumber(value);
      }

    // Enum to string conversions (shared)
    static string TimeframeToString(ENUM_TIMEFRAMES tf)
      {
       switch(tf)
         {
          case PERIOD_M1:  return "M1";
          case PERIOD_M5:  return "M5";
          case PERIOD_M15: return "M15";
          case PERIOD_M30: return "M30";
          case PERIOD_H1:  return "H1";
          case PERIOD_H4:  return "H4";
          case PERIOD_D1:  return "D1";
          case PERIOD_W1:  return "W1";
          case PERIOD_MN1: return "MN1";
          default: return "TF";
         }
      }

    static string StyleToString(ENUM_TRADING_STYLE s)
      {
       switch(s)
         {
          case STYLE_SCALPING:    return "SCALP";
          case STYLE_DAY_TRADING: return "DAY";
          case STYLE_SWING_TRADING: return "SWING";
          default: return "UNKNOWN";
         }
      }

    static string RegimeToString(ENUM_HYBRID_REGIME r)
      {
       switch(r)
         {
          case HYBRID_REGIME_TRENDING:            return "TREND";
          case HYBRID_REGIME_RANGING:             return "RANGE";
          case HYBRID_REGIME_VOLATILITY_EXPANSION: return "VOL_EXP";
          case HYBRID_REGIME_COMPRESSION:         return "COMPRESS";
          case HYBRID_REGIME_TRANSITION:          return "TRANSITION";
          case HYBRID_REGIME_INSUFFICIENT_DATA:   return "N/A";
          default: return "?";
         }
      }

    static string BiasToString(ENUM_BIAS_DIRECTION b)
      {
       switch(b)
         {
          case BIAS_BULLISH:          return "BULL";
          case BIAS_BEARISH:          return "BEAR";
          case BIAS_NEUTRAL:          return "NEUTRAL";
          case BIAS_CONFLICTED:       return "CONFLICT";
          case BIAS_INSUFFICIENT_DATA: return "N/A";
          default: return "?";
         }
      }

    static string NewsStateToString(ENUM_NEWS_STATE s)
      {
       switch(s)
         {
          case NEWS_UNAVAILABLE:        return "N/A";
          case NEWS_NO_EVENT_SCHEDULED: return "CLEAR";
          case NEWS_BLACKOUT_ACTIVE:    return "BLACKOUT";
          case NEWS_COOLDOWN_ACTIVE:    return "COOLDOWN";
          case NEWS_EVENT_PASSED:       return "PAST";
          default: return "?";
         }
      }

    static string DecisionStatusToString(ENUM_DECISION_STATUS s)
      {
       switch(s)
         {
          case DECISION_BUY_CANDIDATE:      return "BUY";
          case DECISION_SELL_CANDIDATE:     return "SELL";
          case DECISION_NO_TRADE:           return "NO-TRADE";
          case DECISION_DATA_UNAVAILABLE:   return "NO-DATA";
          case DECISION_NEWS_BLOCKED:       return "NEWS-BLOCKED";
          case DECISION_RISK_REJECTED:      return "RISK-REJECT";
          case DECISION_CONFLICTED_SIGNAL:  return "CONFLICT";
          case DECISION_SETUP_EXPIRED:      return "EXPIRED";
          case DECISION_SETUP_INVALIDATED:  return "INVALIDATED";
          default: return "?";
         }
      }
  };
#endif