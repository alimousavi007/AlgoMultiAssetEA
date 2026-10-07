#ifndef __ALGOSYSTEM_DASHBOARD_MQH__
#define __ALGOSYSTEM_DASHBOARD_MQH__

#include "Types.mqh"

class CAlgoDashboard
  {
private:
   bool   m_enabled;
   string m_title;
   long   m_chart_id;
   string m_bg_name;
   string m_text_name;
   string m_last_signal_text;
   string m_last_risk_text;
   bool   m_has_evaluation;

   string TimeframeText(const ENUM_TIMEFRAMES tf) const
     {
      string value=EnumToString(tf);
      StringReplace(value,"PERIOD_","");
      return value;
     }

   string SignalText(const StrategySignal &signal) const
     {
      if(!signal.valid)
         return "NONE";

      return EnumToString(signal.direction)+
             " "+EnumToString(signal.strategy)+
             " S="+DoubleToString(signal.score,0);
     }

   string RiskText(const RiskDecision &risk) const
     {
      if(risk.decision==RISK_APPROVED)
         return "OK V="+DoubleToString(risk.calculated_volume,4);

      if(risk.decision==RISK_REJECTED)
         return "BLOCK";

      return "WAIT";
     }

   void Render(const MarketSnapshot &market,
               const FeatureSet &features,
               const ENUM_REGIME_TYPE regime,
               const string signal_text,
               const string risk_text,
               const PortfolioState &portfolio)
     {
      string chart_tf=TimeframeText((ENUM_TIMEFRAMES)ChartPeriod(0));
      string analysis_tf=TimeframeText(market.timeframe);

      string title_line=
         m_title+" | "+market.symbol+
         " | "+chart_tf+"/"+analysis_tf;

      string line1=
         "P "+DoubleToString(market.bid,market.properties.digits)+
         "/"+DoubleToString(market.ask,market.properties.digits)+
         " | Spr "+DoubleToString(market.spread_points,1);

      string line2=
         "R "+EnumToString(regime)+
         " | ATR "+DoubleToString(features.atr,market.properties.digits)+
         " | ADX "+DoubleToString(features.adx,1)+
         " | RSI "+DoubleToString(features.rsi,1);

      string line3=
         "S "+signal_text+
         " | Risk "+risk_text;

      string line4=
         "Eq "+DoubleToString(portfolio.equity,2)+
         " | Pos "+IntegerToString(portfolio.total_positions)+
         " | D "+DoubleToString(portfolio.daily_loss_percent,1)+"%"+
         " | M "+DoubleToString(portfolio.monthly_loss_percent,1)+"%";

      string line5=
         "Lock "+(portfolio.trading_locked ? "ON" : "OFF");

      SetText(
         title_line+"\n"+
         line1+"\n"+
         line2+"\n"+
         line3+"\n"+
         line4+"\n"+
         line5);
     }

   bool EnsureObjects()
     {
      if(!m_enabled)
         return false;

      long chart_id=ChartID();

      if(m_chart_id!=chart_id ||
         m_bg_name=="" ||
         m_text_name=="")
        {
         m_chart_id=chart_id;

         string suffix=IntegerToString((long)chart_id);
         m_bg_name="AlgoDashboard_BG_"+suffix;
         m_text_name="AlgoDashboard_Text_"+suffix;
        }

      if(ObjectFind(m_chart_id,m_bg_name)<0)
        {
         if(!ObjectCreate(m_chart_id,m_bg_name,OBJ_RECTANGLE_LABEL,0,0,0))
            return false;

         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XDISTANCE,8);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YDISTANCE,8);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XSIZE,300);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YSIZE,122);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BGCOLOR,clrBlack);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_COLOR,clrDimGray);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_SELECTED,false);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_HIDDEN,true);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BACK,false);
         ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_ZORDER,0);
        }

      if(ObjectFind(m_chart_id,m_text_name)<0)
        {
         if(!ObjectCreate(m_chart_id,m_text_name,OBJ_LABEL,0,0,0))
            return false;

         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_XDISTANCE,18);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_YDISTANCE,17);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_COLOR,clrWhite);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_FONTSIZE,8);
         ObjectSetString(m_chart_id,m_text_name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_SELECTED,false);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_HIDDEN,true);
         ObjectSetInteger(m_chart_id,m_text_name,OBJPROP_ZORDER,1);
        }

      return true;
     }

   void SetText(const string text)
     {
      if(!EnsureObjects())
         return;

      ObjectSetString(m_chart_id,m_text_name,OBJPROP_TEXT,text);
      ChartRedraw(m_chart_id);
     }

public:
   CAlgoDashboard()
     {
      m_enabled=true;
      m_title="ALGO";
      m_chart_id=0;
      m_bg_name="";
      m_text_name="";
      m_last_signal_text="NONE";
      m_last_risk_text="WAIT";
      m_has_evaluation=false;
     }

   void Enable(const bool enabled)
     {
      m_enabled=enabled;

      if(!enabled)
         Clear();
     }

   void SetTitle(const string title)
     {
      m_title=title;
     }

   void Clear()
     {
      long chart_id=(m_chart_id!=0 ? m_chart_id : ChartID());

      if(m_bg_name!="")
         ObjectDelete(chart_id,m_bg_name);

      if(m_text_name!="")
         ObjectDelete(chart_id,m_text_name);
     }

   void ShowStatus(const string status)
     {
      if(!m_enabled)
         return;

      SetText(
         m_title+" | "+status+"\n"+
         "S "+(m_has_evaluation ? m_last_signal_text : "NONE")+
         " | Risk "+(m_has_evaluation ? m_last_risk_text : "WAIT"));
     }

   void Update(const MarketSnapshot &market,
               const FeatureSet &features,
               const ENUM_REGIME_TYPE regime,
               const StrategySignal &signal,
               const RiskDecision &risk,
               const PortfolioState &portfolio)
     {
      if(!m_enabled)
         return;

      // The dashboard belongs only to the chart symbol.
      string chart_symbol=ChartSymbol(0);
      if(chart_symbol!="" && market.symbol!=chart_symbol)
         return;

      m_last_signal_text=SignalText(signal);
      m_last_risk_text=RiskText(risk);
      m_has_evaluation=true;

      Render(
         market,
         features,
         regime,
         m_last_signal_text,
         m_last_risk_text,
         portfolio);
     }

   void UpdateMarket(const MarketSnapshot &market,
                     const FeatureSet &features,
                     const ENUM_REGIME_TYPE regime,
                     const PortfolioState &portfolio)
     {
      if(!m_enabled)
         return;

      // The dashboard belongs only to the chart symbol.
      string chart_symbol=ChartSymbol(0);
      if(chart_symbol!="" && market.symbol!=chart_symbol)
         return;

      Render(
         market,
         features,
         regime,
         m_has_evaluation ? m_last_signal_text : "NONE",
         m_has_evaluation ? m_last_risk_text : "WAIT",
         portfolio);
     }
  };

#endif
