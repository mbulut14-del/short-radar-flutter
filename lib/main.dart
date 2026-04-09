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

class CoinRadarData {
  final String name;
  final double changePercent;
  final double fundingRate;
  final double lastPrice;
  final double markPrice;
  final double indexPrice;
  final double volume24h;
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

  double get divergencePercent {
    if (indexPrice == 0) return 0;
    return ((markPrice - indexPrice) / indexPrice).abs() * 100;
  }
}

class CandleData {
  final int timestamp;
  final double volume;
  final double close;
  final double high;
  final double low;
  final double open;

  const CandleData({
    required this.timestamp,
    required this.volume,
    required this.close,
    required this.high,
    required this.low,
    required this.open,
  });

  factory CandleData.fromJson(Map<String, dynamic> raw) {
    return CandleData(
      timestamp: int.tryParse(raw['t'].toString()) ?? 0,
      volume: _parseDouble(raw['v']),
      close: _parseDouble(raw['c']),
      high: _parseDouble(raw['h']),
      low: _parseDouble(raw['l']),
      open: _parseDouble(raw['o']),
    );
  }

  bool get isBullish => close >= open;
  double get bodySize => (close - open).abs();
  double get range => (high - low).abs();
  double get upperWick => high - math.max(open, close);
  double get lowerWick => math.min(open, close) - low;
}

class ShortSetupResult {
  final double entry;
  final double stopLoss;
  final double target1;
  final double target2;
  final double rr;
  final String status;
  final String summary;
  final List<String> reasons;

  const ShortSetupResult({
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.rr,
    required this.status,
    required this.summary,
    required this.reasons,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final AnimationController _logoController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoGlow;
  late final Animation<double> _logoTranslateY;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoGlow = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    _logoTranslateY = Tween<double>(begin: -180, end: 0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Widget _buildSplashText() {
    return FadeTransition(
      opacity: _textOpacity,
      child: SlideTransition(
        position: _textSlide,
        child: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFEDEDED),
                Color(0xFFFFB300),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'SHORT RADAR PRO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.translate(
            offset: Offset(0, _logoTranslateY.value),
            child: Transform.scale(
              scale: _logoScale.value,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2CFF).withOpacity(
                        0.22 * _logoGlow.value,
                      ),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF2E63).withOpacity(
                        0.20 * _logoGlow.value,
                      ),
                      blurRadius: 48,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.15,
            colors: [
              Color(0xFF0B0B13),
              Color(0xFF050507),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF243CFF).withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF243CFF).withOpacity(0.20),
                      blurRadius: 80,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -70,
              bottom: 120,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF2E63).withOpacity(0.10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2E63).withOpacity(0.18),
                      blurRadius: 90,
                      spreadRadius: 35,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAnimatedLogo(),
                    const SizedBox(height: 28),
                    _buildSplashText(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  bool _isFetching = false;

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
    if (_isFetching) return;
    _isFetching = true;

    if (mounted) {
      setState(() {
        isLoading = true;
        errorText = '';
      });
    }

    try {
      final response = await http
          .get(
            Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorText = 'Canlı veri alınamadı';
          });
        }
        return;
      }

      final dynamic parsed = json.decode(response.body);
      if (parsed is! List) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorText = 'API veri formatı hatalı';
          });
        }
        return;
      }

      final List<CoinRadarData> allCoins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (allCoins.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorText = 'Canlı veri boş döndü';
          });
        }
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

      if (mounted) {
        setState(() {
          coins = sortedByChange.take(10).toList();
          radarLeader = sortedByScore.first;
          isLoading = false;
          errorText = '';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorText = 'İstek zaman aşımına uğradı';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri alınamadı';
        });
      }
    } finally {
      _isFetching = false;
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
                              builder: (_) => DetailPage(
                                coinData: coin,
                                leaderData: radarLeader,
                              ),
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
  ShortSetupResult? setupResult;
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

      if (tickerResponse.statusCode != 200 || candleResponse.statusCode != 200) {
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

      final List<CandleData> newCandles = parsedCandles
          .whereType<Map<String, dynamic>>()
          .map(CandleData.fromJson)
          .toList()
          .reversed
          .toList();

      if (newCandles.isEmpty) {
        if (!mounted) return;
        setState(() {
          selectedCoin = detailItem!;
          candles = [];
          setupResult = null;
          detailLoading = false;
          detailError = 'Grafik verisi bulunamadı';
        });
        return;
      }

      final ShortSetupResult newSetup = _buildShortSetup(
        candles: newCandles,
        coin: detailItem,
      );

      if (!mounted) return;
      setState(() {
        selectedCoin = detailItem!;
        candles = newCandles;
        setupResult = newSetup;
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
    final List<CandleData> recent = candles.length > 24
        ? candles.sublist(candles.length - 24)
        : candles;

    final CandleData last = recent.last;
    final CandleData prev = recent.length >= 2 ? recent[recent.length - 2] : last;

    final List<CandleData> swingWindow = recent.length > 12
        ? recent.sublist(recent.length - 12)
        : recent;

    final double swingHigh = swingWindow.map((e) => e.high).reduce(math.max);
    final double swingLow = swingWindow.map((e) => e.low).reduce(math.min);

    final double avgRange = recent.map((e) => e.range).reduce((a, b) => a + b) /
        recent.length;

    final double firstOpen = recent.first.open == 0 ? 1 : recent.first.open;
    final double priceRisePercent =
        ((last.close - recent.first.open) / firstOpen) * 100;

    final bool nearResistance =
        swingHigh > 0 && ((swingHigh - last.close) / swingHigh) * 100 < 1.25;

    final bool weakening =
        recent.length < 2 ? false : (last.close <= prev.close || last.bodySize <= prev.bodySize);

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

    if (recent.length < 6) {
      reasons.add('Grafik geçmişi kısa, setup daha temkinli okunmalı.');
    }

    String status;
    if (strength >= 70) {
      status = 'Güçlü';
    } else if (strength >= 45) {
      status = 'Orta';
    } else {
      status = 'Zayıf';
    }

    final double volatilityBuffer = math.max(
      avgRange * 0.35,
      last.close * 0.002,
    );

    final double entry = last.close;
    final double stop = math.max(swingHigh + volatilityBuffer, entry * 1.002);

    final double supportSpan = math.max(
      avgRange > 0 ? avgRange * 1.2 : entry * 0.01,
      (entry - swingLow).abs() > 0 ? (entry - swingLow).abs() : entry * 0.008,
    );

    final double target1 = math.max(entry - supportSpan * 0.55, 0);
    final double target2 = math.max(entry - supportSpan, 0);

    final double risk = math.max(stop - entry, math.max(entry * 0.001, 0.0000001));
    final double reward = math.max(entry - target2, math.max(entry * 0.001, 0.0000001));
    final double rr = reward / risk;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.55)),
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
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
    final bool hasData = setupResult != null && candles.isNotEmpty;

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
                    _buildSetupStatusCard(),
                    const SizedBox(height: 12),
                    _buildShortSetupCard(),
                    const SizedBox(height: 14),
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
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.45,
                      children: [
                        metricBox('Son fiyat', selectedCoin.lastPriceText),
                        metricBox('Mark price', selectedCoin.markPriceText),
                        metricBox('Index price', selectedCoin.indexPriceText),
                        metricBox(
                          'Funding rate',
                          selectedCoin.fundingText,
                          valueColor: selectedCoin.fundingRate < 0
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                        ),
                      ],
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

class CandleChartPainter extends CustomPainter {
  final List<CandleData> candles;

  CandleChartPainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final double maxPrice = candles.map((e) => e.high).reduce(math.max);
    final double minPrice = candles.map((e) => e.low).reduce(math.min);
    final double priceRange = math.max(maxPrice - minPrice, 0.0000001);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 5; i++) {
      final double x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final int visibleCount = candles.length;
    final double candleSpace = size.width / visibleCount;
    final double bodyWidth = math.max(candleSpace * 0.62, 2.2);

    for (int i = 0; i < visibleCount; i++) {
      final CandleData candle = candles[i];
      final double centerX = (i * candleSpace) + candleSpace / 2;

      final double highY =
          (1 - ((candle.high - minPrice) / priceRange)) * size.height;
      final double lowY =
          (1 - ((candle.low - minPrice) / priceRange)) * size.height;
      final double openY =
          (1 - ((candle.open - minPrice) / priceRange)) * size.height;
      final double closeY =
          (1 - ((candle.close - minPrice) / priceRange)) * size.height;

      final bool bullish = candle.isBullish;
      final Color candleColor =
          bullish ? const Color(0xFF37E39C) : const Color(0xFFFF5C73);

      final Paint wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.2;

      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, lowY),
        wickPaint,
      );

      final double rectTop = math.min(openY, closeY);
      final double rectBottom = math.max(openY, closeY);
      final Rect bodyRect = Rect.fromLTWH(
        centerX - bodyWidth / 2,
        rectTop,
        bodyWidth,
        math.max(rectBottom - rectTop, 1.4),
      );

      final Paint bodyPaint = Paint()..color = candleColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(1.8)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}
