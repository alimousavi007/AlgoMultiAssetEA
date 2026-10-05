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
  };

#endif