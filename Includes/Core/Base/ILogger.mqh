//+------------------------------------------------------------------+
//|                                                    ILogger.mqh    |
//|                        Logger Interface (Dependency Inversion)   |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

//+------------------------------------------------------------------+
//| Logger Interface - Dependency Inversion Principle               |
//+------------------------------------------------------------------+
interface ILogger
{
   void LogInfo(string message);
   void LogWarning(string message);
   void LogError(string message);
   void LogDebug(string message);
   void LogTrade(string message);
   bool IsDebugEnabled();
   bool IsDetailedLoggingEnabled();
};

