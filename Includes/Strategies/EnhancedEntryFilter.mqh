//+------------------------------------------------------------------+
//|                                        EnhancedEntryFilter.mqh   |
//|              Advanced Entry Filtering System                     |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "../MarketStructure/MarketStructureAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Enhanced Entry Filter - Multi-layer validation                  |
//+------------------------------------------------------------------+
class CEnhancedEntryFilter
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CEAConfig* m_config;
   CATRIndicator* m_atrIndicator;
   CMarketStructureAnalyzer* m_msAnalyzer;
   
   // Technical indicators
   int m_rsiHandle;
   int m_emaFastHandle;
   int m_emaSlowHandle;
   int m_adxHandle;
   
public:
   CEnhancedEntryFilter(string symbol, ENUM_TIMEFRAMES tf, CEAConfig* config,
                       CATRIndicator* atr, CMarketStructureAnalyzer* msAnalyzer)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_config = config;
      m_atrIndicator = atr;
      m_msAnalyzer = msAnalyzer;
      
      // Initialize indicators
      m_rsiHandle = iRSI(m_symbol, m_config.RSIPeriod, PRICE_CLOSE);
      m_emaFastHandle = iMA(m_symbol, PERIOD_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_emaSlowHandle = iMA(m_symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_adxHandle = iADX(m_symbol, PERIOD_M15, m_config.ADXPeriod);
   }
   
   ~CEnhancedEntryFilter()
   {
      if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_emaFastHandle != INVALID_HANDLE) IndicatorRelease(m_emaFastHandle);
      if(m_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(m_emaSlowHandle);
      if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
   }
   
   // Main entry validation
   bool ValidateEntry(TRADE_DIRECTION direction, double entryPrice, double stopLoss, double takeProfit, int &confidenceScore)
   {
      confidenceScore = 0;
      
      // Layer 1: Trend alignment (20 points)
      if(!CheckTrendAlignment(direction))
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Trend misalignment");
         return false;
      }
      confidenceScore += 20;
      
      // Layer 2: Momentum confirmation (20 points)
      int momentumScore = CheckMomentum(direction);
      if(momentumScore < 10)
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Weak momentum (", momentumScore, "/20)");
         return false;
      }
      confidenceScore += momentumScore;
      
      // Layer 3: Market structure (20 points)
      int structureScore = CheckMarketStructure(direction);
      if(structureScore < 10)
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Weak market structure (", structureScore, "/20)");
         return false;
      }
      confidenceScore += structureScore;
      
      // Layer 4: Volatility filter (15 points)
      int volatilityScore = CheckVolatility(entryPrice, stopLoss);
      if(volatilityScore < 8)
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Volatility filter failed (", volatilityScore, "/15)");
         return false;
      }
      confidenceScore += volatilityScore;
      
      // Layer 5: Risk/Reward validation (15 points)
      int rrScore = CheckRiskReward(entryPrice, stopLoss, takeProfit);
      if(rrScore < 10)
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Poor R:R (", rrScore, "/15)");
         return false;
      }
      confidenceScore += rrScore;
      
      // Layer 6: Time-based filter (10 points)
      int timeScore = CheckTimeFilter();
      confidenceScore += timeScore;
      
      // Minimum confidence required: 60/100
      if(confidenceScore < 60)
      {
         if(m_config.EnableDebugLog)
            Print("Entry rejected: Low confidence score (", confidenceScore, "/100)");
         return false;
      }
      
      return true;
   }
   
private:
   // Layer 1: Trend Alignment
   bool CheckTrendAlignment(TRADE_DIRECTION direction)
   {
      if(!m_config.UseEMATrendFilter)
         return true;
      
      double emaFast[], emaSlow[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      
      if(CopyBuffer(m_emaFastHandle, 0, 0, 3, emaFast) < 3) return false;
      if(CopyBuffer(m_emaSlowHandle, 0, 0, 3, emaSlow) < 3) return false;
      
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      
      // BUY: Price above both EMAs, fast EMA above slow EMA
      if(direction == TRADE_BUY)
      {
         bool priceAboveEMAs = (currentPrice > emaFast[0] && currentPrice > emaSlow[0]);
         bool emaBullish = (emaFast[0] > emaSlow[0] && emaFast[1] > emaSlow[1]);
         return priceAboveEMAs && emaBullish;
      }
      // SELL: Price below both EMAs, fast EMA below slow EMA
      else
      {
         bool priceBelowEMAs = (currentPrice < emaFast[0] && currentPrice < emaSlow[0]);
         bool emaBearish = (emaFast[0] < emaSlow[0] && emaFast[1] < emaSlow[1]);
         return priceBelowEMAs && emaBearish;
      }
   }
   
   // Layer 2: Momentum
   int CheckMomentum(TRADE_DIRECTION direction)
   {
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsiHandle, 0, 0, 3, rsi) < 3) return 0;
      
      int score = 0;
      
      if(direction == TRADE_BUY)
      {
         // RSI should be above 50 but not overbought (>70)
         if(rsi[0] > 50 && rsi[0] < 70) score += 10;
         if(rsi[0] > rsi[1]) score += 5; // Rising momentum
         if(rsi[1] > rsi[2]) score += 5; // Continued momentum
      }
      else
      {
         // RSI should be below 50 but not oversold (<30)
         if(rsi[0] < 50 && rsi[0] > 30) score += 10;
         if(rsi[0] < rsi[1]) score += 5; // Falling momentum
         if(rsi[1] < rsi[2]) score += 5; // Continued momentum
      }
      
      return score;
   }
   
   // Layer 3: Market Structure
   int CheckMarketStructure(TRADE_DIRECTION direction)
   {
      if(m_msAnalyzer == NULL) return 10; // Neutral if not available
      
      int score = 0;
      MARKET_STATE state = m_msAnalyzer.GetMarketState();
      
      if(direction == TRADE_BUY)
      {
         if(state == MARKET_STATE_BULLISH) score += 15;
         else if(state == MARKET_STATE_BULLISH_CORRECTION) score += 10;
         else if(state == MARKET_STATE_RANGING) score += 5;
      }
      else
      {
         if(state == MARKET_STATE_BEARISH) score += 15;
         else if(state == MARKET_STATE_BEARISH_CORRECTION) score += 10;
         else if(state == MARKET_STATE_RANGING) score += 5;
      }
      
      // Check for recent BOS/CHoCH
      if(m_msAnalyzer.HasRecentBOS(direction == TRADE_BUY)) score += 5;
      
      return score;
   }
   
   // Layer 4: Volatility Filter
   int CheckVolatility(double entryPrice, double stopLoss)
   {
      if(m_atrIndicator == NULL) return 10; // Neutral
      
      double atr = m_atrIndicator.GetValue(0);
      double slDistance = MathAbs(entryPrice - stopLoss);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // SL should be 1.5x to 3x ATR
      double atrMultiplier = slDistance / atr;
      
      int score = 0;
      if(atrMultiplier >= 1.5 && atrMultiplier <= 3.0) score += 15; // Optimal
      else if(atrMultiplier >= 1.0 && atrMultiplier < 1.5) score += 10; // Acceptable
      else if(atrMultiplier > 3.0 && atrMultiplier <= 4.0) score += 8; // Wide but OK
      else score += 5; // Too tight or too wide
      
      return score;
   }
   
   // Layer 5: Risk/Reward
   int CheckRiskReward(double entryPrice, double stopLoss, double takeProfit)
   {
      double slDistance = MathAbs(entryPrice - stopLoss);
      double tpDistance = (takeProfit > entryPrice) ? (takeProfit - entryPrice) : (entryPrice - takeProfit);
      
      if(slDistance == 0) return 0;
      
      double rr = tpDistance / slDistance;
      
      int score = 0;
      if(rr >= 3.0) score += 15; // Excellent
      else if(rr >= 2.5) score += 12; // Good
      else if(rr >= 2.0) score += 10; // Acceptable
      else if(rr >= 1.5) score += 7; // Poor
      else score += 3; // Very poor
      
      return score;
   }
   
   // Layer 6: Time Filter
   int CheckTimeFilter()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;
      
      // Optimal trading hours: London (8-10), NY (13-15), Overlap (13-16)
      if((hour >= 8 && hour < 10) || (hour >= 13 && hour < 16))
         return 10;
      else if((hour >= 10 && hour < 13) || (hour >= 16 && hour < 20))
         return 7;
      else
         return 5;
   }
};

