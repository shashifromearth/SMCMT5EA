//+------------------------------------------------------------------+
//|                                          MomentumAnalyzer.mqh    |
//|                        Momentum Analysis Class                    |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "IndicatorWrapper.mqh"

//+------------------------------------------------------------------+
//| Momentum Analyzer - Analyzes price momentum                       |
//+------------------------------------------------------------------+
class CMomentumAnalyzer
{
private:
   string m_symbol;
   CEAConfig* m_config;
   CATRIndicator* m_atrIndicator;
   ILogger* m_logger;
   
public:
   CMomentumAnalyzer(string symbol, CEAConfig* config, CATRIndicator* atrIndicator, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_config = config;
      m_atrIndicator = atrIndicator;
      m_logger = logger;
   }
   
   bool CheckStrongMomentum(bool isBuy)
   {
      if(m_atrIndicator == NULL || m_config == NULL)
         return false;
      
      double atr = m_atrIndicator.GetValue(0);
      if(atr <= 0)
         return false;
      
      double close0 = iClose(m_symbol, m_config.LowerTF, 0);
      double close3 = iClose(m_symbol, m_config.LowerTF, 3);
      
      if(isBuy)
         return (close0 - close3) > (atr * 1.5);
      else
         return (close3 - close0) > (atr * 1.5);
   }
};

