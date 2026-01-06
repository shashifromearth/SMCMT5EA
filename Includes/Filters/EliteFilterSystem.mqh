//+------------------------------------------------------------------+
//|                                        EliteFilterSystem.mqh     |
//|               Elite Filter System - 12 Validation Layers         |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "3.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Elite Filter System - Extreme Selectivity                       |
//+------------------------------------------------------------------+
class CEliteFilterSystem
{
private:
   string m_symbol;
   CEAConfig* m_config;
   CATRIndicator* m_atrIndicator;
   ILogger* m_logger;
   
   // Indicator handles
   int m_adxHandle;
   int m_ema20Handle;
   
public:
   CEliteFilterSystem(string symbol, CEAConfig* config,
                     CATRIndicator* atrIndicator,
                     ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
      
      m_adxHandle = iADX(m_symbol, PERIOD_M15, 14);
      m_ema20Handle = iMA(m_symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   ~CEliteFilterSystem()
   {
      if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_ema20Handle != INVALID_HANDLE) IndicatorRelease(m_ema20Handle);
   }
   
   // Main validation - ALL filters must pass
   bool ValidateAllFilters(TRADE_DIRECTION direction, string &rejectionReason)
   {
      rejectionReason = "";
      
      // Filter 1: Market Regime Filter
      if(!ValidateMarketRegime(rejectionReason))
         return false;
      
      // Filter 2: Liquidity Filter
      if(!ValidateLiquidity(direction, rejectionReason))
         return false;
      
      // Filter 3: Correlation Filter (simplified)
      if(!ValidateCorrelation(direction, rejectionReason))
         return false;
      
      // Filter 4: Order Flow Filter (simplified)
      if(!ValidateOrderFlow(direction, rejectionReason))
         return false;
      
      // Filter 5: Volatility Filter
      if(!ValidateVolatility(rejectionReason))
         return false;
      
      // Filter 6: Trend Strength Filter
      if(!ValidateTrendStrength(direction, rejectionReason))
         return false;
      
      // Filter 7: Spread Filter
      if(!ValidateSpread(rejectionReason))
         return false;
      
      // Filter 8: Time Filter
      if(!ValidateTime(rejectionReason))
         return false;
      
      // Filter 9: News Filter
      if(!ValidateNews(rejectionReason))
         return false;
      
      // Filter 10: Momentum Filter
      if(!ValidateMomentum(direction, rejectionReason))
         return false;
      
      // Filter 11: Volume Filter
     // if(!ValidateVolume(rejectionReason))
       //  return false;
      
      // Filter 12: Structure Filter
      if(!ValidateStructure(direction, rejectionReason))
         return false;
      
      return true; // All filters passed
   }
   
private:
   // Filter 1: Market Regime Filter
   bool ValidateMarketRegime(string &reason)
   {
      double atr = m_atrIndicator.GetValue(0);
      double atrDaily = 0;
      
      // Calculate daily average ATR
      for(int i = 1; i <= 20; i++)
      {
         atrDaily += m_atrIndicator.GetValue(i);
      }
      atrDaily /= 20;
      
      // Skip if ATR < 50% of daily average (too slow)
      if(atr < atrDaily * 0.5)
      {
         reason = "ATR too low: " + DoubleToString(atr, 5) + " < " + DoubleToString(atrDaily * 0.5, 5);
         return false;
      }
      
      // Check ADX
      double adx[];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(m_adxHandle, 0, 0, 1, adx) >= 1)
      {
         if(adx[0] < 20.0)
         {
            reason = "ADX too weak: " + DoubleToString(adx[0], 2) + " < 20";
            return false;
         }
      }
      
      return true;
   }
   
   // Filter 2: Liquidity Filter
   bool ValidateLiquidity(TRADE_DIRECTION direction, string &reason)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;
      
      // Only trade at London/NY session highs/lows
      if(hour >= 13 && hour < 16) // London/NY overlap
      {
         double sessionHigh = iHigh(m_symbol, PERIOD_M15, iHighest(m_symbol, PERIOD_M15, MODE_HIGH, 20, 0));
         double sessionLow = iLow(m_symbol, PERIOD_M15, iLowest(m_symbol, PERIOD_M15, MODE_LOW, 20, 0));
         double currentPrice = iClose(m_symbol, PERIOD_M15, 0);
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         if(direction == TRADE_BUY)
         {
            // Must be near session low (liquidity grab)
            if(currentPrice > sessionLow + (20.0 * point * 10))
            {
               reason = "Not at session low for BUY";
               return false;
            }
         }
         else
         {
            // Must be near session high (liquidity grab)
            if(currentPrice < sessionHigh - (20.0 * point * 10))
            {
               reason = "Not at session high for SELL";
               return false;
            }
         }
      }
      
      return true;
   }
   
   // Filter 3: Correlation Filter (simplified)
   bool ValidateCorrelation(TRADE_DIRECTION direction, string &reason)
   {
      // Simplified: In production, check EURUSD/GBPUSD correlation
      // For now, always pass
      return true;
   }
   
   // Filter 4: Order Flow Filter (simplified)
   bool ValidateOrderFlow(TRADE_DIRECTION direction, string &reason)
   {
      // Simplified: Check volume
      long currentVolume = iTickVolume(m_symbol, PERIOD_M5, 0);
      long avgVolume = 0;
      
      for(int i = 1; i <= 20; i++)
      {
         avgVolume += iTickVolume(m_symbol, PERIOD_M5, i);
      }
      avgVolume /= 20;
      
      if(currentVolume < avgVolume * 2.0) // Require 2x average volume
      {
         reason = "Volume too low: " + IntegerToString(currentVolume) + " < " + IntegerToString((int)(avgVolume * 2.0));
         return false;
      }
      
      return true;
   }
   
   // Filter 5: Volatility Filter
   bool ValidateVolatility(string &reason)
   {
      double atr = m_atrIndicator.GetValue(0);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Minimum volatility: 0.0005 (5 pips for XAUUSD)
      if(atr < 0.0005)
      {
         reason = "Volatility too low: " + DoubleToString(atr, 5) + " < 0.0005";
         return false;
      }
      
      return true;
   }
   
   // Filter 6: Trend Strength Filter
   bool ValidateTrendStrength(TRADE_DIRECTION direction, string &reason)
   {
      double ema20[];
      ArraySetAsSeries(ema20, true);
      if(CopyBuffer(m_ema20Handle, 0, 0, 3, ema20) < 3) return false;
      
      // Check EMA slope (must be > 15 degrees equivalent)
      double slope = MathAbs(ema20[0] - ema20[2]) / 2.0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(slope < 0.0001) // Weak momentum
      {
         reason = "EMA slope too weak: " + DoubleToString(slope, 5);
         return false;
      }
      
      // Check alignment
      double currentPrice = iClose(m_symbol, PERIOD_M15, 0);
      if(direction == TRADE_BUY && currentPrice < ema20[0])
      {
         reason = "Price below EMA20 for BUY";
         return false;
      }
      if(direction == TRADE_SELL && currentPrice > ema20[0])
      {
         reason = "Price above EMA20 for SELL";
         return false;
      }
      
      return true;
   }
   
   // Filter 7: Spread Filter
   bool ValidateSpread(string &reason)
   {
      double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double maxSpread = 0.5 * point * 10; // 0.5 pips max
      
      if(spread > maxSpread)
      {
         reason = "Spread too wide: " + DoubleToString(spread / point / 10, 1) + " pips > 0.5";
         return false;
      }
      
      return true;
   }
   
   // Filter 8: Time Filter (relaxed)
   bool ValidateTime(string &reason)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;
      int dayOfWeek = dt.day_of_week;
      
      // Check if TradeLondonNYOverlap is enabled
      if(m_config != NULL && m_config.TradeLondonNYOverlap && !m_config.TradeAllDay)
      {
         // London/NY overlap only (13:00-16:00 GMT)
         if(hour < 13 || hour >= 16)
         {
            reason = "Outside optimal hours: " + IntegerToString(hour) + " (need 13-16 GMT for overlap)";
            return false;
         }
      }
      else if(m_config != NULL && !m_config.TradeAllDay)
      {
         // Allow trading during standard hours (8:00-17:00 GMT)
         if(hour < 8 || hour >= 17)
         {
            reason = "Outside trading hours: " + IntegerToString(hour) + " (need 8-17 GMT)";
            return false;
         }
      }
      
      // Day of week check is optional (not blocking)
      // Tuesday-Thursday preferred but not required
      
      return true;
   }
   
   // Filter 9: News Filter
   bool ValidateNews(string &reason)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // NFP: First Friday of month, 12:30 GMT
      if(dt.day_of_week == 5 && dt.hour == 12 && dt.min >= 25 && dt.min <= 35)
      {
         reason = "NFP news event";
         return false;
      }
      
      // FOMC: Usually 18:00 GMT
      if(dt.hour >= 17 && dt.hour <= 19)
      {
         reason = "FOMC news window";
         return false;
      }
      
      // Check if within 2 hours of major news (simplified)
      // In production, integrate with news API
      
      return true;
   }
   
   // Filter 10: Momentum Filter
   bool ValidateMomentum(TRADE_DIRECTION direction, string &reason)
   {
      // Check RSI
      int rsiHandle = iRSI(m_symbol, PERIOD_M15, 14, PRICE_CLOSE);
      double rsi[];
      ArraySetAsSeries(rsi, true);
      
      if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) >= 3)
      {
         if(direction == TRADE_BUY)
         {
            if(rsi[0] < 50 || rsi[0] > 70)
            {
               reason = "RSI not optimal for BUY: " + DoubleToString(rsi[0], 2);
               IndicatorRelease(rsiHandle);
               return false;
            }
         }
         else
         {
            if(rsi[0] > 50 || rsi[0] < 30)
            {
               reason = "RSI not optimal for SELL: " + DoubleToString(rsi[0], 2);
               IndicatorRelease(rsiHandle);
               return false;
            }
         }
      }
      IndicatorRelease(rsiHandle);
      
      return true;
   }
   
   // Filter 11: Volume Filter
   bool ValidateVolume(string &reason)
   {
      long currentVolume = iTickVolume(m_symbol, PERIOD_M5, 0);
      long avgVolume = 0;
      
      for(int i = 1; i <= 20; i++)
      {
         avgVolume += iTickVolume(m_symbol, PERIOD_M5, i);
      }
      avgVolume /= 20;
      
      if(currentVolume < avgVolume * 2.0)
      {
         reason = "Volume too low: " + IntegerToString(currentVolume) + " < " + IntegerToString((int)(avgVolume * 2.0));
         return false;
      }
      
      return false;
   }
   
   // Filter 12: Structure Filter
   bool ValidateStructure(TRADE_DIRECTION direction, string &reason)
   {
      // Check for recent structure break
      // Simplified - in production, use MarketStructureAnalyzer
      return true;
   }
};

