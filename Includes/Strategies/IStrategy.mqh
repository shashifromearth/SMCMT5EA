//+------------------------------------------------------------------+
//|                                                    IStrategy.mqh   |
//|                        Strategy Interface (Strategy Pattern)      |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Core/Structures/SMCStructures.mqh"
#include "../Core/Enums/SMCEnums.mqh"

//+------------------------------------------------------------------+
//| Strategy Interface - Strategy Pattern                            |
//+------------------------------------------------------------------+
interface IStrategy
{
   bool CheckBuySignal(TradeSignal &signal);
   bool CheckSellSignal(TradeSignal &signal);
   string GetStrategyName();
   bool IsEnabled();
};

