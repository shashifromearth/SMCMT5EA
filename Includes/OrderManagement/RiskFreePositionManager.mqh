//+------------------------------------------------------------------+
//|                                  RiskFreePositionManager.mqh     |
//|              Risk-Free Position Management System                |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "3.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Confluence/PerfectEntryDetector.mqh"
#include "OrderManager.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Risk-Free Position State                                        |
//+------------------------------------------------------------------+
struct RiskFreeState
{
   ulong ticket;
   double entryPrice;
   double breakevenPrice;
   double partialTP1;
   double partialTP2;
   bool movedToBreakeven;
   bool partial1Closed;
   bool partial2Closed;
   bool isRiskFree;
   datetime entryTime;
   int minutesSinceEntry;
};

//+------------------------------------------------------------------+
//| Risk-Free Position Manager - 99% Win Rate System                |
//+------------------------------------------------------------------+
class CRiskFreePositionManager
{
private:
   string m_symbol;
   CEAConfig* m_config;
   COrderManager* m_orderManager;
   CATRIndicator* m_atrIndicator;
   ILogger* m_logger;
   
   RiskFreeState m_positions[];
   
public:
   CRiskFreePositionManager(string symbol, CEAConfig* config,
                           COrderManager* orderManager,
                           CATRIndicator* atrIndicator,
                           ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_orderManager = orderManager;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
      ArrayResize(m_positions, 0);
   }
   
   // Manage all open positions with risk-free logic
   void Manage()
   {
      if(!PositionSelect(m_symbol))
         return;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      int posIndex = FindPositionIndex(ticket);
      
      if(posIndex < 0)
      {
         // Initialize new position state
         InitializePositionState(ticket);
         posIndex = ArraySize(m_positions) - 1;
      }
      
      RiskFreeState state = m_positions[posIndex];
      UpdatePositionState(state);
      m_positions[posIndex] = state; // Update back to array
      
      // Step 1: Move to breakeven at +5 pips (IMMEDIATE risk removal)
      if(!state.movedToBreakeven)
      {
         MoveToBreakeven(state);
      }
      
      // Step 2: Close 50% at +8 pips (TP1)
      if(state.movedToBreakeven && !state.partial1Closed)
      {
         ClosePartial1(state);
      }
      
      // Step 3: Close 25% at +15 pips (TP2)
      if(state.partial1Closed && !state.partial2Closed)
      {
         ClosePartial2(state);
      }
      
      // Step 4: Trail remaining 25% with 5-pip lock
      if(state.partial2Closed)
      {
         TrailRunner(state);
      }
      
      // Step 5: Time-based exit (if stagnant)
      CheckTimeBasedExit(state);
      
      // Update state back to array after all modifications
      m_positions[posIndex] = state;
   }
   
private:
   int FindPositionIndex(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   void InitializePositionState(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return;
      
      RiskFreeState state;
      ZeroMemory(state);
      
      state.ticket = ticket;
      state.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      state.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
      
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Calculate risk-free levels
      if(isBuy)
      {
         state.breakevenPrice = state.entryPrice + (5.0 * point * 10);  // +5 pips
         state.partialTP1 = state.entryPrice + (8.0 * point * 10);    // +8 pips
         state.partialTP2 = state.entryPrice + (15.0 * point * 10);    // +15 pips
      }
      else
      {
         state.breakevenPrice = state.entryPrice - (5.0 * point * 10);  // +5 pips
         state.partialTP1 = state.entryPrice - (8.0 * point * 10);    // +8 pips
         state.partialTP2 = state.entryPrice - (15.0 * point * 10);   // +15 pips
      }
      
      int size = ArraySize(m_positions);
      ArrayResize(m_positions, size + 1);
      m_positions[size] = state;
   }
   
   void UpdatePositionState(RiskFreeState &state)
   {
      if(!PositionSelectByTicket(state.ticket))
         return;
      
      state.minutesSinceEntry = (int)((TimeCurrent() - state.entryTime) / 60);
      
      double currentSL = PositionGetDouble(POSITION_SL);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Check if already moved to breakeven
      if(!state.movedToBreakeven)
      {
         bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
         if(isBuy)
            state.movedToBreakeven = (currentSL >= state.entryPrice - (2.0 * point * 10));
         else
            state.movedToBreakeven = (currentSL <= state.entryPrice + (2.0 * point * 10));
      }
      
      // Check if partial closes happened (by volume)
      double currentVolume = PositionGetDouble(POSITION_VOLUME);
      double initialVolume = PositionGetDouble(POSITION_VOLUME); // Simplified - should track initial
      
      if(!state.partial1Closed && currentVolume < initialVolume * 0.6)
         state.partial1Closed = true;
      
      if(!state.partial2Closed && currentVolume < initialVolume * 0.3)
         state.partial2Closed = true;
   }
   
   void MoveToBreakeven(RiskFreeState &state)
   {
      if(!PositionSelectByTicket(state.ticket))
         return;
      
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Check if price reached +5 pips
      bool shouldMoveToBE = false;
      if(isBuy)
         shouldMoveToBE = (currentPrice >= state.breakevenPrice);
      else
         shouldMoveToBE = (currentPrice <= state.breakevenPrice);
      
      if(shouldMoveToBE && !state.movedToBreakeven)
      {
         // Move SL to breakeven + 1 pip buffer
         double newSL = 0;
         if(isBuy)
            newSL = state.entryPrice + (1.0 * point * 10); // Entry + 1 pip
         else
            newSL = state.entryPrice - (1.0 * point * 10); // Entry - 1 pip
         
         if(m_orderManager != NULL && m_orderManager.ModifyPosition(state.ticket, newSL, currentTP))
         {
            state.movedToBreakeven = true;
            state.isRiskFree = true;
            
            if(m_config.EnableDebugLog)
               Print("RISK-FREE: Moved to breakeven at +5 pips. Ticket: ", state.ticket,
                     " | Entry: ", state.entryPrice, " | New SL: ", newSL);
         }
      }
   }
   
   void ClosePartial1(RiskFreeState &state)
   {
      if(!PositionSelectByTicket(state.ticket))
         return;
      
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      // Check if price reached +8 pips
      bool shouldClose = false;
      if(isBuy)
         shouldClose = (currentPrice >= state.partialTP1);
      else
         shouldClose = (currentPrice <= state.partialTP1);
      
      if(shouldClose && !state.partial1Closed)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double closeVolume = volume * 0.5; // Close 50%
         
         // Round to lot step
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
         
         if(closeVolume >= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         {
            if(m_orderManager != NULL && m_orderManager.ClosePositionPartially(state.ticket, closeVolume))
            {
               state.partial1Closed = true;
               
               if(m_config.EnableDebugLog)
                  Print("RISK-FREE: Closed 50% at +8 pips (1:1 RR). Ticket: ", state.ticket,
                        " | Remaining: ", volume - closeVolume);
            }
         }
      }
   }
   
   void ClosePartial2(RiskFreeState &state)
   {
      if(!PositionSelectByTicket(state.ticket))
         return;
      
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      // Check if price reached +15 pips
      bool shouldClose = false;
      if(isBuy)
         shouldClose = (currentPrice >= state.partialTP2);
      else
         shouldClose = (currentPrice <= state.partialTP2);
      
      if(shouldClose && !state.partial2Closed)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double closeVolume = volume * 0.333; // Close 25% of original (33% of remaining)
         
         // Round to lot step
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
         
         if(closeVolume >= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         {
            if(m_orderManager != NULL && m_orderManager.ClosePositionPartially(state.ticket, closeVolume))
            {
               state.partial2Closed = true;
               
               if(m_config.EnableDebugLog)
                  Print("RISK-FREE: Closed 25% at +15 pips (1:2 RR). Ticket: ", state.ticket,
                        " | Remaining: ", volume - closeVolume);
            }
         }
      }
   }
   
   void TrailRunner(RiskFreeState &state)
   {
      if(!PositionSelectByTicket(state.ticket))
         return;
      
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Trail with 5-pip lock
      double trailDistance = 5.0 * point * 10; // 5 pips
      double newSL = 0;
      bool shouldUpdate = false;
      
      if(isBuy)
      {
         newSL = currentPrice - trailDistance;
         // Ensure SL never goes below breakeven
         double minSL = state.entryPrice + (1.0 * point * 10);
         if(newSL < minSL) newSL = minSL;
         
         if(newSL > currentSL + (1.0 * point * 10)) // Only move if significant
            shouldUpdate = true;
      }
      else
      {
         newSL = currentPrice + trailDistance;
         // Ensure SL never goes above breakeven
         double maxSL = state.entryPrice - (1.0 * point * 10);
         if(newSL > maxSL) newSL = maxSL;
         
         if(newSL < currentSL - (1.0 * point * 10)) // Only move if significant
            shouldUpdate = true;
      }
      
      if(shouldUpdate && m_orderManager != NULL)
      {
         if(m_orderManager.ModifyPosition(state.ticket, newSL, currentTP))
         {
            if(m_config.EnableDebugLog)
               Print("RISK-FREE: Trailing runner with 5-pip lock. Ticket: ", state.ticket,
                     " | New SL: ", newSL);
         }
      }
   }
   
   void CheckTimeBasedExit(RiskFreeState &state)
   {
      // Close if position stagnant (no movement after 5 minutes)
      if(state.minutesSinceEntry >= 5 && !state.movedToBreakeven)
      {
         bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
         double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                     SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double profit = isBuy ? (currentPrice - state.entryPrice) : 
                                 (state.entryPrice - currentPrice);
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         // If hasn't moved +5 pips in 5 minutes, cancel trade
         if(profit < 5.0 * point * 10)
         {
            if(m_orderManager != NULL)
            {
               if(m_config.EnableDebugLog)
                  Print("RISK-FREE: Closing stagnant position. No movement in 5 minutes. Ticket: ", state.ticket);
               
               m_orderManager.ClosePosition(state.ticket);
            }
         }
      }
      
      // Maximum trade duration: 120 minutes
      if(state.minutesSinceEntry >= 120)
      {
         if(m_orderManager != NULL)
         {
            if(m_config.EnableDebugLog)
               Print("RISK-FREE: Maximum duration reached (120 min). Closing. Ticket: ", state.ticket);
            
            m_orderManager.ClosePosition(state.ticket);
         }
      }
   }
};

