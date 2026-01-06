//+------------------------------------------------------------------+
//|                                        EnhancedExitManager.mqh   |
//|              Advanced Exit Management System                      |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "OrderManager.mqh"

//+------------------------------------------------------------------+
//| Enhanced Exit Manager - Multi-tier exit strategy                |
//+------------------------------------------------------------------+
class CEnhancedExitManager
{
private:
   string m_symbol;
   CEAConfig* m_config;
   COrderManager* m_orderManager;
   CATRIndicator* m_atrIndicator;
   ILogger* m_logger;
   
   // Exit tracking
   struct ExitState
   {
      bool partialClosed;
      bool movedToBreakeven;
      bool trailingActive;
      double highestProfit;
      datetime lastUpdateTime;
   };
   
   ExitState m_exitStates[];
   
public:
   CEnhancedExitManager(string symbol, CEAConfig* config, COrderManager* orderManager,
                       CATRIndicator* atrIndicator, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_orderManager = orderManager;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
      ArrayResize(m_exitStates, 0);
   }
   
   void ManageExits()
   {
      if(!PositionSelect(m_symbol))
         return;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      int positionIndex = FindExitStateIndex(ticket);
      
      if(positionIndex < 0)
      {
         // Initialize new exit state
         ExitState newState;
         ZeroMemory(newState);
         newState.highestProfit = 0;
         newState.lastUpdateTime = TimeCurrent();
         int size = ArraySize(m_exitStates);
         ArrayResize(m_exitStates, size + 1);
         m_exitStates[size] = newState;
         positionIndex = size;
      }
      
      ExitState &state = m_exitStates[positionIndex];
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double profit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double slDistance = MathAbs(openPrice - currentSL);
      double riskAmount = slDistance;
      
      // Update highest profit
      if(profit > state.highestProfit)
         state.highestProfit = profit;
      
      // Tier 1: Partial profit taking at 1.5R (if enabled)
      if(m_config.PartialClose && !state.partialClosed && profit >= riskAmount * 1.5)
      {
         ExecutePartialClose(ticket, isBuy, state);
      }
      
      // Tier 2: Move to breakeven at 1.5R (safer than 1.0R)
      if(!state.movedToBreakeven && profit >= riskAmount * 1.5)
      {
         MoveToBreakeven(ticket, openPrice, currentPrice, currentSL, currentTP, isBuy, state);
      }
      
      // Tier 3: Dynamic trailing stop (activates at 2.0R)
      if(profit >= riskAmount * 2.0)
      {
         ManageDynamicTrailing(ticket, openPrice, currentPrice, currentSL, currentTP, isBuy, state, riskAmount);
      }
      
      // Tier 4: Time-based exit (if position held too long)
      CheckTimeBasedExit(ticket, isBuy, state);
   }
   
private:
   int FindExitStateIndex(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_exitStates); i++)
      {
         // Use ticket as identifier (simplified - in production use proper tracking)
         if(m_exitStates[i].lastUpdateTime > 0) // Active state
            return i;
      }
      return -1;
   }
   
   void ExecutePartialClose(ulong ticket, bool isBuy, ExitState &state)
   {
      double volume = PositionGetDouble(POSITION_VOLUME);
      double closeVolume = volume * (m_config.PartialClosePercent / 100.0);
      
      if(closeVolume < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         return;
      
      // Round to lot step
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
      
      if(m_orderManager != NULL)
      {
         double closePrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                     SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         if(m_orderManager.ClosePositionPartially(ticket, closeVolume))
         {
            state.partialClosed = true;
            if(m_config.EnableDebugLog)
               Print("Partial close executed: ", closeVolume, " lots at ", closePrice);
         }
      }
   }
   
   void MoveToBreakeven(ulong ticket, double openPrice, double currentPrice, 
                       double currentSL, double currentTP, bool isBuy, ExitState &state)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double atr = m_atrIndicator != NULL ? m_atrIndicator.GetValue(0) : 0;
      double buffer = (atr > 0) ? (atr * 0.3) : (10.0 * point * 10); // 0.3x ATR or 10 pips
      
      double breakevenSL = 0;
      if(isBuy)
         breakevenSL = openPrice + buffer; // Slightly above entry
      else
         breakevenSL = openPrice - buffer; // Slightly below entry
      
      // Ensure SL is better than current
      if((isBuy && breakevenSL > currentSL) || (!isBuy && breakevenSL < currentSL))
      {
         if(m_orderManager != NULL && m_orderManager.ModifyPosition(ticket, breakevenSL, currentTP))
         {
            state.movedToBreakeven = true;
            if(m_config.EnableDebugLog)
               Print("Moved to breakeven: SL = ", breakevenSL, " | Entry = ", openPrice);
         }
      }
   }
   
   void ManageDynamicTrailing(ulong ticket, double openPrice, double currentPrice,
                             double currentSL, double currentTP, bool isBuy, 
                             ExitState &state, double riskAmount)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double atr = m_atrIndicator != NULL ? m_atrIndicator.GetValue(0) : 0;
      
      // Dynamic trailing distance based on profit
      double profit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double profitMultiplier = profit / riskAmount; // How many R in profit
      
      // Trailing distance: 0.5x ATR at 2R, 1.0x ATR at 3R, 1.5x ATR at 4R+
      double trailingDistance = 0;
      if(profitMultiplier >= 4.0)
         trailingDistance = atr * 1.5;
      else if(profitMultiplier >= 3.0)
         trailingDistance = atr * 1.0;
      else
         trailingDistance = atr * 0.5;
      
      // Minimum trailing distance
      double minTrailing = 15.0 * point * 10; // 15 pips minimum
      if(trailingDistance < minTrailing)
         trailingDistance = minTrailing;
      
      double newSL = 0;
      bool shouldUpdate = false;
      
      if(isBuy)
      {
         newSL = currentPrice - trailingDistance;
         // Ensure new SL is above breakeven and better than current
         double minSL = openPrice + (5.0 * point * 10);
         if(newSL < minSL) newSL = minSL;
         
         if(newSL > currentSL + (5.0 * point * 10)) // Only move if significant improvement
            shouldUpdate = true;
      }
      else
      {
         newSL = currentPrice + trailingDistance;
         // Ensure new SL is below breakeven and better than current
         double maxSL = openPrice - (5.0 * point * 10);
         if(newSL > maxSL) newSL = maxSL;
         
         if(newSL < currentSL - (5.0 * point * 10)) // Only move if significant improvement
            shouldUpdate = true;
      }
      
      if(shouldUpdate && m_orderManager != NULL)
      {
         if(m_orderManager.ModifyPosition(ticket, newSL, currentTP))
         {
            state.trailingActive = true;
            if(m_config.EnableDebugLog)
               Print("Dynamic trailing stop: New SL = ", newSL, " | Profit = ", profitMultiplier, "R");
         }
      }
   }
   
   void CheckTimeBasedExit(ulong ticket, bool isBuy, ExitState &state)
   {
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int hoursOpen = (int)((TimeCurrent() - openTime) / 3600);
      
      if(hoursOpen >= m_config.MaxHoldHours)
      {
         // Close position if held too long
         if(m_orderManager != NULL)
         {
            double closePrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                        SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            
            if(m_config.EnableDebugLog)
               Print("Time-based exit: Position held for ", hoursOpen, " hours");
            
            m_orderManager.ClosePosition(ticket);
         }
      }
   }
};

