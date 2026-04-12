import 'dart:async';

import 'package:flutter/material.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/detail_data_service.dart';
import '../widgets/detail_page_content.dart';

class DetailPage extends StatefulWidget {
  final CoinRadarData coinData;
  final CoinRadarData? leaderData;

  const DetailPage({
    super.key,
    required this.coinData,
    this.leaderData,
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

  bool _isFetchingDetail = false;

  // =========================
  // 🔥 30DK OI SİSTEMİ
  // =========================

  final List<double> _oiHistory = [];
  String _openInterestDisplay = '-';

  static const int _maxHistory = 360; // 30dk (5sn veri)

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

  String _calculateOITrend(double currentOI) {
    if (currentOI <= 0) return '-';

    // listeye ekle
    _oiHistory.add(currentOI);

    // max 360 veri tut
    if (_oiHistory.length > _maxHistory) {
      _oiHistory.removeAt(0);
    }

    // yeterli veri yoksa yön verme
    if (_oiHistory.length < _maxHistory) {
      return '${_formatOI(currentOI)} -';
    }

    // 30dk önceki veri
    final double pastOI = _oiHistory.first;

    String direction = '-';
    if (currentOI > pastOI) {
      direction = '↑';
    } else if (currentOI < pastOI) {
      direction = '↓';
    }

    return '${_formatOI(currentOI)} $direction';
  }

  // =========================

  @override
  void initState() {
    super.initState();
    contractName = widget.coinData.name;
    selectedCoin = widget.coinData;

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

      final String oiDisplay =
          _calculateOITrend(bundle.selectedCoin.openInterest);

      if (!mounted) return;
      setState(() {
        selectedCoin = bundle.selectedCoin;
        candles = bundle.candles;
        visibleCandles = bundle.visibleCandles;
        setupResult = bundle.setupResult;
        pumpAnalysis = bundle.pumpAnalysis;
        entryTiming = bundle.entryTiming;
        _openInterestDisplay = oiDisplay;
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
            ),
          ),
        ],
      ),
    );
  }
}
