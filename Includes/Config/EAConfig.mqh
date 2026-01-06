//+------------------------------------------------------------------+
//|                                                   EAConfig.mqh    |
//|                        EA Configuration Management                |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

//+------------------------------------------------------------------+
//| EA Configuration Class - Single Responsibility: Configuration   |
//+------------------------------------------------------------------+
class CEAConfig
{
public:
   // Risk Management
   double BaseRiskPerTrade;
   double MaxRiskPerTrade;
   double HighConfidenceRisk; // PROFIT OPTIMIZED: Separate risk for A+ setups
   bool UseConfluenceBasedRisk;
   double HighConfidenceMultiplier;
   double MediumConfidenceMultiplier;
   bool UseKellyCriterion; // PROFIT OPTIMIZED: Enable Kelly Criterion
   double KellyFraction; // PROFIT OPTIMIZED: Kelly fraction (0.1-0.25)
   double MaxDailyLoss;
   double MaxWeeklyLoss;
   double MaxMonthlyLoss;
   int MaxTradesPerDay;
   int MaxConsecutiveLosses;
   bool UseAdaptiveRiskScaling;
   int WinningStreakThreshold;
   double WinningStreakMultiplier;
   bool UseAISL;
   bool PartialClose;
   double RiskReward;
   double PartialClosePercent;
   bool UseTrailingStop;
   double TrailingStopPips;
   double TrailingStepPips;
   bool CompoundProfits;
   double CompoundMultiplier;
   bool Use3TierExits;
   bool UseVolatilityAdjustment;
   double VolatilityScaleDown;
   double VolatilityScaleUp;
   int MaxHoldHours;
   
   // Timeframe Settings
   ENUM_TIMEFRAMES StructureTF;
   ENUM_TIMEFRAMES HigherTF;
   ENUM_TIMEFRAMES MediumTF;
   ENUM_TIMEFRAMES LowerTF;
   bool UseEMATrendFilter;
   ENUM_TIMEFRAMES EMATrendTF;
   
   // Session Filters
   bool TradeLondonOpen;
   bool TradeNYOpen;
   bool TradeLondonNYOverlap; // PROFIT OPTIMIZED: Focus on overlap only
   bool TradeAsianSession;
   bool TradeAllDay;
   bool AvoidNews;
   int NewsMinutesBefore;
   int NewsMinutesAfter;
   
   // Market Structure
   int SwingValidationBars;
   double MSSThreshold;
   bool RequireBOS;
   bool RequireCHoCH;
   
   // Liquidity Zones
   int EqualHighLowLookback;
   double EqualHighLowTolerance;
   int FVGLookback;
   double FVGMinSize;
   bool TrackFVGMitigation;
   
   // Order Blocks
   int OrderBlockLookback;
   bool RequireOBConfluence;
   int OBTimeFilter;
   bool RequireVolumeConfirmation;
   double VolumeSpikeMultiplier;
   bool RequireFVGNearOB;
   
   // Entry Conditions
   int MinConfluenceScore;
   bool RequireLiquidityZone;
   bool RequireOrderBlock;
   bool RequireFVG;
   bool RequireBOSConfirmation;
   // RequireCHoCH is already declared in Market Structure section (line 67)
   bool RequireLiquiditySweep;
   bool RequireHTFBias;
   bool RequireM1MSS;
   bool AvoidRangingMarkets;
   double MinTrendStrength;
   bool UseMomentumConfirmation;
   bool UseTickDivergence;
   double MinMomentumStrength;
   bool UseMarketRegimeFilter; // PROFIT OPTIMIZED: Enable market regime filter
   double MinVolatilityPercent; // PROFIT OPTIMIZED: Minimum volatility requirement
   
   // Strategy Settings
   bool UseOB_FVG_Combo;
   double OB_FVG_MinFVG_Pips;
   int OB_FVG_OBLookback;
   double OB_FVG_RetracementMin;
   double OB_FVG_RetracementMax;
   int OB_FVG_QualityMin;
   
   bool UseLiquidityGrab_FVG;
   double LG_FVG_SweepBuffer;
   double LG_FVG_ReversalConfirmation;
   int LG_FVG_Lookback;
   
   bool UseBOS_Retest;
   double BOS_Retest_Tolerance;
   int BOS_Retest_Lookback;
   
   bool UseOB_CHOCH;
   bool OB_CHOCH_RequireMSS;
   double OB_CHOCH_PullbackMax;
   
   bool UseFVG_Mitigation;
   double FVG_Mitigation_FillPercent;
   int FVG_Mitigation_Lookback;
   
   bool UseEqualHL_Traps;
   int EqualHL_Traps_MinTouches;
   double EqualHL_Traps_MomentumThreshold;
   
   // Advanced Settings
   bool EnableMarketRegime;
   double ATRMultiplier;
   bool UseSessionBasedATR;
   double LondonATRMultiplier;
   double NYATRMultiplier;
   double OverlapATRMultiplier;
   double AsianATRMultiplier;
   int MagicNumber;
   string TradeComment;
   bool EnableAlerts;
   bool EnableDrawings;
   bool EnableDebugLog;
   bool EnableDetailedLogging;
   bool UseCustomRSI;
   int RSIPeriod;
   bool UseVolumeProfile;
   bool OptimizeBarProcessing;
   bool UseDynamicRisk;
   // UseKellyCriterion and KellyFraction are already declared in Risk Management section (lines 21-22)
   bool UseADXFilter;
   double MinADX;
   double MaxADXForRanging;
   int ADXPeriod;
   bool TrackPerformanceMetrics;
   bool EnableStrategyAdaptation;
   int AdaptationPeriod;
   double DecayThreshold;
   bool UseCorrelationFilter;
   double MaxCorrelationRisk;
   bool UseOrderFlowAnalysis;
   bool UseKalmanFilter;
   bool UseEVTRisk;
   bool UseFractalRisk;
   bool DetectSpoofing;
   bool UseDarkPoolDetection;
   bool UseLiveGA;
   bool UseQuantumMetrics;
   bool UseMillisecondTiming;
   int OrderFlowLookback;
   double KalmanQ;
   double KalmanR;
   
   // Constructor - Initialize from input parameters
   CEAConfig()
   {
      InitializeFromInputs();
   }
   
   // Validate configuration
   bool Validate()
   {
      if(BaseRiskPerTrade <= 0 || BaseRiskPerTrade > 10)
         return false;
      if(RiskReward < 1.0)
         return false;
      if(MagicNumber <= 0)
         return false;
      return true;
   }
   
private:
   void InitializeFromInputs()
   {
      // This will be populated from the main EA file's input parameters
      // For now, set defaults - actual values will be passed from main EA
   }
};

