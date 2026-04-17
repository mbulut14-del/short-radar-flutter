import '../models/coin_radar_data.dart';
import '../models/unified_coin_analysis_result.dart';
import '../services/detail_data_service.dart';
import '../services/final_trade_decision_service.dart';

class UnifiedCoinAnalysisService {
  static final Map<String, List<FinalTradeDecision>> _decisionBuffers = {};
  static final Map<String, DateTime?> _lastDecisionTimes = {};
  static final Map<String, FinalTradeDecision?> _lastDisplayDecisions = {};

  static const Duration _dataRefreshInterval = Duration(seconds: 5);
  static const Duration _decisionInterval = Duration(minutes: 3);

  static List<FinalTradeDecision> _decisionBufferFor(String symbol) =>
      _decisionBuffers.putIfAbsent(symbol, () => <FinalTradeDecision>[]);

  static DateTime? _lastDecisionAtFor(String symbol) =>
      _lastDecisionTimes[symbol];

  static void _setLastDecisionAtFor(String symbol, DateTime? value) {
    _lastDecisionTimes[symbol] = value;
  }

  static FinalTradeDecision? _cachedDisplayDecisionFor(String symbol) =>
      _lastDisplayDecisions[symbol];

  static void _setCachedDisplayDecisionFor(
    String symbol,
    FinalTradeDecision? value,
  ) {
    _lastDisplayDecisions[symbol] = value;
  }

  static void _pushDecisionToBuffer(
    String symbol,
    FinalTradeDecision decision,
  ) {
    final List<FinalTradeDecision> buffer = _decisionBufferFor(symbol);
    buffer.add(decision);

    final int maxItems =
        (_decisionInterval.inSeconds ~/ _dataRefreshInterval.inSeconds) + 2;

    while (buffer.length > maxItems) {
      buffer.removeAt(0);
    }
  }

  static double _averageScore(
    List<FinalTradeDecision> decisions,
    double Function(FinalTradeDecision item) getter,
  ) {
    if (decisions.isEmpty) return 0;

    double total = 0;
    for (final item in decisions) {
      total += getter(item);
    }

    return FinalTradeDecisionService.clampScore(total / decisions.length);
  }

  static String _dominantText(
    List<FinalTradeDecision> decisions,
    String Function(FinalTradeDecision item) getter,
  ) {
    if (decisions.isEmpty) return '';

    final Map<String, int> counts = {};
    for (final item in decisions) {
      final String value = getter(item);
      counts[value] = (counts[value] ?? 0) + 1;
    }

    String winner = getter(decisions.last);
    int bestCount = -1;

    counts.forEach((key, value) {
      if (value > bestCount) {
        winner = key;
        bestCount = value;
      }
    });

    return winner;
  }

  static List<String> _mergeUniqueLists({
    required List<String> priorityItems,
    required List<String> secondaryItems,
    int maxItems = 6,
  }) {
    final List<String> merged = [];

    for (final item in [...priorityItems, ...secondaryItems]) {
      if (item.trim().isEmpty) continue;
      if (!merged.contains(item)) {
        merged.add(item);
      }
      if (merged.length >= maxItems) break;
    }

    return merged;
  }

  static String _scoreClassFromScore(double finalScore) {
    if (finalScore >= 85) return 'Güçlü fırsat';
    if (finalScore >= 70) return 'Kurulum var';
    if (finalScore >= 40) return 'İzlenmeli';
    return 'Zayıf';
  }

  static String _buildDecisionSummary({
    required double finalScore,
    required String scoreClass,
    required double confidence,
    required String primarySignal,
    required String tradeBias,
    required String action,
  }) {
    final String scoreText = finalScore.toStringAsFixed(0);
    final String confidenceText = confidence.toStringAsFixed(0);

    return '$scoreClass • Score $scoreText • Confidence $confidenceText% • Signal: $primarySignal • Bias: $tradeBias • Action: $action';
  }

  static FinalTradeDecision _buildBufferedDecision(
    List<FinalTradeDecision> decisions,
  ) {
    final FinalTradeDecision latest = decisions.last;
    final FinalTradeDecision previous =
        decisions.length >= 2 ? decisions[decisions.length - 2] : latest;

    final double averageFinalScore =
        _averageScore(decisions, (item) => item.finalScore);
    final double averageConfidence =
        _averageScore(decisions, (item) => item.confidence);

    final double averageOiScore =
        _averageScore(decisions, (item) => item.oiScore);
    final double averagePriceScore =
        _averageScore(decisions, (item) => item.priceScore);
    final double averageOrderFlowScore =
        _averageScore(decisions, (item) => item.orderFlowScore);
    final double averageVolumeScore =
        _averageScore(decisions, (item) => item.volumeScore);
    final double averageLiquidationScore =
        _averageScore(decisions, (item) => item.liquidationScore);
    final double averageMomentumScore =
        _averageScore(decisions, (item) => item.momentumScore);

    final String dominantBias =
        _dominantText(decisions, (item) => item.tradeBias);
    final String dominantSignal =
        _dominantText(decisions, (item) => item.primarySignal);

    String action = latest.action;

    final bool strongPersistence =
        latest.finalScore >= 80 && previous.finalScore >= 80;
    final bool strongBiasPersistence =
        latest.tradeBias == 'SHORT' && previous.tradeBias == 'SHORT';

    if (action == 'ENTER SHORT' &&
        (!strongPersistence || !strongBiasPersistence)) {
      action = 'PREPARE SHORT';
    }

    final String scoreClass = _scoreClassFromScore(averageFinalScore);

    final List<String> marketReadBullets = _mergeUniqueLists(
      priorityItems: [
        'Karar 3 dakikalık filtrelenmiş veri penceresine göre üretildi.',
        ...latest.marketReadBullets,
      ],
      secondaryItems:
          decisions.length > 2
              ? decisions[decisions.length - 2].marketReadBullets
              : const [],
      maxItems: 7,
    );

    final List<String> warnings = _mergeUniqueLists(
      priorityItems: [
        if (!strongPersistence && dominantBias == 'SHORT')
          'Son iki ölçüm tam güçte hizalanmadı.',
        ...latest.warnings,
      ],
      secondaryItems:
          decisions.length > 2 ? decisions[decisions.length - 2].warnings : const [],
      maxItems: 6,
    );

    final List<String> entryNotes = _mergeUniqueLists(
      priorityItems: [
        'Karar her 5 saniyede değil, 3 dakikalık ortalama akışla güncellenir.',
        ...latest.entryNotes,
      ],
      secondaryItems:
          decisions.length > 2 ? decisions[decisions.length - 2].entryNotes : const [],
      maxItems: 6,
    );

    final List<String> triggerConditions = _mergeUniqueLists(
      priorityItems: latest.triggerConditions,
      secondaryItems:
          decisions.length > 2
              ? decisions[decisions.length - 2].triggerConditions
              : const [],
      maxItems: 5,
    );

    final String summary = _buildDecisionSummary(
      finalScore: averageFinalScore,
      scoreClass: scoreClass,
      confidence: averageConfidence,
      primarySignal: dominantSignal,
      tradeBias: dominantBias,
      action: action,
    );

    return FinalTradeDecision(
      finalScore: averageFinalScore,
      scoreClass: scoreClass,
      confidence: averageConfidence,
      primarySignal: dominantSignal,
      tradeBias: dominantBias,
      action: action,
      summary: summary,
      oiScore: averageOiScore,
      priceScore: averagePriceScore,
      orderFlowScore: averageOrderFlowScore,
      volumeScore: averageVolumeScore,
      liquidationScore: averageLiquidationScore,
      momentumScore: averageMomentumScore,
      marketReadBullets: marketReadBullets,
      entryNotes: entryNotes,
      warnings: warnings,
      triggerConditions: triggerConditions,
    );
  }

  static FinalTradeDecision _resolveDecisionForDisplay(
    String symbol,
    FinalTradeDecision rawDecision,
  ) {
    _pushDecisionToBuffer(symbol, rawDecision);

    final DateTime now = DateTime.now();
    final FinalTradeDecision? cachedDecision =
        _cachedDisplayDecisionFor(symbol);
    final DateTime? lastDecisionAt = _lastDecisionAtFor(symbol);

    if (cachedDecision == null || lastDecisionAt == null) {
      _setLastDecisionAtFor(symbol, now);
      _setCachedDisplayDecisionFor(symbol, rawDecision);
      return rawDecision;
    }

    if (now.difference(lastDecisionAt) < _decisionInterval) {
      return cachedDecision;
    }

    final FinalTradeDecision filteredDecision =
        _buildBufferedDecision(_decisionBufferFor(symbol));

    _setLastDecisionAtFor(symbol, now);
    _setCachedDisplayDecisionFor(symbol, filteredDecision);

    _decisionBufferFor(symbol)
      ..clear()
      ..add(filteredDecision);

    return filteredDecision;
  }

  static Future<UnifiedCoinAnalysisResult> analyze({
    required CoinRadarData coin,
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String orderFlowDirection,
    String selectedInterval = '1h',
    String? combinedSignal,
    String? stableCombinedSignal,
  }) async {
    final bundle = await DetailDataService.load(
      contractName: coin.name,
      selectedInterval: selectedInterval,
      fallbackCoin: coin,
    );

    final FinalTradeDecision rawDecision = FinalTradeDecisionService.build(
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

    final FinalTradeDecision displayDecision = _resolveDecisionForDisplay(
      coin.name,
      rawDecision,
    );

    return UnifiedCoinAnalysisResult(
      coin: bundle.selectedCoin,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      combinedSignal: combinedSignal ?? oiPriceSignal,
      stableCombinedSignal: stableCombinedSignal ?? oiPriceSignal,
      pumpAnalysis: bundle.pumpAnalysis,
      entryTiming: bundle.entryTiming,
      setupResult: bundle.setupResult,
      candles: bundle.visibleCandles,
      rawDecision: rawDecision,
      displayDecision: displayDecision,
    );
  }
}
