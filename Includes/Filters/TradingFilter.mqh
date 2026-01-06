//+------------------------------------------------------------------+
//|                                             TradingFilter.mqh    |
//|                        Trading Filter Class                       |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Core/Structures/EAState.mqh"
#include "../RiskManagement/RiskManager.mqh"
#include "../OrderManagement/OrderManager.mqh"
#include "SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Trading Filter - Checks if trading is allowed                   |
//+------------------------------------------------------------------+
class CTradingFilter
{
private:
   CEAConfig* m_config;
   CRiskManager* m_riskManager;
   COrderManager* m_orderManager;
   CSessionFilter* m_sessionFilter;
   ILogger* m_logger;
   
public:
   CTradingFilter(CEAConfig* config, CRiskManager* riskManager, COrderManager* orderManager,
                  CSessionFilter* sessionFilter, ILogger* logger = NULL)
   {
      m_config = config;
      m_riskManager = riskManager;
      m_orderManager = orderManager;
      m_sessionFilter = sessionFilter;
      m_logger = logger;
   }
   
   bool CanTrade(SEAState& state)
   {
      if(m_config == NULL)
      {
         if(m_logger != NULL)
            m_logger.LogError("TradingFilter: Config is NULL");
         return false;
      }
      
      // Check daily trade limit
      if(state.dailyTrades >= m_config.MaxTradesPerDay)
      {
         if(m_config.EnableDebugLog)
            Print("TRADING FILTER BLOCKED: Daily trade limit reached: ", state.dailyTrades, "/", m_config.MaxTradesPerDay);
         return false;
      }
      
      // Check consecutive losses
      if(state.consecutiveLosses >= m_config.MaxConsecutiveLosses)
      {
         datetime currentTime = TimeCurrent();
         if(state.lastTradeTime > 0)
         {
            MqlDateTime currentDT, lastDT;
            TimeToStruct(currentTime, currentDT);
            TimeToStruct(state.lastTradeTime, lastDT);
            
            if(currentDT.day != lastDT.day || currentDT.mon != lastDT.mon || currentDT.year != lastDT.year)
            {
               if(m_config.EnableDebugLog)
                  Print("TRADING FILTER: New day detected - Resetting consecutive losses from ", state.consecutiveLosses, " to 0");
               state.consecutiveLosses = 0;
               if(m_riskManager != NULL)
                  m_riskManager.SetConsecutiveLosses(0);
            }
            else
            {
               if(m_config.EnableDebugLog)
                  Print("TRADING FILTER BLOCKED: Trading temporarily stopped: ", state.consecutiveLosses, " consecutive losses (will reset tomorrow)");
               return false;
            }
         }
         else
         {
            state.consecutiveLosses = 0;
            if(m_riskManager != NULL)
               m_riskManager.SetConsecutiveLosses(0);
         }
      }
      
      // Check loss limits
      if(m_riskManager != NULL)
      {
         double currentBalance = m_riskManager.GetAccountBalance();
         double dailyLossLimit = currentBalance * m_config.MaxDailyLoss / 100.0;
         state.dailyProfit = m_riskManager.GetDailyProfit();
         
         if(state.dailyProfit <= -dailyLossLimit)
         {
            if(m_config.EnableAlerts)
               Alert("Daily loss limit reached (", DoubleToString(state.dailyProfit, 2), "). Trading stopped.");
            if(m_config.EnableDebugLog)
               Print("TRADING FILTER BLOCKED: Daily loss limit reached: ", state.dailyProfit, " / ", -dailyLossLimit);
            return false;
         }
         
         double weeklyLossLimit = currentBalance * m_config.MaxWeeklyLoss / 100.0;
         state.weeklyProfit = m_riskManager.GetWeeklyProfit();
         if(state.weeklyProfit <= -weeklyLossLimit)
         {
            if(m_config.EnableAlerts)
               Alert("Weekly loss limit reached (", DoubleToString(state.weeklyProfit, 2), "). Trading stopped.");
            if(m_config.EnableDebugLog)
               Print("TRADING FILTER BLOCKED: Weekly loss limit reached: ", state.weeklyProfit, " / ", -weeklyLossLimit);
            return false;
         }
         
         double monthlyLossLimit = currentBalance * m_config.MaxMonthlyLoss / 100.0;
         state.monthlyProfit = m_riskManager.GetMonthlyProfit();
         state.consecutiveLosses = m_riskManager.GetConsecutiveLosses();
         if(state.monthlyProfit <= -monthlyLossLimit)
         {
            if(m_config.EnableAlerts)
               Alert("Monthly loss limit reached (", DoubleToString(state.monthlyProfit, 2), "). Trading stopped.");
            if(m_config.EnableDebugLog)
               Print("TRADING FILTER BLOCKED: Monthly loss limit reached: ", state.monthlyProfit, " / ", -monthlyLossLimit);
            return false;
         }
      }
      
      // Check trading sessions
      if(m_sessionFilter != NULL && !m_sessionFilter.CanTrade())
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         if(m_config.EnableDebugLog)
            Print("TRADING FILTER BLOCKED: Session filter rejected. Hour: ", dt.hour, 
                  " GMT | TradeAllDay: ", m_config.TradeAllDay ? "true" : "false",
                  " | TradeLondonNYOverlap: ", m_config.TradeLondonNYOverlap ? "true" : "false",
                  " | TradeLondonOpen: ", m_config.TradeLondonOpen ? "true" : "false",
                  " | TradeNYOpen: ", m_config.TradeNYOpen ? "true" : "false");
         return false;
      }
      
      // Check for news events
      if(m_config.AvoidNews && IsHighImpactNews(2))
      {
         if(m_config.EnableDebugLog)
            Print("TRADING FILTER BLOCKED: High-impact news detected");
         return false;
      }
      
      // Check if position already exists
      if(m_orderManager != NULL && m_orderManager.HasOpenPosition())
      {
         if(m_config.EnableDebugLog)
            Print("TRADING FILTER BLOCKED: Position already exists");
         return false;
      }
      
      return true;
   }
   
private:
   bool IsHighImpactNews(int hoursBefore)
   {
      // TODO: Integrate with news API
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // NFP: First Friday of month, 12:30 GMT
      if(dt.day_of_week == 5 && dt.hour == 12 && dt.min >= 25 && dt.min <= 35)
         return true;
      
      // FOMC: Usually 18:00 GMT
      if(dt.hour >= 17 && dt.hour <= 19)
         return true;
      
      return false;
   }
};

