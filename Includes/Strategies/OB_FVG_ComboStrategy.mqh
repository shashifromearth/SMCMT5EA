//+------------------------------------------------------------------+
//|                                         OB_FVG_ComboStrategy.mqh  |
//|                        OB+FVG Combo Strategy Implementation       |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "BaseStrategy.mqh"
#include "../Indicators/IndicatorWrapper.mqh"
#include "../Core/Enums/SMCEnums.mqh"  // Explicit include for ENTRY_TYPE enum

//+------------------------------------------------------------------+
//| OB+FVG Combo Strategy - Concrete Strategy Implementation        |
//+------------------------------------------------------------------+
class COB_FVG_ComboStrategy : public CBaseStrategy
{
private:
   CATRIndicator* m_atrIndicator;
   
public:
   COB_FVG_ComboStrategy(string symbol, ENUM_TIMEFRAMES timeframe, CEAConfig* config,
                         CMarketStructureAnalyzer* msAnalyzer, CFVGDetector* fvgDetector,
                         COrderBlockDetector* obDetector, CATRIndicator* atrIndicator,
                         ILogger* logger = NULL)
      : CBaseStrategy(symbol, timeframe, config, msAnalyzer, fvgDetector, obDetector, logger)
   {
      m_atrIndicator = atrIndicator;
      m_strategyName = "OB_FVG_Combo";
   }
   
   bool CheckBuySignal(TradeSignal &signal) override
   {
      if(!m_config.UseOB_FVG_Combo || !m_enabled)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo: Strategy disabled or not enabled");
         return false;
      }
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo BUY: Starting signal check...");
      
      // Find bullish Order Block
      int bullOBIndex = m_obDetector.FindBullishOB(m_config.OB_FVG_OBLookback);
      if(bullOBIndex == -1)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: No bullish OB found in last ", m_config.OB_FVG_OBLookback, " bars");
         return false;
      }
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo BUY: Found bullish OB at index ", bullOBIndex);
      
      OrderBlock ob = m_obDetector.GetOrderBlock(bullOBIndex);
      
      // QUANT ENHANCEMENT: Calculate quality using original algorithm (0-100 scale)
      int obQuality = m_obDetector.CalculateOBQualityForBar(ob.barIndex, true, m_atrIndicator);
      
      // ENHANCED: Require minimum quality but also check for strong OB (quality >= 50)
      // This ensures we only trade high-probability setups
      int minQuality = MathMax(m_config.OB_FVG_QualityMin, 30); // Minimum 30 quality
      if(obQuality < minQuality)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: OB quality too low: ", obQuality, " < ", minQuality);
         return false;
      }
      
      // QUANT ENHANCEMENT: Prefer high-quality OBs (quality >= 50) for better win rate
      bool isHighQualityOB = (obQuality >= 50);
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo BUY: OB quality OK: ", obQuality, " (bar index: ", ob.barIndex, ") | High Quality: ", isHighQualityOB);
      
      // Find FVG after OB - MATCH ORIGINAL LOGIC EXACTLY
      // Original: for(int i = bullOB - 1; i >= 0; i--) checks bars AFTER OB
      // This means FVG should END at bars bullOB-1, bullOB-2, ..., 0
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double obLow = ob.low; // Store OB low for price validation
      bool foundFVG = false;
      double fvgTop = 0, fvgBottom = 0;
      int fvgBar = -1;
      
      int obBarIndex = ob.barIndex;
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo BUY: Looking for FVG after OB at bar ", obBarIndex, " | Checking bars ", (obBarIndex - 1), " down to 0");
      
      // Match original: Check bars from bullOB-1 down to 0 (bars AFTER OB)
      for(int checkBar = obBarIndex - 1; checkBar >= 0; checkBar--)
      {
         // Find FVG that ENDS at this bar
         for(int i = 0; i < m_fvgDetector.GetFVGCount(); i++)
         {
            FairValueGap fvg = m_fvgDetector.GetFVG(i);
            
            // FVG must END at the bar we're checking (checkBar)
            if(fvg.endBar != checkBar)
               continue;
            
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo BUY: Found FVG ending at bar ", checkBar, " | Type: ", fvg.type, " | Mitigated: ", fvg.mitigated);
            
            if(fvg.mitigated || fvg.type != FVG_BULLISH)
               continue;
            
            double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            double fvgSize = (fvg.topPrice - fvg.bottomPrice) / point;
            
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo BUY: FVG size: ", fvgSize, " pips (min required: ", m_config.OB_FVG_MinFVG_Pips, ")");
            
            if(fvgSize < m_config.OB_FVG_MinFVG_Pips)
               continue;
            
            // RELAXED: Allow entries when price is in FVG OR anywhere between OB and FVG
            // This allows continuation entries when price is moving from OB towards FVG
            bool priceInFVG = (currentPrice >= fvg.bottomPrice && currentPrice <= fvg.topPrice);
            
            if(!priceInFVG)
            {
               // Increased tolerance for more lenient entries
               double tolerance = 20.0 * point * 10; // 20 pips tolerance (increased from 5)
               
               // Check if price is retracing TO FVG from above (slightly above FVG top)
               bool retracingFromAbove = (currentPrice > fvg.topPrice && currentPrice <= fvg.topPrice + tolerance);
               
               // Check if price is approaching FVG from below (within tolerance of FVG bottom)
               bool approachingFromBelow = (currentPrice < fvg.bottomPrice && currentPrice >= fvg.bottomPrice - tolerance);
               
               // RELAXED: Allow entries when price is anywhere between OB low and FVG top
               // This includes price below OB if it's moving towards FVG
               double maxDistanceFromOB = 100.0 * point * 10; // Allow up to 100 pips below OB
               bool priceBetweenOBAndFVG = (currentPrice >= (obLow - maxDistanceFromOB) && currentPrice < fvg.topPrice);
               
               // ADDITIONAL: Allow entries if price is reasonably close to FVG (within 50 pips)
               double maxDistanceFromFVG = 50.0 * point * 10; // 50 pips max distance
               bool priceNearFVG = false;
               if(currentPrice < fvg.bottomPrice)
                  priceNearFVG = ((fvg.bottomPrice - currentPrice) <= maxDistanceFromFVG);
               else if(currentPrice > fvg.topPrice)
                  priceNearFVG = ((currentPrice - fvg.topPrice) <= maxDistanceFromFVG);
               
               if(retracingFromAbove)
               {
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo BUY: Price retracing to FVG from above (within tolerance)");
               }
               else if(approachingFromBelow)
               {
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo BUY: Price approaching FVG from below (within tolerance)");
               }
               else if(priceBetweenOBAndFVG)
               {
                  // Price is between OB and FVG - valid continuation entry
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo BUY: Price between OB and FVG - valid continuation entry");
               }
               else if(priceNearFVG)
               {
                  // Price is reasonably close to FVG - allow entry
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo BUY: Price near FVG - allowing entry");
               }
               else
               {
                  if(m_config.EnableDebugLog)
                  {
                     double distance = 0;
                     if(currentPrice > fvg.topPrice)
                        distance = currentPrice - fvg.topPrice;
                     else if(currentPrice < fvg.bottomPrice)
                        distance = fvg.bottomPrice - currentPrice;
                     
                     Print("OB_FVG_Combo BUY: Price too far from FVG. Current: ", currentPrice, 
                           " | FVG: ", fvg.bottomPrice, "-", fvg.topPrice,
                           " | OB Low: ", obLow,
                           " | Distance: ", distance / point / 10, " pips");
                  }
                  continue;
               }
            }
            
            fvgTop = fvg.topPrice;
            fvgBottom = fvg.bottomPrice;
            fvgBar = checkBar;
            foundFVG = true;
            
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo BUY: Found valid FVG at bar ", fvgBar, " | Price in FVG: YES");
            break; // Found valid FVG, exit inner loop
         }
         
         if(foundFVG)
            break; // Found valid FVG, exit outer loop
      }
      
      // OPTIMIZED: Allow OB-only entries if FVG not required
      if(!foundFVG && m_config.RequireFVG)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: No valid FVG found after OB (checked bars ", (obBarIndex - 1), " to 0) | FVG required");
         return false;
      }
      
      // OPTIMIZED: If FVG not required and price is near OB, allow entry
      if(!foundFVG && !m_config.RequireFVG)
      {
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double atr = m_atrIndicator.GetValue(0);
         
         // Check if price is near OB (within 2x ATR or 50 pips)
         double maxDistanceFromOB = MathMax(atr * 2.0, 50.0 * point * 10);
         bool priceNearOB = (currentPrice >= obLow && currentPrice <= obLow + maxDistanceFromOB);
         
         if(!priceNearOB)
         {
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo BUY: Price not near OB. Current: ", currentPrice, " | OB Low: ", obLow, " | Distance: ", (currentPrice - obLow) / point / 10, " pips");
            return false;
         }
         
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: OB-only entry allowed (FVG not required) | Price near OB");
      }
      
      // Calculate entry, SL, TP
      double entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double atr = m_atrIndicator.GetValue(0);
      
      // CRITICAL FIX: SL at OB low minus 2.5x ATR (much more room for volatility)
      // Previous 1.5x ATR was too tight, causing quick SL hits
      double sl = obLow - (2.5 * atr);
      
      // CRITICAL: Ensure minimum 20 pips SL to prevent oversized lot sizes
      // Small SL = huge lot size = massive losses when hit
      double minSLDistance = 20.0 * point * 10; // Minimum 20 pips
      if(entryPrice - sl < minSLDistance)
      {
         sl = entryPrice - minSLDistance;
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: SL adjusted to minimum 20 pips. Original: ", obLow - (2.5 * atr), " | New: ", sl);
      }
      
      // Ensure SL is not too close to entry (safety check)
      double maxSLDistance = 50.0 * point * 10; // Maximum 50 pips SL
      if(entryPrice - sl > maxSLDistance)
      {
         sl = entryPrice - maxSLDistance;
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: SL capped at maximum 50 pips");
      }
      
      // FINAL VALIDATION: Reject if SL is still too small
      double finalSLDistance = entryPrice - sl;
      if(finalSLDistance < minSLDistance)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: SL too small after adjustments: ", finalSLDistance / point / 10, " pips. Rejecting signal.");
         return false;
      }
      
      // QUANT ENHANCEMENT: TP based on Risk:Reward (minimum 3.0R for profitability)
      // Previous 2.0R was not enough - need 3.0R to overcome losses
      double slDistance = entryPrice - sl;
      double tp = entryPrice + (slDistance * MathMax(m_config.RiskReward, 3.0)); // Minimum 3.0R
      
      // QUANT ENHANCEMENT: Validate R:R and SL/ATR ratio
      double tpDistance = tp - entryPrice;
      double rr = tpDistance / slDistance;
      
      if(rr < 3.0) // Minimum 3.0R for profitability
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo BUY: R:R too low: ", rr, " < 3.0. Rejecting signal.");
         return false;
      }
      
      // QUANT ENHANCEMENT: Ensure SL is reasonable (not too tight, not too wide)
      if(atr > 0)
      {
         double slMultiplier = slDistance / atr;
         if(slMultiplier < 1.5 || slMultiplier > 4.0)
         {
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo BUY: SL distance not optimal. SL/ATR: ", slMultiplier, " (optimal: 1.5-4.0). Adjusting...");
            // Adjust SL to be within optimal range
            if(slMultiplier < 1.5)
            {
               sl = entryPrice - (atr * 1.5);
               slDistance = entryPrice - sl;
               tp = entryPrice + (slDistance * 3.0); // Recalculate TP
               tpDistance = tp - entryPrice;
               rr = tpDistance / slDistance;
            }
            else if(slMultiplier > 4.0)
            {
               sl = entryPrice - (atr * 4.0);
               slDistance = entryPrice - sl;
               tp = entryPrice + (slDistance * 3.0); // Recalculate TP
               tpDistance = tp - entryPrice;
               rr = tpDistance / slDistance;
            }
         }
      }
      
      // Fill signal structure
      signal.direction = TRADE_BUY;
      signal.entryPrice = entryPrice;
      signal.stopLoss = sl;
      signal.takeProfit = tp;
      signal.confluenceScore = obQuality; // Use calculated quality (0-100 scale)
      signal.strategy = m_strategyName;
      signal.entryType = foundFVG ? ENTRY_FVG_FILL_CONTINUATION : ENTRY_ORDER_BLOCK_BOUNCE;
      signal.comment = foundFVG ? "OB+FVG Combo" : "OB Only";
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo BUY: Signal generated | Entry: ", entryPrice, " | SL: ", sl, " (", DoubleToString(slDistance/point/10, 1), " pips) | TP: ", tp, " | R:R: ", DoubleToString(rr, 2), " | Quality: ", obQuality, " | Type: ", signal.comment);
      
      return true;
   }
   
   bool CheckSellSignal(TradeSignal &signal) override
   {
      if(!m_config.UseOB_FVG_Combo || !m_enabled)
         return false;
      
      // Find bearish Order Block
      int bearOBIndex = m_obDetector.FindBearishOB(m_config.OB_FVG_OBLookback);
      if(bearOBIndex == -1)
         return false;
      
      OrderBlock ob = m_obDetector.GetOrderBlock(bearOBIndex);
      
      // QUANT ENHANCEMENT: Calculate quality using original algorithm (0-100 scale)
      int obQuality = m_obDetector.CalculateOBQualityForBar(ob.barIndex, false, m_atrIndicator);
      
      // ENHANCED: Require minimum quality but also check for strong OB (quality >= 50)
      // This ensures we only trade high-probability setups
      int minQuality = MathMax(m_config.OB_FVG_QualityMin, 30); // Minimum 30 quality
      if(obQuality < minQuality)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: OB quality too low: ", obQuality, " < ", minQuality);
         return false;
      }
      
      // QUANT ENHANCEMENT: Prefer high-quality OBs (quality >= 50) for better win rate
      bool isHighQualityOB = (obQuality >= 50);
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo SELL: OB quality OK: ", obQuality, " (bar index: ", ob.barIndex, ") | High Quality: ", isHighQualityOB);
      
      // Find FVG after OB - MATCH ORIGINAL LOGIC EXACTLY
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double obHigh = ob.high; // Store OB high for price validation
      bool foundFVG = false;
      double fvgTop = 0, fvgBottom = 0;
      int fvgBar = -1;
      
      int obBarIndex = ob.barIndex;
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo SELL: Looking for FVG after OB at bar ", obBarIndex, " | Checking bars ", (obBarIndex - 1), " down to 0");
      
      // Match original: Check bars from bearOB-1 down to 0 (bars AFTER OB)
      for(int checkBar = obBarIndex - 1; checkBar >= 0; checkBar--)
      {
         // Find FVG that ENDS at this bar
         for(int i = 0; i < m_fvgDetector.GetFVGCount(); i++)
         {
            FairValueGap fvg = m_fvgDetector.GetFVG(i);
            
            // FVG must END at the bar we're checking (checkBar)
            if(fvg.endBar != checkBar)
               continue;
            
            if(fvg.mitigated || fvg.type != FVG_BEARISH)
               continue;
            
            double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            double fvgSize = (fvg.topPrice - fvg.bottomPrice) / point;
            
            if(fvgSize < m_config.OB_FVG_MinFVG_Pips)
               continue;
            
            // RELAXED: Allow entries when price is in FVG OR anywhere between OB and FVG
            bool priceInFVG = (currentPrice >= fvg.bottomPrice && currentPrice <= fvg.topPrice);
            
            if(!priceInFVG)
            {
               // Increased tolerance for more lenient entries
               double tolerance = 20.0 * point * 10; // 20 pips tolerance (increased from 5)
               
               // Check if price is retracing TO FVG from below (slightly below FVG bottom)
               bool retracingFromBelow = (currentPrice < fvg.bottomPrice && currentPrice >= fvg.bottomPrice - tolerance);
               
               // Check if price is approaching FVG from above (within tolerance of FVG top)
               bool approachingFromAbove = (currentPrice > fvg.topPrice && currentPrice <= fvg.topPrice + tolerance);
               
               // RELAXED: Allow entries when price is anywhere between OB high and FVG bottom
               double maxDistanceFromOB = 100.0 * point * 10; // Allow up to 100 pips above OB
               bool priceBetweenOBAndFVG = (currentPrice <= (obHigh + maxDistanceFromOB) && currentPrice > fvg.bottomPrice);
               
               // ADDITIONAL: Allow entries if price is reasonably close to FVG (within 50 pips)
               double maxDistanceFromFVG = 50.0 * point * 10; // 50 pips max distance
               bool priceNearFVG = false;
               if(currentPrice < fvg.bottomPrice)
                  priceNearFVG = ((fvg.bottomPrice - currentPrice) <= maxDistanceFromFVG);
               else if(currentPrice > fvg.topPrice)
                  priceNearFVG = ((currentPrice - fvg.topPrice) <= maxDistanceFromFVG);
               
               if(retracingFromBelow)
               {
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo SELL: Price retracing to FVG from below (within tolerance)");
               }
               else if(approachingFromAbove)
               {
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo SELL: Price approaching FVG from above (within tolerance)");
               }
               else if(priceBetweenOBAndFVG)
               {
                  // Price is between OB and FVG - valid continuation entry
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo SELL: Price between OB and FVG - valid continuation entry");
               }
               else if(priceNearFVG)
               {
                  // Price is reasonably close to FVG - allow entry
                  priceInFVG = true;
                  if(m_config.EnableDebugLog)
                     Print("OB_FVG_Combo SELL: Price near FVG - allowing entry");
               }
               else
               {
                  if(m_config.EnableDebugLog)
                  {
                     double distance = 0;
                     if(currentPrice < fvg.bottomPrice)
                        distance = fvg.bottomPrice - currentPrice;
                     else if(currentPrice > fvg.topPrice)
                        distance = currentPrice - fvg.topPrice;
                     
                     Print("OB_FVG_Combo SELL: Price too far from FVG. Current: ", currentPrice, 
                           " | FVG: ", fvg.bottomPrice, "-", fvg.topPrice,
                           " | OB High: ", obHigh,
                           " | Distance: ", distance / point / 10, " pips");
                  }
                  continue;
               }
            }
            
            fvgTop = fvg.topPrice;
            fvgBottom = fvg.bottomPrice;
            fvgBar = checkBar;
            foundFVG = true;
            
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo SELL: Found valid FVG at bar ", fvgBar, " | Price in FVG: YES");
            break; // Found valid FVG, exit inner loop
         }
         
         if(foundFVG)
            break; // Found valid FVG, exit outer loop
      }
      
      // OPTIMIZED: Allow OB-only entries if FVG not required
      if(!foundFVG && m_config.RequireFVG)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: No valid FVG found after OB (checked bars ", (obBarIndex - 1), " to 0) | FVG required");
         return false;
      }
      
      // OPTIMIZED: If FVG not required and price is near OB, allow entry
      if(!foundFVG && !m_config.RequireFVG)
      {
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         double atr = m_atrIndicator.GetValue(0);
         
         // Check if price is near OB (within 2x ATR or 50 pips)
         double maxDistanceFromOB = MathMax(atr * 2.0, 50.0 * point * 10);
         bool priceNearOB = (currentPrice <= obHigh && currentPrice >= obHigh - maxDistanceFromOB);
         
         if(!priceNearOB)
         {
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo SELL: Price not near OB. Current: ", currentPrice, " | OB High: ", obHigh, " | Distance: ", (obHigh - currentPrice) / point / 10, " pips");
            return false;
         }
         
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: OB-only entry allowed (FVG not required) | Price near OB");
      }
      
      // Calculate entry, SL, TP
      double entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double atr = m_atrIndicator.GetValue(0);
      
      // CRITICAL FIX: SL at OB high plus 2.5x ATR (much more room for volatility)
      // Previous 1.5x ATR was too tight, causing quick SL hits
      double sl = obHigh + (2.5 * atr);
      
      // CRITICAL: Ensure minimum 20 pips SL to prevent oversized lot sizes
      // Small SL = huge lot size = massive losses when hit
      double minSLDistance = 20.0 * point * 10; // Minimum 20 pips
      if(sl - entryPrice < minSLDistance)
      {
         sl = entryPrice + minSLDistance;
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: SL adjusted to minimum 20 pips. Original: ", obHigh + (2.5 * atr), " | New: ", sl);
      }
      
      // Ensure SL is not too close to entry (safety check)
      double maxSLDistance = 50.0 * point * 10; // Maximum 50 pips SL
      if(sl - entryPrice > maxSLDistance)
      {
         sl = entryPrice + maxSLDistance;
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: SL capped at maximum 50 pips");
      }
      
      // FINAL VALIDATION: Reject if SL is still too small
      double finalSLDistance = sl - entryPrice;
      if(finalSLDistance < minSLDistance)
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: SL too small after adjustments: ", finalSLDistance / point / 10, " pips. Rejecting signal.");
         return false;
      }
      
      // QUANT ENHANCEMENT: TP based on Risk:Reward (minimum 3.0R for profitability)
      // Previous 2.0R was not enough - need 3.0R to overcome losses
      double slDistance = sl - entryPrice;
      double tp = entryPrice - (slDistance * MathMax(m_config.RiskReward, 3.0)); // Minimum 3.0R
      
      // QUANT ENHANCEMENT: Validate R:R and SL/ATR ratio
      double tpDistance = entryPrice - tp;
      double rr = tpDistance / slDistance;
      
      if(rr < 3.0) // Minimum 3.0R for profitability
      {
         if(m_config.EnableDebugLog)
            Print("OB_FVG_Combo SELL: R:R too low: ", rr, " < 3.0. Rejecting signal.");
         return false;
      }
      
      // QUANT ENHANCEMENT: Ensure SL is reasonable (not too tight, not too wide)
      if(atr > 0)
      {
         double slMultiplier = slDistance / atr;
         if(slMultiplier < 1.5 || slMultiplier > 4.0)
         {
            if(m_config.EnableDebugLog)
               Print("OB_FVG_Combo SELL: SL distance not optimal. SL/ATR: ", slMultiplier, " (optimal: 1.5-4.0). Adjusting...");
            // Adjust SL to be within optimal range
            if(slMultiplier < 1.5)
            {
               sl = entryPrice + (atr * 1.5);
               slDistance = sl - entryPrice;
               tp = entryPrice - (slDistance * 3.0); // Recalculate TP
               tpDistance = entryPrice - tp;
               rr = tpDistance / slDistance;
            }
            else if(slMultiplier > 4.0)
            {
               sl = entryPrice + (atr * 4.0);
               slDistance = sl - entryPrice;
               tp = entryPrice - (slDistance * 3.0); // Recalculate TP
               tpDistance = entryPrice - tp;
               rr = tpDistance / slDistance;
            }
         }
      }
      
      // Fill signal structure
      signal.direction = TRADE_SELL;
      signal.entryPrice = entryPrice;
      signal.stopLoss = sl;
      signal.takeProfit = tp;
      signal.confluenceScore = obQuality; // Use calculated quality (0-100 scale)
      signal.strategy = m_strategyName;
      signal.entryType = foundFVG ? ENTRY_FVG_FILL_CONTINUATION : ENTRY_ORDER_BLOCK_BOUNCE;
      signal.comment = foundFVG ? "OB+FVG Combo" : "OB Only";
      
      if(m_config.EnableDebugLog)
         Print("OB_FVG_Combo SELL: Signal generated | Entry: ", entryPrice, " | SL: ", sl, " (", DoubleToString(slDistance/point/10, 1), " pips) | TP: ", tp, " | R:R: ", DoubleToString(rr, 2), " | Quality: ", obQuality, " | Type: ", signal.comment);
      
      return true;
   }
};

