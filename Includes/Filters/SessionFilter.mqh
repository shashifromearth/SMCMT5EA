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
         return true;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour; // GMT hour
      
      // London Open: 08:00-10:00 GMT
      if(m_config.TradeLondonOpen && hour >= 8 && hour < 10)
         return true;
      
      // NY Open: 13:00-15:00 GMT
      if(m_config.TradeNYOpen && hour >= 13 && hour < 15)
         return true;
      
      // Asian Session: 00:00-08:00 GMT
      if(m_config.TradeAsianSession && hour >= 0 && hour < 8)
         return true;
      
      // London-NY Overlap: 13:00-16:00 GMT
      if(m_config.TradeLondonOpen && m_config.TradeNYOpen && hour >= 13 && hour < 16)
         return true;
      
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
};

