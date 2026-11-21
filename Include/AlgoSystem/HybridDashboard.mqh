#ifndef __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__
#define __ALGOSYSTEM_HYBRID_DASHBOARD_MQH__

#define MAX_WRAP_LINES 80  // Unified line buffer capacity for measure and render (was 40)

#include "HybridTypes.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Card-Based Adaptive Dashboard - Content-Driven Layout            |
//| COMPACT/NORMAL/FULL are semantic content levels, not width tiers |
//+------------------------------------------------------------------+
class CHybridDashboard
  {
private:
    // --- Configuration ---
    bool               m_enabled;
    int                m_view_mode;        // 0=FULL, 1=NORMAL, 2=COMPACT
    bool               m_show_diagnostics;
    bool               m_safe_mode;

    // Retry UI state constants (mirror ENUM_E2E6_RETRY_UI_STATE from EA)
    // Must match EA enum: HIDDEN=0, REVIEW=1, CONFIRM_READY=2, BLOCKED=3, COMMITTED=4, INTERRUPTED_VIEW=5
    enum ENUM_RETRY_UI_STATE_CONST
      {
       RETRY_UI_HIDDEN = 0,
       RETRY_UI_REVIEW = 1,
       RETRY_UI_CONFIRM_READY = 2,
       RETRY_UI_BLOCKED = 3,
       RETRY_UI_COMMITTED = 4,
       RETRY_UI_INTERRUPTED_VIEW = 5
      };

    // Retry UI button prefix - must match EA's click router
    string             m_retry_btn_prefix;

   // --- Card ViewModel ---
   // Card types for layout priority
   enum ENUM_CARD_TYPE
     {
      CARD_HEADER = 0,
      CARD_SYSTEM_STATUS = 1,
      CARD_STRATEGY_PRIMARY = 2,   // STYLE, REGIME, BIAS, LONG, SHORT (always visible)
      CARD_STRATEGY_STAGE = 3,     // STAGE (NORMAL/FULL only)
      CARD_SYSTEM_HEALTH = 4,      // Coordinator, Authority, Ledger, Chart Reg (NORMAL/FULL)
      CARD_DIAGNOSTICS = 5,        // Full diagnostics (FULL only, when enabled)
      CARD_RETRY_REVIEW = 6        // Retry/Review (FULL only when active, NORMAL summary when active)
     };

// Card content model - self-contained display data
    struct CardContent
      {
       ENUM_CARD_TYPE   type;
       string           title;              // Card header title
       string           subtitle;           // Optional subtitle
       string           fields[16];         // Value strings (max 16)
       string           field_labels[16];   // Label strings
       string           field_colors[16];   // Color for each value
       string           status_badge;       // System Status: badge text
       string           status_color;       // Badge color
       string           full_reason;        // Full reason (no truncation)
       string           action_text;        // Action required
       bool             visible;            // Runtime visibility
       int              priority;           // Layout priority (lower = first)
      };

   // Card geometry calculated by layout engine
   struct CardGeometry
     {
      int x, y;                    // Top-left position
      int width, height;           // Calculated dimensions
      int content_width;           // Available for text (width - 2*padding)
      int rows_needed;             // Based on wrapped content
      bool valid;
     };

   // Theme/design tokens (centralized) - BASE values only, ViewMode derives from these
   struct DashboardTheme
     {
      // Fonts - base sizes, ViewMode scales from these
      string font_family;
      int    font_size_base;           // Base font size for primary content
      int    font_size_header;         // Header (slightly larger)
      int    font_size_status;         // System status badge
      int    font_size_diagnostics;    // Diagnostics (smaller)
      int    font_size_retry;          // Retry card

      // Colors
      color  bg_panel;
      color  bg_card;
      color  border_card;
      color  text_primary;
      color  text_secondary;
      color  text_muted;
      color  status_ready;
      color  status_waiting;
      color  status_blocked;
      color  status_error;
      color  status_unavailable;
      color  diag_valid;
      color  diag_invalid;
      color  diag_unknown;
      color  btn_primary;
      color  btn_confirm;
      color  btn_cancel;
      color  btn_disabled;

      // Spacing - derived from font_size_base in InitializeTheme()
      int panel_margin;
      int card_spacing;
      int card_padding;
      int min_card_width;
      int max_card_width;
     };

   // DashboardState model (preserved from U3 - authoritative with traceability)
   struct DashboardFieldState
     {
      string        value;
      string        source;
      datetime      timestamp;
      bool          valid;
      bool          stale;
      string        freshness_rule;
     };

   struct DashboardState
     {
      // System Health
      DashboardFieldState coordinator_state;
      DashboardFieldState authority_state;
      DashboardFieldState ledger_state;
      DashboardFieldState chart_registration_state;
      DashboardFieldState snapshot_state;
      DashboardFieldState blocking_subsystem;
      DashboardFieldState failure_reason;
      DashboardFieldState last_successful_stage;
      DashboardFieldState action_required;
      DashboardFieldState external_risk_lock_state; // ERL state

      // Strategy Snapshot
      DashboardFieldState style;
      DashboardFieldState regime;
      DashboardFieldState bias;
      DashboardFieldState long_score;
      DashboardFieldState short_score;
      DashboardFieldState stage;
      DashboardFieldState reason;

      // Runtime
      datetime        last_update_time;
      bool            initialized;

      // Retry UI state (integrated)
      struct RetryUIState
        {
        int            ui_state;
        string         status;
        string         detail;
        bool           review_valid;
        string         review_symbol;
        int            review_direction;
        string         review_claim_id;
        string         review_prior_attempt_id;
        int            review_retry_sequence;
        string         review_failure_class;
        int            review_retcode;
        long           review_broker_order_ticket;
        long           review_broker_deal_ticket;
        long           review_broker_position_ticket;
        string         review_evidence_reason;
        int            candidate_count;
        int            candidate_index;
        };
      RetryUIState m_retry_ui_state;
     };
   DashboardState m_state;

   // Chart objects
   long               m_chart_id;
   string             m_bg_name;
   string             m_title;

// Label management (dynamic, indexed) - track ALL created objects for cleanup
    int                m_label_count;
    string             m_label_names[512];   // Increased capacity from 256 to 512
    int                m_label_rel_x[512];
    int                m_label_rel_y[512];
    bool               m_label_rel_valid[512];
    int                m_next_label_index;

   // Button management (Retry UI)
   string             m_btn_names[32];
   int                m_next_btn_index;

   // Card background tracking for complete cleanup
   string             m_card_bg_names[32];
   int                m_card_bg_count;

   // Render throttling
   ulong              m_last_render_tick;
   int                m_render_interval_ms;
   bool               m_dirty;
   bool               m_force_render;

   // Layout cache
   struct DashboardLayout
     {
      int chart_width;
      int chart_height;
      int panel_x;
      int panel_y;
      int panel_width;
      int panel_height;
      int padding;
      int font_size;
      int view_mode;
      bool valid;
     };
   DashboardLayout m_layout;

   // Card arrays (max cards)
   CardContent        m_cards[24];
   CardGeometry       m_card_geom[24];
   int                m_card_count;

   // Theme instance
   DashboardTheme m_theme;

   // Object ownership prefix for complete cleanup via ObjectsDeleteAll
   string             m_object_prefix;

   // --- Helpers ---
   string LabelName(const int index) const
     {
      return m_object_prefix + "lbl_" + IntegerToString(index);
     }
   string BtnName(const int index) const
     {
      return m_object_prefix + "btn_" + IntegerToString(index);
     }
   string CardBgName(const int index) const
     {
      return m_object_prefix + "cardbg_" + IntegerToString(index);
     }

   DashboardFieldState MakeFieldState(const string value, const string source,
                                      const datetime timestamp, const bool valid,
                                      const bool stale, const string freshness_rule)
     {
      DashboardFieldState fs;
      fs.value = value;
      fs.source = source;
      fs.timestamp = timestamp;
      fs.valid = valid;
      fs.stale = stale;
      fs.freshness_rule = freshness_rule;
      return fs;
     }

// Text measurement - uses TextGetSize for exact pixel dimensions (MQL5 standard)
    void MeasureText(const string text, const int font_size, const string font_name,
                     int& width, int& height) const
      {
       uint uwidth = 0, uheight = 0;
       // Use TextSetFont + TextGetSize per MQL5 reference
       if(TextSetFont(font_name, font_size * -10)) // negative size = points
         {
          TextGetSize(text, uwidth, uheight);
          width = (int)uwidth;
          height = (int)uheight;
         }
       else
         {
          // Fallback estimation
          width = StringLen(text) * font_size * 6 / 10;
          height = font_size + 2;
         }
      }

    // Calculate content width from panel width (single source of truth)
    int GetContentWidth(const int panel_width) const
      {
       int cw = panel_width - 2 * m_theme.card_padding;
       if(cw < m_theme.min_card_width) cw = m_theme.min_card_width;
       return cw;
      }

    // Calculate content width from geometry (for grid cards)
    int GetContentWidthFromGeom(const CardGeometry& geom) const
      {
       return geom.content_width;
      }

    // Get default content width from current layout
    int GetDefaultContentWidth() const
      {
       if(m_layout.valid && m_layout.panel_width > 0)
         return GetContentWidth(m_layout.panel_width);
       return m_theme.min_card_width;
      }

    // Word-wrap text to fit within max_width pixels - NO truncation, pure word-wrap
    // Handles tabs, newlines, multiple spaces. Returns actual line count (0 for empty text).
    void WrapText(const string text, const int max_width, const int font_size,
                  const string font_name, string& lines[], int& line_count) const
      {
        line_count = 0;
        if(text == "") return;

        // Normalize whitespace: replace tabs with spaces, preserve newlines as explicit breaks
        string normalized = text;
        StringReplace(normalized, "\t", "    "); // tabs -> 4 spaces
        
        // Split by newlines first to preserve intentional line breaks
        string paragraphs[];
        int para_count = StringSplit(normalized, '\n', paragraphs);
        if(para_count <= 0) return;

        // Cache word widths - use larger buffer with bound checking
        int word_widths[1024];

        for(int pi = 0; pi < para_count && line_count < ArraySize(lines); pi++)
          {
           string para = paragraphs[pi];
           // Split paragraph by spaces, filtering out empty strings (collapses multiple spaces)
string words_raw[];
            int raw_count = StringSplit(para, ' ', words_raw);
            string words[];
            // Pre-resize to maximum expected words (1024 bound)
            ArrayResize(words, 1024);
            int word_count = 0;
            for(int wi = 0; wi < raw_count; wi++)
              {
               string w = words_raw[wi];
               StringTrimLeft(w);
               StringTrimRight(w);
               if(w != "")
                 {
                  if(word_count < 1024) // bound check
                    {
                     words[word_count] = w;
                     word_count++;
                    }
                 }
              }
           if(word_count <= 0)
             {
              // Empty paragraph (blank line) - preserve as empty line
              if(line_count < ArraySize(lines)) lines[line_count++] = "";
              continue;
             }

           int max_words = (word_count < 1024) ? word_count : 1024;
           for(int wi = 0; wi < max_words; wi++)
             {
              int ww = 0, wh = 0;
              MeasureText(words[wi], font_size, font_name, ww, wh);
              word_widths[wi] = ww;
             }

           string current_line = "";
           int current_width = 0;
           for(int wi = 0; wi < max_words; wi++)
             {
              int word_w = word_widths[wi];
              int space_w = (current_line == "") ? 0 : (font_size * 3 / 10);
              int test_width = current_width + space_w + word_w;

              if(test_width <= max_width)
                {
                 current_line = (current_line == "") ? words[wi] : current_line + " " + words[wi];
                 current_width = test_width;
                }
              else
                {
                 if(current_line != "")
                   {
                    if(line_count < ArraySize(lines)) lines[line_count++] = current_line;
                    current_line = words[wi];
                    current_width = word_w;
                   }
                 else
                   {
                    // Single word exceeds max_width - allow it to overflow (no truncation, no ellipsis)
                    // The layout engine will handle clipping via chart object boundaries
                    if(line_count < ArraySize(lines)) lines[line_count++] = words[wi];
                    current_line = "";
                    current_width = 0;
                   }
                }
             }
           if(current_line != "" && line_count < ArraySize(lines))
             {
              lines[line_count++] = current_line;
             }
           // Add paragraph break (blank line) between paragraphs except after last
           if(pi < para_count - 1 && line_count < ArraySize(lines))
             {
              lines[line_count++] = "";
             }
          }
      }

   // Color helpers
   string StyleText(ENUM_TRADING_STYLE s) const { return CAlgoUtils::StyleToString(s); }
   string RegimeText(ENUM_HYBRID_REGIME r) const { return CAlgoUtils::RegimeToString(r); }
   string BiasText(ENUM_BIAS_DIRECTION b) const { return CAlgoUtils::BiasToString(b); }
   string NewsText(ENUM_NEWS_STATE s) const { return CAlgoUtils::NewsStateToString(s); }
   string DecisionText(ENUM_DECISION_STATUS s) const { return CAlgoUtils::DecisionStatusToString(s); }
   string ColorForStatus(ENUM_DECISION_STATUS s) const
     {
      switch(s)
        {
         case DECISION_BUY_CANDIDATE: return "GREEN";
         case DECISION_SELL_CANDIDATE: return "RED";
         case DECISION_NO_TRADE: return "GREY";
         case DECISION_DATA_UNAVAILABLE: return "GREY";
         case DECISION_NEWS_BLOCKED: return "AMBER";
         case DECISION_RISK_REJECTED: return "AMBER";
         case DECISION_CONFLICTED_SIGNAL: return "AMBER";
         default: return "GREY";
        }
     }
   color ColorFromString(const string c) const
     {
      string n = c; StringTrimLeft(n); StringTrimRight(n); StringToUpper(n);
      if(n == "GREEN") return clrDarkGreen;
      if(n == "RED") return clrDarkRed;
      if(n == "AMBER") return clrDarkOrange;
      if(n == "GREY") return clrDimGray;
      if(n == "LIME") return clrSeaGreen;
      if(n == "SILVER") return clrDarkSlateGray;
      if(n == "TEAL") return clrTeal;
      if(n == "CHARCOAL") return clrBlack;
      return clrBlack;
     }
   string TimeframeText(ENUM_TIMEFRAMES tf) const { return CAlgoUtils::TimeframeToString(tf); }

   // Status color from DashboardFieldState
   string FieldStateColor(const DashboardFieldState& fs) const
     {
      if(!fs.valid) return "RED";
      if(fs.stale) return "AMBER";
      return "GREEN";
     }

// System status badge from DashboardState
    string GetSystemStatusBadge(string& badge_color) const
      {
       // Determine overall system status
       // EA initialization complete is tracked separately from snapshot readiness
       // If EA is initialized but snapshot not ready, show WAITING not INITIALIZING
       bool ea_initialized = m_state.initialized;
       
       if(!ea_initialized)
         {
          badge_color = "AMBER";
          return "INITIALIZING";
         }

       // EA initialized - check specific blocking states
       // Check Authority ORPHANED (highest priority blocking state) - exact match only
       if(m_state.authority_state.value == "ORPHANED")
         {
          badge_color = "RED";
          return "ORPHANED";
         }

      // Check Coordinator unavailable
      if(m_state.coordinator_state.value == "UNAVAILABLE" ||
         StringFind(m_state.coordinator_state.value, "UNAVAILABLE") >= 0)
        {
         badge_color = "RED";
         return "COORDINATOR UNAVAILABLE";
        }

      // Check blocking subsystem
      if(m_state.blocking_subsystem.value != "NONE" && m_state.blocking_subsystem.value != "")
        {
         badge_color = "AMBER";
         return "BLOCKED";
        }

      // Check if snapshot valid
      if(m_state.snapshot_state.valid && m_state.snapshot_state.value == "VALID")
        {
         badge_color = "GREEN";
         return "READY";
        }

      // Check if waiting for data/registration
      if(m_state.coordinator_state.value == "CONNECTED" &&
         (m_state.snapshot_state.value == "NO SNAPSHOT" ||
          m_state.snapshot_state.value == "NO DATA"))
        {
         badge_color = "AMBER";
         return "WAITING";
        }

      badge_color = "GREY";
      return "UNKNOWN";
     }

// Initialize theme with ViewMode-aware values derived from base font size
    void InitializeTheme()
      {
        m_theme.font_family = "Consolas";
        
        // Base font size - COMPACT=8, NORMAL=9, FULL=10 (derived, not hardcoded per mode)
        int base_size = (m_view_mode == 2) ? 8 : (m_view_mode == 1) ? 9 : 10;
        // Clamp minimum font size for readability (MQL5 minimum practical size is 6)
        if(base_size < 6) base_size = 6;
        m_theme.font_size_base = base_size;
        m_theme.font_size_header    = base_size + 1;
        m_theme.font_size_status    = base_size;
        // Diagnostics font: one size smaller than base, but not below minimum readable (7)
        m_theme.font_size_diagnostics = base_size - 1;
        if(m_theme.font_size_diagnostics < 7) m_theme.font_size_diagnostics = 7;
        m_theme.font_size_retry     = base_size;

        m_theme.bg_panel     = clrWhite;
        m_theme.bg_card      = clrWhite;
        m_theme.border_card  = clrSilver;
        m_theme.text_primary = clrBlack;
        m_theme.text_secondary = clrDimGray;
        m_theme.text_muted   = clrGray;
        m_theme.status_ready      = clrDarkGreen;
        m_theme.status_waiting    = clrDarkOrange;
        m_theme.status_blocked    = clrDarkRed;
        m_theme.status_error      = clrMaroon;
        m_theme.status_unavailable = clrDimGray;
        m_theme.diag_valid        = clrDarkGreen;
        m_theme.diag_invalid      = clrDarkRed;
        m_theme.diag_unknown      = clrDimGray;
        m_theme.btn_primary       = clrSteelBlue;
        m_theme.btn_confirm       = clrDarkGreen;
        m_theme.btn_cancel        = clrMaroon;
        m_theme.btn_disabled      = clrDimGray;

        // Spacing derived from base font size (not hardcoded)
        m_theme.panel_margin   = base_size * 2;
        m_theme.card_spacing   = base_size;
        m_theme.card_padding   = base_size + 2;
        m_theme.min_card_width = base_size * 18;  // ~144px at base_size=8, ~162px at base_size=9 (increased for readability)
        m_theme.max_card_width = base_size * 38;  // ~304px at base_size=8, ~380px at base_size=10 (compact policy compatible)
      }

   // Create or get label object
   string GetOrCreateLabel(int& index)
     {
      if(index >= 0 && index < m_label_count && m_label_names[index] != "")
        {
         if(ObjectFind(m_chart_id, m_label_names[index]) >= 0)
           return m_label_names[index];
        }

      // Find or allocate new
      for(int i = 0; i < m_label_count; i++)
        {
         if(m_label_names[i] == "")
           {
            index = i;
            m_label_names[i] = LabelName(i);
            if(ObjectFind(m_chart_id, m_label_names[i]) < 0)
              ObjectCreate(m_chart_id, m_label_names[i], OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetString(m_chart_id, m_label_names[i], OBJPROP_FONT, m_theme.font_family);
            ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_HIDDEN, false);
            ObjectSetInteger(m_chart_id, m_label_names[i], OBJPROP_ZORDER, 20);
            return m_label_names[i];
           }
        }

      // Expand if needed
      return "";
     }

   // Create or get button object
   string GetOrCreateButton(int& index)
     {
      if(index >= 0 && index < 32 && m_btn_names[index] != "")
        {
         if(ObjectFind(m_chart_id, m_btn_names[index]) >= 0)
           return m_btn_names[index];
        }

      for(int i = 0; i < 32; i++)
        {
         if(m_btn_names[i] == "")
           {
            index = i;
            m_btn_names[i] = BtnName(i);
            if(ObjectFind(m_chart_id, m_btn_names[i]) < 0)
              ObjectCreate(m_chart_id, m_btn_names[i], OBJ_BUTTON, 0, 0, 0);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetString(m_chart_id, m_btn_names[i], OBJPROP_FONT, m_theme.font_family);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_FONTSIZE, m_theme.font_size_retry);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_BACK, true);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_SELECTABLE, true);
            ObjectSetInteger(m_chart_id, m_btn_names[i], OBJPROP_ZORDER, 30);
            return m_btn_names[i];
           }
        }
      return "";
     }

   // Create or get RETRY button object - uses exact names expected by EA click router
   string GetOrCreateRetryButton(const string suffix, int& index)
     {
      string name = m_retry_btn_prefix + suffix;
      if(ObjectFind(m_chart_id, name) >= 0)
        {
         // Find in tracking array
         for(int i = 0; i < 32; i++)
           if(m_btn_names[i] == name) { index = i; return name; }
         // Not tracked yet, add to first free slot
         for(int i = 0; i < 32; i++)
           if(m_btn_names[i] == "")
             { index = i; m_btn_names[i] = name; return name; }
         return name;
        }

      // Create new
      for(int i = 0; i < 32; i++)
        {
         if(m_btn_names[i] == "")
           {
            index = i;
            m_btn_names[i] = name;
            ObjectCreate(m_chart_id, name, OBJ_BUTTON, 0, 0, 0);
            ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(m_chart_id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetString(m_chart_id, name, OBJPROP_FONT, m_theme.font_family);
            ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, m_theme.font_size_retry);
            ObjectSetInteger(m_chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, true);
            ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 30);
            return name;
           }
        }
      return "";
     }

   // Create or get card background object
   string GetOrCreateCardBg(int& index)
     {
      if(index >= 0 && index < 32 && m_card_bg_names[index] != "")
        {
         if(ObjectFind(m_chart_id, m_card_bg_names[index]) >= 0)
           return m_card_bg_names[index];
        }

      for(int i = 0; i < 32; i++)
        {
         if(m_card_bg_names[i] == "")
           {
            index = i;
            m_card_bg_names[i] = CardBgName(i);
            if(ObjectFind(m_chart_id, m_card_bg_names[i]) < 0)
              ObjectCreate(m_chart_id, m_card_bg_names[i], OBJ_RECTANGLE_LABEL, 0, 0, 0);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_BGCOLOR, m_theme.bg_card);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_COLOR, m_theme.border_card);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_BACK, false);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_HIDDEN, false);
            ObjectSetInteger(m_chart_id, m_card_bg_names[i], OBJPROP_ZORDER, 15);
            if(i >= m_card_bg_count) m_card_bg_count = i + 1;
            return m_card_bg_names[i];
           }
        }
      return "";
     }

   // Set label text and color
   void SetLabelProps(const string name, const string text, const string color_name, const int font_size)
     {
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, (long)ColorFromString(color_name));
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, font_size);
     }

   // Set button props
   void SetButtonProps(const string name, const string caption, int x, int y, int width, int height,
                       const color bg_color, const color text_color, const bool enabled)
     {
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, height);
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, caption);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, enabled ? bg_color : m_theme.btn_disabled);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, enabled);
     }

   // Calculate button width from caption
   int CalcButtonWidth(const string caption, const int font_size)
     {
      int w = 0, h = 0;
      MeasureText(caption, font_size, m_theme.font_family, w, h);
      return w + 16; // padding
     }

public:
CHybridDashboard()
      {
       m_enabled = true;
       m_view_mode = 1; // NORMAL (was 0=FULL)
       m_show_diagnostics = false; // OFF by default (was true)
       m_safe_mode = false;

      m_state.initialized = false;
      m_state.last_update_time = 0;

      // System Health defaults
      m_state.coordinator_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");
      m_state.authority_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");
      m_state.ledger_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");
      m_state.chart_registration_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");
      m_state.snapshot_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");
      m_state.blocking_subsystem = MakeFieldState("NONE", "Dashboard", 0, false, false, "");
      m_state.failure_reason = MakeFieldState("", "Dashboard", 0, false, false, "");
      m_state.last_successful_stage = MakeFieldState("", "Dashboard", 0, false, false, "");
      m_state.action_required = MakeFieldState("", "Dashboard", 0, false, false, "");
      m_state.external_risk_lock_state = MakeFieldState("NOT EVALUATED", "Dashboard", 0, false, false, "");

// Strategy Snapshot defaults
       m_state.style = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.regime = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.bias = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.long_score = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.short_score = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.stage = MakeFieldState("NOT EVALUATED", "Snapshot", 0, false, false, "");
       m_state.reason = MakeFieldState("", "Snapshot", 0, false, false, "");

      m_chart_id = 0;
      m_bg_name = "";
      m_title = "ALGO HYBRID";

m_label_count = 512;
       m_next_label_index = 0;
       m_next_btn_index = 0;
       m_card_bg_count = 0;
       for(int i = 0; i < 512; i++) { m_label_names[i] = ""; m_label_rel_x[i] = 0; m_label_rel_y[i] = 0; m_label_rel_valid[i] = false; }
      for(int i = 0; i < 32; i++) { m_btn_names[i] = ""; m_card_bg_names[i] = ""; }

      m_card_count = 0;
      for(int i = 0; i < 24; i++) { m_cards[i].visible = false; m_card_geom[i].valid = false; }

      m_last_render_tick = 0;
      m_render_interval_ms = 500;
      m_dirty = true;
      m_force_render = false;

      m_layout.chart_width = 0; m_layout.chart_height = 0; m_layout.panel_x = 0; m_layout.panel_y = 0;
      m_layout.panel_width = 0; m_layout.panel_height = 0; m_layout.padding = 0; m_layout.font_size = 0;
      m_layout.view_mode = 0; m_layout.valid = false;

m_object_prefix = "";
       m_retry_btn_prefix = "";
       
       InitializeTheme();
     }

   void Enable(bool enabled) { m_enabled = enabled; if(!enabled) Clear(); }

   // Consumer-only snapshot setter - updates DashboardState model
   void SetRuntimeSnapshot(const string style, const string regime, const string bias,
                           const string longt, const string shortt, const string stage,
                           const string reason, const datetime snap_time, const datetime success_time,
                           const bool valid)
     {
      datetime now = TimeCurrent();
      
      // Determine snapshot staleness based on age (TTL = 300 seconds for context/structure)
      bool stale = false;
      if(snap_time > 0)
        {
         int age_seconds = (int)(now - snap_time);
         if(age_seconds > 300) stale = true;
        }
      else if(success_time > 0)
        {
         int age_seconds = (int)(now - success_time);
         if(age_seconds > 300) stale = true;
        }

      m_state.style = MakeFieldState((style == "" ? "NOT EVALUATED" : style), "Snapshot", now, valid, stale, "");
      m_state.regime = MakeFieldState((regime == "" ? "NOT EVALUATED" : regime), "Snapshot", now, valid, stale, "");
      m_state.bias = MakeFieldState((bias == "" ? "NOT EVALUATED" : bias), "Snapshot", now, valid, stale, "");
      m_state.long_score = MakeFieldState((longt == "" ? "NOT EVALUATED" : longt), "Snapshot", now, valid, stale, "");
      m_state.short_score = MakeFieldState((shortt == "" ? "NOT EVALUATED" : shortt), "Snapshot", now, valid, stale, "");
      m_state.stage = MakeFieldState((stage == "" ? "NOT EVALUATED" : stage), "Snapshot", now, valid, stale, "");
      m_state.reason = MakeFieldState(reason, "Snapshot", now, valid, stale, "");
      m_state.snapshot_state = MakeFieldState((valid ? "VALID" : "INVALID"), "Snapshot", now, valid, stale, "");
      m_state.last_update_time = now;
      m_state.initialized = true;
      m_dirty = true;
     }

   void ShowDiagnostics(bool show) { m_show_diagnostics = show; m_dirty = true; }
   void SetSafeMode(bool safe) { m_safe_mode = safe; m_dirty = true; }
   void SetTitle(const string title) { m_title = title; m_dirty = true; }
   void SetViewMode(int mode) { if(mode < 0 || mode > 2) return; m_view_mode = mode; InitializeTheme(); m_dirty = true; }

// COMPLETE object cleanup - uses ObjectsDeleteAll with prefix for guaranteed removal
    void Clear()
      {
       long chart_id = (m_chart_id != 0 ? m_chart_id : ChartID());
       
       // Delete ALL objects with our main prefix on this chart (most reliable)
       if(m_object_prefix != "")
         {
          ObjectsDeleteAll(chart_id, m_object_prefix);
         }
       
       // Also delete Retry UI buttons (separate prefix)
       if(m_retry_btn_prefix != "")
         {
          ObjectsDeleteAll(chart_id, m_retry_btn_prefix);
         }
       
       // Also explicitly delete main background if it exists (belt and suspenders)
       if(m_bg_name != "")
         {
          ObjectDelete(chart_id, m_bg_name);
         }

       // Reset all tracking state
       m_bg_name = ""; 
       m_chart_id = 0;
       m_object_prefix = "";
       m_retry_btn_prefix = "";
       m_next_label_index = 0;
       m_next_btn_index = 0;
       m_card_bg_count = 0;
m_card_count = 0;
        for(int i = 0; i < m_label_count; i++) { m_label_names[i] = ""; m_label_rel_x[i] = 0; m_label_rel_y[i] = 0; m_label_rel_valid[i] = false; }
       for(int i = 0; i < 32; i++) { m_btn_names[i] = ""; m_card_bg_names[i] = ""; }
       for(int i = 0; i < 24; i++) { m_cards[i].visible = false; m_card_geom[i].valid = false; }
      }

   // System Health state setters - update DashboardState model with full traceability
   void SetCoordinatorState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.coordinator_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetAuthorityState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.authority_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetLedgerState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.ledger_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetChartRegistrationState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.chart_registration_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetSnapshotState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.snapshot_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetExternalRiskLockState(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.external_risk_lock_state = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetBlockingSubsystem(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.blocking_subsystem = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetFailureReason(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.failure_reason = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetLastSuccessfulStage(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.last_successful_stage = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
   void SetActionRequired(const string value, const string source, const bool valid, const string freshness_rule = "")
     { if(!m_enabled) return; datetime now = TimeCurrent(); m_state.action_required = MakeFieldState(value, source, now, valid, false, freshness_rule); m_dirty = true; }
void MarkStateStale()
       {
        if(!m_enabled) return;
        m_state.coordinator_state.stale = true;
        m_state.authority_state.stale = true;
        m_state.ledger_state.stale = true;
        m_state.chart_registration_state.stale = true;
        m_state.snapshot_state.stale = true;
        m_state.blocking_subsystem.stale = true;
        m_state.failure_reason.stale = true;
        m_state.last_successful_stage.stale = true;
        m_state.action_required.stale = true;
        m_state.external_risk_lock_state.stale = true;
        m_dirty = true;
       }

    // Explicitly mark EA initialization as complete (separate from snapshot readiness)
    void SetEAInitialized()
      {
       if(!m_enabled) return;
       if(!m_state.initialized)
         {
          m_state.initialized = true;
          m_dirty = true;
         }
      }

    // Reset all Diagnostics-specific fields to default/unknown state
    // Ensures consistency between System Health and Diagnostics cards
    void ResetDiagnosticsFields()
      {
       if(!m_enabled) return;
       datetime now = TimeCurrent();
       // EXT RISK LOCK - default to UNKNOWN (not blocked unless explicitly set)
       m_state.external_risk_lock_state = MakeFieldState("UNKNOWN", "Diagnostics", now, false, false, "");
       // LAST OK - default to N/A (no successful stage yet)
       m_state.last_successful_stage = MakeFieldState("N/A", "Diagnostics", now, false, false, "");
       // REASON - default to empty (no specific reason)
       m_state.reason = MakeFieldState("", "Diagnostics", now, true, false, "");
       m_dirty = true;
      }

   // Retry UI state setters - integrated into dashboard layout
   void SetRetryUIState(const int ui_state, const string status, const string detail)
     { if(!m_enabled) return; m_state.m_retry_ui_state.ui_state = ui_state; m_state.m_retry_ui_state.status = status; m_state.m_retry_ui_state.detail = detail; m_dirty = true; }
   void SetRetryUIReview(const bool valid, const string symbol, const int direction, const string claim_id,
                         const string prior_attempt_id, const int retry_sequence, const string failure_class,
                         const int retcode, const long order_ticket, const long deal_ticket,
                         const long position_ticket, const string evidence_reason,
                         const int candidate_count, const int candidate_index)
     {
      if(!m_enabled) return;
      m_state.m_retry_ui_state.review_valid = valid;
      m_state.m_retry_ui_state.review_symbol = symbol;
      m_state.m_retry_ui_state.review_direction = direction;
      m_state.m_retry_ui_state.review_claim_id = claim_id;
      m_state.m_retry_ui_state.review_prior_attempt_id = prior_attempt_id;
      m_state.m_retry_ui_state.review_retry_sequence = retry_sequence;
      m_state.m_retry_ui_state.review_failure_class = failure_class;
      m_state.m_retry_ui_state.review_retcode = retcode;
      m_state.m_retry_ui_state.review_broker_order_ticket = order_ticket;
      m_state.m_retry_ui_state.review_broker_deal_ticket = deal_ticket;
      m_state.m_retry_ui_state.review_broker_position_ticket = position_ticket;
      m_state.m_retry_ui_state.review_evidence_reason = evidence_reason;
      m_state.m_retry_ui_state.candidate_count = candidate_count;
      m_state.m_retry_ui_state.candidate_index = candidate_index;
      m_dirty = true;
     }
   void ClearRetryUI()
     { if(!m_enabled) return; ZeroMemory(m_state.m_retry_ui_state); m_dirty = true; }

   // Show status (legacy compatibility - updates model)
   void ShowStatus(const string status)
     { if(!m_enabled) return; m_state.failure_reason = MakeFieldState(status, "Status", TimeCurrent(), true, false, ""); m_dirty = true; m_force_render = true; }

   // Chart geometry change handler
   void HandleChartGeometryChange()
     {
      RecalculateDashboardLayout();
      if(m_bg_name != "" && ObjectFind(m_chart_id, m_bg_name) >= 0 && m_layout.valid)
        {
         ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XDISTANCE, m_layout.panel_x);
         ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YDISTANCE, m_layout.panel_y);
         ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XSIZE, m_layout.panel_width);
         ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YSIZE, m_layout.panel_height);
        }
      if(m_layout.valid)
        {
         // Rebuild cards on resize
         m_dirty = true;
         m_force_render = true;
        }
      ChartRedraw(m_chart_id);
     }

private:
    // --- Layout Engine ---

 // Measure wrapped line count for text at given width (helper for width calculation)
    int MeasureWrappedLines(const string text, const int width, const int font_size, const string font_name) const
      {
       if(text == "") return 0;
       string lines[MAX_WRAP_LINES];
       int line_count = 0;
       WrapText(text, width, font_size, font_name, lines, line_count);
       return line_count;
      }

// Calculate required panel width from actual card content measurements
    // COMPACT WIDTH POLICY: Measure atomic content + ensure long wrapped text fits reasonably
    // Long strings (full_reason, action_text, failure_reason, fields) should not exceed MAX_WRAPPED_LINES lines
    int CalculateRequiredPanelWidth()
      {
        if(m_card_count == 0) return m_theme.min_card_width + 2 * m_theme.card_padding;

        int max_content_width = 0;
        const int max_allowed_lines = 3; // Max lines for wrapped content
        
        // Measure each card's required content width
        for(int i = 0; i < m_card_count; i++)
          {
           if(!m_cards[i].visible) continue;
           
           int font_size = 0;
           switch(m_cards[i].type)
             {
              case CARD_HEADER: font_size = m_theme.font_size_header; break;
              case CARD_SYSTEM_STATUS: font_size = m_theme.font_size_status; break;
              case CARD_STRATEGY_PRIMARY:
              case CARD_STRATEGY_STAGE: font_size = m_theme.font_size_base; break;
              case CARD_SYSTEM_HEALTH: font_size = m_theme.font_size_base - 1; break;
              case CARD_DIAGNOSTICS: font_size = m_theme.font_size_diagnostics; break;
              case CARD_RETRY_REVIEW: font_size = m_theme.font_size_retry; break;
              default: font_size = m_theme.font_size_base;
             }

           // Measure title (atomic - short header text)
           int title_w = 0, title_h = 0;
           MeasureText(m_cards[i].title, font_size, m_theme.font_family, title_w, title_h);
           if(title_w > max_content_width) max_content_width = title_w;

           // Measure subtitle (atomic - short context text)
           if(m_cards[i].subtitle != "")
             {
              int sub_w = 0, sub_h = 0;
              MeasureText(m_cards[i].subtitle, font_size - 1, m_theme.font_family, sub_w, sub_h);
              if(sub_w > max_content_width) max_content_width = sub_w;
             }

           // Measure status badge (atomic - short status text like "READY", "BLOCKED")
           if(m_cards[i].status_badge != "")
             {
              int badge_w = 0, badge_h = 0;
              MeasureText(m_cards[i].status_badge, font_size, m_theme.font_family, badge_w, badge_h);
              if(badge_w > max_content_width) max_content_width = badge_w;
             }

           // Measure ALL fields (both labeled and unlabeled like primary strategy fields)
           for(int fi = 0; fi < 16; fi++)
             {
              if(m_cards[i].fields[fi] == "") continue;
              
              string display;
              if(m_cards[i].field_labels[fi] != "")
                display = m_cards[i].field_labels[fi] + ": " + m_cards[i].fields[fi];
              else
                display = m_cards[i].fields[fi]; // Unlabeled field (e.g., primary strategy values)
              
              // Measure atomic width first
              int field_w = 0, field_h = 0;
              MeasureText(display, font_size - 1, m_theme.font_family, field_w, field_h);
              if(field_w > max_content_width) max_content_width = field_w;
              
              // ALSO check wrapped line count at minimum width - if it wraps too much, increase required width
              int lines = MeasureWrappedLines(display, m_theme.min_card_width, font_size - 1, m_theme.font_family);
              if(lines > max_allowed_lines)
                {
                 int low = m_theme.min_card_width;
                 int high = m_theme.max_card_width;
                 while(low < high)
                   {
                    int mid = (low + high) / 2;
                    int l = MeasureWrappedLines(display, mid, font_size - 1, m_theme.font_family);
                    if(l <= max_allowed_lines) high = mid;
                    else low = mid + 1;
                   }
                 if(low > max_content_width) max_content_width = low;
                }
             }

           // Ensure long wrapped text (full_reason, action_text) fits within reasonable line count
           // for ALL card types, not just SYSTEM_STATUS
           if(m_cards[i].full_reason != "")
             {
              int lines = MeasureWrappedLines(m_cards[i].full_reason, m_theme.min_card_width, font_size - 1, m_theme.font_family);
              if(lines > max_allowed_lines)
                {
                 int low = m_theme.min_card_width;
                 int high = m_theme.max_card_width;
                 while(low < high)
                   {
                    int mid = (low + high) / 2;
                    int l = MeasureWrappedLines(m_cards[i].full_reason, mid, font_size - 1, m_theme.font_family);
                    if(l <= max_allowed_lines) high = mid;
                    else low = mid + 1;
                   }
                 if(low > max_content_width) max_content_width = low;
                }
             }
           
           if(m_cards[i].action_text != "")
             {
              int lines = MeasureWrappedLines(m_cards[i].action_text, m_theme.min_card_width, font_size - 1, m_theme.font_family);
              if(lines > max_allowed_lines)
                {
                 int low = m_theme.min_card_width;
                 int high = m_theme.max_card_width;
                 while(low < high)
                   {
                    int mid = (low + high) / 2;
                    int l = MeasureWrappedLines(m_cards[i].action_text, mid, font_size - 1, m_theme.font_family);
                    if(l <= max_allowed_lines) high = mid;
                    else low = mid + 1;
                   }
                 if(low > max_content_width) max_content_width = low;
                }
             }
          }

        // Add padding
        int required_width = max_content_width + 2 * m_theme.card_padding;
        
        // Clamp to min/max
        if(required_width < m_theme.min_card_width) required_width = m_theme.min_card_width;
        if(required_width > m_theme.max_card_width) required_width = m_theme.max_card_width;
        
        // For multi-column strategy cards, we need wider panel (but still bounded)
        // Use measured fit from CalculateStrategyGrid instead of hardcoded multiplier
        // NOTE: Multi-column width is now determined dynamically in LayoutCards based on actual panel_width
        // CalculateRequiredPanelWidth returns single-card content width; grid adapts to available space
        
        return required_width;
       }

// Calculate the right edge of the current/rightmost candle (bar 0) in chart X pixels
    // Returns -1 if calculation fails
    int CalculateCurrentCandleRightEdge() const
      {
       int x0 = 0, y0 = 0;
       int x1 = 0, y1 = 0;
       // Get the time of the current forming bar (bar 0)
       datetime bar_time_0 = iTime(ChartSymbol(m_chart_id), ChartPeriod(m_chart_id), 0);
       if(bar_time_0 == 0) return -1;
       
       // Use a price within the visible range (chart mid-price) for coordinate conversion
       double price = (ChartGetDouble(m_chart_id, CHART_PRICE_MAX, 0) + ChartGetDouble(m_chart_id, CHART_PRICE_MIN, 0)) / 2.0;
       if(price <= 0) price = SymbolInfoDouble(ChartSymbol(m_chart_id), SYMBOL_BID);
       if(price <= 0) return -1;
       
       // Convert bar 0 time + price to chart X,Y coordinates (center of current forming bar)
       if(!ChartTimePriceToXY(m_chart_id, 0, bar_time_0, price, x0, y0)) return -1;
       
       // Get bar 1 (last closed bar) time for measuring actual candle width
       datetime bar_time_1 = iTime(ChartSymbol(m_chart_id), ChartPeriod(m_chart_id), 1);
       if(bar_time_1 > 0)
         {
          // Convert bar 1 at same price level
          if(ChartTimePriceToXY(m_chart_id, 0, bar_time_1, price, x1, y1))
            {
             // Actual candle width = distance between bar centers
             int candle_width_px = MathAbs(x0 - x1);
             if(candle_width_px > 0)
               {
                // Right edge of current forming bar = center + half width
                int candle_right = x0 + (candle_width_px / 2);
                return candle_right;
               }
            }
         }
       
       // Fallback: use chart geometry approximation
       long bars_in_width = 0;
       ChartGetInteger(m_chart_id, CHART_WIDTH_IN_BARS, 0, bars_in_width);
       if(bars_in_width <= 0) bars_in_width = 1;
       
       int candle_width_px = (int)((double)m_layout.chart_width / (double)bars_in_width);
       if(candle_width_px <= 0) candle_width_px = 1;
       
       // Right edge of candle = center X + half candle width
       int candle_right = x0 + (candle_width_px / 2);
       return candle_right;
      }

// Calculate usable plot right boundary (excludes price scale if visible)
    // CHART_WIDTH_IN_PIXELS includes the entire chart window including price scale
    // We need to determine the actual plot area right edge
    int CalculateUsablePlotRight() const
      {
        // MQL5 does not expose price scale width directly; conservative approach uses
        // full chart width minus panel_margin. CHART_SHIFT is accounted for.
        int usable_right = m_layout.chart_width - m_theme.panel_margin;
        
        // If chart shift is enabled, the last bar is indented from the right edge
        // The shift size (percentage) tells us how much space is reserved
        long chart_shift_val = 0;
        ChartGetInteger(m_chart_id, CHART_SHIFT, 0, chart_shift_val);
        bool chart_shift = (chart_shift_val != 0);
        if(chart_shift)
          {
           double shift_size = 0.0;
           ChartGetDouble(m_chart_id, CHART_SHIFT_SIZE, 0, shift_size);
           if(shift_size > 0 && shift_size <= 50)
             {
              int shift_px = (int)((m_layout.chart_width * shift_size) / 100.0);
              usable_right = m_layout.chart_width - shift_px - m_theme.panel_margin;
             }
          }
        
        return usable_right;
       }

// Recalculate panel dimensions using dynamic right-gap docking
    // Dashboard anchors to free space after current candle and before usable plot boundary
    void RecalculateDashboardLayout()
      {
       m_layout.valid = false;
       long w = 0, h = 0;
       bool ok_w = ChartGetInteger(m_chart_id, CHART_WIDTH_IN_PIXELS, 0, w) && w > 0;
       bool ok_h = ChartGetInteger(m_chart_id, CHART_HEIGHT_IN_PIXELS, 0, h) && h > 0;
       if(!ok_w) w = 800;
       if(!ok_h) h = 600;
       m_layout.chart_width = (int)w;
       m_layout.chart_height = (int)h;

       // Calculate content-driven preferred width (atomic content only)
       int preferred_width = CalculateRequiredPanelWidth();
       
       // DYNAMIC RIGHT-GAP DOCKING:
       // 1. Find right edge of current candle
       int candle_right = CalculateCurrentCandleRightEdge();
       
       // 2. Find usable plot right boundary
       int plot_right = CalculateUsablePlotRight();
       
       // 3. Calculate available gap
       int edge_spacing = m_theme.panel_margin; // spacing from candle and from plot edge
       
       // Handle edge case: plot_right should always be >= candle_right for valid geometry
       if(plot_right < candle_right && candle_right >= 0)
         {
          // Invalid geometry - candle beyond plot boundary
          // Fall back to right-aligned without candle constraint
          candle_right = -1;
         }
       
       int available_gap = plot_right - candle_right - edge_spacing;
       
       // 4. If candle calculation failed OR available gap too small, fall back to content-derived width at right side
       if(candle_right < 0 || available_gap < m_theme.min_card_width)
         {
          // Fallback: right-aligned with margin (content-driven width, no 30% hardcode)
          m_layout.panel_width = preferred_width;
          // Ensure panel doesn't exceed chart width
          if(m_layout.panel_width > m_layout.chart_width - 2 * m_theme.panel_margin)
            m_layout.panel_width = m_layout.chart_width - 2 * m_theme.panel_margin;
          if(m_layout.panel_width < m_theme.min_card_width)
            m_layout.panel_width = m_theme.min_card_width;
          
          m_layout.panel_x = m_layout.chart_width - m_layout.panel_width - m_theme.panel_margin;
          if(m_layout.panel_x < 0) m_layout.panel_x = 0;
          
          // Also clamp to candle_right in fallback if candle was calculated (don't overlap candle)
          if(candle_right >= 0)
            {
             int min_x = candle_right + edge_spacing;
             if(m_layout.panel_x < min_x) m_layout.panel_x = min_x;
             // Re-check panel doesn't go off-chart after clamp
             if(m_layout.panel_x + m_layout.panel_width > m_layout.chart_width - m_theme.panel_margin)
               {
                m_layout.panel_x = m_layout.chart_width - m_layout.panel_width - m_theme.panel_margin;
                if(m_layout.panel_x < 0) m_layout.panel_x = 0;
               }
            }
         }
      else
        {
         // Dynamic width: fit in available gap, but not wider than preferred content width
         int final_width = preferred_width;
         if(final_width > available_gap) final_width = available_gap;
         if(final_width < m_theme.min_card_width) final_width = m_theme.min_card_width;
         
         m_layout.panel_width = final_width;
         // Position panel so its RIGHT edge aligns with plot_right - edge_spacing
         m_layout.panel_x = plot_right - m_layout.panel_width - edge_spacing;
         // Never overlap candle
         if(m_layout.panel_x < candle_right + edge_spacing) 
           m_layout.panel_x = candle_right + edge_spacing;
         // Final safety: panel must be on chart
         if(m_layout.panel_x < 0) m_layout.panel_x = 0;
         if(m_layout.panel_x + m_layout.panel_width > m_layout.chart_width)
           {
            m_layout.panel_width = m_layout.chart_width - m_layout.panel_x;
            if(m_layout.panel_width < m_theme.min_card_width)
              {
               // Too narrow - fall back to right-aligned
               m_layout.panel_width = preferred_width;
               m_layout.panel_x = m_layout.chart_width - m_layout.panel_width - m_theme.panel_margin;
               if(m_layout.panel_x < 0) m_layout.panel_x = 0;
              }
           }
        }
       
       if(m_layout.panel_x < 0) m_layout.panel_x = 0;
       m_layout.panel_y = m_theme.panel_margin;
       m_layout.padding = m_theme.card_padding;
       m_layout.font_size = m_theme.font_size_base;
       m_layout.view_mode = m_view_mode;

       // Panel height will be calculated by LayoutCards() based on actual content
       m_layout.panel_height = m_theme.min_card_width * 2; // Initial estimate
       if(m_layout.panel_height > m_layout.chart_height - m_theme.panel_margin) 
         m_layout.panel_height = m_layout.chart_height - m_theme.panel_margin;

       m_layout.valid = true;
      }

// Build CardContent array from DashboardState - VIEWMODE SEMANTIC CONTENT POLICY
    void BuildCardContent()
      {
       // Clear all card slots to prevent stale field leakage
       for(int i = 0; i < 24; i++)
         {
          m_cards[i].type = CARD_HEADER;
          m_cards[i].title = "";
          m_cards[i].subtitle = "";
          for(int fi = 0; fi < 16; fi++)
            {
             m_cards[i].fields[fi] = "";
             m_cards[i].field_labels[fi] = "";
             m_cards[i].field_colors[fi] = "";
            }
          m_cards[i].status_badge = "";
m_cards[i].status_color = "";
           m_cards[i].full_reason = "";
           m_cards[i].action_text = "";
           m_cards[i].visible = false;
           m_cards[i].priority = 0;
          }
       
       m_card_count = 0;

       // ============================================================
       // CARD 0: Header - ALWAYS visible in all ViewModes
       // ============================================================
      int idx = m_card_count++;
      m_cards[idx].type = CARD_HEADER;
      m_cards[idx].title = m_title;
      if(m_safe_mode) m_cards[idx].title += " [SAFE MODE]";
      m_cards[idx].subtitle = ChartSymbol() + "  " + TimeframeText(Period());
      m_cards[idx].visible = true;
      m_cards[idx].priority = 0;

      // ============================================================
      // CARD 1: System Status - ALWAYS visible in all ViewModes
      // COMPACT: badge + critical blocking reason only
      // NORMAL: badge + critical reason
      // FULL: badge + full_reason + action_text
      // ============================================================
      idx = m_card_count++;
      m_cards[idx].type = CARD_SYSTEM_STATUS;
      m_cards[idx].title = "SYSTEM";
      string badge_color;
      m_cards[idx].status_badge = GetSystemStatusBadge(badge_color);
      m_cards[idx].status_color = badge_color;
      
      // Critical blocking reason - shown in ALL modes
      if(m_state.failure_reason.value != "" && m_state.failure_reason.value != "NONE")
        {
         m_cards[idx].full_reason = m_state.failure_reason.value;
        }
      
      // Full details only in FULL mode
      if(m_view_mode == 0) // FULL
        {
         if(m_state.action_required.value != "")
           m_cards[idx].action_text = m_state.action_required.value;
        }
      
      m_cards[idx].visible = true;
      m_cards[idx].priority = 1;

      // ============================================================
      // CARD 2-6: Strategy PRIMARY Fields (5 fields) - ALWAYS visible in ALL ViewModes
      // STYLE, REGIME, BIAS, LONG, SHORT
      // ============================================================
      string primary_labels[5] = { "STYLE", "REGIME", "BIAS", "LONG", "SHORT" };
      string primary_colors[5] = { "GREY", "GREY", "GREY", "GREEN", "RED" };

      for(int i = 0; i < 5; i++)
        {
         idx = m_card_count++;
         m_cards[idx].type = CARD_STRATEGY_PRIMARY;
         m_cards[idx].title = primary_labels[i];
         
         string field_value = "";
         bool field_valid = false;
         if(i == 0) { field_value = m_state.style.value; field_valid = m_state.style.valid; }
         else if(i == 1) { field_value = m_state.regime.value; field_valid = m_state.regime.valid; }
         else if(i == 2) { field_value = m_state.bias.value; field_valid = m_state.bias.valid; }
         else if(i == 3) { field_value = m_state.long_score.value; field_valid = m_state.long_score.valid; }
         else if(i == 4) { field_value = m_state.short_score.value; field_valid = m_state.short_score.valid; }
         
m_cards[idx].fields[0] = field_value;
          m_cards[idx].field_labels[0] = "";  // Label is the card title
          m_cards[idx].field_colors[0] = (field_valid && 
                                           field_value != "NOT EVALUATED")
                                          ? primary_colors[i] : "GREY";
          m_cards[idx].visible = true;
          m_cards[idx].priority = 2 + i;
          }

      // ============================================================
      // ViewMode-specific additional content
      // ============================================================

      if(m_view_mode <= 1) // NORMAL or FULL
        {
// ------------------------------------------------------------------
          // CARD: Strategy STAGE - NORMAL/FULL only
          // ------------------------------------------------------------------
          idx = m_card_count++;
m_cards[idx].type = CARD_STRATEGY_STAGE;
          m_cards[idx].title = "STAGE";
          m_cards[idx].fields[0] = m_state.stage.value;
          m_cards[idx].field_labels[0] = "";
          m_cards[idx].field_colors[0] = (m_state.stage.valid && 
                                           m_state.stage.value != "NOT EVALUATED")
                                          ? "TEAL" : "GREY";
          m_cards[idx].visible = true;
          m_cards[idx].priority = 7;

// ------------------------------------------------------------------
          // CARD: System Health Summary - NORMAL/FULL
          // Shows: Coordinator, Authority, Ledger, Chart Registration (condensed)
          // Skip coordinator/auth if already shown in SYSTEM_STATUS badge to avoid duplication
          // ------------------------------------------------------------------
          idx = m_card_count++;
          m_cards[idx].type = CARD_SYSTEM_HEALTH;
          m_cards[idx].title = "HEALTH";
          m_cards[idx].subtitle = "System Status";
          
          // Determine if SYSTEM_STATUS badge already shows COORDINATOR or AUTHORITY issue
          string sys_badge_color;
          string sys_badge = GetSystemStatusBadge(sys_badge_color);
          bool skip_coord = (sys_badge == "COORDINATOR UNAVAILABLE");
          bool skip_auth = (sys_badge == "ORPHANED");
          
          string health_labels[4] = { "COORD", "AUTH", "LEDGER", "CHART" };
          int health_field_idx = 0;
          
          // Coordinator (skip if already shown in SYSTEM_STATUS)
          if(!skip_coord)
            {
             string field_value = m_state.coordinator_state.value;
             bool field_valid = m_state.coordinator_state.valid;
             bool field_stale = m_state.coordinator_state.stale;
             m_cards[idx].fields[health_field_idx] = field_value;
             m_cards[idx].field_labels[health_field_idx] = health_labels[0];
             m_cards[idx].field_colors[health_field_idx] = (field_valid && !field_stale) ? "GREEN" : (field_stale ? "AMBER" : "RED");
             health_field_idx++;
            }
          
          // Authority (skip if already shown in SYSTEM_STATUS)
          if(!skip_auth)
            {
             string field_value = m_state.authority_state.value;
             bool field_valid = m_state.authority_state.valid;
             bool field_stale = m_state.authority_state.stale;
             m_cards[idx].fields[health_field_idx] = field_value;
             m_cards[idx].field_labels[health_field_idx] = health_labels[1];
             m_cards[idx].field_colors[health_field_idx] = (field_valid && !field_stale) ? "GREEN" : (field_stale ? "AMBER" : "RED");
             health_field_idx++;
            }
          
          // Ledger (always show)
          {
           string field_value = m_state.ledger_state.value;
           bool field_valid = m_state.ledger_state.valid;
           bool field_stale = m_state.ledger_state.stale;
           m_cards[idx].fields[health_field_idx] = field_value;
           m_cards[idx].field_labels[health_field_idx] = health_labels[2];
           m_cards[idx].field_colors[health_field_idx] = (field_valid && !field_stale) ? "GREEN" : (field_stale ? "AMBER" : "RED");
           health_field_idx++;
          }
          
          // Chart Registration (always show)
          {
           string field_value = m_state.chart_registration_state.value;
           bool field_valid = m_state.chart_registration_state.valid;
           bool field_stale = m_state.chart_registration_state.stale;
           m_cards[idx].fields[health_field_idx] = field_value;
           m_cards[idx].field_labels[health_field_idx] = health_labels[3];
           m_cards[idx].field_colors[health_field_idx] = (field_valid && !field_stale) ? "GREEN" : (field_stale ? "AMBER" : "RED");
           health_field_idx++;
          }
          
          m_cards[idx].visible = true;
          m_cards[idx].priority = 8;
         }

      if(m_view_mode == 0) // FULL only
        {
         // ------------------------------------------------------------------
         // CARD: Diagnostics - FULL mode AND when m_show_diagnostics is true
         // ------------------------------------------------------------------
         if(m_show_diagnostics)
           {
            idx = m_card_count++;
            m_cards[idx].type = CARD_DIAGNOSTICS;
            m_cards[idx].title = "DIAGNOSTICS";
            m_cards[idx].subtitle = "Full System Health Details";
            string diag_labels[10];
            diag_labels[0] = "COORDINATOR";
            diag_labels[1] = "AUTHORITY";
            diag_labels[2] = "LEDGER";
            diag_labels[3] = "CHART REG";
            diag_labels[4] = "SNAPSHOT";
            diag_labels[5] = "EXT RISK LOCK";
            diag_labels[6] = "BLOCKED BY";
            diag_labels[7] = "LAST OK";
            diag_labels[8] = "ACTION";
            diag_labels[9] = "REASON";

            for(int i = 0; i < 10; i++)
              {
               string field_value = "";
               bool field_valid = false;
               bool field_stale = false;
               if(i == 0) { field_value = m_state.coordinator_state.value; field_valid = m_state.coordinator_state.valid; field_stale = m_state.coordinator_state.stale; }
               else if(i == 1) { field_value = m_state.authority_state.value; field_valid = m_state.authority_state.valid; field_stale = m_state.authority_state.stale; }
               else if(i == 2) { field_value = m_state.ledger_state.value; field_valid = m_state.ledger_state.valid; field_stale = m_state.ledger_state.stale; }
               else if(i == 3) { field_value = m_state.chart_registration_state.value; field_valid = m_state.chart_registration_state.valid; field_stale = m_state.chart_registration_state.stale; }
               else if(i == 4) { field_value = m_state.snapshot_state.value; field_valid = m_state.snapshot_state.valid; field_stale = m_state.snapshot_state.stale; }
               else if(i == 5) { field_value = m_state.external_risk_lock_state.value; field_valid = m_state.external_risk_lock_state.valid; field_stale = m_state.external_risk_lock_state.stale; }
               else if(i == 6) { field_value = m_state.blocking_subsystem.value; field_valid = m_state.blocking_subsystem.valid; field_stale = m_state.blocking_subsystem.stale; }
               else if(i == 7) { field_value = m_state.last_successful_stage.value; field_valid = m_state.last_successful_stage.valid; field_stale = m_state.last_successful_stage.stale; }
               else if(i == 8) { field_value = m_state.action_required.value; field_valid = m_state.action_required.valid; field_stale = m_state.action_required.stale; }
               else if(i == 9) { field_value = m_state.reason.value; field_valid = m_state.reason.valid; field_stale = m_state.reason.stale; }
               m_cards[idx].fields[i] = field_value;
               m_cards[idx].field_labels[i] = diag_labels[i];
               m_cards[idx].field_colors[i] = (field_valid && !field_stale) ? "GREEN" : (field_stale ? "AMBER" : "RED");
              }
            m_cards[idx].visible = true;
            m_cards[idx].priority = 15;
           }

         // ------------------------------------------------------------------
         // CARD: Retry/Review - FULL mode AND when active
         // ------------------------------------------------------------------
         if(m_state.m_retry_ui_state.ui_state != 0)
           {
            idx = m_card_count++;
            m_cards[idx].type = CARD_RETRY_REVIEW;
            m_cards[idx].title = "RETRY / REVIEW";
            m_cards[idx].status_badge = m_state.m_retry_ui_state.status;
            m_cards[idx].status_color = "GOLD";
            m_cards[idx].full_reason = m_state.m_retry_ui_state.detail;
            if(m_state.m_retry_ui_state.review_valid)
              {
               m_cards[idx].action_text = "cand[" + IntegerToString(m_state.m_retry_ui_state.candidate_index + 1) + "/" +
                                          IntegerToString(m_state.m_retry_ui_state.candidate_count) + "] " +
                                          m_state.m_retry_ui_state.review_symbol + " dir=" +
                                          IntegerToString(m_state.m_retry_ui_state.review_direction) +
                                          " claim=" + m_state.m_retry_ui_state.review_claim_id +
                                          " prior=" + m_state.m_retry_ui_state.review_prior_attempt_id +
                                          " seq=" + IntegerToString(m_state.m_retry_ui_state.review_retry_sequence) +
                                          " class=" + m_state.m_retry_ui_state.review_failure_class +
                                          " ret=" + IntegerToString(m_state.m_retry_ui_state.review_retcode) +
                                          " ord=" + IntegerToString(m_state.m_retry_ui_state.review_broker_order_ticket) +
                                          " deal=" + IntegerToString(m_state.m_retry_ui_state.review_broker_deal_ticket) +
                                          " pos=" + IntegerToString(m_state.m_retry_ui_state.review_broker_position_ticket) +
                                          " ev=" + m_state.m_retry_ui_state.review_evidence_reason;
              }
            else
              {
               m_cards[idx].action_text = m_state.m_retry_ui_state.detail;
              }
            m_cards[idx].visible = true;
            m_cards[idx].priority = 20;
           }
        }
      else if(m_view_mode == 1 && m_state.m_retry_ui_state.ui_state != 0) // NORMAL mode with active retry
        {
         // ------------------------------------------------------------------
         // CARD: Retry Summary - NORMAL mode when active (condensed)
         // ------------------------------------------------------------------
         idx = m_card_count++;
         m_cards[idx].type = CARD_RETRY_REVIEW;
         m_cards[idx].title = "RETRY";
         m_cards[idx].status_badge = m_state.m_retry_ui_state.status;
         m_cards[idx].status_color = "GOLD";
         m_cards[idx].full_reason = m_state.m_retry_ui_state.detail;
         // Condensed action text for NORMAL
         if(m_state.m_retry_ui_state.review_valid)
           {
            m_cards[idx].action_text = m_state.m_retry_ui_state.review_symbol + " " +
                                       IntegerToString(m_state.m_retry_ui_state.review_direction) + " " +
                                       "cand[" + IntegerToString(m_state.m_retry_ui_state.candidate_index + 1) + "/" +
                                       IntegerToString(m_state.m_retry_ui_state.candidate_count) + "]";
           }
         m_cards[idx].visible = true;
         m_cards[idx].priority = 12;
        }

      // ============================================================
      // Diagnostics toggle for NORMAL mode - concise summary
      // ============================================================
      if(m_view_mode == 1 && m_show_diagnostics)
        {
         // Add a concise diagnostic line to System Health card
         // We'll append key diagnostic info to the HEALTH card's fields
         // Find the HEALTH card (type CARD_SYSTEM_HEALTH)
         for(int h = 0; h < m_card_count; h++)
           {
            if(m_cards[h].type == CARD_SYSTEM_HEALTH)
              {
               // Add ERL and Snapshot status as extra fields
               int next_field = 4; // After COORD, AUTH, LEDGER, CHART
               m_cards[h].fields[next_field] = m_state.external_risk_lock_state.value;
               m_cards[h].field_labels[next_field] = "ERL";
               m_cards[h].field_colors[next_field] = FieldStateColor(m_state.external_risk_lock_state);
               next_field++;
               m_cards[h].fields[next_field] = m_state.snapshot_state.value;
               m_cards[h].field_labels[next_field] = "SNAP";
               m_cards[h].field_colors[next_field] = FieldStateColor(m_state.snapshot_state);
               break;
              }
           }
        }
     }

   // Measure a single card's required height - ONLY counts actual content lines
   // content_w_override: if >0, use this instead of panel width (for grid cards)
   int MeasureCardHeight(const int card_idx, const int content_w_override = 0)
     {
      if(card_idx < 0 || card_idx >= m_card_count) return 0;
      CardContent card = m_cards[card_idx]; // Copy - MQL5 doesn't allow ref to array element
      int font_size = 0;
      string font_name = m_theme.font_family;

      switch(card.type)
        {
         case CARD_HEADER:
            font_size = m_theme.font_size_header;
            break;
         case CARD_SYSTEM_STATUS:
            font_size = m_theme.font_size_status;
            break;
         case CARD_STRATEGY_PRIMARY:
         case CARD_STRATEGY_STAGE:
            font_size = m_theme.font_size_base;
            break;
         case CARD_SYSTEM_HEALTH:
            font_size = m_theme.font_size_base - 1;
            break;
         case CARD_DIAGNOSTICS:
            font_size = m_theme.font_size_diagnostics;
            break;
         case CARD_RETRY_REVIEW:
            font_size = m_theme.font_size_retry;
            break;
default:
             font_size = m_theme.font_size_base;
         }

       int content_w = (content_w_override > 0) ? content_w_override : GetDefaultContentWidth();

       int total_lines = 0;
      string lines[MAX_WRAP_LINES];
      int line_count = 0;

      // Title line(s) - only if title exists
      if(card.title != "")
        {
         WrapText(card.title, content_w, font_size, font_name, lines, line_count);
         total_lines += line_count; // line_count is 0 if empty after wrap
        }

      // Subtitle line(s) - only if subtitle exists
      if(card.subtitle != "")
        {
         line_count = 0;
         WrapText(card.subtitle, content_w, font_size - 1, font_name, lines, line_count);
         total_lines += line_count;
        }

      // Status badge - only if exists
      if(card.status_badge != "")
        {
         line_count = 0;
         WrapText(card.status_badge, content_w, font_size, font_name, lines, line_count);
         total_lines += line_count;
        }

      // Full reason - only if exists
      if(card.full_reason != "")
        {
         line_count = 0;
         WrapText(card.full_reason, content_w, font_size - 1, font_name, lines, line_count);
         total_lines += line_count;
        }

      // Action text - only if exists
      if(card.action_text != "")
        {
         line_count = 0;
         WrapText(card.action_text, content_w, font_size - 1, font_name, lines, line_count);
         total_lines += line_count;
        }

      // Fields (for Strategy and Diagnostics cards) - only non-empty fields
      for(int i = 0; i < 16; i++)
        {
         if(card.fields[i] == "") continue;
         line_count = 0;
         string display = "";
         if(card.field_labels[i] != "")
           display = card.field_labels[i] + ": " + card.fields[i];
         else
           display = card.fields[i];
         WrapText(display, content_w, font_size - 1, font_name, lines, line_count);
         total_lines += line_count;
        }

      // Buttons (Retry card) - measure actual button height, not 1 line
      if(card.type == CARD_RETRY_REVIEW && m_state.m_retry_ui_state.ui_state != 0)
        {
         int btn_h = font_size + 8;
         total_lines += (btn_h + 4) / (font_size + 4); // Convert button height to line equivalents
        }

      // Minimum 1 line for card container
      if(total_lines == 0) total_lines = 1;

      int line_h = font_size + 4; // line height with padding (derived from font)
      int height = total_lines * line_h + 2 * m_theme.card_padding;
      return height;
     }

// Calculate Strategy card grid layout (1/2/3+ columns) based on measured fit
    // Returns optimal column count that fits within panel_width
    void CalculateStrategyGrid(int& cols, int& rows, int card_count, int panel_width)
      {
        if(card_count <= 0)
          {
           cols = 1;
           rows = 0;
           return;
          }

        int min_card_w = m_theme.min_card_width;
        int available_w = panel_width - 2 * m_theme.card_padding;
        if(available_w < min_card_w) available_w = min_card_w;

        // Calculate maximum columns that can fit based on measured minimum card width
        // Max columns = floor((available_w + card_spacing) / (min_card_w + card_spacing))
        // But never more than card_count
        int max_fit_cols = (available_w + m_theme.card_spacing) / (min_card_w + m_theme.card_spacing);
        if(max_fit_cols < 1) max_fit_cols = 1;
        int max_possible_cols = (card_count < max_fit_cols) ? card_count : max_fit_cols;
        
        // Try columns from max down to 1, pick first that fits
        for(int test_cols = max_possible_cols; test_cols >= 1; test_cols--)
          {
           int spacing_needed = (test_cols - 1) * m_theme.card_spacing;
           int col_w = (available_w - spacing_needed) / test_cols;
           
           if(col_w >= min_card_w)
             {
              cols = test_cols;
              rows = (card_count + cols - 1) / cols;
              return;
             }
          }

        // Fallback: single column (should always fit min_card_w)
        cols = 1;
        rows = card_count;
       }

// Layout all cards - calculate positions and dimensions
    // Render order: Header -> System Status -> Primary Strategy -> Stage -> Health -> Diagnostics -> Retry
    void LayoutCards()
      {
       if(!m_layout.valid) return;

       int x = m_layout.panel_x;
       int y = m_layout.panel_y;
       int panel_w = m_layout.panel_width;
       int content_w = GetContentWidth(panel_w);

       // Track indices for different card groups in RENDER PRIORITY ORDER
       int header_indices[2];
       int header_count = 0;
       int primary_strategy_indices[5];
       int primary_strat_count = 0;
       int stage_strategy_indices[1];
       int stage_strat_count = 0;
       int health_indices[2];
       int health_count = 0;
       int diagnostics_indices[1];
       int diagnostics_count = 0;
       int retry_indices[1];
       int retry_count = 0;

       for(int i = 0; i < m_card_count; i++)
         {
          if(!m_cards[i].visible) continue;
          
          if(m_cards[i].type == CARD_HEADER)
            {
             if(header_count < 2) header_indices[header_count++] = i;
            }
          else if(m_cards[i].type == CARD_SYSTEM_STATUS)
            {
             if(header_count < 2) header_indices[header_count++] = i; // System Status grouped with Header
            }
          else if(m_cards[i].type == CARD_STRATEGY_PRIMARY)
            {
             if(primary_strat_count < 5) primary_strategy_indices[primary_strat_count++] = i;
            }
          else if(m_cards[i].type == CARD_STRATEGY_STAGE)
            {
             if(stage_strat_count < 1) stage_strategy_indices[stage_strat_count++] = i;
            }
          else if(m_cards[i].type == CARD_SYSTEM_HEALTH)
            {
             if(health_count < 2) health_indices[health_count++] = i;
            }
          else if(m_cards[i].type == CARD_DIAGNOSTICS)
            {
             if(diagnostics_count < 1) diagnostics_indices[diagnostics_count++] = i;
            }
          else if(m_cards[i].type == CARD_RETRY_REVIEW)
            {
             if(retry_count < 1) retry_indices[retry_count++] = i;
            }
         }

// ============================================================
        // LAYOUT IN PRIORITY ORDER (top to bottom)
        // ============================================================
        
        // Maximum Y position (clamp to chart height with bottom margin)
        int max_y = m_layout.chart_height - m_theme.panel_margin;
        bool space_exhausted = false;
        
        // 1. Header + System Status (single column, full width) - ALWAYS shown
        for(int i = 0; i < header_count; i++)
          {
           int idx = header_indices[i];
           CardGeometry g = m_card_geom[idx];
           g.x = x;
           g.y = y;
           g.width = panel_w;
           g.content_width = content_w;
           g.height = MeasureCardHeight(idx);
           g.valid = true;
           m_card_geom[idx] = g;
           y += g.height + m_theme.card_spacing;
          }
        
// 2. PRIMARY Strategy cards (5 fields) in adaptive grid - IMMEDIATELY after Status - ALWAYS shown (never hidden)
        if(primary_strat_count > 0)
          {
           int cols, rows;
           CalculateStrategyGrid(cols, rows, primary_strat_count, panel_w);
           int card_w = (content_w - (cols - 1) * m_theme.card_spacing) / cols;
           if(card_w < m_theme.min_card_width) card_w = m_theme.min_card_width;
           int card_content_w = card_w - 2 * m_theme.card_padding;
           
           int max_card_h = 0;
           // First pass: measure all heights with actual card content width
           for(int i = 0; i < primary_strat_count; i++)
             {
              int idx = primary_strategy_indices[i];
              int h = MeasureCardHeight(idx, card_content_w);
              if(h > max_card_h) max_card_h = h;
             }
           
           // Primary strategy cards are ALWAYS rendered - no space check
           // Second pass: position in grid
           for(int i = 0; i < primary_strat_count; i++)
             {
              int idx = primary_strategy_indices[i];
              CardGeometry g2 = m_card_geom[idx];
              int col = i % cols;
              int row = i / cols;
              g2.x = x + col * (card_w + m_theme.card_spacing);
              g2.y = y + row * (max_card_h + m_theme.card_spacing);
              g2.width = card_w;
              g2.content_width = card_content_w;
              g2.height = max_card_h;
              g2.valid = true;
              m_card_geom[idx] = g2;
             }
           
           y += max_card_h * rows + (rows - 1) * m_theme.card_spacing + m_theme.card_spacing;
          }
        
// 3. STAGE Strategy card (if present) - single card below primary grid - HIGH PRIORITY (always shown)
        if(stage_strat_count > 0)
          {
           int idx = stage_strategy_indices[0];
           int h = MeasureCardHeight(idx);
           // Stage is HIGH PRIORITY - always render
           CardGeometry g3 = m_card_geom[idx];
           g3.x = x;
           g3.y = y;
           g3.width = panel_w;
           g3.content_width = content_w;
           g3.height = h;
           g3.valid = true;
           m_card_geom[idx] = g3;
           y += h + m_theme.card_spacing;
          }
        
        // 4. System Health cards - MEDIUM PRIORITY (show if space permits)
        for(int i = 0; i < health_count && !space_exhausted; i++)
          {
           int idx = health_indices[i];
int h = MeasureCardHeight(idx);
            if(!(y + h <= max_y))
              {
               space_exhausted = true;
               m_cards[idx].visible = false; // Hide this and remaining health cards
              }
           else
             {
              CardGeometry g4 = m_card_geom[idx];
              g4.x = x;
              g4.y = y;
              g4.width = panel_w;
              g4.content_width = content_w;
              g4.height = h;
              g4.valid = true;
              m_card_geom[idx] = g4;
              y += h + m_theme.card_spacing;
             }
          }
        
        // 5. Diagnostics cards (FULL mode only) - LOW PRIORITY (show if space permits)
        for(int i = 0; i < diagnostics_count && !space_exhausted; i++)
          {
           int idx = diagnostics_indices[i];
int h = MeasureCardHeight(idx);
            if(!(y + h <= max_y))
              {
               space_exhausted = true;
               m_cards[idx].visible = false; // Hide diagnostics
              }
           else
             {
              CardGeometry g5 = m_card_geom[idx];
              g5.x = x;
              g5.y = y;
              g5.width = panel_w;
              g5.content_width = content_w;
              g5.height = h;
              g5.valid = true;
              m_card_geom[idx] = g5;
              y += h + m_theme.card_spacing;
             }
          }
        
        // 6. Retry/Review cards - LOW PRIORITY (show if space permits)
        for(int i = 0; i < retry_count && !space_exhausted; i++)
          {
           int idx = retry_indices[i];
int h = MeasureCardHeight(idx);
            if(!(y + h <= max_y))
              {
               space_exhausted = true;
              m_cards[idx].visible = false; // Hide retry
             }
           else
             {
              CardGeometry g6 = m_card_geom[idx];
              g6.x = x;
              g6.y = y;
              g6.width = panel_w;
              g6.content_width = content_w;
              g6.height = h;
              g6.valid = true;
              m_card_geom[idx] = g6;
              y += h + m_theme.card_spacing;
             }
          }

// Update panel height to fit all cards exactly, clamped to chart boundaries
        // Formula: top_margin (panel_y) + sum(card_heights) + (num_visible_cards - 1) * card_spacing + bottom_padding
        int visible_card_count = 0;
        for(int vc = 0; vc < m_card_count; vc++)
          {
           if(m_cards[vc].visible && m_card_geom[vc].valid) visible_card_count++;
          }
        int total_h = m_theme.panel_margin; // top margin (matches panel_y)
        for(int vc = 0; vc < m_card_count; vc++)
          {
           if(m_cards[vc].visible && m_card_geom[vc].valid)
             {
              total_h += m_card_geom[vc].height;
             }
          }
        if(visible_card_count > 1) total_h += (visible_card_count - 1) * m_theme.card_spacing;
        total_h += m_theme.panel_margin / 2; // reduced bottom padding (was full panel_margin)
        int max_h = m_layout.chart_height - m_theme.panel_margin;
        if(total_h > max_h) total_h = max_h;
        if(total_h < m_theme.min_card_width * 2) total_h = m_theme.min_card_width * 2;
        m_layout.panel_height = total_h;
      }

   // --- Renderer ---

// Create background panel
    void CreateBackground()
      {
       if(ObjectFind(m_chart_id, m_bg_name) < 0)
         {
          if(!ObjectCreate(m_chart_id, m_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return;
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XDISTANCE, m_layout.panel_x);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YDISTANCE, m_layout.panel_y);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XSIZE, m_layout.panel_width);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YSIZE, m_layout.panel_height);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BGCOLOR, m_theme.bg_panel);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_COLOR, m_theme.border_card);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_BACK, false);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_SELECTABLE, false);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_HIDDEN, false);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_ZORDER, 10);
         }
else if(m_layout.valid)
         {
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XDISTANCE, m_layout.panel_x);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YDISTANCE, m_layout.panel_y);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_XSIZE, m_layout.panel_width);
          ObjectSetInteger(m_chart_id, m_bg_name, OBJPROP_YSIZE, m_layout.panel_height);
         }
     }

   // Render a single card
   void RenderCard(const CardContent& card, const CardGeometry& geom, int base_label_idx)
     {
      if(!geom.valid) return;

      int font_size = 0;
      color title_color = m_theme.text_primary;
      color subtitle_color = m_theme.text_secondary;
      color value_color = m_theme.text_primary;

      switch(card.type)
        {
         case CARD_HEADER:
            font_size = m_theme.font_size_header;
            break;
         case CARD_SYSTEM_STATUS:
            font_size = m_theme.font_size_status;
            break;
         case CARD_STRATEGY_PRIMARY:
         case CARD_STRATEGY_STAGE:
            font_size = m_theme.font_size_base;
            break;
         case CARD_SYSTEM_HEALTH:
            font_size = m_theme.font_size_base - 1;
            break;
         case CARD_DIAGNOSTICS:
            font_size = m_theme.font_size_diagnostics;
            break;
         case CARD_RETRY_REVIEW:
            font_size = m_theme.font_size_retry;
            break;
        }

      int label_idx = base_label_idx;
      int cur_y = geom.y + m_theme.card_padding;
      int line_h = font_size + 4;
      int content_x = geom.x + m_theme.card_padding;

      // Card background (tracked for cleanup)
      int card_bg_idx = -1;
      string card_bg_name = GetOrCreateCardBg(card_bg_idx);
      if(card_bg_name != "")
        {
         ObjectSetInteger(m_chart_id, card_bg_name, OBJPROP_XDISTANCE, geom.x);
         ObjectSetInteger(m_chart_id, card_bg_name, OBJPROP_YDISTANCE, geom.y);
         ObjectSetInteger(m_chart_id, card_bg_name, OBJPROP_XSIZE, geom.width);
         ObjectSetInteger(m_chart_id, card_bg_name, OBJPROP_YSIZE, geom.height);
        }

      // Title
      string lines[MAX_WRAP_LINES];
      int line_count = 0;
      if(card.title != "")
        {
         WrapText(card.title, geom.content_width, font_size, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               SetLabelProps(name, lines[li], "CHARCOAL", font_size);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Subtitle
      if(card.subtitle != "")
        {
         line_count = 0;
         WrapText(card.subtitle, geom.content_width, font_size - 1, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               SetLabelProps(name, lines[li], "SILVER", font_size - 1);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Status badge (System Status, Retry)
      if(card.status_badge != "")
        {
         line_count = 0;
         WrapText(card.status_badge, geom.content_width, font_size, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               SetLabelProps(name, lines[li], card.status_color, font_size);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Full reason
      if(card.full_reason != "")
        {
         line_count = 0;
         WrapText(card.full_reason, geom.content_width, font_size - 1, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               SetLabelProps(name, lines[li], "SILVER", font_size - 1);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Action text
      if(card.action_text != "")
        {
         line_count = 0;
         WrapText(card.action_text, geom.content_width, font_size - 1, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               SetLabelProps(name, lines[li], "LIME", font_size - 1);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Fields (Strategy, Diagnostics, Health)
      for(int i = 0; i < 16; i++)
        {
         if(card.fields[i] == "") continue;
         line_count = 0;
         string display = "";
         if(card.field_labels[i] != "")
           display = card.field_labels[i] + ": " + card.fields[i];
         else
           display = card.fields[i];
         WrapText(display, geom.content_width, font_size - 1, m_theme.font_family, lines, line_count);
         for(int li = 0; li < line_count; li++)
           {
            string name = GetOrCreateLabel(label_idx);
            if(name != "")
              {
               string txt_color = "GREY";
               if(card.field_colors[i] != "")
                 txt_color = card.field_colors[i];
               SetLabelProps(name, lines[li], txt_color, font_size - 1);
               ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, content_x);
               ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, cur_y);
               cur_y += line_h;
               label_idx++;
              }
           }
        }

      // Buttons (Retry card) - use exact names expected by EA click router
      if(card.type == CARD_RETRY_REVIEW && m_state.m_retry_ui_state.ui_state != 0)
        {
         string btn_captions[5] = { "Inspect", "Review", "Next", "Confirm", "Cancel" };
         string btn_suffixes[5] = { "INSPECT", "REVIEW", "NEXT", "CONFIRM", "CANCEL" };
         bool btn_enabled[5] = {
            true,
            m_state.m_retry_ui_state.review_valid,
            m_state.m_retry_ui_state.candidate_count > 1,
            (m_state.m_retry_ui_state.ui_state == RETRY_UI_CONFIRM_READY && m_state.m_retry_ui_state.review_valid),
            true
           };
         color btn_bg[5] = {
            m_theme.btn_primary,
            m_theme.btn_primary,
            m_theme.btn_primary,
            m_theme.btn_confirm,
            m_theme.btn_cancel
           };

         int btn_y = cur_y + 4;
         int btn_x = content_x;
         int btn_h = font_size + 8;
         int max_btn_idx_used = -1;

         for(int bi = 0; bi < 5; bi++)
           {
            int btn_idx = -1;
            string btn_name = GetOrCreateRetryButton(btn_suffixes[bi], btn_idx);
            if(btn_name != "")
              {
               if(btn_idx > max_btn_idx_used) max_btn_idx_used = btn_idx;
               int btn_w = CalcButtonWidth(btn_captions[bi], font_size);
               SetButtonProps(btn_name, btn_captions[bi], btn_x, btn_y, btn_w, btn_h,
                             btn_bg[bi], clrWhite, btn_enabled[bi]);
               btn_x += btn_w + 6;
              }
           }
         if(max_btn_idx_used >= m_next_btn_index) m_next_btn_index = max_btn_idx_used + 1;
        }

      m_next_label_index = label_idx;
     }

   // Delete unused objects (not hide - DELETE to prevent ghost objects)
   void CleanupUnusedObjects()
     {
      // Delete unused labels
      for(int i = m_next_label_index; i < m_label_count; i++)
        {
         if(m_label_names[i] != "" && ObjectFind(m_chart_id, m_label_names[i]) >= 0)
           {
            ObjectDelete(m_chart_id, m_label_names[i]);
            m_label_names[i] = "";
           }
        }

      // Delete unused buttons
      for(int i = m_next_btn_index; i < 32; i++)
        {
         if(m_btn_names[i] != "" && ObjectFind(m_chart_id, m_btn_names[i]) >= 0)
           {
            ObjectDelete(m_chart_id, m_btn_names[i]);
            m_btn_names[i] = "";
           }
        }

// Delete unused card backgrounds
      for(int i = m_card_count; i < m_card_bg_count; i++)
        {
         if(m_card_bg_names[i] != "" && ObjectFind(m_chart_id, m_card_bg_names[i]) >= 0)
           {
            ObjectDelete(m_chart_id, m_card_bg_names[i]);
            m_card_bg_names[i] = "";
           }
        }
      }

    public:
    // Unified render - single authoritative entry point
    void Render()
     {
      if(!m_enabled) return;

      // Throttling
      ulong now_tick = GetTickCount64();
      if(!m_dirty && !m_force_render)
        {
         if(m_last_render_tick > 0 && (now_tick - m_last_render_tick) < (ulong)m_render_interval_ms)
           return;
        }

long chart_id = ChartID();
       if(m_chart_id != chart_id || m_bg_name == "")
         {
          // Chart changed or first render - clean up old chart's objects first
          if(m_chart_id != 0 && m_chart_id != chart_id)
            {
             if(m_object_prefix != "")
               {
                ObjectsDeleteAll(m_chart_id, m_object_prefix);
               }
             if(m_retry_btn_prefix != "")
               {
                ObjectsDeleteAll(m_chart_id, m_retry_btn_prefix);
               }
            }
          
          m_chart_id = chart_id;
          m_bg_name = "AlgoHybridDashboard_BG_" + IntegerToString((int)chart_id);
          m_object_prefix = "AlgoHybridDB_" + IntegerToString((int)chart_id) + "_";
          m_retry_btn_prefix = "AlgoE2E6Retry_" + IntegerToString((int)chart_id) + "_";
          
          // Reset label names on chart change
          for(int i = 0; i < m_label_count; i++) m_label_names[i] = "";
          for(int i = 0; i < 32; i++) { m_btn_names[i] = ""; m_card_bg_names[i] = ""; }
          m_next_label_index = 0;
          m_next_btn_index = 0;
          m_card_bg_count = 0;
         }

      InitializeTheme(); // ViewMode-aware font sizes (must be before layout)

      BuildCardContent();        // Build content FIRST so layout can measure it
      RecalculateDashboardLayout(); // Now layout can measure actual content
      if(!m_layout.valid) return;

      LayoutCards();
      CreateBackground();

      m_next_label_index = 0;
      m_next_btn_index = 0;

      // Render all cards in priority order
      int render_order[24];
      for(int i = 0; i < m_card_count; i++) render_order[i] = i;
      // Simple bubble sort on indices by priority
      for(int i = 0; i < m_card_count - 1; i++)
        {
         for(int j = 0; j < m_card_count - i - 1; j++)
           {
            if(m_cards[render_order[j]].priority > m_cards[render_order[j + 1]].priority)
              {
               int tmp = render_order[j];
               render_order[j] = render_order[j + 1];
               render_order[j + 1] = tmp;
              }
           }
        }

      for(int i = 0; i < m_card_count; i++)
        {
         int idx = render_order[i];
         if(m_cards[idx].visible && m_card_geom[idx].valid)
           RenderCard(m_cards[idx], m_card_geom[idx], m_next_label_index);
        }

      // Delete (not hide) unused objects to prevent ghost/dotted artifacts
      CleanupUnusedObjects();

      m_last_render_tick = now_tick;
      m_dirty = false;
      m_force_render = false;
      ChartRedraw(m_chart_id);
     }

};

#endif