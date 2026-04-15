import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/detail_data_service.dart';
import '../services/decision_engine.dart';
import '../services/entry_engine.dart';
import '../widgets/detail_page_content.dart';

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

      final FinalTradeDecision rawDecision = DecisionEngine.buildFinalTradeDecision(
        oiPriceSignal: widget.oiPriceSignal,
        oiDirection: widget.oiDirection,
        priceDirection: widget.priceDirection,
        orderFlowDirection: widget.orderFlowDirection,
        pumpAnalysis: bundle.pumpAnalysis,
        entryTiming: bundle.entryTiming,
        setupResult: bundle.setupResult,
        visibleCandles: bundle.visibleCandles,
        entryEngineState: _entryEngineState,
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
