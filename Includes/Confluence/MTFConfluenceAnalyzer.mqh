//+------------------------------------------------------------------+
//|                                      MTFConfluenceAnalyzer.mqh   |
//|              Multi-Timeframe Confluence Analysis Engine          |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "3.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Enums/SMCEnums.mqh"
#include "../MarketStructure/MarketStructureAnalyzer.mqh"
#include "../MarketStructure/FVGDetector.mqh"
#include "../MarketStructure/OrderBlockDetector.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Multi-Timeframe Confluence Score Structure                      |
//+------------------------------------------------------------------+
struct MTFConfluenceScore
{
   int monthlyScore;      // 0-20 points
   int weeklyScore;        // 0-20 points
   int dailyScore;         // 0-20 points
   int h4Score;           // 0-20 points
   int h1Score;           // 0-20 points
   int totalScore;         // 0-100 points
   TRADE_DIRECTION bias;   // Overall bias
   bool isAligned;         // All timeframes aligned
};

//+------------------------------------------------------------------+
//| Institutional Footprint Structure                                |
//+------------------------------------------------------------------+
struct InstitutionalFootprint
{
   bool hasFairValueGap;
   bool hasOrderBlock;
   bool hasLiquidityGrab;
   bool hasBreakOfStructure;
   bool hasChangeOfCharacter;
   bool hasVolumeSpike;
   bool hasEqualHighLow;
   double confluenceScore;  // 0-100
   bool isValid;            // Score >= 90
};

//+------------------------------------------------------------------+
//| Multi-Timeframe Confluence Analyzer                             |
//+------------------------------------------------------------------+
class CMTFConfluenceAnalyzer
{
private:
   string m_symbol;
   CEAConfig* m_config;
   ILogger* m_logger;
   
   // Market structure analyzers for each timeframe
   CMarketStructureAnalyzer* m_msDaily;
   CMarketStructureAnalyzer* m_msH4;
   CMarketStructureAnalyzer* m_msH1;
   CFVGDetector* m_fvgDetector;
   COrderBlockDetector* m_obDetector;
   CATRIndicator* m_atrIndicator;
   
   // Indicator handles
   int m_rsiH4Handle;
   int m_rsiH1Handle;
   int m_macdH4Handle;
   int m_macdH1Handle;
   int m_adxH4Handle;
   int m_ema200MonthlyHandle;
   int m_ema200WeeklyHandle;
   int m_ema200DailyHandle;
   
public:
   CMTFConfluenceAnalyzer(string symbol, CEAConfig* config, 
                          CMarketStructureAnalyzer* msDaily,
                          CMarketStructureAnalyzer* msH4,
                          CMarketStructureAnalyzer* msH1,
                          CFVGDetector* fvgDetector,
                          COrderBlockDetector* obDetector,
                          CATRIndicator* atrIndicator,
                          ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_logger = logger;
      m_msDaily = msDaily;
      m_msH4 = msH4;
      m_msH1 = msH1;
      m_fvgDetector = fvgDetector;
      m_obDetector = obDetector;
      m_atrIndicator = atrIndicator;
      
      // Initialize indicators
      m_rsiH4Handle = iRSI(m_symbol, PERIOD_H4, 14, PRICE_CLOSE);
      m_rsiH1Handle = iRSI(m_symbol, PERIOD_H1, 14, PRICE_CLOSE);
      m_macdH4Handle = iMACD(m_symbol, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);
      m_macdH1Handle = iMACD(m_symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
      m_adxH4Handle = iADX(m_symbol, PERIOD_H4, 14);
      m_ema200MonthlyHandle = iMA(m_symbol, PERIOD_MN1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200WeeklyHandle = iMA(m_symbol, PERIOD_W1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200DailyHandle = iMA(m_symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   ~CMTFConfluenceAnalyzer()
   {
      if(m_rsiH4Handle != INVALID_HANDLE) IndicatorRelease(m_rsiH4Handle);
      if(m_rsiH1Handle != INVALID_HANDLE) IndicatorRelease(m_rsiH1Handle);
      if(m_macdH4Handle != INVALID_HANDLE) IndicatorRelease(m_macdH4Handle);
      if(m_macdH1Handle != INVALID_HANDLE) IndicatorRelease(m_macdH1Handle);
      if(m_adxH4Handle != INVALID_HANDLE) IndicatorRelease(m_adxH4Handle);
      if(m_ema200MonthlyHandle != INVALID_HANDLE) IndicatorRelease(m_ema200MonthlyHandle);
      if(m_ema200WeeklyHandle != INVALID_HANDLE) IndicatorRelease(m_ema200WeeklyHandle);
      if(m_ema200DailyHandle != INVALID_HANDLE) IndicatorRelease(m_ema200DailyHandle);
   }
   
   // Main analysis function - returns total confluence score
   MTFConfluenceScore AnalyzeConfluence(TRADE_DIRECTION direction)
   {
      MTFConfluenceScore score;
      ZeroMemory(score);
      score.bias = direction;
      
      // Level 1: Monthly/Weekly Bias (Foundation) - 20 points each
      score.monthlyScore = AnalyzeMonthlyBias(direction);
      score.weeklyScore = AnalyzeWeeklyBias(direction);
      
      // Level 2: Daily Structure - 20 points
      score.dailyScore = AnalyzeDailyStructure(direction);
      
      // Level 3: H4 Structure - 20 points
      score.h4Score = AnalyzeH4Structure(direction);
      
      // Level 4: H1 Structure - 20 points
      score.h1Score = AnalyzeH1Structure(direction);
      
      // Calculate total
      score.totalScore = score.monthlyScore + score.weeklyScore + 
                        score.dailyScore + score.h4Score + score.h1Score;
      
      // All timeframes must be aligned for perfect setup
      score.isAligned = (score.totalScore >= 95 && 
                        score.monthlyScore >= 18 &&
                        score.weeklyScore >= 18 &&
                        score.dailyScore >= 18 &&
                        score.h4Score >= 18 &&
                        score.h1Score >= 18);
      
      return score;
   }
   
   // Detect institutional footprint
   InstitutionalFootprint DetectInstitutionalFootprint(TRADE_DIRECTION direction)
   {
      InstitutionalFootprint footprint;
      ZeroMemory(footprint);
      
      int score = 0;
      
      // Check for Fair Value Gap (15 points)
      footprint.hasFairValueGap = HasFVGAtEntry(direction);
      if(footprint.hasFairValueGap) score += 15;
      
      // Check for Order Block (15 points)
      footprint.hasOrderBlock = HasFreshOrderBlock(direction);
      if(footprint.hasOrderBlock) score += 15;
      
      // Check for Liquidity Grab (15 points)
      footprint.hasLiquidityGrab = HasLiquiditySweep(direction);
      if(footprint.hasLiquidityGrab) score += 15;
      
      // Check for Break of Structure (15 points)
      footprint.hasBreakOfStructure = HasBOS(direction);
      if(footprint.hasBreakOfStructure) score += 15;
      
      // Check for Change of Character (15 points)
      footprint.hasChangeOfCharacter = HasCHoCH(direction);
      if(footprint.hasChangeOfCharacter) score += 15;
      
      // Check for Volume Spike (10 points)
      footprint.hasVolumeSpike = HasVolumeSpike();
      if(footprint.hasVolumeSpike) score += 10;
      
      // Check for Equal High/Low (10 points)
      footprint.hasEqualHighLow = HasEqualHighLow(direction);
      if(footprint.hasEqualHighLow) score += 10;
      
      footprint.confluenceScore = score;
      footprint.isValid = (score >= 90); // 90/100 minimum
      
      return footprint;
   }
   
private:
   // Level 1: Monthly Bias Analysis
   int AnalyzeMonthlyBias(TRADE_DIRECTION direction)
   {
      int score = 0;
      
      // Check monthly EMA200
      double ema200[];
      ArraySetAsSeries(ema200, true);
      if(CopyBuffer(m_ema200MonthlyHandle, 0, 0, 3, ema200) >= 3)
      {
         double currentPrice = iClose(m_symbol, PERIOD_MN1, 0);
         
         if(direction == TRADE_BUY)
         {
            if(currentPrice > ema200[0]) score += 10; // Above 200MA
            if(ema200[0] > ema200[1]) score += 5;     // 200MA rising
            if(currentPrice > iClose(m_symbol, PERIOD_MN1, 1)) score += 5; // Higher close
         }
         else
         {
            if(currentPrice < ema200[0]) score += 10; // Below 200MA
            if(ema200[0] < ema200[1]) score += 5;     // 200MA falling
            if(currentPrice < iClose(m_symbol, PERIOD_MN1, 1)) score += 5; // Lower close
         }
      }
      
      return score;
   }
   
   // Level 1: Weekly Bias Analysis
   int AnalyzeWeeklyBias(TRADE_DIRECTION direction)
   {
      int score = 0;
      
      // Check weekly EMA200
      double ema200[];
      ArraySetAsSeries(ema200, true);
      if(CopyBuffer(m_ema200WeeklyHandle, 0, 0, 3, ema200) >= 3)
      {
         double currentPrice = iClose(m_symbol, PERIOD_W1, 0);
         
         if(direction == TRADE_BUY)
         {
            if(currentPrice > ema200[0]) score += 10; // Above 200MA
            // Check for 2+ consecutive bullish closes
            if(iClose(m_symbol, PERIOD_W1, 0) > iOpen(m_symbol, PERIOD_W1, 0) &&
               iClose(m_symbol, PERIOD_W1, 1) > iOpen(m_symbol, PERIOD_W1, 1))
               score += 10;
         }
         else
         {
            if(currentPrice < ema200[0]) score += 10; // Below 200MA
            // Check for 2+ consecutive bearish closes
            if(iClose(m_symbol, PERIOD_W1, 0) < iOpen(m_symbol, PERIOD_W1, 0) &&
               iClose(m_symbol, PERIOD_W1, 1) < iOpen(m_symbol, PERIOD_W1, 1))
               score += 10;
         }
      }
      
      return score;
   }
   
   // Level 2: Daily Structure Analysis
   int AnalyzeDailyStructure(TRADE_DIRECTION direction)
   {
      int score = 0;
      
      if(m_msDaily == NULL) return 0;
      
      MARKET_STATE state = m_msDaily.GetMarketState();
      
      if(direction == TRADE_BUY)
      {
         if(state == MARKET_STATE_BULLISH) score += 10;
         if(m_msDaily.HasRecentBOS(true)) score += 10; // BOS confirmed
      }
      else
      {
         if(state == MARKET_STATE_BEARISH) score += 10;
         if(m_msDaily.HasRecentBOS(false)) score += 10; // BOS confirmed
      }
      
      return score;
   }
   
   // Level 3: H4 Structure Analysis
   int AnalyzeH4Structure(TRADE_DIRECTION direction)
   {
      int score = 0;
      
      if(m_msH4 == NULL) return 0;
      
      MARKET_STATE state = m_msH4.GetMarketState();
      
      if(direction == TRADE_BUY)
      {
         if(state == MARKET_STATE_BULLISH) score += 10;
         if(m_msH4.HasRecentBOS(true)) score += 10; // BOS confirmed
      }
      else
      {
         if(state == MARKET_STATE_BEARISH) score += 10;
         if(m_msH4.HasRecentBOS(false)) score += 10; // BOS confirmed
      }
      
      return score;
   }
   
   // Level 4: H1 Structure Analysis
   int AnalyzeH1Structure(TRADE_DIRECTION direction)
   {
      int score = 0;
      
      if(m_msH1 == NULL) return 0;
      
      MARKET_STATE state = m_msH1.GetMarketState();
      
      if(direction == TRADE_BUY)
      {
         if(state == MARKET_STATE_BULLISH) score += 10;
         if(m_msH1.HasRecentBOS(true)) score += 10; // BOS confirmed
      }
      else
      {
         if(state == MARKET_STATE_BEARISH) score += 10;
         if(m_msH1.HasRecentBOS(false)) score += 10; // BOS confirmed
      }
      
      return score;
   }
   
public:
   bool HasLiquiditySweep(TRADE_DIRECTION direction)
   {
      // Check for recent sweep of highs/lows (last 20 bars)
      for(int i = 1; i <= 20; i++)
      {
         double high = iHigh(m_symbol, PERIOD_M5, i);
         double low = iLow(m_symbol, PERIOD_M5, i);
         double prevHigh = iHigh(m_symbol, PERIOD_M5, i+1);
         double prevLow = iLow(m_symbol, PERIOD_M5, i+1);
         
         if(direction == TRADE_BUY)
         {
            // Sweep of lows (stop hunt before reversal)
            if(low < prevLow && iClose(m_symbol, PERIOD_M5, i) > iOpen(m_symbol, PERIOD_M5, i))
               return true;
         }
         else
         {
            // Sweep of highs (stop hunt before reversal)
            if(high > prevHigh && iClose(m_symbol, PERIOD_M5, i) < iOpen(m_symbol, PERIOD_M5, i))
               return true;
         }
      }
      
      return false;
   }
   
   bool HasBOS(TRADE_DIRECTION direction)
   {
      if(m_msH1 == NULL) return false;
      return m_msH1.HasRecentBOS(direction == TRADE_BUY);
   }
   
   bool HasCHoCH(TRADE_DIRECTION direction)
   {
      if(m_msH1 == NULL) return false;
      // CHoCH is implied by BOS - if we have BOS, we likely have CHoCH
      return HasBOS(direction);
   }
   
   bool HasFVGAtEntry(TRADE_DIRECTION direction)
   {
      if(m_fvgDetector == NULL) return false;
      
      double currentPrice = iClose(m_symbol, PERIOD_M5, 0);
      
      for(int i = 0; i < m_fvgDetector.GetFVGCount(); i++)
      {
         FairValueGap fvg = m_fvgDetector.GetFVG(i);
         if(fvg.mitigated) continue;
         
         if(direction == TRADE_BUY && fvg.type == FVG_BULLISH)
         {
            if(currentPrice >= fvg.bottomPrice && currentPrice <= fvg.topPrice)
               return true;
         }
         else if(direction == TRADE_SELL && fvg.type == FVG_BEARISH)
         {
            if(currentPrice >= fvg.bottomPrice && currentPrice <= fvg.topPrice)
               return true;
         }
      }
      
      return false;
   }
   
   bool HasFreshOrderBlock(TRADE_DIRECTION direction)
   {
      if(m_obDetector == NULL) return false;
      
      datetime currentTime = TimeCurrent();
      
      if(direction == TRADE_BUY)
      {
         int obIndex = m_obDetector.FindBullishOB(50);
         if(obIndex >= 0)
         {
            OrderBlock ob = m_obDetector.GetOrderBlock(obIndex);
            int hoursSinceOB = (int)((currentTime - ob.time) / 3600);
            return (hoursSinceOB < 12); // Fresh OB (<12 hours)
         }
      }
      else
      {
         int obIndex = m_obDetector.FindBearishOB(50);
         if(obIndex >= 0)
         {
            OrderBlock ob = m_obDetector.GetOrderBlock(obIndex);
            int hoursSinceOB = (int)((currentTime - ob.time) / 3600);
            return (hoursSinceOB < 12); // Fresh OB (<12 hours)
         }
      }
      
      return false;
   }
   
   bool HasVolumeSpike()
   {
      long currentVolume = iTickVolume(m_symbol, PERIOD_M5, 0);
      long avgVolume = 0;
      
      for(int i = 1; i <= 20; i++)
      {
         avgVolume += iTickVolume(m_symbol, PERIOD_M5, i);
      }
      avgVolume /= 20;
      
      return (currentVolume >= avgVolume * 3.0); // 3x average volume
   }
   
   bool HasEqualHighLow(TRADE_DIRECTION direction)
   {
      double currentPrice = iClose(m_symbol, PERIOD_M5, 0);
      double tolerance = 0.0002; // 2 pips tolerance
      
      // Check last 50 bars for equal highs/lows
      for(int i = 1; i <= 50; i++)
      {
         double high = iHigh(m_symbol, PERIOD_M5, i);
         double low = iLow(m_symbol, PERIOD_M5, i);
         
         if(direction == TRADE_BUY)
         {
            // Check for equal lows (support level)
            if(MathAbs(currentPrice - low) <= tolerance)
               return true;
         }
         else
         {
            // Check for equal highs (resistance level)
            if(MathAbs(currentPrice - high) <= tolerance)
               return true;
         }
      }
      
      return false;
   }
};

