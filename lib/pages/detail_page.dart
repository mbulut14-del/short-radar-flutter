import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../painters/candle_chart_painter.dart';
import '../widgets/entry_timing_card.dart';
import '../widgets/price_box.dart';
import '../widgets/pump_analysis_card.dart';
import '../widgets/risk_panel_card.dart';
import '../widgets/setup_status_card.dart';
import '../widgets/short_setup_card.dart';

String _formatPrice(double value, {int digits = 6}) {
  if (value == 0) return '-';
  return value.toStringAsFixed(digits);
}

String _formatPercent(double value, {int digits = 2}) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
}

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

  String _apiInterval(String value) {
    switch (value) {
      case '12h':
        return '1d';
      default:
        return value;
    }
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
      final tickerUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers',
      );

      final candlesUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/candlesticks'
        '?contract=${Uri.encodeQueryComponent(contractName)}'
        '&interval=${Uri.encodeQueryComponent(_apiInterval(selectedInterval))}'
        '&limit=120',
      );

      final responses = await Future.wait([
        http
            .get(
              tickerUri,
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              candlesUri,
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      final tickerResponse = responses[0];
      final candleResponse = responses[1];

      if (tickerResponse.statusCode != 200 ||
          candleResponse.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          detailLoading = false;
          detailError = 'Detay verisi alınamadı';
        });
        return;
      }

      final dynamic parsedTicker = json.decode(tickerResponse.body);
      final dynamic parsedCandles = json.decode(candleResponse.body);

      if (parsedTicker is! List || parsedCandles is! List) {
        if (!mounted) return;
        setState(() {
          detailLoading = false;
          detailError = 'API veri formatı beklenen gibi değil';
        });
        return;
      }

      final List<CoinRadarData> allCoins = parsedTicker
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      CoinRadarData? detailItem;
      for (final coin in allCoins) {
        if (coin.name == contractName) {
          detailItem = coin;
          break;
        }
      }

      detailItem ??= selectedCoin;

      final List<CandleData> newCandles = [];
      for (final raw in parsedCandles) {
        try {
          newCandles.add(CandleData.fromApi(raw));
        } catch (_) {}
      }

      newCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (newCandles.isEmpty) {
        if (!mounted) return;
        setState(() {
          selectedCoin = detailItem!;
          candles = [];
          visibleCandles = [];
          setupResult = null;
          pumpAnalysis = null;
          entryTiming = null;
          detailLoading = false;
          detailError = 'Grafik verisi bulunamadı';
        });
        return;
      }

      final List<CandleData> zoomCandles = newCandles.length > 10
          ? newCandles.sublist(newCandles.length - 10)
          : newCandles;

      final ShortSetupResult newSetup = _buildShortSetup(
        candles: zoomCandles,
        coin: detailItem,
      );

      final PumpAnalysisResult newPumpAnalysis =
          PumpAnalysis.analyze(zoomCandles);

      final EntryTimingResult newEntryTiming =
          EntryTiming.analyze(zoomCandles);

      if (!mounted) return;
      setState(() {
        selectedCoin = detailItem!;
        candles = newCandles;
        visibleCandles = zoomCandles;
        setupResult = newSetup;
        pumpAnalysis = newPumpAnalysis;
        entryTiming = newEntryTiming;
        detailLoading = false;
        detailError = '';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        detailLoading = false;
        detailError = 'İstek zaman aşımına uğradı';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        detailLoading = false;
        detailError = 'Detay verisi alınamadı';
      });
    } finally {
      _isFetchingDetail = false;
    }
  }

  ShortSetupResult _buildShortSetup({
    required List<CandleData> candles,
    required CoinRadarData coin,
  }) {
    final List<CandleData> recent = candles.length > 10
        ? candles.sublist(candles.length - 10)
        : candles;

    final CandleData last = recent.last;
    final CandleData prev =
        recent.length >= 2 ? recent[recent.length - 2] : last;

    final List<CandleData> swingWindow = recent.length > 5
        ? recent.sublist(recent.length - 5)
        : recent;

    final double swingHigh = swingWindow.map((e) => e.high).reduce(math.max);

    final double firstOpen = recent.first.open == 0 ? 1 : recent.first.open;
    final double priceRisePercent =
        ((last.close - recent.first.open) / firstOpen) * 100;

    final bool nearResistance =
        swingHigh > 0 && ((swingHigh - last.close) / swingHigh) * 100 < 1.40;

    final bool weakening = recent.length < 2
        ? false
        : (last.close <= prev.close || last.bodySize <= prev.bodySize);

    final bool upperWickSignal =
        last.range > 0 && last.upperWick > last.bodySize * 0.75;

    final bool lowerHigh = recent.length >= 3 &&
        recent[recent.length - 2].high < recent[recent.length - 3].high;

    final bool divergenceWide = coin.divergencePercent > 0.08;
    final bool fundingPositive = coin.fundingRate > 0;
    final bool pumpStrong = priceRisePercent > 1.4 || coin.changePercent > 4.0;

    int strength = 0;
    final List<String> reasons = [];

    if (pumpStrong) {
      strength += 18;
      reasons.add('Son mumlarda yukarı yönlü şişme var.');
    }
    if (fundingPositive) {
      strength += coin.fundingRate > 0.0001 ? 14 : 8;
      reasons.add('Funding pozitif, long tarafı kalabalık.');
    } else {
      strength -= 10;
    }
    if (divergenceWide) {
      strength += 14;
      reasons.add('Mark-index farkı genişlemiş durumda.');
    }
    if (nearResistance) {
      strength += 16;
      reasons.add('Fiyat yakın direnç bölgesinde.');
    }
    if (upperWickSignal) {
      strength += 16;
      reasons.add('Son mumda üst fitil satış baskısı gösteriyor.');
    }
    if (weakening) {
      strength += 12;
      reasons.add('Kısa vadeli ivme zayıflıyor.');
    }
    if (lowerHigh) {
      strength += 10;
      reasons.add('Son yapıda lower-high oluşumu var.');
    }

    final double structuralStop = swingHigh * 1.003;
    final double percentCapStop = last.close * 1.028;
    final double stop = math.min(
      math.max(structuralStop, last.close * 1.008),
      percentCapStop,
    );

    final double entry = last.close;
    final double target1 = math.max(entry - (stop - entry) * 1.25, 0);
    final double target2 = math.max(entry - (stop - entry) * 2.0, 0);

    final double risk =
        math.max(stop - entry, math.max(entry * 0.001, 0.0000001));
    final double reward =
        math.max(entry - target2, math.max(entry * 0.001, 0.0000001));
    final double rr = reward / risk;

    String status;
    if (rr < 1 || coin.fundingRate < 0) {
      status = 'Zayıf';
    } else if (strength >= 68 && rr >= 1.5) {
      status = 'Güçlü';
    } else if (strength >= 42 && rr >= 1.1) {
      status = 'Orta';
    } else {
      status = 'Zayıf';
    }

    final String summary = reasons.isNotEmpty
        ? reasons.take(2).join(' ')
        : 'Net short teyidi zayıf, dikkatli takip edilmeli.';

    return ShortSetupResult(
      entry: entry,
      stopLoss: stop,
      target1: target1,
      target2: target2,
      rr: rr,
      status: status,
      summary: summary,
      reasons: reasons.isNotEmpty
          ? reasons
          : ['Veri var ama güçlü teyit sayısı şu an düşük.'],
    );
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Risk: ${(((setupResult!.stopLoss - setupResult!.entry) / setupResult!.entry) * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 280,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.35),
                        ),
                      ),
                      child: CustomPaint(
                        painter: CandleChartPainter(candles: visibleCandles),
                        child: const SizedBox.expand(),
                      ),
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
