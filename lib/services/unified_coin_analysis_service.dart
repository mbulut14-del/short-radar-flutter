
import '../models/coin_radar_data.dart';
import '../models/unified_coin_analysis_result.dart';
import '../services/detail_data_service.dart';
import '../services/final_trade_decision_service.dart';

class UnifiedCoinAnalysisService {
  // 🔥 Geçici: şimdilik sadece mevcut Home mantığını sarıyoruz
  static Future<UnifiedCoinAnalysisResult> analyze({
    required CoinRadarData coin,
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String orderFlowDirection,
  }) async {
    final bundle = await DetailDataService.load(
      contractName: coin.name,
      selectedInterval: '1h',
      fallbackCoin: coin,
    );

    final rawDecision = FinalTradeDecisionService.build(
      symbol: coin.name,
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      pumpAnalysis: bundle.pumpAnalysis,
      entryTiming: bundle.entryTiming,
      setupResult: bundle.setupResult,
      candles: bundle.visibleCandles,
    );

    // 🔥 Şimdilik display = raw (ileride 3dk buffer eklenecek)
    final displayDecision = rawDecision;

    return UnifiedCoinAnalysisResult(
      coin: coin,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      combinedSignal: oiPriceSignal,
      stableCombinedSignal: oiPriceSignal,
      pumpAnalysis: bundle.pumpAnalysis,
      entryTiming: bundle.entryTiming,
      setupResult: bundle.setupResult,
      candles: bundle.visibleCandles,
      rawDecision: rawDecision,
      displayDecision: displayDecision,
    );
  }
}
