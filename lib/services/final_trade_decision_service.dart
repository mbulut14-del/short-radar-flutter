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
  bool fakePumpDetected;
  int breakdownConfirmations;
  String phase;
  List<String> reasons;
  double score;
  double weaknessScore;

  EntryEngineState({
    this.hadPump = false,
    this.weaknessSeen = false,
    this.breakStarted = false,
    this.fakePumpDetected = false,
    this.breakdownConfirmations = 0,
    this.phase = 'SEARCHING',
    List<String>? reasons,
    this.score = 0,
    this.weaknessScore = 0,
  }) : reasons = reasons ?? <String>[];

  void reset() {
    hadPump = false;
    weaknessSeen = false;
    breakStarted = false;
    fakePumpDetected = false;
    breakdownConfirmations = 0;
    phase = 'SEARCHING';
    reasons = <String>[];
    score = 0;
    weaknessScore = 0;
  }
}

class EntryEngineSnapshot {
  final bool hadPump;
  final bool weaknessSeen;
  final bool breakStarted;
  final bool fakePumpDetected;
  final int breakdownConfirmations;
  final String phase;
  final double score;
  final double weaknessScore;
  final List<String> reasons;

  const EntryEngineSnapshot({
    required this.hadPump,
    required this.weaknessSeen,
    required this.breakStarted,
    required this.fakePumpDetected,
    required this.breakdownConfirmations,
    required this.phase,
    required this.score,
    required this.weaknessScore,
    required this.reasons,
  });
}

class FinalTradeDecisionService {
  static final Map<String, FinalTradeDecision> _cache = {};
  static final Map<String, EntryEngineState> _entryStates = {};

  static FinalTradeDecision? getFromCache(String symbol) {
    return _cache[symbol];
  }

  static void setCache(String symbol, FinalTradeDecision decision) {
    _cache[symbol] = decision;
  }

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

  static EntryEngineState _stateFor(String symbol) {
    return _entryStates.putIfAbsent(symbol, () => EntryEngineState());
  }

  static double _candleBody(CandleData candle) {
    return (candle.close - candle.open).abs();
  }

  static double _candleRange(CandleData candle) {
    return (candle.high - candle.low).abs();
  }

  static bool _isBearish(CandleData candle) {
    return candle.close < candle.open;
  }

  static bool _isBullish(CandleData candle) {
    return candle.close > candle.open;
  }

  static bool _lastBodyShrinking(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    final double lastBody = _candleBody(last);
    final double prevBody = _candleBody(prev);

    return lastBody < prevBody;
  }

  static bool _upperWickWeakness(List<CandleData> candles) {
    if (candles.isEmpty) return false;

    final CandleData last = candles.last;
    final double body = _candleBody(last);
    final double upperWick =
        last.high - (last.open > last.close ? last.open : last.close);

    if (body <= 0) {
      return upperWick > 0;
    }

    return upperWick > body * 1.2;
  }

  static bool _closeNearLow(CandleData candle) {
    final double range = _candleRange(candle);
    if (range <= 0) return false;

    final double closePosition = (candle.close - candle.low) / range;
    return closePosition <= 0.35;
  }

  static bool _failedBreakout(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];

    final bool madeNewHigh = last.high > prev.high;
    final bool weakClose = _closeNearLow(last);
    final bool upperWickWeak = _upperWickWeakness(candles);

    return madeNewHigh && (weakClose || upperWickWeak);
  }

  static bool _microBreakdownStarted(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];

    return last.close < prev.low;
  }

  static bool _lowerHighFormed(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    return last.high < prev.high;
  }

  static bool _pumpDetected(
    PumpAnalysisResult? pumpAnalysis,
    String oiPriceSignal,
    List<CandleData> candles,
  ) {
    bool hadPump = false;

    if (pumpAnalysis != null) {
      final double pumpScore = extractDynamicScore(pumpAnalysis);
      final String label = safeLower(extractDynamicLabel(pumpAnalysis));
      final String signal = safeLower(extractDynamicSignal(pumpAnalysis));
      final String summary = safeLower(extractDynamicSummary(pumpAnalysis));

      if (pumpScore >= 70) hadPump = true;
      if (label.contains('güçlü') || label.contains('pump')) hadPump = true;
      if (signal.contains('pump')) hadPump = true;
      if (summary.contains('pump')) hadPump = true;
      if (summary.contains('şiş')) hadPump = true;
    }

    if (oiPriceSignal == 'FAKE_PUMP' || oiPriceSignal == 'SHORT_SQUEEZE') {
      hadPump = true;
    }

    if (!hadPump && candles.length >= 3) {
      final CandleData a = candles[candles.length - 3];
      final CandleData b = candles[candles.length - 2];
      final CandleData c = candles[candles.length - 1];

      if (_isBullish(a) && _isBullish(b)) {
        final double rise1 =
            a.open != 0 ? ((a.close - a.open) / a.open) * 100 : 0;
        final double rise2 =
            b.open != 0 ? ((b.close - b.open) / b.open) * 100 : 0;
        final double totalRise = rise1 + rise2;
        if (totalRise >= 2.5 && c.high >= b.high) {
          hadPump = true;
        }
      }
    }

    return hadPump;
  }

  static EntryEngineSnapshot evaluateEntryEngine({
    required String symbol,
    required String oiPriceSignal,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> candles,
    required double finalScore,
  }) {
    final EntryEngineState state = _stateFor(symbol);
    final List<String> reasons = <String>[];

    final bool hadPump = _pumpDetected(pumpAnalysis, oiPriceSignal, candles);
    final bool bodyShrinking = _lastBodyShrinking(candles);
    final bool upperWickWeak = _upperWickWeakness(candles);
    final bool lowerHigh = _lowerHighFormed(candles);
    final bool bearishLastCandle =
        candles.isNotEmpty ? _isBearish(candles.last) : false;
    final bool breakStarted = _microBreakdownStarted(candles);
    final bool failedBreakout = _failedBreakout(candles);
    final bool closeNearLow =
        candles.isNotEmpty ? _closeNearLow(candles.last) : false;

    final String entryLabel =
        safeLower(entryTiming != null ? extractDynamicLabel(entryTiming) : '');
    final String entrySummary = safeLower(
      entryTiming != null ? extractDynamicSummary(entryTiming) : '',
    );
    final String setupSummary = safeLower(
      setupResult != null ? extractDynamicSummary(setupResult) : '',
    );
    final double entryScore =
        entryTiming != null ? extractDynamicScore(entryTiming) : 0;

    bool weaknessSeen = false;
    double weaknessScore = 0;

    if (hadPump) {
      reasons.add('Öncesinde pump tespit edildi');
    }

    if (bodyShrinking) {
      weaknessSeen = true;
      weaknessScore += 20;
      reasons.add('Son mum gövdesi küçülüyor');
    }

    if (upperWickWeak) {
      weaknessSeen = true;
      weaknessScore += 20;
      reasons.add('Üst fitil baskısı görülüyor');
    }

    if (failedBreakout) {
      weaknessSeen = true;
      weaknessScore += 20;
      reasons.add('Yeni high denemesi zayıf kalmış');
    }

    if (closeNearLow) {
      weaknessSeen = true;
      weaknessScore += 15;
      reasons.add('Kapanış mumun alt kısmına yakın');
    }

    if (lowerHigh) {
      weaknessSeen = true;
      weaknessScore += 10;
      reasons.add('Daha düşük tepe oluşmaya başladı');
    }

    if (bearishLastCandle) {
      weaknessSeen = true;
      weaknessScore += 10;
      reasons.add('Son mum satış baskılı kapanıyor');
    }

    if (entryLabel.contains('erken')) {
      weaknessSeen = true;
      weaknessScore += 8;
      reasons.add('Timing motoru erken short hazırlığı söylüyor');
    }

    if (entrySummary.contains('yakın')) {
      weaknessSeen = true;
      weaknessScore += 5;
      reasons.add('Tetik bölgesi yakın görünüyor');
    }

    if (setupSummary.contains('zayıfl')) {
      weaknessSeen = true;
      weaknessScore += 7;
      reasons.add('Setup özeti zayıflama içeriyor');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      weaknessScore += 8;
      reasons.add('Order flow satış baskısı gösteriyor');
    }

    if (priceDirection == 'DOWN') {
      weaknessScore += 5;
      reasons.add('Fiyat yönü aşağı dönmeye başlamış');
    }

    if (entryScore >= 70) {
      weaknessScore += 5;
      reasons.add('Entry timing skoru yüksek');
    }

    if (breakStarted) {
      weaknessScore += 12;
      reasons.add('İlk micro breakdown başladı');
    }

    weaknessScore = clampScore(weaknessScore);
    final bool fakePumpDetected = hadPump && weaknessScore >= 55;

    state.hadPump = hadPump;
    state.weaknessSeen = weaknessSeen;
    state.breakStarted = breakStarted;
    state.fakePumpDetected = fakePumpDetected;
    state.weaknessScore = weaknessScore;

    if (breakStarted) {
      state.breakdownConfirmations += 1;
    } else {
      state.breakdownConfirmations = 0;
    }

    double score = 0;
    if (hadPump) score += 30;
    score += weaknessScore * 0.45;
    if (breakStarted) score += 10;
    if (fakePumpDetected) score += 8;

    state.score = clampScore(score);

    if (!hadPump) {
      state.phase = 'SEARCHING';
    } else if (hadPump && weaknessScore < 40) {
      state.phase = 'PUMP_ACTIVE';
    } else if (hadPump && weaknessScore >= 40 && weaknessScore < 75) {
      state.phase = 'PREPARE_SHORT';
    } else if (hadPump && weaknessScore >= 75 && !breakStarted) {
      state.phase = 'EARLY_SHORT_READY';
    } else if (hadPump && weaknessScore >= 75 && breakStarted) {
      state.phase = 'BREAKDOWN_STARTED';
    }

    state.reasons = reasons;

    return EntryEngineSnapshot(
      hadPump: state.hadPump,
      weaknessSeen: state.weaknessSeen,
      breakStarted: state.breakStarted,
      fakePumpDetected: state.fakePumpDetected,
      breakdownConfirmations: state.breakdownConfirmations,
      phase: state.phase,
      score: state.score,
      weaknessScore: state.weaknessScore,
      reasons: List<String>.from(state.reasons),
    );
  }

  static String decideAction({
    required double finalScore,
    required String oiPriceSignal,
    required EntryEngineSnapshot entrySnapshot,
  }) {
    if (finalScore < 40) return 'IGNORE';

    if (oiPriceSignal == 'SHORT_SQUEEZE' &&
        !entrySnapshot.breakStarted &&
        entrySnapshot.weaknessScore < 75) {
      return 'WATCH';
    }

    if (entrySnapshot.hadPump &&
        entrySnapshot.fakePumpDetected &&
        entrySnapshot.weaknessScore >= 75 &&
        finalScore >= 70) {
      return 'ENTER_SHORT';
    }

    if (entrySnapshot.hadPump &&
        entrySnapshot.fakePumpDetected &&
        entrySnapshot.weaknessScore >= 55 &&
        finalScore >= 60) {
      return 'PREPARE_SHORT';
    }

    if (entrySnapshot.hadPump &&
        entrySnapshot.weaknessSeen &&
        finalScore >= 60) {
      return 'PREPARE_SHORT';
    }

    if (oiPriceSignal == 'STRONG_SHORT' && finalScore >= 70) {
      return 'PREPARE_SHORT';
    }

    if (finalScore >= 85 &&
        (oiPriceSignal == 'FAKE_PUMP' ||
            oiPriceSignal == 'EARLY_DISTRIBUTION')) {
      return 'PREPARE_SHORT';
    }

    return 'WATCH';
  }

  static double calculateConfidence({
    required double finalScore,
    required EntryEngineSnapshot entrySnapshot,
    required String oiPriceSignal,
  }) {
    double confidence = 45;

    confidence += (finalScore - 50) * 0.35;
    confidence += entrySnapshot.weaknessScore * 0.20;

    if (entrySnapshot.hadPump) confidence += 6;
    if (entrySnapshot.fakePumpDetected) confidence += 8;
    if (entrySnapshot.breakStarted) confidence += 6;
    if (oiPriceSignal == 'STRONG_SHORT') confidence += 4;
    if (oiPriceSignal == 'FAKE_PUMP') confidence += 5;
    if (oiPriceSignal == 'SHORT_SQUEEZE') confidence -= 8;

    return clampScore(confidence);
  }

  static List<String> buildMarketReadBullets({
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required String oiPriceSignal,
    required EntryEngineSnapshot entrySnapshot,
  }) {
    final List<String> bullets = <String>[];

    bullets.add('OI: $oiDirection');
    bullets.add('Fiyat: $priceDirection');
    bullets.add('Order Flow: $orderFlowDirection');
    bullets.add('Ana sinyal: $oiPriceSignal');
    bullets.add(
      'Zayıflama skoru: ${entrySnapshot.weaknessScore.toStringAsFixed(1)}',
    );

    if (entrySnapshot.hadPump) {
      bullets.add('Piyasada önce pump izi var');
    }

    if (entrySnapshot.fakePumpDetected) {
      bullets.add('Fake pump olasılığı yükselmiş görünüyor');
    }

    if (entrySnapshot.weaknessSeen) {
      bullets.add('Pump sonrası zayıflama sinyali görülüyor');
    }

    if (entrySnapshot.breakStarted) {
      bullets.add('İlk breakdown denemesi başlamış görünüyor');
    }

    return bullets;
  }

  static List<String> buildEntryNotes({
    required EntryEngineSnapshot entrySnapshot,
    required String action,
  }) {
    final List<String> notes = <String>[];

    if (action == 'PREPARE_SHORT') {
      notes.add('Short kurulumu oluşuyor; tam yüklenmeden izlemeyi sürdür');
    }

    if (action == 'ENTER_SHORT') {
      notes.add('Fake pump sonrası zayıflama yeterli; erken short girişi aktif');
    }

    if (action == 'WATCH') {
      notes.add('Kurulum izleniyor, erken davranma');
    }

    notes.addAll(entrySnapshot.reasons);

    return notes;
  }

  static List<String> buildWarnings({
    required String oiPriceSignal,
    required EntryEngineSnapshot entrySnapshot,
    required double finalScore,
  }) {
    final List<String> warnings = <String>[];

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      warnings.add('Short squeeze riski var, teyitsiz agresif girişten kaçın');
    }

    if (entrySnapshot.hadPump &&
        !entrySnapshot.fakePumpDetected &&
        !entrySnapshot.breakStarted) {
      warnings.add('Pump hâlâ canlı olabilir, çok erken short riskli');
    }

    if (entrySnapshot.fakePumpDetected && !entrySnapshot.breakStarted) {
      warnings.add('Giriş erken sayılır; pozisyon boyutunu kontrollü tut');
    }

    if (finalScore < 60) {
      warnings.add('Skor orta-alt bölgede; sinyal tam olgun değil');
    }

    return warnings;
  }

  static List<String> buildTriggerConditions({
    required EntryEngineSnapshot entrySnapshot,
    required List<CandleData> candles,
  }) {
    final List<String> triggers = <String>[];

    if (candles.length >= 2) {
      final CandleData prev = candles[candles.length - 2];
      triggers.add(
        'Önceki mum dibi (${prev.low.toStringAsFixed(6)}) altı kapanış',
      );
    }

    if (entrySnapshot.fakePumpDetected) {
      triggers.add('Yeni high denemesinin yeniden reddedilmesi');
    }

    if (entrySnapshot.hadPump && entrySnapshot.weaknessSeen) {
      triggers.add('Zayıflama sonrası satış baskısının devam etmesi');
    }

    if (!entrySnapshot.breakStarted) {
      triggers.add('Micro breakdown başlarsa giriş daha da güçlenir');
    }

    return triggers;
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

  static double componentPriceScore(
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
    final String summary = saf
