#ifndef __ALGOSYSTEM_SESSIONFILTER_MQH__
#define __ALGOSYSTEM_SESSIONFILTER_MQH__

class CSessionFilter
  {
private:
   bool m_enabled;
   int  m_start_hour;
   int  m_end_hour;

public:
   CSessionFilter()
     {
      m_enabled=true;
      m_start_hour=0;
      m_end_hour=24;
     }

   bool Set(const bool enabled,
            const int start_hour,
            const int end_hour)
     {
      if(start_hour<0 || start_hour>23)
         return false;
   
      if(end_hour<0 || end_hour>24)
         return false;
   
      m_enabled=enabled;
      m_start_hour=start_hour;
      m_end_hour=end_hour;
   
      return true;
     }

   bool IsAllowed(const datetime when) const
     {
      if(!m_enabled)
         return true;

      MqlDateTime dt;
      TimeToStruct(when,dt);

      if(m_start_hour==m_end_hour)
         return true;

      if(m_start_hour< m_end_hour)
         return dt.hour>=m_start_hour && dt.hour<m_end_hour;

      return dt.hour>=m_start_hour || dt.hour<m_end_hour;
     }
  };

#endif
