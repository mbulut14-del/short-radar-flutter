import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../models/unified_coin_analysis_result.dart';
import '../services/analysis_engine.dart';
import '../services/detail_data_service.dart';
import '../services/final_trade_decision_service.dart';

class UnifiedCoinAnalysisService {
  static final Map<String, List<FinalTradeDecision>> _decisionBuffers = {};
  static final Map<String, DateTime?> _lastDecisionTimes = {};
  static final Map<String, FinalTradeDecision?> _lastDisplayDecisions = {};
  static final Map<String, EntryEngineState> _entryEngineStates = {};

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

  static EntryEngineState _entryEngineStateFor(String symbol) =>
      _entryEngineStates.putIfAbsent(symbol, () => EntryEngineState());

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

  static String _extractDynamicLabel(dynamic source) {
    try {
      final dynamic label = source.label;
      if (label is String) return label;
    } catch (_) {}
    return '';
  }

  static String _extractDynamicSummary(dynamic source) {
    try {
      final dynamic summary = source.summary;
      if (summary is String) return summary;
    } catch (_) {}
    return '';
  }

  static String _extractDynamicSignal(dynamic source) {
    try {
      final dynamic signal = source.signal;
      if (signal is String) return signal;
    } catch (_) {}
    return '';
  }

  static double _componentOiScore(String oiDirection) {
    switch (oiDirection) {
      case 'UP':
        return 78;
      case 'DOWN':
        return 34;
      default:
        return 50;
    }
  }

  static double _componentPriceScore(
    String priceDirection,
    String oiPriceSignal,
  ) {
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
      default:
        break;
    }

    return FinalTradeDecisionService.clampScore(score);
  }

  static double _componentOrderFlowScore(String orderFlowDirection) {
    switch (orderFlowDirection) {
      case 'SELL_PRESSURE':
        return 88;
      case 'BUY_PRESSURE':
        return 18;
      default:
        return 52;
    }
  }

  static double _componentVolumeScore(PumpAnalysisResult? result) {
    if (result == null) return 48;

    final dynamic dynamicResult = result;
    double score = 46;

    final double rawScore =
        FinalTradeDecisionService.extractDynamicScore(dynamicResult);
    if (rawScore > 0) {
      score = 35 + (rawScore * 0.55);
    }

    final String label =
        FinalTradeDecisionService.safeLower(_extractDynamicLabel(dynamicResult));
    final String signal =
        FinalTradeDecisionService.safeLower(_extractDynamicSignal(dynamicResult));
    final String summary =
        FinalTradeDecisionService.safeLower(
          _extractDynamicSummary(dynamicResult),
        );

    if (label.contains('güçlü')) score += 8;
    if (label.contains('uygun')) score += 6;
    if (label.contains('zayıf')) score -= 10;
    if (label.contains('bekle')) score -= 5;

    if (signal.contains('short')) score += 5;
    if (signal.contains('pump')) score += 4;

    if (summary.contains('hacim')) score += 4;
    if (summary.contains('zayıf')) score -= 4;

    return FinalTradeDecisionService.clampScore(score);
  }

  static double _componentLiquidationScore(
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
      final String summary = FinalTradeDecisionService.safeLower(
        _extractDynamicSummary(pumpAnalysis),
      );
      final String signal = FinalTradeDecisionService.safeLower(
        _extractDynamicSignal(pumpAnalysis),
      );

      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (signal.contains('pump')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('toplanma')) score -= 6;
    }

    if (setupResult != null) {
      final String summary = FinalTradeDecisionService.safeLower(
        _extractDynamicSummary(setupResult),
      );
      if (summary.contains('squeeze')) score -= 10;
      if (summary.contains('risk')) score -= 6;
      if (summary.contains('uygun')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('birikim')) score -= 8;
    }

    return FinalTradeDecisionService.clampScore(score);
  }

  static double _componentMomentumScore(
    EntryTimingResult? entryTiming,
    List<CandleData> candleList,
  ) {
    double score = 50;

    if (entryTiming != null) {
      final dynamic dynamicResult = entryTiming;
      final double rawScore =
          FinalTradeDecisionService.extractDynamicScore(dynamicResult);
      final String label = FinalTradeDecisionService.safeLower(
        _extractDynamicLabel(dynamicResult),
      );
      final String summary = FinalTradeDecisionService.safeLower(
        _extractDynamicSummary(dynamicResult),
      );

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

    if (candleList.length >= 3) {
      final CandleData last = candleList.last;
      final CandleData prev = candleList[candleList.length - 2];
      final CandleData prev2 = candleList[candleList.length - 3];

      if (last.close < last.open) score += 6;
      if (prev.close < prev.open) score += 4;
      if (prev2.close < prev2.open) score += 3;

      final double range = (last.high - last.low).abs();
      if (range > 0) {
        final double upperWick =
            last.high - (last.open > last.close ? last.open : last.close);
        final double upperWickRatio = upperWick / range;
        if (upperWickRatio >= 0.35) score += 7;
      }
    }

    return FinalTradeDecisionService.clampScore(score);
  }

  static double _bodySize(CandleData candle) {
    return (candle.close - candle.open).abs();
  }

  static double _rangeSize(CandleData candle) {
    return (candle.high - candle.low).abs();
  }

  static double _upperWickSize(CandleData candle) {
    final double bodyTop =
        candle.close >= candle.open ? candle.close : candle.open;
    return candle.high - bodyTop;
  }

  static bool _hasBigUpperWick(CandleData candle, {double minRatio = 0.35}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    return (_upperWickSize(candle) / range) >= minRatio;
  }

  static bool _hasWeakClose(CandleData candle, {double maxCloseRatio = 0.60}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    final double closePosition = (candle.close - candle.low) / range;
    return closePosition <= maxCloseRatio;
  }

  static bool _hasVolumeExpansion(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];

    final double avgPrevVolume = (prev.volume + prev2.volume + prev3.volume) / 3;
    if (avgPrevVolume <= 0) return false;

    return last.volume >= avgPrevVolume * 1.15;
  }

  static Map<String, dynamic> _detectPriceStructure(List<CandleData> candles) {
    if (candles.length < 6) {
      return {
        'detected': false,
        'score': 0.0,
        'label': 'NONE',
        'reasons': <String>[],
      };
    }

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];
    final CandleData prev4 = candles[candles.length - 5];

    double score = 0;
    final List<String> reasons = [];

    final double baseClose = prev4.close;
    final double topHigh = prev.high;
    final double lastClose = last.close;

    if (baseClose > 0) {
      final double pumpPct = ((topHigh - baseClose) / baseClose) * 100;
      if (pumpPct >= 6) {
        score += 28;
        reasons.add('Öncesinde güçlü pump var.');
      } else if (pumpPct >= 4) {
        score += 20;
        reasons.add('Öncesinde anlamlı yükseliş var.');
      } else if (pumpPct >= 2.5) {
        score += 10;
        reasons.add('Kısa vadede yukarı şişme görülüyor.');
      }
    }

    final int greenCount = [
      prev4.close > prev4.open,
      prev3.close > prev3.open,
      prev2.close > prev2.open,
      prev.close > prev.open,
    ].where((e) => e).length;

    if (greenCount >= 3) {
      score += 12;
      reasons.add('Seri yeşil mumlarla yukarı taşınmış.');
    }

    if (_hasBigUpperWick(prev, minRatio: 0.35) &&
        _hasWeakClose(prev, maxCloseRatio: 0.62)) {
      score += 22;
      reasons.add('Tepe mumunda belirgin üst wick / exhaustion var.');
    } else if (_hasBigUpperWick(last, minRatio: 0.35) &&
        _hasWeakClose(last, maxCloseRatio: 0.62)) {
      score += 18;
      reasons.add('Son mumda yukarı reddedilme var.');
    }

    if (_hasVolumeExpansion(candles)) {
      score += 10;
      reasons.add('Hacim genişlemesi eşlik ediyor.');
    }

    if (last.close < last.open) {
      score += 8;
      reasons.add('Son mum kırmızı kapanmış.');
    }

    if (last.high < prev.high) {
      score += 8;
      reasons.add('Lower high oluşumu başladı.');
    }

    if (_bodySize(prev) > 0 &&
        _bodySize(last) > _bodySize(prev) * 1.05 &&
        last.close < last.open) {
      score += 8;
      reasons.add('Dönüş mumu gövde olarak güçleniyor.');
    }

    final double triggerLow = prev2.low < prev3.low ? prev2.low : prev3.low;
    if (triggerLow > 0 && lastClose < triggerLow) {
      score += 14;
      reasons.add('Önceki destek altına sarkma var.');
    }

    score = score.clamp(0, 100).toDouble();

    String label = 'NONE';
    if (score >= 70) {
      label = 'EARLY_SHORT_STRONG';
    } else if (score >= 50) {
      label = 'EARLY_SHORT';
    } else if (score >= 35) {
      label = 'WEAK_TOP_FORMING';
    }

    return {
      'detected': score >= 50,
      'score': score,
      'label': label,
      'reasons': reasons,
    };
  }

  static Map<String, dynamic> _detectFirstBreak(List<CandleData> candles) {
    if (candles.length < 5) {
      return {
        'detected': false,
        'score': 0.0,
        'label': 'NONE',
        'reasons': <String>[],
      };
    }

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];
    final CandleData prev4 = candles[candles.length - 5];

    double score = 0;
    final List<String> reasons = [];

    final double baseClose = prev4.close;
    if (baseClose > 0) {
      final double pumpPct = ((prev.high - baseClose) / baseClose) * 100;
      if (pumpPct >= 6) {
        score += 18;
        reasons.add('Kırılma öncesi güçlü pump var.');
      } else if (pumpPct >= 3.5) {
        score += 12;
        reasons.add('Kırılma öncesi anlamlı yükseliş var.');
      }
    }

    if (_hasBigUpperWick(prev, minRatio: 0.40)) {
      score += 24;
      reasons.add('Önceki mumda güçlü üst wick oluştu.');
    }

    if (_hasWeakClose(prev, maxCloseRatio: 0.50)) {
      score += 18;
      reasons.add('Önceki mum zayıf kapanış yaptı.');
    }

    final double prevAvgVolume =
        (prev2.volume + prev3.volume + prev4.volume) / 3;
    if (prevAvgVolume > 0 && prev.volume >= prevAvgVolume * 1.20) {
      score += 14;
      reasons.add('Red mumunda hacim genişledi.');
    }

    if (last.high < prev.high) {
      score += 14;
      reasons.add('Son mum lower high üretiyor.');
    }

    if (last.close < last.open) {
      score += 8;
      reasons.add('Son mum kırmızı baskı gösteriyor.');
    }

    final double prevMid = prev.low + (_rangeSize(prev) * 0.5);
    if (last.close < prevMid) {
      score += 10;
      reasons.add('Son kapanış önceki mumun orta bandı altında.');
    }

    if (_bodySize(last) > 0 &&
        _bodySize(prev) > 0 &&
        _bodySize(last) >= _bodySize(prev) * 0.85 &&
        last.close < last.open) {
      score += 8;
      reasons.add('Satıcı gövdesi zayıflamıyor.');
    }

    score = score.clamp(0, 100).toDouble();

    String label = 'NONE';
    if (score >= 80) {
      label = 'FIRST_BREAK_STRONG';
    } else if (score >= 60) {
      label = 'FIRST_BREAK';
    } else if (score >= 40) {
      label = 'EARLY_WEAKENING';
    }

    return {
      'detected': score >= 60,
      'score': score,
      'label': label,
      'reasons': reasons,
    };
  }

  static bool _detectPumpNow(List<CandleData> candles) {
    if (candles.length < 5) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev4 = candles[candles.length - 5];

    if (prev4.close <= 0) return false;

    final double risePct = ((last.high - prev4.close) / prev4.close) * 100;
    final int greenCount = [
      candles[candles.length - 5].close > candles[candles.length - 5].open,
      candles[candles.length - 4].close > candles[candles.length - 4].open,
      candles[candles.length - 3].close > candles[candles.length - 3].open,
      candles[candles.length - 2].close > candles[candles.length - 2].open,
    ].where((e) => e).length;

    return risePct >= 4.0 && greenCount >= 3;
  }

  static bool _detectWeaknessNow(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    final bool prevReject =
        _hasBigUpperWick(prev, minRatio: 0.35) &&
        _hasWeakClose(prev, maxCloseRatio: 0.58);
    final bool lastReject =
        _hasBigUpperWick(last, minRatio: 0.35) &&
        _hasWeakClose(last, maxCloseRatio: 0.58);
    final bool lowerHigh = last.high < prev.high;
    final bool redPressure = last.close < last.open;

    return prevReject || (lastReject && lowerHigh) || (lowerHigh && redPressure);
  }

  static bool _detectBreakdownNow(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];

    final bool lowerHigh = last.high < prev.high;
    final bool weakClose = _hasWeakClose(last, maxCloseRatio: 0.55);
    final bool redBody = last.close < last.open;
    final double support = prev2.low < prev3.low ? prev2.low : prev3.low;
    final bool supportBreak = support > 0 && last.close < support;
    final bool belowPrevMid = last.close < (prev.low + (_rangeSize(prev) * 0.5));

    return (lowerHigh && redBody && weakClose) ||
        (lowerHigh && belowPrevMid) ||
        supportBreak;
  }

  static bool _detectRecoveryInvalidation(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    final bool strongGreenRecovery =
        last.close > last.open &&
        _bodySize(last) > 0 &&
        _bodySize(last) >= _rangeSize(last) * 0.45;
    final bool reclaimedPrevHigh = last.close > prev.high;
    final bool strongCloseNearHigh = !_hasWeakClose(last, maxCloseRatio: 0.75);

    return strongGreenRecovery && reclaimedPrevHigh && strongCloseNearHigh;
  }

  static EntryEngineSnapshot _evaluateEntryEngine(
    String symbol,
    List<CandleData> candles,
  ) {
    final EntryEngineState state = _entryEngineStateFor(symbol);

    if (candles.length < 5) {
      state.reset();
      return EntryEngineSnapshot(
        hadPump: false,
        weaknessSeen: false,
        breakStarted: false,
        breakdownConfirmations: 0,
        phase: 'SEARCHING',
        score: 0,
        reasons: const <String>[],
      );
    }

    final bool pumpNow = _detectPumpNow(candles);
    final bool weaknessNow = _detectWeaknessNow(candles);
    final bool breakdownNow = _detectBreakdownNow(candles);
    final bool invalidated = _detectRecoveryInvalidation(candles);

    final List<String> reasons = [];

    if (invalidated) {
      state.reset();
      state.phase = 'INVALIDATED';
      state.reasons = <String>[
        'Kırılma denemesi sonrası güçlü yukarı toparlama geldi.',
      ];
      state.score = 18;
      return EntryEngineSnapshot(
        hadPump: state.hadPump,
        weaknessSeen: state.weaknessSeen,
        breakStarted: state.breakStarted,
        breakdownConfirmations: state.breakdownConfirmations,
        phase: state.phase,
        score: state.score,
        reasons: List<String>.from(state.reasons),
      );
    }

    if (pumpNow) {
      state.hadPump = true;
      state.phase = 'PUMP_TRACKING';
      reasons.add('Önce güçlü pump tespit edildi.');
    }

    if (state.hadPump && weaknessNow) {
      state.weaknessSeen = true;
      state.phase = 'WEAKNESS_TRACKING';
      reasons.add('Pump sonrası ilk zayıflama başladı.');
    }

    if (state.hadPump && state.weaknessSeen && breakdownNow) {
      state.breakStarted = true;
      state.breakdownConfirmations += 1;
      state.phase = 'BREAK_READY';
      reasons.add('İlk kırılma başladı.');
      if (state.breakdownConfirmations >= 2) {
        reasons.add('Kırılma ikinci kez teyit aldı.');
      }
    } else if (!breakdownNow && state.breakdownConfirmations > 0) {
      state.breakdownConfirmations = 1;
    }

    if (!state.hadPump && !pumpNow) {
      state.phase = 'SEARCHING';
      state.reasons = <String>[];
      state.score = 0;
      return EntryEngineSnapshot(
        hadPump: state.hadPump,
        weaknessSeen: state.weaknessSeen,
        breakStarted: state.breakStarted,
        breakdownConfirmations: state.breakdownConfirmations,
        phase: state.phase,
        score: state.score,
        reasons: List<String>.from(state.reasons),
      );
    }

    double score = 0;

    if (state.hadPump) score += 26;
    if (state.weaknessSeen) score += 24;
    if (state.breakStarted) score += 26;
    if (state.breakdownConfirmations >= 2) score += 12;

    if (pumpNow) score += 6;
    if (weaknessNow) score += 8;
    if (breakdownNow) score += 12;

    score = FinalTradeDecisionService.clampScore(score);

    if (reasons.isEmpty) {
      if (state.phase == 'PUMP_TRACKING') {
        reasons.add('Pump izleniyor, zayıflama bekleniyor.');
      } else if (state.phase == 'WEAKNESS_TRACKING') {
        reasons.add('İlk zayıflama izlendi, kırılma teyidi bekleniyor.');
      } else if (state.phase == 'BREAK_READY') {
        reasons.add('Entry engine kırılma modunda.');
      }
    }

    state.score = score;
    state.reasons = reasons;

    return EntryEngineSnapshot(
      hadPump: state.hadPump,
      weaknessSeen: state.weaknessSeen,
      breakStarted: state.breakStarted,
      breakdownConfirmations: state.breakdownConfirmations,
      phase: state.phase,
      score: state.score,
      reasons: List<String>.from(state.reasons),
    );
  }

  static String _determineTradeBias({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required bool structureDetected,
    required double structureScore,
    required bool firstBreakDetected,
    required double firstBreakScore,
    required EntryEngineSnapshot entryEngine,
  }) {
    if (oiPriceSignal == 'STRONG_SHORT' ||
        oiPriceSignal == 'FAKE_PUMP' ||
        oiPriceSignal == 'WEAK_DROP' ||
        oiPriceSignal == 'EARLY_DISTRIBUTION') {
      return 'SHORT';
    }

    int shortVotes = 0;
    int neutralPenalty = 0;

    if (oiDirection == 'UP') {
      shortVotes += 1;
    } else if (oiDirection == 'DOWN') {
      neutralPenalty += 1;
    }

    if (priceDirection == 'DOWN') {
      shortVotes += 2;
    } else if (priceDirection == 'UP') {
      neutralPenalty += 2;
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      shortVotes += 2;
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      neutralPenalty += 2;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      neutralPenalty += 3;
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') {
      neutralPenalty += 3;
    }

    if (structureDetected) {
      shortVotes += structureScore >= 70 ? 3 : 2;
    }

    if (firstBreakDetected) {
      shortVotes += firstBreakScore >= 80 ? 3 : 2;
    }

    if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      shortVotes += 2;
    } else if (entryEngine.phase == 'BREAK_READY') {
      shortVotes += entryEngine.breakdownConfirmations >= 2 ? 4 : 3;
    } else if (entryEngine.phase == 'INVALIDATED') {
      neutralPenalty += 3;
    }

    if (shortVotes >= 3 && shortVotes > neutralPenalty) {
      return 'SHORT';
    }

    return 'NEUTRAL';
  }

  static double _weightedFinalScore({
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

    return FinalTradeDecisionService.clampScore(raw);
  }

  static double _confidenceScore({
    required double oiScore,
    required double priceScore,
    required double orderFlowScore,
    required double volumeScore,
    required double liquidationScore,
    required double momentumScore,
    required String tradeBias,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required String oiPriceSignal,
  }) {
    double confidence = 58;

    final bool shortAligned =
        tradeBias == 'SHORT' &&
        (priceDirection == 'DOWN' || oiPriceSignal == 'FAKE_PUMP') &&
        orderFlowDirection == 'SELL_PRESSURE';

    if (shortAligned) {
      confidence += 16;
    }

    final List<double> scores = [
      oiScore,
      priceScore,
      orderFlowScore,
      volumeScore,
      liquidationScore,
      momentumScore,
    ]..sort();

    final double spread = scores.last - scores.first;

    if (spread <= 20) {
      confidence += 8;
    } else if (spread <= 35) {
      confidence += 4;
    } else if (spread >= 55) {
      confidence -= 10;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      confidence -= 20;
    }

    if (orderFlowDirection == 'BUY_PRESSURE') {
      confidence -= 16;
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') {
      confidence -= 14;
    }

    if (tradeBias == 'SHORT' && oiDirection == 'UP') {
      confidence += 4;
    }

    if (tradeBias == 'NEUTRAL') {
      confidence -= 12;
    }

    return FinalTradeDecisionService.clampScore(confidence);
  }

  static String _actionFromDecision({
    required double finalScore,
    required double confidence,
    required String tradeBias,
    required String oiPriceSignal,
    required String priceDirection,
    required String orderFlowDirection,
    required bool structureDetected,
    required double structureScore,
    required bool firstBreakDetected,
    required double firstBreakScore,
    required EntryEngineSnapshot entryEngine,
  }) {
    if (entryEngine.phase == 'INVALIDATED') {
      return 'WATCH';
    }

    if (priceDirection == 'UP' && orderFlowDirection == 'BUY_PRESSURE') {
      return 'WATCH';
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION') {
      return 'WATCH';
    }

    if (oiPriceSignal == 'NEUTRAL' &&
        entryEngine.phase != 'BREAK_READY' &&
        !firstBreakDetected) {
      return 'WATCH';
    }

    if (entryEngine.phase == 'BREAK_READY' &&
        entryEngine.breakdownConfirmations >= 2 &&
        tradeBias == 'SHORT' &&
        confidence >= 60) {
      if (priceDirection == 'UP' ||
          orderFlowDirection == 'BUY_PRESSURE' ||
          oiPriceSignal == 'NEUTRAL') {
        return 'PREPARE SHORT';
      }
      return 'ENTER SHORT';
    }

    if (entryEngine.phase == 'BREAK_READY' && tradeBias == 'SHORT') {
      return 'PREPARE SHORT';
    }

    if (firstBreakScore >= 80 && tradeBias == 'SHORT') {
      if (priceDirection == 'UP' ||
          orderFlowDirection == 'BUY_PRESSURE' ||
          oiPriceSignal == 'NEUTRAL') {
        return 'PREPARE SHORT';
      }
      return 'ENTER SHORT';
    }

    if (finalScore < 40) {
      return 'NO TRADE';
    }

    if (tradeBias != 'SHORT') {
      return finalScore >= 40 ? 'WATCH' : 'NO TRADE';
    }

    if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      return 'WATCH';
    }

    if (firstBreakDetected && firstBreakScore >= 60) {
      return finalScore >= 70 ? 'PREPARE SHORT' : 'WATCH';
    }

    if (finalScore < 70) {
      return structureDetected && structureScore >= 70
          ? 'PREPARE SHORT'
          : 'WATCH';
    }

    if (finalScore < 85) {
      if (confidence < 60) {
        return structureDetected && structureScore >= 70
            ? 'PREPARE SHORT'
            : 'WATCH';
      }
      return 'PREPARE SHORT';
    }

    if (confidence < 68) {
      return 'WATCH';
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION' ||
        oiPriceSignal == 'NEUTRAL' ||
        priceDirection == 'UP' ||
        orderFlowDirection == 'BUY_PRESSURE') {
      return 'PREPARE SHORT';
    }

    return 'ENTER SHORT';
  }

  static List<String> _buildMarketReadBullets({
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String orderFlowDirection,
    required double volumeScore,
    required double momentumScore,
    required bool structureDetected,
    required double structureScore,
    required List<String> structureReasons,
    required bool firstBreakDetected,
    required double firstBreakScore,
    required List<String> firstBreakReasons,
    required EntryEngineSnapshot entryEngine,
  }) {
    final List<String> bullets = [];

    if (oiDirection == 'UP') {
      bullets.add('Open interest artıyor, piyasaya yeni pozisyon girişi var.');
    } else if (oiDirection == 'DOWN') {
      bullets.add('Open interest düşüyor, pozisyon çözülmesi görülüyor.');
    } else {
      bullets.add('Open interest tarafı yatay, güçlü yön teyidi sınırlı.');
    }

    if (priceDirection == 'DOWN') {
      bullets.add('Fiyat aşağı yönlü baskı gösteriyor.');
    } else if (priceDirection == 'UP') {
      bullets.add(
        'Fiyat yukarı gidiyor, short tarafı için risk oluşturabilir.',
      );
    } else {
      bullets.add('Fiyat yatay seyirde, net kırılım henüz gelmemiş olabilir.');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      bullets.add('Order flow satış baskısını destekliyor.');
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      bullets.add(
        'Order flow alıcı baskısını gösteriyor; short için ters rüzgar var.',
      );
    } else {
      bullets.add('Order flow tarafında belirgin üstünlük yok.');
    }

    switch (oiPriceSignal) {
      case 'STRONG_SHORT':
        bullets.add('OI + fiyat yapısı güçlü short senaryosuna işaret ediyor.');
        break;
      case 'FAKE_PUMP':
        bullets.add('Yukarı hareket trap olabilir, fake pump ihtimali var.');
        break;
      case 'WEAK_DROP':
        bullets.add('Düşüş var ama henüz tam kuvvetli görünmüyor.');
        break;
      case 'EARLY_DISTRIBUTION':
        bullets.add(
          'Erken dağıtım sinyali short lehine öncü işaret olabilir.',
        );
        break;
      case 'EARLY_ACCUMULATION':
        bullets.add(
          'Erken toplama sinyali var; short tarafı için negatif filtre oluşuyor.',
        );
        break;
      case 'SHORT_SQUEEZE':
        bullets.add(
          'Kısa pozisyonlar sıkışıyor olabilir; short açmak için risk yüksek.',
        );
        break;
      default:
        bullets.add('Ana sinyal nötr bölgede, ek teyit gerekiyor.');
        break;
    }

    if (entryEngine.phase == 'PUMP_TRACKING') {
      bullets.add('Entry engine pump fazını hafızaya aldı.');
    } else if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      bullets.add('Entry engine ilk zayıflamayı yakaladı, kırılma bekliyor.');
    } else if (entryEngine.phase == 'BREAK_READY') {
      bullets.add(
        'Entry engine kırılma fazında; girişe en yakın bölge izleniyor.',
      );
    } else if (entryEngine.phase == 'INVALIDATED') {
      bullets.add('Entry engine önceki kırılma fikrini geçersiz saydı.');
    }

    for (final reason in entryEngine.reasons.take(2)) {
      bullets.add(reason);
    }

    if (firstBreakDetected) {
      if (firstBreakScore >= 80) {
        bullets.add('İlk kırılma motoru güçlü şekilde tetiklendi.');
      } else {
        bullets.add('İlk kırılma motoru erken short zayıflaması yakaladı.');
      }
    } else if (firstBreakScore >= 40) {
      bullets.add('İlk kırılma belirtileri oluşuyor ama henüz tam teyit yok.');
    }

    if (structureDetected) {
      if (structureScore >= 70) {
        bullets.add(
          'Price structure tarafında güçlü tepe / exhaustion oluşumu var.',
        );
      } else {
        bullets.add('Price structure tarafında erken short yapısı beliriyor.');
      }
    } else if (structureScore >= 35) {
      bullets.add('Yapısal olarak tepe oluşumu başlayabilir ama teyit henüz zayıf.');
    }

    for (final reason in firstBreakReasons.take(2)) {
      bullets.add(reason);
    }

    for (final reason in structureReasons.take(2)) {
      bullets.add(reason);
    }

    if (volumeScore >= 70) {
      bullets.add('Hacim tarafı hareketi destekliyor.');
    } else if (volumeScore <= 40) {
      bullets.add('Hacim teyidi zayıf, hareket güven vermiyor.');
    }

    if (momentumScore >= 72) {
      bullets.add('Momentum kurulum lehine güçleniyor.');
    } else if (momentumScore <= 40) {
      bullets.add('Momentum tarafı zayıf, giriş acele olabilir.');
    }

    return bullets;
  }

  static List<String> _buildWarnings({
    required String tradeBias,
    required String oiPriceSignal,
    required String orderFlowDirection,
    required double confidence,
    required double volumeScore,
    required double liquidationScore,
    required double momentumScore,
    required bool structureDetected,
    required bool firstBreakDetected,
    required EntryEngineSnapshot entryEngine,
  }) {
    final List<String> warnings = [];

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      warnings.add('Short squeeze riski var.');
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') {
      warnings.add('Erken birikim sinyali short girişini zayıflatıyor.');
    }

    if (tradeBias == 'SHORT' && orderFlowDirection == 'BUY_PRESSURE') {
      warnings.add('Short bias ile order flow çelişiyor.');
    }

    if (!structureDetected) {
      warnings.add('Geçmiş fiyat yapısı henüz güçlü tepe teyidi vermiyor.');
    }

    if (!firstBreakDetected && entryEngine.phase != 'BREAK_READY') {
      warnings.add('İlk kırılma motoru henüz tam tetik vermedi.');
    }

    if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      warnings.add('Zayıflama var ama breakdown teyidi henüz eksik.');
    }

    if (entryEngine.phase == 'INVALIDATED') {
      warnings.add('Önceki kırılma denemesi yukarı toparlama ile bozuldu.');
    }

    if (confidence < 60) {
      warnings.add('Sinyal uyumu düşük.');
    }

    if (volumeScore < 45) {
      warnings.add('Hacim teyidi zayıf.');
    }

    if (liquidationScore < 45) {
      warnings.add('Likidasyon desteği sınırlı.');
    }

    if (momentumScore < 45) {
      warnings.add('Momentum zayıf.');
    }

    return warnings;
  }

  static List<String> _buildEntryNotes({
    required String tradeBias,
    required String action,
    required double confidence,
    required String oiPriceSignal,
    required EntryTimingResult? entryTiming,
    required bool structureDetected,
    required double structureScore,
    required List<String> structureReasons,
    required bool firstBreakDetected,
    required double firstBreakScore,
    required List<String> firstBreakReasons,
    required EntryEngineSnapshot entryEngine,
  }) {
    final List<String> notes = [];

    if (action == 'ENTER SHORT') {
      notes.add('Kurulum güçlü; agresif short giriş düşünülebilir.');
      notes.add('Stop bölgesi son yukarı wick üstü izlenebilir.');
    } else if (action == 'PREPARE SHORT') {
      notes.add('Short hazırlığı var; tetik için ek fiyat teyidi beklenmeli.');
      notes.add('Zayıflayan mum yapısı gelirse giriş kalitesi artar.');
    } else if (action == 'WATCH') {
      notes.add('Şimdilik izleme modunda kalmak daha doğru.');
    } else {
      notes.add('Mevcut görüntü short işlemi için yeterli kalite üretmiyor.');
    }

    if (entryEngine.phase == 'PUMP_TRACKING') {
      notes.add('Engine pumpı hafızaya aldı; şimdi zayıflama arıyor.');
    } else if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      notes.add('İlk zayıflama görüldü; ilk kırılma teyidi gelmeden acele etme.');
    } else if (entryEngine.phase == 'BREAK_READY') {
      if (entryEngine.breakdownConfirmations >= 2) {
        notes.add('Stateful entry engine iki aşamalı kırılma teyidi aldı.');
      } else {
        notes.add(
          'Stateful entry engine kırılma başlattı; continuation beklenmeli.',
        );
      }
    } else if (entryEngine.phase == 'INVALIDATED') {
      notes.add('Yukarı toparlama geldiği için önceki setup bozuldu.');
    }

    if (firstBreakDetected) {
      if (firstBreakScore >= 80) {
        notes.add('İlk kırılma motoru giriş anına çok yakın görüntü üretiyor.');
      } else {
        notes.add(
          'İlk kırılma başladı; tam breakdown teyidi gelirse giriş kalitesi artar.',
        );
      }
    }

    if (firstBreakReasons.isNotEmpty) {
      notes.add(firstBreakReasons.first);
    }

    if (structureDetected) {
      if (structureScore >= 70) {
        notes.add('Geçmiş price structure güçlü tepe oluşumunu destekliyor.');
      } else {
        notes.add('Erken short yapısı oluşuyor olabilir; teyidi acele etmeden bekle.');
      }
    }

    if (structureReasons.isNotEmpty) {
      notes.add(structureReasons.first);
    }

    if (oiPriceSignal == 'FAKE_PUMP') {
      notes.add('Yukarı spike sonrası zayıflama short için tetik olabilir.');
    }

    if (oiPriceSignal == 'EARLY_DISTRIBUTION') {
      notes.add(
        'Erken dağıtım sinyali nedeniyle sabırlı bekleme avantajlı olabilir.',
      );
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') {
      notes.add('Alıcı tarafı erken üstünlük kuruyor olabilir; short için acele etme.');
    }

    if (confidence < 60) {
      notes.add('Sinyaller tam hizalanmadığı için pozisyon boyutu küçük tutulmalı.');
    }

    if (entryTiming != null) {
      final String label = FinalTradeDecisionService.safeLower(
        _extractDynamicLabel(entryTiming),
      );
      if (label.contains('geç')) {
        notes.add('Giriş geç kalmış olabilir; FOMO ile işlem açma.');
      } else if (label.contains('erken')) {
        notes.add('Kurulum erken aşamada olabilir; net tetik beklemek mantıklı.');
      } else if (label.contains('hazır')) {
        notes.add('Entry timing tarafı short girişine daha yakın görünüyor.');
      }
    }

    if (tradeBias != 'SHORT') {
      notes.add('Sistem şu an short yönünde net üstünlük görmüyor.');
    }

    return notes;
  }

  static List<String> _buildTriggerConditions({
    required String tradeBias,
    required String oiPriceSignal,
    required String priceDirection,
    required String orderFlowDirection,
    required bool structureDetected,
    required bool firstBreakDetected,
    required EntryEngineSnapshot entryEngine,
  }) {
    final List<String> triggers = [];

    if (tradeBias == 'SHORT') {
      if (entryEngine.phase == 'WEAKNESS_TRACKING') {
        triggers.add('Weakness sonrası yeni lower high oluşması');
      }
      if (entryEngine.phase == 'BREAK_READY') {
        triggers.add('Kırılma sonrası continuation mumu');
      }
      if (firstBreakDetected) {
        triggers.add('İlk kırılma sonrası zayıf kapanışın devam etmesi');
      }
      triggers.add('Zayıf kapanış veya breakdown teyidi');
      triggers.add('Satış baskısının devam etmesi');
      if (priceDirection == 'UP' || oiPriceSignal == 'FAKE_PUMP') {
        triggers.add('Yukarı fitil sonrası reddedilme');
      }
      if (structureDetected) {
        triggers.add('Tepe bölgesinden gelen lower high yapısının sürmesi');
      }
    } else {
      triggers.add('Net short yön teyidi');
      triggers.add('Order flow tarafında satış baskısının belirginleşmesi');
      triggers.add('Alıcı baskısının zayıflaması');
    }

    return triggers;
  }

  static FinalTradeDecision _buildRealTradeDecision({
    required String symbol,
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> visibleCandles,
  }) {
    final Map<String, dynamic> structureResult =
        _detectPriceStructure(visibleCandles);
    final bool structureDetected = structureResult['detected'] == true;
    final double structureScore =
        ((structureResult['score'] ?? 0) as num).toDouble();
    final List<String> structureReasons =
        List<String>.from(structureResult['reasons'] ?? const []);

    final Map<String, dynamic> firstBreakResult =
        _detectFirstBreak(visibleCandles);
    final bool firstBreakDetected = firstBreakResult['detected'] == true;
    final double firstBreakScore =
        ((firstBreakResult['score'] ?? 0) as num).toDouble();
    final List<String> firstBreakReasons =
        List<String>.from(firstBreakResult['reasons'] ?? const []);

    final EntryEngineSnapshot entryEngine =
        _evaluateEntryEngine(symbol, visibleCandles);

    final double oiScore = _componentOiScore(oiDirection);
    final double priceScore = _componentPriceScore(
      priceDirection,
      oiPriceSignal,
    );
    final double orderFlowScore = _componentOrderFlowScore(orderFlowDirection);
    final double volumeScore = _componentVolumeScore(pumpAnalysis);
    final double liquidationScore = _componentLiquidationScore(
      pumpAnalysis,
      setupResult,
      oiPriceSignal,
    );
    final double momentumScore =
        _componentMomentumScore(entryTiming, visibleCandles);

    final double momentumShift =
        AnalysisEngine.calculateMomentumShift(visibleCandles);

    double finalScore = _weightedFinalScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
    );

    if (momentumShift >= 60) {
      finalScore -= 15;
    } else if (momentumShift >= 40) {
      finalScore -= 8;
    }

    if (structureDetected) {
      finalScore += structureScore >= 70 ? 12 : 7;
    } else if (structureScore >= 35) {
      finalScore += 3;
    }

    if (firstBreakDetected) {
      finalScore += firstBreakScore >= 80 ? 20 : 12;
    } else if (firstBreakScore >= 40) {
      finalScore += 5;
    }

    if (entryEngine.phase == 'PUMP_TRACKING') {
      finalScore += 4;
    } else if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      finalScore += 10;
    } else if (entryEngine.phase == 'BREAK_READY') {
      finalScore += entryEngine.breakdownConfirmations >= 2 ? 22 : 16;
    } else if (entryEngine.phase == 'INVALIDATED') {
      finalScore -= 14;
    }

    String tradeBias = _determineTradeBias(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      structureDetected: structureDetected,
      structureScore: structureScore,
      firstBreakDetected: firstBreakDetected,
      firstBreakScore: firstBreakScore,
      entryEngine: entryEngine,
    );

    if (structureScore >= 70) {
      finalScore += 15;
      if (structureScore >= 80) {
        tradeBias = 'SHORT';
      }
    }

    if (firstBreakScore >= 80) {
      tradeBias = 'SHORT';
    }

    if (entryEngine.phase == 'BREAK_READY') {
      tradeBias = 'SHORT';
    }

    if (entryEngine.phase == 'INVALIDATED' &&
        oiPriceSignal != 'STRONG_SHORT' &&
        oiPriceSignal != 'FAKE_PUMP') {
      tradeBias = 'NEUTRAL';
    }

    finalScore = FinalTradeDecisionService.clampScore(finalScore);

    double confidence = _confidenceScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
      tradeBias: tradeBias,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      oiPriceSignal: oiPriceSignal,
    );

    if (momentumShift >= 60) {
      confidence -= 15;
    } else if (momentumShift >= 40) {
      confidence -= 8;
    }

    if (structureDetected) {
      confidence += structureScore >= 70 ? 10 : 6;
    } else if (structureScore >= 35) {
      confidence += 2;
    }

    if (structureScore >= 70) {
      confidence += structureScore >= 80 ? 12 : 8;
    }

    if (firstBreakDetected) {
      confidence += firstBreakScore >= 80 ? 15 : 8;
    } else if (firstBreakScore >= 40) {
      confidence += 3;
    }

    if (entryEngine.phase == 'WEAKNESS_TRACKING') {
      confidence += 6;
    } else if (entryEngine.phase == 'BREAK_READY') {
      confidence += entryEngine.breakdownConfirmations >= 2 ? 16 : 10;
    } else if (entryEngine.phase == 'INVALIDATED') {
      confidence -= 12;
    }

    confidence = FinalTradeDecisionService.clampScore(confidence);

    final String scoreClass = _scoreClassFromScore(finalScore);

    String action = _actionFromDecision(
      finalScore: finalScore,
      confidence: confidence,
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      structureDetected: structureDetected,
      structureScore: structureScore,
      firstBreakDetected: firstBreakDetected,
      firstBreakScore: firstBreakScore,
      entryEngine: entryEngine,
    );

    if (entryEngine.phase == 'BREAK_READY' &&
        entryEngine.breakdownConfirmations >= 2 &&
        action == 'PREPARE SHORT') {
      action = 'ENTER SHORT';
    }

    if (entryEngine.phase == 'WEAKNESS_TRACKING' &&
        action == 'ENTER SHORT') {
      action = 'PREPARE SHORT';
    }

    if (structureScore >= 80 && action == 'WATCH') {
      action = 'PREPARE SHORT';
    } else if (structureScore >= 80 &&
        action != 'ENTER SHORT' &&
        entryEngine.phase != 'INVALIDATED' &&
        entryEngine.phase != 'WEAKNESS_TRACKING') {
      action = 'PREPARE SHORT';
    }

    final bool invalidAggressiveShort =
        oiPriceSignal == 'NEUTRAL' ||
        oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION' ||
        priceDirection == 'UP' ||
        orderFlowDirection == 'BUY_PRESSURE';

    if (invalidAggressiveShort && action == 'ENTER SHORT') {
      action = 'PREPARE SHORT';
    }

    if (invalidAggressiveShort &&
        action == 'PREPARE SHORT' &&
        entryEngine.phase != 'BREAK_READY' &&
        !firstBreakDetected) {
      action = 'WATCH';
    }

    if (tradeBias != 'SHORT' && action == 'ENTER SHORT') {
      action = 'WATCH';
    }

    final List<String> marketReadBullets = _buildMarketReadBullets(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      volumeScore: volumeScore,
      momentumScore: momentumScore,
      structureDetected: structureDetected,
      structureScore: structureScore,
      structureReasons: structureReasons,
      firstBreakDetected: firstBreakDetected,
      firstBreakScore: firstBreakScore,
      firstBreakReasons: firstBreakReasons,
      entryEngine: entryEngine,
    );

    final List<String> warnings = _buildWarnings(
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      confidence: confidence,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
      structureDetected: structureDetected,
      firstBreakDetected: firstBreakDetected,
      entryEngine: entryEngine,
    );

    final List<String> entryNotes = _buildEntryNotes(
      tradeBias: tradeBias,
      action: action,
      confidence: confidence,
      oiPriceSignal: oiPriceSignal,
      entryTiming: entryTiming,
      structureDetected: structureDetected,
      structureScore: structureScore,
      structureReasons: structureReasons,
      firstBreakDetected: firstBreakDetected,
      firstBreakScore: firstBreakScore,
      firstBreakReasons: firstBreakReasons,
      entryEngine: entryEngine,
    );

    final List<String> triggerConditions = _buildTriggerConditions(
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      structureDetected: structureDetected,
      firstBreakDetected: firstBreakDetected,
      entryEngine: entryEngine,
    );

    final String summary = _buildDecisionSummary(
      finalScore: finalScore,
      scoreClass: scoreClass,
      confidence: confidence,
      primarySignal: oiPriceSignal,
      tradeBias: tradeBias,
      action: action,
    );

    return FinalTradeDecision(
      finalScore: finalScore,
      scoreClass: scoreClass,
      confidence: confidence,
      primarySignal: oiPriceSignal,
      tradeBias: tradeBias,
      action: action,
      summary: summary,
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
      marketReadBullets: marketReadBullets,
      entryNotes: entryNotes,
      warnings: warnings,
      triggerConditions: triggerConditions,
    );
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
          decisions.length > 2
              ? decisions[decisions.length - 2].warnings
              : const [],
      maxItems: 6,
    );

    final List<String> entryNotes = _mergeUniqueLists(
      priorityItems: [
        'Karar her 5 saniyede değil, 3 dakikalık ortalama akışla güncellenir.',
        ...latest.entryNotes,
      ],
      secondaryItems:
          decisions.length > 2
              ? decisions[decisions.length - 2].entryNotes
              : const [],
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

  static bool _shouldResetOnReversal(FinalTradeDecision rawDecision) {
    if (rawDecision.tradeBias != 'SHORT') return true;
    if (rawDecision.action == 'WATCH' || rawDecision.action == 'NO TRADE') {
      return true;
    }
    if (rawDecision.primarySignal == 'NEUTRAL' ||
        rawDecision.primarySignal == 'SHORT_SQUEEZE' ||
        rawDecision.primarySignal == 'EARLY_ACCUMULATION') {
      return true;
    }
    final String warningsText = rawDecision.warnings.join(' ').toLowerCase();
    if (warningsText.contains('short squeeze') ||
        warningsText.contains('yukarı toparlama') ||
        warningsText.contains('order flow çelişiyor')) {
      return true;
    }
    return false;
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

    if (_shouldResetOnReversal(rawDecision)) {
      _decisionBufferFor(symbol).clear();
      _setLastDecisionAtFor(symbol, now);
      _setCachedDisplayDecisionFor(symbol, rawDecision);
      return rawDecision;
    }

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
    String selectedInterval = '3m',
    String? combinedSignal,
    String? stableCombinedSignal,
  }) async {
    final bundle = await DetailDataService.load(
      contractName: coin.name,
      selectedInterval: selectedInterval,
      fallbackCoin: coin,
    );

    final FinalTradeDecision rawDecision = _buildRealTradeDecision(
      symbol: coin.name,
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      pumpAnalysis: bundle.pumpAnalysis,
      entryTiming: bundle.entryTiming,
      setupResult: bundle.setupResult,
      visibleCandles: bundle.visibleCandles,
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
