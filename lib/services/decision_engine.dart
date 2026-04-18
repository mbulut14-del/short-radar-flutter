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
    return 0;
  }

  String _extractDynamicLabel(dynamic source) {
    try {
      final dynamic label = source.label;
      if (label is String) return label;
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
    if (label.contains('zayıf')) score -= 10;
    if (label.contains('bekle')) score -= 5;

    if (summary.contains('hacim')) score += 4;
    if (summary.contains('zayıf')) score -= 4;

    return _clampScore(score);
  }

  double _componentLiquidationScore(
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
      final String summary = _safeLower(_extractDynamicSummary(pumpAnalysis));
      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (summary.contains('alıcı')) score -= 8;
      if (summary.contains('toplanma')) score -= 6;
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
    }

    if (candleList.length >= 3) {
      final CandleData last = candleList.last;
      final CandleData prev = candleList[candleList.length - 2];
      final CandleData prev2 = candleList[candleList.length - 3];

      if (last.close < last.open) score += 6;
      if (prev.close < prev.open) score += 4;
      if (prev2.close < prev2.open) score += 3;
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
  }) {
    double confidence = 58;

    final bool shortAligned =
        tradeBias == 'SHORT' &&
        (priceDirection == 'DOWN' || oiPriceSignal == 'FAKE_PUMP') &&
        orderFlowDirection == 'SELL_PRESSURE';

    if (shortAligned) {
      confidence += 16;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') confidence -= 20;
    if (orderFlowDirection == 'BUY_PRESSURE') confidence -= 16;
    if (oiPriceSignal == 'EARLY_ACCUMULATION') confidence -= 14;
    if (tradeBias == 'SHORT' && oiDirection == 'UP') confidence += 4;
    if (tradeBias == 'NEUTRAL') confidence -= 12;

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

    return '$scoreClass • Score $scoreText • Confidence $confidenceText% • Signal: $primarySignal • Bias: $tradeBias • Action: $action';
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

    final double finalScore = _weightedFinalScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
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
    );

    final bool breakdownConfirmed = _isBreakdownConfirmed(visibleCandles);

    final String scoreClass = _scoreClassFromScore(finalScore);
    final String action = _actionFromDecision(
      finalScore: finalScore,
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
      else if (orderFlowDirection == 'BUY_PRESSURE')
        'Order flow alıcı baskısını gösteriyor; short için ters rüzgar var.'
      else
        'Order flow tarafında belirgin üstünlük yok.',
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
    ];

    final List<String> entryNotes = <String>[
      if (action == 'ENTER SHORT')
        'Kurulum güçlü; yapı kırılımı da geldiği için aktif short fırsatı gösteriliyor.'
      else if (action == 'PREPARE SHORT' &&
          finalScore >= 85 &&
          confidence >= 68 &&
          !breakdownConfirmed)
        'Kurulum güçlü ama yapı kırılımı teyidi gelmeden aktif girişe geçilmedi.'
      else if (action == 'PREPARE SHORT')
        'Short hazırlığı var; tetik için ek fiyat teyidi beklenmeli.'
      else
        'Şimdilik izleme modunda kalmak daha doğru.',
    ];

    final List<String> triggerConditions = <String>[
      if (tradeBias == 'SHORT' && !breakdownConfirmed) ...<String>[
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
}
