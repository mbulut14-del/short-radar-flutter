import 'dart:async';

import 'package:flutter/material.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/detail_data_service.dart';
import '../widgets/candle_chart_widget.dart';
import '../widgets/entry_timing_card.dart';
import '../widgets/price_box.dart';
import '../widgets/pump_analysis_card.dart';
import '../widgets/risk_panel_card.dart';
import '../widgets/setup_status_card.dart';
import '../widgets/short_setup_card.dart';

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

      if (!mounted) return;
      setState(() {
        selectedCoin = bundle.selectedCoin;
        candles = bundle.candles;
        visibleCandles = bundle.visibleCandles;
        setupResult = bundle.setupResult;
        pumpAnalysis = bundle.pumpAnalysis;
        entryTiming = bundle.entryTiming;
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

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
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

  Widget _timeframeChip(String value) {
    final bool active = selectedInterval == value;

    return GestureDetector(
      onTap: () async {
        if (selectedInterval == value) return;
        setState(() {
          selectedInterval = value;
        });
        await fetchDetail();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? Colors.orangeAccent.withOpacity(0.85)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }

  Widget _buildWhyCard() {
    final List<String> reasons = setupResult!.reasons.take(4).toList();

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEDEN?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterState({
    required Widget child,
  }) {
    return SizedBox(
      height: 420,
      child: Center(child: child),
    );
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contractName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _spinnerRing(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _timeframeChip('1h'),
                      _timeframeChip('4h'),
                      _timeframeChip('8h'),
                      _timeframeChip('12h'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (detailError.isNotEmpty && !hasData)
                    _buildCenterState(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          detailError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else if (detailLoading && !hasData)
                    _buildCenterState(
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                      ),
                    )
                  else if (hasData) ...[
                    if (detailError.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          detailError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SetupStatusCard(setup: setupResult!),
                    const SizedBox(height: 12),
                    if (pumpAnalysis != null)
                      PumpAnalysisCard(result: pumpAnalysis!),
                    const SizedBox(height: 12),
                    if (entryTiming != null)
                      EntryTimingCard(result: entryTiming!),
                    const SizedBox(height: 12),
                    ShortSetupCard(
                      entry: _formatPrice(setupResult!.entry),
                      stopLoss: _formatPrice(setupResult!.stopLoss),
                      target1: _formatPrice(setupResult!.target1),
                      target2: _formatPrice(setupResult!.target2),
                      rr: setupResult!.rr.toStringAsFixed(2),
                      riskPercent:
                          '${(((setupResult!.stopLoss - setupResult!.entry) / setupResult!.entry) * 100).toStringAsFixed(2)}%',
                    ),
                    const SizedBox(height: 12),
                    CandleChartWidget(
                      candles: visibleCandles,
                      setupResult: setupResult,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: PriceBox(
                            title: 'Son fiyat',
                            value: selectedCoin.lastPriceText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PriceBox(
                            title: 'Mark price',
                            value: selectedCoin.markPriceText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: PriceBox(
                            title: 'Index price',
                            value: selectedCoin.indexPriceText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PriceBox(
                            title: 'Funding rate',
                            value: selectedCoin.fundingText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    RiskPanelCard(
                      result: setupResult!,
                    ),
                    const SizedBox(height: 18),
                    _buildWhyCard(),
                  ] else
                    _buildCenterState(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.45),
                          ),
                        ),
                        child: const Text(
                          'Detay verisi bekleniyor...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
