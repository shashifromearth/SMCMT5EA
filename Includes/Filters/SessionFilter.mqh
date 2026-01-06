//+------------------------------------------------------------------+
//|                                                SessionFilter.mqh   |
//|                        Session Filter Class                       |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Session Filter - Single Responsibility: Session Validation      |
//+------------------------------------------------------------------+
class CSessionFilter
{
private:
   CEAConfig* m_config;
   ILogger* m_logger;
   
public:
   CSessionFilter(CEAConfig* config, ILogger* logger = NULL)
   {
      m_config = config;
      m_logger = logger;
   }
   
   bool CanTrade()
   {
      if(m_config.TradeAllDay)
      {
         if(m_config.EnableDebugLog)
            Print("SESSION FILTER: TradeAllDay enabled - allowing trading");
         return true;
      }
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour; // GMT hour
      
      // PROFIT OPTIMIZED: Focus ONLY on London/NY overlap (13:00-16:00 GMT)
      if(m_config.TradeLondonNYOverlap)
      {
         if(hour >= 13 && hour < 16)
         {
            if(m_config.EnableDebugLog)
               Print("SESSION FILTER: London/NY overlap active (hour: ", hour, " GMT)");
            return true;
         }
         else
         {
            if(m_config.EnableDebugLog)
               Print("SESSION FILTER: Outside London/NY overlap hours (hour: ", hour, " GMT, need 13-16 GMT)");
            return false;
         }
      }
      
      // Fallback to individual sessions if overlap disabled
      if(!m_config.TradeLondonNYOverlap)
      {
         // London Open: 08:00-10:00 GMT
         if(m_config.TradeLondonOpen && hour >= 8 && hour < 10)
         {
            if(m_config.EnableDebugLog)
               Print("SESSION FILTER: London session active (hour: ", hour, " GMT)");
            return true;
         }
         
         // NY Open: 13:00-15:00 GMT
         if(m_config.TradeNYOpen && hour >= 13 && hour < 15)
         {
            if(m_config.EnableDebugLog)
               Print("SESSION FILTER: NY session active (hour: ", hour, " GMT)");
            return true;
         }
      }
      
      // Asian Session: 00:00-08:00 GMT (disabled by default for profit optimization)
      if(m_config.TradeAsianSession && hour >= 0 && hour < 8)
      {
         if(m_config.EnableDebugLog)
            Print("SESSION FILTER: Asian session active (hour: ", hour, " GMT)");
         return true;
      }
      
      if(m_config.EnableDebugLog)
         Print("SESSION FILTER: No active session (hour: ", hour, " GMT)");
      
      return false;
   }
   
   string GetCurrentSession()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;
      
      if(hour >= 13 && hour < 16)
         return "London-NY Overlap";
      else if(hour >= 8 && hour < 10)
         return "London Open";
      else if(hour >= 13 && hour < 15)
         return "NY Open";
      else if(hour >= 0 && hour < 8)
         return "Asian Session";
      else
         return "Other";
   }
   
   bool IsOptimalTradingTime()
   {
      MqlDateTime timeStruct;
      TimeToStruct(TimeCurrent(), timeStruct);
      int hour = timeStruct.hour;
      
      // London/NY overlap premium (13:00-16:00 GMT)
      if(hour >= 13 && hour <= 16)
      {
         if(m_config != NULL && m_config.AvoidNews && IsHighImpactNews(2))
            return false;
         return true;
      }
      
      // Standard trading hours (8:00-17:00 GMT)
      return (hour >= 8 && hour <= 17);
   }
   
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

