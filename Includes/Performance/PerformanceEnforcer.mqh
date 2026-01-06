//+------------------------------------------------------------------+
//|                                      PerformanceEnforcer.mqh     |
//|              Performance Enforcement & Adaptive Learning          |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "3.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Structures/EAState.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Performance Enforcer - Stops Trading After Losses               |
//+------------------------------------------------------------------+
class CPerformanceEnforcer
{
private:
   CEAConfig* m_config;
   ILogger* m_logger;
   
   int m_weeklyTrades;
   int m_weeklyWins;
   int m_weeklyLosses;
   datetime m_weekStartTime;
   
public:
   CPerformanceEnforcer(CEAConfig* config, ILogger* logger = NULL)
   {
      m_config = config;
      m_logger = logger;
      m_weeklyTrades = 0;
      m_weeklyWins = 0;
      m_weeklyLosses = 0;
      m_weekStartTime = 0;
   }
   
   // Check if trading is allowed
   bool CanTrade(SEAState& state)
   {
      // Rule 1: Maximum 1 trade per day (only the BEST setup)
      if(state.dailyTrades >= 1)
      {
         if(m_config.EnableDebugLog)
            Print("PERFORMANCE ENFORCER: Daily trade limit reached (1 trade/day)");
         return false;
      }
      
      // Rule 2: No trading after 2 losses (stop for the week)
      if(state.consecutiveLosses >= 2)
      {
         if(m_config.EnableDebugLog)
            Print("PERFORMANCE ENFORCER: Stopped trading after 2 consecutive losses");
         return false;
      }
      
      // Rule 3: Maximum 3 trades per week
      UpdateWeeklyCounters();
      if(m_weeklyTrades >= 3)
      {
         if(m_config.EnableDebugLog)
            Print("PERFORMANCE ENFORCER: Weekly trade limit reached (3 trades/week)");
         return false;
      }
      
      // Rule 4: System must be "hot" (recent win rate > 85%)
      if(m_weeklyTrades >= 5)
      {
         double winRate = (double)m_weeklyWins / (double)m_weeklyTrades;
         if(winRate < 0.85)
         {
            if(m_config.EnableDebugLog)
               Print("PERFORMANCE ENFORCER: Win rate too low: ", DoubleToString(winRate * 100, 1), "% < 85%");
            return false;
         }
      }
      
      return true;
   }
   
   // Record trade result
   void RecordTradeResult(bool isWin)
   {
      UpdateWeeklyCounters();
      
      if(isWin)
         m_weeklyWins++;
      else
         m_weeklyLosses++;
      
      m_weeklyTrades++;
   }
   
private:
   void UpdateWeeklyCounters()
   {
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Reset on new week (Monday)
      if(m_weekStartTime == 0 || dt.day_of_week == 1)
      {
         m_weekStartTime = currentTime;
         m_weeklyTrades = 0;
         m_weeklyWins = 0;
         m_weeklyLosses = 0;
      }
   }
};

