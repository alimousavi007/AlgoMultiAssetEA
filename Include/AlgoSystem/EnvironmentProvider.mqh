#ifndef __ALGOSYSTEM_ENVIRONMENTPROVIDER_MQH__
#define __ALGOSYSTEM_ENVIRONMENTPROVIDER_MQH__

#include "Types.mqh"
#include "ExecutionLedger.mqh"

//+------------------------------------------------------------------+
//| Abstract Environment Provider for PortfolioRisk                  |
//| Provides testable access to terminal/account/market data         |
//+------------------------------------------------------------------+
class IEnvironmentProvider
  {
public:
   virtual ~IEnvironmentProvider() {}

   // Account information
   virtual double GetAccountEquity() const = 0;
   virtual double GetAccountBalance() const = 0;
   virtual double GetAccountFreeMargin() const = 0;
   virtual bool   IsAccountTradeAllowed() const = 0;
   virtual bool   IsAccountTradeExpert() const = 0;
   virtual long   GetAccountLogin() const = 0;
   virtual string GetAccountServer() const = 0;
   virtual string GetAccountCurrency() const = 0;

// Positions
    virtual int    GetPositionsTotal() const = 0;
    virtual ulong  GetPositionTicket(const int index) const = 0;
    virtual bool   PositionSelectByTicket(const ulong ticket) = 0;
    virtual string PositionGetSymbol() const = 0;
    virtual long   PositionGetMagic() const = 0;
    virtual double PositionGetVolume() const = 0;
    virtual double PositionGetPriceOpen() const = 0;
    virtual double PositionGetSL() const = 0;
    virtual double PositionGetTP() const = 0;
    virtual ENUM_POSITION_TYPE PositionGetType() const = 0;
    virtual long   PositionGetIdentifier() const = 0;

    // Orders
    virtual int    GetOrdersTotal() const = 0;
    virtual ulong  GetOrderTicket(const int index) const = 0;
    virtual bool   OrderSelect(const ulong ticket) = 0;
    virtual string OrderGetSymbol() const = 0;
    virtual long   OrderGetMagic() const = 0;
    virtual ENUM_ORDER_TYPE OrderGetType() const = 0;
    virtual double OrderGetVolumeCurrent() const = 0;
    virtual double OrderGetPriceOpen() const = 0;
    virtual double OrderGetSL() const = 0;

    // History
    virtual bool   HistorySelect(const datetime from, const datetime to) = 0;
    virtual int    HistoryDealsTotal() const = 0;
    virtual ulong  HistoryDealGetTicket(const int index) const = 0;
    virtual bool   HistoryDealSelect(const ulong ticket) = 0;
    virtual string HistoryDealGetSymbol(const ulong ticket) const = 0;
    virtual long   HistoryDealGetMagic(const ulong ticket) const = 0;
    virtual datetime HistoryDealGetTime(const ulong ticket) const = 0;
    virtual double HistoryDealGetVolume(const ulong ticket) const = 0;
    virtual long   HistoryDealGetPositionId(const ulong ticket) const = 0;
    virtual long   HistoryDealGetOrder(const ulong ticket) const = 0;
    virtual int    HistoryOrdersTotal() const = 0;
    virtual ulong  HistoryOrderGetTicket(const int index) const = 0;
    virtual bool   HistoryOrderSelect(const ulong ticket) = 0;
    virtual string HistoryOrderGetSymbol(const ulong ticket) const = 0;
    virtual long   HistoryOrderGetMagic(const ulong ticket) const = 0;
    virtual datetime HistoryOrderGetTimeSetup(const ulong ticket) const = 0;
    virtual long   HistoryOrderGetPositionId(const ulong ticket) const = 0;

   // Symbol information
   virtual bool   SymbolExist(const string symbol) const = 0;
   virtual bool   SymbolSelect(const string symbol, const bool select) const = 0;
   virtual bool   SymbolIsSynchronized(const string symbol) const = 0;
   virtual bool   SymbolInfoTick(const string symbol, MqlTick &tick) const = 0;
   virtual double SymbolInfoDouble(const string symbol, const int prop_id) const = 0;
   virtual long   SymbolInfoInteger(const string symbol, const int prop_id) const = 0;

   // Calculation
   virtual bool   OrderCalcProfit(const ENUM_ORDER_TYPE order_type,
                                  const string symbol,
                                  const double volume,
                                  const double price_open,
                                  const double price_sl,
                                  double &profit) const = 0;
   virtual bool   OrderCalcMargin(const ENUM_ORDER_TYPE order_type,
                                  const string symbol,
                                  const double volume,
                                  const double price,
                                  double &margin) const = 0;

   // Time
   virtual datetime TimeCurrent() const = 0;

   // Execution Ledger access (for magic ownership resolution)
   virtual CExecutionLedger* GetExecutionLedger() const = 0;
   virtual string GetAccountKey() const = 0;
  };

//+------------------------------------------------------------------+
//| Native Environment Provider - Production Implementation          |
//| Directly calls MQL5 terminal APIs                                |
//+------------------------------------------------------------------+
class CNativeEnvironmentProvider : public IEnvironmentProvider
  {
private:
   CExecutionLedger *m_execution_ledger;
   string            m_account_key;

public:
   CNativeEnvironmentProvider()
     : m_execution_ledger(NULL), m_account_key("") {}

   void SetExecutionLedger(CExecutionLedger *ledger, const string account_key)
     {
      m_execution_ledger = ledger;
      m_account_key = account_key;
     }

   // Account information
   virtual double GetAccountEquity() const override
     { return AccountInfoDouble(ACCOUNT_EQUITY); }
   virtual double GetAccountBalance() const override
     { return AccountInfoDouble(ACCOUNT_BALANCE); }
   virtual double GetAccountFreeMargin() const override
     { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
   virtual bool   IsAccountTradeAllowed() const override
     { return (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED); }
   virtual bool   IsAccountTradeExpert() const override
     { return (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT); }
   virtual long   GetAccountLogin() const override
     { return AccountInfoInteger(ACCOUNT_LOGIN); }
   virtual string GetAccountServer() const override
     { return AccountInfoString(ACCOUNT_SERVER); }
   virtual string GetAccountCurrency() const override
     { return AccountInfoString(ACCOUNT_CURRENCY); }

// Positions
    virtual int    GetPositionsTotal() const override
      { return ::PositionsTotal(); }
    virtual ulong  GetPositionTicket(const int index) const override
      { return ::PositionGetTicket(index); }
    virtual bool   PositionSelectByTicket(const ulong ticket) override
      { return ::PositionSelectByTicket(ticket); }
    virtual string PositionGetSymbol() const override
      { return ::PositionGetString(POSITION_SYMBOL); }
    virtual long   PositionGetMagic() const override
      { return ::PositionGetInteger(POSITION_MAGIC); }
    virtual double PositionGetVolume() const override
      { return ::PositionGetDouble(POSITION_VOLUME); }
    virtual double PositionGetPriceOpen() const override
      { return ::PositionGetDouble(POSITION_PRICE_OPEN); }
    virtual double PositionGetSL() const override
      { return ::PositionGetDouble(POSITION_SL); }
    virtual double PositionGetTP() const override
      { return ::PositionGetDouble(POSITION_TP); }
    virtual ENUM_POSITION_TYPE PositionGetType() const override
      { return (ENUM_POSITION_TYPE)::PositionGetInteger(POSITION_TYPE); }
    virtual long   PositionGetIdentifier() const override
      { return ::PositionGetInteger(POSITION_IDENTIFIER); }

    // Orders
    virtual int    GetOrdersTotal() const override
      { return ::OrdersTotal(); }
    virtual ulong  GetOrderTicket(const int index) const override
      { return ::OrderGetTicket(index); }
    virtual bool   OrderSelect(const ulong ticket) override
      { return ::OrderSelect(ticket); }
    virtual string OrderGetSymbol() const override
      { return ::OrderGetString(ORDER_SYMBOL); }
    virtual long   OrderGetMagic() const override
      { return ::OrderGetInteger(ORDER_MAGIC); }
    virtual ENUM_ORDER_TYPE OrderGetType() const override
      { return (ENUM_ORDER_TYPE)::OrderGetInteger(ORDER_TYPE); }
    virtual double OrderGetVolumeCurrent() const override
      { return ::OrderGetDouble(ORDER_VOLUME_CURRENT); }
    virtual double OrderGetPriceOpen() const override
      { return ::OrderGetDouble(ORDER_PRICE_OPEN); }
    virtual double OrderGetSL() const override
      { return ::OrderGetDouble(ORDER_SL); }

    // History
    virtual bool   HistorySelect(const datetime from, const datetime to) override
      { return ::HistorySelect(from, to); }
    virtual int    HistoryDealsTotal() const override
      { return ::HistoryDealsTotal(); }
    virtual ulong  HistoryDealGetTicket(const int index) const override
      { return ::HistoryDealGetTicket(index); }
    virtual bool   HistoryDealSelect(const ulong ticket) override
      { return ::HistoryDealSelect(ticket); }
    virtual string HistoryDealGetSymbol(const ulong ticket) const override
      { return ::HistoryDealGetString(ticket, DEAL_SYMBOL); }
    virtual long   HistoryDealGetMagic(const ulong ticket) const override
      {
       long magic = 0;
       ::HistoryDealGetInteger(ticket, DEAL_MAGIC, magic);
       return magic;
      }
    virtual datetime HistoryDealGetTime(const ulong ticket) const override
      { return (datetime)::HistoryDealGetInteger(ticket, DEAL_TIME); }
    virtual double HistoryDealGetVolume(const ulong ticket) const override
      { return ::HistoryDealGetDouble(ticket, DEAL_VOLUME); }
    virtual long   HistoryDealGetPositionId(const ulong ticket) const override
      { return ::HistoryDealGetInteger(ticket, DEAL_POSITION_ID); }
    virtual long   HistoryDealGetOrder(const ulong ticket) const override
      { return ::HistoryDealGetInteger(ticket, DEAL_ORDER); }
    virtual int    HistoryOrdersTotal() const override
      { return ::HistoryOrdersTotal(); }
    virtual ulong  HistoryOrderGetTicket(const int index) const override
      { return ::HistoryOrderGetTicket(index); }
    virtual bool   HistoryOrderSelect(const ulong ticket) override
      { return ::HistoryOrderSelect(ticket); }
    virtual string HistoryOrderGetSymbol(const ulong ticket) const override
      { return ::HistoryOrderGetString(ticket, ORDER_SYMBOL); }
    virtual long   HistoryOrderGetMagic(const ulong ticket) const override
      {
       long magic = 0;
       ::HistoryOrderGetInteger(ticket, ORDER_MAGIC, magic);
       return magic;
      }
    virtual datetime HistoryOrderGetTimeSetup(const ulong ticket) const override
      { return (datetime)::HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP); }
    virtual long   HistoryOrderGetPositionId(const ulong ticket) const override
      { return ::HistoryOrderGetInteger(ticket, ORDER_POSITION_ID); }

    // Symbol information
    virtual bool   SymbolExist(const string symbol) const override
      { return ::SymbolInfoInteger(symbol, SYMBOL_SELECT) != 0; }
    virtual bool   SymbolSelect(const string symbol, const bool select) const override
      { return ::SymbolSelect(symbol, select); }
    virtual bool   SymbolIsSynchronized(const string symbol) const override
      { return ::SymbolIsSynchronized(symbol); }
    virtual bool   SymbolInfoTick(const string symbol, MqlTick &tick) const override
      { return ::SymbolInfoTick(symbol, tick); }
    virtual double SymbolInfoDouble(const string symbol, const int prop_id) const override
      { return ::SymbolInfoDouble(symbol, (ENUM_SYMBOL_INFO_DOUBLE)prop_id); }
    virtual long   SymbolInfoInteger(const string symbol, const int prop_id) const override
      { return ::SymbolInfoInteger(symbol, (ENUM_SYMBOL_INFO_INTEGER)prop_id); }

    // Calculation
    virtual bool   OrderCalcProfit(const ENUM_ORDER_TYPE order_type,
                                   const string symbol,
                                   const double volume,
                                   const double price_open,
                                   const double price_sl,
                                   double &profit) const override
      { return ::OrderCalcProfit(order_type, symbol, volume, price_open, price_sl, profit); }
    virtual bool   OrderCalcMargin(const ENUM_ORDER_TYPE order_type,
                                   const string symbol,
                                   const double volume,
                                   const double price,
                                   double &margin) const override
      { return ::OrderCalcMargin(order_type, symbol, volume, price, margin); }

    // Time
    virtual datetime TimeCurrent() const override
      { return ::TimeCurrent(); }

   // Execution Ledger
   virtual CExecutionLedger* GetExecutionLedger() const override
     { return m_execution_ledger; }
   virtual string GetAccountKey() const override
     { return m_account_key; }
  };

//+------------------------------------------------------------------+
//| Fake Environment Provider - Test Implementation                  |
//| Returns controlled test data                                     |
//+------------------------------------------------------------------+
class CFakeEnvironmentProvider : public IEnvironmentProvider
  {
private:
    struct FakePosition
      {
       ulong  ticket;
       string symbol;
       long   magic;
       double volume;
       double price_open;
       double sl;
       double tp;
       ENUM_POSITION_TYPE type;
       long   identifier;
      };

    struct FakeOrder
      {
       ulong         ticket;
       string        symbol;
       long          magic;
       ENUM_ORDER_TYPE type;
       double        volume_current;
       double        price_open;
       double        sl;
      };

    struct FakeDeal
      {
       ulong      ticket;
       string     symbol;
       long       magic;
       datetime   time;
       double     volume;
       long       position_id;
       long       order_ticket;
      };

    struct FakeHistoryOrder
      {
       ulong      ticket;
       string     symbol;
       long       magic;
       datetime   time_setup;
       long       position_id;
      };

    CExecutionLedger *m_execution_ledger;
    string            m_account_key;
    double            m_equity;
    double            m_balance;
    double            m_free_margin;
    bool              m_trade_allowed;
    bool              m_trade_expert;
    long              m_login;
    string            m_server;
    string            m_currency;
    FakePosition      m_positions[];
    FakeOrder         m_orders[];
    FakeDeal          m_deals[];
    FakeHistoryOrder  m_history_orders[];
    int               m_position_index;
    int               m_order_index;
    int               m_deal_index;
    int               m_history_order_index;
    bool              m_history_selected;
    datetime          m_history_from;
    datetime          m_history_to;

public:
   CFakeEnvironmentProvider()
     : m_execution_ledger(NULL)
     , m_account_key("")
     , m_equity(100000.0)
     , m_balance(100000.0)
     , m_free_margin(50000.0)
     , m_trade_allowed(true)
     , m_trade_expert(true)
     , m_login(12345678)
     , m_server("TestServer")
     , m_currency("USD")
     , m_position_index(-1)
     , m_order_index(-1)
     , m_deal_index(-1)
     , m_history_order_index(-1)
     , m_history_selected(false) {}

   void SetExecutionLedger(CExecutionLedger *ledger, const string account_key)
     {
      m_execution_ledger = ledger;
      m_account_key = account_key;
     }

   // Configuration methods for tests
   void SetEquity(const double equity) { m_equity = equity; }
   void SetBalance(const double balance) { m_balance = balance; }
   void SetFreeMargin(const double margin) { m_free_margin = margin; }
   void SetTradeAllowed(const bool allowed) { m_trade_allowed = allowed; }
   void SetTradeExpert(const bool expert) { m_trade_expert = expert; }
   void SetAccountKey(const string key) { m_account_key = key; }
   void SetLogin(const long login) { m_login = login; }
   void SetServer(const string server) { m_server = server; }
   void SetCurrency(const string currency) { m_currency = currency; }

void AddPosition(const ulong ticket, const string symbol, const long magic,
                     const double volume, const double price_open,
                     const double sl, const double tp,
                     const ENUM_POSITION_TYPE type, const long identifier)
      {
       int n = ArraySize(m_positions);
       ArrayResize(m_positions, n + 1);
       m_positions[n].ticket = ticket;
       m_positions[n].symbol = symbol;
       m_positions[n].magic = magic;
       m_positions[n].volume = volume;
       m_positions[n].price_open = price_open;
       m_positions[n].sl = sl;
       m_positions[n].tp = tp;
       m_positions[n].type = type;
       m_positions[n].identifier = identifier;
      }

    void AddOrder(const ulong ticket, const string symbol, const long magic,
                  const ENUM_ORDER_TYPE type, const double volume_current,
                  const double price_open, const double sl)
      {
       int n = ArraySize(m_orders);
       ArrayResize(m_orders, n + 1);
       m_orders[n].ticket = ticket;
       m_orders[n].symbol = symbol;
       m_orders[n].magic = magic;
       m_orders[n].type = type;
       m_orders[n].volume_current = volume_current;
       m_orders[n].price_open = price_open;
       m_orders[n].sl = sl;
      }

    void AddDeal(const ulong ticket, const string symbol, const long magic,
                 const datetime time, const double volume,
                 const long position_id, const long order_ticket)
      {
       int n = ArraySize(m_deals);
       ArrayResize(m_deals, n + 1);
       m_deals[n].ticket = ticket;
       m_deals[n].symbol = symbol;
       m_deals[n].magic = magic;
       m_deals[n].time = time;
       m_deals[n].volume = volume;
       m_deals[n].position_id = position_id;
       m_deals[n].order_ticket = order_ticket;
      }

    void AddHistoryOrder(const ulong ticket, const string symbol, const long magic,
                         const datetime time_setup, const long position_id)
      {
       int n = ArraySize(m_history_orders);
       ArrayResize(m_history_orders, n + 1);
       m_history_orders[n].ticket = ticket;
       m_history_orders[n].symbol = symbol;
       m_history_orders[n].magic = magic;
       m_history_orders[n].time_setup = time_setup;
       m_history_orders[n].position_id = position_id;
      }

   void ClearAll()
     {
      ArrayResize(m_positions, 0);
      ArrayResize(m_orders, 0);
      ArrayResize(m_deals, 0);
      ArrayResize(m_history_orders, 0);
      m_position_index = -1;
      m_order_index = -1;
      m_deal_index = -1;
      m_history_order_index = -1;
      m_history_selected = false;
     }

   // Account information
   virtual double GetAccountEquity() const override { return m_equity; }
   virtual double GetAccountBalance() const override { return m_balance; }
   virtual double GetAccountFreeMargin() const override { return m_free_margin; }
   virtual bool   IsAccountTradeAllowed() const override { return m_trade_allowed; }
   virtual bool   IsAccountTradeExpert() const override { return m_trade_expert; }
   virtual long   GetAccountLogin() const override { return m_login; }
   virtual string GetAccountServer() const override { return m_server; }
   virtual string GetAccountCurrency() const override { return m_currency; }

// Positions
    virtual int    GetPositionsTotal() const override { return ArraySize(m_positions); }
    virtual ulong  GetPositionTicket(const int index) const override
      {
       if(index >= 0 && index < ArraySize(m_positions)) return m_positions[index].ticket;
       return 0;
      }
    virtual bool   PositionSelectByTicket(const ulong ticket) override
      {
       for(int i = 0; i < ArraySize(m_positions); i++)
         if(m_positions[i].ticket == ticket) { m_position_index = i; return true; }
       m_position_index = -1;
       return false;
      }
    virtual string PositionGetSymbol() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].symbol;
       return "";
      }
    virtual long   PositionGetMagic() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].magic;
       return 0;
      }
    virtual double PositionGetVolume() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].volume;
       return 0.0;
      }
    virtual double PositionGetPriceOpen() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].price_open;
       return 0.0;
      }
    virtual double PositionGetSL() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].sl;
       return 0.0;
      }
    virtual double PositionGetTP() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].tp;
       return 0.0;
      }
    virtual ENUM_POSITION_TYPE PositionGetType() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].type;
       return POSITION_TYPE_BUY;
      }
    virtual long   PositionGetIdentifier() const override
      {
       if(m_position_index >= 0 && m_position_index < ArraySize(m_positions))
         return m_positions[m_position_index].identifier;
       return 0;
      }

    // Orders
    virtual int    GetOrdersTotal() const override { return ArraySize(m_orders); }
    virtual ulong  GetOrderTicket(const int index) const override
      {
       if(index >= 0 && index < ArraySize(m_orders)) return m_orders[index].ticket;
       return 0;
      }
    virtual bool   OrderSelect(const ulong ticket) override
      {
       for(int i = 0; i < ArraySize(m_orders); i++)
         if(m_orders[i].ticket == ticket) { m_order_index = i; return true; }
       m_order_index = -1;
       return false;
      }
    virtual string OrderGetSymbol() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].symbol;
       return "";
      }
    virtual long   OrderGetMagic() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].magic;
       return 0;
      }
    virtual ENUM_ORDER_TYPE OrderGetType() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].type;
       return ORDER_TYPE_BUY;
      }
    virtual double OrderGetVolumeCurrent() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].volume_current;
       return 0.0;
      }
    virtual double OrderGetPriceOpen() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].price_open;
       return 0.0;
      }
    virtual double OrderGetSL() const override
      {
       if(m_order_index >= 0 && m_order_index < ArraySize(m_orders))
         return m_orders[m_order_index].sl;
       return 0.0;
      }

    // History
    virtual bool   HistorySelect(const datetime from, const datetime to) override
      {
       m_history_selected = true;
       m_history_from = from;
       m_history_to = to;
       m_deal_index = -1;
       m_history_order_index = -1;
       return true;
      }
    virtual int    HistoryDealsTotal() const override { return ArraySize(m_deals); }
    virtual ulong  HistoryDealGetTicket(const int index) const override
      {
       if(index >= 0 && index < ArraySize(m_deals)) return m_deals[index].ticket;
       return 0;
      }
    virtual bool   HistoryDealSelect(const ulong ticket) override
      {
       for(int i = 0; i < ArraySize(m_deals); i++)
         if(m_deals[i].ticket == ticket) { m_deal_index = i; return true; }
       m_deal_index = -1;
       return false;
      }
    virtual string HistoryDealGetSymbol(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].symbol;
       return "";
      }
    virtual long   HistoryDealGetMagic(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].magic;
       return 0;
      }
    virtual datetime HistoryDealGetTime(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].time;
       return 0;
      }
    virtual double HistoryDealGetVolume(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].volume;
       return 0.0;
      }
    virtual long   HistoryDealGetPositionId(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].position_id;
       return 0;
      }
    virtual long   HistoryDealGetOrder(const ulong ticket) const override
      {
       if(m_deal_index >= 0 && m_deal_index < ArraySize(m_deals))
         return m_deals[m_deal_index].order_ticket;
       return 0;
      }
    virtual int    HistoryOrdersTotal() const override { return ArraySize(m_history_orders); }
    virtual ulong  HistoryOrderGetTicket(const int index) const override
      {
       if(index >= 0 && index < ArraySize(m_history_orders)) return m_history_orders[index].ticket;
       return 0;
      }
    virtual bool   HistoryOrderSelect(const ulong ticket) override
      {
       for(int i = 0; i < ArraySize(m_history_orders); i++)
         if(m_history_orders[i].ticket == ticket) { m_history_order_index = i; return true; }
       m_history_order_index = -1;
       return false;
      }
    virtual string HistoryOrderGetSymbol(const ulong ticket) const override
      {
       if(m_history_order_index >= 0 && m_history_order_index < ArraySize(m_history_orders))
         return m_history_orders[m_history_order_index].symbol;
       return "";
      }
    virtual long   HistoryOrderGetMagic(const ulong ticket) const override
      {
       if(m_history_order_index >= 0 && m_history_order_index < ArraySize(m_history_orders))
         return m_history_orders[m_history_order_index].magic;
       return 0;
      }
    virtual datetime HistoryOrderGetTimeSetup(const ulong ticket) const override
      {
       if(m_history_order_index >= 0 && m_history_order_index < ArraySize(m_history_orders))
         return m_history_orders[m_history_order_index].time_setup;
       return 0;
      }
    virtual long   HistoryOrderGetPositionId(const ulong ticket) const override
      {
       if(m_history_order_index >= 0 && m_history_order_index < ArraySize(m_history_orders))
         return m_history_orders[m_history_order_index].position_id;
       return 0;
      }

   // Symbol information
   virtual bool   SymbolExist(const string symbol) const override { return true; }
   virtual bool   SymbolSelect(const string symbol, const bool select) const override { return true; }
   virtual bool   SymbolIsSynchronized(const string symbol) const override { return true; }
   virtual bool   SymbolInfoTick(const string symbol, MqlTick &tick) const override
     {
      tick.bid = 1.0000; tick.ask = 1.0002; tick.last = 1.0001;
      tick.time = (datetime)TimeCurrent(); tick.flags = 0; tick.volume = 1;
      return true;
     }
   virtual double SymbolInfoDouble(const string symbol, const int prop_id) const override
     {
      switch(prop_id)
        {
         case SYMBOL_TRADE_TICK_SIZE: return 0.00001;
         case SYMBOL_POINT: return 0.00001;
         case SYMBOL_VOLUME_MIN: return 0.01;
         case SYMBOL_VOLUME_MAX: return 100.0;
         case SYMBOL_VOLUME_STEP: return 0.01;
         case SYMBOL_TRADE_STOPS_LEVEL: return 10;
         case SYMBOL_TRADE_FREEZE_LEVEL: return 0;
        }
      return 0.0;
     }
   virtual long   SymbolInfoInteger(const string symbol, const int prop_id) const override
     {
      switch(prop_id)
        {
         case SYMBOL_TRADE_MODE: return SYMBOL_TRADE_MODE_FULL;
         case SYMBOL_DIGITS: return 5;
         case SYMBOL_TRADE_STOPS_LEVEL: return 10;
         case SYMBOL_TRADE_FREEZE_LEVEL: return 0;
        }
      return 0;
     }

   // Calculation
   virtual bool   OrderCalcProfit(const ENUM_ORDER_TYPE order_type,
                                  const string symbol,
                                  const double volume,
                                  const double price_open,
                                  const double price_sl,
                                  double &profit) const override
     {
      double diff = (order_type == ORDER_TYPE_BUY) ? (price_sl - price_open) : (price_open - price_sl);
      profit = diff * volume * 100000.0; // Simplified: 1 pip = 10 currency units per lot
      return true;
     }
   virtual bool   OrderCalcMargin(const ENUM_ORDER_TYPE order_type,
                                  const string symbol,
                                  const double volume,
                                  const double price,
                                  double &margin) const override
     {
      margin = volume * price * 100000.0 * 0.02; // 2% margin
      return true;
     }

   // Time
   virtual datetime TimeCurrent() const override
     {
      // Return a fixed time for deterministic tests
      return D'2024.01.01 12:00:00';
     }

   // Execution Ledger
   virtual CExecutionLedger* GetExecutionLedger() const override { return m_execution_ledger; }
   virtual string GetAccountKey() const override { return m_account_key; }
  };

#endif