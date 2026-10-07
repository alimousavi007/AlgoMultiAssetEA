#ifndef __ALGOSYSTEM_DASHBOARD_MQH__
#define __ALGOSYSTEM_DASHBOARD_MQH__

#include "Types.mqh"

#define ALGOSYSTEM_DASHBOARD_ROW_COUNT 15
#define ALGOSYSTEM_DASHBOARD_LABEL_COUNT 32

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
   string m_last_evaluation_symbol;
   string m_last_status;
   string m_last_display_symbol;
   string m_last_display_texts[ALGOSYSTEM_DASHBOARD_LABEL_COUNT];
   ENUM_TIMEFRAMES m_last_evaluation_tf;
   datetime m_last_evaluation_time;
   bool   m_has_evaluation;
   bool   m_has_market_view;

   string LabelName(const int index) const
     {
      return m_text_name+"_"+IntegerToString(index);
     }

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
         return "approved V="+DoubleToString(risk.calculated_volume,4);

      if(risk.decision==RISK_REJECTED)
         return "rejected";

      return "undefined";
     }

   string DisplayStatus() const
     {
      if(StringLen(m_last_status)<=42)
         return m_last_status;

      return StringSubstr(m_last_status,0,39)+"...";
     }

   bool ConfigureLabel(const string name,
                       const int index)
     {
      if(ObjectFind(m_chart_id,name)<0)
        {
         if(!ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0))
            return false;
        }

      bool left_aligned=(index<2 ||
                         ((index-2)%2)==0);
      ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(m_chart_id,name,OBJPROP_ANCHOR,
                       left_aligned ? ANCHOR_LEFT_UPPER : ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,
                       left_aligned ? 242 : 22);

      int y_distance=42;
      if(index==1)
         y_distance=62;
      else if(index>=2)
         y_distance=82+((index-2)/2)*15;

      ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,y_distance);
      ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,
                       index==0 ? clrAqua :
                       index==1 ? clrSilver :
                       ((index-2)%2)==0 ? clrSilver : clrWhite);
      ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,index==0 ? 9 : 8);
      ObjectSetString(m_chart_id,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(m_chart_id,name,OBJPROP_ZORDER,1);

      return true;
     }

   void SetLabels(const string &texts[])
     {
      if(!EnsureObjects())
         return;

      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
         ObjectSetString(m_chart_id,LabelName(i),OBJPROP_TEXT,texts[i]);

      ChartRedraw(m_chart_id);
     }

   void Render(const MarketSnapshot &market,
               const FeatureSet &features,
               const ENUM_REGIME_TYPE regime,
               const PortfolioState &portfolio)
     {
      string chart_tf=TimeframeText((ENUM_TIMEFRAMES)ChartPeriod(0));
      string analysis_tf=TimeframeText(market.timeframe);
      bool has_symbol_evaluation=
         m_has_evaluation &&
         m_last_evaluation_symbol==market.symbol;
      string texts[ALGOSYSTEM_DASHBOARD_LABEL_COUNT];
      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
         texts[i]="";

      texts[0]=m_title+" | "+market.symbol;
      if(m_last_status!="")
         texts[1]="Status: "+DisplayStatus();

      string labels[ALGOSYSTEM_DASHBOARD_ROW_COUNT]=
        {
         "Timeframe",
         "Bid / Ask",
         "Spread",
         "Regime",
         "ATR / ADX",
         "RSI",
         "Signal",
         "Risk",
         "Evaluated",
         "Snapshot",
         "Equity",
         "Positions",
         "Daily loss",
         "Monthly loss",
         "Trading lock"
        };
      string values[ALGOSYSTEM_DASHBOARD_ROW_COUNT];
      values[0]=chart_tf+" / "+analysis_tf;
      values[1]=DoubleToString(market.bid,market.properties.digits)+
                " / "+DoubleToString(market.ask,market.properties.digits);
      values[2]=DoubleToString(market.spread_points,1)+" points";
      values[3]=EnumToString(regime);
      values[4]=DoubleToString(features.atr,market.properties.digits)+
                " / "+DoubleToString(features.adx,1);
      values[5]=DoubleToString(features.rsi,1);
      values[6]=has_symbol_evaluation ? m_last_signal_text : "not evaluated";
      values[7]=has_symbol_evaluation ? m_last_risk_text : "not evaluated";
      values[8]=has_symbol_evaluation ?
                m_last_evaluation_symbol+" "+
                TimeframeText(m_last_evaluation_tf)+" "+
                TimeToString(m_last_evaluation_time,TIME_DATE|TIME_MINUTES) :
                "not evaluated";
      values[9]=TimeToString(market.current_time,TIME_DATE|TIME_MINUTES);
      values[10]=DoubleToString(portfolio.equity,2);
      values[11]=IntegerToString(portfolio.total_positions);
      values[12]=DoubleToString(portfolio.daily_loss_percent,1)+"%";
      values[13]=DoubleToString(portfolio.monthly_loss_percent,1)+"%";
      values[14]=portfolio.trading_locked ? "ON" : "OFF";

      for(int row=0;row<ALGOSYSTEM_DASHBOARD_ROW_COUNT;row++)
        {
         int label_index=2+row*2;
         texts[label_index]=labels[row];
         texts[label_index+1]=values[row];
        }

      m_last_display_symbol=market.symbol;
      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
         m_last_display_texts[i]=texts[i];
      m_has_market_view=true;

      SetLabels(texts);
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

      if(ObjectFind(m_chart_id,m_text_name)>=0)
         ObjectDelete(m_chart_id,m_text_name);

      if(ObjectFind(m_chart_id,m_bg_name)<0)
        {
         if(!ObjectCreate(m_chart_id,m_bg_name,OBJ_RECTANGLE_LABEL,0,0,0))
            return false;
        }

      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XDISTANCE,250);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YDISTANCE,30);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XSIZE,240);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YSIZE,288);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_SELECTED,false);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BACK,false);
      ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_ZORDER,0);

      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
        {
         if(!ConfigureLabel(LabelName(i),i))
            return false;
        }

      return true;
     }

public:
   CAlgoDashboard()
     {
      m_enabled=true;
      m_title="ALGO";
      m_chart_id=0;
      m_bg_name="";
      m_text_name="";
      m_last_signal_text="";
      m_last_risk_text="";
      m_last_evaluation_symbol="";
      m_last_status="";
      m_last_display_symbol="";
      m_last_evaluation_tf=PERIOD_CURRENT;
      m_last_evaluation_time=0;
      m_has_evaluation=false;
      m_has_market_view=false;
      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
         m_last_display_texts[i]="";
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
        {
         ObjectDelete(chart_id,m_text_name);
         for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
            ObjectDelete(chart_id,LabelName(i));
        }
     }

   void ShowStatus(const string status)
     {
      if(!m_enabled)
         return;

      m_last_status=status;

      string texts[ALGOSYSTEM_DASHBOARD_LABEL_COUNT];
      string chart_symbol=ChartSymbol(0);
      bool use_cached_view=
         m_has_market_view &&
         (chart_symbol=="" || m_last_display_symbol==chart_symbol);
      for(int i=0;i<ALGOSYSTEM_DASHBOARD_LABEL_COUNT;i++)
         texts[i]=use_cached_view ? m_last_display_texts[i] : "";

      if(!use_cached_view)
         texts[0]=m_title;
      texts[1]="Status: "+DisplayStatus();
      if(!use_cached_view)
        {
         texts[2+6*2]="Signal";
         texts[2+6*2+1]="not evaluated";
         texts[2+7*2]="Risk";
         texts[2+7*2+1]="not evaluated";
         texts[2+8*2]="Evaluated";
         texts[2+8*2+1]="not evaluated";
        }

      SetLabels(texts);
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
      m_last_evaluation_symbol=market.symbol;
      m_last_evaluation_tf=market.timeframe;
      m_last_evaluation_time=market.closed_bar_time;
      m_last_status="";
      m_has_evaluation=true;

      Render(
         market,
         features,
         regime,
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

      m_last_status="";
      Render(
         market,
         features,
         regime,
         portfolio);
     }
  };

#undef ALGOSYSTEM_DASHBOARD_ROW_COUNT
#undef ALGOSYSTEM_DASHBOARD_LABEL_COUNT

#endif
