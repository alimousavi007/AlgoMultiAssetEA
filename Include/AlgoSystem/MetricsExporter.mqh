#ifndef __ALGOSYSTEM_METRICS_EXPORTER_MQH__
#define __ALGOSYSTEM_METRICS_EXPORTER_MQH__

#include "Interfaces.mqh"
#include "HybridTypes.mqh"
#include "Logger.mqh"

class CMetricsExporter
{
private:
   CAlgoLogger*        m_logger;
   string              m_metrics_dir;
   string              m_metrics_file;
   string              m_instance_id;
   int                 m_file_handle;
   datetime            m_last_write_time;
   int                 m_write_interval_seconds;
   
   // Metrics counters
   ulong               m_total_ticks_processed;
   ulong               m_total_signals_generated;
   ulong               m_total_signals_approved;
   ulong               m_total_signals_rejected;
   ulong               m_total_orders_submitted;
   ulong               m_total_orders_filled;
   ulong               m_total_orders_rejected;
   ulong               m_total_positions_open;
   ulong               m_total_positions_closed;
   ulong               m_total_errors;
   ulong               m_total_warnings;
   
   // Account metrics
   double              m_account_balance;
   double              m_account_equity;
   double              m_account_margin;
   double              m_account_free_margin;
   double              m_account_margin_level;
   
   // Portfolio metrics
   double              m_portfolio_exposure_pct;
   double              m_portfolio_unrealized_pnl;
   double              m_portfolio_realized_pnl;
   int                 m_portfolio_active_positions;
   int                 m_portfolio_pending_orders;
   
   // Risk metrics
   double              m_risk_daily_loss_pct;
   double              m_risk_drawdown_pct;
   double              m_risk_var_95;
   
   // Engine metrics
   double              m_engine_uptime_seconds;
   double              m_engine_avg_tick_latency_ms;
   int                 m_engine_active_symbols;
   
   // News metrics
   int                 m_news_events_pending;
   int                 m_news_blackout_active;
   
   bool InitializeFile()
   {
      if(m_file_handle != INVALID_HANDLE)
         return true;
      
      FolderCreate(m_metrics_dir);
      
      ResetLastError();
      m_file_handle = FileOpen(
         m_metrics_file,
         FILE_WRITE|FILE_TXT|FILE_ANSI,
         '\t');
      
if(m_file_handle == INVALID_HANDLE)
       {
          int err = GetLastError();
          if(m_logger)
             m_logger.Error("Metrics file open failed: " + m_metrics_file + " LastError=" + IntegerToString(err));
          ResetLastError();
          return false;
       }
      
      // Write Prometheus format header
      WriteHeader();
      return true;
   }
   
void WriteHeader()
    {
       if(m_file_handle == INVALID_HANDLE)
          return;
       
       // Truncate by seeking to start - MQL5 doesn't have FileTruncate
       FileSeek(m_file_handle, 0, SEEK_SET);
       
       FileWriteString(m_file_handle, "# HELP algo_ticks_processed_total Total number of ticks processed\n");
      FileWriteString(m_file_handle, "# TYPE algo_ticks_processed_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_signals_generated_total Total number of signals generated\n");
      FileWriteString(m_file_handle, "# TYPE algo_signals_generated_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_signals_approved_total Total number of signals approved by risk\n");
      FileWriteString(m_file_handle, "# TYPE algo_signals_approved_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_signals_rejected_total Total number of signals rejected by risk\n");
      FileWriteString(m_file_handle, "# TYPE algo_signals_rejected_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_orders_submitted_total Total number of orders submitted\n");
      FileWriteString(m_file_handle, "# TYPE algo_orders_submitted_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_orders_filled_total Total number of orders filled\n");
      FileWriteString(m_file_handle, "# TYPE algo_orders_filled_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_orders_rejected_total Total number of orders rejected\n");
      FileWriteString(m_file_handle, "# TYPE algo_orders_rejected_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_positions_open_total Total number of positions opened\n");
      FileWriteString(m_file_handle, "# TYPE algo_positions_open_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_positions_closed_total Total number of positions closed\n");
      FileWriteString(m_file_handle, "# TYPE algo_positions_closed_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_errors_total Total number of errors\n");
      FileWriteString(m_file_handle, "# TYPE algo_errors_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_warnings_total Total number of warnings\n");
      FileWriteString(m_file_handle, "# TYPE algo_warnings_total counter\n");
      FileWriteString(m_file_handle, "# HELP algo_account_balance Account balance\n");
      FileWriteString(m_file_handle, "# TYPE algo_account_balance gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_account_equity Account equity\n");
      FileWriteString(m_file_handle, "# TYPE algo_account_equity gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_account_margin Used margin\n");
      FileWriteString(m_file_handle, "# TYPE algo_account_margin gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_account_free_margin Free margin\n");
      FileWriteString(m_file_handle, "# TYPE algo_account_free_margin gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_account_margin_level Margin level percentage\n");
      FileWriteString(m_file_handle, "# TYPE algo_account_margin_level gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_portfolio_exposure_pct Portfolio exposure as percentage of equity\n");
      FileWriteString(m_file_handle, "# TYPE algo_portfolio_exposure_pct gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_portfolio_unrealized_pnl Unrealized P&L\n");
      FileWriteString(m_file_handle, "# TYPE algo_portfolio_unrealized_pnl gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_portfolio_realized_pnl Realized P&L\n");
      FileWriteString(m_file_handle, "# TYPE algo_portfolio_realized_pnl gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_portfolio_active_positions Number of active positions\n");
      FileWriteString(m_file_handle, "# TYPE algo_portfolio_active_positions gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_portfolio_pending_orders Number of pending orders\n");
      FileWriteString(m_file_handle, "# TYPE algo_portfolio_pending_orders gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_risk_daily_loss_pct Daily loss as percentage of equity\n");
      FileWriteString(m_file_handle, "# TYPE algo_risk_daily_loss_pct gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_risk_drawdown_pct Current drawdown percentage\n");
      FileWriteString(m_file_handle, "# TYPE algo_risk_drawdown_pct gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_risk_var_95 Value at Risk 95%\n");
      FileWriteString(m_file_handle, "# TYPE algo_risk_var_95 gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_engine_uptime_seconds Engine uptime in seconds\n");
      FileWriteString(m_file_handle, "# TYPE algo_engine_uptime_seconds gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_engine_avg_tick_latency_ms Average tick processing latency in ms\n");
      FileWriteString(m_file_handle, "# TYPE algo_engine_avg_tick_latency_ms gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_engine_active_symbols Number of active symbols being monitored\n");
      FileWriteString(m_file_handle, "# TYPE algo_engine_active_symbols gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_news_events_pending Number of pending news events\n");
      FileWriteString(m_file_handle, "# TYPE algo_news_events_pending gauge\n");
      FileWriteString(m_file_handle, "# HELP algo_news_blackout_active Whether news blackout is active (1=yes, 0=no)\n");
      FileWriteString(m_file_handle, "# TYPE algo_news_blackout_active gauge\n");
      
      FileFlush(m_file_handle);
   }
   
void WriteMetrics()
    {
       if(m_file_handle == INVALID_HANDLE)
          return;
       
       string instance_label = (m_instance_id != "") ? "{instance=\"" + m_instance_id + "\"}" : "";
       
       FileSeek(m_file_handle, 0, SEEK_SET);
       WriteHeader();
      
      FileWriteString(m_file_handle, "algo_ticks_processed_total" + instance_label + " " + IntegerToString(m_total_ticks_processed) + "\n");
      FileWriteString(m_file_handle, "algo_signals_generated_total" + instance_label + " " + IntegerToString(m_total_signals_generated) + "\n");
      FileWriteString(m_file_handle, "algo_signals_approved_total" + instance_label + " " + IntegerToString(m_total_signals_approved) + "\n");
      FileWriteString(m_file_handle, "algo_signals_rejected_total" + instance_label + " " + IntegerToString(m_total_signals_rejected) + "\n");
      FileWriteString(m_file_handle, "algo_orders_submitted_total" + instance_label + " " + IntegerToString(m_total_orders_submitted) + "\n");
      FileWriteString(m_file_handle, "algo_orders_filled_total" + instance_label + " " + IntegerToString(m_total_orders_filled) + "\n");
      FileWriteString(m_file_handle, "algo_orders_rejected_total" + instance_label + " " + IntegerToString(m_total_orders_rejected) + "\n");
      FileWriteString(m_file_handle, "algo_positions_open_total" + instance_label + " " + IntegerToString(m_total_positions_open) + "\n");
      FileWriteString(m_file_handle, "algo_positions_closed_total" + instance_label + " " + IntegerToString(m_total_positions_closed) + "\n");
      FileWriteString(m_file_handle, "algo_errors_total" + instance_label + " " + IntegerToString(m_total_errors) + "\n");
      FileWriteString(m_file_handle, "algo_warnings_total" + instance_label + " " + IntegerToString(m_total_warnings) + "\n");
      FileWriteString(m_file_handle, "algo_account_balance" + instance_label + " " + DoubleToString(m_account_balance, 2) + "\n");
      FileWriteString(m_file_handle, "algo_account_equity" + instance_label + " " + DoubleToString(m_account_equity, 2) + "\n");
      FileWriteString(m_file_handle, "algo_account_margin" + instance_label + " " + DoubleToString(m_account_margin, 2) + "\n");
      FileWriteString(m_file_handle, "algo_account_free_margin" + instance_label + " " + DoubleToString(m_account_free_margin, 2) + "\n");
      FileWriteString(m_file_handle, "algo_account_margin_level" + instance_label + " " + DoubleToString(m_account_margin_level, 2) + "\n");
      FileWriteString(m_file_handle, "algo_portfolio_exposure_pct" + instance_label + " " + DoubleToString(m_portfolio_exposure_pct, 2) + "\n");
      FileWriteString(m_file_handle, "algo_portfolio_unrealized_pnl" + instance_label + " " + DoubleToString(m_portfolio_unrealized_pnl, 2) + "\n");
      FileWriteString(m_file_handle, "algo_portfolio_realized_pnl" + instance_label + " " + DoubleToString(m_portfolio_realized_pnl, 2) + "\n");
      FileWriteString(m_file_handle, "algo_portfolio_active_positions" + instance_label + " " + IntegerToString(m_portfolio_active_positions) + "\n");
      FileWriteString(m_file_handle, "algo_portfolio_pending_orders" + instance_label + " " + IntegerToString(m_portfolio_pending_orders) + "\n");
      FileWriteString(m_file_handle, "algo_risk_daily_loss_pct" + instance_label + " " + DoubleToString(m_risk_daily_loss_pct, 4) + "\n");
      FileWriteString(m_file_handle, "algo_risk_drawdown_pct" + instance_label + " " + DoubleToString(m_risk_drawdown_pct, 4) + "\n");
      FileWriteString(m_file_handle, "algo_risk_var_95" + instance_label + " " + DoubleToString(m_risk_var_95, 2) + "\n");
      FileWriteString(m_file_handle, "algo_engine_uptime_seconds" + instance_label + " " + DoubleToString(m_engine_uptime_seconds, 0) + "\n");
      FileWriteString(m_file_handle, "algo_engine_avg_tick_latency_ms" + instance_label + " " + DoubleToString(m_engine_avg_tick_latency_ms, 2) + "\n");
      FileWriteString(m_file_handle, "algo_engine_active_symbols" + instance_label + " " + IntegerToString(m_engine_active_symbols) + "\n");
      FileWriteString(m_file_handle, "algo_news_events_pending" + instance_label + " " + IntegerToString(m_news_events_pending) + "\n");
      FileWriteString(m_file_handle, "algo_news_blackout_active" + instance_label + " " + IntegerToString(m_news_blackout_active) + "\n");
      
      FileFlush(m_file_handle);
   }

public:
   CMetricsExporter() : m_logger(NULL), m_metrics_dir("AlgoSystem/Metrics"), m_instance_id(""), 
                        m_file_handle(INVALID_HANDLE), m_last_write_time(0), m_write_interval_seconds(10),
                        m_total_ticks_processed(0), m_total_signals_generated(0), m_total_signals_approved(0),
                        m_total_signals_rejected(0), m_total_orders_submitted(0), m_total_orders_filled(0),
                        m_total_orders_rejected(0), m_total_positions_open(0), m_total_positions_closed(0),
                        m_total_errors(0), m_total_warnings(0),
                        m_account_balance(0), m_account_equity(0), m_account_margin(0), m_account_free_margin(0),
                        m_account_margin_level(0),
                        m_portfolio_exposure_pct(0), m_portfolio_unrealized_pnl(0), m_portfolio_realized_pnl(0),
                        m_portfolio_active_positions(0), m_portfolio_pending_orders(0),
                        m_risk_daily_loss_pct(0), m_risk_drawdown_pct(0), m_risk_var_95(0),
                        m_engine_uptime_seconds(0), m_engine_avg_tick_latency_ms(0), m_engine_active_symbols(0),
                        m_news_events_pending(0), m_news_blackout_active(0) {}
   
   ~CMetricsExporter()
   {
      if(m_file_handle != INVALID_HANDLE)
      {
         FileClose(m_file_handle);
         m_file_handle = INVALID_HANDLE;
      }
   }
   
   void Initialize(CAlgoLogger* logger, const string instance_id = "", const int write_interval_seconds = 10)
   {
      m_logger = logger;
      m_instance_id = instance_id;
      m_write_interval_seconds = write_interval_seconds;
      m_metrics_file = m_metrics_dir + "/metrics" + (m_instance_id != "" ? "_" + m_instance_id : "") + ".prom";
      InitializeFile();
   }
   
   void SetLogger(CAlgoLogger* logger) { m_logger = logger; }
   
   // Counter increments
   void IncrementTicksProcessed() { m_total_ticks_processed++; }
   void IncrementSignalsGenerated() { m_total_signals_generated++; }
   void IncrementSignalsApproved() { m_total_signals_approved++; }
   void IncrementSignalsRejected() { m_total_signals_rejected++; }
   void IncrementOrdersSubmitted() { m_total_orders_submitted++; }
   void IncrementOrdersFilled() { m_total_orders_filled++; }
   void IncrementOrdersRejected() { m_total_orders_rejected++; }
   void IncrementPositionsOpen() { m_total_positions_open++; }
   void IncrementPositionsClosed() { m_total_positions_closed++; }
   void IncrementErrors() { m_total_errors++; }
   void IncrementWarnings() { m_total_warnings++; }
   
   // Gauge setters
   void SetAccountMetrics(double balance, double equity, double margin, double free_margin, double margin_level)
   {
      m_account_balance = balance;
      m_account_equity = equity;
      m_account_margin = margin;
      m_account_free_margin = free_margin;
      m_account_margin_level = margin_level;
   }
   
   void SetPortfolioMetrics(double exposure_pct, double unrealized_pnl, double realized_pnl, 
                           int active_positions, int pending_orders)
   {
      m_portfolio_exposure_pct = exposure_pct;
      m_portfolio_unrealized_pnl = unrealized_pnl;
      m_portfolio_realized_pnl = realized_pnl;
      m_portfolio_active_positions = active_positions;
      m_portfolio_pending_orders = pending_orders;
   }
   
   void SetRiskMetrics(double daily_loss_pct, double drawdown_pct, double var_95)
   {
      m_risk_daily_loss_pct = daily_loss_pct;
      m_risk_drawdown_pct = drawdown_pct;
      m_risk_var_95 = var_95;
   }
   
   void SetEngineMetrics(double uptime_seconds, double avg_tick_latency_ms, int active_symbols)
   {
      m_engine_uptime_seconds = uptime_seconds;
      m_engine_avg_tick_latency_ms = avg_tick_latency_ms;
      m_engine_active_symbols = active_symbols;
   }
   
   void SetNewsMetrics(int events_pending, int blackout_active)
   {
      m_news_events_pending = events_pending;
      m_news_blackout_active = blackout_active;
   }
   
   // Periodic flush
   void OnTimer()
   {
      if(TimeCurrent() - m_last_write_time >= m_write_interval_seconds)
      {
         WriteMetrics();
         m_last_write_time = TimeCurrent();
      }
   }
   
   void ForceFlush()
   {
      WriteMetrics();
      m_last_write_time = TimeCurrent();
   }
   
   string GetMetricsFilePath() const { return m_metrics_file; }
   bool IsInitialized() const { return m_file_handle != INVALID_HANDLE; }
};

// Alert system
enum ENUM_ALERT_SEVERITY
{
   ALERT_INFO = 0,
   ALERT_WARNING = 1,
   ALERT_CRITICAL = 2
};

struct AlertRecord
{
   datetime       timestamp;
   ENUM_ALERT_SEVERITY severity;
   string         category;
   string         message;
   string         symbol;
   double         value;       // Associated numeric value (e.g., drawdown %, margin level)
   double         threshold;   // Threshold that triggered the alert
   bool           acknowledged;
};

class CAlertManager
{
private:
   CAlgoLogger*        m_logger;
   CMetricsExporter*   m_metrics;
   AlertRecord         m_alerts[256];
   int                 m_alert_count;
   int                 m_max_alerts;
   
   // Alert thresholds
   double              m_margin_level_critical;
   double              m_margin_level_warning;
   double              m_daily_loss_critical;
   double              m_daily_loss_warning;
   double              m_drawdown_critical;
   double              m_drawdown_warning;
   double              m_spread_warning_multiplier;
   int                 m_max_positions_warning;
   int                 m_max_positions_critical;
   
   // Cooldown tracking
   datetime            m_last_alert_time[10]; // Per category cooldown
   int                 m_alert_cooldown_seconds;
   
   int CategoryToIndex(const string category)
   {
      if(category == "MARGIN") return 0;
      if(category == "DAILY_LOSS") return 1;
      if(category == "DRAWDOWN") return 2;
      if(category == "SPREAD") return 3;
      if(category == "POSITIONS") return 4;
      if(category == "NEWS") return 5;
      if(category == "EXECUTION") return 6;
      if(category == "CONNECTION") return 7;
      if(category == "RISK") return 8;
      return 9; // GENERAL
   }
   
   bool IsInCooldown(const string category)
   {
      int idx = CategoryToIndex(category);
      if(idx >= 0 && idx < 10)
      {
         return (TimeCurrent() - m_last_alert_time[idx] < m_alert_cooldown_seconds);
      }
      return false;
   }
   
   void UpdateCooldown(const string category)
   {
      int idx = CategoryToIndex(category);
      if(idx >= 0 && idx < 10)
         m_last_alert_time[idx] = TimeCurrent();
   }
   
void LogAlert(const AlertRecord& alert)
    {
       if(!m_logger)
          return;
       
       ENUM_LOG_LEVEL level = LOG_INFO;
       if(alert.severity == ALERT_WARNING)
          level = LOG_WARNING;
       else if(alert.severity == ALERT_CRITICAL)
          level = LOG_ERROR;
       
m_logger.Event(level, "ALERT", "ALERT_RAISED", alert.symbol, "", "", "", 
                      "", alert.category + ": " + alert.message, 
                      0, 0, 
                      (double)alert.value, (double)alert.threshold, 0.0);
    }
   
   void ShowOnChart(const AlertRecord& alert)
   {
      string prefix = "";
      color clr = clrWhite;
      
      switch(alert.severity)
      {
         case ALERT_INFO:
            prefix = "[INFO] ";
            clr = clrDodgerBlue;
            break;
         case ALERT_WARNING:
            prefix = "[WARN] ";
            clr = clrOrange;
            break;
         case ALERT_CRITICAL:
            prefix = "[CRIT] ";
            clr = clrRed;
            break;
      }
      
      string msg = prefix + alert.category + ": " + alert.message;
      Comment(msg);
      
      // Also use Alert() for popup/sound if critical
      if(alert.severity == ALERT_CRITICAL)
      {
         Alert(msg);
      }
   }

public:
   CAlertManager() : m_logger(NULL), m_metrics(NULL), m_alert_count(0), m_max_alerts(256),
                     m_margin_level_critical(150), m_margin_level_warning(200),
                     m_daily_loss_critical(5.0), m_daily_loss_warning(3.0),
                     m_drawdown_critical(10.0), m_drawdown_warning(5.0),
                     m_spread_warning_multiplier(3.0), m_max_positions_warning(8), m_max_positions_critical(10),
                     m_alert_cooldown_seconds(60) {}
   
   ~CAlertManager() {}
   
   void Initialize(CAlgoLogger* logger, CMetricsExporter* metrics = NULL)
   {
      m_logger = logger;
      m_metrics = metrics;
      
      for(int i = 0; i < 10; i++)
         m_last_alert_time[i] = 0;
   }
   
   void SetThresholds(double margin_crit, double margin_warn, double daily_loss_crit, double daily_loss_warn,
                      double dd_crit, double dd_warn, double spread_mult, int pos_warn, int pos_crit, int cooldown_sec)
   {
      m_margin_level_critical = margin_crit;
      m_margin_level_warning = margin_warn;
      m_daily_loss_critical = daily_loss_crit;
      m_daily_loss_warning = daily_loss_warn;
      m_drawdown_critical = dd_crit;
      m_drawdown_warning = dd_warn;
      m_spread_warning_multiplier = spread_mult;
      m_max_positions_warning = pos_warn;
      m_max_positions_critical = pos_crit;
      m_alert_cooldown_seconds = cooldown_sec;
   }
   
   void RaiseAlert(ENUM_ALERT_SEVERITY severity, const string category, const string message, 
                   const string symbol = "", double value = 0, double threshold = 0)
   {
      if(IsInCooldown(category))
         return;
      
      if(m_alert_count >= m_max_alerts)
      {
         // Shift alerts left, drop oldest
         for(int i = 1; i < m_max_alerts; i++)
            m_alerts[i-1] = m_alerts[i];
         m_alert_count--;
      }
      
      AlertRecord alert;
      alert.timestamp = TimeCurrent();
      alert.severity = severity;
      alert.category = category;
      alert.message = message;
      alert.symbol = symbol;
      alert.value = value;
      alert.threshold = threshold;
      alert.acknowledged = false;
      
      m_alerts[m_alert_count] = alert;
      m_alert_count++;
      
      UpdateCooldown(category);
      LogAlert(alert);
      ShowOnChart(alert);
      
      // Update metrics if available
      if(m_metrics)
         m_metrics.IncrementWarnings(); // Use warnings counter for alerts too
   }
   
   // Convenience methods for common alerts
   void CheckMarginLevel(double margin_level)
   {
      if(margin_level <= 0)
         return;
      
      if(margin_level <= m_margin_level_critical)
         RaiseAlert(ALERT_CRITICAL, "MARGIN", "Margin level critical: " + DoubleToString(margin_level, 1) + "%", 
                    "", margin_level, m_margin_level_critical);
      else if(margin_level <= m_margin_level_warning)
         RaiseAlert(ALERT_WARNING, "MARGIN", "Margin level low: " + DoubleToString(margin_level, 1) + "%", 
                    "", margin_level, m_margin_level_warning);
   }
   
   void CheckDailyLoss(double daily_loss_pct)
   {
      if(daily_loss_pct >= m_daily_loss_critical)
         RaiseAlert(ALERT_CRITICAL, "DAILY_LOSS", "Daily loss limit exceeded: " + DoubleToString(daily_loss_pct, 2) + "%", 
                    "", daily_loss_pct, m_daily_loss_critical);
      else if(daily_loss_pct >= m_daily_loss_warning)
         RaiseAlert(ALERT_WARNING, "DAILY_LOSS", "Daily loss warning: " + DoubleToString(daily_loss_pct, 2) + "%", 
                    "", daily_loss_pct, m_daily_loss_warning);
   }
   
   void CheckDrawdown(double drawdown_pct)
   {
      if(drawdown_pct >= m_drawdown_critical)
         RaiseAlert(ALERT_CRITICAL, "DRAWDOWN", "Drawdown critical: " + DoubleToString(drawdown_pct, 2) + "%", 
                    "", drawdown_pct, m_drawdown_critical);
      else if(drawdown_pct >= m_drawdown_warning)
         RaiseAlert(ALERT_WARNING, "DRAWDOWN", "Drawdown warning: " + DoubleToString(drawdown_pct, 2) + "%", 
                    "", drawdown_pct, m_drawdown_warning);
   }
   
   void CheckSpread(const string symbol, double spread_points, double normal_spread_points)
   {
      if(normal_spread_points <= 0)
         return;
      
      double ratio = spread_points / normal_spread_points;
      if(ratio >= m_spread_warning_multiplier)
      {
         RaiseAlert(ALERT_WARNING, "SPREAD", "Spread widened: " + DoubleToString(ratio, 1) + "x normal", 
                    symbol, spread_points, normal_spread_points * m_spread_warning_multiplier);
      }
   }
   
   void CheckPositionCount(int active_positions)
   {
      if(active_positions >= m_max_positions_critical)
         RaiseAlert(ALERT_CRITICAL, "POSITIONS", "Maximum positions reached: " + IntegerToString(active_positions), 
                    "", active_positions, m_max_positions_critical);
      else if(active_positions >= m_max_positions_warning)
         RaiseAlert(ALERT_WARNING, "POSITIONS", "Position count high: " + IntegerToString(active_positions), 
                    "", active_positions, m_max_positions_warning);
   }
   
   void CheckNewsBlackout(bool is_blackout)
   {
      if(is_blackout)
         RaiseAlert(ALERT_WARNING, "NEWS", "News blackout active - new entries blocked", "", 1, 1);
   }
   
   void CheckExecutionFailure(const string symbol, const string reason)
   {
      RaiseAlert(ALERT_CRITICAL, "EXECUTION", "Execution failed: " + reason, symbol, 0, 0);
   }
   
   void CheckConnectionLost()
   {
      RaiseAlert(ALERT_CRITICAL, "CONNECTION", "Terminal connection lost", "", 0, 0);
   }
   
   // Getters
   int GetAlertCount() const { return m_alert_count; }
   AlertRecord GetAlert(int index) const { return (index >= 0 && index < m_alert_count) ? m_alerts[index] : AlertRecord(); }
   
   void AcknowledgeAlert(int index)
   {
      if(index >= 0 && index < m_alert_count)
         m_alerts[index].acknowledged = true;
   }
   
   void ClearAcknowledged()
   {
      int write_idx = 0;
      for(int i = 0; i < m_alert_count; i++)
      {
         if(!m_alerts[i].acknowledged)
         {
            if(write_idx != i)
               m_alerts[write_idx] = m_alerts[i];
            write_idx++;
         }
      }
      m_alert_count = write_idx;
   }
   
   void ClearAll()
   {
      m_alert_count = 0;
   }
};

#endif