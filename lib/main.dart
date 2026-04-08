import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

String _formatPrice(double value, {int digits = 6}) {
  if (value == 0) return '-';
  return value.toStringAsFixed(digits);
}

String _formatPercent(double value, {int digits = 2}) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
}

String _formatFunding(double value) {
  final percent = value * 100;
  return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(4)}%';
}

String _formatCompactNumber(double value) {
  final abs = value.abs();
  if (abs >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}

class CoinRadarData {
  final String name;
  final double changePercent;
  final double fundingRate;
  final double lastPrice;
  final double markPrice;
  final double indexPrice;
  final double volume24h;
  final double openInterest;
  final int score;
  final String biasLabel;
  final String note;

  const CoinRadarData({
    required this.name,
    required this.changePercent,
    required this.fundingRate,
    required this.lastPrice,
    required this.markPrice,
    required this.indexPrice,
    required this.volume24h,
    required this.openInterest,
    required this.score,
    required this.biasLabel,
    required this.note,
  });

  factory CoinRadarData.seed({
    required String name,
    required double changePercent,
  }) {
    final int score = _calculateScore(
      changePercent: changePercent,
      fundingRate: 0,
      markPrice: 0,
      indexPrice: 0,
      volume24h: 0,
    );

    return CoinRadarData(
      name: name,
      changePercent: changePercent,
      fundingRate: 0,
      lastPrice: 0,
      markPrice: 0,
      indexPrice: 0,
      volume24h: 0,
      openInterest: 0,
      score: score,
      biasLabel: _biasLabel(score),
      note: _noteText(score, changePercent, 0, 0, 0),
    );
  }

  factory CoinRadarData.fromJson(Map<String, dynamic> json) {
    final double changePercent = _parseDouble(json['change_percentage']);
    final double fundingRate = _parseDouble(json['funding_rate']);
    final double lastPrice = _parseDouble(json['last']);
    final double markPrice = _parseDouble(json['mark_price']);
    final double indexPrice = _parseDouble(json['index_price']);
    final double volume24h = _parseDouble(
      json['volume_24h_quote'] ?? json['volume_24h'] ?? 0,
    );
    final double openInterest = _parseDouble(
      json['open_interest'] ?? json['total_size'] ?? 0,
    );

    final int score = _calculateScore(
      changePercent: changePercent,
      fundingRate: fundingRate,
      markPrice: markPrice,
      indexPrice: indexPrice,
      volume24h: volume24h,
    );

    return CoinRadarData(
      name: (json['contract'] ?? '').toString(),
      changePercent: changePercent,
      fundingRate: fundingRate,
      lastPrice: lastPrice,
      markPrice: markPrice,
      indexPrice: indexPrice,
      volume24h: volume24h,
      openInterest: openInterest,
      score: score,
      biasLabel: _biasLabel(score),
      note: _noteText(
        score,
        changePercent,
        fundingRate,
        markPrice,
        indexPrice,
      ),
    );
  }

  static int _calculateScore({
    required double changePercent,
    required double fundingRate,
    required double markPrice,
    required double indexPrice,
    required double volume24h,
  }) {
    double score = 0;

    if (changePercent > 0) {
      score += math.min(changePercent * 0.9, 48);
    } else {
      score += math.max(changePercent * 0.15, -10);
    }

    if (fundingRate > 0) {
      score += math.min(fundingRate * 10000, 28);
    } else if (fundingRate < 0) {
      score -= math.min(fundingRate.abs() * 5000, 10);
    }

    if (indexPrice != 0) {
      final double divergence =
          ((markPrice - indexPrice) / indexPrice).abs() * 100;
      score += math.min(divergence * 22, 14);
    }

    if (volume24h > 0) {
      final double volumeBoost = math.max(
        0,
        math.min((math.log(volume24h + 1) - 10) * 2.2, 10),
      );
      score += volumeBoost;
    }

    score = score.clamp(0, 100);
    return score.round();
  }

  static String _biasLabel(int score) {
    if (score >= 75) return 'Çok güçlü short';
    if (score >= 60) return 'Güçlü short';
    if (score >= 45) return 'İzlemeye değer';
    if (score >= 30) return 'Zayıf baskı';
    return 'Nötr';
  }

  static String _noteText(
    int score,
    double changePercent,
    double fundingRate,
    double markPrice,
    double indexPrice,
  ) {
    final double divergence = indexPrice == 0
        ? 0
        : ((markPrice - indexPrice) / indexPrice).abs() * 100;

    if (score >= 75) {
      return 'Pump güçlü, funding şişmiş. Sert short takibi.';
    }
    if (score >= 60) {
      return 'Yükseliş ve funding birlikte ısınıyor.';
    }
    if (score >= 45) {
      return 'İzlenebilir short baskısı oluşuyor.';
    }
    if (changePercent < 0) {
      return 'Zaten zayıflamış, short avantajı düşebilir.';
    }
    if (divergence > 0.20) {
      return 'Fiyat farkı var, volatilite yükselebilir.';
    }
    if (fundingRate > 0) {
      return 'Funding pozitif ama sinyal orta güçte.';
    }
    return 'Şimdilik net short baskısı zayıf.';
  }

  String get changeText => _formatPercent(changePercent);
  String get fundingText => _formatFunding(fundingRate);
  String get lastPriceText => _formatPrice(lastPrice);
  String get volumeText => _formatCompactNumber(volume24h);
  String get openInterestText => _formatCompactNumber(openInterest);
}

class CandleData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandleData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class FundingPoint {
  final DateTime time;
  final double ratePercent;

  const FundingPoint({
    required this.time,
    required this.ratePercent,
  });
}

class OiSample {
  final DateTime time;
  final double openInterest;
  final double volume24h;

  const OiSample({
    required this.time,
    required this.openInterest,
    required this.volume24h,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CoinRadarData> coins = [
    CoinRadarData.seed(name: 'KOMA_USDT', changePercent: 58.22),
    CoinRadarData.seed(name: 'BULLA_USDT', changePercent: 44.77),
    CoinRadarData.seed(name: 'PLAY_USDT', changePercent: 34.27),
    CoinRadarData.seed(name: 'APR_USDT', changePercent: 31.12),
    CoinRadarData.seed(name: 'TRU_USDT', changePercent: 28.90),
    CoinRadarData.seed(name: 'DOGE_USDT', changePercent: 25.61),
    CoinRadarData.seed(name: 'SOL_USDT', changePercent: 22.10),
    CoinRadarData.seed(name: 'ETH_USDT', changePercent: 19.85),
    CoinRadarData.seed(name: 'BTC_USDT', changePercent: 17.40),
    CoinRadarData.seed(name: 'XRP_USDT', changePercent: 15.12),
  ];

  CoinRadarData? radarLeader;
  bool isLoading = true;
  String errorText = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    radarLeader = coins.first;
    fetchCoins();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        fetchCoins();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchCoins() async {
    setState(() {
      isLoading = true;
      errorText = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri alınamadı';
        });
        return;
      }

      final List<dynamic> parsed = json.decode(response.body);

      final List<CoinRadarData> allCoins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (allCoins.isEmpty) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri boş döndü';
        });
        return;
      }

      final List<CoinRadarData> sortedByChange = [...allCoins]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final List<CoinRadarData> sortedByScore = [...allCoins]
        ..sort((a, b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return b.changePercent.compareTo(a.changePercent);
        });

      setState(() {
        coins = sortedByChange.take(10).toList();
        radarLeader = sortedByScore.first;
        isLoading = false;
        errorText = '';
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorText = 'Canlı veri alınamadı';
      });
    }
  }

  Widget _buildRadarHero() {
    final CoinRadarData? leader = radarLeader;
    if (leader == null) {
      return const SizedBox(height: 150);
    }

    final Color scoreColor = leader.score >= 75
        ? Colors.redAccent
        : leader.score >= 60
            ? Colors.orangeAccent
            : leader.score >= 45
                ? Colors.amberAccent
                : Colors.greenAccent;

    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLoading ? Colors.orangeAccent : Colors.greenAccent,
                ),
              ),
              child: Text(
                isLoading ? 'Yükleniyor' : 'Canlı Veri',
                style: TextStyle(
                  color: isLoading ? Colors.orangeAccent : Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scoreColor.withOpacity(0.75),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scoreColor.withOpacity(0.18),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                      border: Border.all(color: scoreColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: scoreColor.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${leader.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EN GÜÇLÜ SHORT ADAYI',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leader.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _miniInfo('Skor', '${leader.score}'),
                            _miniInfo('Değişim', leader.changeText),
                            _miniInfo('Funding', leader.fundingText),
                            _miniInfo('Bias', leader.biasLabel),
                          ],
                        ),
                      ],
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

  Widget _miniInfo(String title, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: RefreshIndicator(
              onRefresh: fetchCoins,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildRadarHero(),
                  if (radarLeader != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.32),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              radarLeader!.note,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...coins.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final coin = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailPage(coinData: coin),
                            ),
                          );
                        },
                        child: Container(
                          height: 86,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF07122A),
                                Color(0xFF091933),
                                Color(0xFF07122A),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF3EA6FF),
                              width: 1.4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x663EA6FF),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color(0x3300FFFF),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF123D9B),
                                    border: Border.all(
                                      color: const Color(0xFF5AA8FF),
                                      width: 1.6,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x663EA6FF),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$index',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coin.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Short skoru: ${coin.score} • ${coin.biasLabel}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.72),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  coin.changeText,
                                  style: TextStyle(
                                    color: coin.changePercent < 0
                                        ? Colors.redAccent
                                        : const Color(0xFF3CFFB2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final CoinRadarData coinData;

  const DetailPage({
    super.key,
    required this.coinData,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Timer? _detailTimer;
  bool detailLoading = true;
  String detailError = '';

  late CoinRadarData selectedCoin;
  List<CandleData> candles = [];
  List<FundingPoint> fundingHistory = [];
  final List<OiSample> oiHistory = [];

  @override
  void initState() {
    super.initState();
    selectedCoin = widget.coinData;
    fetchDetail();

    _detailTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        fetchDetail();
      }
    });
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchDetail() async {
    setState(() {
      detailLoading = true;
      detailError = '';
    });

    try {
      final contract = widget.coinData.name;

      final tickerUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers?contract=$contract',
      );
      final candlesUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/candlesticks?contract=$contract&interval=5m&limit=24',
      );
      final fundingUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/funding_rate?contract=$contract&limit=24',
      );

      final responses = await Future.wait([
        http.get(tickerUri, headers: {'Accept': 'application/json'}),
        http.get(candlesUri, headers: {'Accept': 'application/json'}),
        http.get(fundingUri, headers: {'Accept': 'application/json'}),
      ]);

      final tickerResponse = responses[0];
      final candlesResponse = responses[1];
      final fundingResponse = responses[2];

      if (tickerResponse.statusCode != 200 ||
          candlesResponse.statusCode != 200 ||
          fundingResponse.statusCode != 200) {
        setState(() {
          detailLoading = false;
          detailError = 'Detay verisi alınamadı';
        });
        return;
      }

      final List<dynamic> tickerParsed = json.decode(tickerResponse.body);
      final List<dynamic> candlesParsed = json.decode(candlesResponse.body);
      final List<dynamic> fundingParsed = json.decode(fundingResponse.body);

      if (tickerParsed.isEmpty) {
        setState(() {
          detailLoading = false;
          detailError = 'Coin detayı bulunamadı';
        });
        return;
      }

      final coin = CoinRadarData.fromJson(
        Map<String, dynamic>.from(tickerParsed.first as Map),
      );

      final liveCandles = candlesParsed
          .whereType<Map>()
          .map((e) => CandleData(
                time: DateTime.fromMillisecondsSinceEpoch(
                  (_parseDouble(e['t']) * 1000).round(),
                ),
                open: _parseDouble(e['o']),
                high: _parseDouble(e['h']),
                low: _parseDouble(e['l']),
                close: _parseDouble(e['c']),
                volume: _parseDouble(e['v']),
              ))
          .where((e) => e.open != 0 || e.close != 0)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      final liveFunding = fundingParsed
          .whereType<Map>()
          .map((e) => FundingPoint(
                time: DateTime.fromMillisecondsSinceEpoch(
                  (_parseDouble(e['t']) * 1000).round(),
                ),
                ratePercent: _parseDouble(e['r']) * 100,
              ))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      oiHistory.add(
        OiSample(
          time: DateTime.now(),
          openInterest: coin.openInterest,
          volume24h: coin.volume24h,
        ),
      );
      if (oiHistory.length > 36) {
        oiHistory.removeRange(0, oiHistory.length - 36);
      }

      setState(() {
        selectedCoin = coin;
        candles = liveCandles;
        fundingHistory = liveFunding;
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

  Color getChangeColor(double value) {
    return value < 0 ? Colors.redAccent : const Color(0xFF3CFFB2);
  }

  double get shortPercent {
    double value = 50;
    value += math.min(selectedCoin.score * 0.30, 28);

    if (selectedCoin.fundingRate > 0) {
      value += math.min(selectedCoin.fundingRate * 100 * 25, 15);
    } else {
      value -= math.min(selectedCoin.fundingRate.abs() * 100 * 16, 10);
    }

    if (selectedCoin.changePercent > 0) {
      value += math.min(selectedCoin.changePercent * 0.16, 12);
    } else {
      value -= math.min(selectedCoin.changePercent.abs() * 0.10, 8);
    }

    return value.clamp(10, 90);
  }

  double get longPercent => 100 - shortPercent;

  String get pressureText {
    if (shortPercent >= 72) return 'Short baskısı çok güçlü.';
    if (shortPercent >= 60) return 'Short baskısı önde.';
    if (longPercent >= 60) return 'Long tarafı ağır basıyor.';
    return 'Piyasa dengeli görünüyor.';
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: detailLoading ? Colors.orangeAccent : Colors.greenAccent,
        ),
      ),
      child: Text(
        detailLoading ? 'Yükleniyor' : 'Canlı Detay',
        style: TextStyle(
          color: detailLoading ? Colors.orangeAccent : Colors.greenAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0B1428),
            const Color(0xFF0A1020),
            const Color(0xFF180C24).withOpacity(0.92),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedCoin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                selectedCoin.changeText,
                style: TextStyle(
                  color: getChangeColor(selectedCoin.changePercent),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Short skoru: ${selectedCoin.score} • ${selectedCoin.biasLabel}',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            selectedCoin.note,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _miniAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mini Analiz',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _metricBox('Son fiyat', selectedCoin.lastPriceText),
              _metricBox(
                'Funding oranı',
                selectedCoin.fundingText,
                valueColor: selectedCoin.fundingRate < 0
                    ? Colors.redAccent
                    : Colors.orangeAccent,
              ),
              _metricBox('24s Hacim', selectedCoin.volumeText),
              _metricBox(
                'Açık pozisyon',
                selectedCoin.openInterestText,
                valueColor: Colors.cyanAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pressureCard() {
    return _sectionCard(
      title: 'Piyasa Baskısı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Long %\n${longPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF3CFFB2),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Short %\n${shortPercent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.08),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (longPercent * 10).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CFFB2).withOpacity(0.72),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: (shortPercent * 10).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.84),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pressureText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '5 sn’de bir canlı güncellenir.',
            style: TextStyle(
              color: Colors.orangeAccent.withOpacity(0.92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      _statusChip(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _summaryCard(),
                  if (detailError.isNotEmpty) ...[
                    const SizedBox(height: 14),
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
                  ],
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Fiyat Grafiği',
                    child: SizedBox(
                      height: 250,
                      child: CustomPaint(
                        painter: LiveCandlePainter(candles: candles),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Açık Pozisyon (OI) & Hacim',
                    child: SizedBox(
                      height: 230,
                      child: CustomPaint(
                        painter: OiVolumePainter(samples: oiHistory),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Funding Oranı',
                    child: SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: FundingPainter(points: fundingHistory),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _miniAnalysisCard(),
                  const SizedBox(height: 16),
                  _pressureCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveCandlePainter extends CustomPainter {
  final List<CandleData> candles;

  LiveCandlePainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0;
    const right = 54.0;
    const top = 12.0;
    const bottom = 28.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = top + (chartHeight / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    if (candles.length < 2) return;

    double minPrice = candles.map((e) => e.low).reduce(math.min);
    double maxPrice = candles.map((e) => e.high).reduce(math.max);

    if ((maxPrice - minPrice).abs() < 0.0000001) {
      maxPrice += 0.000001;
      minPrice -= 0.000001;
    }

    double yFromPrice(double price) {
      final normalized = (price - minPrice) / (maxPrice - minPrice);
      return top + chartHeight - normalized * chartHeight;
    }

    final step = chartWidth / candles.length;
    final bodyWidth = step * 0.48;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final xCenter = left + step * i + step / 2;
      final color = candle.close >= candle.open
          ? const Color(0xFF3CFFB2)
          : Colors.redAccent;

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.4;

      final bodyPaint = Paint()..color = color;

      canvas.drawLine(
        Offset(xCenter, yFromPrice(candle.high)),
        Offset(xCenter, yFromPrice(candle.low)),
        wickPaint,
      );

      final bodyTop = yFromPrice(math.max(candle.open, candle.close));
      final bodyBottom = yFromPrice(math.min(candle.open, candle.close));

      final rect = Rect.fromLTRB(
        xCenter - bodyWidth / 2,
        bodyTop,
        xCenter + bodyWidth / 2,
        math.max(bodyBottom, bodyTop + 2),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        bodyPaint,
      );
    }

    final style = TextStyle(
      color: Colors.white.withOpacity(0.65),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final maxTp = TextPainter(
      text: TextSpan(text: _formatPrice(maxPrice), style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final minTp = TextPainter(
      text: TextSpan(text: _formatPrice(minPrice), style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    maxTp.paint(canvas, Offset(size.width - right + 6, top - 2));
    minTp.paint(
      canvas,
      Offset(size.width - right + 6, top + chartHeight - 10),
    );
  }

  @override
  bool shouldRepaint(covariant LiveCandlePainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}

class OiVolumePainter extends CustomPainter {
  final List<OiSample> samples;

  OiVolumePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 28.0;

    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = top + (height / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    if (samples.length < 2) return;

    final maxVol = math.max(
      1,
      samples.map((e) => e.volume24h).fold<double>(0, math.max),
    );
    double minOi = samples.map((e) => e.openInterest).reduce(math.min);
    double maxOi = samples.map((e) => e.openInterest).reduce(math.max);

    if ((maxOi - minOi).abs() < 0.000001) {
      maxOi += 1;
      minOi -= 1;
    }

    final step = width / samples.length;
    final barWidth = step * 0.50;

    double yFromOi(double value) {
      final normalized = (value - minOi) / (maxOi - minOi);
      return top + height - normalized * height;
    }

    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final x = left + (step * i) + ((step - barWidth) / 2);
      final barHeight = (sample.volume24h / maxVol) * height;

      final barPaint = Paint()..color = Colors.orangeAccent;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            top + height - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = left + step * i + step / 2;
      final y = yFromOi(samples[i].openInterest);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF3EA6FF).withOpacity(0.32)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = const Color(0xFF3EA6FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final style = TextStyle(
      color: Colors.white.withOpacity(0.74),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    final tp1 = TextPainter(
      text: TextSpan(
        text: '● OI',
        style: style.copyWith(color: const Color(0xFF3EA6FF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tp2 = TextPainter(
      text: TextSpan(
        text: '● Hacim',
        style: style.copyWith(color: Colors.orangeAccent),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp1.paint(canvas, Offset(left + 26, size.height - 18));
    tp2.paint(canvas, Offset(left + 88, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant OiVolumePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

class FundingPainter extends CustomPainter {
  final List<FundingPoint> points;

  FundingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0;
    const right = 10.0;
    const top = 14.0;
    const bottom = 26.0;

    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = top + (height / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    if (points.length < 2) return;

    double minV = points.map((e) => e.ratePercent).reduce(math.min);
    double maxV = points.map((e) => e.ratePercent).reduce(math.max);

    if ((maxV - minV).abs() < 0.0001) {
      maxV += 0.1;
      minV -= 0.1;
    }

    double yFromValue(double v) {
      final normalized = (v - minV) / (maxV - minV);
      return top + height - normalized * height;
    }

    final zeroNorm = (0 - minV) / (maxV - minV);
    final zeroY = top + height - zeroNorm * height;

    final zeroPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(left, zeroY),
      Offset(size.width - right, zeroY),
      zeroPaint,
    );

    final step = width / (points.length - 1);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      final paint = Paint()
        ..color = curr.ratePercent >= 0
            ? const Color(0xFF3CFFB2)
            : Colors.redAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(left + step * (i - 1), yFromValue(prev.ratePercent)),
        Offset(left + step * i, yFromValue(curr.ratePercent)),
        paint,
      );
    }

    final style = TextStyle(
      color: Colors.white.withOpacity(0.74),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    final tp1 = TextPainter(
      text: TextSpan(
        text: '● Pozitif',
        style: style.copyWith(color: const Color(0xFF3CFFB2)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tp2 = TextPainter(
      text: TextSpan(
        text: '● Negatif',
        style: style.copyWith(color: Colors.redAccent),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp1.paint(canvas, Offset(left + 24, size.height - 18));
    tp2.paint(canvas, Offset(left + 108, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant FundingPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
