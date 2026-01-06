//+------------------------------------------------------------------+
//|                                                  SMCEnums.mqh     |
//|                        Smart Money Concepts Enumerations          |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

//+------------------------------------------------------------------+
//| Market Regime Enumeration                                        |
//+------------------------------------------------------------------+
enum MARKET_REGIME
{
   REGIME_RANGING,
   REGIME_TRENDING,
   REGIME_VOLATILE,
   REGIME_LOW_VOLATILITY
};

//+------------------------------------------------------------------+
//| Market State Enumeration                                         |
//+------------------------------------------------------------------+
enum MARKET_STATE
{
   MARKET_STATE_RANGING,
   MARKET_STATE_BULLISH,
   MARKET_STATE_BEARISH,
   MARKET_STATE_TRENDING,
   MARKET_STATE_VOLATILE,
   MARKET_STATE_NEWS_DRIVEN
};

//+------------------------------------------------------------------+
//| Entry Type Enumeration                                           |
//+------------------------------------------------------------------+
enum ENTRY_TYPE
{
   ENTRY_LIQUIDITY_GRAB_REVERSAL,
   ENTRY_BOS_RETEST,
   ENTRY_FVG_FILL_CONTINUATION,
   ENTRY_ORDER_BLOCK_BOUNCE  // OPTIMIZED: Added for OB-only entries
};

//+------------------------------------------------------------------+
//| Fair Value Gap Type Enumeration                                  |
//+------------------------------------------------------------------+
enum FVG_TYPE
{
   FVG_BULLISH,
   FVG_BEARISH,
   FVG_NEUTRAL
};

//+------------------------------------------------------------------+
//| Trade Direction Enumeration                                     |
//+------------------------------------------------------------------+
enum TRADE_DIRECTION
{
   TRADE_BUY,
   TRADE_SELL,
   TRADE_NONE
};

