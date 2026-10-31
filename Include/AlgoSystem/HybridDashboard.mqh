#ifndef __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__
#define __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__

#include "HybridTypes.mqh"

//+------------------------------------------------------------------+
//| Compact Glass-Inspired Dashboard                                 |
//|                                                                  |
//| Displays hybrid engine state: style, regime, bias, profile      |
//| levels, liquidity state, divergence, momentum, news, scores,    |
//| decision, and rejection reasons.                                |
//+------------------------------------------------------------------+
class CHybridDashboard
  {
 private:
    bool               m_enabled;
    bool               m_compact_view;
    bool               m_show_diagnostics;
    bool               m_show_overlay;

    long               m_chart_id;
    string             m_bg_name;
    string             m_title;

    int                m_label_count;
    string             m_label_names[40];

    datetime           m_last_update_time;
    string             m_last_display_symbol;
    ENUM_TRADING_STYLE m_last_style;

    string             m_status_text;
    string             m_decision_text;
    string             m_rejection_text;

    struct colorRef
      {
       uchar r, g, b;
      };

    colorRef m_color_green;
    colorRef m_color_red;
    colorRef m_color_amber;
    colorRef m_color_grey;
    colorRef m_color_silver;
    colorRef m_color_lime;

public:
    CHybridDashboard()
      {
       m_enabled=true;
       m_compact_view=true;
       m_show_diagnostics=false;
       m_show_overlay=true;
       m_chart_id=0;
       m_bg_name="";
       m_title="ALGO HYBRID";
       m_label_count=40;
       m_last_update_time=0;
       m_last_display_symbol="";
       m_last_style=STYLE_DAY_TRADING;
       m_status_text="INITIALIZING";
       m_decision_text="";
       m_rejection_text="";

       m_color_green.r=100;  m_color_green.g=220;   m_color_green.b=100;
       m_color_red.r=220;    m_color_red.g=100;     m_color_red.b=100;
       m_color_amber.r=255;  m_color_amber.g=190;   m_color_amber.b=60;
       m_color_grey.r=140;   m_color_grey.g=140;    m_color_grey.b=140;
       m_color_silver.r=200; m_color_silver.g=200;  m_color_silver.b=200;
       m_color_lime.r=173;   m_color_lime.g=255;    m_color_lime.b=47;
      }

   void Enable(bool enabled)
     {
      m_enabled=enabled;
      if(!enabled)
         Clear();
     }

   void SetCompactView(bool compact) { m_compact_view=compact; }
   void ShowDiagnostics(bool show) { m_show_diagnostics=show; }
   void ShowOverlay(bool show) { m_show_overlay=show; }
   void SetTitle(const string title) { m_title=title; }

   void Clear()
     {
      long chart_id=(m_chart_id!=0 ? m_chart_id : ChartID());

      if(m_bg_name!="")
        {
         ObjectDelete(chart_id, m_bg_name);

         for(int i=0; i<m_label_count; i++)
            ObjectDelete(chart_id, m_label_names[i]);
        }

      m_bg_name="";
      m_chart_id=0;
     }

private:
   string LabelName(const int index) const
     {
      return m_bg_name + "_lbl_" + IntegerToString(index);
     }

   string StyleText(ENUM_TRADING_STYLE style) const
     {
      switch(style)
        {
         case STYLE_SCALPING:      return "SCALP";
         case STYLE_DAY_TRADING:   return "DAY";
         case STYLE_SWING_TRADING: return "SWING";
         default: return "UNKNOWN";
        }
     }

   string RegimeText(ENUM_HYBRID_REGIME regime) const
     {
      switch(regime)
        {
         case HYBRID_REGIME_TRENDING:                return "TREND";
         case HYBRID_REGIME_RANGING:                 return "RANGE";
         case HYBRID_REGIME_VOLATILITY_EXPANSION:    return "VOL_EXP";
         case HYBRID_REGIME_COMPRESSION:             return "COMPRESS";
         case HYBRID_REGIME_TRANSITION:              return "TRANSITION";
         case HYBRID_REGIME_INSUFFICIENT_DATA:       return "N/A";
         default: return "?";
        }
     }

   string BiasText(ENUM_BIAS_DIRECTION bias) const
     {
      switch(bias)
        {
         case BIAS_BULLISH:               return "BULL";
         case BIAS_BEARISH:               return "BEAR";
         case BIAS_NEUTRAL:               return "NEUTRAL";
         case BIAS_CONFLICTED:            return "CONFLICT";
         case BIAS_INSUFFICIENT_DATA:     return "N/A";
         default: return "?";
        }
     }

   string NewsText(ENUM_NEWS_STATE state) const
     {
      switch(state)
        {
         case NEWS_UNAVAILABLE:           return "N/A";
         case NEWS_NO_EVENT_SCHEDULED:     return "CLEAR";
         case NEWS_BLACKOUT_ACTIVE:        return "BLACKOUT";
         case NEWS_COOLDOWN_ACTIVE:        return "COOLDOWN";
         case NEWS_EVENT_PASSED:           return "PAST";
         default: return "?";
        }
     }

   string DecisionText(ENUM_DECISION_STATUS status) const
     {
      switch(status)
        {
         case DECISION_BUY_CANDIDATE:       return "BUY";
         case DECISION_SELL_CANDIDATE:      return "SELL";
         case DECISION_NO_TRADE:            return "NO-TRADE";
         case DECISION_DATA_UNAVAILABLE:    return "NO-DATA";
         case DECISION_NEWS_BLOCKED:        return "NEWS-BLOCKED";
         case DECISION_RISK_REJECTED:       return "RISK-REJECT";
         case DECISION_CONFLICTED_SIGNAL:   return "CONFLICT";
         case DECISION_SETUP_EXPIRED:       return "EXPIRED";
         case DECISION_SETUP_INVALIDATED:   return "INVALIDATED";
         default: return "?";
        }
     }

   string ColorForStatus(ENUM_DECISION_STATUS status) const
     {
      switch(status)
        {
         case DECISION_BUY_CANDIDATE:       return "GREEN";
         case DECISION_SELL_CANDIDATE:      return "RED";
         case DECISION_NO_TRADE:            return "GREY";
         case DECISION_DATA_UNAVAILABLE:   return "GREY";
         case DECISION_NEWS_BLOCKED:        return "AMBER";
         case DECISION_RISK_REJECTED:       return "AMBER";
         case DECISION_CONFLICTED_SIGNAL:   return "AMBER";
         case DECISION_SETUP_EXPIRED:       return "GREY";
         case DECISION_SETUP_INVALIDATED:   return "GREY";
         default: return "GREY";
        }
     }

   string FormatScore(double score) const
     {
      return DoubleToString(score, 1);
     }

   void CreateObjects()
     {
      if(ObjectFind(m_chart_id, m_bg_name) >= 0)
         ObjectDelete(m_chart_id, m_bg_name);

      if(!ObjectCreate(m_chart_id, m_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return;

      int width = m_compact_view ? 220 : 280;
      int height = 180;

      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XDISTANCE, 230);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YSIZE, height);
       ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
       ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_COLOR, clrDimGray);
       ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_HIDDEN, true);

      for(int i=0; i<m_label_count; i++)
        {
         m_label_names[i] = LabelName(i);

         if(ObjectFind(m_chart_id, m_label_names[i]) >= 0)
            ObjectDelete(m_chart_id, m_label_names[i]);

         if(!ObjectCreate(m_chart_id, m_label_names[i], OBJ_LABEL, 0, 0, 0))
            continue;

         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
          ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_FONTSIZE, 7);
          ObjectSetString(m_chart_id, m_label_names[i], OBJPROP_FONT, "Consolas");
         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_SELECTED, false);
         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_ZORDER, 1);
        }
     }

   void PositionLabel(const int index, int x, int y)
     {
      if(index < 0 || index >= m_label_count)
         return;

      ObjectSetInteger(m_chart_id, m_label_names[index], OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, m_label_names[index], OBJPROP_YDISTANCE, y);
     }

    color ColorFromString(const string color_str) const
      {
       string normalized = color_str;
       StringTrimLeft(normalized);
       StringTrimRight(normalized);
       StringToUpper(normalized);

       if(normalized == "GREEN")
          return clrLimeGreen;
       else if(normalized == "RED")
          return clrSalmon;
       else if(normalized == "AMBER")
          return clrOrange;
       else if(normalized == "GREY")
          return clrGray;
       else if(normalized == "LIME")
          return clrLime;
       else if(normalized == "SILVER")
          return clrSilver;

       return clrWhite;
      }

      void SetLabelText(const int index, const string text, const string col)
        {
         if(index < 0 || index >= m_label_count)
            return;

         ObjectSetString(m_chart_id, m_label_names[index], OBJPROP_TEXT, text);
         long clr = (long)ColorFromString(col);
         ObjectSetInteger(m_chart_id, m_label_names[index], OBJPROP_COLOR, clr);
        }

    string ShortReason(const string reason) const
      {
       if(StringLen(reason) <= 24)
          return reason;
       return StringSubstr(reason, 0, 21) + "...";
      }

public:
   void ShowStatus(const string status)
     {
      if(!m_enabled)
         return;

      m_status_text = status;
     }

   void Update(const HybridDecision& decision,
               const PortfolioState& portfolio_state)
     {
      if(!m_enabled)
         return;

      long chart_id = ChartID();
      string chart_symbol = ChartSymbol(0);

      if(chart_symbol != "" && decision.symbol != chart_symbol)
          return;

       if(m_chart_id != chart_id || m_bg_name == "")
         {
          m_chart_id = chart_id;
          m_bg_name = "AlgoHybridDashboard_BG_" + IntegerToString((int)chart_id);
         }

       if(TimeCurrent() - m_last_update_time < 3)
         return;

      if(decision.style != m_last_style)
        {
         m_last_style = decision.style;
         Clear();
        }

      CreateObjects();

      int x_col1 = 10;
      int x_col2 = 120;
      int y_start = 20;
      int y_step = 14;

      int row = 0;
      SetLabelText(0, m_title, "SILVER");
      PositionLabel(0, x_col1, y_start);

      SetLabelText(1, "SYMBOL: " + decision.symbol, "SILVER");
      PositionLabel(1, x_col1, y_start + y_step * (++row));

      SetLabelText(2, "STYLE: " + StyleText(decision.style),
                   decision.style == m_last_style ? "LIME" : "SILVER");
      PositionLabel(2, x_col1, y_start + y_step * (++row));

      SetLabelText(3, "REGIME: " + RegimeText(decision.regime), "SILVER");
      PositionLabel(3, x_col1, y_start + y_step * (++row));

      SetLabelText(4, "BIAS: " + BiasText(decision.bias),
                   decision.bias == BIAS_BULLISH ? "GREEN" :
                   decision.bias == BIAS_BEARISH ? "RED" : "SILVER");
      PositionLabel(4, x_col1, y_start + y_step * (++row));

      row = 0;
      SetLabelText(5, "LONG: " + FormatScore(decision.long_score),
                   decision.long_score >= 70 ? "GREEN" : "SILVER");
      PositionLabel(5, x_col2, y_start + y_step * row);

      SetLabelText(6, "SHORT: " + FormatScore(decision.short_score),
                   decision.short_score >= 70 ? "RED" : "SILVER");
      PositionLabel(6, x_col2, y_start + y_step * (++row));

      row = 2;
      SetLabelText(7, "DECISION: " + DecisionText(decision.status),
                   ColorForStatus(decision.status));
      PositionLabel(7, x_col2, y_start + y_step * row);

      if(decision.status == DECISION_BUY_CANDIDATE ||
         decision.status == DECISION_SELL_CANDIDATE)
        {
         if(decision.plan.valid)
           {
            SetLabelText(8, "ENTRY: " + DoubleToString(decision.plan.entry, (int)decision.context.setup_market.properties.digits), "LIME");
            PositionLabel(8, x_col2, y_start + y_step * (++row));

            SetLabelText(9, "SL: " + DoubleToString(decision.plan.stop, (int)decision.context.setup_market.properties.digits), "AMBER");
            PositionLabel(9, x_col2, y_start + y_step * (++row));

            SetLabelText(10, "TP: " + DoubleToString(decision.plan.target, (int)decision.context.setup_market.properties.digits), "AMBER");
            PositionLabel(10, x_col2, y_start + y_step * (++row));

            SetLabelText(11, "RR: " + DoubleToString(decision.plan.reward_to_risk, 2), "SILVER");
            PositionLabel(11, x_col2, y_start + y_step * (++row));
           }
        }
      else if(decision.status != DECISION_NO_TRADE)
        {
         SetLabelText(8, "REJECT: " + ShortReason(decision.main_reason),
                      ColorForStatus(decision.status));
         PositionLabel(8, x_col2, y_start + y_step * row);
        }
      else
        {
         SetLabelText(8, "REASON: " + ShortReason(decision.main_reason), "GREY");
         PositionLabel(8, x_col2, y_start + y_step * row);
        }

      row = 6;
      string news_str = "NEWS: " + NewsText(decision.context.news.state);
      SetLabelText(12, news_str,
                   decision.context.news.state == NEWS_BLACKOUT_ACTIVE ? "RED" :
                   decision.context.news.state == NEWS_UNAVAILABLE ? "GREY" : "SILVER");
      PositionLabel(12, x_col1, y_start + y_step * row);

      row = 7;
      string profile_str = "POC: " +
         (decision.context.profile.valid ?
            DoubleToString(decision.context.profile.poc, (int)decision.context.setup_market.properties.digits) : "N/A");
      SetLabelText(13, profile_str, "SILVER");
      PositionLabel(13, x_col1, y_start + y_step * row);

      row = 8;
      string liq_str = "LIQ: " +
         (decision.context.liquidity.valid ?
            "EVENT=" + (decision.context.liquidity.recent_event == LIQ_EVENT_LONG_SWEEP ? "LONG" :
                        decision.context.liquidity.recent_event == LIQ_EVENT_SHORT_SWEEP ? "SHORT" : "NONE") : "N/A");
      SetLabelText(14, liq_str, "SILVER");
      PositionLabel(14, x_col1, y_start + y_step * row);

      row = 9;
      string mom_str = "MOM: " +
         (decision.context.momentum.valid ?
            EnumToString(decision.context.momentum.state) : "N/A");
      SetLabelText(15, mom_str, "SILVER");
      PositionLabel(15, x_col1, y_start + y_step * row);

      row = 10;
      string spread_str = "SPREAD: " +
         DoubleToString(decision.context.setup_market.spread_points /
                        decision.context.setup_market.properties.point, 1) + "pts";
      SetLabelText(16, spread_str, "SILVER");
      PositionLabel(16, x_col1, y_start + y_step * row);

      row = 11;
      string pos_str = "POS: " + IntegerToString(portfolio_state.total_positions);
      SetLabelText(17, pos_str, portfolio_state.trading_locked ? "RED" : "SILVER");
      PositionLabel(17, x_col1, y_start + y_step * row);

      if(m_show_diagnostics)
        {
         row = 12;
         SetLabelText(18, "EVIDENCE: " + ShortReason(decision.evidence_summary), "GREY");
         PositionLabel(18, x_col1, y_start + y_step * row);
        }

      m_last_update_time = TimeCurrent();
      ChartRedraw(m_chart_id);
     }

   void RenderMarketView(const MarketSnapshot& market)
     {
      if(!m_enabled)
         return;

      long chart_id = ChartID();
      string chart_symbol = ChartSymbol(0);

      if(chart_symbol != "" && market.symbol != chart_symbol)
          return;

       if(m_chart_id != chart_id || m_bg_name == "")
         {
          m_chart_id = chart_id;
          m_bg_name = "AlgoHybridDashboard_BG_" + IntegerToString((int)chart_id);
         }

       CreateObjects();

      int x_col1 = 10;
      int y_start = 20;
      int y_step = 14;

      int row = 0;
      SetLabelText(0, m_title, "SILVER");
      PositionLabel(0, x_col1, y_start);

      SetLabelText(1, "SYMBOL: " + market.symbol, "SILVER");
      PositionLabel(1, x_col1, y_start + y_step * (++row));

      SetLabelText(2, "STYLE: " + StyleText(m_last_style), "SILVER");
      PositionLabel(2, x_col1, y_start + y_step * (++row));

      row = 1;
      SetLabelText(5, "STATUS: " + m_status_text, "AMBER");
      PositionLabel(5, 120, y_start + y_step * row);

      SetLabelText(6, "BID/ASK: " +
         DoubleToString(market.bid, (int)market.properties.digits) + "/" +
         DoubleToString(market.ask, (int)market.properties.digits), "SILVER");
      PositionLabel(6, 120, y_start + y_step * (++row));

      row = 3;
      SetLabelText(7, "SPREAD: " +
         DoubleToString(market.spread_points / market.properties.point, 1) + " pts", "SILVER");
      PositionLabel(7, 120, y_start + y_step * row);

      row = 4;
      SetLabelText(8, "BAR: " + TimeToString(market.closed_bar_time, TIME_DATE|TIME_MINUTES), "SILVER");
      PositionLabel(8, 120, y_start + y_step * row);

      m_last_update_time = TimeCurrent();
      ChartRedraw(m_chart_id);
     }

  };

#endif