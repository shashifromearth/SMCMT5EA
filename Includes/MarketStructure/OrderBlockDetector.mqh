//+------------------------------------------------------------------+
//|                                             OrderBlockDetector.mqh|
//|                        Order Block Detector                       |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Enums/SMCEnums.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Config/EAConfig.mqh"
#include "FVGDetector.mqh"
#include "../Indicators/IndicatorWrapper.mqh"

//+------------------------------------------------------------------+
//| Order Block Detector - Single Responsibility                    |
//+------------------------------------------------------------------+
class COrderBlockDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CEAConfig* m_config;
   ILogger* m_logger;
   CFVGDetector* m_fvgDetector;
   
   OrderBlock m_orderBlocks[];
   
public:
   COrderBlockDetector(string symbol, ENUM_TIMEFRAMES timeframe, 
                       CEAConfig* config, CFVGDetector* fvgDetector, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_config = config;
      m_fvgDetector = fvgDetector;
      m_logger = logger;
      ArrayResize(m_orderBlocks, 0);
   }
   
   void Detect()
   {
      ArrayResize(m_orderBlocks, 0);
      
      int bars = iBars(m_symbol, m_timeframe);
      if(bars < 2)
         return;
      
      int lookback = m_config.OrderBlockLookback;
      
      for(int i = 1; i < bars && i < lookback; i++)
      {
         double open1 = iOpen(m_symbol, m_timeframe, i+1);
         double close1 = iClose(m_symbol, m_timeframe, i+1);
         double open2 = iOpen(m_symbol, m_timeframe, i);
         double close2 = iClose(m_symbol, m_timeframe, i);
         
         // Bullish Order Block
         bool isBearishCandle = close1 < open1;
         bool isBullishMove = close2 > open2 && close2 > open1;
         
         if(isBearishCandle && isBullishMove)
         {
            OrderBlock ob;
            ob.time = iTime(m_symbol, m_timeframe, i+1);
            ob.high = iHigh(m_symbol, m_timeframe, i+1);
            ob.low = iLow(m_symbol, m_timeframe, i+1);
            ob.isBullish = true;
            ob.barIndex = i+1;
            ob.volume = (double)iTickVolume(m_symbol, m_timeframe, i+1);
            ob.hasVolumeSpike = CheckVolumeSpike(i+1);
            ob.hasFVGNearby = CheckFVGNearOrderBlock(ob.high, ob.low, true);
            ob.qualityScore = CalculateOBQuality(ob);
            ob.active = IsOrderBlockActive(ob, true) && 
                       (ob.qualityScore >= 5 || !m_config.RequireVolumeConfirmation);
            
            int size = ArraySize(m_orderBlocks);
            ArrayResize(m_orderBlocks, size + 1);
            m_orderBlocks[size] = ob;
         }
         
         // Bearish Order Block
         bool isBullishCandle = close1 > open1;
         bool isBearishMove = close2 < open2 && close2 < open1;
         
         if(isBullishCandle && isBearishMove)
         {
            OrderBlock ob;
            ob.time = iTime(m_symbol, m_timeframe, i+1);
            ob.high = iHigh(m_symbol, m_timeframe, i+1);
            ob.low = iLow(m_symbol, m_timeframe, i+1);
            ob.isBullish = false;
            ob.barIndex = i+1;
            ob.volume = (double)iTickVolume(m_symbol, m_timeframe, i+1);
            ob.hasVolumeSpike = CheckVolumeSpike(i+1);
            ob.hasFVGNearby = CheckFVGNearOrderBlock(ob.high, ob.low, false);
            ob.qualityScore = CalculateOBQuality(ob);
            ob.active = IsOrderBlockActive(ob, false) && 
                       (ob.qualityScore >= 5 || !m_config.RequireVolumeConfirmation);
            
            int size = ArraySize(m_orderBlocks);
            ArrayResize(m_orderBlocks, size + 1);
            m_orderBlocks[size] = ob;
         }
      }
   }
   
   OrderBlock GetOrderBlock(int index)
   {
      if(index >= 0 && index < ArraySize(m_orderBlocks))
         return m_orderBlocks[index];
      OrderBlock empty;
      ZeroMemory(empty);
      return empty;
   }
   
   int GetOrderBlockCount() { return ArraySize(m_orderBlocks); }
   
   int FindBullishOB(int lookback)
   {
      for(int i = 0; i < ArraySize(m_orderBlocks) && i < lookback; i++)
      {
         if(m_orderBlocks[i].isBullish && m_orderBlocks[i].active)
            return i;
      }
      return -1;
   }
   
   int FindBearishOB(int lookback)
   {
      for(int i = 0; i < ArraySize(m_orderBlocks) && i < lookback; i++)
      {
         if(!m_orderBlocks[i].isBullish && m_orderBlocks[i].active)
            return i;
      }
      return -1;
   }
   
   // Calculate OB quality using original algorithm (0-100 scale) - PUBLIC
   int CalculateOBQualityForBar(int barIndex, bool isBullish, CATRIndicator* atrIndicator)
   {
      int score = 0;
      
      if(barIndex < 0 || barIndex >= iBars(m_symbol, m_timeframe))
         return 0;
      
      // Volume spike (20 points)
      long volume_i = iTickVolume(m_symbol, m_timeframe, barIndex);
      long volume_avg = 0;
      int totalBars = iBars(m_symbol, m_timeframe);
      int avgCount = 0;
      for(int i = 1; i <= 20; i++)
      {
         if(barIndex + i < totalBars)
         {
            volume_avg += iTickVolume(m_symbol, m_timeframe, barIndex + i);
            avgCount++;
         }
      }
      if(avgCount > 0)
         volume_avg /= avgCount;
      
      if(volume_avg > 0 && volume_i >= volume_avg * 0.9)
         score += 20;
      else if(volume_avg == 0)
         score += 15;
      
      // Price movement after OB (30 points)
      double price_after = 0;
      if(isBullish)
      {
         double obLow = iLow(m_symbol, m_timeframe, barIndex);
         if(barIndex >= 2)
            price_after = iClose(m_symbol, m_timeframe, barIndex - 2);
         if(price_after > obLow)
            score += 30;
         else
            score += 15;
      }
      else
      {
         double obHigh = iHigh(m_symbol, m_timeframe, barIndex);
         if(barIndex >= 2)
            price_after = iClose(m_symbol, m_timeframe, barIndex - 2);
         if(price_after < obHigh)
            score += 30;
         else
            score += 15;
      }
      
      // Recent OB (25 points - within 24 hours)
      datetime obTime = iTime(m_symbol, m_timeframe, barIndex);
      datetime currentTime = TimeCurrent();
      int hoursSinceOB = (int)((currentTime - obTime) / 3600);
      if(hoursSinceOB <= 24)
         score += 25;
      else if(hoursSinceOB <= 48)
         score += 15;
      
      // OB size (15 points)
      double obSize = 0;
      double high = iHigh(m_symbol, m_timeframe, barIndex);
      double low = iLow(m_symbol, m_timeframe, barIndex);
      obSize = high - low;
      
      if(atrIndicator != NULL)
      {
         double atr = atrIndicator.GetValue(0);
         if(atr > 0)
         {
            if(obSize >= atr * 0.2 && obSize <= atr * 2.0)
               score += 15;
            else
               score += 10;
         }
         else
         {
            score += 10;
         }
      }
      else
      {
         score += 10;
      }
      
      // Base score for valid OB (10 points)
      score += 10;
      
      return score;
   }
   
private:
   bool CheckVolumeSpike(int barIndex)
   {
      if(!m_config.RequireVolumeConfirmation)
         return true;
      
      long currentVolume = iTickVolume(m_symbol, m_timeframe, barIndex);
      long totalVolume = 0;
      int lookback = 20;
      
      for(int i = 1; i <= lookback; i++)
      {
         totalVolume += iTickVolume(m_symbol, m_timeframe, barIndex + i);
      }
      
      double avgVolume = (double)totalVolume / lookback;
      if(avgVolume == 0)
         return false;
      
      return (currentVolume >= avgVolume * m_config.VolumeSpikeMultiplier);
   }
   
   bool CheckFVGNearOrderBlock(double obHigh, double obLow, bool isBullish)
   {
      if(!m_config.RequireFVGNearOB)
         return true;
      
      double tolerance = m_config.EqualHighLowTolerance * 3;
      
      for(int i = 0; i < m_fvgDetector.GetFVGCount(); i++)
      {
         FairValueGap fvg = m_fvgDetector.GetFVG(i);
         if(fvg.mitigated)
            continue;
         
         bool overlaps = (fvg.bottomPrice <= obHigh + tolerance && 
                        fvg.topPrice >= obLow - tolerance);
         
         if(overlaps)
         {
            if(isBullish && fvg.type == FVG_BULLISH)
               return true;
            if(!isBullish && fvg.type == FVG_BEARISH)
               return true;
         }
      }
      return false;
   }
   
   int CalculateOBQuality(OrderBlock &ob)
   {
      // This is a simplified version - use CalculateOBQualityForBar() for full calculation
      int score = 0;
      
      if(ob.hasVolumeSpike)
         score += 3;
      if(ob.hasFVGNearby)
         score += 2;
      if(IsNearLiquidityZone((ob.high + ob.low) / 2.0))
         score += 2;
      
      datetime currentTime = TimeCurrent();
      int hoursSinceOB = (int)((currentTime - ob.time) / 3600);
      if(hoursSinceOB <= 12)
         score += 2;
      
      return score;
   }
   
   bool IsOrderBlockActive(OrderBlock &ob, bool isBullish)
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      datetime currentTime = TimeCurrent();
      
      int hoursSinceOB = (int)((currentTime - ob.time) / 3600);
      if(hoursSinceOB > m_config.OBTimeFilter)
         return false;
      
      if(isBullish)
      {
         if(currentPrice < ob.low)
            return false;
      }
      else
      {
         if(currentPrice > ob.high)
            return false;
      }
      
      return true;
   }
   
   bool IsNearLiquidityZone(double price)
   {
      // Simplified - would need liquidity zone detector
      return false;
   }
};

