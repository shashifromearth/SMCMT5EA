//+------------------------------------------------------------------+
//|                                          SMCALGO_Refactored.mq5  |
//|                        Smart Money Concepts Scalping EA          |
//|                    Refactored Modular Architecture                |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property link      ""
#property version   "2.0"

// Include all necessary headers
#include "Includes/Core/Enums/SMCEnums.mqh"
#include "Includes/Core/Structures/SMCStructures.mqh"
#include "Includes/Core/Base/ILogger.mqh"
#include "Includes/Core/Base/Logger.mqh"
#include "Includes/Config/EAConfig.mqh"
#include "Includes/Indicators/IndicatorWrapper.mqh"
#include "Includes/MarketStructure/MarketStructureAnalyzer.mqh"
#include "Includes/MarketStructure/FVGDetector.mqh"
#include "Includes/MarketStructure/OrderBlockDetector.mqh"
#include "Includes/Strategies/IStrategy.mqh"
#include "Includes/Strategies/BaseStrategy.mqh"
#include "Includes/Strategies/OB_FVG_ComboStrategy.mqh"
#include "Includes/RiskManagement/RiskManager.mqh"
#include "Includes/OrderManagement/OrderManager.mqh"
#include "Includes/Filters/SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Input Parameters (same as original for compatibility)            |
//+------------------------------------------------------------------+
//--- Risk Management
input group "=== RISK MANAGEMENT ==="
input double BaseRiskPerTrade = 0.5;
input double MaxRiskPerTrade = 1.5;
input bool UseConfluenceBasedRisk = true;
input double HighConfidenceMultiplier = 2.0;
input double MediumConfidenceMultiplier = 1.5;
input double MaxDailyLoss = 2.0;
input double MaxWeeklyLoss = 5.0;
input double MaxMonthlyLoss = 10.0;
input int MaxTradesPerDay = 10;
input int MaxConsecutiveLosses = 2;
input bool UseAdaptiveRiskScaling = true;
input int WinningStreakThreshold = 3;
input double WinningStreakMultiplier = 1.3;
input bool UseAISL = true;
input bool PartialClose = true;
input double RiskReward = 2.5;
input double PartialClosePercent = 50.0;
input bool UseTrailingStop = true;
input double TrailingStopPips = 20.0;
input double TrailingStepPips = 5.0;
input bool CompoundProfits = false;
input double CompoundMultiplier = 1.2;
input bool Use3TierExits = true;
input bool UseVolatilityAdjustment = true;
input double VolatilityScaleDown = 0.5;
input double VolatilityScaleUp = 1.5;
input int MaxHoldHours = 4;

//--- Timeframe Settings
input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES StructureTF = PERIOD_H4;
input ENUM_TIMEFRAMES HigherTF = PERIOD_H1;
input ENUM_TIMEFRAMES MediumTF = PERIOD_M15;
input ENUM_TIMEFRAMES LowerTF = PERIOD_M5;
input bool UseEMATrendFilter = true;
input ENUM_TIMEFRAMES EMATrendTF = PERIOD_H4;

//--- Trading Sessions
input group "=== SESSION FILTERS ==="
input bool TradeLondonOpen = true;
input bool TradeNYOpen = true;
input bool TradeAsianSession = false;
input bool TradeAllDay = false;
input bool AvoidNews = true;
input int NewsMinutesBefore = 30;
input int NewsMinutesAfter = 30;

//--- Market Structure Parameters
input group "=== MARKET STRUCTURE ==="
input int SwingValidationBars = 3;
input double MSSThreshold = 0.0001;
input bool RequireBOS = true;
input bool RequireCHoCH = true;

//--- Liquidity Zone Parameters
input group "=== LIQUIDITY ZONES ==="
input int EqualHighLowLookback = 100;
input double EqualHighLowTolerance = 0.0002;
input int FVGLookback = 30;
input double FVGMinSize = 0.0002;
input bool TrackFVGMitigation = true;

//--- Order Block Parameters
input group "=== ORDER BLOCKS ==="
input int OrderBlockLookback = 75;
input bool RequireOBConfluence = true;
input int OBTimeFilter = 48;
input bool RequireVolumeConfirmation = true;
input double VolumeSpikeMultiplier = 1.5;
input bool RequireFVGNearOB = true;

//--- Entry Conditions
input group "=== ENTRY CONDITIONS ==="
input int MinConfluenceScore = 1; // RELAXED: Lowered from 6 to 1 for more trades
input bool RequireLiquidityZone = false;
input bool RequireOrderBlock = true;
input bool RequireFVG = true;
input bool RequireBOSConfirmation = false;
input bool RequireLiquiditySweep = false;
input bool RequireHTFBias = false;
input bool RequireM1MSS = false;
input bool AvoidRangingMarkets = false;
input double MinTrendStrength = 0.0001;
input bool UseMomentumConfirmation = true;
input bool UseTickDivergence = true;
input double MinMomentumStrength = 0.5;

//--- SMC Bot Strategy Selection
input group "=== SMC BOT STRATEGIES ==="
input bool UseOB_FVG_Combo = true;
input double OB_FVG_MinFVG_Pips = 3.0;
input int OB_FVG_OBLookback = 30;
input double OB_FVG_RetracementMin = 0.40;
input double OB_FVG_RetracementMax = 0.80;
input int OB_FVG_QualityMin = 10; // RELAXED: Lowered from 25 to 10 for more trades

//--- Advanced Settings
input group "=== ADVANCED SETTINGS ==="
input bool EnableMarketRegime = true;
input double ATRMultiplier = 1.75;
input bool UseSessionBasedATR = true;
input double LondonATRMultiplier = 2.0;
input double NYATRMultiplier = 1.8;
input double OverlapATRMultiplier = 2.2;
input double AsianATRMultiplier = 1.2;
input int MagicNumber = 123456;
input string TradeComment = "SMC Pro";
input bool EnableAlerts = true;
input bool EnableDrawings = true;
input bool EnableDebugLog = true;
input bool EnableDetailedLogging = true;
input bool UseCustomRSI = true;
input int RSIPeriod = 14;
input bool UseVolumeProfile = true;
input bool OptimizeBarProcessing = true;
input bool UseDynamicRisk = true;
input bool UseKellyCriterion = false;
input double KellyFraction = 0.25;
input bool UseADXFilter = false;
input double MinADX = 15.0;
input double MaxADXForRanging = 15.0;
input int ADXPeriod = 14;
input bool TrackPerformanceMetrics = true;
input bool EnableStrategyAdaptation = true;
input int AdaptationPeriod = 30;
input double DecayThreshold = 0.7;
input bool UseCorrelationFilter = false;
input double MaxCorrelationRisk = 2.0;
input bool UseOrderFlowAnalysis = true;
input bool UseKalmanFilter = true;
input bool UseEVTRisk = false;
input bool UseFractalRisk = true;
input bool DetectSpoofing = true;
input bool UseDarkPoolDetection = false;
input bool UseLiveGA = false;
input bool UseQuantumMetrics = true;
input bool UseMillisecondTiming = true;
input int OrderFlowLookback = 100;
input double KalmanQ = 0.0001;
input double KalmanR = 0.001;

//+------------------------------------------------------------------+
//| Global Objects - Dependency Injection                           |
//+------------------------------------------------------------------+
CEAConfig* g_config = NULL;
CLogger* g_logger = NULL;
CSessionFilter* g_sessionFilter = NULL;
CRiskManager* g_riskManager = NULL;
COrderManager* g_orderManager = NULL;

// Market Structure Analysis
CMarketStructureAnalyzer* g_msAnalyzer = NULL;
CFVGDetector* g_fvgDetector = NULL;
COrderBlockDetector* g_obDetector = NULL;

// Indicators
CATRIndicator* g_atrLowerTF = NULL;

// Strategies
IStrategy* g_strategies[];

// State
datetime g_lastBarTime = 0;

// Global state variables (for compatibility with original functions)
int g_dailyTrades = 0;
double g_dailyProfit = 0.0;
double g_weeklyProfit = 0.0;
double g_monthlyProfit = 0.0;
datetime g_lastTradeTime = 0;
datetime g_weekStartTime = 0;
datetime g_monthStartTime = 0;
int g_consecutiveLosses = 0;
int g_consecutiveWins = 0;
ulong g_performanceCounter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize configuration
   g_config = new CEAConfig();
   InitializeConfigFromInputs(g_config);
   
   if(!g_config.Validate())
   {
      Print("ERROR: Invalid configuration parameters");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize logger
   g_logger = new CLogger(g_config.EnableDebugLog, g_config.EnableDetailedLogging, 
                          g_config.EnableAlerts);
   
   // Initialize session filter
   g_sessionFilter = new CSessionFilter(g_config, g_logger);
   
   // Initialize ATR indicator
   g_atrLowerTF = new CATRIndicator(_Symbol, g_config.LowerTF, 14, g_logger);
   if(!g_atrLowerTF.Initialize())
   {
      g_logger.LogError("Failed to initialize ATR indicator");
      return INIT_FAILED;
   }
   
   // Initialize risk manager
   g_riskManager = new CRiskManager(_Symbol, g_config, g_atrLowerTF, g_logger);
   
   // Initialize order manager
   g_orderManager = new COrderManager(_Symbol, g_config, g_logger);
   
   // Initialize market structure analyzers
   g_msAnalyzer = new CMarketStructureAnalyzer(_Symbol, g_config.LowerTF, g_config, g_logger);
   g_fvgDetector = new CFVGDetector(_Symbol, g_config.LowerTF, g_config, g_logger);
   g_obDetector = new COrderBlockDetector(_Symbol, g_config.LowerTF, g_config, 
                                          g_fvgDetector, g_logger);
   
   // Initialize strategies
   ArrayResize(g_strategies, 1);
   g_strategies[0] = new COB_FVG_ComboStrategy(_Symbol, g_config.LowerTF, g_config,
                                               g_msAnalyzer, g_fvgDetector, g_obDetector,
                                               g_atrLowerTF, g_logger);
   
   // Initialize global state variables
   ResetDailyCounters();
   
   // Initialize week and month start times
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dayOfWeek = dt.day_of_week == 0 ? 7 : dt.day_of_week;
   int daysFromMonday = (dayOfWeek == 1) ? 0 : (dayOfWeek - 1);
   g_weekStartTime = TimeCurrent() - (daysFromMonday * 86400);
   g_monthStartTime = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, 1));
   
   g_logger.LogInfo("SMC Scalper EA initialized successfully");
   g_logger.LogInfo("Symbol: " + _Symbol);
   g_logger.LogInfo("Risk Per Trade: " + DoubleToString(g_config.BaseRiskPerTrade, 2) + "%");
   g_logger.LogInfo("Risk:Reward: " + DoubleToString(g_config.RiskReward, 2));
   g_logger.LogInfo("Magic Number: " + IntegerToString(g_config.MagicNumber));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(g_atrLowerTF != NULL)
   {
      g_atrLowerTF.Release();
      delete g_atrLowerTF;
   }
   
   // Delete strategies
   for(int i = 0; i < ArraySize(g_strategies); i++)
   {
      if(g_strategies[i] != NULL)
         delete g_strategies[i];
   }
   
   // Delete market structure analyzers
   if(g_obDetector != NULL) delete g_obDetector;
   if(g_fvgDetector != NULL) delete g_fvgDetector;
   if(g_msAnalyzer != NULL) delete g_msAnalyzer;
   
   // Delete managers
   if(g_orderManager != NULL) delete g_orderManager;
   if(g_riskManager != NULL) delete g_riskManager;
   if(g_sessionFilter != NULL) delete g_sessionFilter;
   if(g_logger != NULL) delete g_logger;
   if(g_config != NULL) delete g_config;
   
   // Clean up drawings
   if(g_config != NULL && g_config.EnableDrawings)
   {
      ObjectsDeleteAll(0, "SMC_");
   }
   
   Print("SMC Scalper EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   
   ulong dealTicket = trans.deal;
   if(dealTicket == 0)
      return;
   
   if(!HistoryDealSelect(dealTicket))
      return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != g_config.MagicNumber)
      return;
   
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   
   double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double totalProfit = dealProfit + dealSwap + dealCommission;
   
   // Update global profit variables
   g_dailyProfit += totalProfit;
   g_weeklyProfit += totalProfit;
   g_monthlyProfit += totalProfit;
   
   // Update consecutive losses/wins
   if(totalProfit < 0)
   {
      g_consecutiveLosses++;
      g_consecutiveWins = 0;
   }
   else
   {
      g_consecutiveLosses = 0;
      g_consecutiveWins++;
   }
   
   if(g_riskManager != NULL)
   {
      g_riskManager.OnTradeClosed(totalProfit);
      // Sync global variables with RiskManager
      g_riskManager.SetDailyProfit(g_dailyProfit);
      g_riskManager.SetWeeklyProfit(g_weeklyProfit);
      g_riskManager.SetMonthlyProfit(g_monthlyProfit);
      g_riskManager.SetConsecutiveLosses(g_consecutiveLosses);
   }
   
   if(g_logger != NULL && g_config.EnableDetailedLogging)
   {
      g_logger.LogTrade("Trade closed. Profit: " + DoubleToString(totalProfit, 2) +
                       " | Daily Profit: " + DoubleToString(g_dailyProfit, 2) +
                       " | Consecutive Losses: " + IntegerToString(g_consecutiveLosses));
   }
}

//+------------------------------------------------------------------+
//| Manage open positions (from original)                           |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!PositionSelect(_Symbol))
      return;
   
   if(g_orderManager == NULL || g_config == NULL)
      return;
   
   // Get position information
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);
   bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   
   // Get stop level to prevent "Invalid stops" errors
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopLevel > 0 ? stopLevel * point : point * 10;
   
   // Check if we're already at breakeven (with small tolerance)
   bool isAtBreakeven = MathAbs(currentSL - openPrice) < (point * 5);
   
   // Calculate profit and risk
   double slDistance = MathAbs(openPrice - currentSL);
   double riskAmount = slDistance;
   double profit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
   
   // CRITICAL FIX: Delay breakeven to 2.0R instead of 1.5R
   bool shouldMoveToBreakeven = false;
   if(isBuy)
      shouldMoveToBreakeven = (profit >= riskAmount * 2.0 && !isAtBreakeven && currentSL < openPrice);
   else
      shouldMoveToBreakeven = (profit >= riskAmount * 2.0 && !isAtBreakeven && currentSL > openPrice);
   
   if(shouldMoveToBreakeven)
   {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double breakevenSL = NormalizeDouble(openPrice, digits);
      
      bool isValidBreakeven = false;
      if(isBuy)
         isValidBreakeven = (breakevenSL < currentPrice - minStopDistance);
      else
         isValidBreakeven = (breakevenSL > currentPrice + minStopDistance);
      
      if(isValidBreakeven)
      {
         if(g_orderManager.ModifyPosition(ticket, breakevenSL, currentTP))
         {
            if(g_config.EnableDebugLog)
               Print("Stop moved to breakeven: Ticket ", ticket);
            return; // Exit early to avoid trailing stop conflict
         }
      }
   }
   
   // Trailing Stop Management (ATR-based)
   if(g_config.UseTrailingStop && g_config.TrailingStopPips > 0 && g_atrLowerTF != NULL)
   {
      double trailingStopDistance = 0;
      double trailingStep = g_config.TrailingStepPips * point * 10;
      
      // Use ATR-based trailing (2x ATR)
      double atrValue = g_atrLowerTF.GetValue(0);
      if(atrValue > 0)
         trailingStopDistance = atrValue * 2.0;
      else
         trailingStopDistance = g_config.TrailingStopPips * point * 10;
      
      double newSL = 0;
      bool modifySL = false;
      
      if(isBuy)
      {
         double currentProfit = currentPrice - openPrice;
         if(currentProfit > trailingStopDistance)
         {
            newSL = currentPrice - trailingStopDistance;
            if(newSL < openPrice)
               newSL = openPrice; // Keep at breakeven minimum
            
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
         if(currentProfit > trailingStopDistance)
         {
            newSL = currentPrice + trailingStopDistance;
            if(newSL > openPrice)
               newSL = openPrice; // Keep at breakeven minimum
            
            if(newSL < currentSL - trailingStep)
            {
               if(newSL > currentPrice + minStopDistance)
                  modifySL = true;
            }
         }
      }
      
      if(modifySL && newSL > 0)
      {
         int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         newSL = NormalizeDouble(newSL, digits);
         
         if(MathAbs(newSL - currentSL) > (point * 2))
         {
            if(g_orderManager.ModifyPosition(ticket, newSL, currentTP))
            {
               if(g_config.EnableDebugLog)
                  Print("Trailing Stop Updated: Ticket ", ticket, " | New SL: ", newSL);
            }
         }
      }
   }
   
   // 3-tier exits or dynamic TP extension
   if(g_config.Use3TierExits)
   {
      // Use OrderManager's 3-tier exit logic
      g_orderManager.Check3TierExits();
   }
   else if(slDistance > 0)
   {
      // Dynamic TP extension for high-momentum trades
      double currentRR = profit / slDistance;
      if(currentRR >= 2.0 && CheckStrongMomentum(isBuy))
      {
         double newTP = 0;
         if(isBuy)
            newTP = currentPrice + (slDistance * 1.5); // Extend by 1.5R
         else
            newTP = currentPrice - (slDistance * 1.5);
         
         if(newTP > 0 && MathAbs(newTP - currentTP) > (point * 5))
         {
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            newTP = NormalizeDouble(newTP, digits);
            g_orderManager.ModifyPosition(ticket, currentSL, newTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check strong momentum (simplified version)                       |
//+------------------------------------------------------------------+
bool CheckStrongMomentum(bool isBuy)
{
   // Simplified momentum check - can be enhanced
   if(g_atrLowerTF == NULL || g_config == NULL)
      return false;
   
   double atr = g_atrLowerTF.GetValue(0);
   if(atr <= 0)
      return false;
   
   // Check if price moved significantly (more than 1.5x ATR in last few bars)
   double close0 = iClose(_Symbol, g_config.LowerTF, 0);
   double close3 = iClose(_Symbol, g_config.LowerTF, 3);
   
   if(isBuy)
      return (close0 - close3) > (atr * 1.5);
   else
      return (close3 - close0) > (atr * 1.5);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Performance tracking
   g_performanceCounter++;
   ulong startTime = GetMicrosecondCount();
   
   if(g_config == NULL)
      return;
   
   // Check if new bar
   datetime currentBarTime = iTime(_Symbol, g_config.LowerTF, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {
      g_lastBarTime = currentBarTime;
      
      // Reset daily counters if new day
      datetime currentTime = TimeCurrent();
      if(g_lastTradeTime == 0)
      {
         ResetDailyCounters();
      }
      else
      {
         MqlDateTime currentDT, lastDT;
         TimeToStruct(currentTime, currentDT);
         TimeToStruct(g_lastTradeTime, lastDT);
         
         if(currentDT.day != lastDT.day || currentDT.mon != lastDT.mon || currentDT.year != lastDT.year)
         {
            ResetDailyCounters();
         }
      }
      
      // Update market structure analysis
      if(g_msAnalyzer != NULL)
         g_msAnalyzer.Update();
      if(g_fvgDetector != NULL)
         g_fvgDetector.Detect();
      if(g_obDetector != NULL)
         g_obDetector.Detect();
      
      // TODO: Add DetectLiquidityZones() when implemented
      // DetectLiquidityZones();
      
      // Draw on chart if enabled
      if(g_config.EnableDrawings)
      {
         // TODO: Add drawing functions when implemented
         // DrawMarketStructure();
         // DrawLiquidityZones();
         // DrawOrderBlocks();
         // DrawFairValueGaps();
      }
   }
   
   // Check for entry signals (only on new bar to reduce CPU usage)
   if(isNewBar && CanTrade())
   {
      // TIME FILTER: Optimal Trading Time
      if(!IsOptimalTradingTime() && !g_config.TradeAllDay)
      {
         if(g_config.EnableDebugLog)
            Print("Skipping trade - Outside optimal trading hours");
         // Skip entry signals but continue to ManagePositions()
      }
      else
      {
         // TODO: Add ADX filter check if UseADXFilter
         // TODO: Add market regime check if AvoidRangingMarkets
         // TODO: Add correlation exposure check if UseCorrelationFilter
         
         CheckForEntrySignals();
      }
   }
   
   // Manage open positions (EVERY TICK - critical!)
   ManagePositions();
   
   // TODO: Add performance metrics update if TrackPerformanceMetrics
   // TODO: Add strategy adaptation if EnableStrategyAdaptation
   // TODO: Add Live GA if UseLiveGA
   // TODO: Add quantum metrics if UseQuantumMetrics
   
   // Performance logging (every 1000 ticks)
   if(g_performanceCounter % 1000 == 0)
   {
      ulong endTime = GetMicrosecondCount();
      double executionTime = (endTime - startTime) / 1000.0; // Convert to milliseconds
      if(executionTime > 100.0)
      {
         Print("WARNING: Execution time exceeded 100ms: ", DoubleToString(executionTime, 2), "ms");
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize configuration from input parameters                   |
//+------------------------------------------------------------------+
void InitializeConfigFromInputs(CEAConfig* config)
{
   // Risk Management
   config.BaseRiskPerTrade = BaseRiskPerTrade;
   config.MaxRiskPerTrade = MaxRiskPerTrade;
   config.UseConfluenceBasedRisk = UseConfluenceBasedRisk;
   config.HighConfidenceMultiplier = HighConfidenceMultiplier;
   config.MediumConfidenceMultiplier = MediumConfidenceMultiplier;
   config.MaxDailyLoss = MaxDailyLoss;
   config.MaxWeeklyLoss = MaxWeeklyLoss;
   config.MaxMonthlyLoss = MaxMonthlyLoss;
   config.MaxTradesPerDay = MaxTradesPerDay;
   config.MaxConsecutiveLosses = MaxConsecutiveLosses;
   config.UseAdaptiveRiskScaling = UseAdaptiveRiskScaling;
   config.WinningStreakThreshold = WinningStreakThreshold;
   config.WinningStreakMultiplier = WinningStreakMultiplier;
   config.UseAISL = UseAISL;
   config.PartialClose = PartialClose;
   config.RiskReward = RiskReward;
   config.PartialClosePercent = PartialClosePercent;
   config.UseTrailingStop = UseTrailingStop;
   config.TrailingStopPips = TrailingStopPips;
   config.TrailingStepPips = TrailingStepPips;
   config.CompoundProfits = CompoundProfits;
   config.CompoundMultiplier = CompoundMultiplier;
   config.Use3TierExits = Use3TierExits;
   config.UseVolatilityAdjustment = UseVolatilityAdjustment;
   config.VolatilityScaleDown = VolatilityScaleDown;
   config.VolatilityScaleUp = VolatilityScaleUp;
   config.MaxHoldHours = MaxHoldHours;
   
   // Timeframe Settings
   config.StructureTF = StructureTF;
   config.HigherTF = HigherTF;
   config.MediumTF = MediumTF;
   config.LowerTF = LowerTF;
   config.UseEMATrendFilter = UseEMATrendFilter;
   config.EMATrendTF = EMATrendTF;
   
   // Session Filters
   config.TradeLondonOpen = TradeLondonOpen;
   config.TradeNYOpen = TradeNYOpen;
   config.TradeAsianSession = TradeAsianSession;
   config.TradeAllDay = TradeAllDay;
   config.AvoidNews = AvoidNews;
   config.NewsMinutesBefore = NewsMinutesBefore;
   config.NewsMinutesAfter = NewsMinutesAfter;
   
   // Market Structure
   config.SwingValidationBars = SwingValidationBars;
   config.MSSThreshold = MSSThreshold;
   config.RequireBOS = RequireBOS;
   config.RequireCHoCH = RequireCHoCH;
   
   // Liquidity Zones
   config.EqualHighLowLookback = EqualHighLowLookback;
   config.EqualHighLowTolerance = EqualHighLowTolerance;
   config.FVGLookback = FVGLookback;
   config.FVGMinSize = FVGMinSize;
   config.TrackFVGMitigation = TrackFVGMitigation;
   
   // Order Blocks
   config.OrderBlockLookback = OrderBlockLookback;
   config.RequireOBConfluence = RequireOBConfluence;
   config.OBTimeFilter = OBTimeFilter;
   config.RequireVolumeConfirmation = RequireVolumeConfirmation;
   config.VolumeSpikeMultiplier = VolumeSpikeMultiplier;
   config.RequireFVGNearOB = RequireFVGNearOB;
   
   // Entry Conditions
   config.MinConfluenceScore = MinConfluenceScore;
   config.RequireLiquidityZone = RequireLiquidityZone;
   config.RequireOrderBlock = RequireOrderBlock;
   config.RequireFVG = RequireFVG;
   config.RequireBOSConfirmation = RequireBOSConfirmation;
   config.RequireLiquiditySweep = RequireLiquiditySweep;
   config.RequireHTFBias = RequireHTFBias;
   config.RequireM1MSS = RequireM1MSS;
   config.AvoidRangingMarkets = AvoidRangingMarkets;
   config.MinTrendStrength = MinTrendStrength;
   config.UseMomentumConfirmation = UseMomentumConfirmation;
   config.UseTickDivergence = UseTickDivergence;
   config.MinMomentumStrength = MinMomentumStrength;
   
   // Strategy Settings
   config.UseOB_FVG_Combo = UseOB_FVG_Combo;
   config.OB_FVG_MinFVG_Pips = OB_FVG_MinFVG_Pips;
   config.OB_FVG_OBLookback = OB_FVG_OBLookback;
   config.OB_FVG_RetracementMin = OB_FVG_RetracementMin;
   config.OB_FVG_RetracementMax = OB_FVG_RetracementMax;
   config.OB_FVG_QualityMin = OB_FVG_QualityMin;
   
   // Advanced Settings
   config.EnableMarketRegime = EnableMarketRegime;
   config.ATRMultiplier = ATRMultiplier;
   config.UseSessionBasedATR = UseSessionBasedATR;
   config.LondonATRMultiplier = LondonATRMultiplier;
   config.NYATRMultiplier = NYATRMultiplier;
   config.OverlapATRMultiplier = OverlapATRMultiplier;
   config.AsianATRMultiplier = AsianATRMultiplier;
   config.MagicNumber = MagicNumber;
   config.TradeComment = TradeComment;
   config.EnableAlerts = EnableAlerts;
   config.EnableDrawings = EnableDrawings;
   config.EnableDebugLog = EnableDebugLog;
   config.EnableDetailedLogging = EnableDetailedLogging;
   config.UseCustomRSI = UseCustomRSI;
   config.RSIPeriod = RSIPeriod;
   config.UseVolumeProfile = UseVolumeProfile;
   config.OptimizeBarProcessing = OptimizeBarProcessing;
   config.UseDynamicRisk = UseDynamicRisk;
   config.UseKellyCriterion = UseKellyCriterion;
   config.KellyFraction = KellyFraction;
   config.UseADXFilter = UseADXFilter;
   config.MinADX = MinADX;
   config.MaxADXForRanging = MaxADXForRanging;
   config.ADXPeriod = ADXPeriod;
   config.TrackPerformanceMetrics = TrackPerformanceMetrics;
   config.EnableStrategyAdaptation = EnableStrategyAdaptation;
   config.AdaptationPeriod = AdaptationPeriod;
   config.DecayThreshold = DecayThreshold;
   config.UseCorrelationFilter = UseCorrelationFilter;
   config.MaxCorrelationRisk = MaxCorrelationRisk;
   config.UseOrderFlowAnalysis = UseOrderFlowAnalysis;
   config.UseKalmanFilter = UseKalmanFilter;
   config.UseEVTRisk = UseEVTRisk;
   config.UseFractalRisk = UseFractalRisk;
   config.DetectSpoofing = DetectSpoofing;
   config.UseDarkPoolDetection = UseDarkPoolDetection;
   config.UseLiveGA = UseLiveGA;
   config.UseQuantumMetrics = UseQuantumMetrics;
   config.UseMillisecondTiming = UseMillisecondTiming;
   config.OrderFlowLookback = OrderFlowLookback;
   config.KalmanQ = KalmanQ;
   config.KalmanR = KalmanR;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CanTrade()
{
   if(g_config == NULL)
      return false;
   
   // Check daily trade limit
   if(g_dailyTrades >= g_config.MaxTradesPerDay)
   {
      if(g_config.EnableDebugLog)
         Print("Daily trade limit reached: ", g_dailyTrades, "/", g_config.MaxTradesPerDay);
      return false;
   }
   
   // Check consecutive losses
   if(g_consecutiveLosses >= g_config.MaxConsecutiveLosses)
   {
      if(g_config.EnableAlerts)
         Alert("Max consecutive losses reached (", g_consecutiveLosses, "). Trading stopped for safety.");
      if(g_config.EnableDebugLog)
         Print("Trading stopped: ", g_consecutiveLosses, " consecutive losses");
      return false;
   }
   
   // Check daily loss limit
   if(g_riskManager != NULL)
   {
      double currentBalance = g_riskManager.GetAccountBalance();
      double dailyLossLimit = currentBalance * g_config.MaxDailyLoss / 100.0;
      // Sync global variable with RiskManager
      g_dailyProfit = g_riskManager.GetDailyProfit();
      if(g_dailyProfit <= -dailyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Daily loss limit reached (", DoubleToString(g_dailyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Daily loss limit reached: ", g_dailyProfit, " / ", -dailyLossLimit);
         return false;
      }
      
      // Check weekly loss limit
      double weeklyLossLimit = currentBalance * g_config.MaxWeeklyLoss / 100.0;
      g_weeklyProfit = g_riskManager.GetWeeklyProfit();
      if(g_weeklyProfit <= -weeklyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Weekly loss limit reached (", DoubleToString(g_weeklyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Weekly loss limit reached: ", g_weeklyProfit, " / ", -weeklyLossLimit);
         return false;
      }
      
      // Check monthly loss limit
      double monthlyLossLimit = currentBalance * g_config.MaxMonthlyLoss / 100.0;
      g_monthlyProfit = g_riskManager.GetMonthlyProfit();
      g_consecutiveLosses = g_riskManager.GetConsecutiveLosses();
      if(g_monthlyProfit <= -monthlyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Monthly loss limit reached (", DoubleToString(g_monthlyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Monthly loss limit reached: ", g_monthlyProfit, " / ", -monthlyLossLimit);
         return false;
      }
   }
   
   // Check trading sessions
   if(g_sessionFilter != NULL && !g_sessionFilter.CanTrade())
      return false;
   
   // Check for news events (if enabled)
   if(g_config.AvoidNews && IsHighImpactNews(2))
      return false;
   
   // Check if position already exists
   if(g_orderManager != NULL && g_orderManager.HasOpenPosition())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for entry signals from all strategies                      |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
   if(g_config == NULL)
      return;
   
   TradeSignal signal;
   ZeroMemory(signal);
   
   // Debug logging
   if(g_config.EnableDetailedLogging)
      Print("=== CHECKING FOR ENTRY SIGNALS ===");
   
   // Check all strategies
   for(int i = 0; i < ArraySize(g_strategies); i++)
   {
      if(g_strategies[i] == NULL)
      {
         if(g_config.EnableDetailedLogging)
            Print("Strategy ", i, " is NULL");
         continue;
      }
      
      if(!g_strategies[i].IsEnabled())
      {
         if(g_config.EnableDetailedLogging)
            Print("Strategy ", i, " (", g_strategies[i].GetStrategyName(), ") is disabled");
         continue;
      }
      
      if(g_config.EnableDetailedLogging)
         Print("Checking strategy: ", g_strategies[i].GetStrategyName());
      
      // Check buy signal
      ZeroMemory(signal);
      if(g_strategies[i].CheckBuySignal(signal))
      {
         if(g_config.EnableDetailedLogging)
            Print("BUY signal found from ", g_strategies[i].GetStrategyName(), 
                  " | Entry: ", DoubleToString(signal.entryPrice, 5),
                  " | SL: ", DoubleToString(signal.stopLoss, 5),
                  " | TP: ", DoubleToString(signal.takeProfit, 5),
                  " | Confluence: ", signal.confluenceScore);
         
         if(ValidateSignal(signal))
         {
            if(g_config.EnableDetailedLogging)
               Print("Signal validated, executing trade...");
            ExecuteTrade(signal);
            return; // Only execute one trade per bar
         }
         else if(g_config.EnableDetailedLogging)
         {
            Print("Signal validation FAILED - Confluence: ", signal.confluenceScore, 
                  " (min required: ", g_config.MinConfluenceScore, ")");
         }
      }
      
      // Check sell signal
      ZeroMemory(signal);
      if(g_strategies[i].CheckSellSignal(signal))
      {
         if(g_config.EnableDetailedLogging)
            Print("SELL signal found from ", g_strategies[i].GetStrategyName(),
                  " | Entry: ", DoubleToString(signal.entryPrice, 5),
                  " | SL: ", DoubleToString(signal.stopLoss, 5),
                  " | TP: ", DoubleToString(signal.takeProfit, 5),
                  " | Confluence: ", signal.confluenceScore);
         
         if(ValidateSignal(signal))
         {
            if(g_config.EnableDetailedLogging)
               Print("Signal validated, executing trade...");
            ExecuteTrade(signal);
            return; // Only execute one trade per bar
         }
         else if(g_config.EnableDetailedLogging)
         {
            Print("Signal validation FAILED - Confluence: ", signal.confluenceScore,
                  " (min required: ", g_config.MinConfluenceScore, ")");
         }
      }
   }
   
   if(g_config.EnableDetailedLogging)
      Print("No entry signals found from any strategy");
}

//+------------------------------------------------------------------+
//| Validate trade signal                                            |
//+------------------------------------------------------------------+
bool ValidateSignal(TradeSignal &signal)
{
   if(g_config == NULL)
      return false;
   
   // Check confluence score
   if(signal.confluenceScore < g_config.MinConfluenceScore)
   {
      if(g_config.EnableDetailedLogging)
         Print("Signal validation failed: Confluence score ", signal.confluenceScore, 
               " < minimum required ", g_config.MinConfluenceScore);
      return false;
   }
   
   // Check if entry price is valid
   if(signal.entryPrice <= 0)
   {
      if(g_config.EnableDetailedLogging)
         Print("Signal validation failed: Invalid entry price ", signal.entryPrice);
      return false;
   }
   
   // Check if SL and TP are valid
   if(signal.stopLoss <= 0 || signal.takeProfit <= 0)
   {
      if(g_config.EnableDetailedLogging)
         Print("Signal validation failed: Invalid SL or TP");
      return false;
   }
   
   // Additional validations can be added here
   return true;
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(TradeSignal &signal)
{
   if(g_riskManager == NULL || g_orderManager == NULL)
      return;
   
   // Calculate risk-adjusted lot size
   double riskPercent = g_riskManager.CalculateRiskPercent(signal.confluenceScore);
   double lotSize = g_riskManager.CalculateLotSize(signal.entryPrice, signal.stopLoss, riskPercent);
   
   if(lotSize <= 0)
   {
      if(g_logger != NULL)
         g_logger.LogError("Invalid lot size calculated: " + DoubleToString(lotSize, 2));
      return;
   }
   
   // FINAL SAFETY CHECK: Verify margin before executing
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginRequired = 0.0;
   if(OrderCalcMargin(signal.direction == TRADE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, 
                      _Symbol, lotSize, signal.entryPrice, marginRequired))
   {
      if(marginRequired > freeMargin)
      {
         // Reduce lot size to fit available margin
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double maxLotByMargin = 0.0;
         
         // Binary search for maximum affordable lot size
         double testLot = minLot;
         double testMargin = 0.0;
         while(testLot <= lotSize)
         {
            if(OrderCalcMargin(signal.direction == TRADE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                              _Symbol, testLot, signal.entryPrice, testMargin))
            {
               if(testMargin <= freeMargin)
                  maxLotByMargin = testLot;
               else
                  break;
            }
            testLot += lotStep;
         }
         
         if(maxLotByMargin < minLot)
         {
            if(g_logger != NULL)
               g_logger.LogError("Insufficient margin for trade. Required: " + DoubleToString(marginRequired, 2) + 
                                " | Available: " + DoubleToString(freeMargin, 2) + 
                                " | Lot size: " + DoubleToString(lotSize, 2));
            return;
         }
         
         lotSize = maxLotByMargin;
         
         if(g_logger != NULL)
            g_logger.LogWarning("Lot size reduced before execution: " + DoubleToString(lotSize, 2) + 
                              " (margin check: " + DoubleToString(marginRequired, 2) + " > " + DoubleToString(freeMargin, 2) + ")");
      }
   }
   
   // FINAL NORMALIZATION: Ensure lot size matches broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Normalize to lot step (critical for brokers with lot step like 0.01)
   if(lotStep > 0)
   {
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
   }
   
   // Ensure within min/max bounds
   if(lotSize < minLot) 
   {
      if(g_logger != NULL)
         g_logger.LogWarning("Lot size " + DoubleToString(lotSize, 3) + " below minimum " + DoubleToString(minLot, 3) + " - using minimum");
      lotSize = minLot;
   }
   if(lotSize > maxLot) 
   {
      if(g_logger != NULL)
         g_logger.LogWarning("Lot size " + DoubleToString(lotSize, 3) + " above maximum " + DoubleToString(maxLot, 3) + " - using maximum");
      lotSize = maxLot;
   }
   
   // Final validation before execution
   if(lotSize <= 0 || lotSize < minLot)
   {
      if(g_logger != NULL)
         g_logger.LogError("Invalid lot size after normalization: " + DoubleToString(lotSize, 3) + 
                          " | Min: " + DoubleToString(minLot, 3) + 
                          " | Step: " + DoubleToString(lotStep, 3));
      return;
   }
   
   // Execute order
   bool success = false;
   string comment = g_config.TradeComment + " " + signal.strategy;
   
   if(signal.direction == TRADE_BUY)
   {
      success = g_orderManager.OpenBuyOrder(signal.entryPrice, signal.stopLoss, 
                                            signal.takeProfit, lotSize, comment);
   }
   else if(signal.direction == TRADE_SELL)
   {
      success = g_orderManager.OpenSellOrder(signal.entryPrice, signal.stopLoss, 
                                             signal.takeProfit, lotSize, comment);
   }
   
   if(success && g_riskManager != NULL)
   {
      g_riskManager.OnTradeOpened();
   }
   
   if(g_logger != NULL && success)
   {
      g_logger.LogTrade("Trade executed: " + EnumToString(signal.direction) + 
                       " Entry: " + DoubleToString(signal.entryPrice, 5) +
                       " SL: " + DoubleToString(signal.stopLoss, 5) +
                       " TP: " + DoubleToString(signal.takeProfit, 5) +
                       " Lots: " + DoubleToString(lotSize, 2));
   }
   
   // Update global state
   if(success)
   {
      g_dailyTrades++;
      g_lastTradeTime = TimeCurrent();
      
      // Sync with RiskManager
      if(g_riskManager != NULL)
      {
         g_riskManager.SetDailyTrades(g_dailyTrades);
      }
   }
}

//+------------------------------------------------------------------+
//| Reset daily trading counters (from original)                    |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   // FIRST: Reset to zero to prevent accumulation
   g_dailyTrades = 0;
   g_dailyProfit = 0.0;
   g_lastTradeTime = 0;
   
   // CRITICAL FIX: Reset consecutive losses at start of new day
   // This prevents EA from being stuck after hitting max consecutive losses
   if(g_consecutiveLosses > 0)
   {
      if(g_config != NULL && g_config.EnableDetailedLogging)
         Print("ResetDailyCounters: Resetting consecutive losses from ", g_consecutiveLosses, " to 0 (new day)");
      g_consecutiveLosses = 0;
   }
   
   // Use bar time for backtesting accuracy
   datetime referenceTime = g_lastBarTime;
   if(referenceTime == 0)
      referenceTime = TimeCurrent(); // Fallback
   
   MqlDateTime refDT;
   TimeToStruct(referenceTime, refDT);
   
   // Get start and end of current day
   datetime dayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                                   refDT.year, refDT.mon, refDT.day));
   datetime dayEnd = dayStart + 86400; // End of day
   
   // Select history for current day only
   if(HistorySelect(dayStart, dayEnd))
   {
      int totalDeals = HistoryDealsTotal();
      double todayProfit = 0.0;
      
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         if(g_config != NULL && HistoryDealGetInteger(ticket, DEAL_MAGIC) != g_config.MagicNumber)
            continue;
         
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
         
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         MqlDateTime dealDT;
         TimeToStruct(dealTime, dealDT);
         
         // Only count deals from today (double-check)
         if(dealDT.day == refDT.day && dealDT.mon == refDT.mon && dealDT.year == refDT.year)
         {
            double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double dealSwap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double dealCommission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            todayProfit += dealProfit + dealSwap + dealCommission;
         }
      }
      
      g_dailyProfit = todayProfit;
      
      if(g_config != NULL && g_config.EnableDebugLog)
         Print("ResetDailyCounters: Reset daily profit. Recalculated from history: ", 
               DoubleToString(g_dailyProfit, 2), " | Date: ", TimeToString(referenceTime, TIME_DATE));
   }
   else
   {
      if(g_config != NULL && g_config.EnableDebugLog)
         Print("ResetDailyCounters: HistorySelect failed. Daily profit reset to 0.0");
   }
   
   // Sync with RiskManager
   if(g_riskManager != NULL)
   {
      g_riskManager.ResetDailyCounters();
      g_riskManager.SetDailyTrades(g_dailyTrades);
      g_riskManager.SetDailyProfit(g_dailyProfit);
      g_riskManager.SetConsecutiveLosses(g_consecutiveLosses);
   }
}

//+------------------------------------------------------------------+
//| Check if optimal trading time (from original)                    |
//+------------------------------------------------------------------+
bool IsOptimalTradingTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   int hour = timeStruct.hour;
   
   // London/NY overlap premium (13:00-16:00 GMT)
   if(hour >= 13 && hour <= 16)
   {
      // Check for high-impact news
      if(g_config != NULL && g_config.AvoidNews && IsHighImpactNews(2))
         return false;
      return true;
   }
   
   // Standard trading hours (8:00-17:00 GMT)
   return (hour >= 8 && hour <= 17);
}

//+------------------------------------------------------------------+
//| Check if high impact news (placeholder - needs news API)        |
//+------------------------------------------------------------------+
bool IsHighImpactNews(int hoursBefore)
{
   // TODO: Integrate with news API
   // For now, check common news times
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // NFP: First Friday of month, 12:30 GMT
   // FOMC: Usually 18:00 GMT
   // CPI: Usually 12:30 GMT
   
   // Simplified check: Avoid trading 30 minutes before/after top of hour during news hours
   if(dt.min >= g_config.NewsMinutesBefore && dt.min <= (60 - g_config.NewsMinutesAfter))
   {
      if((dt.hour == 12 && dt.min >= 25 && dt.min <= 35) || // CPI/NFP time
         (dt.hour == 18 && dt.min >= 25 && dt.min <= 35))   // FOMC time
      {
         return true;
      }
   }
   
   return false;
}

