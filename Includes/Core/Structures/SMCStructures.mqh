//+------------------------------------------------------------------+
//|                                              SMCStructures.mqh   |
//|                        Smart Money Concepts Structures            |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Enums/SMCEnums.mqh"

//+------------------------------------------------------------------+
//| Swing Point Structure                                            |
//+------------------------------------------------------------------+
struct SwingPoint
{
   datetime time;
   double price;
   bool isHigh;
   int barIndex;
};

//+------------------------------------------------------------------+
//| Fair Value Gap Structure                                         |
//+------------------------------------------------------------------+
struct FairValueGap
{
   datetime startTime;
   datetime endTime;
   double topPrice;
   double bottomPrice;
   FVG_TYPE type;
   bool mitigated;
   int startBar;
   int endBar;
};

//+------------------------------------------------------------------+
//| Order Block Structure                                            |
//+------------------------------------------------------------------+
struct OrderBlock
{
   datetime time;
   double high;
   double low;
   bool isBullish;
   bool active;
   int barIndex;
   double volume;              // Volume at OB formation
   bool hasVolumeSpike;        // Volume spike confirmation
   bool hasFVGNearby;          // FVG nearby confirmation
   int qualityScore;           // Quality score (0-10)
};

//+------------------------------------------------------------------+
//| Liquidity Zone Structure                                         |
//+------------------------------------------------------------------+
struct LiquidityZone
{
   double price;
   bool isHigh;
   datetime time;
   int strength;  // Number of touches
   bool broken;
};

//+------------------------------------------------------------------+
//| Market Structure Structure                                       |
//+------------------------------------------------------------------+
struct MarketStructure
{
   bool isUptrend;
   bool isDowntrend;
   double lastHH;  // Higher High
   double lastHL;  // Higher Low
   double lastLH;  // Lower High
   double lastLL;  // Lower Low
   bool hasBOS;
   bool hasCHoCH;
   datetime lastMSS;
};

//+------------------------------------------------------------------+
//| Trade Information Structure                                      |
//+------------------------------------------------------------------+
struct TradeInfo
{
   ulong ticket;
   datetime entryTime;
   double entryPrice;
   double sl;
   double tp;
   double lotSize;
   bool isBuy;
   double riskPercent;
   double riskReward;
   double slDistancePips;
   double tpDistancePips;
   int confluenceScore;
   string entryType;
   string strategy;
   // Market conditions at entry
   bool htfUptrend;
   bool htfDowntrend;
   bool hasBOS;
   bool hasCHoCH;
   string marketRegime;
   double atr;
   double spread;
   string session;
   // Entry quality
   double fvgFillPercent;
   bool inPreferredZone;
   bool hasRejection;
   int obQuality;
   // Additional info
   string comment;
};

//+------------------------------------------------------------------+
//| Position Exit Structure (for 3-tier exits)                      |
//+------------------------------------------------------------------+
struct PositionExit
{
   ulong ticket;
   double entryPrice;
   double sl;
   double tp1;  // 1:1 RR (30%)
   double tp2;  // 2:1 RR (30%)
   double tp3;  // 3:1 RR (40%)
   bool tp1Hit;
   bool tp2Hit;
   bool tp3Hit;
   datetime entryTime;
   bool isBuy;
};

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                    |
//+------------------------------------------------------------------+
struct PerformanceMetrics
{
   double winRate;
   double profitFactor;
   double sharpeRatio;
   double maxDrawdown;
   double recoveryFactor;
   double avgWinLossRatio;
   int totalTrades;
   int winningTrades;
   double totalProfit;
   double totalLoss;
   double currentDrawdown;
   double peakBalance;
};

//+------------------------------------------------------------------+
//| Strategy Adaptation Structure                                    |
//+------------------------------------------------------------------+
struct StrategyAdaptation
{
   double baseRiskPercent;
   int minConfluenceScore;
   bool strategyDecaying;
   datetime lastAdaptation;
};

//+------------------------------------------------------------------+
//| Order Flow Data Structure                                        |
//+------------------------------------------------------------------+
struct OrderFlowData
{
   double bidVolume;
   double askVolume;
   double imbalance;
   ulong timestamp;
   double price;
};

//+------------------------------------------------------------------+
//| Kalman Filter Structure                                          |
//+------------------------------------------------------------------+
struct KalmanFilter
{
   double Q;  // Process variance
   double R;  // Measurement variance
   double P;  // Estimation error
   double K;  // Kalman gain
   double X;  // Estimated value
};

//+------------------------------------------------------------------+
//| GA Individual Structure                                          |
//+------------------------------------------------------------------+
struct GAIndividual
{
   double params[10];  // Parameter values
   double fitness;     // Fitness score
};

//+------------------------------------------------------------------+
//| Quantum Metrics Structure                                        |
//+------------------------------------------------------------------+
struct QuantumMetrics
{
   double calmarRatio;
   double burkeRatio;
   double kappaThree;
   double omegaRatio;
   double painIndex;
   double tailRatio;
   double serenityRatio;
   double speculationQuotient;
};

//+------------------------------------------------------------------+
//| Execution Timing Structure                                       |
//+------------------------------------------------------------------+
struct ExecutionTiming
{
   ulong executionTimes[];
   ulong bestTime;
   int count;
};

//+------------------------------------------------------------------+
//| Trade Signal Structure                                           |
//+------------------------------------------------------------------+
struct TradeSignal
{
   TRADE_DIRECTION direction;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double lotSize;
   int confluenceScore;
   string strategy;
   ENTRY_TYPE entryType;
   string comment;
};

