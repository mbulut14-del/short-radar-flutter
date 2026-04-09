import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/short_setup_result.dart';
import '../painters/candle_chart_painter.dart';

class DetailPage extends StatefulWidget {
  final CoinRadarData coinData;

  const DetailPage({
    super.key,
    required this.coinData,
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

  late final AnimationController _spinnerController;
  late CoinRadarData selectedCoin;

  List<CandleData> candles = [];
  ShortSetupResult? setupResult;

  @override
  void initState() {
    super.initState();

    selectedCoin = widget.coinData;

    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    fetchDetail();

    _detailTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        fetchDetail();
      }
    });
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    _spinnerController.dispose();
    super.dispose();
  }

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
  }

  String _formatFunding(double value) {
    final double percent = value * 100;
    return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(4)}%';
  }

  Future<void> fetchDetail() async {
    setState(() {
      detailLoading = true;
      detailError = '';
    });

    try {
      final tickerResponse = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
        headers: {'Accept': 'application/json'},
      );

      final candleResponse = await http.get(
        Uri.parse(
          'https://api.gateio.ws/api/v4/futures/usdt/candlesticks'
          '?contract=${widget.coinData.name}'
          '&interval=$selectedInterval'
          '&limit=200',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (tickerResponse.statusCode != 200 || candleResponse.statusCode != 200) {
        setState(() {
          detailLoading = false;
          detailError = 'Detay verisi alınamadı';
        });
        return;
      }

      final List<dynamic> parsedTicker = json.decode(tickerResponse.body);
      final List<dynamic> parsedCandles = json.decode(candleResponse.body);

      final List<CoinRadarData> allCoins = parsedTicker
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      CoinRadarData? detailItem;
      for (final coin in allCoins) {
        if (coin.name == widget.coinData.name) {
          detailItem = coin;
          break;
        }
      }

      if (detailItem == null) {
        setState(() {
          detailLoading = false;
          detailError = 'Coin detayı bulunamadı';
        });
        return;
      }

      final List<CandleData> newCandles = parsedCandles
          .whereType<List<dynamic>>()
          .map(CandleData.fromJson)
          .toList()
          .reversed
          .toList();

      if (newCandles.isEmpty) {
        setState(() {
          selectedCoin = detailItem!;
          candles = [];
          setupResult = null;
          detailLoading = false;
          detailError = '';
        });
        return;
      }

      final ShortSetupResult newSetup = _buildShortSetup(
        candles: newCandles,
        coin: detailItem,
      );

      setState(() {
        selectedCoin = detailItem!;
        candles = newCandles;
        setupResult = newSetup;
        detailLoading = false;
        detailError = '';
      });
    } catch (_) {
      setState(() {
        detailLoading = false;
        detailError = 'Detay verisi alınamadı';
      });
    }
  }

  ShortSetupResult _buildShortSetup({
    required List<CandleData> candles,
    required CoinRadarData coin,
  }) {
    final List<CandleData> recent =
        candles.length > 24 ? candles.sublist(candles.length - 24) : candles;

    final CandleData last = recent.last;
    final CandleData prev = recent.length > 1 ? recent[recent.length - 2] : recent.last;

    final List<CandleData> swingWindow =
        recent.length > 12 ? recent.sublist(recent.length - 12) : recent;

    final double swingHigh = swingWindow.map((e) => e.high).reduce(math.max);
    final double swingLow = swingWindow.map((e) => e.low).reduce(math.min);

    final double avgRange =
        recent.map((e) => e.range).reduce((a, b) => a + b) / recent.length;

    final double priceRisePercent =
        recent.first.open == 0 ? 0 : ((last.close - recent.first.open) / recent.first.open) * 100;

    final bool nearResistance =
        swingHigh > 0 && ((swingHigh - last.close) / swingHigh) * 100 < 1.25;

    final bool weakening =
        last.close <= prev.close || last.bodySize <= prev.bodySize;

    final bool upperWickSignal =
        last.range > 0 && last.upperWick > last.bodySize * 0.9;

    final bool lowerHigh = recent.length >= 3 &&
        recent[recent.length - 2].high < recent[recent.length - 3].high;

    final bool divergenceWide = coin.divergencePercent > 0.12;
    final bool fundingPositive = coin.fundingRate > 0;
    final bool pumpStrong = priceRisePercent > 2.0 || coin.changePercent > 4.0;

    int strength = 0;
    final List<String> reasons = [];

    if (pumpStrong) {
      strength += 20;
      reasons.add('Son mumlarda yukarı yönlü şişme var.');
    }
    if (fundingPositive) {
      strength += coin.fundingRate > 0.0001 ? 18 : 10;
      reasons.add('Funding pozitif, long tarafı kalabalık.');
    }
    if (divergenceWide) {
      strength += 14;
      reasons.add('Mark-index farkı genişlemiş durumda.');
    }
    if (nearResistance) {
      strength += 18;
      reasons.add('Fiyat son tepe/direnç bölgesine yakın.');
    }
    if (upperWickSignal) {
      strength += 16;
      reasons.add('Son mumda üst fitil satış baskısı gösteriyor.');
    }
    if (weakening) {
      strength += 10;
      reasons.add('Kısa vadeli ivme zayıflıyor.');
    }
    if (lowerHigh) {
      strength += 10;
      reasons.add('Son yapıda lower-high oluşumu var.');
    }

    String status;
    if (strength >= 70) {
      status = 'Güçlü';
    } else if (strength >= 45) {
      status = 'Orta';
    } else {
      status = 'Zayıf';
    }

    final double volatilityBuffer =
        math.max(avgRange * 0.35, last.close * 0.002);

    final double entry = last.close;
    final double stopLoss = swingHigh + volatilityBuffer;
    final double supportSpan =
        math.max(avgRange * 1.2, (entry - swingLow).abs());
    final double target1 = entry - supportSpan * 0.55;
    final double target2 = entry - supportSpan;

    final double risk = math.max(stopLoss - entry, entry * 0.001);
    final double reward = math.max(entry - target2, entry * 0.001);
    final double rr = reward / risk;

    final String summary = reasons.isNotEmpty
        ? reasons.take(2).join(' ')
        : 'Net short teyidi zayıf, dikkatli takip edilmeli.';

    return ShortSetupResult(
      entry: entry,
      stopLoss: stopLoss,
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
      onTap: () {
        if (selectedInterval == value) return;

        setState(() {
          selectedInterval = value;
        });

        fetchDetail();
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
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: child,
    );
  }

  Widget _buildSetupStatusCard() {
    final ShortSetupResult setup = setupResult!;

    Color statusColor;
    switch (setup.status) {
      case 'Güçlü':
        statusColor = Colors.redAccent;
        break;
      case 'Orta':
        statusColor = Colors.orangeAccent;
        break;
      default:
        statusColor = Colors.amberAccent;
    }

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SETUP DURUMU',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.55),
                  ),
                ),
                child: Text(
                  setup.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'RR: ${setup.rr.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            setup.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortSetupCard() {
    final ShortSetupResult setup = setupResult!;

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHORT SETUP',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _setupRow('Giriş', _formatPrice(setup.entry)),
          const SizedBox(height: 8),
          _setupRow(
            'Stop loss',
            _formatPrice(setup.stopLoss),
            valueColor: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          _setupRow(
            'Hedef 1',
            _formatPrice(setup.target1),
            valueColor: Colors.greenAccent,
          ),
          const SizedBox(height: 8),
          _setupRow(
            'Hedef 2',
            _formatPrice(setup.target2),
            valueColor: Colors.greenAccent,
          ),
          const SizedBox(height: 8),
          _setupRow(
            'Risk / Ödül',
            setup.rr.toStringAsFixed(2),
            valueColor: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _setupRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget metricBox(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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

  Widget _buildNoChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.35),
        ),
      ),
      child: const Text(
        'Bu coin için şu an grafik verisi yok.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSetup = setupResult != null;
    final bool hasCandles = candles.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
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
                          selectedCoin.name,
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
                  if (hasSetup) ...[
                    _buildSetupStatusCard(),
                    const SizedBox(height: 12),
                    _buildShortSetupCard(),
                    const SizedBox(height: 14),
                  ],
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
                  if (hasCandles)
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
                        painter: CandleChartPainter(candles: candles),
                        child: const SizedBox.expand(),
                      ),
                    )
                  else
                    _buildNoChartCard(),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.45,
                    children: [
                      metricBox('Son fiyat', _formatPrice(selectedCoin.lastPrice)),
                      metricBox('Mark price', _formatPrice(selectedCoin.markPrice)),
                      metricBox('Index price', _formatPrice(selectedCoin.indexPrice)),
                      metricBox(
                        'Funding rate',
                        _formatFunding(selectedCoin.fundingRate),
                        valueColor: selectedCoin.fundingRate < 0
                            ? Colors.redAccent
                            : Colors.orangeAccent,
                      ),
                    ],
                  ),
                  if (hasSetup) ...[
                    const SizedBox(height: 18),
                    _buildWhyCard(),
                  ],
                  if (detailLoading && !hasSetup && !hasCandles) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
