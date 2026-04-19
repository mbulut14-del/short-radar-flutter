import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/final_trade_decision_service.dart';
import '../services/unified_coin_analysis_service.dart';
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

  static const Duration _dataRefreshInterval = Duration(seconds: 5);

  Timer? _detailTimer;
  bool detailLoading = true;
  String detailError = '';
  String selectedInterval = '3m';

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
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
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
      final result = await UnifiedCoinAnalysisService.analyze(
        coin: selectedCoin,
        oiDirection: widget.oiDirection,
        priceDirection: widget.priceDirection,
        oiPriceSignal: widget.oiPriceSignal,
        orderFlowDirection: widget.orderFlowDirection,
        selectedInterval: selectedInterval,
      );

      final FinalTradeDecision displayDecision = result.displayDecision;

      if (!mounted) return;
      setState(() {
        selectedCoin = result.coin;
        candles = result.candles;
        visibleCandles = result.candles;
        setupResult = result.setupResult;
        pumpAnalysis = result.pumpAnalysis;
        entryTiming = result.entryTiming;
        finalTradeDecision = displayDecision;
        finalScoreResult = displayDecision.toLegacyScoreResult();
        _openInterestDisplay = _buildOpenInterestDisplay(
          result.coin.openInterest,
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
      finalTradeDecision = null;
      finalScoreResult = null;
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
