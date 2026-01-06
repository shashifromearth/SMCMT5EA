//+------------------------------------------------------------------+
//|                                                  BaseStrategy.mqh |
//|                        Base Strategy Class                        |
//+------------------------------------------------------------------+
#property copyright "SMC Pro Scalper EA"
#property version   "2.0"

#include "IStrategy.mqh"
#include "../Config/EAConfig.mqh"
#include "../Core/Base/ILogger.mqh"
#include "../MarketStructure/MarketStructureAnalyzer.mqh"
#include "../MarketStructure/FVGDetector.mqh"
#include "../MarketStructure/OrderBlockDetector.mqh"

//+------------------------------------------------------------------+
//| Base Strategy Class - Open/Closed Principle                     |
//+------------------------------------------------------------------+
class CBaseStrategy : public IStrategy
{
protected:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CEAConfig* m_config;
   ILogger* m_logger;
   CMarketStructureAnalyzer* m_msAnalyzer;
   CFVGDetector* m_fvgDetector;
   COrderBlockDetector* m_obDetector;
   bool m_enabled;
   string m_strategyName;
   
public:
   CBaseStrategy(string symbol, ENUM_TIMEFRAMES timeframe, CEAConfig* config,
                 CMarketStructureAnalyzer* msAnalyzer, CFVGDetector* fvgDetector,
                 COrderBlockDetector* obDetector, ILogger* logger = NULL)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_config = config;
      m_logger = logger;
      m_msAnalyzer = msAnalyzer;
      m_fvgDetector = fvgDetector;
      m_obDetector = obDetector;
      m_enabled = true;
   }
   
   virtual bool CheckBuySignal(TradeSignal &signal) { return false; }
   virtual bool CheckSellSignal(TradeSignal &signal) { return false; }
   virtual string GetStrategyName() { return m_strategyName; }
   virtual bool IsEnabled() { return m_enabled; }
   
   void SetEnabled(bool enabled) { m_enabled = enabled; }
};

