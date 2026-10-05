#ifndef __ALGOSYSTEM_TYPES_MQH__
#define __ALGOSYSTEM_TYPES_MQH__

#include "Constants.mqh"

struct SymbolProperties
  {
   string symbol;

   int    digits;
   double point;

   double tick_size;
   double tick_value;
   double tick_value_profit;
   double tick_value_loss;

   double volume_min;
   double volume_max;
   double volume_step;

   int    stops_level;
   int    freeze_level;

   bool   trade_allowed;
   bool   selected;
  };

struct BarData
  {
   datetime time;

   double open;
   double high;
   double low;
   double close;

   long tick_volume;
   long real_volume;

   int spread;
  };

struct MarketSnapshot
  {
   string symbol;

   ENUM_TIMEFRAMES timeframe;

   datetime current_time;
   datetime closed_bar_time;

   double bid;
   double ask;
   double spread_points;

   BarData current_bar;
   BarData closed_bar;

   SymbolProperties properties;

   bool valid;
  };

struct FeatureSet
  {
   string symbol;

   ENUM_TIMEFRAMES timeframe;

   datetime bar_time;

   double ema_fast;
   double ema_slow;
   double ema_long;

   double adx;
   double atr;
   double rsi;
   double roc;

   double macd_main;
   double macd_signal;

   double volume_ratio;

   double candle_body;
   double candle_range;
   double candle_strength;

   double volatility;

   bool valid;
  };

struct StrategySignal
  {
   bool valid;

   ENUM_SIGNAL_DIRECTION direction;
   ENUM_STRATEGY_ID strategy;

   string symbol;

   ENUM_TIMEFRAMES timeframe;

   ENUM_REGIME_TYPE regime;

   double score;
   double confidence;

   double entry;
   double stop;
   double target;

   datetime timestamp;

   string signal_id;
   string reason;
  };

struct RiskDecision
  {
   ENUM_RISK_DECISION_TYPE decision;

   ENUM_REJECTION_REASON rejection_reason;

   string symbol;

   double risk_percent;
   double risk_amount;

   double stop_distance;
   double calculated_volume;

   double portfolio_risk_after;

   string reason;
  };

struct ExecutionRequest
  {
   ENUM_ORDER_INTENT intent;

   string symbol;

   ENUM_SIGNAL_DIRECTION direction;

   ENUM_STRATEGY_ID strategy;

   double volume;
   double price;

   double stop_loss;
   double take_profit;

   ulong position_ticket;

   ulong magic;

   string comment;

   string signal_id;
  };

struct ExecutionResult
  {
   bool success;

   uint retcode;

   ulong order_ticket;
   ulong deal_ticket;
   ulong position_ticket;

   double executed_price;
   double executed_volume;

   string message;
  };

struct PositionState
  {
   ulong ticket;

   string symbol;

   ENUM_POSITION_TYPE type;

   double volume;
   double open_price;

   double stop_loss;
   double take_profit;

   double profit;

   long magic;

   datetime open_time;

   string comment;
  };

struct PortfolioState
  {
   double equity;
   double balance;

   double daily_start_equity;
   double monthly_start_equity;

   double daily_loss_percent;
   double monthly_loss_percent;

   double total_open_risk_percent;

   int total_positions;

   int consecutive_losses;

   bool daily_lock;
   bool monthly_lock;
   bool trading_locked;
  };

struct StrategyContext
  {
   MarketSnapshot market;
   FeatureSet features;

   ENUM_REGIME_TYPE regime;

   bool trading_allowed;

   string rejection_reason;
  };

#endif