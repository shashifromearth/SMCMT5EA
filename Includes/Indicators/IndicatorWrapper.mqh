//+------------------------------------------------------------------+
//|                                            IndicatorWrapper.mqh   |
//|                        Indicator Wrapper Base Class               |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Base Indicator Wrapper - Open/Closed Principle                   |
//+------------------------------------------------------------------+
class CIndicatorWrapper
{
protected:
   int m_handle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   ILogger* m_logger;
   
public:
   CIndicatorWrapper(string symbol, ENUM_TIMEFRAMES timeframe, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_logger = logger;
      m_handle = INVALID_HANDLE;
   }
   
   virtual ~CIndicatorWrapper()
   {
      Release();
   }
   
   virtual bool Initialize() = 0;
   
   void Release()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }
   
   bool IsValid() { return m_handle != INVALID_HANDLE; }
   int GetHandle() { return m_handle; }
};

//+------------------------------------------------------------------+
//| ATR Indicator Wrapper                                            |
//+------------------------------------------------------------------+
class CATRIndicator : public CIndicatorWrapper
{
private:
   int m_period;
   
public:
   CATRIndicator(string symbol, ENUM_TIMEFRAMES timeframe, int period, ILogger* logger = NULL)
      : CIndicatorWrapper(symbol, timeframe, logger)
   {
      m_period = period;
   }
   
   bool Initialize() override
   {
      m_handle = iATR(m_symbol, m_timeframe, m_period);
      if(m_handle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.LogError("Failed to create ATR indicator for " + m_symbol + " " + EnumToString(m_timeframe));
         return false;
      }
      return true;
   }
   
   double GetValue(int shift = 0)
   {
      if(!IsValid()) return 0.0;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handle, 0, shift, 1, buffer) > 0)
         return buffer[0];
      return 0.0;
   }
};

//+------------------------------------------------------------------+
//| RSI Indicator Wrapper                                            |
//+------------------------------------------------------------------+
class CRSIIndicator : public CIndicatorWrapper
{
private:
   int m_period;
   ENUM_APPLIED_PRICE m_appliedPrice;
   
public:
   CRSIIndicator(string symbol, ENUM_TIMEFRAMES timeframe, int period, 
                 ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE, ILogger* logger = NULL)
      : CIndicatorWrapper(symbol, timeframe, logger)
   {
      m_period = period;
      m_appliedPrice = appliedPrice;
   }
   
   bool Initialize() override
   {
      m_handle = iRSI(m_symbol, m_timeframe, m_period, m_appliedPrice);
      if(m_handle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.LogError("Failed to create RSI indicator");
         return false;
      }
      return true;
   }
   
   double GetValue(int shift = 0)
   {
      if(!IsValid()) return 50.0;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handle, 0, shift, 1, buffer) > 0)
         return buffer[0];
      return 50.0;
   }
};

//+------------------------------------------------------------------+
//| EMA Indicator Wrapper                                             |
//+------------------------------------------------------------------+
class CEMAIndicator : public CIndicatorWrapper
{
private:
   int m_period;
   ENUM_APPLIED_PRICE m_appliedPrice;
   
public:
   CEMAIndicator(string symbol, ENUM_TIMEFRAMES timeframe, int period,
                 ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE, ILogger* logger = NULL)
      : CIndicatorWrapper(symbol, timeframe, logger)
   {
      m_period = period;
      m_appliedPrice = appliedPrice;
   }
   
   bool Initialize() override
   {
      m_handle = iMA(m_symbol, m_timeframe, m_period, 0, MODE_EMA, m_appliedPrice);
      if(m_handle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.LogError("Failed to create EMA indicator");
         return false;
      }
      return true;
   }
   
   double GetValue(int shift = 0)
   {
      if(!IsValid()) return 0.0;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handle, 0, shift, 1, buffer) > 0)
         return buffer[0];
      return 0.0;
   }
};

//+------------------------------------------------------------------+
//| ADX Indicator Wrapper                                            |
//+------------------------------------------------------------------+
class CADXIndicator : public CIndicatorWrapper
{
private:
   int m_period;
   
public:
   CADXIndicator(string symbol, ENUM_TIMEFRAMES timeframe, int period, ILogger* logger = NULL)
      : CIndicatorWrapper(symbol, timeframe, logger)
   {
      m_period = period;
   }
   
   bool Initialize() override
   {
      m_handle = iADX(m_symbol, m_timeframe, m_period);
      if(m_handle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.LogError("Failed to create ADX indicator");
         return false;
      }
      return true;
   }
   
   double GetValue(int shift = 0)
   {
      if(!IsValid()) return 0.0;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handle, 0, shift, 1, buffer) > 0)
         return buffer[0];
      return 0.0;
   }
};

