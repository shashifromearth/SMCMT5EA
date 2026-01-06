//+------------------------------------------------------------------+
//|                                                  FVGDetector.mqh  |
//|                        Fair Value Gap Detector                    |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Enums/SMCEnums.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Config/EAConfig.mqh"

//+------------------------------------------------------------------+
//| Fair Value Gap Detector - Single Responsibility                  |
//+------------------------------------------------------------------+
class CFVGDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CEAConfig* m_config;
   ILogger* m_logger;
   
   FairValueGap m_fvgArray[];
   
public:
   CFVGDetector(string symbol, ENUM_TIMEFRAMES timeframe, 
                CEAConfig* config, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_config = config;
      m_logger = logger;
      ArrayResize(m_fvgArray, 0);
   }
   
   void Detect()
   {
      ArrayResize(m_fvgArray, 0);
      
      int bars = iBars(m_symbol, m_timeframe);
      if(bars < 3)
         return;
      
      int lookback = m_config.FVGLookback;
      double minSize = m_config.FVGMinSize;
      
      for(int i = 2; i < bars && i < lookback; i++)
      {
         double high1 = iHigh(m_symbol, m_timeframe, i+1);
         double low1 = iLow(m_symbol, m_timeframe, i+1);
         double high3 = iHigh(m_symbol, m_timeframe, i-1);
         double low3 = iLow(m_symbol, m_timeframe, i-1);
         
         // Bullish FVG: Low of candle 1 > High of candle 3
         if(low1 > high3 && (low1 - high3) >= minSize)
         {
            FairValueGap fvg;
            fvg.startTime = iTime(m_symbol, m_timeframe, i+1);
            fvg.endTime = iTime(m_symbol, m_timeframe, i-1);
            fvg.bottomPrice = high3;
            fvg.topPrice = low1;
            fvg.type = FVG_BULLISH;
            fvg.mitigated = false;
            fvg.startBar = i+1;
            fvg.endBar = i-1;
            
            int size = ArraySize(m_fvgArray);
            ArrayResize(m_fvgArray, size + 1);
            m_fvgArray[size] = fvg;
         }
         
         // Bearish FVG: High of candle 1 < Low of candle 3
         if(high1 < low3 && (low3 - high1) >= minSize)
         {
            FairValueGap fvg;
            fvg.startTime = iTime(m_symbol, m_timeframe, i+1);
            fvg.endTime = iTime(m_symbol, m_timeframe, i-1);
            fvg.topPrice = high1;
            fvg.bottomPrice = low3;
            fvg.type = FVG_BEARISH;
            fvg.mitigated = false;
            fvg.startBar = i+1;
            fvg.endBar = i-1;
            
            int size = ArraySize(m_fvgArray);
            ArrayResize(m_fvgArray, size + 1);
            m_fvgArray[size] = fvg;
         }
      }
      
      // Check for FVG mitigation
      if(m_config.TrackFVGMitigation)
      {
         CheckMitigation();
      }
   }
   
   void CheckMitigation()
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      
      for(int i = 0; i < ArraySize(m_fvgArray); i++)
      {
         if(m_fvgArray[i].mitigated)
            continue;
         
         if(m_fvgArray[i].type == FVG_BULLISH)
         {
            if(currentPrice <= m_fvgArray[i].topPrice && currentPrice >= m_fvgArray[i].bottomPrice)
            {
               m_fvgArray[i].mitigated = true;
            }
         }
         else if(m_fvgArray[i].type == FVG_BEARISH)
         {
            if(currentPrice >= m_fvgArray[i].bottomPrice && currentPrice <= m_fvgArray[i].topPrice)
            {
               m_fvgArray[i].mitigated = true;
            }
         }
      }
   }
   
   FairValueGap GetFVG(int index)
   {
      if(index >= 0 && index < ArraySize(m_fvgArray))
         return m_fvgArray[index];
      FairValueGap empty;
      ZeroMemory(empty);
      return empty;
   }
   
   int GetFVGCount() { return ArraySize(m_fvgArray); }
   
   bool IsPriceInFVG(double price, bool isBullish)
   {
      for(int i = 0; i < ArraySize(m_fvgArray); i++)
      {
         if(m_fvgArray[i].mitigated)
            continue;
         
         if(isBullish && m_fvgArray[i].type == FVG_BULLISH)
         {
            if(price >= m_fvgArray[i].bottomPrice && price <= m_fvgArray[i].topPrice)
               return true;
         }
         else if(!isBullish && m_fvgArray[i].type == FVG_BEARISH)
         {
            if(price >= m_fvgArray[i].bottomPrice && price <= m_fvgArray[i].topPrice)
               return true;
         }
      }
      return false;
   }
};

