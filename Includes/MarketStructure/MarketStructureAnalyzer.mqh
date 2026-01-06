//+------------------------------------------------------------------+
//|                                      MarketStructureAnalyzer.mqh  |
//|                        Market Structure Analysis Class            |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Enums/SMCEnums.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Config/EAConfig.mqh"

//+------------------------------------------------------------------+
//| Market Structure Analyzer - Single Responsibility               |
//+------------------------------------------------------------------+
class CMarketStructureAnalyzer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CEAConfig* m_config;
   ILogger* m_logger;
   
   SwingPoint m_swingPoints[];
   MarketStructure m_marketStructure;
   
public:
   CMarketStructureAnalyzer(string symbol, ENUM_TIMEFRAMES timeframe, 
                            CEAConfig* config, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_config = config;
      m_logger = logger;
      ZeroMemory(m_marketStructure);
      ArrayResize(m_swingPoints, 0);
   }
   
   void Update()
   {
      DetectSwingPoints();
      CheckMarketStructureShift();
      CheckBreakOfStructure();
      CheckChangeOfCharacter();
   }
   
   void DetectSwingPoints()
   {
      ArrayResize(m_swingPoints, 0);
      
      int bars = iBars(m_symbol, m_timeframe);
      int validationBars = m_config.SwingValidationBars;
      
      if(bars < validationBars * 2 + 5)
         return;
      
      for(int i = validationBars; i < bars - validationBars; i++)
      {
         // Check for swing high
         bool isSwingHigh = true;
         double highPrice = iHigh(m_symbol, m_timeframe, i);
         
         for(int j = 1; j <= validationBars; j++)
         {
            if(highPrice <= iHigh(m_symbol, m_timeframe, i-j) || 
               highPrice <= iHigh(m_symbol, m_timeframe, i+j))
            {
               isSwingHigh = false;
               break;
            }
         }
         
         if(isSwingHigh)
         {
            SwingPoint sp;
            sp.time = iTime(m_symbol, m_timeframe, i);
            sp.price = highPrice;
            sp.isHigh = true;
            sp.barIndex = i;
            
            int size = ArraySize(m_swingPoints);
            ArrayResize(m_swingPoints, size + 1);
            m_swingPoints[size] = sp;
         }
         
         // Check for swing low
         bool isSwingLow = true;
         double lowPrice = iLow(m_symbol, m_timeframe, i);
         
         for(int j = 1; j <= validationBars; j++)
         {
            if(lowPrice >= iLow(m_symbol, m_timeframe, i-j) || 
               lowPrice >= iLow(m_symbol, m_timeframe, i+j))
            {
               isSwingLow = false;
               break;
            }
         }
         
         if(isSwingLow)
         {
            SwingPoint sp;
            sp.time = iTime(m_symbol, m_timeframe, i);
            sp.price = lowPrice;
            sp.isHigh = false;
            sp.barIndex = i;
            
            int size = ArraySize(m_swingPoints);
            ArrayResize(m_swingPoints, size + 1);
            m_swingPoints[size] = sp;
         }
      }
   }
   
   void CheckMarketStructureShift()
   {
      int swingCount = ArraySize(m_swingPoints);
      if(swingCount < 4)
         return;
      
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double threshold = m_config.MSSThreshold;
      
      // Find most recent swing high and low
      double lastSwingHigh = 0;
      double lastSwingLow = DBL_MAX;
      datetime lastHighTime = 0;
      datetime lastLowTime = 0;
      
      for(int i = swingCount - 1; i >= 0; i--)
      {
         if(m_swingPoints[i].isHigh && m_swingPoints[i].time > lastHighTime)
         {
            lastSwingHigh = m_swingPoints[i].price;
            lastHighTime = m_swingPoints[i].time;
         }
         if(!m_swingPoints[i].isHigh && m_swingPoints[i].time > lastLowTime)
         {
            lastSwingLow = m_swingPoints[i].price;
            lastLowTime = m_swingPoints[i].time;
         }
      }
      
      // Check for bullish MSS
      if(lastSwingHigh > 0 && currentPrice > lastSwingHigh + threshold)
      {
         m_marketStructure.hasBOS = true;
         m_marketStructure.lastMSS = TimeCurrent();
         m_marketStructure.isUptrend = true;
         m_marketStructure.isDowntrend = false;
      }
      
      // Check for bearish MSS
      if(lastSwingLow < DBL_MAX && currentPrice < lastSwingLow - threshold)
      {
         m_marketStructure.hasBOS = true;
         m_marketStructure.lastMSS = TimeCurrent();
         m_marketStructure.isUptrend = false;
         m_marketStructure.isDowntrend = true;
      }
   }
   
   void CheckBreakOfStructure()
   {
      // BOS is detected in CheckMarketStructureShift
      // Additional validation can be added here
   }
   
   void CheckChangeOfCharacter()
   {
      int swingCount = ArraySize(m_swingPoints);
      if(swingCount < 4)
      {
         m_marketStructure.hasCHoCH = false;
         return;
      }
      
      // Analyze recent swing points for CHoCH pattern
      // Simplified implementation - can be enhanced
      m_marketStructure.hasCHoCH = false;
   }
   
   MarketStructure GetMarketStructure() { return m_marketStructure; }
   SwingPoint GetSwingPoint(int index)
   {
      if(index >= 0 && index < ArraySize(m_swingPoints))
         return m_swingPoints[index];
      SwingPoint empty;
      ZeroMemory(empty);
      return empty;
   }
   int GetSwingPointCount() { return ArraySize(m_swingPoints); }
};

