import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';

class DecisionEngine {
  const DecisionEngine();

  double _clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  String _safeLower(dynamic value) {
    if (value is String) {
      return value.toLowerCase();
    }
    return '';
  }

  double _extractDynamicScore(dynamic source) {
    try {
      final dynamic score = source.score;
      if (score is num) {
        return _clampScore(score.toDouble());
      }
    } catch (_) {}

    try {
      final dynamic score = source.pumpScore;
      if (score is num) {
        return _clampScore(score.toDouble());
      }
    } catch (_) {}

    try {
      final dynamic score = source.entryScore;
      if (score is num) {
        return _clampScore(score.toDouble());
      }
    } catch (_) {}

    return 0;
  }

  String _extractDynamicLabel(dynamic source) {
    try {
      final dynamic label = source.label;
      if (label is String) return label;
    } catch (_) {}

    try {
      final dynamic signal = source.signal;
      if (signal is String) return signal;
    } catch (_) {}

    try {
      final dynamic signal = source.entrySignal;
      if (signal is String) return signal;
    } catch (_) {}

    try {
      final dynamic status = source.status;
      if (status is String) return status;
    } catch (_) {}

    return '';
  }

  String _extractDynamicSummary(dynamic source) {
    try {
      final dynamic summary = source.summary;
      if (summary is String) return summary;
    } catch (_) {}

    return '';
  }

  List<dynamic> _extractDynamicReasons(dynamic source) {
    try {
      final dynamic reasons = source.reasons;
      if (reasons is List) return reasons.cast<dynamic>();
    } catch (_) {}

    return const <dynamic>[];
  }

  bool _reasonContains(dynamic source, String needle) {
    final String summary = _safeLower(_extractDynamicSummary(source));
    if (summary.contains(needle)) return true;

    final String label = _safeLower(_extractDynamicLabel(source));
    if (label.contains(needle)) return true;

    for (final dynamic item in _extractDynamicReasons(source)) {
      final String text = _safeLower(item);
      if (text.contains(needle)) return true;
    }

    return false;
  }

  double _componentOiScore(String oiDirection) {
    switch (oiDirection) {
      case 'UP':
        return 78;
      case 'DOWN':
        return 34;
      default:
        return 50;
    }
  }

  double _componentPriceScore(String priceDirection, String oiPriceSignal) {
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
        score += 8;
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

    return _clampScore(score);
  }

  double _componentOrderFlowScore(String orderFlowDirection) {
    switch (orderFlowDirection) {
      case 'SELL_PRESSURE':
        return 88;
      case 'BUY_PRESSURE':
        return 18;
      default:
        return 52;
    }
  }

  double _componentVolumeScore(PumpAnalysisResult? result) {
    if (result == null) return 48;

    final dynamic dynamicResult = result;
    double score = 46;

    final double rawScore = _extractDynamicScore(dynamicResult);
    if (rawScore > 0) {
      score = 35 + (rawScore * 0.55);
    }

    final String label = _safeLower(_extractDynamicLabel(dynamicResult));
    final String summary = _safeLower(_extractDynamicSummary(dynamicResult));

    if (label.contains('güçlü')) score += 8;
    if (label.contains('uygun')) score += 6;
    if (label.contains('hazır')) score += 8;
    if (label.contains('zayıf')) score -= 10;
    if (label.contains('bekle')) score -= 5;

    if (summary.contains('hacim')) score += 4;
    if (summary.contains('climax')) score += 8;
    if (summary.contains('patlama')) score += 6;
    if (summary.contains('zayıf')) score -= 4;

    if (_reasonContains(dynamicResult, 'hacim')) score += 4;
    if (_reasonContains(dynamicResult, 'volume')) score += 3;

    return _clampScore(score);
  }

  double _componentLiquidationScore(
    PumpAnalysisResult? pumpAnalysis,
    ShortSetupResult? setupResult,
    String oiPriceSignal,
  ) {
    double score = 50;

    if (oiPriceSignal == 'STRONG_SHORT') score += 12;
    if (oiPriceSignal == 'FAKE_PUMP') score += 10;
    if (oiPriceSignal == 'EARLY_DISTRIBUTION') score += 8;
    if (oiPriceSignal == 'SHORT_SQUEEZE') score -= 18;
    if (oiPriceSignal == 'EARLY_ACCUMULATION') score -= 10;

    if (pumpAnalysis != null) {
      final String summary = _safeLower(_extractDynamicSummary(pumpAnalysis));
      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('toplanma')) score -= 6;
      if (_reasonContains(pumpAnalysis, 'weakness')) score += 5;
      if (_reasonContains(pumpAnalysis, 'lower-high')) score += 5;
      if (_reasonContains(pumpAnalysis, 'lower high')) score += 5;
    }

    if (setupResult != null) {
      final String summary = _safeLower(_extractDynamicSummary(setupResult));
      if (summary.contains('squeeze')) score -= 10;
      if (summary.contains('risk')) score -= 6;
      if (summary.contains('uygun')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('birikim')) score -= 8;
    }

    return _clampScore(score);
  }

  bool _hasLowerHigh(List<CandleData> candleList) {
    if (candleList.length < 2) return false;
    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];
    return last.high < prev.high;
  }

  bool _hasLowerClose(List<CandleData> candleList) {
    if (candleList.length < 2) return false;
    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];
    return last.close < prev.close;
  }

  bool _hasMomentumLoss(List<CandleData> candleList) {
    if (candleList.length < 2) return false;
    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];
    return last.close <= prev.close;
  }

  bool _hasWeakBearishShift(List<CandleData> candleList) {
    if (candleList.length < 2) return false;

    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];

    final bool lastRed = last.close < last.open;
    final bool lowerHigh = last.high < prev.high;
    final bool lowerClose = last.close < prev.close;

    return lowerHigh || (lastRed && lowerClose);
  }

  bool _isParabolicExtension(List<CandleData> candleList) {
    if (candleList.length < 4) return false;

    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];
    final CandleData prev2 = candleList[candleList.length - 3];
    final CandleData prev3 = candleList[candleList.length - 4];

    final bool staircaseUp =
        last.close > prev.close &&
        prev.close > prev2.close &&
        (prev2.close >= prev3.close || prev2.high > prev3.high);

    final double moveFromPrev =
        prev.close == 0 ? 0 : ((last.close - prev.close) / prev.close) * 100;
    final double moveFromPrev2 =
        prev2.close == 0 ? 0 : ((last.close - prev2.close) / prev2.close) * 100;

    return staircaseUp && (moveFromPrev >= 1.5 || moveFromPrev2 >= 4.0);
  }

  double _componentMomentumScore(
    EntryTimingResult? entryTiming,
    List<CandleData> candleList,
  ) {
    double score = 50;

    if (entryTiming != null) {
      final dynamic dynamicResult = entryTiming;
      final double rawScore = _extractDynamicScore(dynamicResult);
      final String label = _safeLower(_extractDynamicLabel(dynamicResult));
      final String summary = _safeLower(_extractDynamicSummary(dynamicResult));

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

      if (_reasonContains(dynamicResult, 'lower-high')) score += 10;
      if (_reasonContains(dynamicResult, 'lower high')) score += 10;
      if (_reasonContains(dynamicResult, 'zayıf')) score += 4;
      if (_reasonContains(dynamicResult, 'weak')) score += 4;
      if (_reasonContains(dynamicResult, 'kırılma')) score += 8;
      if (_reasonContains(dynamicResult, 'breakdown')) score += 8;
      if (_reasonContains(dynamicResult, 'momentum')) score += 4;
    }

    if (candleList.length >= 3) {
      final CandleData last = candleList.last;
      final CandleData prev = candleList[candleList.length - 2];
      final CandleData prev2 = candleList[candleList.length - 3];

      if (last.close < last.open) score += 6;
      if (prev.close < prev.open) score += 4;
      if (prev2.close < prev2.open) score += 3;

      final bool lastRed = last.close < last.open;
      final bool prevRed = prev.close < prev.open;
      final bool prevGreen = prev.close > prev.open;

      final bool lowerHigh = last.high < prev.high;
      final bool lowerClose = last.close < prev.close;

      if (lowerHigh && lastRed) {
        score += 8;
      }

      if (prevGreen && lastRed) {
        score += 6;
      }

      if (prevRed && lastRed && lowerClose) {
        score += 6;
      }

      final double prevBody = (prev.close - prev.open).abs();
      final double lastBody = (last.close - last.open).abs();

      if (lastRed && prevGreen && lastBody > prevBody * 0.8) {
        score += 4;
      }

      final double lastRange = (last.high - last.low).abs();
      if (lastRange > 0) {
        final double upperWickRatio = last.upperWick / lastRange;
        if (upperWickRatio > 0.35 && last.close <= prev.close) {
          score += 6;
        }
      }

      if (_hasWeakBearishShift(candleList)) {
        score += 8;
      }
    }

    return _clampScore(score);
  }

  double _weightedFinalScore({
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

    return _clampScore(raw);
  }

  bool _isFakePumpZone({
    required String oiPriceSignal,
    required String oiDirection,
    required double priceScore,
    required double momentumScore,
    required List<CandleData> visibleCandles,
    PumpAnalysisResult? pumpAnalysis,
  }) {
    final bool signalSuggestsDistribution =
        oiPriceSignal == 'FAKE_PUMP' || oiPriceSignal == 'EARLY_DISTRIBUTION';

    final bool blowOffTopLike =
        priceScore >= 75 &&
        momentumScore >= 72 &&
        (_isParabolicExtension(visibleCandles) || signalSuggestsDistribution);

    final bool oiUnwinding = oiDirection == 'DOWN';

    final bool weaknessHints =
        _hasLowerHigh(visibleCandles) ||
        _hasMomentumLoss(visibleCandles) ||
        _reasonContains(pumpAnalysis, 'lower-high') ||
        _reasonContains(pumpAnalysis, 'lower high') ||
        _reasonContains(pumpAnalysis, 'zayıflama') ||
        _reasonContains(pumpAnalysis, 'weakness');

    return blowOffTopLike && oiUnwinding && weaknessHints;
  }

  double _distributionOverride({
    required double rawFinalScore,
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required double priceScore,
    required double momentumScore,
    required double oiScore,
    required List<CandleData> visibleCandles,
    PumpAnalysisResult? pumpAnalysis,
    EntryTimingResult? entryTiming,
  }) {
    double bonus = 0;

    final bool fakePumpZone = _isFakePumpZone(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceScore: priceScore,
      momentumScore: momentumScore,
      visibleCandles: visibleCandles,
      pumpAnalysis: pumpAnalysis,
    );

    final bool lowerHigh = _hasLowerHigh(visibleCandles);
    final bool lowerClose = _hasLowerClose(visibleCandles);
    final bool momentumLoss = _hasMomentumLoss(visibleCandles);

    if (oiPriceSignal == 'EARLY_DISTRIBUTION') {
      bonus += 8;
    }

    if (fakePumpZone) {
      bonus += 10;
    }

    if (fakePumpZone && orderFlowDirection == 'BUY_PRESSURE') {
      bonus += 6;
    }

    if (priceDirection == 'DOWN' && oiDirection == 'DOWN') {
      bonus += 6;
    }

    if (priceScore >= 80 && momentumScore >= 80 && oiScore <= 40) {
      bonus += 8;
    }

    if (lowerHigh) {
      bonus += 6;
    }

    if (lowerClose) {
      bonus += 5;
    }

    if (momentumLoss) {
      bonus += 4;
    }

    if (entryTiming != null) {
      if (_reasonContains(entryTiming, 'lower-high') ||
          _reasonContains(entryTiming, 'lower high')) {
        bonus += 6;
      }
      if (_reasonContains(entryTiming, 'zayıf') ||
          _reasonContains(entryTiming, 'weakness')) {
        bonus += 4;
      }
      if (_reasonContains(entryTiming, 'breakdown') ||
          _reasonContains(entryTiming, 'kırılma')) {
        bonus += 6;
      }
    }

    if (pumpAnalysis != null) {
      if (_reasonContains(pumpAnalysis, 'lower-high') ||
          _reasonContains(pumpAnalysis, 'lower high')) {
        bonus += 4;
      }
      if (_reasonContains(pumpAnalysis, 'zayıflama') ||
          _reasonContains(pumpAnalysis, 'weakness')) {
        bonus += 4;
      }
    }

    if (rawFinalScore < 70 && fakePumpZone && (lowerHigh || momentumLoss)) {
      bonus += 6;
    }

    return bonus;
  }

  double _confidenceScore({
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
    required List<CandleData> visibleCandles,
    PumpAnalysisResult? pumpAnalysis,
    EntryTimingResult? entryTiming,
  }) {
    double confidence = 58;

    final bool fakePumpZone = _isFakePumpZone(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceScore: priceScore,
      momentumScore: momentumScore,
      visibleCandles: visibleCandles,
      pumpAnalysis: pumpAnalysis,
    );

    final bool shortAligned =
        tradeBias == 'SHORT' &&
        (priceDirection == 'DOWN' ||
            oiPriceSignal == 'FAKE_PUMP' ||
            oiPriceSignal == 'EARLY_DISTRIBUTION') &&
        (orderFlowDirection == 'SELL_PRESSURE' || fakePumpZone);

    if (shortAligned) {
      confidence += 16;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') confidence -= 20;

    if (orderFlowDirection == 'BUY_PRESSURE' && !fakePumpZone) {
      confidence -= 16;
    }

    if (orderFlowDirection == 'BUY_PRESSURE' && fakePumpZone) {
      confidence -= 6;
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') confidence -= 14;
    if (tradeBias == 'SHORT' && oiDirection == 'UP') confidence += 4;
    if (tradeBias == 'NEUTRAL') confidence -= 12;

    if (_hasLowerHigh(visibleCandles)) confidence += 6;
    if (_hasMomentumLoss(visibleCandles)) confidence += 4;

    if (_reasonContains(entryTiming, 'breakdown') ||
        _reasonContains(entryTiming, 'kırılma')) {
      confidence += 6;
    }

    return _clampScore(confidence);
  }

  String _scoreClassFromScore(double finalScore) {
    if (finalScore >= 85) return 'Güçlü fırsat';
    if (finalScore >= 70) return 'Kurulum var';
    if (finalScore >= 40) return 'İzlenmeli';
    return 'Zayıf';
  }

  String _determineTradeBias({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
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

    if (oiPriceSignal == 'SHORT_SQUEEZE') neutralPenalty += 3;
    if (oiPriceSignal == 'EARLY_ACCUMULATION') neutralPenalty += 3;

    if (shortVotes >= 3 && shortVotes > neutralPenalty) {
      return 'SHORT';
    }

    return 'NEUTRAL';
  }

  bool _isBreakdownConfirmed(List<CandleData> candleList) {
    if (candleList.length < 2) return false;

    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];

    final bool closeBelowPreviousLow = last.close < prev.low;
    final bool bearishClose = last.close < last.open;

    final double candleRange = (last.high - last.low).abs();
    final double candleBody = (last.open - last.close).abs();
    final double bodyRatio = candleRange > 0 ? candleBody / candleRange : 0;
    final bool meaningfulBearBody = bodyRatio >= 0.35;

    return closeBelowPreviousLow && bearishClose && meaningfulBearBody;
  }

  String _actionFromDecision({
    required double finalScore,
    required double confidence,
    required String tradeBias,
    required String oiPriceSignal,
    required List<CandleData> visibleCandles,
  }) {
    if (finalScore < 40) return 'WATCH';
    if (tradeBias != 'SHORT') return 'WATCH';

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION') {
      return 'WATCH';
    }

    final bool breakdownConfirmed = _isBreakdownConfirmed(visibleCandles);

    if (!breakdownConfirmed && finalScore >= 80) {
      return 'PREPARE SHORT';
    }

    if (finalScore >= 85 && confidence >= 68) {
      return breakdownConfirmed ? 'ENTER SHORT' : 'PREPARE SHORT';
    }

    if (finalScore >= 70) return 'PREPARE SHORT';
    return 'WATCH';
  }

  String _buildDecisionSummary({
    required double finalScore,
    required String scoreClass,
    required double confidence,
    required String primarySignal,
    required String tradeBias,
    required String action,
  }) {
    final String scoreText = finalScore.toStringAsFixed(0);
    final String confidenceText = confidence.toStringAsFixed(0);

    return '$scoreClass • Score $scoreText • Confidence $confidenceText% • '
        'Signal: $primarySignal • Bias: $tradeBias • Action: $action';
  }

  FinalTradeDecision build({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> visibleCandles,
  }) {
    final double oiScore = _componentOiScore(oiDirection);
    final double priceScore = _componentPriceScore(priceDirection, oiPriceSignal);
    final double orderFlowScore = _componentOrderFlowScore(orderFlowDirection);
    final double volumeScore = _componentVolumeScore(pumpAnalysis);
    final double liquidationScore = _componentLiquidationScore(
      pumpAnalysis,
      setupResult,
      oiPriceSignal,
    );
    final double momentumScore =
        _componentMomentumScore(entryTiming, visibleCandles);

    final String tradeBias = _determineTradeBias(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
    );

    final double rawFinalScore = _weightedFinalScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
    );

    final bool fakePumpZone = _isFakePumpZone(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceScore: priceScore,
      momentumScore: momentumScore,
      visibleCandles: visibleCandles,
      pumpAnalysis: pumpAnalysis,
    );

    final double distributionBonus = _distributionOverride(
      rawFinalScore: rawFinalScore,
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
      priceScore: priceScore,
      momentumScore: momentumScore,
      oiScore: oiScore,
      visibleCandles: visibleCandles,
      pumpAnalysis: pumpAnalysis,
      entryTiming: entryTiming,
    );

    final double confidence = _confidenceScore(
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
      visibleCandles: visibleCandles,
      pumpAnalysis: pumpAnalysis,
      entryTiming: entryTiming,
    );

    final bool breakdownConfirmed = _isBreakdownConfirmed(visibleCandles);

    double adjustedScore = rawFinalScore + distributionBonus;

    if (tradeBias == 'SHORT' && !breakdownConfirmed) {
      final double cap = fakePumpZone ? 82 : 75;
      adjustedScore = adjustedScore > cap ? cap : adjustedScore;
    }

    adjustedScore = _clampScore(adjustedScore);

    final String scoreClass = _scoreClassFromScore(adjustedScore);
    final String action = _actionFromDecision(
      finalScore: adjustedScore,
      confidence: confidence,
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      visibleCandles: visibleCandles,
    );

    final List<String> marketReadBullets = <String>[
      if (oiDirection == 'UP')
        'Open interest artıyor, piyasaya yeni pozisyon girişi var.'
      else if (oiDirection == 'DOWN')
        'Open interest düşüyor, pozisyon çözülmesi görülüyor.'
      else
        'Open interest tarafı yatay, güçlü yön teyidi sınırlı.',
      if (priceDirection == 'DOWN')
        'Fiyat aşağı yönlü baskı gösteriyor.'
      else if (priceDirection == 'UP')
        'Fiyat yukarı gidiyor, short tarafı için risk oluşturabilir.'
      else
        'Fiyat yatay seyirde, net kırılım henüz gelmemiş olabilir.',
      if (orderFlowDirection == 'SELL_PRESSURE')
        'Order flow satış baskısını destekliyor.'
      else if (orderFlowDirection == 'BUY_PRESSURE' && fakePumpZone)
        'Order flow alıcı baskısı gösterse de bu, blow-off top sonrası geç kalan alıcıları temsil ediyor olabilir.'
      else if (orderFlowDirection == 'BUY_PRESSURE')
        'Order flow alıcı baskısını gösteriyor; short için ters rüzgar var.'
      else
        'Order flow tarafında belirgin üstünlük yok.',
      if (fakePumpZone)
        'Parabolik yükseliş + düşen OI + zayıflama işaretleri fake pump / distribution bölgesine işaret ediyor.',
      if (_hasLowerHigh(visibleCandles))
        'Son yapıda lower-high oluşumu var; tepe gücü zayıflıyor.',
      if (tradeBias == 'SHORT' && breakdownConfirmed)
        'Yapı kırılımı teyidi alındı; son kapanış önceki mumun dip bölgesinin altına sarktı.'
      else if (tradeBias == 'SHORT')
        'Kurulum kısa pozisyon lehine olsa da yapı kırılımı henüz teyit vermedi.',
    ];

    final List<String> warnings = <String>[
      if (oiPriceSignal == 'SHORT_SQUEEZE') 'Short squeeze riski var.',
      if (oiPriceSignal == 'EARLY_ACCUMULATION')
        'Erken birikim sinyali short girişini zayıflatıyor.',
      if (confidence < 60) 'Sinyal uyumu düşük.',
      if (volumeScore < 45) 'Hacim teyidi zayıf.',
      if (momentumScore < 45) 'Momentum zayıf.',
      if (tradeBias == 'SHORT' && !breakdownConfirmed)
        'Yapı kırılımı gelmeden agresif short tarafına geçilmedi.',
      if (orderFlowDirection == 'BUY_PRESSURE' && !fakePumpZone)
        'Short bias ile order flow çelişiyor.',
    ];

    final List<String> entryNotes = <String>[
      if (action == 'ENTER SHORT')
        'Kurulum güçlü; yapı kırılımı da geldiği için aktif short fırsatı gösteriliyor.'
      else if (action == 'PREPARE SHORT' &&
          adjustedScore >= 85 &&
          confidence >= 68 &&
          !breakdownConfirmed)
        'Kurulum güçlü ama yapı kırılımı teyidi gelmeden aktif girişe geçilmedi.'
      else if (action == 'PREPARE SHORT' && fakePumpZone)
        'Fake pump / distribution bölgesi yakalandı; küçük spike ihtimaline karşı tetik teyidi beklenmeli.'
      else if (action == 'PREPARE SHORT')
        'Short hazırlığı var; tetik için ek fiyat teyidi beklenmeli.'
      else
        'Şimdilik izleme modunda kalmak daha doğru.',
    ];

    final List<String> triggerConditions = <String>[
      if (tradeBias == 'SHORT' && !breakdownConfirmed && fakePumpZone) ...<String>[
        'İlk kırılma sonrası zayıf kapanışın devam etmesi',
        'Lower-high yapısının bozulmaması',
        'Satış baskısının veya breakdown teyidinin gelmesi',
      ] else if (tradeBias == 'SHORT' && !breakdownConfirmed) ...<String>[
        'Son kapanışın bir önceki mumun low seviyesinin altına inmesi',
        'Ayı yönlü mum gövdesinin anlamlı kalması',
        'Satış baskısının devam etmesi',
      ] else if (tradeBias == 'SHORT') ...<String>[
        'Satış baskısının devam etmesi',
        'Breakdown sonrası zayıf toparlanma görülmesi',
      ] else ...<String>[
        'Net short yön teyidi',
        'Alıcı baskısının zayıflaması',
      ],
    ];

    final String summary = _buildDecisionSummary(
      finalScore: adjustedScore,
      scoreClass: scoreClass,
      confidence: confidence,
      primarySignal: oiPriceSignal,
      tradeBias: tradeBias,
      action: action,
    );

    return FinalTradeDecision(
      finalScore: adjustedScore,
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
}
