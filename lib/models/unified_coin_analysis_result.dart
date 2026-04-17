import 'candle_data.dart';
import 'coin_radar_data.dart';
import 'entry_timing_result.dart';
import 'pump_analysis_result.dart';
import 'short_setup_result.dart';
import '../services/final_trade_decision_service.dart';

class UnifiedCoinAnalysisResult {
  final CoinRadarData coin;

  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;

  final String combinedSignal;
  final String stableCombinedSignal;

  final PumpAnalysisResult? pumpAnalysis;
  final EntryTimingResult? entryTiming;
  final ShortSetupResult? setupResult;
  final List<CandleData> candles;

  final FinalTradeDecision rawDecision;
  final FinalTradeDecision displayDecision;

  const UnifiedCoinAnalysisResult({
    required this.coin,
    required this.oiDirection,
    required this.priceDirection,
    required this.oiPriceSignal,
    required this.orderFlowDirection,
    required this.combinedSignal,
    required this.stableCombinedSignal,
    required this.pumpAnalysis,
    required this.entryTiming,
    required this.setupResult,
    required this.candles,
    required this.rawDecision,
    required this.displayDecision,
  });

  int get score => displayDecision.finalScore.round();
  String get scoreClass => displayDecision.scoreClass;
  String get summary => displayDecision.summary;
}
