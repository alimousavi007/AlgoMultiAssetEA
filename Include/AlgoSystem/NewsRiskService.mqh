//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef __ALGOSYSTEM_NEWS_RISK_MQH__
#define __ALGOSYSTEM_NEWS_RISK_MQH__

#include "HybridTypes.mqh"
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| News Provider Interface                                           |
//|                                                                  |
//| Abstract base for news data providers.                            |
//| The implementation must provide real data or report unavailable.|
//+------------------------------------------------------------------+
class INewsProvider
  {
public:
   virtual          ~INewsProvider() {}

   virtual bool      Initialize() = 0;

   virtual ENUM_NEWS_STATE GetState(const string symbol,
                                    datetime current_time,
                                    NewsFeatures& news) = 0;

   virtual bool      IsUnavailable() const = 0;
  };

//+------------------------------------------------------------------+
//| Empty News Provider (fallback when no real source is available)   |
//+------------------------------------------------------------------+
class CNoOpNewsProvider : public INewsProvider
  {
public:
   bool              Initialize() override
     {
      return true;
     }

   ENUM_NEWS_STATE   GetState(const string symbol,
                            datetime current_time,
                            NewsFeatures& news) override
     {
      news.valid=true;
      news.state=NEWS_UNAVAILABLE;
      news.reason="No news provider configured";
      news.next_event_time=0;
      news.next_event_currency="";
      news.next_event_name="";
      news.next_event_impact=0;
      news.bar_time=current_time;
      news.symbol=symbol;
      return NEWS_UNAVAILABLE;
     }

   bool              IsUnavailable() const override
     {
      return true;
     }
  };

//+------------------------------------------------------------------+
//| Economic Calendar Event                                           |
//+------------------------------------------------------------------+
struct CalendarEvent
  {
   datetime          time;
   string            currency;
   string            name;
   int               impact;
   double            actual;
   double            forecast;
   double            previous;
   bool              has_actual;
   bool              has_forecast;
   bool              has_previous;

                     CalendarEvent()
     {
      time=0;
      currency="";
      name="";
      impact=0;
      actual=0;
      forecast=0;
      previous=0;
      has_actual=false;
      has_forecast=false;
      has_previous=false;
     }
  };

//+------------------------------------------------------------------+
//| News Risk Service                                                 |
//|                                                                  |
//| Manages news blackouts, cooldowns, and event risk.               |
//| Integrates with a news provider to determine event risk state.  |
//+------------------------------------------------------------------+
class CNewsRiskService
  {
private:
   INewsProvider*     m_provider;
   bool               m_own_provider;

   int                m_blackout_minutes_before;
   int                m_blackout_minutes_after;
   int                m_cooldown_minutes;
   int                m_high_impact_threshold;

   bool               m_prevent_new_entries;
   bool               m_close_positions_on_news;
   bool               m_enabled;

   datetime           m_last_event_time;

   string             m_last_currency;
   string             m_last_event_name;

   bool               m_initialized;

public:
                     CNewsRiskService()
     {
      m_provider=NULL;
      m_own_provider=false;
      m_blackout_minutes_before=30;
      m_blackout_minutes_after=30;
      m_cooldown_minutes=60;
      m_high_impact_threshold=3;
      m_prevent_new_entries=true;
      m_close_positions_on_news=false;
      m_enabled=true;
      m_last_event_time=0;

      m_last_currency="";
      m_last_event_name="";
      m_initialized=false;
     }

                    ~CNewsRiskService()
     {
      if(m_own_provider && m_provider!=NULL)
        {
         delete m_provider;
         m_provider=NULL;
        }
     }

   void              SetParameters(int blackout_before,
                      int blackout_after,
                      int cooldown,
                      int impact_threshold,
                      bool prevent_entries,
                      bool close_on_news)
     {
      m_blackout_minutes_before=blackout_before;
      m_blackout_minutes_after=blackout_after;
      m_cooldown_minutes=cooldown;
      m_high_impact_threshold=impact_threshold;
      m_prevent_new_entries=prevent_entries;
      m_close_positions_on_news=close_on_news;
     }

   bool              SetProvider(INewsProvider* provider, bool take_ownership=false)
     {
      if(m_own_provider && m_provider!=NULL)
        {
         delete m_provider;
        }

      m_provider=provider;
      m_own_provider=take_ownership;
      return m_provider != NULL;
     }

   void              SetEnabled(bool enabled)
     {
      m_enabled=enabled;
     }

   bool              Initialize(INewsProvider* provider=NULL)

     {
      if(provider!=NULL)
        {
         SetProvider(provider, true);
        }

      if(m_provider==NULL)
        {
         m_provider=new CNoOpNewsProvider();
         m_own_provider=true;
        }

      if(!m_provider.Initialize())
        {
         m_provider= new CNoOpNewsProvider();
         m_own_provider=true;
        }

      m_initialized=true;
      return true;
     }

   bool              IsSymbolAffected(const string symbol,
                         const string event_currency) const
     {
      if(symbol=="" || event_currency=="")
         return false;

      string base=StringSubstr(symbol, 0, 3);
      string quote=StringSubstr(symbol, 3, 3);

      string event_cur=event_currency;
      StringTrimLeft(event_cur);
      StringToUpper(event_cur);

      return (event_cur==base || event_cur==quote);
     }

   NewsFeatures      Evaluate(const string symbol,
                         datetime current_time,
                         const PortfolioState& portfolio_state)
     {
      NewsFeatures result;
      result.valid=true;
      result.state=NEWS_UNAVAILABLE;
      result.reason="Not yet evaluated";
      result.next_event_time=0;
      result.next_event_currency="";
      result.next_event_name="";
      result.next_event_impact=0;
      result.bar_time=current_time;
      result.symbol=symbol;
      result.reason_detail="";

      if(!m_enabled)
        {
         result.state=NEWS_DISABLED;
         result.reason="News risk disabled by configuration";
         return result;
        }


      if(m_provider.IsUnavailable())
        {
         result.state=NEWS_UNAVAILABLE;
         result.reason="News provider unavailable";
         result.reason_detail="News is enabled but no usable provider is available; entries must fail closed";
         return result;
        }

      NewsFeatures provider_news;
      ENUM_NEWS_STATE provider_state=
         m_provider.GetState(symbol, current_time, provider_news);

      result.state=provider_state;
      result.next_event_time=provider_news.next_event_time;
      result.next_event_currency=provider_news.next_event_currency;
      result.next_event_name=provider_news.next_event_name;
      result.next_event_impact=provider_news.next_event_impact;
      result.bar_time=current_time;
      result.symbol=symbol;

      if(provider_state==NEWS_UNAVAILABLE)
        {
         result.reason="News data unavailable; using safe policy";
         result.reason_detail="No news source configured; new entries during high-impact event windows are blocked";
         return result;
        }

      if(provider_state==NEWS_NO_EVENT_SCHEDULED)
        {
         result.reason="No events scheduled for this symbol";
         return result;
        }

      if(provider_state==NEWS_BLACKOUT_ACTIVE)
        {
         if(m_prevent_new_entries)
           {
            result.reason="In blackout window for high-impact news";
            result.reason_detail=
               "Event: "+provider_news.next_event_name+
               " at "+TimeToString(provider_news.next_event_time)+
               " currency: "+provider_news.next_event_currency;
           }
         else
           {
            result.reason="Event scheduled but new-entry blocking disabled";
           }
         return result;
        }

      if(provider_state==NEWS_COOLDOWN_ACTIVE)
        {
         result.reason="In cooldown after recent news event";
         return result;
        }

      if(provider_state==NEWS_EVENT_PASSED)
        {
         result.reason="Recent event has passed; in cooldown window";
         return result;
        }

      result.reason="News state evaluated: "+EnumToString(provider_state);
      return result;
     }

   bool ShouldBlockEntry(const NewsFeatures& news,
                        const string symbol) const
     {
      // Disabled means explicitly disabled by configuration. When enabled,
      // invalid or unavailable news data must not silently become NO NEWS.
      if(!m_enabled)
         return false;

      if(!news.valid ||
         news.state==NEWS_UNAVAILABLE ||
         news.state==NEWS_DISABLED)
         return true;

      if((news.state==NEWS_BLACKOUT_ACTIVE ||
          news.state==NEWS_COOLDOWN_ACTIVE ||
          news.state==NEWS_EVENT_PASSED) &&
         m_prevent_new_entries)
         return true;

      return false;
     }

   bool              ShouldClosePosition(const NewsFeatures& news,
                            const string symbol) const
     {
      if(!m_close_positions_on_news)
         return false;

      if(!news.valid)
         return false;

      if(news.state==NEWS_BLACKOUT_ACTIVE)
         return true;

      return false;
     }

   bool              IsUnavailable() const
     {
      return m_provider==NULL || m_provider.IsUnavailable();
     }
  };

#endif
//+------------------------------------------------------------------+