//+------------------------------------------------------------------+
//|                                          ConfigInitializer.mqh   |
//|                        Configuration Initializer Class            |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "EAConfig.mqh"

//+------------------------------------------------------------------+
//| Config Initializer - Initializes config from input parameters   |
//+------------------------------------------------------------------+
class CConfigInitializer
{
public:
   static void Initialize(CEAConfig* config,
                         // Risk Management
                         double baseRiskPerTrade, double maxRiskPerTrade, bool useConfluenceBasedRisk,
                         double highConfidenceMultiplier, double mediumConfidenceMultiplier,
                         double maxDailyLoss, double maxWeeklyLoss, double maxMonthlyLoss,
                         int maxTradesPerDay, int maxConsecutiveLosses, bool useAdaptiveRiskScaling,
                         int winningStreakThreshold, double winningStreakMultiplier,
                         bool useAISL, bool partialClose, double riskReward, double partialClosePercent,
                         bool useTrailingStop, double trailingStopPips, double trailingStepPips,
                         bool compoundProfits, double compoundMultiplier, bool use3TierExits,
                         bool useVolatilityAdjustment, double volatilityScaleDown, double volatilityScaleUp,
                         int maxHoldHours,
                         // Timeframe Settings
                         ENUM_TIMEFRAMES structureTF, ENUM_TIMEFRAMES higherTF, 
                         ENUM_TIMEFRAMES mediumTF, ENUM_TIMEFRAMES lowerTF,
                         bool useEMATrendFilter, ENUM_TIMEFRAMES emaTrendTF,
                         // Trading Sessions
                         bool tradeLondonOpen, bool tradeNYOpen, bool tradeAsianSession, bool tradeAllDay,
                         bool avoidNews, int newsMinutesBefore, int newsMinutesAfter,
                         // Market Structure
                         int swingValidationBars, double mssThreshold, bool requireBOS, bool requireCHoCH,
                         // Liquidity Zones
                         int equalHighLowLookback, double equalHighLowTolerance,
                         int fvgLookback, double fvgMinSize, bool trackFVGMitigation,
                         // Order Blocks
                         int orderBlockLookback, bool requireOBConfluence, int obTimeFilter,
                         bool requireVolumeConfirmation, double volumeSpikeMultiplier, bool requireFVGNearOB,
                         // Entry Conditions
                         int minConfluenceScore, bool requireLiquidityZone, bool requireOrderBlock,
                         bool requireFVG, bool requireBOSConfirmation, bool requireLiquiditySweep,
                         bool requireHTFBias, bool requireM1MSS, bool avoidRangingMarkets,
                         double minTrendStrength, bool useMomentumConfirmation, bool useTickDivergence,
                         double minMomentumStrength,
                         // Strategy Settings
                         bool useOB_FVG_Combo, double ob_FVG_MinFVG_Pips, int ob_FVG_OBLookback,
                         double ob_FVG_RetracementMin, double ob_FVG_RetracementMax, int ob_FVG_QualityMin,
                         // Advanced Settings Part 1
                         bool enableMarketRegime, double atrMultiplier, bool useSessionBasedATR,
                         double londonATRMultiplier, double nyATRMultiplier, double overlapATRMultiplier,
                         double asianATRMultiplier, int magicNumber, string tradeComment,
                         bool enableAlerts, bool enableDrawings, bool enableDebugLog, bool enableDetailedLogging,
                         // Advanced Settings Part 2
                         bool useCustomRSI, int rsiPeriod, bool useVolumeProfile, bool optimizeBarProcessing,
                         bool useDynamicRisk, bool useKellyCriterion, double kellyFraction,
                         bool useADXFilter, double minADX, double maxADXForRanging, int adxPeriod,
                         bool trackPerformanceMetrics, bool enableStrategyAdaptation, int adaptationPeriod,
                         double decayThreshold, bool useCorrelationFilter, double maxCorrelationRisk,
                         bool useOrderFlowAnalysis, bool useKalmanFilter, bool useEVTRisk, bool useFractalRisk,
                         bool detectSpoofing, bool useDarkPoolDetection, bool useLiveGA,
                         bool useQuantumMetrics, bool useMillisecondTiming, int orderFlowLookback,
                         double kalmanQ, double kalmanR)
   {
      // Risk Management
      config.BaseRiskPerTrade = baseRiskPerTrade;
      config.MaxRiskPerTrade = maxRiskPerTrade;
      config.UseConfluenceBasedRisk = useConfluenceBasedRisk;
      config.HighConfidenceMultiplier = highConfidenceMultiplier;
      config.MediumConfidenceMultiplier = mediumConfidenceMultiplier;
      config.MaxDailyLoss = maxDailyLoss;
      config.MaxWeeklyLoss = maxWeeklyLoss;
      config.MaxMonthlyLoss = maxMonthlyLoss;
      config.MaxTradesPerDay = maxTradesPerDay;
      config.MaxConsecutiveLosses = maxConsecutiveLosses;
      config.UseAdaptiveRiskScaling = useAdaptiveRiskScaling;
      config.WinningStreakThreshold = winningStreakThreshold;
      config.WinningStreakMultiplier = winningStreakMultiplier;
      config.UseAISL = useAISL;
      config.PartialClose = partialClose;
      config.RiskReward = riskReward;
      config.PartialClosePercent = partialClosePercent;
      config.UseTrailingStop = useTrailingStop;
      config.TrailingStopPips = trailingStopPips;
      config.TrailingStepPips = trailingStepPips;
      config.CompoundProfits = compoundProfits;
      config.CompoundMultiplier = compoundMultiplier;
      config.Use3TierExits = use3TierExits;
      config.UseVolatilityAdjustment = useVolatilityAdjustment;
      config.VolatilityScaleDown = volatilityScaleDown;
      config.VolatilityScaleUp = volatilityScaleUp;
      config.MaxHoldHours = maxHoldHours;
      
      // Timeframe Settings
      config.StructureTF = structureTF;
      config.HigherTF = higherTF;
      config.MediumTF = mediumTF;
      config.LowerTF = lowerTF;
      config.UseEMATrendFilter = useEMATrendFilter;
      config.EMATrendTF = emaTrendTF;
      
      // Session Filters
      config.TradeLondonOpen = tradeLondonOpen;
      config.TradeNYOpen = tradeNYOpen;
      config.TradeAsianSession = tradeAsianSession;
      config.TradeAllDay = tradeAllDay;
      config.AvoidNews = avoidNews;
      config.NewsMinutesBefore = newsMinutesBefore;
      config.NewsMinutesAfter = newsMinutesAfter;
      
      // Market Structure
      config.SwingValidationBars = swingValidationBars;
      config.MSSThreshold = mssThreshold;
      config.RequireBOS = requireBOS;
      config.RequireCHoCH = requireCHoCH;
      
      // Liquidity Zones
      config.EqualHighLowLookback = equalHighLowLookback;
      config.EqualHighLowTolerance = equalHighLowTolerance;
      config.FVGLookback = fvgLookback;
      config.FVGMinSize = fvgMinSize;
      config.TrackFVGMitigation = trackFVGMitigation;
      
      // Order Blocks
      config.OrderBlockLookback = orderBlockLookback;
      config.RequireOBConfluence = requireOBConfluence;
      config.OBTimeFilter = obTimeFilter;
      config.RequireVolumeConfirmation = requireVolumeConfirmation;
      config.VolumeSpikeMultiplier = volumeSpikeMultiplier;
      config.RequireFVGNearOB = requireFVGNearOB;
      
      // Entry Conditions
      config.MinConfluenceScore = minConfluenceScore;
      config.RequireLiquidityZone = requireLiquidityZone;
      config.RequireOrderBlock = requireOrderBlock;
      config.RequireFVG = requireFVG;
      config.RequireBOSConfirmation = requireBOSConfirmation;
      config.RequireLiquiditySweep = requireLiquiditySweep;
      config.RequireHTFBias = requireHTFBias;
      config.RequireM1MSS = requireM1MSS;
      config.AvoidRangingMarkets = avoidRangingMarkets;
      config.MinTrendStrength = minTrendStrength;
      config.UseMomentumConfirmation = useMomentumConfirmation;
      config.UseTickDivergence = useTickDivergence;
      config.MinMomentumStrength = minMomentumStrength;
      
      // Strategy Settings
      config.UseOB_FVG_Combo = useOB_FVG_Combo;
      config.OB_FVG_MinFVG_Pips = ob_FVG_MinFVG_Pips;
      config.OB_FVG_OBLookback = ob_FVG_OBLookback;
      config.OB_FVG_RetracementMin = ob_FVG_RetracementMin;
      config.OB_FVG_RetracementMax = ob_FVG_RetracementMax;
      config.OB_FVG_QualityMin = ob_FVG_QualityMin;
      
      // Advanced Settings
      config.EnableMarketRegime = enableMarketRegime;
      config.ATRMultiplier = atrMultiplier;
      config.UseSessionBasedATR = useSessionBasedATR;
      config.LondonATRMultiplier = londonATRMultiplier;
      config.NYATRMultiplier = nyATRMultiplier;
      config.OverlapATRMultiplier = overlapATRMultiplier;
      config.AsianATRMultiplier = asianATRMultiplier;
      config.MagicNumber = magicNumber;
      config.TradeComment = tradeComment;
      config.EnableAlerts = enableAlerts;
      config.EnableDrawings = enableDrawings;
      config.EnableDebugLog = enableDebugLog;
      config.EnableDetailedLogging = enableDetailedLogging;
      config.UseCustomRSI = useCustomRSI;
      config.RSIPeriod = rsiPeriod;
      config.UseVolumeProfile = useVolumeProfile;
      config.OptimizeBarProcessing = optimizeBarProcessing;
      config.UseDynamicRisk = useDynamicRisk;
      config.UseKellyCriterion = useKellyCriterion;
      config.KellyFraction = kellyFraction;
      config.UseADXFilter = useADXFilter;
      config.MinADX = minADX;
      config.MaxADXForRanging = maxADXForRanging;
      config.ADXPeriod = adxPeriod;
      config.TrackPerformanceMetrics = trackPerformanceMetrics;
      config.EnableStrategyAdaptation = enableStrategyAdaptation;
      config.AdaptationPeriod = adaptationPeriod;
      config.DecayThreshold = decayThreshold;
      config.UseCorrelationFilter = useCorrelationFilter;
      config.MaxCorrelationRisk = maxCorrelationRisk;
      config.UseOrderFlowAnalysis = useOrderFlowAnalysis;
      config.UseKalmanFilter = useKalmanFilter;
      config.UseEVTRisk = useEVTRisk;
      config.UseFractalRisk = useFractalRisk;
      config.DetectSpoofing = detectSpoofing;
      config.UseDarkPoolDetection = useDarkPoolDetection;
      config.UseLiveGA = useLiveGA;
      config.UseQuantumMetrics = useQuantumMetrics;
      config.UseMillisecondTiming = useMillisecondTiming;
      config.OrderFlowLookback = orderFlowLookback;
      config.KalmanQ = kalmanQ;
      config.KalmanR = kalmanR;
   }
};
