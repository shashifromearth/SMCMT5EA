//+------------------------------------------------------------------+
//|                                              SignalManager.mqh   |
//|                        Signal Management Class                    |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Structures/EAState.mqh"
#include "../Strategies/IStrategy.mqh"
#include "../RiskManagement/RiskManager.mqh"
#include "../OrderManagement/OrderManager.mqh"

//+------------------------------------------------------------------+
//| Signal Manager - Handles entry signal checking and validation   |
//+------------------------------------------------------------------+
class CSignalManager
{
private:
   CEAConfig* m_config;
   IStrategy* m_strategies[];
   CRiskManager* m_riskManager;
   COrderManager* m_orderManager;
   ILogger* m_logger;
   string m_symbol;
   
public:
   CSignalManager(CEAConfig* config, IStrategy* &strategies[], CRiskManager* riskManager,
                  COrderManager* orderManager, string symbol, ILogger* logger = NULL)
   {
      m_config = config;
      ArrayCopy(m_strategies, strategies);
      m_riskManager = riskManager;
      m_orderManager = orderManager;
      m_symbol = symbol;
      m_logger = logger;
   }
   
   void CheckForEntrySignals(SEAState& state)
   {
      if(m_config == NULL)
         return;
      
      TradeSignal signal;
      ZeroMemory(signal);
      
      if(m_config.EnableDetailedLogging)
         Print("=== CHECKING FOR ENTRY SIGNALS ===");
      
      for(int i = 0; i < ArraySize(m_strategies); i++)
      {
         if(m_strategies[i] == NULL)
         {
            if(m_config.EnableDetailedLogging)
               Print("Strategy ", i, " is NULL");
            continue;
         }
         
         if(!m_strategies[i].IsEnabled())
         {
            if(m_config.EnableDetailedLogging)
               Print("Strategy ", i, " (", m_strategies[i].GetStrategyName(), ") is disabled");
            continue;
         }
         
         if(m_config.EnableDetailedLogging)
            Print("Checking strategy: ", m_strategies[i].GetStrategyName());
         
         // Check buy signal
         ZeroMemory(signal);
         if(m_strategies[i].CheckBuySignal(signal))
         {
            if(m_config.EnableDetailedLogging)
               Print("BUY signal found from ", m_strategies[i].GetStrategyName(), 
                     " | Entry: ", DoubleToString(signal.entryPrice, 5),
                     " | SL: ", DoubleToString(signal.stopLoss, 5),
                     " | TP: ", DoubleToString(signal.takeProfit, 5),
                     " | Confluence: ", signal.confluenceScore);
            
            if(ValidateSignal(signal))
            {
               if(m_config.EnableDetailedLogging)
                  Print("Signal validated, executing trade...");
               ExecuteTrade(signal, state);
               return;
            }
            else if(m_config.EnableDetailedLogging)
            {
               Print("Signal validation FAILED - Confluence: ", signal.confluenceScore, 
                     " (min required: ", m_config.MinConfluenceScore, ")");
            }
         }
         
         // Check sell signal
         ZeroMemory(signal);
         if(m_strategies[i].CheckSellSignal(signal))
         {
            if(m_config.EnableDetailedLogging)
               Print("SELL signal found from ", m_strategies[i].GetStrategyName(),
                     " | Entry: ", DoubleToString(signal.entryPrice, 5),
                     " | SL: ", DoubleToString(signal.stopLoss, 5),
                     " | TP: ", DoubleToString(signal.takeProfit, 5),
                     " | Confluence: ", signal.confluenceScore);
            
            if(ValidateSignal(signal))
            {
               if(m_config.EnableDetailedLogging)
                  Print("Signal validated, executing trade...");
               ExecuteTrade(signal, state);
               return;
            }
            else if(m_config.EnableDetailedLogging)
            {
               Print("Signal validation FAILED - Confluence: ", signal.confluenceScore, 
                     " (min required: ", m_config.MinConfluenceScore, ")");
            }
         }
      }
      
      if(m_config.EnableDetailedLogging)
         Print("No entry signals found from any strategy");
   }
   
   bool ValidateSignal(TradeSignal &signal)
   {
      if(m_config == NULL)
         return false;
      
      if(signal.confluenceScore < m_config.MinConfluenceScore)
      {
         if(m_config.EnableDetailedLogging)
            Print("Signal validation failed: Confluence score ", signal.confluenceScore, 
                  " < minimum required ", m_config.MinConfluenceScore);
         return false;
      }
      
      if(signal.entryPrice <= 0)
      {
         if(m_config.EnableDetailedLogging)
            Print("Signal validation failed: Invalid entry price ", signal.entryPrice);
         return false;
      }
      
      return true;
   }
   
   void ExecuteTrade(TradeSignal &signal, SEAState& state)
   {
      if(m_riskManager == NULL || m_orderManager == NULL || m_config == NULL)
         return;
      
      double entryPrice = signal.entryPrice;
      double stopLoss = signal.stopLoss;
      double takeProfit = signal.takeProfit;
      
      // Calculate lot size
      double riskPercent = m_riskManager.CalculateRiskPercent(signal.confluenceScore);
      double lotSize = m_riskManager.CalculateLotSize(entryPrice, stopLoss, riskPercent);
      
      if(lotSize <= 0)
      {
         if(m_config.EnableDebugLog)
            Print("Invalid lot size calculated: ", lotSize);
         return;
      }
      
      // Final margin safety check
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double marginRequired = 0.0;
      ENUM_ORDER_TYPE orderType = (signal.direction == TRADE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      if(!OrderCalcMargin(orderType, m_symbol, lotSize, entryPrice, marginRequired))
      {
         if(m_config.EnableDebugLog)
            Print("Failed to calculate margin. Error: ", GetLastError());
         return;
      }
      
      if(marginRequired > freeMargin && freeMargin > 0)
      {
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         
         double low = minLot;
         double high = lotSize;
         double maxLotByMargin = 0.0;
         
         while(high - low >= lotStep)
         {
            double testLot = MathFloor(((low + high) / 2.0) / lotStep) * lotStep;
            if(testLot < minLot) testLot = minLot;
            if(testLot > maxLot) testLot = maxLot;
            
            double testMargin = 0.0;
            if(!OrderCalcMargin(orderType, m_symbol, testLot, entryPrice, testMargin))
               break;
            
            if(testMargin <= freeMargin)
            {
               maxLotByMargin = testLot;
               low = testLot + lotStep;
            }
            else
            {
               high = testLot - lotStep;
            }
         }
         
         if(maxLotByMargin < minLot)
         {
            if(m_config.EnableDebugLog)
               Print("Insufficient margin. Required: ", marginRequired, 
                     " | Available: ", freeMargin);
            return;
         }
         
         lotSize = maxLotByMargin;
         
         if(m_config.EnableDebugLog)
            Print("Lot size reduced due to margin: ", lotSize, 
                  " (original: ", (riskPercent / 100.0) * AccountInfoDouble(ACCOUNT_BALANCE), ")");
      }
      
      // Final lot size normalization
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      if(lotSize < minLot) lotSize = minLot;
      if(lotSize > maxLot) lotSize = maxLot;
      
      // Execute trade
      bool success = false;
      if(signal.direction == TRADE_BUY)
         success = m_orderManager.OpenBuyOrder(entryPrice, stopLoss, takeProfit, lotSize, signal.comment);
      else
         success = m_orderManager.OpenSellOrder(entryPrice, stopLoss, takeProfit, lotSize, signal.comment);
      
      if(success)
      {
         state.dailyTrades++;
         state.lastTradeTime = TimeCurrent();
         
         if(m_config.EnableDebugLog)
            Print("Trade executed: ", EnumToString(signal.direction), 
                  " | Entry: ", entryPrice, " | SL: ", stopLoss, 
                  " | TP: ", takeProfit, " | Lots: ", lotSize);
      }
      else
      {
         if(m_config.EnableDebugLog)
            Print("Failed to execute trade. Error: ", GetLastError());
      }
   }
};

