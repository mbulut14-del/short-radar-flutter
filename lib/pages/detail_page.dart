import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/analysis_engine.dart';
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

  static final Map<String, List<FinalTradeDecision>> _decisionBuffers = {};
  static final Map<String, DateTime?> _lastDecisionTimes = {};
  static final Map<String, FinalTradeDecision?> _lastDisplayDecisions = {};
  static final Map<String, FinalScoreResult?> _lastLegacyScores = {};
  static final Map<String, EntryEngineState> _entryEngineStates = {};

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

  List<FinalTradeDecision> get _decisionBuffer =>
      _decisionBuffers.putIfAbsent(contractName, () => []);

  DateTime? get _lastDecisionAt => _lastDecisionTimes[contractName];

  set _lastDecisionAt(DateTime? value) {
    _lastDecisionTimes[contractName] = value;
  }

  FinalTradeDecision? get _cachedDisplayDecision =>
      _lastDisplayDecisions[contractName];

  set _cachedDisplayDecision(FinalTradeDecision? value) {
    _lastDisplayDecisions[contractName] = value;
  }

  FinalScoreResult? get _cachedLegacyScore => _lastLegacyScores[contractName];

  set _cachedLegacyScore(FinalScoreResult? value) {
    _lastLegacyScores[contractName] = value;
  }

  EntryEngineState get _entryEngineState =>
      _entryEngineStates.putIfAbsent(contractName, () => EntryEngineState());

  @override
  void initState() {
    super.initState();
    contractName = widget.coinData.name;
    selectedCoin = widget.coinData;
    _openInterestDisplay = _buildOpenInterestDisplay(
      widget.coinData.openInterest,
      widget.oiDirection,
    );

    finalTradeDecision = _cachedDisplayDecision;
    finalScoreResult = _cachedLegacyScore;

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
  }

  double _bodySize(CandleData candle) {
    return (candle.close - candle.open).abs();
  }

  double _rangeSize(CandleData candle) {
    return (candle.high - candle.low).abs();
  }

  double _upperWickSize(CandleData candle) {
    final double bodyTop =
        candle.close >= candle.open ? candle.close : candle.open;
    return candle.high - bodyTop;
  }

  bool _hasBigUpperWick(CandleData candle, {double minRatio = 0.35}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    return (_upperWickSize(candle) / range) >= minRatio;
  }

  bool _hasWeakClose(CandleData candle, {double maxCloseRatio = 0.60}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    final double closePosition = (candle.close - candle.low) / range;
    return closePosition <= maxCloseRatio;
  }

  bool _hasVolumeExpansion(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];

    final double avgPrevVolume = (prev.volume + prev2.volume + prev3.volume) / 3;
    if (avgPrevVolume <= 0) return false;

    return last.volume >= avgPrevVolume * 1.15;
  }

  Map<String, dynamic> _detectPriceStructure(List<CandleData> candles) {
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

  Map<String, dynamic> _detectFirstBreak(List<CandleData> candles) {
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

  bool _detectPumpNow(List<CandleData> candles) {
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

  bool _detectWeaknessNow(List<CandleData> candles) {
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

  bool _detectBreakdownNow(List<CandleData> candles) {
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

  bool _detectRecoveryInvalidation(List<CandleData> candles) {
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

  EntryEngineSnapshot _evaluateEntryEngine(List<CandleData> candles) {
    final EntryEngineState state = _entryEngineState;

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
        'Kırılma denemesi sonrası güçlü yukarı toparlama geldi.'
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

    score = _clampScore(score);

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

  String _determineTradeBias({
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
        _evaluateEntryEngine(visibleCandles);

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

  void _resetDecisionEngine() {
    _decisionBuffers.remove(contractName);
    _lastDecisionTimes.remove(contractName);
    _lastDisplayDecisions.remove(contractName);
    _lastLegacyScores.remove(contractName);
    _entryEngineStates.remove(contractName);

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

  FinalTradeDecision _resolveDecisionForDisplay(FinalTradeDecision rawDecision) {
    _pushDecisionToBuffer(rawDecision);

    final DateTime now = DateTime.now();
    final FinalTradeDecision? cachedDecision = _cachedDisplayDecision;
    final DateTime? lastDecisionAt = _lastDecisionAt;

    if (cachedDecision == null || lastDecisionAt == null) {
      _lastDecisionAt = now;
      _cachedDisplayDecision = rawDecision;
      _cachedLegacyScore = rawDecision.toLegacyScoreResult();
      return rawDecision;
    }

    if (now.difference(lastDecisionAt) < _decisionInterval) {
      return cachedDecision;
    }

    final FinalTradeDecision filteredDecision =
        _buildBufferedDecision(_decisionBuffer);

    _lastDecisionAt = now;
    _cachedDisplayDecision = filteredDecision;
    _cachedLegacyScore = filteredDecision.toLegacyScoreResult();

    _decisionBuffer
      ..clear()
      ..add(filteredDecision);

    return filteredDecision;
  }

  bool _shouldTriggerShortAlert(FinalTradeDecision result) {
    if (result.finalScore < 85) return false;
    if (result.tradeBias != 'SHORT') return false;
    if (result.action != 'ENTER SHORT' && result.action != 'PREPARE SHORT') {
      return false;
    }
    if (widget.orderFlowDirection == 'BUY_PRESSURE') return false;
    if (widget.oiPriceSignal == 'SHORT_SQUEEZE') return false;
    if (widget.oiPriceSignal == 'EARLY_ACCUMULATION') return false;
    return true;
  }

  Future<void> _triggerTestNotification() async {
    if (!_notificationsReady) return;

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'short_radar_test_channel',
        'Short Radar Test',
        channelDescription: 'Bildirim test kanalı',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        999001,
        'TEST',
        'Çalışıyor mu?',
        notificationDetails,
      );
    } catch (_) {}
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

      _cachedDisplayDecision = displayDecision;
      _cachedLegacyScore = displayDecision.toLegacyScoreResult();

      await _triggerTestNotification();

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
