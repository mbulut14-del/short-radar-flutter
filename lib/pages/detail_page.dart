import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/detail_data_service.dart';
import '../widgets/detail_page_content.dart';

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

class DetailPage extends StatefulWidget {
  final CoinRadarData coinData;
  final CoinRadarData? leaderData;
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;

  const DetailPage({
    super.key,
    required this.coinData,
    required this.oiDirection,
    this.leaderData,
    this.priceDirection = 'FLAT',
    this.oiPriceSignal = 'NEUTRAL',
    this.orderFlowDirection = 'NEUTRAL',
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage>
    with SingleTickerProviderStateMixin {
  static final Map<String, DateTime> _lastAlertTimes = {};

  static const Duration _dataRefreshInterval = Duration(seconds: 5);
  static const Duration _decisionInterval = Duration(minutes: 3);

  Timer? _detailTimer;
  bool detailLoading = true;
  String detailError = '';
  String selectedInterval = '1h';

  late AnimationController _spinnerController;
  late final String contractName;
  late CoinRadarData selectedCoin;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<FinalTradeDecision> _decisionBuffer = [];
  DateTime? _lastDecisionAt;

  List<CandleData> candles = [];
  List<CandleData> visibleCandles = [];

  ShortSetupResult? setupResult;
  PumpAnalysisResult? pumpAnalysis;
  EntryTimingResult? entryTiming;
  FinalScoreResult? finalScoreResult;
  FinalTradeDecision? finalTradeDecision;

  bool _isFetchingDetail = false;
  bool _notificationsReady = false;
  String _openInterestDisplay = '-';

  @override
  void initState() {
    super.initState();
    contractName = widget.coinData.name;
    selectedCoin = widget.coinData;
    _openInterestDisplay = _buildOpenInterestDisplay(
      widget.coinData.openInterest,
      widget.oiDirection,
    );

    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _initLocalNotifications();
    fetchDetail();

    _detailTimer = Timer.periodic(_dataRefreshInterval, (_) {
      if (mounted) {
        fetchDetail(showLoader: false);
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(initSettings);
      _notificationsReady = true;
    } catch (_) {
      _notificationsReady = false;
    }
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    _spinnerController.dispose();
    super.dispose();
  }

  String _formatOI(double value) {
    if (value <= 0) return '-';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _buildOpenInterestDisplay(double currentOI, String direction) {
    final String formatted = _formatOI(currentOI);

    switch (direction) {
      case 'UP':
        return '$formatted ↑';
      case 'DOWN':
        return '$formatted ↓';
      default:
        return '$formatted -';
    }
  }

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

    if (pumpAnalysis != null) {
      final String summary = _safeLower(_extractDynamicSummary(pumpAnalysis));
      final String signal = _safeLower(_extractDynamicSignal(pumpAnalysis));

      if (summary.contains('liq')) score += 8;
      if (summary.contains('short')) score += 4;
      if (signal.contains('pump')) score += 4;
    }

    if (setupResult != null) {
      final String summary = _safeLower(_extractDynamicSummary(setupResult));
      if (summary.contains('squeeze')) score -= 10;
      if (summary.contains('risk')) score -= 6;
      if (summary.contains('uygun')) score += 4;
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

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION') {
      return 'LONG';
    }

    int shortVotes = 0;
    int longVotes = 0;

    if (oiDirection == 'UP') {
      shortVotes += 1;
    } else if (oiDirection == 'DOWN') {
      longVotes += 1;
    }

    if (priceDirection == 'DOWN') {
      shortVotes += 2;
    } else if (priceDirection == 'UP') {
      longVotes += 2;
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      shortVotes += 2;
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      longVotes += 2;
    }

    if (shortVotes > longVotes) return 'SHORT';
    if (longVotes > shortVotes) return 'LONG';
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

    final bool longAligned =
        tradeBias == 'LONG' &&
        priceDirection == 'UP' &&
        orderFlowDirection == 'BUY_PRESSURE';

    if (shortAligned || longAligned) {
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

    if (tradeBias == 'SHORT' && oiPriceSignal == 'SHORT_SQUEEZE') {
      confidence -= 20;
    }

    if (tradeBias == 'SHORT' && orderFlowDirection == 'BUY_PRESSURE') {
      confidence -= 16;
    }

    if (tradeBias == 'LONG' && orderFlowDirection == 'SELL_PRESSURE') {
      confidence -= 16;
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
  }) {
    if (finalScore < 40) {
      return 'NO TRADE';
    }

    if (finalScore < 70) {
      if (tradeBias == 'SHORT') return 'WATCH';
      if (tradeBias == 'LONG') return 'WATCH';
      return 'WAIT FOR CONFIRMATION';
    }

    if (finalScore < 85) {
      if (confidence < 60) return 'WAIT FOR CONFIRMATION';
      if (tradeBias == 'SHORT') return 'PREPARE SHORT';
      if (tradeBias == 'LONG') return 'PREPARE LONG';
      return 'WATCH';
    }

    if (confidence < 68) {
      return 'WAIT FOR CONFIRMATION';
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      return 'WAIT FOR CONFIRMATION';
    }

    if (tradeBias == 'SHORT') return 'ENTER SHORT';
    if (tradeBias == 'LONG') return 'ENTER LONG';
    return 'WATCH';
  }

  List<String> _buildMarketReadBullets({
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String orderFlowDirection,
    required double volumeScore,
    required double momentumScore,
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
      bullets.add('Fiyat yukarı gidiyor, tek başına short için risk oluşturabilir.');
    } else {
      bullets.add('Fiyat yatay seyirde, net kırılım henüz gelmemiş olabilir.');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      bullets.add('Order flow satış baskısını destekliyor.');
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      bullets.add('Order flow alıcı baskısını gösteriyor.');
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
        bullets.add('Erken dağıtım sinyali oluşuyor olabilir.');
        break;
      case 'EARLY_ACCUMULATION':
        bullets.add('Erken toplama sinyali short için ters risk üretebilir.');
        break;
      case 'SHORT_SQUEEZE':
        bullets.add('Kısa pozisyonlar sıkışıyor olabilir; squeeze riski yüksek.');
        break;
      default:
        bullets.add('Ana sinyal nötr bölgede, ek teyit gerekiyor.');
        break;
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
  }) {
    final List<String> warnings = [];

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      warnings.add('Short squeeze riski var.');
    }

    if (tradeBias == 'SHORT' && orderFlowDirection == 'BUY_PRESSURE') {
      warnings.add('Short bias ile order flow çelişiyor.');
    }

    if (tradeBias == 'LONG' && orderFlowDirection == 'SELL_PRESSURE') {
      warnings.add('Long bias ile order flow çelişiyor.');
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
  }) {
    final List<String> notes = [];

    if (action == 'ENTER SHORT') {
      notes.add('Kurulum güçlü; agresif short giriş düşünülebilir.');
      notes.add('Stop bölgesi son yukarı wick üstü izlenebilir.');
    } else if (action == 'PREPARE SHORT') {
      notes.add('Short hazırlığı var; tetik için ek fiyat teyidi beklenmeli.');
      notes.add('Zayıflayan mum yapısı gelirse giriş kalitesi artar.');
    } else if (action == 'ENTER LONG') {
      notes.add('Long tarafı güçleniyor; giriş fırsatı oluşmuş olabilir.');
      notes.add('Stop bölgesi son dip altı izlenebilir.');
    } else if (action == 'PREPARE LONG') {
      notes.add('Long hazırlığı var; net kırılım beklemek daha sağlıklı.');
      notes.add('Alıcı baskısı sürerse giriş kalitesi artar.');
    } else if (action == 'WAIT FOR CONFIRMATION') {
      notes.add('Kurulum var ama teyit tamamlanmadan acele giriş riskli.');
    } else if (action == 'WATCH') {
      notes.add('Şimdilik izleme modunda kalmak daha doğru.');
    } else {
      notes.add('Mevcut görüntü işlem kalitesi için yeterli değil.');
    }

    if (oiPriceSignal == 'FAKE_PUMP') {
      notes.add('Yukarı spike sonrası zayıflama short için tetik olabilir.');
    }

    if (oiPriceSignal == 'EARLY_DISTRIBUTION') {
      notes.add('Erken dağıtım sinyali nedeniyle sabırlı bekleme avantajlı olabilir.');
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
        notes.add('Entry timing tarafı girişe daha yakın görünüyor.');
      }
    }

    return notes;
  }

  List<String> _buildTriggerConditions({
    required String tradeBias,
    required String oiPriceSignal,
    required String priceDirection,
    required String orderFlowDirection,
  }) {
    final List<String> triggers = [];

    if (tradeBias == 'SHORT') {
      triggers.add('Zayıf kapanış veya breakdown teyidi');
      triggers.add('Satış baskısının devam etmesi');
      if (priceDirection == 'UP' || oiPriceSignal == 'FAKE_PUMP') {
        triggers.add('Yukarı fitil sonrası reddedilme');
      }
    } else if (tradeBias == 'LONG') {
      triggers.add('Kırılım üstü kapanış');
      triggers.add('Alıcı baskısının devam etmesi');
      if (orderFlowDirection == 'BUY_PRESSURE') {
        triggers.add('Hacim destekli yukarı devam');
      }
    } else {
      triggers.add('Net yön teyidi');
      triggers.add('Order flow baskısının belirginleşmesi');
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

    final double finalScore = _weightedFinalScore(
      oiScore: oiScore,
      priceScore: priceScore,
      orderFlowScore: orderFlowScore,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
    );

    final String tradeBias = _determineTradeBias(
      oiPriceSignal: oiPriceSignal,
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
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

    final String scoreClass = _scoreClassFromScore(finalScore);
    final String action = _actionFromDecision(
      finalScore: finalScore,
      confidence: confidence,
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
    );

    final List<String> marketReadBullets = _buildMarketReadBullets(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      volumeScore: volumeScore,
      momentumScore: momentumScore,
    );

    final List<String> warnings = _buildWarnings(
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      confidence: confidence,
      volumeScore: volumeScore,
      liquidationScore: liquidationScore,
      momentumScore: momentumScore,
    );

    final List<String> entryNotes = _buildEntryNotes(
      tradeBias: tradeBias,
      action: action,
      confidence: confidence,
      oiPriceSignal: oiPriceSignal,
      entryTiming: entryTiming,
    );

    final List<String> triggerConditions = _buildTriggerConditions(
      tradeBias: tradeBias,
      oiPriceSignal: oiPriceSignal,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
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

  void _resetDecisionEngine() {
    _decisionBuffer.clear();
    _lastDecisionAt = null;
    finalTradeDecision = null;
    finalScoreResult = null;
  }

  int get _maxBufferLength =>
      (_decisionInterval.inSeconds / _dataRefreshInterval.inSeconds).round();

  void _pushDecisionToBuffer(FinalTradeDecision decision) {
    _decisionBuffer.add(decision);

    while (_decisionBuffer.length > _maxBufferLength) {
      _decisionBuffer.removeAt(0);
    }
  }

  double _averageScore(
    List<FinalTradeDecision> decisions,
    double Function(FinalTradeDecision item) getter,
  ) {
    if (decisions.isEmpty) return 0;

    double total = 0;
    for (final item in decisions) {
      total += getter(item);
    }
    return _clampScore(total / decisions.length);
  }

  String _dominantText(
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

  List<String> _mergeUniqueLists({
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

  FinalTradeDecision _buildBufferedDecision(
    List<FinalTradeDecision> decisions,
  ) {
    final FinalTradeDecision latest = decisions.last;
    final FinalTradeDecision previous =
        decisions.length >= 2 ? decisions[decisions.length - 2] : latest;

    final double averageFinalScore =
        _averageScore(decisions, (item) => item.finalScore);
    final double averageConfidence =
        _averageScore(decisions, (item) => item.confidence);

    final double averageOiScore = _averageScore(decisions, (item) => item.oiScore);
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

    String action = _actionFromDecision(
      finalScore: averageFinalScore,
      confidence: averageConfidence,
      tradeBias: dominantBias,
      oiPriceSignal: dominantSignal,
    );

    final bool strongPersistence =
        latest.finalScore >= 80 && previous.finalScore >= 80;
    final bool strongBiasPersistence =
        latest.tradeBias == dominantBias && previous.tradeBias == dominantBias;

    if ((action == 'ENTER SHORT' || action == 'ENTER LONG') &&
        (!strongPersistence || !strongBiasPersistence)) {
      if (dominantBias == 'SHORT') {
        action = 'PREPARE SHORT';
      } else if (dominantBias == 'LONG') {
        action = 'PREPARE LONG';
      } else {
        action = 'WAIT FOR CONFIRMATION';
      }
    }

    final String scoreClass = _scoreClassFromScore(averageFinalScore);

    final List<String> marketReadBullets = _mergeUniqueLists(
      priorityItems: [
        'Karar 3 dakikalık filtrelenmiş veri penceresine göre üretildi.',
        ...latest.marketReadBullets,
      ],
      secondaryItems:
          decisions.length > 2 ? decisions[decisions.length - 2].marketReadBullets : const [],
      maxItems: 7,
    );

    final List<String> warnings = _mergeUniqueLists(
      priorityItems: [
        if (!strongPersistence) 'Son iki ölçüm tam güçte hizalanmadı.',
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
          decisions.length > 2 ? decisions[decisions.length - 2].triggerConditions : const [],
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

  FinalTradeDecision _resolveDecisionForDisplay(FinalTradeDecision rawDecision) {
    _pushDecisionToBuffer(rawDecision);

    final DateTime now = DateTime.now();

    if (finalTradeDecision == null || _lastDecisionAt == null) {
      _lastDecisionAt = now;
      return rawDecision;
    }

    if (now.difference(_lastDecisionAt!) < _decisionInterval) {
      return finalTradeDecision!;
    }

    _lastDecisionAt = now;
    return _buildBufferedDecision(_decisionBuffer);
  }

  bool _shouldTriggerShortAlert(FinalTradeDecision result) {
    if (result.finalScore < 85) return false;
    if (result.tradeBias != 'SHORT') return false;
    if (result.action != 'ENTER SHORT' && result.action != 'PREPARE SHORT') {
      return false;
    }
    if (widget.orderFlowDirection == 'BUY_PRESSURE') return false;
    if (widget.oiPriceSignal == 'SHORT_SQUEEZE') return false;
    return true;
  }

  Future<void> _triggerShortAlert(FinalTradeDecision result) async {
    final DateTime now = DateTime.now();
    final DateTime? lastAlertAt = _lastAlertTimes[contractName];

    if (lastAlertAt != null &&
        now.difference(lastAlertAt) < const Duration(minutes: 10)) {
      return;
    }

    _lastAlertTimes[contractName] = now;

    try {
      await HapticFeedback.heavyImpact();
      await HapticFeedback.vibrate();
    } catch (_) {}

    if (!_notificationsReady) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'short_setup_alerts',
      'Short Setup Alerts',
      channelDescription: 'Final score eşiği geçen short fırsat alarmları',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      ticker: 'short-alert',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        contractName.hashCode,
        'Short setup hazır olabilir',
        '$contractName • Score ${result.finalScore.toStringAsFixed(0)} • ${result.scoreClass}',
        notificationDetails,
      );
    } catch (_) {}
  }

  Future<void> fetchDetail({bool showLoader = true}) async {
    if (_isFetchingDetail) return;
    _isFetchingDetail = true;

    if (showLoader && mounted) {
      setState(() {
        detailLoading = true;
        detailError = '';
      });
    }

    try {
      final bundle = await DetailDataService.load(
        contractName: contractName,
        selectedInterval: selectedInterval,
        fallbackCoin: selectedCoin,
      );

      final FinalTradeDecision rawDecision = _buildFinalTradeDecision(
        oiPriceSignal: widget.oiPriceSignal,
        oiDirection: widget.oiDirection,
        priceDirection: widget.priceDirection,
        orderFlowDirection: widget.orderFlowDirection,
        pumpAnalysis: bundle.pumpAnalysis,
        entryTiming: bundle.entryTiming,
        setupResult: bundle.setupResult,
        visibleCandles: bundle.visibleCandles,
      );

      final FinalTradeDecision displayDecision =
          _resolveDecisionForDisplay(rawDecision);

      if (!mounted) return;
      setState(() {
        selectedCoin = bundle.selectedCoin;
        candles = bundle.candles;
        visibleCandles = bundle.visibleCandles;
        setupResult = bundle.setupResult;
        pumpAnalysis = bundle.pumpAnalysis;
        entryTiming = bundle.entryTiming;
        finalTradeDecision = displayDecision;
        finalScoreResult = displayDecision.toLegacyScoreResult();
        _openInterestDisplay = _buildOpenInterestDisplay(
          bundle.selectedCoin.openInterest,
          widget.oiDirection,
        );
        detailLoading = false;
        detailError = '';
      });

      if (_shouldTriggerShortAlert(displayDecision)) {
        await _triggerShortAlert(displayDecision);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        detailLoading = false;
        detailError = 'İstek zaman aşımına uğradı';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        detailLoading = false;
        detailError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _isFetchingDetail = false;
    }
  }

  Widget _spinnerRing() {
    Color color = Colors.greenAccent;
    if (detailError.isNotEmpty) {
      color = Colors.redAccent;
    } else if (detailLoading) {
      color = Colors.orangeAccent;
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: RotationTransition(
        turns: _spinnerController,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }

  Future<void> _handleIntervalChange(String value) async {
    if (selectedInterval == value) return;

    setState(() {
      selectedInterval = value;
      _resetDecisionEngine();
    });

    await fetchDetail();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = setupResult != null && visibleCandles.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Image.asset(
                'assets/bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: DetailPageContent(
              contractName: contractName,
              spinner: _spinnerRing(),
              selectedInterval: selectedInterval,
              onIntervalChanged: _handleIntervalChange,
              detailError: detailError,
              detailLoading: detailLoading,
              hasData: hasData,
              setupResult: setupResult,
              pumpAnalysis: pumpAnalysis,
              entryTiming: entryTiming,
              visibleCandles: visibleCandles,
              selectedCoin: selectedCoin,
              openInterestDisplay: _openInterestDisplay,
              oiDirection: widget.oiDirection,
              priceDirection: widget.priceDirection,
              oiPriceSignal: widget.oiPriceSignal,
              orderFlowDirection: widget.orderFlowDirection,
              finalScore: finalScoreResult?.score,
              finalScoreLabel: finalScoreResult?.label,
              finalScoreSummary: finalScoreResult?.summary,
              decisionConfidence: finalTradeDecision?.confidence,
              decisionPrimarySignal: finalTradeDecision?.primarySignal,
              decisionTradeBias: finalTradeDecision?.tradeBias,
              decisionAction: finalTradeDecision?.action,
              oiComponentScore: finalTradeDecision?.oiScore,
              priceComponentScore: finalTradeDecision?.priceScore,
              orderFlowComponentScore: finalTradeDecision?.orderFlowScore,
              volumeComponentScore: finalTradeDecision?.volumeScore,
              liquidationComponentScore: finalTradeDecision?.liquidationScore,
              momentumComponentScore: finalTradeDecision?.momentumScore,
              marketReadBullets: finalTradeDecision?.marketReadBullets,
              entryNotes: finalTradeDecision?.entryNotes,
              warnings: finalTradeDecision?.warnings,
              triggerConditions: finalTradeDecision?.triggerConditions,
            ),
          ),
        ],
      ),
    );
  }
}
