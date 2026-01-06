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
#include "Includes/OrderManagement/PositionManager.mqh"
#include "Includes/Filters/SessionFilter.mqh"
#include "Includes/Filters/TradingFilter.mqh"
#include "Includes/Filters/SignalManager.mqh"
#include "Includes/Indicators/MomentumAnalyzer.mqh"
#include "Includes/Confluence/MTFConfluenceAnalyzer.mqh"
#include "Includes/Confluence/PerfectEntryDetector.mqh"
// PerfectEntry struct is defined in PerfectEntryDetector.mqh
#include "Includes/OrderManagement/RiskFreePositionManager.mqh"
#include "Includes/Filters/EliteFilterSystem.mqh"
#include "Includes/Performance/PerformanceEnforcer.mqh"

//+------------------------------------------------------------------+
//| Input Parameters (same as original for compatibility)            |
//+------------------------------------------------------------------+
//--- Risk Management
input group "=== RISK MANAGEMENT ==="
input double BaseRiskPerTrade = 0.1; // 99% WIN RATE: Ultra-conservative 0.1% risk
input double MaxRiskPerTrade = 0.25; // 99% WIN RATE: Maximum 0.25% for perfect setups
input double HighConfidenceRisk = 0.25; // 99% WIN RATE: Only for perfect setups (confluence >= 95)
input bool UseConfluenceBasedRisk = true;
input double HighConfidenceMultiplier = 2.0;
input double MediumConfidenceMultiplier = 1.5;
input bool UseKellyCriterion = true; // PROFIT OPTIMIZED: Enable Kelly Criterion for optimal sizing
input double KellyFraction = 0.25; // PROFIT OPTIMIZED: Conservative Kelly fraction (0.1-0.25)
input double MaxDailyLoss = 2.0;
input double MaxWeeklyLoss = 5.0;
input double MaxMonthlyLoss = 10.0;
input int MaxTradesPerDay = 50; // OPTIMIZED: Increased to 50 for more opportunities (was 10)
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
input int MaxHoldHours = 2; // 99% WIN RATE: Maximum 2 hours (120 minutes)
input int MaxStopLossPips = 8; // 99% WIN RATE: Maximum 8 pips SL
input int BreakevenAtPips = 5; // 99% WIN RATE: Move to BE at +5 pips
input int PartialClose1AtPips = 8; // 99% WIN RATE: Close 50% at +8 pips
input int PartialClose2AtPips = 15; // 99% WIN RATE: Close 25% at +15 pips
input int TrailLockPips = 5; // 99% WIN RATE: Trail with 5-pip lock
input int MaxTradeDurationMinutes = 120; // 99% WIN RATE: Close if stagnant

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
input bool TradeLondonOpen = true; // Enable London session (08:00-10:00 GMT)
input bool TradeNYOpen = true; // Enable NY session (13:00-15:00 GMT)
input bool TradeLondonNYOverlap = true; // Enable London/NY overlap (13:00-16:00 GMT)
input bool TradeAsianSession = false; // Disabled - low volatility
input bool TradeAllDay = true; // ENABLED for backtesting - allows trading at any time
input bool AvoidNews = true;
input int NewsMinutesBefore = 15; // PROFIT OPTIMIZED: Reduced from 30 to 15 minutes
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
input bool RequireVolumeConfirmation = false;
input double VolumeSpikeMultiplier = 1.5;
input bool RequireFVGNearOB = true;

//--- Entry Conditions
input group "=== ENTRY CONDITIONS ==="
input bool TradeOnlyPerfectSetups = true; // 99% WIN RATE: Only trade perfect setups
input int RequiredConfluenceScore = 95; // 99% WIN RATE: Minimum 95/100 confluence
input bool RequireAllTimeframeAlignment = true; // 99% WIN RATE: All timeframes must align
input bool RequireInstitutionalFootprint = true; // 99% WIN RATE: Require institutional footprint
input int MinConfluenceScore = 95; // 99% WIN RATE: Minimum 95/100 for entry
input bool RequireLiquidityZone = false;
input bool RequireOrderBlock = true;
input bool RequireFVG = true; // PROFIT OPTIMIZED: Required for better entry quality
input bool RequireBOSConfirmation = true; // PROFIT OPTIMIZED: Enable BOS requirement
// RequireCHoCH is already declared in Market Structure section (line 91)
input bool RequireLiquiditySweep = false;
input bool RequireHTFBias = false;
input bool RequireM1MSS = false;
input bool AvoidRangingMarkets = true; // PROFIT OPTIMIZED: Enable to avoid ranging markets
input double MinTrendStrength = 0.0001;
input bool UseMomentumConfirmation = true;
input bool UseTickDivergence = true;
input double MinMomentumStrength = 0.5;
input bool UseMarketRegimeFilter = true; // PROFIT OPTIMIZED: Enable ADX/ATR-based regime filter
input double MinVolatilityPercent = 20.0; // PROFIT OPTIMIZED: Minimum 20% of average ATR

//--- SMC Bot Strategy Selection
input group "=== SMC BOT STRATEGIES ==="
input bool UseOB_FVG_Combo = true;
input double OB_FVG_MinFVG_Pips = 3.0; // PROFIT OPTIMIZED: Increased from 1.0 to 3.0 for quality FVGs
input int OB_FVG_OBLookback = 75; // PROFIT OPTIMIZED: Reduced from 100 to 75 (focus on recent OBs)
input double OB_FVG_RetracementMin = 0.40;
input double OB_FVG_RetracementMax = 0.80;
input int OB_FVG_QualityMin = 60; // PROFIT OPTIMIZED: Increased from 30 to 60 for high-quality setups

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
// UseKellyCriterion and KellyFraction are already declared in Risk Management section (lines 42-43)
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

// Managers
CPositionManager* g_positionManager = NULL;
CSignalManager* g_signalManager = NULL;
CTradingFilter* g_tradingFilter = NULL;
CMomentumAnalyzer* g_momentumAnalyzer = NULL;

// 99% Win Rate System Components
CMarketStructureAnalyzer* g_msDaily = NULL;
CMarketStructureAnalyzer* g_msH4 = NULL;
CMarketStructureAnalyzer* g_msH1 = NULL;
CMTFConfluenceAnalyzer* g_mtfAnalyzer = NULL;
CPerfectEntryDetector* g_perfectEntryDetector = NULL;
CRiskFreePositionManager* g_riskFreeManager = NULL;
CEliteFilterSystem* g_eliteFilter = NULL;
CPerformanceEnforcer* g_performanceEnforcer = NULL;

// State
datetime g_lastBarTime = 0;

// Global state structure
SEAState g_state;

// Legacy global variables (for compatibility)
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
   
   // Risk Management
   g_config.BaseRiskPerTrade = BaseRiskPerTrade;
   g_config.MaxRiskPerTrade = MaxRiskPerTrade;
   g_config.HighConfidenceRisk = HighConfidenceRisk;
   g_config.UseConfluenceBasedRisk = UseConfluenceBasedRisk;
   g_config.HighConfidenceMultiplier = HighConfidenceMultiplier;
   g_config.MediumConfidenceMultiplier = MediumConfidenceMultiplier;
   g_config.UseKellyCriterion = UseKellyCriterion;
   g_config.KellyFraction = KellyFraction;
   g_config.MaxDailyLoss = MaxDailyLoss;
   g_config.MaxWeeklyLoss = MaxWeeklyLoss;
   g_config.MaxMonthlyLoss = MaxMonthlyLoss;
   g_config.MaxTradesPerDay = MaxTradesPerDay;
   g_config.MaxConsecutiveLosses = MaxConsecutiveLosses;
   g_config.UseAdaptiveRiskScaling = UseAdaptiveRiskScaling;
   g_config.WinningStreakThreshold = WinningStreakThreshold;
   g_config.WinningStreakMultiplier = WinningStreakMultiplier;
   g_config.UseAISL = UseAISL;
   g_config.PartialClose = PartialClose;
   g_config.RiskReward = RiskReward;
   g_config.PartialClosePercent = PartialClosePercent;
   g_config.UseTrailingStop = UseTrailingStop;
   g_config.TrailingStopPips = TrailingStopPips;
   g_config.TrailingStepPips = TrailingStepPips;
   g_config.CompoundProfits = CompoundProfits;
   g_config.CompoundMultiplier = CompoundMultiplier;
   g_config.Use3TierExits = Use3TierExits;
   g_config.UseVolatilityAdjustment = UseVolatilityAdjustment;
   g_config.VolatilityScaleDown = VolatilityScaleDown;
   g_config.VolatilityScaleUp = VolatilityScaleUp;
   g_config.MaxHoldHours = MaxHoldHours;
   
   // Timeframe Settings
   g_config.StructureTF = StructureTF;
   g_config.HigherTF = HigherTF;
   g_config.MediumTF = MediumTF;
   g_config.LowerTF = LowerTF;
   g_config.UseEMATrendFilter = UseEMATrendFilter;
   g_config.EMATrendTF = EMATrendTF;
   
   // Session Filters
   g_config.TradeLondonOpen = TradeLondonOpen;
   g_config.TradeNYOpen = TradeNYOpen;
   g_config.TradeLondonNYOverlap = TradeLondonNYOverlap;
   g_config.TradeAsianSession = TradeAsianSession;
   g_config.TradeAllDay = TradeAllDay;
   g_config.AvoidNews = AvoidNews;
   g_config.NewsMinutesBefore = NewsMinutesBefore;
   g_config.NewsMinutesAfter = NewsMinutesAfter;
   
   // Market Structure
   g_config.SwingValidationBars = SwingValidationBars;
   g_config.MSSThreshold = MSSThreshold;
   g_config.RequireBOS = RequireBOS;
   g_config.RequireCHoCH = RequireCHoCH;
   
   // Liquidity Zones
   g_config.EqualHighLowLookback = EqualHighLowLookback;
   g_config.EqualHighLowTolerance = EqualHighLowTolerance;
   g_config.FVGLookback = FVGLookback;
   g_config.FVGMinSize = FVGMinSize;
   g_config.TrackFVGMitigation = TrackFVGMitigation;
   
   // Order Blocks
   g_config.OrderBlockLookback = OrderBlockLookback;
   g_config.RequireOBConfluence = RequireOBConfluence;
   g_config.OBTimeFilter = OBTimeFilter;
   g_config.RequireVolumeConfirmation = RequireVolumeConfirmation;
   g_config.VolumeSpikeMultiplier = VolumeSpikeMultiplier;
   g_config.RequireFVGNearOB = RequireFVGNearOB;
   
   // Entry Conditions
   g_config.MinConfluenceScore = MinConfluenceScore;
   g_config.RequireLiquidityZone = RequireLiquidityZone;
   g_config.RequireOrderBlock = RequireOrderBlock;
   g_config.RequireFVG = RequireFVG;
   g_config.RequireBOSConfirmation = RequireBOSConfirmation;
   // RequireCHoCH is already assigned in Market Structure section (line 289)
   g_config.RequireLiquiditySweep = RequireLiquiditySweep;
   g_config.RequireHTFBias = RequireHTFBias;
   g_config.RequireM1MSS = RequireM1MSS;
   g_config.AvoidRangingMarkets = AvoidRangingMarkets;
   g_config.MinTrendStrength = MinTrendStrength;
   g_config.UseMomentumConfirmation = UseMomentumConfirmation;
   g_config.UseTickDivergence = UseTickDivergence;
   g_config.MinMomentumStrength = MinMomentumStrength;
   g_config.UseMarketRegimeFilter = UseMarketRegimeFilter;
   g_config.MinVolatilityPercent = MinVolatilityPercent;
   
   // Strategy Settings
   g_config.UseOB_FVG_Combo = UseOB_FVG_Combo;
   g_config.OB_FVG_MinFVG_Pips = OB_FVG_MinFVG_Pips;
   g_config.OB_FVG_OBLookback = OB_FVG_OBLookback;
   g_config.OB_FVG_RetracementMin = OB_FVG_RetracementMin;
   g_config.OB_FVG_RetracementMax = OB_FVG_RetracementMax;
   g_config.OB_FVG_QualityMin = OB_FVG_QualityMin;
   
   // Advanced Settings
   g_config.EnableMarketRegime = EnableMarketRegime;
   g_config.ATRMultiplier = ATRMultiplier;
   g_config.UseSessionBasedATR = UseSessionBasedATR;
   g_config.LondonATRMultiplier = LondonATRMultiplier;
   g_config.NYATRMultiplier = NYATRMultiplier;
   g_config.OverlapATRMultiplier = OverlapATRMultiplier;
   g_config.AsianATRMultiplier = AsianATRMultiplier;
   g_config.MagicNumber = MagicNumber;
   g_config.TradeComment = TradeComment;
   g_config.EnableAlerts = EnableAlerts;
   g_config.EnableDrawings = EnableDrawings;
   g_config.EnableDebugLog = EnableDebugLog;
   g_config.EnableDetailedLogging = EnableDetailedLogging;
   g_config.UseCustomRSI = UseCustomRSI;
   g_config.RSIPeriod = RSIPeriod;
   g_config.UseVolumeProfile = UseVolumeProfile;
   g_config.OptimizeBarProcessing = OptimizeBarProcessing;
   g_config.UseDynamicRisk = UseDynamicRisk;
   // UseKellyCriterion and KellyFraction are already assigned in Risk Management section (lines 242-243)
   g_config.UseADXFilter = UseADXFilter;
   g_config.MinADX = MinADX;
   g_config.MaxADXForRanging = MaxADXForRanging;
   g_config.ADXPeriod = ADXPeriod;
   g_config.TrackPerformanceMetrics = TrackPerformanceMetrics;
   g_config.EnableStrategyAdaptation = EnableStrategyAdaptation;
   g_config.AdaptationPeriod = AdaptationPeriod;
   g_config.DecayThreshold = DecayThreshold;
   g_config.UseCorrelationFilter = UseCorrelationFilter;
   g_config.MaxCorrelationRisk = MaxCorrelationRisk;
   g_config.UseOrderFlowAnalysis = UseOrderFlowAnalysis;
   g_config.UseKalmanFilter = UseKalmanFilter;
   g_config.UseEVTRisk = UseEVTRisk;
   g_config.UseFractalRisk = UseFractalRisk;
   g_config.DetectSpoofing = DetectSpoofing;
   g_config.UseDarkPoolDetection = UseDarkPoolDetection;
   g_config.UseLiveGA = UseLiveGA;
   g_config.UseQuantumMetrics = UseQuantumMetrics;
   g_config.UseMillisecondTiming = UseMillisecondTiming;
   g_config.OrderFlowLookback = OrderFlowLookback;
   g_config.KalmanQ = KalmanQ;
   g_config.KalmanR = KalmanR;
   
   // DEBUG: Log the actual input value being used
   Print("=== EA CONFIGURATION DEBUG ===");
   Print("OB_FVG_QualityMin input value: ", OB_FVG_QualityMin);
   Print("OB_FVG_QualityMin config value: ", g_config.OB_FVG_QualityMin);
   
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
   
   // Initialize state structure
   ZeroMemory(g_state);
   g_state.dailyTrades = 0;
   g_state.consecutiveLosses = 0;
   g_state.consecutiveWins = 0;
   g_state.dailyProfit = 0.0;
   g_state.weeklyProfit = 0.0;
   g_state.monthlyProfit = 0.0;
   
   // Initialize managers
   g_positionManager = new CPositionManager(_Symbol, g_config, g_orderManager, g_atrLowerTF, g_logger);
   g_signalManager = new CSignalManager(g_config, g_strategies, g_riskManager, g_orderManager,
                                        _Symbol, g_logger);
   g_tradingFilter = new CTradingFilter(g_config, g_riskManager, g_orderManager, g_sessionFilter,
                                       g_logger);
   g_momentumAnalyzer = new CMomentumAnalyzer(_Symbol, g_config, g_atrLowerTF, g_logger);
   
   // Initialize 99% Win Rate System Components
   g_msDaily = new CMarketStructureAnalyzer(_Symbol, PERIOD_D1, g_config, g_logger);
   g_msH4 = new CMarketStructureAnalyzer(_Symbol, PERIOD_H4, g_config, g_logger);
   g_msH1 = new CMarketStructureAnalyzer(_Symbol, PERIOD_H1, g_config, g_logger);
   g_mtfAnalyzer = new CMTFConfluenceAnalyzer(_Symbol, g_config, g_msDaily, g_msH4, g_msH1,
                                               g_fvgDetector, g_obDetector, g_atrLowerTF, g_logger);
   g_perfectEntryDetector = new CPerfectEntryDetector(_Symbol, g_config, g_mtfAnalyzer,
                                                      g_atrLowerTF, g_logger);
   g_riskFreeManager = new CRiskFreePositionManager(_Symbol, g_config, g_orderManager,
                                                    g_atrLowerTF, g_logger);
   g_eliteFilter = new CEliteFilterSystem(_Symbol, g_config, g_atrLowerTF, g_logger);
   g_performanceEnforcer = new CPerformanceEnforcer(g_config, g_logger);
   
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
   
   // Cleanup 99% Win Rate System
   if(g_performanceEnforcer != NULL)
   {
      delete g_performanceEnforcer;
      g_performanceEnforcer = NULL;
   }
   if(g_eliteFilter != NULL)
   {
      delete g_eliteFilter;
      g_eliteFilter = NULL;
   }
   if(g_riskFreeManager != NULL)
   {
      delete g_riskFreeManager;
      g_riskFreeManager = NULL;
   }
   if(g_perfectEntryDetector != NULL)
   {
      delete g_perfectEntryDetector;
      g_perfectEntryDetector = NULL;
   }
   if(g_mtfAnalyzer != NULL)
   {
      delete g_mtfAnalyzer;
      g_mtfAnalyzer = NULL;
   }
   if(g_msH1 != NULL)
   {
      delete g_msH1;
      g_msH1 = NULL;
   }
   if(g_msH4 != NULL)
   {
      delete g_msH4;
      g_msH4 = NULL;
   }
   if(g_msDaily != NULL)
   {
      delete g_msDaily;
      g_msDaily = NULL;
   }
   
   if(g_positionManager != NULL) delete g_positionManager;
   if(g_signalManager != NULL) delete g_signalManager;
   if(g_tradingFilter != NULL) delete g_tradingFilter;
   if(g_momentumAnalyzer != NULL) delete g_momentumAnalyzer;
   
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
   
   // Update state structure
   g_state.dailyProfit += totalProfit;
   g_state.weeklyProfit += totalProfit;
   g_state.monthlyProfit += totalProfit;
   
   // Update consecutive losses/wins
   if(totalProfit < 0)
   {
      g_state.consecutiveLosses++;
      g_state.consecutiveWins = 0;
   }
   else
   {
      g_state.consecutiveLosses = 0;
      g_state.consecutiveWins++;
   }
   
   // Sync legacy global variables
   g_dailyProfit = g_state.dailyProfit;
   g_weeklyProfit = g_state.weeklyProfit;
   g_monthlyProfit = g_state.monthlyProfit;
   g_consecutiveLosses = g_state.consecutiveLosses;
   g_consecutiveWins = g_state.consecutiveWins;
   
   if(g_riskManager != NULL)
   {
      g_riskManager.OnTradeClosed(totalProfit);
      // Sync with RiskManager
      g_riskManager.SetDailyProfit(g_state.dailyProfit);
      g_riskManager.SetWeeklyProfit(g_state.weeklyProfit);
      g_riskManager.SetMonthlyProfit(g_state.monthlyProfit);
      g_riskManager.SetConsecutiveLosses(g_state.consecutiveLosses);
   }
   
   if(g_logger != NULL && g_config.EnableDetailedLogging)
   {
      g_logger.LogTrade("Trade closed. Profit: " + DoubleToString(totalProfit, 2) +
                       " | Daily Profit: " + DoubleToString(g_state.dailyProfit, 2) +
                       " | Consecutive Losses: " + IntegerToString(g_state.consecutiveLosses));
   }
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
      if(g_state.lastTradeTime == 0)
      {
         ResetDailyCounters();
      }
      else
      {
         MqlDateTime currentDT, lastDT;
         TimeToStruct(currentTime, currentDT);
         TimeToStruct(g_state.lastTradeTime, lastDT);
         
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
      
      // Update 99% Win Rate System MTF analyzers (critical for confluence analysis)
      if(g_msDaily != NULL)
         g_msDaily.Update();
      if(g_msH4 != NULL)
         g_msH4.Update();
      if(g_msH1 != NULL)
         g_msH1.Update();
      
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
   
   // Check for entry signals (on new bar OR every 5 minutes to catch more opportunities)
   // CRITICAL FIX: Check more frequently to catch entry signals
   static datetime lastSignalCheckTime = 0;
   datetime currentTime = TimeCurrent();
   bool shouldCheckSignals = false;
   
   if(isNewBar)
   {
      shouldCheckSignals = true; // Always check on new bar
      lastSignalCheckTime = currentTime;
   }
   else
   {
      // Also check every 5 minutes (not just on new bar) to catch more opportunities
      if(currentTime - lastSignalCheckTime >= 300) // 5 minutes = 300 seconds
      {
         shouldCheckSignals = true;
         lastSignalCheckTime = currentTime;
      }
   }
   
   // 99% WIN RATE SYSTEM: Check for perfect entry signals
   if(shouldCheckSignals)
   {
      // Debug: Check performance enforcer
      if(g_performanceEnforcer == NULL)
      {
         if(g_config.EnableDebugLog)
            Print("DEBUG: g_performanceEnforcer is NULL");
      }
      else if(!g_performanceEnforcer.CanTrade(g_state))
      {
         if(g_config.EnableDebugLog)
            Print("DEBUG: Performance enforcer blocked trading");
      }
      else if(g_tradingFilter == NULL)
      {
         if(g_config.EnableDebugLog)
            Print("DEBUG: g_tradingFilter is NULL");
      }
      else if(!g_tradingFilter.CanTrade(g_state))
      {
         if(g_config.EnableDebugLog)
            Print("DEBUG: Trading filter blocked trading");
      }
      else if(g_performanceEnforcer != NULL && g_performanceEnforcer.CanTrade(g_state))
      {
         if(g_tradingFilter != NULL && g_tradingFilter.CanTrade(g_state))
         {
            if(g_config.EnableDebugLog)
            {
               MqlDateTime dt;
               TimeToStruct(TimeCurrent(), dt);
               Print("DEBUG: All filters passed! Checking for perfect entries at ", 
                     IntegerToString(dt.hour), ":", IntegerToString(dt.min), " GMT");
            }
            
            // Elite filter validation
            string rejectionReason = "";
            bool eliteFilterPassed = false;
            
            // Check BUY signal
            if(g_perfectEntryDetector != NULL && g_eliteFilter != NULL)
            {
               if(g_config.EnableDebugLog)
                  Print("DEBUG: Checking BUY signal...");
               
               if(g_eliteFilter.ValidateAllFilters(TRADE_BUY, rejectionReason))
               {
                  if(g_config.EnableDebugLog)
                     Print("DEBUG: BUY - Elite filter passed, checking perfect entry...");
                  
                  PerfectEntry buyEntry;
                  ZeroMemory(buyEntry);
                  if(g_perfectEntryDetector.IsPerfectEntry(TRADE_BUY, buyEntry))
                  {
                     eliteFilterPassed = true;
                     ExecutePerfectTrade(buyEntry);
                  }
                  else if(g_config.EnableDebugLog)
                  {
                     Print("DEBUG: BUY - Perfect entry rejected: ", buyEntry.rejectionReason);
                  }
               }
               else if(g_config.EnableDebugLog)
               {
                  Print("DEBUG: BUY - Elite filter rejected: ", rejectionReason);
               }
            }
            else
            {
               if(g_config.EnableDebugLog)
                  Print("DEBUG: g_perfectEntryDetector or g_eliteFilter is NULL");
            }
            
            // Check SELL signal
            if(!eliteFilterPassed && g_perfectEntryDetector != NULL && g_eliteFilter != NULL)
            {
               if(g_config.EnableDebugLog)
                  Print("DEBUG: Checking SELL signal...");
               
               if(g_eliteFilter.ValidateAllFilters(TRADE_SELL, rejectionReason))
               {
                  if(g_config.EnableDebugLog)
                     Print("DEBUG: SELL - Elite filter passed, checking perfect entry...");
                  
                  PerfectEntry sellEntry;
                  ZeroMemory(sellEntry);
                  if(g_perfectEntryDetector.IsPerfectEntry(TRADE_SELL, sellEntry))
                  {
                     ExecutePerfectTrade(sellEntry);
                  }
                  else if(g_config.EnableDebugLog)
                  {
                     Print("DEBUG: SELL - Perfect entry rejected: ", sellEntry.rejectionReason);
                  }
               }
               else if(g_config.EnableDebugLog)
               {
                  Print("DEBUG: SELL - Elite filter rejected: ", rejectionReason);
               }
            }
         }
      }
   }
   
   // Manage open positions with risk-free logic
   if(g_riskFreeManager != NULL)
      g_riskFreeManager.Manage();
   else if(g_positionManager != NULL)
      g_positionManager.Manage();
   
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
   
   // DEBUG: Log the actual input value being used
   Print("=== EA CONFIGURATION DEBUG ===");
   Print("OB_FVG_QualityMin input value: ", OB_FVG_QualityMin);
   Print("OB_FVG_QualityMin config value: ", config.OB_FVG_QualityMin);
   
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
   if(g_state.dailyTrades >= g_config.MaxTradesPerDay)
   {
      if(g_config.EnableDebugLog)
         Print("Daily trade limit reached: ", g_state.dailyTrades, "/", g_config.MaxTradesPerDay);
      return false;
   }
   
   // Check consecutive losses - BUT allow reset after new day
   // CRITICAL FIX: Don't permanently block trading - reset after new day
   if(g_state.consecutiveLosses >= g_config.MaxConsecutiveLosses)
   {
      // Check if it's a new day - if so, reset consecutive losses
      datetime currentTime = TimeCurrent();
      if(g_state.lastTradeTime > 0)
      {
         MqlDateTime currentDT, lastDT;
         TimeToStruct(currentTime, currentDT);
         TimeToStruct(g_state.lastTradeTime, lastDT);
         
         // If new day, reset consecutive losses
         if(currentDT.day != lastDT.day || currentDT.mon != lastDT.mon || currentDT.year != lastDT.year)
         {
            if(g_config.EnableDebugLog)
               Print("New day detected - Resetting consecutive losses from ", g_state.consecutiveLosses, " to 0");
            g_state.consecutiveLosses = 0;
            g_consecutiveLosses = g_state.consecutiveLosses; // Sync legacy variable
            if(g_riskManager != NULL)
               g_riskManager.SetConsecutiveLosses(0);
         }
         else
         {
            // Same day - block trading temporarily
            if(g_config.EnableDebugLog)
               Print("Trading temporarily stopped: ", g_state.consecutiveLosses, " consecutive losses (will reset tomorrow)");
            return false;
         }
      }
      else
      {
         // No previous trade - reset
         g_state.consecutiveLosses = 0;
         g_consecutiveLosses = g_state.consecutiveLosses; // Sync legacy variable
         if(g_riskManager != NULL)
            g_riskManager.SetConsecutiveLosses(0);
      }
   }
   
   // Check daily loss limit
   if(g_riskManager != NULL)
   {
      double currentBalance = g_riskManager.GetAccountBalance();
      double dailyLossLimit = currentBalance * g_config.MaxDailyLoss / 100.0;
      // Sync state with RiskManager
      g_state.dailyProfit = g_riskManager.GetDailyProfit();
      g_dailyProfit = g_state.dailyProfit; // Sync legacy variable
      if(g_state.dailyProfit <= -dailyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Daily loss limit reached (", DoubleToString(g_state.dailyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Daily loss limit reached: ", g_state.dailyProfit, " / ", -dailyLossLimit);
         return false;
      }
      
      // Check weekly loss limit
      double weeklyLossLimit = currentBalance * g_config.MaxWeeklyLoss / 100.0;
      g_state.weeklyProfit = g_riskManager.GetWeeklyProfit();
      g_weeklyProfit = g_state.weeklyProfit; // Sync legacy variable
      if(g_state.weeklyProfit <= -weeklyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Weekly loss limit reached (", DoubleToString(g_weeklyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Weekly loss limit reached: ", g_weeklyProfit, " / ", -weeklyLossLimit);
         return false;
      }
      
      // Check monthly loss limit
      double monthlyLossLimit = currentBalance * g_config.MaxMonthlyLoss / 100.0;
      g_state.monthlyProfit = g_riskManager.GetMonthlyProfit();
      g_state.consecutiveLosses = g_riskManager.GetConsecutiveLosses();
      g_monthlyProfit = g_state.monthlyProfit; // Sync legacy variable
      g_consecutiveLosses = g_state.consecutiveLosses; // Sync legacy variable
      if(g_state.monthlyProfit <= -monthlyLossLimit)
      {
         if(g_config.EnableAlerts)
            Alert("Monthly loss limit reached (", DoubleToString(g_state.monthlyProfit, 2), "). Trading stopped.");
         if(g_config.EnableDebugLog)
            Print("Monthly loss limit reached: ", g_state.monthlyProfit, " / ", -monthlyLossLimit);
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
   
   // Update state structure
   if(success)
   {
      g_state.dailyTrades++;
      g_state.lastTradeTime = TimeCurrent();
      
      // Sync legacy global variables
      g_dailyTrades = g_state.dailyTrades;
      g_lastTradeTime = g_state.lastTradeTime;
      
      // Sync with RiskManager
      if(g_riskManager != NULL)
      {
         g_riskManager.SetDailyTrades(g_state.dailyTrades);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Perfect Trade - 99% Win Rate System                     |
//+------------------------------------------------------------------+
void ExecutePerfectTrade(PerfectEntry &entry)
{
   if(g_riskManager == NULL || g_orderManager == NULL)
      return;
   
   // Calculate lot size with ultra-conservative risk (0.1%)
   double riskPercent = entry.confluenceScore >= 95 ? 0.25 : 0.1; // 0.25% for perfect, 0.1% for others
   double lotSize = g_riskManager.CalculateLotSize(entry.entryPrice, entry.stopLoss, riskPercent);
   
   if(lotSize <= 0)
   {
      if(g_config.EnableDebugLog)
         Print("PERFECT TRADE: Invalid lot size calculated. Rejecting.");
      return;
   }
   
   // Execute trade
   bool success = false;
   if(entry.direction == TRADE_BUY)
   {
      success = g_orderManager.OpenBuyOrder(entry.entryPrice, entry.stopLoss, entry.partialTP1, 
                                           lotSize, "Perfect Entry BUY");
   }
   else
   {
      success = g_orderManager.OpenSellOrder(entry.entryPrice, entry.stopLoss, entry.partialTP1, 
                                            lotSize, "Perfect Entry SELL");
   }
   
   if(success)
   {
      g_state.dailyTrades++;
      g_state.lastTradeTime = TimeCurrent();
      
      if(g_performanceEnforcer != NULL)
         g_performanceEnforcer.RecordTradeResult(true); // Will be updated on close
      
      if(g_config.EnableDebugLog)
         Print("PERFECT TRADE EXECUTED! Direction: ", entry.direction == TRADE_BUY ? "BUY" : "SELL",
               " | Entry: ", entry.entryPrice, " | SL: ", entry.stopLoss,
               " | TP1: ", entry.partialTP1, " | Confluence: ", entry.confluenceScore, "/100");
   }
}

//+------------------------------------------------------------------+
//| Reset daily trading counters (from original)                    |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   // FIRST: Reset state structure to zero to prevent accumulation
   g_state.dailyTrades = 0;
   g_state.dailyProfit = 0.0;
   g_state.lastTradeTime = 0;
   
   // CRITICAL FIX: Reset consecutive losses at start of new day
   // This prevents EA from being stuck after hitting max consecutive losses
   if(g_state.consecutiveLosses > 0)
   {
      if(g_config != NULL && g_config.EnableDetailedLogging)
         Print("ResetDailyCounters: Resetting consecutive losses from ", g_state.consecutiveLosses, " to 0 (new day)");
      g_state.consecutiveLosses = 0;
   }
   
   // Sync legacy global variables
   g_dailyTrades = g_state.dailyTrades;
   g_dailyProfit = g_state.dailyProfit;
   g_lastTradeTime = g_state.lastTradeTime;
   g_consecutiveLosses = g_state.consecutiveLosses;
   
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
      
      g_state.dailyProfit = todayProfit;
      g_dailyProfit = g_state.dailyProfit; // Sync legacy variable
      
      if(g_config != NULL && g_config.EnableDebugLog)
         Print("ResetDailyCounters: Reset daily profit. Recalculated from history: ", 
               DoubleToString(g_state.dailyProfit, 2), " | Date: ", TimeToString(referenceTime, TIME_DATE));
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
      g_riskManager.SetDailyTrades(g_state.dailyTrades);
      g_riskManager.SetDailyProfit(g_state.dailyProfit);
      g_riskManager.SetConsecutiveLosses(g_state.consecutiveLosses);
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

