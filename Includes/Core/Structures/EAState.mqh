//+------------------------------------------------------------------+
//|                                                  EAState.mqh     |
//|                        EA State Structure                        |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

//+------------------------------------------------------------------+
//| EA State - Holds global state variables                         |
//+------------------------------------------------------------------+
struct SEAState
{
   int dailyTrades;
   int consecutiveLosses;
   int consecutiveWins;
   datetime lastTradeTime;
   double dailyProfit;
   double weeklyProfit;
   double monthlyProfit;
   datetime weekStartTime;
   datetime monthStartTime;
   ulong performanceCounter;
};

