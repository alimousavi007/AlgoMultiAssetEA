//+------------------------------------------------------------------+
//|                                                DashboardDiag.mqh |
//|                        AlgoMultiAssetEA Dashboard Diagnostics    |
//|                                                                  |
//| Provides structured diagnostics collection for Dashboard,        |
//| Snapshot transport, Configuration, and Runtime verification.     |
//|                                                                  |
//| Usage:                                                           |
//|   #include <AlgoSystem/DashboardDiag.mqh>                        |
//|   CDashboardDiag g_diag;                                         |
//|   g_diag.Initialize();                                           |
//|   g_diag.LogSnapshotWrite(...);                                  |
//|   g_diag.LogSnapshotRead(...);                                   |
//|   g_diag.LogDashboardApply(...);                                 |
//|   g_diag.GenerateReport();                                       |
//+------------------------------------------------------------------+
#property copyright "AlgoMultiAssetEA"
#property link      ""
#property version   "1.00"
#property strict

#include <AlgoSystem/Logger.mqh>

//--- Diagnostics mode enum
enum ENUM_DIAG_MODE
  {
   DIAG_MODE_OFF = 0,
   DIAG_MODE_MINIMAL = 1,    // Only transitions and errors
   DIAG_MODE_FULL = 2        // All events including periodic state
  };

//--- Run info struct (shared with EA)
struct DiagRunInfo
  {
   string       run_id;
   string       source_sha256;
   string       ex5_sha256;
   int          terminal_build;
   string       ea_version;
   int          runtime_mode;       // 0=Live, 1=Tester, 2=Visual, 3=Optimization
   long         chart_id;
   string       chart_symbol;
   string       strategy_group_key;
   string       config_fingerprint;
   int          coordinator_mode;
   int          authority_epoch;
   int          runtime_count;
  };

//+------------------------------------------------------------------+
//| Class CDashboardDiag                                             |
//+------------------------------------------------------------------+
class CDashboardDiag
  {
private:
   CAlgoLogger*  m_logger;
   int           m_handle;
   string        m_file_path;
   string        m_run_id;
   ENUM_DIAG_MODE m_mode;
   bool          m_initialized;
   datetime      m_start_time;

   // Simple counters for stats
   int           m_write_count;
   int           m_read_count;
   int           m_apply_count;
   int           m_config_count;
   int           m_runtime_count;

   // File management
   bool OpenFile();
   void CloseFile();
   void WriteJsonValue(const string key, const string value, bool is_last=false);
   void WriteJsonValue(const string key, int value, bool is_last=false);
   void WriteJsonValue(const string key, bool value, bool is_last=false);
   void WriteJsonValue(const string key, datetime value, bool is_last=false);
   void WriteArrayStart(const string name);
   void WriteArrayEnd();

public:
   CDashboardDiag();
   ~CDashboardDiag();

bool Initialize(CAlgoLogger* logger, ENUM_DIAG_MODE mode = DIAG_MODE_FULL);
   void SetRunInfo(const DiagRunInfo& info);

    // Snapshot transport diagnostics - simplified with primitive parameters
   void LogSnapshotWrite(const string symbol, int generation, bool success,
                         const string error_details = "",
                         const string gv_keys_written = "",
                         const string gv_keys_failed = "",
                         int key_length_max = 0);
   void LogSnapshotRead(const string symbol, bool success, int generation_read,
                        datetime snapshot_time, const string error_reason = "");
   void LogDashboardApply(const string symbol, bool success,
                          const string current_stage = "",
                          const string regime_text = "",
                          const string bias_text = "",
                          const string long_text = "",
                          const string short_text = "",
                          bool snapshot_valid = false,
                          int generation = 0);

   // Configuration diagnostics
   void LogConfig(const string input_name, const string input_value,
                  const string effective_value, bool mismatch);

   // Runtime state diagnostics
   void LogRuntimeState(const string symbol, int runtime_index, bool valid,
                        int generation,
                        datetime last_process_time,
                        datetime last_data_time,
                        datetime last_feature_time,
                        datetime last_evaluation_time,
                        datetime last_snapshot_time,
                        int current_stage,
                        int regime_code,
                        int bias_code,
                        int long_code,
                        int short_code);

   // Report generation
   bool GenerateReport();
   string GetReportPath() const { return m_file_path; }

   // Utility
   static string GenerateRunId();
   static string GetTimestampISO();
  };

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CDashboardDiag::CDashboardDiag()
  {
   m_logger = NULL;
   m_handle = INVALID_HANDLE;
   m_file_path = "";
   m_run_id = "";
   m_mode = DIAG_MODE_OFF;
   m_initialized = false;
   m_start_time = 0;
   m_write_count = 0;
   m_read_count = 0;
   m_apply_count = 0;
   m_config_count = 0;
   m_runtime_count = 0;
  }

CDashboardDiag::~CDashboardDiag()
  {
   CloseFile();
  }

bool CDashboardDiag::Initialize(CAlgoLogger* logger, ENUM_DIAG_MODE mode)
  {
   if(m_initialized)
     {
      return true;
     }

   m_logger = logger;
   m_mode = mode;
   m_start_time = TimeCurrent();
   m_run_id = GenerateRunId();

   // Build file path: <MQL5>/Files/AlgoMultiAssetEA/diag_<run_id>.json
   string folder = "AlgoMultiAssetEA";
   string filename = "diag_" + m_run_id + ".json";
   m_file_path = folder + "\\" + filename;

   // Create folder if needed
   if(!FileIsExist(folder + "\\dummy", FILE_COMMON))
     {
      int h = FileOpen(folder + "\\dummy", FILE_WRITE | FILE_TXT | FILE_ANSI, FILE_COMMON);
      if(h != INVALID_HANDLE) FileClose(h);
      FileDelete(folder + "\\dummy", FILE_COMMON);
     }

   if(!OpenFile())
     {
      if(m_logger) m_logger.Event(LOG_ERROR, "DIAG", "INIT_FAILED", "", "", "", "", "FAIL", "FILE_OPEN", "Cannot open diagnostics file");
      return false;
     }

   WriteJsonValue("run_id", m_run_id);
   WriteJsonValue("start_time", GetTimestampISO());
   WriteJsonValue("mode", (int)mode, true);
   m_initialized = true;

   if(m_logger) m_logger.Event(LOG_INFO, "DIAG", "INITIALIZED", "", "", "", "", "OK", "INIT", "RunId=" + m_run_id + " Mode=" + IntegerToString((int)mode));
   return true;
  }

void CDashboardDiag::SetRunInfo(const DiagRunInfo& info)
  {
   // Store run info for later report generation
   // Could write to file immediately or buffer for later
   if(m_logger)
     {
      m_logger.Event(LOG_INFO, "DIAG", "RUN_INFO_SET", "", "", "", "", "OK", "RUN_INFO",
                     "RunId=" + info.run_id + " Build=" + IntegerToString(info.terminal_build) +
                     " Mode=" + IntegerToString(info.runtime_mode) + " Symbol=" + info.chart_symbol);
     }
  }

bool CDashboardDiag::OpenFile()
  {
   m_handle = FileOpen(m_file_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(m_handle == INVALID_HANDLE)
     {
      int err = GetLastError();
      ResetLastError();
      return false;
     }
   return true;
  }

void CDashboardDiag::CloseFile()
  {
   if(m_handle != INVALID_HANDLE)
     {
      FileClose(m_handle);
      m_handle = INVALID_HANDLE;
     }
  }

void CDashboardDiag::WriteJsonValue(const string key, const string value, bool is_last)
  {
   if(m_handle == INVALID_HANDLE) return;
   string line = "  \"" + key + "\": \"" + value + "\"";
   if(!is_last) line += ",";
   FileWriteString(m_handle, line + "\n");
  }

void CDashboardDiag::WriteJsonValue(const string key, int value, bool is_last)
  {
   if(m_handle == INVALID_HANDLE) return;
   string line = "  \"" + key + "\": " + IntegerToString(value);
   if(!is_last) line += ",";
   FileWriteString(m_handle, line + "\n");
  }

void CDashboardDiag::WriteJsonValue(const string key, bool value, bool is_last)
  {
   if(m_handle == INVALID_HANDLE) return;
   string line = "  \"" + key + "\": " + (value ? "true" : "false");
   if(!is_last) line += ",";
   FileWriteString(m_handle, line + "\n");
  }

void CDashboardDiag::WriteJsonValue(const string key, datetime value, bool is_last)
  {
   if(m_handle == INVALID_HANDLE) return;
   string line = "  \"" + key + "\": \"" + TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\"";
   if(!is_last) line += ",";
   FileWriteString(m_handle, line + "\n");
  }

void CDashboardDiag::WriteArrayStart(const string name)
  {
   if(m_handle == INVALID_HANDLE) return;
   FileWriteString(m_handle, "  \"" + name + "\": [\n");
  }

void CDashboardDiag::WriteArrayEnd()
  {
   if(m_handle == INVALID_HANDLE) return;
   FileWriteString(m_handle, "  ]\n");
  }

void CDashboardDiag::LogSnapshotWrite(const string symbol, int generation, bool success,
                                      const string error_details,
                                      const string gv_keys_written,
                                      const string gv_keys_failed,
                                      int key_length_max)
  {
   if(m_mode == DIAG_MODE_OFF) return;

   // Also log to logger
   if(m_logger)
     {
      string status = success ? "OK" : "FAIL";
      m_logger.Event(LOG_INFO, "DIAG", "SNAPSHOT_WRITE", symbol, "", "", "", status, "GV_WRITE",
                     "Gen=" + IntegerToString(generation) + " KeyLen=" + IntegerToString(key_length_max) +
                     (gv_keys_written != "" ? " Written=" + gv_keys_written : "") +
                     (gv_keys_failed != "" ? " Failed=" + gv_keys_failed : "") +
                     (error_details != "" ? " Err=" + error_details : ""));
     }
   m_write_count++;
  }

void CDashboardDiag::LogSnapshotRead(const string symbol, bool success, int generation_read,
                                     datetime snapshot_time, const string error_reason)
  {
   if(m_mode == DIAG_MODE_OFF) return;

   if(m_logger)
     {
string status = success ? "OK" : "FAIL";
       int age = (snapshot_time > 0) ? (int)(TimeCurrent() - snapshot_time) : 0;
      m_logger.Event(LOG_INFO, "DIAG", "SNAPSHOT_READ", symbol, "", "", "", status, "GV_READ",
                     "Gen=" + IntegerToString(generation_read) + " Age=" + IntegerToString(age) + "s" +
                     (error_reason != "" ? " Err=" + error_reason : ""));
     }
   m_read_count++;
  }

void CDashboardDiag::LogDashboardApply(const string symbol, bool success,
                                       const string current_stage,
                                       const string regime_text,
                                       const string bias_text,
                                       const string long_text,
                                       const string short_text,
                                       bool snapshot_valid,
                                       int generation)
  {
   if(m_mode == DIAG_MODE_OFF) return;

   if(m_logger)
     {
      string status = success ? "OK" : "FAIL";
      m_logger.Event(LOG_INFO, "DIAG", "DASHBOARD_APPLY", symbol, "", "", "", status, "RENDER",
                     "Stage=" + current_stage + " Regime=" + regime_text + " Bias=" + bias_text +
                     " Long=" + long_text + " Short=" + short_text + " Valid=" + (snapshot_valid ? "true" : "false") +
                     " Gen=" + IntegerToString(generation));
     }
   m_apply_count++;
  }

void CDashboardDiag::LogConfig(const string input_name, const string input_value,
                               const string effective_value, bool mismatch)
  {
   if(m_mode == DIAG_MODE_OFF) return;

   if(m_logger && mismatch)
     {
      m_logger.Event(LOG_WARNING, "DIAG", "CONFIG_MISMATCH", "", "", "", "", "WARN", "CONFIG",
                     input_name + ": Input='" + input_value + "' Effective='" + effective_value + "'");
     }
   m_config_count++;
  }

void CDashboardDiag::LogRuntimeState(const string symbol, int runtime_index, bool valid,
                                     int generation,
                                     datetime last_process_time,
                                     datetime last_data_time,
                                     datetime last_feature_time,
                                     datetime last_evaluation_time,
                                     datetime last_snapshot_time,
                                     int current_stage,
                                     int regime_code,
                                     int bias_code,
                                     int long_code,
                                     int short_code)
  {
   if(m_mode == DIAG_MODE_OFF) return;
   m_runtime_count++;
  }

bool CDashboardDiag::GenerateReport()
  {
   if(!m_initialized || m_handle == INVALID_HANDLE)
     {
      return false;
     }

   // Write summary stats
   WriteJsonValue("snapshot_writes_count", m_write_count);
   WriteJsonValue("snapshot_reads_count", m_read_count);
   WriteJsonValue("dashboard_applies_count", m_apply_count);
   WriteJsonValue("config_checks_count", m_config_count);
   WriteJsonValue("runtime_states_count", m_runtime_count);

   FileWriteString(m_handle, "}\n");
   FileFlush(m_handle);
   CloseFile();

   if(m_logger)
     {
      m_logger.Event(LOG_INFO, "DIAG", "REPORT_GENERATED", "", "", "", "", "OK", "REPORT",
                     "Path=" + m_file_path);
     }

   return true;
  }

string CDashboardDiag::GenerateRunId()
  {
   string id = "DIAG_";
   id += TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   StringReplace(id, ".", "");
   StringReplace(id, ":", "");
   StringReplace(id, " ", "_");
   // Add random suffix
   id += "_" + IntegerToString((int)(MathRand() % 10000), 4, '0');
   return id;
  }

string CDashboardDiag::GetTimestampISO()
  {
   return TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }