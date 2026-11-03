#ifndef __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__
#define __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__

#include "HybridTypes.mqh"

class CHybridDashboard
  {
 private:
    bool               m_enabled;
    int                m_view_mode; // 0 FULL, 1 COMPACT, 2 MINIMAL
    bool               m_show_diagnostics;
    bool               m_show_overlay;

    long               m_chart_id;
    string             m_bg_name;
    string             m_title;

    int                m_label_count;
    string             m_label_names[64];
    int                m_label_rel_x[64];
    int                m_label_rel_y[64];
    bool               m_label_rel_valid[64];

    datetime           m_last_update_time;
    string             m_last_display_symbol;
    ENUM_TRADING_STYLE m_last_style;

    string             m_status_text;
    string             m_decision_text;
    string             m_rejection_text;

    struct DashboardLayout
      {
       int chart_width;
       int chart_height;
       int panel_x;
       int panel_y;
       int panel_width;
       int panel_height;
       int padding;
       int row_height;
       int font_size;
       int column_1_x;
       int column_2_x;
       int visible_rows;
       int view_mode;
       bool valid;
      };
    DashboardLayout m_layout;

    struct colorRef { uchar r,g,b; };
    colorRef m_color_green, m_color_red, m_color_amber, m_color_grey, m_color_silver, m_color_lime;

 public:
    CHybridDashboard()
      {
       m_enabled=true;
       m_view_mode=0;
       m_show_diagnostics=true;
       m_show_overlay=true;
       m_chart_id=0;
       m_bg_name="";
       m_title="ALGO HYBRID";
       m_label_count=64;
       m_last_update_time=0;
       m_last_display_symbol="";
       m_last_style=STYLE_DAY_TRADING;
       m_status_text="INITIALIZING";
       m_decision_text="";
       m_rejection_text="";
       for(int i=0;i<64;i++){ m_label_names[i]=""; m_label_rel_x[i]=0; m_label_rel_y[i]=0; m_label_rel_valid[i]=false; }
       m_layout.chart_width=0; m_layout.chart_height=0; m_layout.panel_x=0; m_layout.panel_y=0;
       m_layout.panel_width=0; m_layout.panel_height=0; m_layout.padding=6; m_layout.row_height=14;
       m_layout.font_size=8; m_layout.column_1_x=0; m_layout.column_2_x=0; m_layout.visible_rows=0;
       m_layout.view_mode=0; m_layout.valid=false;
       m_color_green.r=100; m_color_green.g=220; m_color_green.b=100;
       m_color_red.r=220; m_color_red.g=100; m_color_red.b=100;
       m_color_amber.r=255; m_color_amber.g=190; m_color_amber.b=60;
       m_color_grey.r=140; m_color_grey.g=140; m_color_grey.b=140;
       m_color_silver.r=200; m_color_silver.g=200; m_color_silver.b=200;
       m_color_lime.r=173; m_color_lime.g=255; m_color_lime.b=47;
      }

    void Enable(bool enabled){ m_enabled=enabled; if(!enabled) Clear(); }
    void SetViewMode(int mode){ if(mode<0||mode>2) return; m_view_mode=mode; }
    void ShowDiagnostics(bool show){ m_show_diagnostics=show; }
    void ShowOverlay(bool show){ m_show_overlay=show; }
    void SetTitle(const string title){ m_title=title; }
    void SetCompactView(bool compact){ m_view_mode=compact?1:0; }

    void Clear()
      {
       long chart_id=(m_chart_id!=0?m_chart_id:ChartID());
       if(m_bg_name!="")
         {
          ObjectDelete(chart_id,m_bg_name);
          for(int i=0;i<m_label_count;i++) ObjectDelete(chart_id,m_label_names[i]);
         }
       m_bg_name=""; m_chart_id=0;
      }

 private:
    string LabelName(const int index) const { return m_bg_name+"_lbl_"+IntegerToString(index); }

    string StyleText(ENUM_TRADING_STYLE s) const
      { switch(s){case STYLE_SCALPING:return "SCALP";case STYLE_DAY_TRADING:return "DAY";case STYLE_SWING_TRADING:return "SWING";default:return "UNKNOWN";} }
    string RegimeText(ENUM_HYBRID_REGIME r) const
      { switch(r){case HYBRID_REGIME_TRENDING:return "TREND";case HYBRID_REGIME_RANGING:return "RANGE";case HYBRID_REGIME_VOLATILITY_EXPANSION:return "VOL_EXP";case HYBRID_REGIME_COMPRESSION:return "COMPRESS";case HYBRID_REGIME_TRANSITION:return "TRANSITION";case HYBRID_REGIME_INSUFFICIENT_DATA:return "N/A";default:return "?";} }
    string BiasText(ENUM_BIAS_DIRECTION b) const
      { switch(b){case BIAS_BULLISH:return "BULL";case BIAS_BEARISH:return "BEAR";case BIAS_NEUTRAL:return "NEUTRAL";case BIAS_CONFLICTED:return "CONFLICT";case BIAS_INSUFFICIENT_DATA:return "N/A";default:return "?";} }
    string NewsText(ENUM_NEWS_STATE s) const
      { switch(s){case NEWS_UNAVAILABLE:return "N/A";case NEWS_NO_EVENT_SCHEDULED:return "CLEAR";case NEWS_BLACKOUT_ACTIVE:return "BLACKOUT";case NEWS_COOLDOWN_ACTIVE:return "COOLDOWN";case NEWS_EVENT_PASSED:return "PAST";default:return "?";} }
    string DecisionText(ENUM_DECISION_STATUS s) const
      { switch(s){case DECISION_BUY_CANDIDATE:return "BUY";case DECISION_SELL_CANDIDATE:return "SELL";case DECISION_NO_TRADE:return "NO-TRADE";case DECISION_DATA_UNAVAILABLE:return "NO-DATA";case DECISION_NEWS_BLOCKED:return "NEWS-BLOCKED";case DECISION_RISK_REJECTED:return "RISK-REJECT";case DECISION_CONFLICTED_SIGNAL:return "CONFLICT";case DECISION_SETUP_EXPIRED:return "EXPIRED";case DECISION_SETUP_INVALIDATED:return "INVALIDATED";default:return "?";} }
    string ColorForStatus(ENUM_DECISION_STATUS s) const
      { switch(s){case DECISION_BUY_CANDIDATE:return "GREEN";case DECISION_SELL_CANDIDATE:return "RED";case DECISION_NO_TRADE:return "GREY";case DECISION_DATA_UNAVAILABLE:return "GREY";case DECISION_NEWS_BLOCKED:return "AMBER";case DECISION_RISK_REJECTED:return "AMBER";case DECISION_CONFLICTED_SIGNAL:return "AMBER";default:return "GREY";} }
    color ColorFromString(const string c) const
      {
       string n=c; StringTrimLeft(n); StringTrimRight(n); StringToUpper(n);
       if(n=="GREEN") return clrLimeGreen;
       if(n=="RED") return clrSalmon;
       if(n=="AMBER") return clrOrange;
       if(n=="GREY") return clrGray;
       if(n=="LIME") return clrLime;
       if(n=="SILVER") return clrSilver;
       return clrWhite;
      }
    string ShortReason(const string r) const
      { if(StringLen(r)<=20) return r; return StringSubstr(r,0,17)+"..."; }

    void CreateObjects()
      {
       if(ObjectFind(m_chart_id,m_bg_name)<0)
         {
          if(!ObjectCreate(m_chart_id,m_bg_name,OBJ_RECTANGLE_LABEL,0,0,0)) return;
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XDISTANCE,20);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YDISTANCE,20);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XSIZE,260);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YSIZE,180);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BGCOLOR,clrDarkSlateBlue);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_COLOR,clrSilver);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_BACK,false);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_SELECTABLE,false);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_HIDDEN,false);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_ZORDER,10);
         }
       for(int i=0;i<m_label_count;i++)
         {
          m_label_names[i]=LabelName(i);
          if(ObjectFind(m_chart_id,m_label_names[i])<0)
            {
             if(!ObjectCreate(m_chart_id,m_label_names[i],OBJ_LABEL,0,0,0)) continue;
            }
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_FONTSIZE,m_layout.font_size>0?m_layout.font_size:8);
          ObjectSetString(m_chart_id,m_label_names[i],OBJPROP_FONT,"Consolas");
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_SELECTABLE,false);
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_HIDDEN,false);
          ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_ZORDER,20);
         }
      }

    void RecalculateDashboardLayout()
      {
       m_layout.valid=false;
       long w=0,h=0;
       if(!ChartGetInteger(m_chart_id,CHART_WIDTH_IN_PIXELS,w)||w<=0) return;
       if(!ChartGetInteger(m_chart_id,CHART_HEIGHT_IN_PIXELS,h)||h<=0) return;
       m_layout.chart_width=(int)w; m_layout.chart_height=(int)h;
       if(m_layout.chart_width<260||m_layout.chart_height<160) m_view_mode=2;
       else if(m_layout.chart_width<400||m_layout.chart_height<260) m_view_mode=1;
       else m_view_mode=0;
       int pw=(m_view_mode==2)?180:(m_view_mode==1)?240:300;
       if(pw>m_layout.chart_width-20) pw=m_layout.chart_width-20;
       if(pw<140) pw=140;
       m_layout.panel_width=pw;
       m_layout.panel_x=m_layout.chart_width-pw-16;
       if(m_layout.panel_x<0) m_layout.panel_x=0;
       m_layout.panel_y=16;
       m_layout.padding=6;
       m_layout.row_height=13;
       m_layout.font_size=(m_view_mode==2)?7:(m_view_mode==1)?8:9;
       m_layout.column_1_x=m_layout.panel_x+m_layout.padding;
       m_layout.column_2_x=m_layout.column_1_x+(pw/2);
       m_layout.visible_rows=(m_layout.chart_height-40)/m_layout.row_height;
       if(m_layout.visible_rows<4) m_layout.visible_rows=4;
       int ph=m_layout.visible_rows*m_layout.row_height+16;
       if(ph>m_layout.chart_height-16) ph=m_layout.chart_height-16;
       if(ph<80) ph=80;
       m_layout.panel_height=ph;
       if(m_layout.panel_width<=0||m_layout.panel_height<=0) return;
       if(m_layout.panel_x<0||m_layout.panel_y<0) return;
       if(m_layout.panel_x+m_layout.panel_width>m_layout.chart_width) return;
       if(m_layout.panel_y+m_layout.panel_height>m_layout.chart_height) return;
       m_layout.view_mode=m_view_mode;
       m_layout.valid=true;
      }

    void PositionLabel(const int index,int x,int y)
      {
       if(index<0||index>=m_label_count) return;
       ObjectSetInteger(m_chart_id,m_label_names[index],OBJPROP_XDISTANCE,x);
       ObjectSetInteger(m_chart_id,m_label_names[index],OBJPROP_YDISTANCE,y);
       if(m_layout.valid){ m_label_rel_x[index]=x-m_layout.panel_x; m_label_rel_y[index]=y-m_layout.panel_y; m_label_rel_valid[index]=true; }
      }
    void SetLabelText(const int index,const string text,const string col)
      {
       if(index<0||index>=m_label_count) return;
       ObjectSetString(m_chart_id,m_label_names[index],OBJPROP_TEXT,text);
       ObjectSetInteger(m_chart_id,m_label_names[index],OBJPROP_COLOR,(long)ColorFromString(col));
      }

 public:
    void HandleChartGeometryChange()
      {
       RecalculateDashboardLayout();
       if(m_bg_name!=""&&ObjectFind(m_chart_id,m_bg_name)>=0&&m_layout.valid)
         {
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XDISTANCE,m_layout.panel_x);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YDISTANCE,m_layout.panel_y);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_XSIZE,m_layout.panel_width);
          ObjectSetInteger(m_chart_id,m_bg_name,OBJPROP_YSIZE,m_layout.panel_height);
         }
       if(m_layout.valid)
         {
          for(int i=0;i<m_label_count;i++)
            if(m_label_rel_valid[i]&&ObjectFind(m_chart_id,m_label_names[i])>=0)
              {
               ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_XDISTANCE,m_layout.panel_x+m_label_rel_x[i]);
               ObjectSetInteger(m_chart_id,m_label_names[i],OBJPROP_YDISTANCE,m_layout.panel_y+m_label_rel_y[i]);
              }
         }
       ChartRedraw(m_chart_id);
      }

    void ShowStatus(const string status)
      {
       if(!m_enabled) return;
       m_status_text=status;
       long chart_id=ChartID();
       if(m_chart_id!=chart_id||m_bg_name==""){ m_chart_id=chart_id; m_bg_name="AlgoHybridDashboard_BG_"+IntegerToString((int)chart_id); }
       RecalculateDashboardLayout();
       if(!m_layout.valid) return;
       CreateObjects();
       // Header
       SetLabelText(0,m_title+"  |  "+status,m_view_mode==2?"AMBER":"SILVER");
       PositionLabel(0,m_layout.column_1_x,m_layout.panel_y+4);
       // Hide rest
       for(int li=1;li<m_label_count;li++)
         if(ObjectFind(m_chart_id,m_label_names[li])>=0)
           { ObjectSetString(m_chart_id,m_label_names[li],OBJPROP_TEXT,""); ObjectSetInteger(m_chart_id,m_label_names[li],OBJPROP_HIDDEN,true); }
       ChartRedraw(m_chart_id);
      }

    void Update(const HybridDecision& decision,const PortfolioState& portfolio_state)
      {
       if(!m_enabled) return;
       long chart_id=ChartID();
       string chart_symbol=ChartSymbol(0);
       if(chart_symbol!=""&&decision.symbol!=chart_symbol) return;
       if(m_chart_id!=chart_id||m_bg_name==""){ m_chart_id=chart_id; m_bg_name="AlgoHybridDashboard_BG_"+IntegerToString((int)chart_id); }
       if(TimeCurrent()-m_last_update_time<2) return;
       RecalculateDashboardLayout();
       if(!m_layout.valid) return;
       CreateObjects();
       int row=0; int x1=m_layout.column_1_x; int x2=m_layout.column_2_x; int ys=m_layout.panel_y+4; int step=m_layout.row_height;
       SetLabelText(0,m_title+"  "+decision.symbol,"SILVER"); PositionLabel(0,x1,ys+step*(row++));
       SetLabelText(1,"STATUS: "+DecisionText(decision.status),ColorForStatus(decision.status)); PositionLabel(1,x1,ys+step*(row++));
       SetLabelText(2,"STYLE: "+StyleText(decision.style),"LIME"); PositionLabel(2,x1,ys+step*(row++));
       SetLabelText(3,"REGIME: "+RegimeText(decision.regime),"SILVER"); PositionLabel(3,x1,ys+step*(row++));
       SetLabelText(4,"BIAS: "+BiasText(decision.bias),"SILVER"); PositionLabel(4,x1,ys+step*(row++));
       // column2
       row=0;
       SetLabelText(5,"LONG: "+DoubleToString(decision.long_score,1),"GREEN"); PositionLabel(5,x2,ys+step*(row++));
       SetLabelText(6,"SHORT: "+DoubleToString(decision.short_score,1),"RED"); PositionLabel(6,x2,ys+step*(row++));
       SetLabelText(7,"DECISION: "+DecisionText(decision.status),ColorForStatus(decision.status)); PositionLabel(7,x2,ys+step*(row++));
       if(m_view_mode==0 && m_show_diagnostics)
         {
          SetLabelText(8,"REASON: "+ShortReason(decision.main_reason),"GREY"); PositionLabel(8,x1,ys+step*(row+4));
          SetLabelText(9,"NEWS: "+NewsText(decision.context.news.state),"SILVER"); PositionLabel(9,x1,ys+step*(row+5));
          SetLabelText(10,"LIQ: "+(decision.context.liquidity.valid?"EVENT":"N/A"),"SILVER"); PositionLabel(10,x1,ys+step*(row+6));
          SetLabelText(11,"MOM: "+(decision.context.momentum.valid?EnumToString(decision.context.momentum.state):"N/A"),"SILVER"); PositionLabel(11,x1,ys+step*(row+7));
          SetLabelText(12,"SPREAD: "+DoubleToString(decision.context.setup_market.spread_points/decision.context.setup_market.properties.point,1)+"pts","SILVER"); PositionLabel(12,x1,ys+step*(row+8));
          SetLabelText(13,"POS: "+IntegerToString(portfolio_state.total_positions),(portfolio_state.trading_locked?"RED":"SILVER")); PositionLabel(13,x1,ys+step*(row+9));
         }
       // hide unused
       for(int li=14;li<m_label_count;li++)
         if(ObjectFind(m_chart_id,m_label_names[li])>=0){ ObjectSetString(m_chart_id,m_label_names[li],OBJPROP_TEXT,""); ObjectSetInteger(m_chart_id,m_label_names[li],OBJPROP_HIDDEN,true); }
       m_last_update_time=TimeCurrent();
       ChartRedraw(m_chart_id);
      }

    void RenderMarketView(const MarketSnapshot& market)
      {
       if(!m_enabled) return;
       long chart_id=ChartID();
       string chart_symbol=ChartSymbol(0);
       if(chart_symbol!=""&&market.symbol!=chart_symbol) return;
       if(m_chart_id!=chart_id||m_bg_name==""){ m_chart_id=chart_id; m_bg_name="AlgoHybridDashboard_BG_"+IntegerToString((int)chart_id); }
       RecalculateDashboardLayout();
       if(!m_layout.valid) return;
       CreateObjects();
       int x1=m_layout.column_1_x; int x2=m_layout.column_2_x; int ys=m_layout.panel_y+4; int step=m_layout.row_height;
       SetLabelText(0,m_title+"  "+market.symbol,"SILVER"); PositionLabel(0,x1,ys);
       SetLabelText(1,"STATUS: "+m_status_text,"AMBER"); PositionLabel(1,x1,ys+step);
       SetLabelText(2,"BID/ASK: "+DoubleToString(market.bid,(int)market.properties.digits)+"/"+DoubleToString(market.ask,(int)market.properties.digits),"SILVER"); PositionLabel(2,x1,ys+step*2);
       SetLabelText(3,"SPREAD: "+DoubleToString(market.spread_points/market.properties.point,1)+" pts","SILVER"); PositionLabel(3,x2,ys);
       SetLabelText(4,"BAR: "+TimeToString(market.closed_bar_time,TIME_DATE|TIME_MINUTES),"SILVER"); PositionLabel(4,x2,ys+step);
       for(int li=5;li<m_label_count;li++)
         if(ObjectFind(m_chart_id,m_label_names[li])>=0){ ObjectSetString(m_chart_id,m_label_names[li],OBJPROP_TEXT,""); ObjectSetInteger(m_chart_id,m_label_names[li],OBJPROP_HIDDEN,true); }
       m_last_update_time=TimeCurrent();
       ChartRedraw(m_chart_id);
      }
  };
#endif
