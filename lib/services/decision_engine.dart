
import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import 'analysis_engine.dart';
import 'entry_engine.dart';
import 'structure_detector.dart';

class DecisionEngine {
  const DecisionEngine();

  static final EntryEngine _entryEngine = EntryEngine();
  static final StructureDetector _structureDetector = StructureDetector();

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

  String _extractDynamicSignal(dynamic source) {
    try {
      final dynamic signal = source.signal;
      if (signal is String) return signal;
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
    final String signal = _safeLower(_extractDynamicSignal(dynamicResult));
    final String summary = _safeLower(_extractDynamicSummary(dynamicResult));

    if (label.contains('güçlü')) score += 8;
    if (label.contains('uygun')) score += 6;
    if (label.contains('zayıf')) score -= 10;
    if (label.contains('bekle')) score -= 5;

    if (signal.contains('short')) score += 5;
    if (signal.contains('pump')) score += 4;

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
      final String signal = _safeLower(_extractDynamicSignal(pumpAnalysis));

      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (signal.contains('pump')) score += 4;
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

      final double range = (last.high - last.low).abs();
      if (range > 0) {
        final double upperWick =
            last.high - (last.open > last.close ? last.open : last.close);
        final double upperWickRatio = upperWick / range;
        if (upperWickRatio >= 0.35) score += 7;
      }
    }

    return _clampScore(score);
  \nString _determineTradeBias({
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

    return _clampScore(confidence);
  }

  String _scoreClassFromScore(double finalScore) {
    if (finalScore >= 85) return 'Güçlü fırsat';
    if (finalScore >= 70) return 'Kurulum var';
    if (finalScore >= 40) return 'İzlenmeli';
    return 'Zayıf';
  }

  String _actionFromDecision({
    required double finalScore,
    required double confidence,
    required String tradeBias,
    required String oiPriceSignal,
    required bool structureDetected,
    required double structureScore,
    required bool firstBreakDetected,
    required double firstBreakScore,
    required EntryEngineSnapshot entryEngine,
  }) {
    if (entryEngine.phase == 'INVALIDATED') {
      return 'WATCH';
    }

    if (entryEngine.phase == 'BREAK_READY' &&
        entryEngine.breakdownConfirmations >= 2 &&
        tradeBias == 'SHORT' &&
        confidence >= 60) {
      return 'ENTER SHORT';
    }

    if (entryEngine.phase == 'BREAK_READY' && tradeBias == 'SHORT') {
      return 'PREPARE SHORT';
    }

    if (firstBreakScore >= 80 && tradeBias == 'SHORT') {
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
      return structureDetected && structureScore >= 70 ? 'PREPARE SHORT' : 'WATCH';
    }

    if (finalScore < 85) {
      if (confidence < 60) {
        return structureDetected && structureScore >= 70 ? 'PREPARE SHORT' : 'WATCH';
      }
      return 'PREPARE SHORT';
    }

    if (confidence < 68) {
      return 'WATCH';
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION') {
      return 'WATCH';
    }

    return 'ENTER SHORT';
  }

  List<String> _buildMarketReadBullets({
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
      bullets.add('Fiyat yukarı gidiyor, short tarafı için risk oluşturabilir.');
    } else {
      bullets.add('Fiyat yatay seyirde, net kırılım henüz gelmemiş olabilir.');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      bullets.add('Order flow satış baskısını destekliyor.');
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      bullets.add('Order flow alıcı baskısını gösteriyor; short için ters rüzgar var.');
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
        bullets.add('Erken dağıtım sinyali short lehine öncü işaret olabilir.');
        break;
      case 'EARLY_ACCUMULATION':
        bullets.add('Erken toplama sinyali var; short tarafı için negatif filtre oluşuyor.');
        break;
      case 'SHORT_SQUEEZE':
        bullets.add('Kısa pozisyonlar sıkışıyor olabilir; short açmak için risk yüksek.');
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
      bullets.add('Entry engine kırılma fazında; girişe en yakın bölge izleniyor.');
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
        bullets.add('Price structure tarafında güçlü tepe / exhaustion oluşumu var.');
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

  List<String> _buildWarnings({
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

  List<String> _buildEntryNotes({
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
        notes.add('Stateful entry engine kırılma başlattı; continuation beklenmeli.');
      }
    } else if (entryEngine.phase == 'INVALIDATED') {
      notes.add('Yukarı toparlama geldiği için önceki setup bozuldu.');
    }

    if (firstBreakDetected) {
      if (firstBreakScore >= 80) {
        notes.add('İlk kırılma motoru giriş anına çok yakın görüntü üretiyor.');
      } else {
        notes.add('İlk kırılma başladı; tam breakdown teyidi gelirse giriş kalitesi artar.');
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
      notes.add('Erken dağıtım sinyali nedeniyle sabırlı bekleme avantajlı olabilir.');
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION') {
      notes.add('Alıcı tarafı erken üstünlük kuruyor olabilir; short için acele etme.');
    }

    if (confidence < 60) {
      notes.add('Sinyaller tam hizalanmadığı için pozisyon boyutu küçük tutulmalı.');
    }

    if (entryTiming != null) {
      final String label = _safeLower(_extractDynamicLabel(entryTiming));
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

  List<String> _buildTriggerConditions({
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

  FinalTradeDecision _buildFinalTradeDecision({
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
        _structureDetector.detectPriceStructure(visibleCandles);
    final bool structureDetected = structureResult['detected'] == true;
    final double structureScore =
        ((structureResult['score'] ?? 0) as num).toDouble();
    final List<String> structureReasons =
        List<String>.from(structureResult['reasons'] ?? const []);

    final Map<String, dynamic> firstBreakResult =
        _structureDetector.detectFirstBreak(visibleCandles);
    final bool firstBreakDetected = firstBreakResult['detected'] == true;
    final double firstBreakScore =
        ((firstBreakResult['score'] ?? 0) as num).toDouble();
    final List<String> firstBreakReasons =
        List<String>.from(firstBreakResult['reasons'] ?? const []);

    final EntryEngineSnapshot entryEngine =
        _entryEngine.evaluate(visibleCandles, entryEngineState);

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

    finalScore = _clampScore(finalScore);

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

    confidence = _clampScore(confidence);

    final String scoreClass = _scoreClassFromScore(finalScore);

    String action = _actionFromDecision(
      finalScore: finalScore,
      confidence: confidence,
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
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

}
