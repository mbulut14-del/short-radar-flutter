import 'dart:async';

import 'package:flutter/material.dart';

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
  Timer? _detailTimer;
  bool detailLoading = true;
  String detailError = '';
  String selectedInterval = '1h';

  late AnimationController _spinnerController;
  late final String contractName;
  late CoinRadarData selectedCoin;

  List<CandleData> candles = [];
  List<CandleData> visibleCandles = [];

  ShortSetupResult? setupResult;
  PumpAnalysisResult? pumpAnalysis;
  EntryTimingResult? entryTiming;
  FinalScoreResult? finalScoreResult;

  bool _isFetchingDetail = false;
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

    fetchDetail();

    _detailTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        fetchDetail(showLoader: false);
      }
    });
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

  double _scoreFromOiPriceSignal(String signal) {
    switch (signal.toUpperCase()) {
      case 'STRONG_SHORT':
        return 24;
      case 'FAKE_PUMP':
        return 22;
      case 'EARLY_DISTRIBUTION':
        return 18;
      case 'WEAK_DROP':
        return 14;
      case 'NEUTRAL':
        return 8;
      case 'SHORT_SQUEEZE':
        return 2;
      case 'EARLY_ACCUMULATION':
        return 1;
      default:
        return 6;
    }
  }

  double _scoreFromDirectionCombo({
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
  }) {
    double score = 0;

    if (oiDirection == 'UP' && priceDirection == 'UP') {
      score -= 6;
    } else if (oiDirection == 'UP' && priceDirection == 'DOWN') {
      score += 12;
    } else if (oiDirection == 'DOWN' && priceDirection == 'UP') {
      score += 8;
    } else if (oiDirection == 'DOWN' && priceDirection == 'DOWN') {
      score += 4;
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      score += 12;
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      score -= 10;
    }

    return score;
  }

  double _scoreFromPumpAnalysis(PumpAnalysisResult? result) {
    if (result == null) return 0;

    final dynamic dynamicResult = result;
    double score = 0;

    try {
      final dynamic rawScore = dynamicResult.score;
      if (rawScore is num) {
        score += rawScore.clamp(0, 100) * 0.24;
      }
    } catch (_) {}

    try {
      final dynamic label = dynamicResult.label;
      if (label is String) {
        final normalized = label.toLowerCase();
        if (normalized.contains('uygun')) score += 10;
        if (normalized.contains('güçlü')) score += 8;
        if (normalized.contains('zayıf')) score -= 8;
      }
    } catch (_) {}

    try {
      final dynamic signal = dynamicResult.signal;
      if (signal is String) {
        final normalized = signal.toLowerCase();
        if (normalized.contains('short')) score += 8;
        if (normalized.contains('pump')) score += 5;
      }
    } catch (_) {}

    return score;
  }

  double _scoreFromEntryTiming(EntryTimingResult? result) {
    if (result == null) return 0;

    final dynamic dynamicResult = result;
    double score = 0;

    try {
      final dynamic timingScore = dynamicResult.score;
      if (timingScore is num) {
        score += timingScore.clamp(0, 100) * 0.18;
      }
    } catch (_) {}

    try {
      final dynamic label = dynamicResult.label;
      if (label is String) {
        final normalized = label.toLowerCase();
        if (normalized.contains('erken')) score += 12;
        if (normalized.contains('hazır')) score += 10;
        if (normalized.contains('uygun')) score += 8;
        if (normalized.contains('geç')) score -= 12;
      }
    } catch (_) {}

    try {
      final dynamic summary = dynamicResult.summary;
      if (summary is String) {
        final normalized = summary.toLowerCase();
        if (normalized.contains('geç')) score -= 8;
        if (normalized.contains('bekle')) score -= 4;
        if (normalized.contains('yakın')) score += 4;
      }
    } catch (_) {}

    return score;
  }

  double _scoreFromShortSetup(ShortSetupResult? result) {
    if (result == null) return 0;

    final dynamic dynamicResult = result;
    double score = 0;

    try {
      final dynamic qualityScore = dynamicResult.score;
      if (qualityScore is num) {
        score += qualityScore.clamp(0, 100) * 0.18;
      }
    } catch (_) {}

    try {
      final dynamic label = dynamicResult.label;
      if (label is String) {
        final normalized = label.toLowerCase();
        if (normalized.contains('güçlü')) score += 10;
        if (normalized.contains('kurulum')) score += 6;
        if (normalized.contains('zayıf')) score -= 10;
      }
    } catch (_) {}

    try {
      final dynamic summary = dynamicResult.summary;
      if (summary is String) {
        final normalized = summary.toLowerCase();
        if (normalized.contains('squeeze')) score -= 10;
        if (normalized.contains('risk')) score -= 6;
        if (normalized.contains('uygun')) score += 5;
      }
    } catch (_) {}

    return score;
  }

  double _scoreFromCandles(List<CandleData> candleList) {
    if (candleList.length < 3) return 0;

    final CandleData last = candleList.last;
    final CandleData prev = candleList[candleList.length - 2];
    final CandleData prev2 = candleList[candleList.length - 3];

    double score = 0;

    final double lastBody = (last.close - last.open).abs();
    final double lastRange = (last.high - last.low).abs();
    final double upperWick = last.high - (last.open > last.close ? last.open : last.close);

    if (last.close < last.open) {
      score += 6;
    }

    if (lastRange > 0) {
      final double upperWickRatio = upperWick / lastRange;
      if (upperWickRatio >= 0.35) {
        score += 8;
      }
    }

    if (last.high > prev.high && last.close < last.high) {
      score += 5;
    }

    if (prev.close >= prev.open && last.close < last.open) {
      score += 5;
    }

    if (prev2.close < prev2.open && prev.close < prev.open && last.close < last.open) {
      score += 6;
    }

    if (lastRange > 0 && lastBody / lastRange < 0.25) {
      score += 3;
    }

    return score;
  }

  double _riskPenalty({
    required String oiPriceSignal,
    required String orderFlowDirection,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
  }) {
    double penalty = 0;

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      penalty += 18;
    }

    if (orderFlowDirection == 'BUY_PRESSURE') {
      penalty += 10;
    }

    if (entryTiming != null) {
      final dynamic dynamicEntry = entryTiming;

      try {
        final dynamic label = dynamicEntry.label;
        if (label is String && label.toLowerCase().contains('geç')) {
          penalty += 14;
        }
      } catch (_) {}

      try {
        final dynamic summary = dynamicEntry.summary;
        if (summary is String && summary.toLowerCase().contains('geç')) {
          penalty += 8;
        }
      } catch (_) {}
    }

    if (setupResult != null) {
      final dynamic dynamicSetup = setupResult;

      try {
        final dynamic summary = dynamicSetup.summary;
        if (summary is String) {
          final normalized = summary.toLowerCase();
          if (normalized.contains('yüksek risk')) penalty += 10;
          if (normalized.contains('squeeze')) penalty += 8;
        }
      } catch (_) {}
    }

    return penalty;
  }

  FinalScoreResult _buildFinalScore({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> visibleCandles,
  }) {
    double score = 0;

    score += _scoreFromOiPriceSignal(oiPriceSignal);
    score += _scoreFromDirectionCombo(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlowDirection: orderFlowDirection,
    );
    score += _scoreFromPumpAnalysis(pumpAnalysis);
    score += _scoreFromEntryTiming(entryTiming);
    score += _scoreFromShortSetup(setupResult);
    score += _scoreFromCandles(visibleCandles);

    score -= _riskPenalty(
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
      entryTiming: entryTiming,
      setupResult: setupResult,
    );

    final double finalScore = _clampScore(score);

    if (finalScore >= 85) {
      return FinalScoreResult(
        score: finalScore,
        label: 'Güçlü fırsat',
        summary: 'Merkezi short skoru güçlü. Erken giriş ile tetik birlikte oluşuyor.',
      );
    }

    if (finalScore >= 70) {
      return FinalScoreResult(
        score: finalScore,
        label: 'Kurulum var',
        summary: 'Short kurulumu oluşuyor. Giriş bölgesi yakın olabilir.',
      );
    }

    if (finalScore >= 40) {
      return FinalScoreResult(
        score: finalScore,
        label: 'İzlenmeli',
        summary: 'Erken short sinyali var ama teyit henüz yeterince güçlü değil.',
      );
    }

    return FinalScoreResult(
      score: finalScore,
      label: 'Zayıf',
      summary: 'Short fırsatı için merkezi skor düşük. Şimdilik beklemek daha sağlıklı.',
    );
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

      final FinalScoreResult calculatedFinalScore = _buildFinalScore(
        oiPriceSignal: widget.oiPriceSignal,
        oiDirection: widget.oiDirection,
        priceDirection: widget.priceDirection,
        orderFlowDirection: widget.orderFlowDirection,
        pumpAnalysis: bundle.pumpAnalysis,
        entryTiming: bundle.entryTiming,
        setupResult: bundle.setupResult,
        visibleCandles: bundle.visibleCandles,
      );

      if (!mounted) return;
      setState(() {
        selectedCoin = bundle.selectedCoin;
        candles = bundle.candles;
        visibleCandles = bundle.visibleCandles;
        setupResult = bundle.setupResult;
        pumpAnalysis = bundle.pumpAnalysis;
        entryTiming = bundle.entryTiming;
        finalScoreResult = calculatedFinalScore;
        _openInterestDisplay = _buildOpenInterestDisplay(
          bundle.selectedCoin.openInterest,
          widget.oiDirection,
        );
        detailLoading = false;
        detailError = '';
      });
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
            ),
          ),
        ],
      ),
    );
  }
}
