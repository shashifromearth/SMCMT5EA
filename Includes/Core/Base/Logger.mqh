//+------------------------------------------------------------------+
//|                                                      Logger.mqh   |
//|                        Logger Implementation                     |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "ILogger.mqh"

//+------------------------------------------------------------------+
//| Logger Class - Single Responsibility: Logging                   |
//+------------------------------------------------------------------+
class CLogger : public ILogger
{
private:
   bool m_debugEnabled;
   bool m_detailedLoggingEnabled;
   bool m_alertsEnabled;
   
public:
   CLogger(bool debugEnabled = true, bool detailedLogging = true, bool alertsEnabled = true)
   {
      m_debugEnabled = debugEnabled;
      m_detailedLoggingEnabled = detailedLogging;
      m_alertsEnabled = alertsEnabled;
   }
   
   void LogInfo(string message) override
   {
      Print("[INFO] ", message);
   }
   
   void LogWarning(string message) override
   {
      Print("[WARNING] ", message);
      if(m_alertsEnabled)
         Alert("[WARNING] ", message);
   }
   
   void LogError(string message) override
   {
      Print("[ERROR] ", message);
      if(m_alertsEnabled)
         Alert("[ERROR] ", message);
   }
   
   void LogDebug(string message) override
   {
      if(m_debugEnabled)
         Print("[DEBUG] ", message);
   }
   
   void LogTrade(string message) override
   {
      if(m_detailedLoggingEnabled)
         Print("[TRADE] ", message);
   }
   
   bool IsDebugEnabled() override { return m_debugEnabled; }
   bool IsDetailedLoggingEnabled() override { return m_detailedLoggingEnabled; }
};

