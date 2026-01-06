//+------------------------------------------------------------------+
//|                                                RiskManager.mqh    |
//|                        Risk Management Class                      |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include <Trade\AccountInfo.mqh>
#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../Indicators/IndicatorWrapper.mqh"

//+------------------------------------------------------------------+
//| Risk Manager - Single Responsibility: Risk Management            |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   string m_symbol;
   CEAConfig* m_config;
   ILogger* m_logger;
   CAccountInfo m_account;
   CATRIndicator* m_atrIndicator;
   
   int m_dailyTrades;
   double m_dailyProfit;
   double m_weeklyProfit;
   double m_monthlyProfit;
   int m_consecutiveLosses;
   int m_consecutiveWins;
   datetime m_lastTradeTime;
   datetime m_weekStartTime;
   datetime m_monthStartTime;
   
public:
   CRiskManager(string symbol, CEAConfig* config, CATRIndicator* atrIndicator, 
                ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
      ResetDailyCounters();
   }
   
   void ResetDailyCounters()
   {
      m_dailyTrades = 0;
      m_dailyProfit = 0.0;
      m_consecutiveLosses = 0;
      m_consecutiveWins = 0;
      m_lastTradeTime = TimeCurrent();
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int dayOfWeek = dt.day_of_week == 0 ? 7 : dt.day_of_week;
      int daysFromMonday = (dayOfWeek == 1) ? 0 : (dayOfWeek - 1);
      m_weekStartTime = TimeCurrent() - (daysFromMonday * 86400);
      m_monthStartTime = StringToTime(IntegerToString(dt.year) + "." + 
                                      IntegerToString(dt.mon) + ".01");
   }
   
   double GetAccountBalance()
   {
      return m_account.Balance();
   }
   
   int GetDailyTrades() { return m_dailyTrades; }
   double GetDailyProfit() { return m_dailyProfit; }
   double GetWeeklyProfit() { return m_weeklyProfit; }
   double GetMonthlyProfit() { return m_monthlyProfit; }
   int GetConsecutiveLosses() { return m_consecutiveLosses; }
   
   void SetDailyTrades(int value) { m_dailyTrades = value; }
   void SetDailyProfit(double value) { m_dailyProfit = value; }
   void SetWeeklyProfit(double value) { m_weeklyProfit = value; }
   void SetMonthlyProfit(double value) { m_monthlyProfit = value; }
   void SetConsecutiveLosses(int value) { m_consecutiveLosses = value; }
   
   bool CanTrade()
   {
      // Check daily trade limit
      if(m_dailyTrades >= m_config.MaxTradesPerDay)
      {
         if(m_logger != NULL)
            m_logger.LogDebug("Max trades per day reached: " + IntegerToString(m_dailyTrades));
         return false;
      }
      
      // Check consecutive losses
      if(m_consecutiveLosses >= m_config.MaxConsecutiveLosses)
      {
         if(m_logger != NULL)
            m_logger.LogWarning("Max consecutive losses reached: " + IntegerToString(m_consecutiveLosses));
         return false;
      }
      
      // Check daily loss limit
      double accountBalance = m_account.Balance();
      double dailyLossPercent = (MathAbs(m_dailyProfit) / accountBalance) * 100.0;
      if(m_dailyProfit < 0 && dailyLossPercent >= m_config.MaxDailyLoss)
      {
         if(m_logger != NULL)
            m_logger.LogWarning("Max daily loss reached: " + DoubleToString(dailyLossPercent, 2) + "%");
         return false;
      }
      
      // Check weekly loss limit
      double weeklyLossPercent = (MathAbs(m_weeklyProfit) / accountBalance) * 100.0;
      if(m_weeklyProfit < 0 && weeklyLossPercent >= m_config.MaxWeeklyLoss)
      {
         if(m_logger != NULL)
            m_logger.LogWarning("Max weekly loss reached: " + DoubleToString(weeklyLossPercent, 2) + "%");
         return false;
      }
      
      // Check monthly loss limit
      double monthlyLossPercent = (MathAbs(m_monthlyProfit) / accountBalance) * 100.0;
      if(m_monthlyProfit < 0 && monthlyLossPercent >= m_config.MaxMonthlyLoss)
      {
         if(m_logger != NULL)
            m_logger.LogWarning("Max monthly loss reached: " + DoubleToString(monthlyLossPercent, 2) + "%");
         return false;
      }
      
      return true;
   }
   
   double CalculateRiskPercent(int confluenceScore)
   {
      double riskPercent = m_config.BaseRiskPerTrade;
      
      if(m_config.UseConfluenceBasedRisk)
      {
         if(confluenceScore >= 9)
            riskPercent *= m_config.HighConfidenceMultiplier;
         else if(confluenceScore >= 7)
            riskPercent *= m_config.MediumConfidenceMultiplier;
      }
      
      if(m_config.UseAdaptiveRiskScaling && m_consecutiveWins >= m_config.WinningStreakThreshold)
      {
         riskPercent *= m_config.WinningStreakMultiplier;
      }
      
      // Cap at max risk
      if(riskPercent > m_config.MaxRiskPerTrade)
         riskPercent = m_config.MaxRiskPerTrade;
      
      return riskPercent;
   }
   
   double CalculateStopLoss(bool isBuy, double entryPrice)
   {
      double atr = m_atrIndicator.GetValue(0);
      double multiplier = m_config.ATRMultiplier;
      
      // Session-based ATR adjustment
      if(m_config.UseSessionBasedATR)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         int hour = dt.hour;
         
         if(hour >= 13 && hour < 16) // London-NY Overlap
            multiplier = m_config.OverlapATRMultiplier;
         else if(hour >= 8 && hour < 10) // London Open
            multiplier = m_config.LondonATRMultiplier;
         else if(hour >= 13 && hour < 15) // NY Open
            multiplier = m_config.NYATRMultiplier;
         else if(hour >= 0 && hour < 8) // Asian Session
            multiplier = m_config.AsianATRMultiplier;
      }
      
      double slDistance = atr * multiplier;
      
      if(isBuy)
         return entryPrice - slDistance;
      else
         return entryPrice + slDistance;
   }
   
   double CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss)
   {
      double slDistance = MathAbs(entryPrice - stopLoss);
      double tpDistance = slDistance * m_config.RiskReward;
      
      if(isBuy)
         return entryPrice + tpDistance;
      else
         return entryPrice - tpDistance;
   }
   
   double CalculateLotSize(double entryPrice, double stopLoss, double riskPercent)
   {
      double accountBalance = m_account.Balance();
      double riskAmount = accountBalance * (riskPercent / 100.0);
      double slDistance = MathAbs(entryPrice - stopLoss);
      
      if(slDistance == 0)
         return 0.0;
      
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      double lotSize = (riskAmount / slDistance) * (point / tickSize) / tickValue;
      
      // Normalize lot size
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      if(lotSize < minLot) lotSize = minLot;
      if(lotSize > maxLot) lotSize = maxLot;
      
      // CRITICAL: Check available margin and reduce lot size if necessary
      double freeMargin = m_account.FreeMargin();
      
      // Use MQL5 OrderCalcMargin for accurate margin calculation
      double marginRequired = 0.0;
      double marginRequiredPerLot = 0.0;
      
      // Calculate margin for BUY order (we'll check both directions)
      if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, lotSize, entryPrice, marginRequired))
      {
         // Fallback to manual calculation if OrderCalcMargin fails
         double contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         double leverage = (double)m_account.Leverage();
         marginRequiredPerLot = (entryPrice * contractSize) / leverage;
         marginRequired = lotSize * marginRequiredPerLot;
      }
      else
      {
         marginRequiredPerLot = marginRequired / lotSize;
      }
      
      // If margin required exceeds free margin, reduce lot size
      if(marginRequired > freeMargin && freeMargin > 0)
      {
         // Calculate maximum lot size based on available margin
         double maxLotByMargin = 0.0;
         
         if(marginRequiredPerLot > 0)
         {
            maxLotByMargin = (freeMargin / marginRequiredPerLot);
            maxLotByMargin = MathFloor(maxLotByMargin / lotStep) * lotStep;
         }
         else
         {
            // Try calculating with OrderCalcMargin for different lot sizes
            double testLot = minLot;
            double testMargin = 0.0;
            while(testLot <= maxLot && testLot <= lotSize)
            {
               if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, testLot, entryPrice, testMargin))
               {
                  if(testMargin <= freeMargin)
                     maxLotByMargin = testLot;
                  else
                     break;
               }
               testLot += lotStep;
            }
         }
         
         if(maxLotByMargin < minLot)
         {
            if(m_logger != NULL)
               m_logger.LogWarning("Insufficient margin. Required: " + DoubleToString(marginRequired, 2) + 
                                  " | Available: " + DoubleToString(freeMargin, 2) + 
                                  " | Calculated lot: " + DoubleToString(lotSize, 2));
            return 0.0; // Cannot open trade
         }
         
         lotSize = maxLotByMargin;
         
         if(m_logger != NULL)
            m_logger.LogWarning("Lot size reduced due to margin: " + DoubleToString(lotSize, 2) + 
                              " (risk-based: " + DoubleToString((riskAmount / slDistance) * (point / tickSize) / tickValue, 2) + 
                              " | Margin available: " + DoubleToString(freeMargin, 2) + ")");
      }
      
      return lotSize;
   }
   
   void OnTradeClosed(double profit)
   {
      m_dailyProfit += profit;
      m_weeklyProfit += profit;
      m_monthlyProfit += profit;
      
      if(profit < 0)
         m_consecutiveLosses++;
      else if(profit > 0)
      {
         m_consecutiveLosses = 0;
         m_consecutiveWins++;
      }
   }
   
   void OnTradeOpened()
   {
      m_dailyTrades++;
   }
};
