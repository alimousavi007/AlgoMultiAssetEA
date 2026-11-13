#ifndef __ALGOSYSTEM_PORTFOLIORISK_MQH__
#define __ALGOSYSTEM_PORTFOLIORISK_MQH__

#include "Interfaces.mqh"
#include "ExecutionLedger.mqh"
#include "EnvironmentProvider.mqh"
#include <Trade/Trade.mqh>

class CAlgoPortfolioRisk : public IPortfolioRisk
  {
private:
    double m_max_portfolio_risk;
    int    m_max_positions_total;
    int    m_max_positions_symbol;
    int    m_max_positions_strategy;
    double m_max_precious_metals_risk;
    string m_gold_symbol;
    string m_silver_symbol;

    string m_last_rejection_code;
    string m_last_rejection_reason;

    CExecutionLedger      *m_execution_ledger;
    string                 m_account_key;
    IEnvironmentProvider  *m_env_provider;
    CNativeEnvironmentProvider m_native_provider;
    bool                   m_use_native_provider;

public:
    // F-002: Exposure snapshot (account-wide broker positions + pending orders)
    struct ExposureSnapshot
      {
      double positions_risk_pct;      // sum of position risks (all managed + unknown/ambiguous)
      double pending_risk_pct;        // sum of pending order estimated risks (managed only)
      double equity;                  // current account equity
      string currency;                // ACCOUNT_CURRENCY
      bool   unknown_exposure;        // true if any unknown/ambiguous position exists
      bool   valid;                   // snapshot successfully computed
      };

    // F-002: Durable reservation aggregation from execution_attempts
    struct ReservationAggregate
      {
      double active_reserved_pct;     // sum of ACTIVE reservations as % of equity_at_reservation
      double partially_covered_pct;   // sum of PARTIALLY_COVERED reservations as % of equity_at_reservation
      double total_reserved_pct;      // active + partially_covered
      int    active_count;            // number of ACTIVE reservations
      int    partially_covered_count; // number of PARTIALLY_COVERED reservations
      bool   valid;                   // aggregation successfully computed
      };

    // F-002: Admission decision with revalidation
    struct AdmissionDecision
      {
      bool   admitted;                // true if admission granted
      string rejection_code;          // code if not admitted
      string rejection_reason;        // human-readable reason
      double exposure_after_pct;      // projected total exposure % after admission
      double reservation_after_pct;   // projected total reservation % after admission
      double equity_at_admission;     // F-002-P1: equity at CanAdmit time for revalidation drift check
      };

private:
    // Helper: Get the active environment provider (native or test)
    // Returns non-const pointer from const method to allow selection methods
    IEnvironmentProvider* GetEnv() const
      {
       if(m_use_native_provider)
         return (IEnvironmentProvider*)&m_native_provider;
       return (IEnvironmentProvider*)m_env_provider;
       }

    // F-002-R6: Shared limit checking helper to eliminate CanOpen/CanAdmit duplication
    // Returns true if all limits pass, false otherwise. Populates rejection code/reason on failure.
    bool CheckPortfolioLimits(const string signal_symbol,
                              const ENUM_STRATEGY_ID signal_strategy,
                              const double total_account_risk_pct,
                              const int symbol_count,
                              const int strategy_count,
                              const double precious_risk_pct,
                              const double new_risk_pct,
                              string &rejection_code,
                              string &rejection_reason) const
      {
      // 1. Total portfolio risk limit (includes unknown/ambiguous)
      if(total_account_risk_pct + new_risk_pct > m_max_portfolio_risk)
         {
         rejection_code = "MAX_PORTFOLIO_RISK";
         rejection_reason = "Portfolio risk limit exceeded: " + DoubleToString(total_account_risk_pct + new_risk_pct, 2) +
                            "% > " + DoubleToString(m_max_portfolio_risk, 2) + "%";
         return false;
         }

      // 2. Per-symbol position limit (managed positions only)
      if(symbol_count >= m_max_positions_symbol)
         {
         rejection_code = "MAX_POSITIONS_SYMBOL";
         rejection_reason = "Per-symbol position limit reached: " + IntegerToString(symbol_count) + " >= " +
                            IntegerToString(m_max_positions_symbol);
         return false;
         }

      // 3. Per-strategy position limit (managed positions only)
      if(strategy_count >= m_max_positions_strategy)
         {
         rejection_code = "MAX_POSITIONS_STRATEGY";
         rejection_reason = "Per-strategy position limit reached: " + IntegerToString(strategy_count) + " >= " +
                            IntegerToString(m_max_positions_strategy);
         return false;
         }

      // 4. Precious metals concentration risk (managed + unknown per F-005.2.4)
      if(IsPrecious(signal_symbol) &&
         precious_risk_pct + new_risk_pct > m_max_precious_metals_risk)
         {
         rejection_code = "MAX_PRECIOUS_METALS_RISK";
         rejection_reason = "Precious-metals concentration risk limit exceeded: " +
                            DoubleToString(precious_risk_pct + new_risk_pct, 2) + "% > " +
                            DoubleToString(m_max_precious_metals_risk, 2) + "%";
         return false;
         }

      return true;
      }

    bool IsManagedMagic(const long magic) const
      {
       // Strategy/style Magic (legacy ownership)
       if(magic==MAGIC_TREND ||
          magic==MAGIC_BREAKOUT ||
          magic==MAGIC_MOMENTUM ||
          magic==MAGIC_MEAN_REVERSION ||
          magic==MAGIC_RELATIVE_VALUE ||
          magic==MAGIC_HYBRID_SCALP ||
          magic==MAGIC_HYBRID_DAY ||
          magic==MAGIC_HYBRID_SWING)
          return true;

       // F-005.2.2: Per-Attempt Magic range requires durable ledger lookup.
       // Range membership alone is not ownership proof.
       IEnvironmentProvider* env = GetEnv();
       if(env != NULL)
         {
          CExecutionLedger* ledger = env.GetExecutionLedger();
          string account_key = env.GetAccountKey();
          if(ledger != NULL && account_key != "")
            {
             CExecutionLedger::ENUM_MAGIC_OWNERSHIP ownership = ledger.ResolveMagicOwnership((ulong)magic, account_key);
             // For risk admission: EXACT_ATTEMPT and LEGACY_STRATEGY are managed.
             // AMBIGUOUS and EXTERNAL are not managed (fail closed for risk-increasing).
             return (ownership == CExecutionLedger::MAGIC_OWNERSHIP_EXACT_ATTEMPT ||
                     ownership == CExecutionLedger::MAGIC_OWNERSHIP_LEGACY_STRATEGY);
            }
         }
       // Fallback: if ledger unavailable, reject attempt_magic range (fail closed)
       return false;
      }

    bool IsPrecious(const string symbol) const
      {
       return symbol==m_gold_symbol || symbol==m_silver_symbol;
      }

    ENUM_STRATEGY_ID StrategyFromMagic(const long magic) const
      {
       if(magic==MAGIC_TREND) return STRATEGY_TREND_PULLBACK;
       if(magic==MAGIC_BREAKOUT) return STRATEGY_BREAKOUT;
       if(magic==MAGIC_MOMENTUM) return STRATEGY_MOMENTUM;
       if(magic==MAGIC_MEAN_REVERSION) return STRATEGY_MEAN_REVERSION;
       if(magic==MAGIC_RELATIVE_VALUE) return STRATEGY_RELATIVE_VALUE;
             // Hybrid requests currently use STRATEGY_TREND_PULLBACK.
       // Count Hybrid magic IDs against the same per-strategy position cap.
       if(magic==MAGIC_HYBRID_SCALP ||
          magic==MAGIC_HYBRID_DAY ||
          magic==MAGIC_HYBRID_SWING)
          return STRATEGY_TREND_PULLBACK;
       return STRATEGY_NONE;
      }

    double PositionRiskPercent(const ulong ticket) const
      {
       IEnvironmentProvider* env = GetEnv();
       if(env == NULL) return 0.0;

       if(!env.PositionSelectByTicket(ticket))
          return 0.0;

       string symbol = env.PositionGetSymbol();
       long magic = env.PositionGetMagic();

       double sl = env.PositionGetSL();
       double volume = env.PositionGetVolume();
       double open_price = env.PositionGetPriceOpen();
       ENUM_POSITION_TYPE type = env.PositionGetType();

       if(sl<=0.0 || volume<=0.0 || open_price<=0.0)
          return DBL_MAX;

       ENUM_ORDER_TYPE order_type =
          (type==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

       double loss = 0.0;

       if(!env.OrderCalcProfit(
             order_type,
             symbol,
             volume,
             open_price,
             sl,
             loss))
          return DBL_MAX;

       double equity = env.GetAccountEquity();

       if(equity<=0.0)
          return DBL_MAX;

       return MathAbs(loss)/equity*100.0;
      }

    void Reject(const string code,const string reason)
      {
       m_last_rejection_code=code;
       m_last_rejection_reason=reason;
      }

public:
    CAlgoPortfolioRisk()
      {
       m_max_portfolio_risk=3.0;
       m_max_positions_total=3;
       m_max_positions_symbol=1;
       m_max_positions_strategy=1;
       m_max_precious_metals_risk=2.0;
       m_gold_symbol="XAUUSD";
       m_silver_symbol="XAGUSD";
       m_last_rejection_code="";
       m_last_rejection_reason="";
       m_execution_ledger=NULL;
       m_account_key="";
       m_env_provider=NULL;
       m_use_native_provider=true;
      }

    void SetParameters(const double max_portfolio_risk,
                       const int max_positions_total,
                       const int max_positions_symbol,
                       const int max_positions_strategy,
                       const double max_precious_metals_risk,
                       const string gold_symbol,
                       const string silver_symbol)
      {
       m_max_portfolio_risk=max_portfolio_risk;
       m_max_positions_total=max_positions_total;
       m_max_positions_symbol=max_positions_symbol;
       m_max_positions_strategy=max_positions_strategy;
       m_max_precious_metals_risk=max_precious_metals_risk;
       m_gold_symbol=gold_symbol;
       m_silver_symbol=silver_symbol;
       m_last_rejection_code="";
       m_last_rejection_reason="";
      }

    //+------------------------------------------------------------------+
    //| Attach execution ledger for ownership resolution                 |
    //+------------------------------------------------------------------+
    void SetExecutionLedger(CExecutionLedger *ledger, const string account_key)
      {
       m_execution_ledger=ledger;
       m_account_key=account_key;
       // Also configure native provider
       m_native_provider.SetExecutionLedger(ledger, account_key);
      }

    //+------------------------------------------------------------------+
    //| Set test environment provider                                    |
    //+------------------------------------------------------------------+
    void SetEnvironmentProvider(IEnvironmentProvider *provider)
      {
       m_env_provider = provider;
       m_use_native_provider = (provider == NULL);
      }

    virtual bool Initialize() override
      {
       if(m_max_portfolio_risk<=0.0 ||
          m_max_positions_total<=0 ||
          m_max_positions_symbol<=0 ||
          m_max_positions_strategy<=0 ||
          m_max_precious_metals_risk<=0.0)
         {
          Reject("INVALID_CONFIG","Invalid portfolio risk configuration");
          return false;
         }

       // Initialize native provider if using it
       if(m_use_native_provider)
         {
          // Native provider doesn't need explicit initialization
         }

       return true;
      }

    virtual bool CanOpen(const StrategySignal &signal,
                         const RiskDecision &risk) override
      {
       m_last_rejection_code="";
       m_last_rejection_reason="";

       if(!signal.valid)
         {
          Reject("INVALID_SIGNAL","Strategy signal is invalid");
          return false;
         }

       if(risk.decision!=RISK_APPROVED)
         {
          Reject("RISK_NOT_APPROVED","Risk engine did not approve the trade");
          return false;
         }

       IEnvironmentProvider* env = GetEnv();
       if(env == NULL)
         {
          Reject("NO_ENV_PROVIDER","Environment provider not available");
          return false;
         }

       // F-002-R6: Check total managed position limit separately (not in shared helper)
       if(env.GetPositionsTotal() >= m_max_positions_total)
         {
          Reject("MAX_POSITIONS_TOTAL","Total managed position limit reached");
          return false;
         }

       // Compute current portfolio state for shared limit check
       int symbol_count=0;
       int strategy_count=0;
       double precious_risk=0.0;
       double total_account_risk=0.0; // F-005.2.4: includes ALL positions for total risk

       for(int i=0; i<env.GetPositionsTotal(); i++)
         {
          ulong ticket = env.GetPositionTicket(i);
          if(ticket==0) continue;

          string symbol = env.PositionGetSymbol();
          long magic = env.PositionGetMagic();

          bool is_managed = IsManagedMagic(magic);

          double pr = PositionRiskPercent(ticket);

          if(pr==DBL_MAX)
            {
             Reject("INVALID_OPEN_POSITION_RISK",
                    "Cannot calculate existing position risk");
             return false;
            }

          // F-005.2.4: Total portfolio risk MUST include ALL positions (managed + unknown/ambiguous)
          // to prevent understating account exposure when ownership cannot be resolved.
          total_account_risk += pr;

          // Per-symbol/strategy limits only apply to managed positions
          if(is_managed)
            {
             if(symbol==signal.symbol)
                symbol_count++;

             if(StrategyFromMagic(magic)==signal.strategy)
                strategy_count++;

             if(IsPrecious(symbol))
                precious_risk += pr;
             }
          else
            {
             // Unknown/ambiguous positions: include in total risk, track precious metals separately
             if(IsPrecious(symbol))
                precious_risk += pr;
             }
         }

       // F-002-R6: Use shared limit checking helper
       string rej_code, rej_reason;
       if(!CheckPortfolioLimits(signal.symbol, signal.strategy,
                                total_account_risk, symbol_count, strategy_count,
                                precious_risk, risk.risk_percent,
                                rej_code, rej_reason))
         {
          Reject(rej_code, rej_reason);
          return false;
          }

       return true;
      }

    string LastRejectionCode() const
      {
       return m_last_rejection_code;
      }

    string LastRejectionReason() const
      {
       return m_last_rejection_reason;
      }

    virtual double CurrentRiskPercent() const override
      {
       IEnvironmentProvider* env = GetEnv();
       if(env == NULL) return 0.0;

       double total=0.0;

       for(int i=0; i<env.GetPositionsTotal(); i++)
         {
          ulong ticket = env.GetPositionTicket(i);
          if(ticket==0) continue;

          double risk = PositionRiskPercent(ticket);
          if(risk==DBL_MAX)
             return DBL_MAX;

          total+=risk;
         }

       return total;
      }

    // F-002: Compute account-wide exposure snapshot (positions + pending orders)
    bool GetExposureSnapshot(ExposureSnapshot &snapshot) const
      {
       IEnvironmentProvider* env = GetEnv();
       if(env == NULL) return false;

       snapshot.positions_risk_pct = 0.0;
       snapshot.pending_risk_pct = 0.0;
       snapshot.equity = env.GetAccountEquity();
       snapshot.currency = env.GetAccountCurrency();
       snapshot.unknown_exposure = false;
       snapshot.valid = false;

       if(snapshot.equity <= 0.0 || snapshot.currency == "")
          return false;

        // Positions: include ALL (managed + unknown/ambiguous) per F-005.2.4
        // F9: single pass — accumulate risk and count evaluatable positions together
        // (the previous second pass recomputed PositionRiskPercent over the same positions).
        int valid_positions = 0;
        int evaluated_positions = 0;
        for(int i=0; i<env.GetPositionsTotal(); i++)
          {
          ulong ticket = env.GetPositionTicket(i);
          if(ticket == 0) continue;

          string symbol = env.PositionGetSymbol();
          long magic = env.PositionGetMagic();

          bool is_managed = IsManagedMagic(magic);
          if(!is_managed)
             snapshot.unknown_exposure = true;

          double pr = PositionRiskPercent(ticket);
          if(MathIsValidNumber(pr) && pr >= 0.0)
             evaluated_positions++;
          if(pr == DBL_MAX)
             {
             // F-002-P1: Conservative handling - use max portfolio risk as cap for uncalculatable position
             // instead of failing entire snapshot. Log the ticket for diagnostics.
             pr = m_max_portfolio_risk; // cap at portfolio limit
// Note: In production, consider logging the ticket here
             }
          if(MathIsValidNumber(pr) && pr > 0.0)
             {
             snapshot.positions_risk_pct += pr;
             valid_positions++;
             }
          }

        // If no positions could be evaluated (all uncalculatable), fail
        // But allow positions with zero risk (e.g., SL at open price)
        if(evaluated_positions == 0 && env.GetPositionsTotal() > 0)
           return false;

       // Pending orders: estimate risk from SL if available
       // F-002-R5/FINDING-003: Include unknown pending orders with valid SL in pending_risk_pct
       // Use ORDER_VOLUME_CURRENT (remaining volume) instead of INITIAL
       bool has_unknown_pending = false;
       for(int i=0; i<env.GetOrdersTotal(); i++)
         {
         ulong ticket = env.GetOrderTicket(i);
         if(ticket == 0) continue;

         if(!env.OrderSelect(ticket)) continue;

         string symbol = env.OrderGetSymbol();
         long magic = env.OrderGetMagic();
         ENUM_ORDER_TYPE order_type = env.OrderGetType();
         double volume = env.OrderGetVolumeCurrent(); // F-002-P3: use remaining volume
         double price = env.OrderGetPriceOpen();
         double sl = env.OrderGetSL();

         bool is_managed = IsManagedMagic(magic);
         if(!is_managed)
            has_unknown_pending = true;

         if(sl <= 0.0 || volume <= 0.0 || price <= 0.0)
            continue;

         double loss = 0.0;
         if(!env.OrderCalcProfit(order_type, symbol, volume, price, sl, loss))
            continue; // skip uncalculatable pending order

         double pr = MathAbs(loss) / snapshot.equity * 100.0;
         if(MathIsValidNumber(pr) && pr > 0.0)
            snapshot.pending_risk_pct += pr;
         }

       if(has_unknown_pending)
          snapshot.unknown_exposure = true;

       snapshot.valid = true;
       return true;
      }

    // F-002: Aggregate durable per-Attempt reservations from execution_ledger
    // F-002-P1: Recompute reservation % against current equity (passed as parameter) instead of stale equity_snapshot
    // F-002-P0: Optionally exclude a specific attempt_id (e.g., current attempt being admitted) to avoid double-counting
    bool GetReservationAggregate(ReservationAggregate &agg, const string exclude_attempt_id = "", const double current_equity = 0.0) const
      {
       agg.active_reserved_pct = 0.0;
       agg.partially_covered_pct = 0.0;
       agg.total_reserved_pct = 0.0;
       agg.active_count = 0;
       agg.partially_covered_count = 0;
       agg.valid = false;

       IEnvironmentProvider* env = GetEnv();
       if(env == NULL) return false;

       CExecutionLedger* ledger = env.GetExecutionLedger();
       string account_key = env.GetAccountKey();
       if(ledger == NULL || !ledger.IsAvailable() || account_key == "")
          return false;

       // Query execution_attempts for ACTIVE (2) and PARTIALLY_COVERED (3) reservations
       // Only reservations with risk_reserve_known=true and risk_reserve_model_version=EXEC_RISK_RESERVE_MODEL_V1 count
       string sql = "SELECT risk_reserve_remaining_amount, risk_reserve_equity_snapshot, risk_reserve_state, risk_reserve_known, risk_reserve_model_version, attempt_id "
                    "FROM execution_attempts "
                    "WHERE risk_reserve_state IN (" + IntegerToString(EXEC_RISK_RESERVE_STATE_ACTIVE) + "," + IntegerToString(EXEC_RISK_RESERVE_STATE_PARTIALLY_COVERED) + ") "
                    "AND account_key = '" + CExecutionLedger::EscapeSQLStatic(account_key) + "';";

       int handle = DatabasePrepare(ledger.GetDbHandle(), sql);
       if(handle == INVALID_HANDLE)
          return false;

       double equity_for_pct = (current_equity > 0.0) ? current_equity : 0.0; // will use equity_snapshot per-row if not provided

       while(DatabaseRead(handle))
         {
         double remaining = DatabaseColumnDouble2(handle, 0);
         double equity_snapshot = DatabaseColumnDouble2(handle, 1);
         int state = (int)DatabaseColumnLong2(handle, 2);
         int known = (int)DatabaseColumnLong2(handle, 3);
         int model_version = (int)DatabaseColumnLong2(handle, 4);
         string attempt_id = DatabaseColumnString(handle, 5);

         if(exclude_attempt_id != "" && attempt_id == exclude_attempt_id)
            continue; // exclude current attempt's own reservation

         if(known != 1 || model_version != EXEC_RISK_RESERVE_MODEL_V1)
            continue;

         if(remaining <= 0.0)
            continue;

         double equity_base = (equity_for_pct > 0.0) ? equity_for_pct : equity_snapshot;
         if(equity_base <= 0.0)
            continue;

         double pct = remaining / equity_base * 100.0;
         if(!MathIsValidNumber(pct) || pct <= 0.0)
            continue;

         if(state == EXEC_RISK_RESERVE_STATE_ACTIVE)
            {
            agg.active_reserved_pct += pct;
            agg.active_count++;
            }
         else if(state == EXEC_RISK_RESERVE_STATE_PARTIALLY_COVERED)
            {
            agg.partially_covered_pct += pct;
            agg.partially_covered_count++;
            }
         }

       DatabaseFinalize(handle);

       agg.total_reserved_pct = agg.active_reserved_pct + agg.partially_covered_pct;
       agg.valid = true;
       return true;
      }

    // F-002: Centralized admission with atomic/serialized guard (revision/CAS).
    // Checks: total_exposure (positions + pending) + new_risk + active_reservations <= max_portfolio_risk
    // Must be called immediately before broker submission (final pre-submit revalidation).
    // F-002-P0: Exclude current attempt's own reservation from aggregate to avoid double-counting.
    bool CanAdmit(const StrategySignal &signal, const RiskDecision &risk, AdmissionDecision &decision, const string exclude_attempt_id = "")
      {
       decision.admitted = false;
       decision.rejection_code = "";
       decision.rejection_reason = "";
       decision.exposure_after_pct = 0.0;
       decision.reservation_after_pct = 0.0;
       decision.equity_at_admission = 0.0;

       IEnvironmentProvider* env = GetEnv();
       if(env == NULL)
         {
          decision.rejection_code = "NO_ENV_PROVIDER";
          decision.rejection_reason = "Environment provider not available";
          return false;
         }

       // 1. Get exposure snapshot
       ExposureSnapshot snapshot;
       if(!GetExposureSnapshot(snapshot))
         {
         decision.rejection_code = "EXPOSURE_SNAPSHOT_FAILED";
         decision.rejection_reason = "Failed to compute account-wide exposure snapshot";
         return false;
         }

       // 2. Get reservation aggregate (excluding current attempt if provided)
       ReservationAggregate agg;
       if(!GetReservationAggregate(agg, exclude_attempt_id, snapshot.equity))
         {
         decision.rejection_code = "RESERVATION_AGGREGATE_FAILED";
         decision.rejection_reason = "Failed to aggregate durable reservations from ledger";
         return false;
         }

       // 3. Compute projected exposure after admission
       // F-002-R1: Use verified actual_monetary_risk converted to current equity % for admission,
       // aligning with durable reservation model (which stores monetary amount).
       double new_risk_pct = 0.0;
       if(risk.actual_monetary_risk > 0.0 && MathIsValidNumber(risk.actual_monetary_risk) && snapshot.equity > 0.0)
         {
         new_risk_pct = risk.actual_monetary_risk / snapshot.equity * 100.0;
         }
       else
         {
         // Fallback to configured risk_percent if actual_monetary_risk invalid (should not happen due to EA gate)
         new_risk_pct = risk.risk_percent;
         }
       double total_exposure_pct = snapshot.positions_risk_pct + snapshot.pending_risk_pct;
       double projected_exposure_pct = total_exposure_pct + agg.total_reserved_pct + new_risk_pct;
       double projected_reservation_pct = agg.total_reserved_pct + new_risk_pct; // new attempt will add to active reservations

       decision.exposure_after_pct = projected_exposure_pct;
       decision.reservation_after_pct = projected_reservation_pct;
       decision.equity_at_admission = snapshot.equity;

       // 4. Check total positions limit first (not in shared helper)
       if(env.GetPositionsTotal() >= m_max_positions_total)
         {
         decision.rejection_code = "MAX_POSITIONS_TOTAL";
         decision.rejection_reason = "Total managed position limit reached";
         return false;
         }

       // 5. Compute symbol/strategy/precious counts for shared limit check
       int symbol_count = 0;
       int strategy_count = 0;
       double precious_risk = 0.0;
       double total_account_risk = total_exposure_pct + agg.total_reserved_pct; // already includes all positions + pending + reservations

       // Iterate positions to count per-symbol/strategy and precious metals (managed + unknown)
       for(int i=0; i<env.GetPositionsTotal(); i++)
         {
         ulong ticket = env.GetPositionTicket(i);
         if(ticket == 0) continue;
         string sym = env.PositionGetSymbol();
         long magic = env.PositionGetMagic();
         double pr = PositionRiskPercent(ticket);
         if(pr == DBL_MAX) continue; // skip invalid, already in total_account_risk via snapshot
         if(IsManagedMagic(magic))
            {
            if(sym == signal.symbol) symbol_count++;
            if(StrategyFromMagic(magic) == signal.strategy) strategy_count++;
            if(IsPrecious(sym)) precious_risk += pr;
            }
         else
            {
            if(IsPrecious(sym)) precious_risk += pr; // unknown precious also counted
            }
         }

       // Note: GetExposureSnapshot already includes all positions (managed + unknown) in positions_risk_pct
       // and ALL pending orders (managed + unknown) in pending_risk_pct.
       // We need to add precious metals from ALL pending orders to precious_risk.
       // The shared helper expects precious_risk to include all precious (managed + unknown).
       // Use ORDER_VOLUME_CURRENT for consistency with GetExposureSnapshot.
       for(int i=0; i<env.GetOrdersTotal(); i++)
         {
         ulong ticket = env.GetOrderTicket(i);
         if(ticket == 0) continue;
         if(!env.OrderSelect(ticket)) continue;
         string sym = env.OrderGetSymbol();
         long magic = env.OrderGetMagic();
         if(IsPrecious(sym))
            {
            ENUM_ORDER_TYPE order_type = env.OrderGetType();
            double volume = env.OrderGetVolumeCurrent();
            double price = env.OrderGetPriceOpen();
            double sl = env.OrderGetSL();
            if(sl <= 0.0 || volume <= 0.0 || price <= 0.0) continue;
            double loss = 0.0;
            if(env.OrderCalcProfit(order_type, sym, volume, price, sl, loss))
               {
               double pr = MathAbs(loss) / snapshot.equity * 100.0;
               if(MathIsValidNumber(pr) && pr > 0.0)
                  precious_risk += pr;
               }
            }
         }

       // 6. F-002-R6: Use shared limit checking helper
       string rej_code, rej_reason;
       if(!CheckPortfolioLimits(signal.symbol, signal.strategy,
                                total_account_risk, symbol_count, strategy_count,
                                precious_risk, new_risk_pct,
                                rej_code, rej_reason))
         {
         decision.rejection_code = rej_code;
         decision.rejection_reason = rej_reason;
         return false;
         }

       // All checks passed
       decision.admitted = true;
       return true;
      }

    // F-002: Final pre-submit revalidation (called at SUBMISSION_MAY_HAVE_OCCURRED boundary).
    // Verifies nothing changed since CanAdmit: equity, positions, pending orders, reservations.
    // F-002-P0: Exclude current attempt's own reservation to avoid double-counting.
    bool RevalidateAdmission(const StrategySignal &signal, const RiskDecision &risk, const AdmissionDecision &prior_decision, string &reason, const string exclude_attempt_id = "") const
      {
       reason = "";

       IEnvironmentProvider* env = GetEnv();
       if(env == NULL)
         {
          reason = "Revalidation: environment provider not available";
          return false;
         }

       // Recompute exposure snapshot
       ExposureSnapshot snapshot;
       if(!GetExposureSnapshot(snapshot))
         {
         reason = "Revalidation: exposure snapshot failed";
         return false;
         }

       // Recompute reservation aggregate with current equity
       ReservationAggregate agg;
       double equity_now = env.GetAccountEquity();
       if(equity_now <= 0.0)
         {
         reason = "Revalidation: equity unavailable";
         return false;
         }
       if(!GetReservationAggregate(agg, exclude_attempt_id, equity_now))
         {
         reason = "Revalidation: reservation aggregate failed";
         return false;
         }

       // Verify equity hasn't dropped significantly (allow 1% drift) against prior admission equity
       if(prior_decision.equity_at_admission > 0.0)
         {
         double equity_drop_pct = (prior_decision.equity_at_admission - equity_now) / prior_decision.equity_at_admission * 100.0;
         if(equity_drop_pct > 1.0)
            {
            reason = "Revalidation: equity dropped " + DoubleToString(equity_drop_pct, 2) + "% > 1% tolerance";
            return false;
         }
        }

        // Check total positions limit
        if(env.GetPositionsTotal() >= m_max_positions_total)
           {
           reason = "Revalidation: total managed position limit reached";
           return false;
           }

        // Recompute projected exposure with current snapshot
       // F-002-R1: Use actual_monetary_risk converted to current equity %
       double new_risk_pct = 0.0;
       if(risk.actual_monetary_risk > 0.0 && MathIsValidNumber(risk.actual_monetary_risk) && equity_now > 0.0)
         {
         new_risk_pct = risk.actual_monetary_risk / equity_now * 100.0;
         }
       else
         {
         new_risk_pct = risk.risk_percent;
         }
       double total_exposure_pct = snapshot.positions_risk_pct + snapshot.pending_risk_pct;
       double projected_exposure_pct = total_exposure_pct + agg.total_reserved_pct + new_risk_pct;
       double projected_reservation_pct = agg.total_reserved_pct + new_risk_pct;

       // Check if exposure increased beyond limit
       if(projected_exposure_pct > m_max_portfolio_risk)
         {
         reason = "Revalidation: projected exposure " + DoubleToString(projected_exposure_pct, 2) +
                  "% exceeds limit " + DoubleToString(m_max_portfolio_risk, 2) + "%";
         return false;
         }

       // Check if exposure drifted significantly from prior admission (0.5% tolerance)
       if(projected_exposure_pct > prior_decision.exposure_after_pct + 0.5)
         {
         reason = "Revalidation: exposure drifted from " + DoubleToString(prior_decision.exposure_after_pct, 2) +
                  "% to " + DoubleToString(projected_exposure_pct, 2) + "%";
         return false;
         }

       // Check if reservations increased beyond prior decision (allow small drift)
       if(projected_reservation_pct > prior_decision.reservation_after_pct + 0.5) // 0.5% tolerance
         {
         reason = "Revalidation: reservation increased from " + DoubleToString(prior_decision.reservation_after_pct, 2) +
                  "% to " + DoubleToString(projected_reservation_pct, 2) + "%";
         return false;
         }

       // 5. Compute symbol/strategy/precious counts for shared limit check
       int symbol_count = 0, strategy_count = 0;
       double precious_risk = 0.0;
       double total_account_risk = total_exposure_pct + agg.total_reserved_pct;

       for(int i=0; i<env.GetPositionsTotal(); i++)
         {
         ulong ticket = env.GetPositionTicket(i);
         if(ticket == 0) continue;
         string sym = env.PositionGetSymbol();
         long magic = env.PositionGetMagic();
         double pr = PositionRiskPercent(ticket);
         if(pr == DBL_MAX) continue; // skip invalid, risk already capped in snapshot
         if(IsManagedMagic(magic))
            {
            if(sym == signal.symbol) symbol_count++;
            if(StrategyFromMagic(magic) == signal.strategy) strategy_count++;
            if(IsPrecious(sym)) precious_risk += pr;
            }
         else
            {
            if(IsPrecious(sym)) precious_risk += pr; // unknown precious also counted
            }
         }
       // Add ALL pending precious metals (managed + unknown) using ORDER_VOLUME_CURRENT
       for(int i=0; i<env.GetOrdersTotal(); i++)
         {
         ulong ticket = env.GetOrderTicket(i);
         if(ticket == 0) continue;
         if(!env.OrderSelect(ticket)) continue;
         string sym = env.OrderGetSymbol();
         long magic = env.OrderGetMagic();
         if(!IsPrecious(sym)) continue;
         ENUM_ORDER_TYPE order_type = env.OrderGetType();
         double volume = env.OrderGetVolumeCurrent();
         double price = env.OrderGetPriceOpen();
         double sl = env.OrderGetSL();
         if(sl <= 0.0 || volume <= 0.0 || price <= 0.0) continue;
         double loss = 0.0;
         if(env.OrderCalcProfit(order_type, sym, volume, price, sl, loss))
            {
            double pr = MathAbs(loss) / equity_now * 100.0;
            if(MathIsValidNumber(pr) && pr > 0.0)
               precious_risk += pr;
            }
         }

       // F-002-R6: Use shared limit checking helper
       string rej_code, rej_reason;
       if(!CheckPortfolioLimits(signal.symbol, signal.strategy,
                                total_account_risk, symbol_count, strategy_count,
                                precious_risk, new_risk_pct,
                                rej_code, rej_reason))
         {
         reason = "Revalidation: " + rej_reason;
         return false;
         }

       return true;
      }

  };

#endif