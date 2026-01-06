//+------------------------------------------------------------------+
//|                                            PositionManager.mqh   |
//|                        Position Management Class                  |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "OrderManager.mqh"

//+------------------------------------------------------------------+
//| Position Manager - Manages open positions                        |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   string m_symbol;
   CEAConfig* m_config;
   COrderManager* m_orderManager;
   CATRIndicator* m_atrIndicator;
   ILogger* m_logger;
   
public:
   CPositionManager(string symbol, CEAConfig* config, COrderManager* orderManager, 
                    CATRIndicator* atrIndicator, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_orderManager = orderManager;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
   }
   
   void Manage()
   {
      if(!PositionSelect(m_symbol))
         return;
      
      if(m_orderManager == NULL || m_config == NULL)
         return;
      
      // Get position information
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                           SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentSL = PositionGetDouble(POSITION_SL);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      
      // CRITICAL: Maximum loss protection - Never allow SL to move beyond 3x original risk
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double originalSLDistance = MathAbs(openPrice - currentTP) / 3.0; // Estimate original SL from TP (assuming 3R)
      double maxLossDistance = originalSLDistance * 3.0; // Maximum 3x original risk
      double maxLossPrice = isBuy ? (openPrice - maxLossDistance) : (openPrice + maxLossDistance);
      
      // Safety check: If current SL is beyond max loss, reset it
      if(isBuy && currentSL < maxLossPrice)
      {
         if(m_config.EnableDebugLog)
            Print("CRITICAL: SL beyond max loss protection! Resetting SL. Current: ", currentSL, " | Max Loss: ", maxLossPrice);
         double safeSL = maxLossPrice + (10.0 * point * 10); // Add 10 pip buffer
         m_orderManager.ModifyPosition(ticket, safeSL, currentTP);
         return; // Don't continue with other management
      }
      else if(!isBuy && currentSL > maxLossPrice)
      {
         if(m_config.EnableDebugLog)
            Print("CRITICAL: SL beyond max loss protection! Resetting SL. Current: ", currentSL, " | Max Loss: ", maxLossPrice);
         double safeSL = maxLossPrice - (10.0 * point * 10); // Subtract 10 pip buffer
         m_orderManager.ModifyPosition(ticket, safeSL, currentTP);
         return; // Don't continue with other management
      }
      
      // Get stop level to prevent "Invalid stops" errors
      int stopLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minStopDistance = stopLevel > 0 ? stopLevel * point : point * 10;
      
      // Check if we're already at breakeven
      bool isAtBreakeven = false;
      if(isBuy)
         isAtBreakeven = (currentSL >= openPrice - (20.0 * point * 10) && currentSL <= openPrice + (10.0 * point * 10));
      else
         isAtBreakeven = (currentSL <= openPrice + (20.0 * point * 10) && currentSL >= openPrice - (10.0 * point * 10));
      
      // Calculate profit and risk
      double slDistance = MathAbs(openPrice - currentSL);
      double riskAmount = slDistance;
      double profit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
      
      // PROFIT OPTIMIZED: Exit 50% at 1:1 RR first
      if(m_config.PartialClose && !IsPartialClosed(ticket))
      {
         double rr = profit / riskAmount;
         if(rr >= 1.0) // At 1:1 RR
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume = volume * 0.5; // Close 50%
            
            if(m_orderManager != NULL && m_orderManager.ClosePositionPartially(ticket, closeVolume))
            {
               if(m_config.EnableDebugLog)
                  Print("PROFIT OPTIMIZED: Closed 50% at 1:1 RR. Ticket: ", ticket, " | Profit: ", profit);
               MarkPartialClosed(ticket);
            }
         }
      }
      
      // Move to breakeven logic
      ManageBreakeven(ticket, openPrice, currentPrice, currentSL, currentTP, isBuy, 
                     riskAmount, profit, minStopDistance, isAtBreakeven);
      
      // Candle-based trailing stop
      ManageCandleTrailing(ticket, openPrice, currentPrice, currentSL, currentTP, isBuy, minStopDistance);
      
      // Traditional trailing stop
      ManageTrailingStop(ticket, openPrice, currentPrice, currentSL, currentTP, isBuy, 
                       riskAmount, minStopDistance);
      
      // PROFIT OPTIMIZED: Time-based exit (2 hours max hold)
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int hoursOpen = (int)((TimeCurrent() - openTime) / 3600);
      if(hoursOpen >= m_config.MaxHoldHours)
      {
         if(m_orderManager != NULL)
         {
            if(m_config.EnableDebugLog)
               Print("PROFIT OPTIMIZED: Time-based exit. Position held for ", hoursOpen, " hours");
            m_orderManager.ClosePosition(ticket);
         }
      }
   }
   
private:
   void ManageBreakeven(ulong ticket, double openPrice, double currentPrice, double currentSL, 
                       double currentTP, bool isBuy, double riskAmount, double profit, 
                       double minStopDistance, bool isAtBreakeven)
   {
      // QUANT ENHANCEMENT: Move to breakeven at 1.5R (150% of risk) - more conservative
      // This ensures we only move to breakeven when trade is clearly profitable
      double breakevenThreshold = riskAmount * 1.5; // Changed from 1.0 to 1.5 for better protection
      datetime positionOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesSinceOpen = (int)((TimeCurrent() - positionOpenTime) / 60);
      bool hasBeenOpenLongEnough = (minutesSinceOpen >= 15); // Increased to 15 minutes for stability
      
      bool alreadyMovedToBreakeven = false;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(isBuy)
         alreadyMovedToBreakeven = (currentSL >= openPrice - (30.0 * point * 10) && currentSL <= openPrice + (10.0 * point * 10));
      else
         alreadyMovedToBreakeven = (currentSL <= openPrice + (30.0 * point * 10) && currentSL >= openPrice - (10.0 * point * 10));
      
      bool shouldMoveToBreakeven = false;
      if(isBuy)
         shouldMoveToBreakeven = (profit >= breakevenThreshold && !isAtBreakeven && currentSL < openPrice && hasBeenOpenLongEnough && !alreadyMovedToBreakeven);
      else
         shouldMoveToBreakeven = (profit >= breakevenThreshold && !isAtBreakeven && currentSL > openPrice && hasBeenOpenLongEnough && !alreadyMovedToBreakeven);
      
      if(shouldMoveToBreakeven)
      {
         int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         double breakevenSL = 0;
         
         double atrBuffer = 0;
         if(m_atrIndicator != NULL)
         {
            double atrValue = m_atrIndicator.GetValue(0);
            if(atrValue > 0)
               atrBuffer = atrValue * 0.5;
         }
         
         if(isBuy)
         {
            double bufferPips = (atrBuffer > 0) ? (atrBuffer / point / 10) : 10.0;
            breakevenSL = NormalizeDouble(openPrice - (bufferPips * point * 10), digits);
            double minBreakeven = openPrice - (20.0 * point * 10);
            double maxBreakeven = openPrice - (5.0 * point * 10);
            if(breakevenSL < minBreakeven) breakevenSL = minBreakeven;
            if(breakevenSL > maxBreakeven) breakevenSL = maxBreakeven;
         }
         else
         {
            double bufferPips = (atrBuffer > 0) ? (atrBuffer / point / 10) : 10.0;
            breakevenSL = NormalizeDouble(openPrice + (bufferPips * point * 10), digits);
            double minBreakeven = openPrice + (5.0 * point * 10);
            double maxBreakeven = openPrice + (20.0 * point * 10);
            if(breakevenSL < minBreakeven) breakevenSL = minBreakeven;
            if(breakevenSL > maxBreakeven) breakevenSL = maxBreakeven;
         }
         
         bool isValidBreakeven = false;
         if(isBuy)
            isValidBreakeven = (breakevenSL < currentPrice - minStopDistance && breakevenSL > currentSL);
         else
            isValidBreakeven = (breakevenSL > currentPrice + minStopDistance && breakevenSL < currentSL);
         
         if(isValidBreakeven)
         {
            if(m_orderManager.ModifyPosition(ticket, breakevenSL, currentTP))
            {
               if(m_config.EnableDebugLog)
               {
                  double bufferUsed = MathAbs(breakevenSL - openPrice) / point / 10;
                  Print("Stop moved to breakeven: Ticket ", ticket, " | SL: ", breakevenSL, 
                       " | Entry: ", openPrice, " | Buffer: ", DoubleToString(bufferUsed, 1), " pips");
               }
            }
         }
      }
   }
   
   void ManageCandleTrailing(ulong ticket, double openPrice, double currentPrice, 
                             double currentSL, double currentTP, bool isBuy, double minStopDistance)
   {
      if(m_config == NULL || m_config.LowerTF == PERIOD_CURRENT)
         return;
      
      datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
      int entryBarIndex = -1;
      
      for(int i = 0; i < 100; i++)
      {
         datetime barTime = iTime(m_symbol, m_config.LowerTF, i);
         if(barTime <= entryTime)
         {
            entryBarIndex = i;
            break;
         }
      }
      
      if(entryBarIndex >= 0)
      {
         int profitableCandles = 0;
         double extremePrice = isBuy ? DBL_MAX : 0;
         bool foundProfitableCandle = false;
         
         for(int i = entryBarIndex - 1; i >= 0; i--)
         {
            double candleHigh = iHigh(m_symbol, m_config.LowerTF, i);
            double candleLow = iLow(m_symbol, m_config.LowerTF, i);
            
            if(isBuy)
            {
               if(candleHigh > openPrice)
               {
                  profitableCandles++;
                  if(candleLow < extremePrice)
                     extremePrice = candleLow;
                  foundProfitableCandle = true;
               }
            }
            else
            {
               if(candleLow < openPrice)
               {
                  profitableCandles++;
                  if(candleHigh > extremePrice)
                     extremePrice = candleHigh;
                  foundProfitableCandle = true;
               }
            }
            
            if(foundProfitableCandle && profitableCandles >= 1)
            {
               double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double newSL = 0;
               bool shouldUpdateSL = false;
               
               if(isBuy)
               {
                  // QUANT ENHANCEMENT: Candle-based trailing with ATR buffer
                  double atr = m_atrIndicator != NULL ? m_atrIndicator.GetValue(0) : 0;
                  double buffer = (atr > 0) ? (atr * 0.2) : (5.0 * point * 10); // 0.2x ATR or 5 pips
                  
                  newSL = extremePrice - buffer;
                  if(newSL > currentSL && newSL < currentPrice - minStopDistance && newSL > openPrice)
                  {
                     // Ensure SL never goes below entry (safety)
                     if(newSL < openPrice)
                        newSL = openPrice + (5.0 * point * 10);
                     shouldUpdateSL = true;
                  }
               }
               else
               {
                  // QUANT ENHANCEMENT: Candle-based trailing with ATR buffer
                  double atr = m_atrIndicator != NULL ? m_atrIndicator.GetValue(0) : 0;
                  double buffer = (atr > 0) ? (atr * 0.2) : (5.0 * point * 10); // 0.2x ATR or 5 pips
                  
                  newSL = extremePrice + buffer;
                  if(newSL < currentSL && newSL > currentPrice + minStopDistance && newSL < openPrice)
                  {
                     // Ensure SL never goes above entry (safety)
                     if(newSL > openPrice)
                        newSL = openPrice - (5.0 * point * 10);
                     shouldUpdateSL = true;
                  }
               }
               
               if(shouldUpdateSL && newSL > 0)
               {
                  int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
                  newSL = NormalizeDouble(newSL, digits);
                  
                  if(MathAbs(newSL - currentSL) > (point * 2))
                  {
                     if(m_orderManager.ModifyPosition(ticket, newSL, currentTP))
                     {
                        if(m_config.EnableDebugLog)
                           Print("Candle-Based Trailing: Ticket ", ticket, 
                                 " | Profitable Candles: ", profitableCandles,
                                 " | New SL: ", newSL, " | Entry: ", openPrice,
                                 " | Extreme Price: ", extremePrice);
                        return;
                     }
                  }
               }
               
               if(profitableCandles >= 10)
                  break;
            }
         }
      }
   }
   
   void ManageTrailingStop(ulong ticket, double openPrice, double currentPrice, 
                          double currentSL, double currentTP, bool isBuy, 
                          double riskAmount, double minStopDistance)
   {
      if(!m_config.UseTrailingStop || m_config.TrailingStopPips <= 0 || m_atrIndicator == NULL)
         return;
      
      double trailingActivationThreshold = riskAmount * 3.0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double trailingStep = 20.0 * point * 10;
      
      double atrValue = m_atrIndicator.GetValue(0);
      double trailingStopDistance = 0;
      if(atrValue > 0)
         trailingStopDistance = atrValue * 5.0;
      else
         trailingStopDistance = m_config.TrailingStopPips * point * 10 * 2.5;
      
      double newSL = 0;
      bool modifySL = false;
      
      if(isBuy)
      {
         double currentProfit = currentPrice - openPrice;
         bool slIsWellAboveEntry = (currentSL >= openPrice + (50.0 * point * 10));
         
         if(currentProfit > trailingActivationThreshold && slIsWellAboveEntry)
         {
            newSL = currentPrice - trailingStopDistance;
            double minimumSL = openPrice + (50.0 * point * 10);
            if(newSL < minimumSL)
               newSL = minimumSL;
            
            if(newSL > currentSL + trailingStep)
            {
               if(newSL < currentPrice - minStopDistance)
                  modifySL = true;
            }
         }
      }
      else
      {
         double currentProfit = openPrice - currentPrice;
         bool slIsWellBelowEntry = (currentSL <= openPrice - (50.0 * point * 10));
         
         if(currentProfit > trailingActivationThreshold && slIsWellBelowEntry)
         {
            newSL = currentPrice + trailingStopDistance;
            double minimumSL = openPrice - (50.0 * point * 10);
            if(newSL > minimumSL)
               newSL = minimumSL;
            
            if(newSL < currentSL - trailingStep)
            {
               if(newSL > currentPrice + minStopDistance)
                  modifySL = true;
            }
         }
      }
      
      if(modifySL && newSL > 0)
      {
         int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         newSL = NormalizeDouble(newSL, digits);
         
         if(MathAbs(newSL - currentSL) > (point * 2))
         {
            if(m_orderManager.ModifyPosition(ticket, newSL, currentTP))
            {
               if(m_config.EnableDebugLog)
                  Print("Trailing Stop Updated: Ticket ", ticket, " | New SL: ", newSL);
            }
         }
      }
   }
   
private:
   // PROFIT OPTIMIZED: Track partial closes
   ulong m_partialClosedTickets[];
   
   bool IsPartialClosed(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_partialClosedTickets); i++)
      {
         if(m_partialClosedTickets[i] == ticket)
            return true;
      }
      return false;
   }
   
   void MarkPartialClosed(ulong ticket)
   {
      int size = ArraySize(m_partialClosedTickets);
      ArrayResize(m_partialClosedTickets, size + 1);
      m_partialClosedTickets[size] = ticket;
   }
};

