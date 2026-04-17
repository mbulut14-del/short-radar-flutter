import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/analysis_engine.dart';

class FinalScoreResult {
  final double score;
  final String label;
  final String summary;

  const FinalScoreResult({
    required this.score,
    required this.label,
    required this.summary,
  });
}

class FinalTradeDecision {
  final double finalScore;
  final String scoreClass;
  final double confidence;
  final String primarySignal;
  final String tradeBias;
  final String action;
  final String summary;

  final double oiScore;
  final double priceScore;
  final double orderFlowScore;
  final double volumeScore;
  final double liquidationScore;
  final double momentumScore;

  final List<String> marketReadBullets;
  final List<String> entryNotes;
  final List<String> warnings;
  final List<String> triggerConditions;

  const FinalTradeDecision({
    required this.finalScore,
    required this.scoreClass,
    required this.confidence,
    required this.primarySignal,
    required this.tradeBias,
    required this.action,
    required this.summary,
    required this.oiScore,
    required this.priceScore,
    required this.orderFlowScore,
    required this.volumeScore,
    required this.liquidationScore,
    required this.momentumScore,
    required this.marketReadBullets,
    required this.entryNotes,
    required this.warnings,
    required this.triggerConditions,
  });

  FinalScoreResult toLegacyScoreResult() {
    return FinalScoreResult(
      score: finalScore,
      label: scoreClass,
      summary: summary,
    );
  }
}

class EntryEngineState {
  bool hadPump;
  bool weaknessSeen;
  bool breakStarted;
  int breakdownConfirmations;
  String phase;
  List<String> reasons;
  double score;

  EntryEngineState({
    this.hadPump = false,
    this.weaknessSeen = false,
    this.breakStarted = false,
    this.breakdownConfirmations = 0,
    this.phase = 'SEARCHING',
    List<String>? reasons,
    this.score = 0,
  }) : reasons = reasons ?? <String>[];

  void reset() {
    hadPump = false;
    weaknessSeen = false;
    breakStarted = false;
    breakdownConfirmations = 0;
    phase = 'SEARCHING';
    reasons = <String>[];
    score = 0;
  }
}

class EntryEngineSnapshot {
  final bool hadPump;
  final bool weaknessSeen;
  final bool breakStarted;
  final int breakdownConfirmations;
  final String phase;
  final double score;
  final List<String> reasons;

  const EntryEngineSnapshot({
    required this.hadPump,
    required this.weaknessSeen,
    required this.breakStarted,
    required this.breakdownConfirmations,
    required this.phase,
    required this.score,
    required this.reasons,
  });
}

class FinalTradeDecisionService {
  static String safeLower(dynamic value) {
    if (value is String) {
      return value.toLowerCase();
    }
    return '';
  }

  static double extractDynamicScore(dynamic source) {
    try {
      final dynamic score = source.score;
      if (score is num) {
        return clampScore(score.toDouble());
      }
    } catch (_) {}
    return 0;
  }

  static String extractDynamicLabel(dynamic source) {
    try {
      final dynamic label = source.label;
      if (label is String) return label;
    } catch (_) {}
    return '';
  }

  static String extractDynamicSignal(dynamic source) {
    try {
      final dynamic signal = source.signal;
      if (signal is String) return signal;
    } catch (_) {}
    return '';
  }

  static String extractDynamicSummary(dynamic source) {
    try {
      final dynamic summary = source.summary;
      if (summary is String) return summary;
    } catch (_) {}
    return '';
  }

  static double clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  // ---- COMPONENTS ----

  static double componentOiScore(String oiDirection) {
    switch (oiDirection) {
      case 'UP':
        return 78;
      case 'DOWN':
        return 34;
      default:
        return 50;
    }
  }

  static double componentPriceScore(String priceDirection, String oiPriceSignal) {
    double score;
    switch (priceDirection) {
      case 'DOWN':
        score = 82;
        break;
      case 'UP':
        score = 38;
        break;
      default:
        score = 55;
        break;
    }

    switch (oiPriceSignal) {
      case 'STRONG_SHORT':
        score += 12;
        break;
      case 'FAKE_PUMP':
        score += 10;
        break;
      case 'WEAK_DROP':
        score += 6;
        break;
      case 'EARLY_DISTRIBUTION':
        score += 4;
        break;
      case 'SHORT_SQUEEZE':
        score -= 20;
        break;
      case 'EARLY_ACCUMULATION':
        score -= 15;
        break;
    }

    return clampScore(score);
  }

  static double componentOrderFlowScore(String orderFlowDirection) {
    switch (orderFlowDirection) {
      case 'SELL_PRESSURE':
        return 88;
      case 'BUY_PRESSURE':
        return 18;
      default:
        return 52;
    }
  }

  static double componentVolumeScore(PumpAnalysisResult? result) {
    if (result == null) return 48;

    final dynamic d = result;
    double score = 46;

    final double rawScore = extractDynamicScore(d);
    if (rawScore > 0) {
      score = 35 + (rawScore * 0.55);
    }

    final String label = safeLower(extractDynamicLabel(d));
    final String signal = safeLower(extractDynamicSignal(d));
    final String summary = safeLower(extractDynamicSummary(d));

    if (label.contains('güçlü')) score += 8;
    if (label.contains('uygun')) score += 6;
    if (label.contains('zayıf')) score -= 10;
    if (label.contains('bekle')) score -= 5;

    if (signal.contains('short')) score += 5;
    if (signal.contains('pump')) score += 4;

    if (summary.contains('hacim')) score += 4;
    if (summary.contains('zayıf')) score -= 4;

    return clampScore(score);
  }

  static double componentLiquidationScore(
    PumpAnalysisResult? pumpAnalysis,
    ShortSetupResult? setupResult,
    String oiPriceSignal,
  ) {
    double score = 50;

    if (oiPriceSignal == 'STRONG_SHORT') score += 12;
    if (oiPriceSignal == 'FAKE_PUMP') score += 8;
    if (oiPriceSignal == 'SHORT_SQUEEZE') score -= 18;
    if (oiPriceSignal == 'EARLY_ACCUMULATION') score -= 10;

    if (pumpAnalysis != null) {
      final String summary = safeLower(extractDynamicSummary(pumpAnalysis));
      final String signal = safeLower(extractDynamicSignal(pumpAnalysis));

      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (signal.contains('pump')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('toplanma')) score -= 6;
    }

    if (setupResult != null) {
      final String summary = safeLower(extractDynamicSummary(setupResult));
      if (summary.contains('squeeze')) score -= 10;
      if (summary.contains('risk')) score -= 6;
      if (summary.contains('uygun')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('birikim')) score -= 8;
    }

    return clampScore(score);
  }

  static double componentMomentumScore(
    EntryTimingResult? entryTiming,
    List<CandleData> candles,
  ) {
    double score = 50;

    if (entryTiming != null) {
      final dynamic d = entryTiming;
      final double rawScore = extractDynamicScore(d);
      final String label = safeLower(extractDynamicLabel(d));
      final String summary = safeLower(extractDynamicSummary(d));

      if (rawScore > 0) {
        score = 35 + (rawScore * 0.55);
      }

      if (label.contains('hazır')) score += 10;
      if (label.contains('uygun')) score += 6;
      if (label.contains('erken')) score += 4;
      if (label.contains('geç')) score -= 12;
      if (label.contains('bekle')) score -= 6;

      if (summary.contains('yakın')) score += 4;
      if (summary.contains('geç')) score -= 8;
      if (summary.contains('bekle')) score -= 4;
    }

    if (candles.length >= 2) {
      final last = candles.last;
      if (last.close < last.open) score += 6;
    }

    return clampScore(score);
  }

  static double weightedFinalScore({
    required double oiScore,
    required double priceScore,
    required double orderFlowScore,
    required double volumeScore,
    required double liquidationScore,
    required double momentumScore,
  }) {
    final double raw =
        (oiScore * 0.20) +
        (priceScore * 0.20) +
        (orderFlowScore * 0.25) +
        (volumeScore * 0.15) +
        (liquidationScore * 0.10) +
        (momentumScore * 0.10);

    return clampScore(raw);
  }

  static String scoreClassFromScore(double finalScore) {
    if (finalScore >= 85) return 'Güçlü fırsat';
    if (finalScore >= 70) return 'Kurulum var';
    if (finalScore >= 40) return 'İzlenmeli';
    return 'Zayıf';
  }

  // ---- MAIN ENTRY ----

  static FinalTradeDecision build({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> candles,
  }) {
    final double oiScore = componentOiScore(oiDirection);
    final double priceScore = componentPriceScore(priceDirection, oiPriceSignal);
    final double orderFlowScore = componentOrderFlowScore(orderFlowDirection);
    final double volumeScore = componentVolumeScore(pumpAnalysis);
    final double liquidationScore = componentLiquidationScore(
      pumpAnalysis,
      setupResult,
      oiPriceSignal,
    );
    final double momentumScore = componentMomentumScore(entryTiming, candles);

    double finalScore = weightedFinalScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
    );

    finalScore = clampScore(finalScore);

    final String scoreClass = scoreClassFromScore(finalScore);

    return FinalTradeDecision(
      finalScore: finalScore,
      scoreClass: scoreClass,
      confidence: 60,
      primarySignal: oiPriceSignal,
      tradeBias: 'SHORT',
      action: 'WATCH',
      summary: '$scoreClass • $finalScore',
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
      marketReadBullets: const [],
      entryNotes: const [],
      warnings: const [],
      triggerConditions: const [],
    );
  }
}
