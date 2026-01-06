//+------------------------------------------------------------------+
//|                                                OrderManager.mqh   |
//|                        Order Management Class                     |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Config/EAConfig.mqh"
#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Base/ILogger.mqh"

//+------------------------------------------------------------------+
//| Order Manager - Single Responsibility: Order Execution           |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   string m_symbol;
   CEAConfig* m_config;
   ILogger* m_logger;
   CTrade m_trade;
   CPositionInfo m_position;
   
   PositionExit m_positionExits[];
   
public:
   COrderManager(string symbol, CEAConfig* config, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_logger = logger;
      
      m_trade.SetExpertMagicNumber(config.MagicNumber);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
      
      ArrayResize(m_positionExits, 0);
   }
   
   bool OpenBuyOrder(double entryPrice, double stopLoss, double takeProfit, double lotSize, string comment)
   {
      if(!m_trade.Buy(lotSize, m_symbol, entryPrice, stopLoss, takeProfit, comment))
      {
         if(m_logger != NULL)
         {
            m_logger.LogError("Failed to open BUY order. Error: " + IntegerToString(GetLastError()));
            m_logger.LogError("Entry: " + DoubleToString(entryPrice, 5) + 
                            " SL: " + DoubleToString(stopLoss, 5) + 
                            " TP: " + DoubleToString(takeProfit, 5) + 
                            " Lots: " + DoubleToString(lotSize, 2));
         }
         return false;
      }
      
      ulong ticket = m_trade.ResultOrder();
      if(m_logger != NULL)
         m_logger.LogTrade("BUY order opened. Ticket: " + IntegerToString(ticket) + 
                          " Entry: " + DoubleToString(entryPrice, 5));
      
      // Setup 3-tier exits if enabled
      if(m_config.Use3TierExits)
      {
         Setup3TierExits(ticket, entryPrice, stopLoss, takeProfit, true);
      }
      
      return true;
   }
   
   bool OpenSellOrder(double entryPrice, double stopLoss, double takeProfit, double lotSize, string comment)
   {
      if(!m_trade.Sell(lotSize, m_symbol, entryPrice, stopLoss, takeProfit, comment))
      {
         if(m_logger != NULL)
         {
            m_logger.LogError("Failed to open SELL order. Error: " + IntegerToString(GetLastError()));
            m_logger.LogError("Entry: " + DoubleToString(entryPrice, 5) + 
                            " SL: " + DoubleToString(stopLoss, 5) + 
                            " TP: " + DoubleToString(takeProfit, 5) + 
                            " Lots: " + DoubleToString(lotSize, 2));
         }
         return false;
      }
      
      ulong ticket = m_trade.ResultOrder();
      if(m_logger != NULL)
         m_logger.LogTrade("SELL order opened. Ticket: " + IntegerToString(ticket) + 
                          " Entry: " + DoubleToString(entryPrice, 5));
      
      // Setup 3-tier exits if enabled
      if(m_config.Use3TierExits)
      {
         Setup3TierExits(ticket, entryPrice, stopLoss, takeProfit, false);
      }
      
      return true;
   }
   
   bool HasOpenPosition()
   {
      return PositionSelect(m_symbol);
   }
   
   bool ClosePosition(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      if(m_trade.PositionClose(ticket))
      {
         if(m_logger != NULL)
            m_logger.LogTrade("Position closed. Ticket: " + IntegerToString(ticket));
         return true;
      }
      return false;
   }
   
   bool ClosePositionPartially(ulong ticket, double volume)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      if(m_trade.PositionClosePartial(ticket, volume))
      {
         if(m_logger != NULL)
            m_logger.LogTrade("Position partially closed. Ticket: " + IntegerToString(ticket) + 
                            " Volume: " + DoubleToString(volume, 2));
         return true;
      }
      return false;
   }
   
   bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      return m_trade.PositionModify(ticket, stopLoss, takeProfit);
   }
   
   void UpdateTrailingStops()
   {
      if(!m_config.UseTrailingStop)
         return;
      
      if(!PositionSelect(m_symbol))
         return;
      
      double positionSL = PositionGetDouble(POSITION_SL);
      double positionTP = PositionGetDouble(POSITION_TP);
      double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      
      double currentPrice = isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double trailingDistance = m_config.TrailingStopPips * point * 10;
      double trailingStep = m_config.TrailingStepPips * point * 10;
      
      double newSL = 0;
      
      if(isBuy)
      {
         newSL = currentPrice - trailingDistance;
         if(newSL > positionSL + trailingStep && newSL > positionPrice)
         {
            m_trade.PositionModify(m_symbol, newSL, positionTP);
         }
      }
      else
      {
         newSL = currentPrice + trailingDistance;
         if((newSL < positionSL - trailingStep || positionSL == 0) && newSL < positionPrice)
         {
            m_trade.PositionModify(m_symbol, newSL, positionTP);
         }
      }
   }
   
   void Check3TierExits()
   {
      if(!m_config.Use3TierExits)
         return;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      for(int i = 0; i < ArraySize(m_positionExits); i++)
      {
         if(!PositionSelectByTicket(m_positionExits[i].ticket))
         {
            // Position closed, remove from array
            RemovePositionExit(i);
            i--;
            continue;
         }
         
         double positionVolume = PositionGetDouble(POSITION_VOLUME);
         double initialVolume = PositionGetDouble(POSITION_VOLUME);
         
         // Check TP1 (1:1 RR)
         if(!m_positionExits[i].tp1Hit && 
            ((m_positionExits[i].isBuy && currentPrice >= m_positionExits[i].tp1) ||
             (!m_positionExits[i].isBuy && currentPrice <= m_positionExits[i].tp1)))
         {
            ClosePartialPosition(m_positionExits[i].ticket, 0.3); // 30%
            m_positionExits[i].tp1Hit = true;
         }
         
         // Check TP2 (2:1 RR)
         if(m_positionExits[i].tp1Hit && !m_positionExits[i].tp2Hit &&
            ((m_positionExits[i].isBuy && currentPrice >= m_positionExits[i].tp2) ||
             (!m_positionExits[i].isBuy && currentPrice <= m_positionExits[i].tp2)))
         {
            ClosePartialPosition(m_positionExits[i].ticket, 0.3); // 30%
            m_positionExits[i].tp2Hit = true;
         }
         
         // Check TP3 (3:1 RR)
         if(m_positionExits[i].tp2Hit && !m_positionExits[i].tp3Hit &&
            ((m_positionExits[i].isBuy && currentPrice >= m_positionExits[i].tp3) ||
             (!m_positionExits[i].isBuy && currentPrice <= m_positionExits[i].tp3)))
         {
            ClosePartialPosition(m_positionExits[i].ticket, 1.0); // Remaining 40%
            m_positionExits[i].tp3Hit = true;
         }
      }
   }
   
private:
   void Setup3TierExits(ulong ticket, double entryPrice, double sl, double tp, bool isBuy)
   {
      double slDistance = MathAbs(entryPrice - sl);
      
      PositionExit pe;
      pe.ticket = ticket;
      pe.entryPrice = entryPrice;
      pe.sl = sl;
      pe.tp1 = isBuy ? entryPrice + slDistance : entryPrice - slDistance; // 1:1
      pe.tp2 = isBuy ? entryPrice + (slDistance * 2) : entryPrice - (slDistance * 2); // 2:1
      pe.tp3 = isBuy ? entryPrice + (slDistance * 3) : entryPrice - (slDistance * 3); // 3:1
      pe.tp1Hit = false;
      pe.tp2Hit = false;
      pe.tp3Hit = false;
      pe.entryTime = TimeCurrent();
      pe.isBuy = isBuy;
      
      int size = ArraySize(m_positionExits);
      ArrayResize(m_positionExits, size + 1);
      m_positionExits[size] = pe;
   }
   
   void ClosePartialPosition(ulong ticket, double percent)
   {
      if(!PositionSelectByTicket(ticket))
         return;
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double closeVolume = volume * percent;
      
      if(closeVolume < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN))
         return;
      
      m_trade.PositionClosePartial(ticket, closeVolume);
   }
   
   void RemovePositionExit(int index)
   {
      for(int i = index; i < ArraySize(m_positionExits) - 1; i++)
      {
         m_positionExits[i] = m_positionExits[i + 1];
      }
      ArrayResize(m_positionExits, ArraySize(m_positionExits) - 1);
   }
};

