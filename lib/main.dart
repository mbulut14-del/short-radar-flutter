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
  if (abs >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)}K';
  }
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
      json['open_interest'] ??
          json['total_size'] ??
          json['position_size'] ??
          json['open_interest_usd'] ??
          0,
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
  String get markPriceText => _formatPrice(markPrice);
  String get indexPriceText => _formatPrice(indexPrice);
  String get volumeText => _formatCompactNumber(volume24h);
  String get openInterestText => _formatCompactNumber(openInterest);

  double get divergencePercent {
    if (indexPrice == 0) return 0;
    return ((markPrice - indexPrice) / indexPrice).abs() * 100;
  }
}

class CandlePoint {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandlePoint({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class LivePoint {
  final DateTime time;
  final double fundingPercent;
  final double openInterest;
  final double volume24h;

  const LivePoint({
    required this.time,
    required this.fundingPercent,
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
  List<CandlePoint> candles = [];
  List<LivePoint> livePoints = [];

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

      final tickerResponse = await http.get(
        Uri.parse(
          'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers?contract=$contract',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (tickerResponse.statusCode != 200) {
        setState(() {
          detailLoading = false;
          detailError = 'Detay verisi alınamadı';
        });
        return;
      }

      final List<dynamic> tickerParsed = json.decode(tickerResponse.body);

      if (tickerParsed.isEmpty) {
        setState(() {
          detailLoading = false;
          detailError = 'Coin detayı bulunamadı';
        });
        return;
      }

      final CoinRadarData coin = CoinRadarData.fromJson(
        Map<String, dynamic>.from(tickerParsed.first as Map),
      );

      final candleResponse = await http.get(
        Uri.parse(
          'https://fx-api.gateio.ws/api/v4/futures/usdt/candlesticks?contract=$contract&interval=5m&limit=48',
        ),
        headers: {'Accept': 'application/json'},
      );

      List<CandlePoint> parsedCandles = [];
      if (candleResponse.statusCode == 200) {
        final dynamic candleJson = json.decode(candleResponse.body);
        if (candleJson is List) {
          parsedCandles = candleJson
              .map(_parseCandle)
              .whereType<CandlePoint>()
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));
        }
      }

      final nextPoints = List<LivePoint>.from(livePoints)
        ..add(
          LivePoint(
            time: DateTime.now(),
            fundingPercent: coin.fundingRate * 100,
            openInterest: coin.openInterest,
            volume24h: coin.volume24h,
          ),
        );

      while (nextPoints.length > 48) {
        nextPoints.removeAt(0);
      }

      final normalizedPoints = _normalizeLivePoints(
        nextPoints,
        coin.fundingRate * 100,
        coin.openInterest,
        coin.volume24h,
      );

      setState(() {
        selectedCoin = coin;
        candles = parsedCandles;
        livePoints = normalizedPoints;
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

  List<LivePoint> _normalizeLivePoints(
    List<LivePoint> points,
    double fundingPercent,
    double openInterest,
    double volume24h,
  ) {
    if (points.length >= 12) return points;

    final now = DateTime.now();
    final List<LivePoint> seeded = [];

    for (int i = 11; i >= 0; i--) {
      seeded.add(
        LivePoint(
          time: now.subtract(Duration(seconds: i * 5)),
          fundingPercent: fundingPercent,
          openInterest: openInterest,
          volume24h: volume24h,
        ),
      );
    }

    if (points.isEmpty) {
      return seeded;
    }

    final int overlap = math.min(points.length, seeded.length);
    seeded.removeRange(seeded.length - overlap, seeded.length);
    seeded.addAll(points.takeLast(overlap));
    return seeded;
  }

  CandlePoint? _parseCandle(dynamic item) {
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);

      final double t = _parseDouble(
        map['t'] ?? map['time'] ?? map['timestamp'],
      );
      final double o = _parseDouble(map['o'] ?? map['open']);
      final double h = _parseDouble(map['h'] ?? map['high']);
      final double l = _parseDouble(map['l'] ?? map['low']);
      final double c = _parseDouble(map['c'] ?? map['close']);
      final double v = _parseDouble(map['v'] ?? map['volume']);

      if ([o, h, l, c].every((e) => e == 0)) return null;

      return CandlePoint(
        time: DateTime.fromMillisecondsSinceEpoch((t * 1000).round()),
        open: o,
        high: h,
        low: l,
        close: c,
        volume: v,
      );
    }

    if (item is List && item.length >= 6) {
      final double t = _parseDouble(item[0]);
      final double v = _parseDouble(item[1]);
      final double c = _parseDouble(item[2]);
      final double h = _parseDouble(item[3]);
      final double l = _parseDouble(item[4]);
      final double o = _parseDouble(item[5]);

      if ([o, h, l, c].every((e) => e == 0)) return null;

      return CandlePoint(
        time: DateTime.fromMillisecondsSinceEpoch((t * 1000).round()),
        open: o,
        high: h,
        low: l,
        close: c,
        volume: v,
      );
    }

    return null;
  }

  double get shortPercent {
    double value = 50;
    value += math.min(selectedCoin.score * 0.32, 22);

    if (selectedCoin.fundingRate > 0) {
      value += math.min(selectedCoin.fundingRate * 100 * 18, 12);
    } else {
      value -= math.min(selectedCoin.fundingRate.abs() * 100 * 10, 8);
    }

    if (selectedCoin.changePercent > 0) {
      value += math.min(selectedCoin.changePercent * 0.14, 10);
    } else {
      value -= math.min(selectedCoin.changePercent.abs() * 0.08, 6);
    }

    return value.clamp(10, 90);
  }

  double get longPercent => 100 - shortPercent;

  String get pressureText {
    if (shortPercent >= 70) return 'Short baskısı çok güçlü.';
    if (shortPercent >= 58) return 'Short tarafı önde.';
    if (longPercent >= 60) return 'Long tarafı güçlü.';
    return 'Piyasa dengeli.';
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                  color: selectedCoin.changePercent < 0
                      ? Colors.redAccent
                      : const Color(0xFF3CFFB2),
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

  Widget _miniAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
    final List<LivePoint> graphPoints = livePoints.isEmpty
        ? [
            LivePoint(
              time: DateTime.now(),
              fundingPercent: selectedCoin.fundingRate * 100,
              openInterest: selectedCoin.openInterest,
              volume24h: selectedCoin.volume24h,
            ),
          ]
        : livePoints;

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
                      child: candles.isEmpty
                          ? const Center(
                              child: Text(
                                'Mum verisi alınamadı',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : CustomPaint(
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
                        painter: OiVolumePainter(samples: graphPoints),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Funding Oranı',
                    child: SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: FundingPainter(samples: graphPoints),
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
  final List<CandlePoint> candles;

  LiveCandlePainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 14.0;
    const rightPad = 56.0;
    const topPad = 14.0;
    const bottomPad = 28.0;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topPad + (h / 4) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + w, y),
        gridPaint,
      );
    }

    final minPrice = candles.map((e) => e.low).reduce(math.min);
    final maxPrice = candles.map((e) => e.high).reduce(math.max);
    final diff = (maxPrice - minPrice).abs() < 0.0000001
        ? 0.000001
        : (maxPrice - minPrice);

    double yFromPrice(double value) {
      final p = (value - minPrice) / diff;
      return topPad + h - (p * h);
    }

    final stepX = w / candles.length;
    final bodyWidth = stepX * 0.48;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = leftPad + stepX * i + stepX / 2;
      final color = c.close >= c.open
          ? const Color(0xFF3CFFB2)
          : Colors.redAccent;

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.4;

      canvas.drawLine(
        Offset(x, yFromPrice(c.high)),
        Offset(x, yFromPrice(c.low)),
        wickPaint,
      );

      final top = yFromPrice(math.max(c.open, c.close));
      final bottom = yFromPrice(math.min(c.open, c.close));

      final rect = Rect.fromLTRB(
        x - bodyWidth / 2,
        top,
        x + bodyWidth / 2,
        math.max(bottom, top + 2),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
    }

    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.65),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final maxTp = TextPainter(
      text: TextSpan(text: _formatPrice(maxPrice), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final minTp = TextPainter(
      text: TextSpan(text: _formatPrice(minPrice), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    maxTp.paint(canvas, Offset(leftPad + w + 6, topPad - 2));
    minTp.paint(canvas, Offset(leftPad + w + 6, topPad + h - 10));
  }

  @override
  bool shouldRepaint(covariant LiveCandlePainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}

class OiVolumePainter extends CustomPainter {
  final List<LivePoint> samples;

  OiVolumePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 14.0;
    const rightPad = 14.0;
    const topPad = 14.0;
    const bottomPad = 28.0;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topPad + (h / 4) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + w, y),
        gridPaint,
      );
    }

    final maxVol = samples.map((e) => e.volume24h).fold<double>(1, math.max);
    double minOi = samples.map((e) => e.openInterest).reduce(math.min);
    double maxOi = samples.map((e) => e.openInterest).reduce(math.max);

    if ((maxOi - minOi).abs() < 0.000001) {
      maxOi += 1;
      minOi -= 1;
    }

    final stepX = samples.length == 1 ? w : w / samples.length;
    final barWidth = math.max(6, stepX * 0.52);

    double yFromOi(double value) {
      final p = (value - minOi) / (maxOi - minOi);
      return topPad + h - (p * h);
    }

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final x = samples.length == 1
          ? leftPad + (w - barWidth) / 2
          : leftPad + stepX * i + (stepX - barWidth) / 2;
      final barHeight = (s.volume24h / maxVol) * h;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            topPad + h - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.orangeAccent,
      );
    }

    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = samples.length == 1
          ? leftPad + w / 2
          : leftPad + stepX * i + stepX / 2;
      final y = yFromOi(samples[i].openInterest);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3EA6FF).withOpacity(0.30)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3EA6FF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

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

    tp1.paint(canvas, Offset(leftPad + 26, size.height - 18));
    tp2.paint(canvas, Offset(leftPad + 90, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant OiVolumePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

class FundingPainter extends CustomPainter {
  final List<LivePoint> samples;

  FundingPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 14.0;
    const rightPad = 14.0;
    const topPad = 14.0;
    const bottomPad = 28.0;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topPad + (h / 4) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + w, y),
        gridPaint,
      );
    }

    double minV = samples.map((e) => e.fundingPercent).reduce(math.min);
    double maxV = samples.map((e) => e.fundingPercent).reduce(math.max);

    if ((maxV - minV).abs() < 0.0001) {
      maxV += 0.1;
      minV -= 0.1;
    }

    double yFromValue(double value) {
      final p = (value - minV) / (maxV - minV);
      return topPad + h - (p * h);
    }

    final zeroY = yFromValue(0);
    canvas.drawLine(
      Offset(leftPad, zeroY),
      Offset(leftPad + w, zeroY),
      Paint()
        ..color = Colors.white.withOpacity(0.14)
        ..strokeWidth = 1,
    );

    final stepX = samples.length == 1 ? w : w / (samples.length - 1);

    if (samples.length == 1) {
      final y = yFromValue(samples.first.fundingPercent);
      canvas.drawCircle(
        Offset(leftPad + w / 2, y),
        4,
        Paint()
          ..color = samples.first.fundingPercent >= 0
              ? const Color(0xFF3CFFB2)
              : Colors.redAccent,
      );
    } else {
      for (int i = 1; i < samples.length; i++) {
        final prev = samples[i - 1];
        final curr = samples[i];

        canvas.drawLine(
          Offset(leftPad + stepX * (i - 1), yFromValue(prev.fundingPercent)),
          Offset(leftPad + stepX * i, yFromValue(curr.fundingPercent)),
          Paint()
            ..color = curr.fundingPercent >= 0
                ? const Color(0xFF3CFFB2)
                : Colors.redAccent
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke,
        );
      }
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

    tp1.paint(canvas, Offset(leftPad + 24, size.height - 18));
    tp2.paint(canvas, Offset(leftPad + 108, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant FundingPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

extension _TakeLastExtension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (count <= 0) return const [];
    final list = toList();
    if (count >= list.length) return list;
    return list.sublist(list.length - count);
  }
}
