#ifndef __ALGOSYSTEM_LOGGER_MQH__
#define __ALGOSYSTEM_LOGGER_MQH__

#include "Interfaces.mqh"

class CAlgoLogger : public ILogger
  {
private:
   ENUM_LOG_LEVEL m_min_level;
   bool           m_console_enabled;
   bool           m_file_enabled;
   bool           m_flush_each_write;
   int            m_file_handle;
   int            m_human_file_handle;
   string         m_file_name;
   string         m_human_file_name;
   string         m_run_id;
   string         m_file_day;
   int            m_summary_interval_seconds;
   datetime       m_last_summary_time;

   ulong m_events_total;
   ulong m_errors_total;
   ulong m_warnings_total;
   ulong m_init_failures;
   ulong m_market_failures;
   ulong m_feature_failures;
   ulong m_regime_events;
   ulong m_strategy_batches;
   ulong m_signals;
   ulong m_risk_approvals;
   ulong m_risk_rejections;
   ulong m_portfolio_rejections;
   ulong m_execution_attempts;
   ulong m_execution_failures;
   ulong m_execution_successes;
   ulong m_state_failures;

   string CurrentDay() const
     {
      return TimeToString(TimeCurrent(),TIME_DATE);
     }

   string NewRunId() const
     {
      return TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS)+
             "-"+
             IntegerToString((int)GetTickCount());
     }

   bool ShouldLog(const ENUM_LOG_LEVEL level) const
     {
      // Enum ordering is ERROR -> ... -> OPTIMIZATION.
      // A configured level includes all more-severe levels.
      return ((int)level <= (int)m_min_level);
     }

   string RejectionName(const ENUM_REJECTION_REASON reason) const
     {
      switch(reason)
        {
         case REJECT_NONE: return "NONE";
         case REJECT_INVALID_SIGNAL: return "INVALID_SIGNAL";
         case REJECT_UNCERTAIN_REGIME: return "UNCERTAIN_REGIME";
         case REJECT_SESSION: return "SESSION";
         case REJECT_SPREAD: return "SPREAD";
         case REJECT_DAILY_LOSS: return "DAILY_LOSS";
         case REJECT_MONTHLY_LOSS: return "MONTHLY_LOSS";
         case REJECT_CONSECUTIVE_LOSSES: return "CONSECUTIVE_LOSSES";
         case REJECT_POSITION_LIMIT: return "POSITION_LIMIT";
         case REJECT_PORTFOLIO_RISK: return "PORTFOLIO_RISK";
         case REJECT_CORRELATION: return "CORRELATION";
         case REJECT_INVALID_STOP: return "INVALID_STOP";
         case REJECT_INVALID_TARGET: return "INVALID_TARGET";
         case REJECT_LOW_RR: return "LOW_RR";
         case REJECT_INVALID_VOLUME: return "INVALID_VOLUME";
         case REJECT_MARGIN: return "MARGIN";
         case REJECT_EXECUTION: return "EXECUTION";
         case REJECT_DUPLICATE_SIGNAL: return "DUPLICATE_SIGNAL";
        }
      return "UNKNOWN";
     }

   string LevelName(const ENUM_LOG_LEVEL level) const
     {
      switch(level)
        {
         case LOG_ERROR:       return "ERROR";
         case LOG_WARNING:     return "WARNING";
         case LOG_INFO:        return "INFO";
         case LOG_SIGNAL:      return "SIGNAL";
         case LOG_TRADE:       return "TRADE";
         case LOG_RISK:        return "RISK";
         case LOG_DEBUG:       return "DEBUG";
         case LOG_OPTIMIZATION:return "OPTIMIZATION";
        }
      return "UNKNOWN";
     }

   void ResetCounters()
     {
      m_events_total=0;
      m_errors_total=0;
      m_warnings_total=0;
      m_init_failures=0;
      m_market_failures=0;
      m_feature_failures=0;
      m_regime_events=0;
      m_strategy_batches=0;
      m_signals=0;
      m_risk_approvals=0;
      m_risk_rejections=0;
      m_portfolio_rejections=0;
      m_execution_attempts=0;
      m_execution_failures=0;
      m_execution_successes=0;
      m_state_failures=0;
     }

   void UpdateCounters(const ENUM_LOG_LEVEL level,
                       const string phase,
                       const string event,
                       const string result)
     {
      m_events_total++;

      if(level==LOG_ERROR)
         m_errors_total++;
      else if(level==LOG_WARNING)
         m_warnings_total++;

      if(phase=="INIT" && result=="FAIL")
         m_init_failures++;

      if(phase=="MARKET" && result=="FAIL")
         m_market_failures++;

      if(phase=="FEATURE" && result=="FAIL")
         m_feature_failures++;

      if(phase=="REGIME")
         m_regime_events++;

      if(phase=="STRATEGY")
         m_strategy_batches++;

      if(event=="SIGNAL_GENERATED")
         m_signals++;

      if(phase=="RISK")
        {
         if(result=="OK")
            m_risk_approvals++;
         else if(result=="REJECT")
            m_risk_rejections++;
        }

      if(phase=="PORTFOLIO" && result=="REJECT")
         m_portfolio_rejections++;

      if(phase=="EXECUTION")
        {
         if(event=="EXECUTION_SUBMITTED")
            m_execution_attempts++;

         if(result=="FAIL")
            m_execution_failures++;

         if(result=="OK")
            m_execution_successes++;
        }

      if(phase=="STATE" && result=="FAIL")
         m_state_failures++;
     }

   string PadLevel(const ENUM_LOG_LEVEL level) const
     {
      string name=LevelName(level);
      while(StringLen(name)<5)
         name+=" ";
      return name;
     }

   string HumanLine(const ENUM_LOG_LEVEL level,
                    const string phase,
                    const string event,
                    const string symbol,
                    const string timeframe,
                    const string strategy,
                    const string signal_id,
                    const string result,
                    const string reason_code,
                    const string reason,
                    const int last_error,
                    const uint trade_retcode,
                    const double value1,
                    const double value2,
                    const double value3) const
     {
      string line=
         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
         " | "+PadLevel(level)+
         " | "+phase+
         " | "+event;

      if(symbol!="")
         line+=" | symbol="+symbol;

      if(timeframe!="")
         line+=" | tf="+timeframe;

      if(strategy!="")
         line+=" | strategy="+strategy;

      if(signal_id!="")
         line+=" | signal="+signal_id;

      if(result!="")
         line+=" | result="+result;

      if(reason_code!="")
         line+=" | reason="+reason_code;

      if(reason!="")
         line+=" | detail="+reason;

      if(last_error!=0)
         line+=" | LastError="+IntegerToString(last_error);

      if(trade_retcode!=0)
         line+=" | Retcode="+IntegerToString((int)trade_retcode);

      if(value1!=0.0 || value2!=0.0 || value3!=0.0)
         line+=
            " | values=["+
            DoubleToString(value1,5)+","+
            DoubleToString(value2,5)+","+
            DoubleToString(value3,5)+"]";

      return line;
     }

   void WriteHumanFile(const string line)
     {
      if(m_human_file_handle==INVALID_HANDLE)
         return;

      FileSeek(m_human_file_handle,0,SEEK_END);
      FileWriteString(m_human_file_handle,line+"\r\n");

      if(m_flush_each_write)
         FileFlush(m_human_file_handle);
     }

   bool EnsureDailyFile()
     {
      if(!m_file_enabled)
         return false;

      if(MQLInfoInteger(MQL_OPTIMIZATION))
         return false;

      string day=CurrentDay();

      if(m_file_handle!=INVALID_HANDLE &&
         m_human_file_handle!=INVALID_HANDLE &&
         m_file_day==day)
         return true;

      if(m_file_handle!=INVALID_HANDLE)
        {
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }

      if(m_human_file_handle!=INVALID_HANDLE)
        {
         FileClose(m_human_file_handle);
         m_human_file_handle=INVALID_HANDLE;
        }

      FolderCreate("AlgoSystem");
      FolderCreate("AlgoSystem/Logs");

      m_file_name=
         "AlgoSystem/Logs/AlgoSystem_"+
         day+
         ".csv";

      m_human_file_name=
         "AlgoSystem/Logs/AlgoSystem_Human_"+
         day+
         ".log";

      ResetLastError();
      m_file_handle=FileOpen(
         m_file_name,
         FILE_READ|FILE_WRITE|FILE_CSV|
         FILE_SHARE_READ|FILE_SHARE_WRITE,
         ';');

      if(m_file_handle==INVALID_HANDLE)
        {
         int err=GetLastError();
         Print("[ALGO][LOGGER][ERROR] Structured log open failed path=",
               m_file_name," LastError=",IntegerToString(err));
         ResetLastError();
         return false;
        }

      ResetLastError();
      m_human_file_handle=FileOpen(
         m_human_file_name,
         FILE_READ|FILE_WRITE|FILE_TXT|
         FILE_SHARE_READ|FILE_SHARE_WRITE,
         '\\t');

      if(m_human_file_handle==INVALID_HANDLE)
        {
         int err=GetLastError();
         Print("[ALGO][LOGGER][ERROR] Human log open failed path=",
               m_human_file_name," LastError=",IntegerToString(err));
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
         ResetLastError();
         return false;
        }

      m_file_day=day;

      FileSeek(m_file_handle,0,SEEK_END);
      if(FileTell(m_file_handle)==0)
        {
         FileWrite(
            m_file_handle,
            "ServerTime","LocalTime","RunID","Level","Phase",
            "Event","Symbol","Timeframe","Strategy","SignalID",
            "Result","ReasonCode","Reason","LastError","TradeRetcode",
            "Value1","Value2","Value3");
        }

      FileSeek(m_human_file_handle,0,SEEK_END);
      if(FileTell(m_human_file_handle)==0)
        {
         FileWriteString(
            m_human_file_handle,
            "==============================================================\r\n");
         FileWriteString(
            m_human_file_handle,
            "AlgoMultiAssetEA - HUMAN DEBUG LOG\r\n");
         FileWriteString(
            m_human_file_handle,
            "RunID: "+m_run_id+"\r\n");
         FileWriteString(
            m_human_file_handle,
            "Date: "+day+"\r\n");
         FileWriteString(
            m_human_file_handle,
            "==============================================================\r\n");
      }

      if(m_flush_each_write)
        {
         FileFlush(m_file_handle);
         FileFlush(m_human_file_handle);
        }

      return true;
     }

   void WriteEventFile(const ENUM_LOG_LEVEL level,
                       const string phase,
                       const string event,
                       const string symbol,
                       const string timeframe,
                       const string strategy,
                       const string signal_id,
                       const string result,
                       const string reason_code,
                       const string reason,
                       const int last_error,
                       const uint trade_retcode,
                       const double value1,
                       const double value2,
                       const double value3)
     {
      if(!EnsureDailyFile())
         return;

      FileSeek(m_file_handle,0,SEEK_END);

      FileWrite(
         m_file_handle,
         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
         TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
         m_run_id,
         LevelName(level),
         phase,
         event,
         symbol,
         timeframe,
         strategy,
         signal_id,
         result,
         reason_code,
         reason,
         last_error,
         trade_retcode,
         value1,
         value2,
         value3);

      if(m_flush_each_write)
         FileFlush(m_file_handle);
     }

public:
   CAlgoLogger()
     {
      m_min_level=LOG_INFO;
      m_console_enabled=true;
      m_file_enabled=false;
      m_flush_each_write=true;
      m_file_handle=INVALID_HANDLE;
      m_human_file_handle=INVALID_HANDLE;
      m_file_name="";
      m_human_file_name="";
      m_run_id="";
      m_file_day="";
      m_summary_interval_seconds=60;
      m_last_summary_time=0;
      ResetCounters();
     }

   ~CAlgoLogger()
     {
      Shutdown();
     }

   void StartRun()
     {
      m_run_id=NewRunId();
      ResetCounters();
      m_last_summary_time=TimeCurrent();
     }

   void SetMinimumLevel(const ENUM_LOG_LEVEL level)
     {
      m_min_level=level;
     }

   void SetSummaryInterval(const int seconds)
     {
      m_summary_interval_seconds=
         MathMax(5,seconds);
     }

   void SetFlushEachWrite(const bool enabled)
     {
      m_flush_each_write=enabled;
     }

   bool EnableConsole(const bool enabled)
     {
      m_console_enabled=enabled;
      return true;
     }

   bool EnableFile(const bool enabled,
                   const string filename="")
     {
      if(!enabled)
        {
         m_file_enabled=false;

         if(m_file_handle!=INVALID_HANDLE)
           {
            FileClose(m_file_handle);
            m_file_handle=INVALID_HANDLE;
           }

         if(m_human_file_handle!=INVALID_HANDLE)
           {
            FileClose(m_human_file_handle);
            m_human_file_handle=INVALID_HANDLE;
           }

         return true;
        }

      // Avoid shared file writes from optimization agents.
      if(MQLInfoInteger(MQL_OPTIMIZATION))
        {
         m_file_enabled=false;
         Print("[ALGO][LOGGER][WARNING] File logging disabled during optimization");
         return false;
        }

      // filename is kept for compatibility, but daily rotation is controlled
      // by the logger and stored under AlgoSystem/Logs.
      if(filename!="")
         m_file_name=filename;

      m_file_enabled=true;
      m_file_day="";

      return EnsureDailyFile();
     }

   string RunId() const
     {
      return m_run_id;
     }

   void Shutdown()
     {
      if(m_file_handle!=INVALID_HANDLE)
        {
         FileClose(m_file_handle);
         m_file_handle=INVALID_HANDLE;
        }

      if(m_human_file_handle!=INVALID_HANDLE)
        {
         FileClose(m_human_file_handle);
         m_human_file_handle=INVALID_HANDLE;
        }

      m_file_enabled=false;
     }

   bool Event(const ENUM_LOG_LEVEL level,
              const string phase,
              const string event,
              const string symbol="",
              const string timeframe="",
              const string strategy="",
              const string signal_id="",
              const string result="",
              const string reason_code="",
              const string reason="",
              const int last_error=0,
              const uint trade_retcode=0,
              const double value1=0.0,
              const double value2=0.0,
              const double value3=0.0)
     {
      UpdateCounters(level,phase,event,result);

      bool visible=ShouldLog(level);

      // Errors are always visible in the console even if the configured
      // level is more restrictive. This prevents critical failures from
      // disappearing during diagnosis.
      if(level==LOG_ERROR)
         visible=true;

      if(visible && m_console_enabled &&
         !MQLInfoInteger(MQL_OPTIMIZATION))
        {
         string text=
            "[ALGO]["+LevelName(level)+"] "+
            "phase="+phase+
            " event="+event;

         if(symbol!="")
            text+=" symbol="+symbol;

         if(result!="")
            text+=" result="+result;

         if(reason_code!="")
            text+=" reason_code="+reason_code;

         if(reason!="")
            text+=" reason="+reason;

         if(last_error!=0)
            text+=" LastError="+IntegerToString(last_error);

         if(trade_retcode!=0)
            text+=" Retcode="+IntegerToString((int)trade_retcode);

         Print(text);
        }

      // File logging is independent from console level. Critical errors are
      // always persisted; other events honor the configured level.
      if(m_file_enabled &&
         (ShouldLog(level) || level==LOG_ERROR))
        {
         WriteEventFile(
            level,phase,event,symbol,timeframe,strategy,signal_id,
            result,reason_code,reason,last_error,trade_retcode,
            value1,value2,value3);

         if(m_human_file_handle!=INVALID_HANDLE)
           {
            WriteHumanFile(
               HumanLine(level,phase,event,symbol,timeframe,strategy,signal_id,
                         result,reason_code,reason,last_error,trade_retcode,
                         value1,value2,value3));
           }
        }

      return true;
     }

   void MaybeWriteSummary(const bool force=false)
     {
      if(!m_file_enabled && !m_console_enabled)
         return;

      datetime now=TimeCurrent();

      if(!force &&
         (now-m_last_summary_time)<m_summary_interval_seconds)
         return;

      m_last_summary_time=now;

      string reason=
         "events="+IntegerToString((int)m_events_total)+
         " errors="+IntegerToString((int)m_errors_total)+
         " warnings="+IntegerToString((int)m_warnings_total)+
         " init_fail="+IntegerToString((int)m_init_failures)+
         " market_fail="+IntegerToString((int)m_market_failures)+
         " feature_fail="+IntegerToString((int)m_feature_failures)+
         " regime="+IntegerToString((int)m_regime_events)+
         " strategy_batches="+IntegerToString((int)m_strategy_batches)+
         " signals="+IntegerToString((int)m_signals)+
         " risk_ok="+IntegerToString((int)m_risk_approvals)+
         " risk_reject="+IntegerToString((int)m_risk_rejections)+
         " portfolio_reject="+IntegerToString((int)m_portfolio_rejections)+
         " exec_attempt="+IntegerToString((int)m_execution_attempts)+
         " exec_fail="+IntegerToString((int)m_execution_failures)+
         " exec_ok="+IntegerToString((int)m_execution_successes)+
         " state_fail="+IntegerToString((int)m_state_failures);

      Event(
         LOG_INFO,
         "SYSTEM",
         "RUNTIME_SUMMARY",
         "",
         "",
         "",
         "",
         "INFO",
         "SUMMARY",
         reason);
     }

   virtual void Log(ENUM_LOG_LEVEL level,
                    const string message) override
     {
      Event(level,"SYSTEM","MESSAGE","","","","","INFO","",message);
     }

   virtual void Error(const string message) override
     {
      Event(LOG_ERROR,"SYSTEM","SYSTEM_ERROR","","","","","FAIL","SYSTEM_ERROR",message,GetLastError());
     }

   virtual void Warning(const string message) override
     {
      Event(LOG_WARNING,"SYSTEM","SYSTEM_WARNING","","","","","WARN","WARNING",message);
     }

   virtual void Info(const string message) override
     {
      Event(LOG_INFO,"SYSTEM","SYSTEM_INFO","","","","","INFO","",message);
     }

   virtual void Signal(const StrategySignal &signal) override
     {
      Event(
         LOG_SIGNAL,
         "SIGNAL",
         "SIGNAL_GENERATED",
         signal.symbol,
         EnumToString(signal.timeframe),
         EnumToString(signal.strategy),
         signal.signal_id,
         "OK",
         "SIGNAL_VALID",
         signal.reason,
         0,
         0,
         signal.score,
         signal.confidence,
         signal.entry);
     }

   virtual void Risk(const RiskDecision &decision) override
     {
      string result=
         decision.decision==RISK_APPROVED ? "OK" : "REJECT";

      Event(
         LOG_RISK,
         "RISK",
         decision.decision==RISK_APPROVED ?
            "RISK_APPROVED" : "RISK_REJECTED",
         decision.symbol,
         "",
         "",
         "",
         result,
         RejectionName(decision.rejection_reason),
         decision.reason,
         0,
         0,
         decision.risk_percent,
         decision.stop_distance,
         decision.calculated_volume);
     }

   virtual void Trade(const ExecutionResult &result) override
     {
      Event(
         result.success ? LOG_TRADE : LOG_ERROR,
         "EXECUTION",
         result.success ? "EXECUTION_SUCCESS" : "EXECUTION_FAILED",
         "",
         "",
         "",
         "",
         result.success ? "OK" : "FAIL",
         "EXECUTION",
         result.message,
         0,
         result.retcode,
         result.executed_price,
         result.executed_volume,
         (double)result.order_ticket);
     }
  };

#endif
