import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';

import 'models/coin_radar_data.dart';
import 'models/final_trade_decision.dart';

import 'services/unified_coin_analysis_service.dart';

late final FlutterLocalNotificationsPlugin notificationsPlugin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  notificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const initSettings = InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(initSettings);

  await _requestNotificationPermission();
  await _startForegroundService();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermission() async {
  final androidImplementation =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();
  }
}

Future<void> _startForegroundService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'short_service',
      channelName: 'Short Radar Service',
      channelDescription: 'Piyasa izleniyor',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
    ),
  );

  final isRunning = await FlutterForegroundTask.isRunningService;
  if (isRunning) return;

  await FlutterForegroundTask.startService(
    notificationTitle: 'Short Radar aktif',
    notificationText: 'Piyasa taranıyor...',
    callback: startCallback,
  );
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

class BackgroundSignalSnapshot {
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;
  final String combinedSignal;
  final String stableCombinedSignal;

  const BackgroundSignalSnapshot({
    required this.oiDirection,
    required this.priceDirection,
    required this.oiPriceSignal,
    required this.orderFlowDirection,
    required this.combinedSignal,
    required this.stableCombinedSignal,
  });
}

class ShortRadarTaskHandler extends TaskHandler {
  late FlutterLocalNotificationsPlugin _localNotifications;

  final Map<String, DateTime> _lastNotificationTimes = {};
  final Map<String, FinalTradeDecision> _centralDecisionMap = {};

  final Map<String, List<double>> _oiHistory = {};
  final Map<String, List<double>> _priceHistory = {};

  final Map<String, String> _oiDirectionMap = {};
  final Map<String, String> _priceDirectionMap = {};
  final Map<String, String> _oiPriceSignalMap = {};

  final Map<String, String> _orderFlowMap = {};
  final Map<String, double> _bestBidPriceMap = {};
  final Map<String, double> _bestAskPriceMap = {};
  final Map<String, double> _bestBidSizeMap = {};
  final Map<String, double> _bestAskSizeMap = {};

  final Map<String, String> _combinedSignalMap = {};
  final Map<String, String> _stableCombinedSignalMap = {};
  final Map<String, int> _signalStreakMap = {};

  final Map<String, List<FinalTradeDecision>> _decisionBuffers = {};
  final Map<String, DateTime?> _lastDecisionTimes = {};
  final Map<String, FinalTradeDecision?> _lastDisplayDecisions = {};

  final Set<String> _desiredBookTickerSymbols = <String>{};
  final Set<String> _subscribedBookTickerSymbols = <String>{};

  WebSocket? _bookTickerSocket;
  StreamSubscription<dynamic>? _bookTickerSubscription;
  Timer? _bookTickerReconnectTimer;
  bool _isConnectingBookTicker = false;
  bool _manuallyClosedBookTicker = false;
  bool _isCheckingMarket = false;

  static const int _historyLimit = 360;
  static const String _gateUsdtWsUrl = 'wss://fx-ws.gateio.ws/v4/ws/usdt';
  static const int _alertScoreThreshold = 85;
  static const Duration _alertCooldown = Duration(minutes: 15);
  static const int _stableSignalRequiredRepeats = 2;
  static const Duration _dataRefreshInterval = Duration(seconds: 5);
  static const Duration _decisionInterval = Duration(minutes: 3);

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
    await _connectBookTicker();
    await _checkMarket();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    await _checkMarket();
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    _bookTickerReconnectTimer?.cancel();
    _bookTickerSubscription?.cancel();
    _manuallyClosedBookTicker = true;
    _bookTickerSocket?.close();
  }

  Future<void> _checkMarket() async {
    if (_isCheckingMarket) return;
    _isCheckingMarket = true;

    try {
      final response = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return;

      final List<dynamic> parsed = json.decode(response.body);

      final List<CoinRadarData> rawCoins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (rawCoins.isEmpty) return;

      final Map<String, BackgroundSignalSnapshot> snapshots = {};
      final List<CoinRadarData> preparedCoins = rawCoins.map((coin) {
        _updateOiHistory(coin.name, coin.openInterest);
        _updatePriceHistory(coin.name, coin.lastPrice);

        _updateOrderFlowForSymbol(coin.name);

        final BackgroundSignalSnapshot snapshot =
            _buildSignalSnapshot(coin.name);
        snapshots[coin.name] = snapshot;

        return _withOiDirection(coin, snapshot.oiDirection);
      }).toList();

      final List<CoinRadarData> sortedByChange = [...preparedCoins]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final List<CoinRadarData> preliminaryTopCoins =
          sortedByChange.take(10).toList();

      final List<CoinRadarData> topCoins = await Future.wait(
        preliminaryTopCoins.map(
          (coin) => _enrichCoinWithCentralDecision(
            coin,
            snapshots[coin.name]!,
          ),
        ),
      );

      final List<CoinRadarData> sortedByScore = [...topCoins]
        ..sort((a, b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return b.changePercent.compareTo(a.changePercent);
        });

      final List<CoinRadarData> alertCandidates =
          sortedByScore.take(10).toList();

      _desiredBookTickerSymbols
        ..clear()
        ..addAll(topCoins.map((e) => e.name));

      _syncBookTickerSubscriptions();

      await _checkAndSendAlerts(alertCandidates);
    } catch (e) {
      debugPrint('BACKGROUND ERROR: $e');
    } finally {
      _isCheckingMarket = false;
    }
  }

  void _updateOiHistory(String symbol, double oi) {
    final history = _oiHistory.putIfAbsent(symbol, () => <double>[]);
    history.add(oi);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  void _updatePriceHistory(String symbol, double price) {
    final history = _priceHistory.putIfAbsent(symbol, () => <double>[]);
    history.add(price);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  String _calculateDirectionFromHistory(List<double>? history) {
    if (history == null || history.length < 2) {
      return 'FLAT';
    }

    final double first = history.first;
    final double last = history.last;

    if (first <= 0) return 'FLAT';

    final double changePercent = ((last - first) / first) * 100;

    if (changePercent > 1) return 'UP';
    if (changePercent < -1) return 'DOWN';
    return 'FLAT';
  }

  String _calculateOiDirection(String symbol) {
    return _calculateDirectionFromHistory(_oiHistory[symbol]);
  }

  String _calculatePriceDirection(String symbol) {
    return _calculateDirectionFromHistory(_priceHistory[symbol]);
  }

  String _calculateOiPriceSignal({
    required String oiDirection,
    required String priceDirection,
  }) {
    if (oiDirection == 'UP' && priceDirection == 'DOWN') {
      return 'STRONG_SHORT';
    }
    if (oiDirection == 'UP' && priceDirection == 'UP') {
      return 'PUMP_RISK';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'UP') {
      return 'SHORT_SQUEEZE';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'DOWN') {
      return 'WEAK_DROP';
    }
    return 'NEUTRAL';
  }

  String _calculateOrderFlow(double bid, double ask) {
    if (bid > ask * 1.2) return 'BUY_PRESSURE';
    if (ask > bid * 1.2) return 'SELL_PRESSURE';
    return 'NEUTRAL';
  }

  void _updateOrderFlowForSymbol(String symbol) {
    final double bidSize = _bestBidSizeMap[symbol] ?? 0;
    final double askSize = _bestAskSizeMap[symbol] ?? 0;

    if (bidSize <= 0 && askSize <= 0) {
      _orderFlowMap[symbol] = 'NEUTRAL';
      return;
    }

    _orderFlowMap[symbol] = _calculateOrderFlow(bidSize, askSize);
  }

  String _calculateCombinedSignal({
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String orderFlowDirection,
  }) {
    if (oiDirection == 'UP' &&
        priceDirection == 'DOWN' &&
        orderFlowDirection == 'SELL_PRESSURE') {
      return 'STRONG_SHORT';
    }

    if (oiDirection == 'UP' &&
        priceDirection == 'UP' &&
        orderFlowDirection == 'SELL_PRESSURE') {
      return 'FAKE_PUMP';
    }

    if (oiDirection == 'DOWN' &&
        priceDirection == 'UP' &&
        orderFlowDirection == 'BUY_PRESSURE') {
      return 'SHORT_SQUEEZE';
    }

    if (oiDirection == 'DOWN' &&
        priceDirection == 'DOWN' &&
        orderFlowDirection == 'SELL_PRESSURE') {
      return 'WEAK_DROP';
    }

    if (oiDirection == 'FLAT' &&
        priceDirection == 'FLAT' &&
        orderFlowDirection == 'BUY_PRESSURE') {
      return 'EARLY_ACCUMULATION';
    }

    if (oiDirection == 'FLAT' &&
        priceDirection == 'FLAT' &&
        orderFlowDirection == 'SELL_PRESSURE') {
      return 'EARLY_DISTRIBUTION';
    }

    if (oiPriceSignal != 'NEUTRAL' && orderFlowDirection == 'SELL_PRESSURE') {
      return oiPriceSignal;
    }

    return 'NEUTRAL';
  }

  String _stabilizeCombinedSignal(String symbol, String newSignal) {
    final String previousSignal = _combinedSignalMap[symbol] ?? 'NEUTRAL';

    if (previousSignal == newSignal) {
      _signalStreakMap[symbol] = (_signalStreakMap[symbol] ?? 0) + 1;
    } else {
      _signalStreakMap[symbol] = 1;
    }

    _combinedSignalMap[symbol] = newSignal;

    final int streak = _signalStreakMap[symbol] ?? 1;
    final String previousStable = _stableCombinedSignalMap[symbol] ?? 'NEUTRAL';

    if (streak >= _stableSignalRequiredRepeats) {
      _stableCombinedSignalMap[symbol] = newSignal;
      return newSignal;
    }

    return previousStable;
  }

  BackgroundSignalSnapshot _buildSignalSnapshot(String symbol) {
    final String oiDirection = _calculateOiDirection(symbol);
    final String priceDirection = _calculatePriceDirection(symbol);
    final String oiPriceSignal = _calculateOiPriceSignal(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
    );
    final String orderFlowDirection = _orderFlowMap[symbol] ?? 'NEUTRAL';

    final String combinedSignal = _calculateCombinedSignal(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
    );

    final String stableCombinedSignal =
        _stabilizeCombinedSignal(symbol, combinedSignal);

    _oiDirectionMap[symbol] = oiDirection;
    _priceDirectionMap[symbol] = priceDirection;
    _oiPriceSignalMap[symbol] = oiPriceSignal;

    return BackgroundSignalSnapshot(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      combinedSignal: combinedSignal,
      stableCombinedSignal: stableCombinedSignal,
    );
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  CoinRadarData _withOiDirection(CoinRadarData coin, String direction) {
    return CoinRadarData(
      name: coin.name,
      changePercent: coin.changePercent,
      fundingRate: coin.fundingRate,
      lastPrice: coin.lastPrice,
      markPrice: coin.markPrice,
      indexPrice: coin.indexPrice,
      volume24h: coin.volume24h,
      openInterest: coin.openInterest,
      oiDirection: direction,
      score: coin.score,
      biasLabel: coin.biasLabel,
      note: coin.note,
    );
  }

  List<FinalTradeDecision> _decisionBufferFor(String symbol) =>
      _decisionBuffers.putIfAbsent(symbol, () => <FinalTradeDecision>[]);

  DateTime? _lastDecisionAtFor(String symbol) => _lastDecisionTimes[symbol];

  void _setLastDecisionAtFor(String symbol, DateTime? value) {
    _lastDecisionTimes[symbol] = value;
  }

  FinalTradeDecision? _cachedDisplayDecisionFor(String symbol) =>
      _lastDisplayDecisions[symbol];

  void _setCachedDisplayDecisionFor(
    String symbol,
    FinalTradeDecision? value,
  ) {
    _lastDisplayDecisions[symbol] = value;
  }

  void _pushDecisionToBuffer(String symbol, FinalTradeDecision decision) {
    final List<FinalTradeDecision> buffer = _decisionBufferFor(symbol);
    buffer.add(decision);

    final int maxItems =
        (_decisionInterval.inSeconds ~/ _dataRefreshInterval.inSeconds) + 2;

    while (buffer.length > maxItems) {
      buffer.removeAt(0);
    }
  }

  double _clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
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

  String _scoreClassFromScore(double finalScore) {
    if (finalScore >= 85) return 'Güçlü fırsat';
    if (finalScore >= 70) return 'Kurulum var';
    if (finalScore >= 40) return 'İzlenmeli';
    return 'Zayıf';
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
          decisions.length > 2 ? decisions[decisions.length - 2].marketReadBullets : const [],
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

  FinalTradeDecision _resolveDecisionForDisplay(
    String symbol,
    FinalTradeDecision rawDecision,
  ) {
    _pushDecisionToBuffer(symbol, rawDecision);

    final DateTime now = DateTime.now();
    final FinalTradeDecision? cachedDecision = _cachedDisplayDecisionFor(symbol);
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

  Future<CoinRadarData> _enrichCoinWithCentralDecision(
    CoinRadarData coin,
    BackgroundSignalSnapshot snapshot,
  ) async {
    try {
      final result = await UnifiedCoinAnalysisService.analyze(
        coin: coin,
        oiDirection: snapshot.oiDirection,
        priceDirection: snapshot.priceDirection,
        oiPriceSignal: snapshot.stableCombinedSignal,
        orderFlowDirection: snapshot.orderFlowDirection,
      );

      final FinalTradeDecision rawDecision = result.displayDecision;
      final FinalTradeDecision displayDecision =
          _resolveDecisionForDisplay(coin.name, rawDecision);

      _centralDecisionMap[coin.name] = displayDecision;

      return CoinRadarData(
        name: coin.name,
        changePercent: coin.changePercent,
        fundingRate: coin.fundingRate,
        lastPrice: coin.lastPrice,
        markPrice: coin.markPrice,
        indexPrice: coin.indexPrice,
        volume24h: coin.volume24h,
        openInterest: coin.openInterest,
        oiDirection: snapshot.oiDirection,
        score: displayDecision.finalScore.round(),
        biasLabel: displayDecision.scoreClass,
        note: displayDecision.summary,
      );
    } catch (e) {
      debugPrint('BACKGROUND DECISION ERROR [${coin.name}]: $e');

      return CoinRadarData(
        name: coin.name,
        changePercent: coin.changePercent,
        fundingRate: coin.fundingRate,
        lastPrice: coin.lastPrice,
        markPrice: coin.markPrice,
        indexPrice: coin.indexPrice,
        volume24h: coin.volume24h,
        openInterest: coin.openInterest,
        oiDirection: snapshot.oiDirection,
        score: 0,
        biasLabel: 'ERROR',
        note: 'Decision failed',
      );
    }
  }

  bool _canSendNotification(String symbol) {
    final now = DateTime.now();
    final lastTime = _lastNotificationTimes[symbol];

    if (lastTime == null) {
      _lastNotificationTimes[symbol] = now;
      return true;
    }

    if (now.difference(lastTime) >= _alertCooldown) {
      _lastNotificationTimes[symbol] = now;
      return true;
    }

    return false;
  }

  bool _shouldAlertCoin(CoinRadarData coin) {
    final String stableCombinedSignal =
        _stableCombinedSignalMap[coin.name] ?? 'NEUTRAL';
    final String orderFlowDirection = _orderFlowMap[coin.name] ?? 'NEUTRAL';
    final FinalTradeDecision? decision = _centralDecisionMap[coin.name];

    if (coin.score < _alertScoreThreshold) return false;
    if (coin.fundingRate <= 0) return false;
    if (orderFlowDirection == 'BUY_PRESSURE') return false;
    if (stableCombinedSignal == 'SHORT_SQUEEZE') return false;
    if (stableCombinedSignal == 'NEUTRAL') return false;
    if (decision == null) return false;
    if (decision.tradeBias != 'SHORT') return false;
    if (decision.action != 'PREPARE SHORT' &&
        decision.action != 'ENTER SHORT') {
      return false;
    }

    return _canSendNotification(coin.name);
  }

  Future<void> _sendNotification(
    CoinRadarData coin,
    FinalTradeDecision decision,
  ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'short_alert_channel',
        'Short Alerts',
        channelDescription: 'Short radar fırsat bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        ticker: 'short-alert',
      );

      const details = NotificationDetails(android: androidDetails);

      final String body =
          '${coin.name} • Score ${coin.score} • ${decision.action} • ${decision.primarySignal}';

      await _localNotifications.show(
        coin.name.hashCode,
        decision.action == 'ENTER SHORT'
            ? '🔥 SHORT GİRİŞ FIRSATI'
            : '⚠️ SHORT HAZIRLIK',
        body,
        details,
      );
    } catch (e) {
      debugPrint('NOTIFICATION ERROR: $e');
    }
  }

  Future<void> _checkAndSendAlerts(List<CoinRadarData> candidates) async {
    for (final coin in candidates) {
      final FinalTradeDecision? decision = _centralDecisionMap[coin.name];
      if (decision == null) continue;

      if (_shouldAlertCoin(coin)) {
        await _sendNotification(coin, decision);
      }
    }
  }

  Future<void> _connectBookTicker() async {
    if (_isConnectingBookTicker) return;
    if (_bookTickerSocket != null) return;

    _isConnectingBookTicker = true;

    try {
      final socket = await WebSocket.connect(
        _gateUsdtWsUrl,
        headers: const {
          'X-Gate-Channel-Id': 'short-radar-book-ticker-bg',
        },
      );

      socket.pingInterval = const Duration(seconds: 10);

      _bookTickerSocket = socket;
      _subscribedBookTickerSymbols.clear();

      _bookTickerSubscription = socket.listen(
        _handleBookTickerMessage,
        onDone: _handleBookTickerClosed,
        onError: (_) => _handleBookTickerClosed(),
        cancelOnError: true,
      );

      _syncBookTickerSubscriptions();
    } catch (e) {
      debugPrint('BOOK TICKER CONNECT ERROR: $e');
      _scheduleBookTickerReconnect();
    } finally {
      _isConnectingBookTicker = false;
    }
  }

  void _handleBookTickerClosed() {
    _bookTickerSubscription?.cancel();
    _bookTickerSubscription = null;
    _bookTickerSocket = null;
    _subscribedBookTickerSymbols.clear();

    if (!_manuallyClosedBookTicker) {
      _scheduleBookTickerReconnect();
    }
  }

  void _scheduleBookTickerReconnect() {
    _bookTickerReconnectTimer?.cancel();
    _bookTickerReconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectBookTicker();
    });
  }

  void _sendBookTickerMessage({
    required String event,
    required String symbol,
  }) {
    final socket = _bookTickerSocket;
    if (socket == null) return;

    final Map<String, dynamic> message = {
      'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'channel': 'futures.book_ticker',
      'event': event,
      'payload': [symbol],
    };

    socket.add(jsonEncode(message));
  }

  void _syncBookTickerSubscriptions() {
    final socket = _bookTickerSocket;
    if (socket == null) return;

    final Set<String> toSubscribe =
        _desiredBookTickerSymbols.difference(_subscribedBookTickerSymbols);
    final Set<String> toUnsubscribe =
        _subscribedBookTickerSymbols.difference(_desiredBookTickerSymbols);

    for (final symbol in toSubscribe) {
      _sendBookTickerMessage(event: 'subscribe', symbol: symbol);
      _subscribedBookTickerSymbols.add(symbol);
    }

    for (final symbol in toUnsubscribe) {
      _sendBookTickerMessage(event: 'unsubscribe', symbol: symbol);
      _subscribedBookTickerSymbols.remove(symbol);
    }
  }

  void _handleBookTickerMessage(dynamic rawMessage) {
    try {
      final String messageText;
      if (rawMessage is String) {
        messageText = rawMessage;
      } else if (rawMessage is List<int>) {
        messageText = utf8.decode(rawMessage);
      } else {
        return;
      }

      final dynamic decoded = jsonDecode(messageText);
      if (decoded is! Map<String, dynamic>) return;

      if (decoded['channel'] != 'futures.book_ticker') return;
      if (decoded['event'] != 'update') return;

      final dynamic result = decoded['result'];
      if (result is! Map<String, dynamic>) return;

      final String symbol = (result['s'] ?? '').toString();
      if (symbol.isEmpty) return;

      _bestBidPriceMap[symbol] = _parseToDouble(result['b']);
      _bestAskPriceMap[symbol] = _parseToDouble(result['a']);
      _bestBidSizeMap[symbol] = _parseToDouble(result['B']);
      _bestAskSizeMap[symbol] = _parseToDouble(result['A']);

      _updateOrderFlowForSymbol(symbol);

      if (_oiHistory.containsKey(symbol) || _priceHistory.containsKey(symbol)) {
        _buildSignalSnapshot(symbol);
      }
    } catch (_) {}
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Short Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final coin = settings.arguments as CoinRadarData;

          return MaterialPageRoute(
            builder: (_) => DetailPage(
              coinData: coin,
              oiDirection: 'FLAT',
            ),
          );
        }
        return null;
      },
    );
  }
}
