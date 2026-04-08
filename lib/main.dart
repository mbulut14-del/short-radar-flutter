import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

const String _tickersUrl = 'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers';
const Map<String, String> _jsonHeader = {'Accept': 'application/json'};

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

String _formatPrice(double value, {int digits = 6}) => value == 0 ? '-' : value.toStringAsFixed(digits);
String _formatPercent(double value, {int digits = 2}) => '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
String _formatFunding(double value) {
  final percent = value * 100;
  return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(4)}%';
}

Future<List<CoinRadarData>> _fetchAllCoins() async {
  final response = await http.get(Uri.parse(_tickersUrl), headers: _jsonHeader);
  if (response.statusCode != 200) throw Exception('API error');

  final List<dynamic> parsed = json.decode(response.body);
  return parsed
      .whereType<Map<String, dynamic>>()
      .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
      .map(CoinRadarData.fromJson)
      .toList();
}

BoxDecoration _glassBox({
  Color? borderColor,
  double radius = 16,
  double opacity = 0.35,
  List<BoxShadow>? boxShadow,
}) {
  return BoxDecoration(
    color: Colors.black.withOpacity(opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.12)),
    boxShadow: boxShadow,
  );
}

Widget _liveBadge(bool isLoading, {String readyText = 'Canlı Veri'}) {
  final color = isLoading ? Colors.orangeAccent : Colors.greenAccent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color),
    ),
    child: Text(
      isLoading ? 'Yükleniyor' : readyText,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Widget _errorBox(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.18),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

Color _scoreColor(int score) {
  if (score >= 75) return Colors.redAccent;
  if (score >= 60) return Colors.orangeAccent;
  if (score >= 45) return Colors.amberAccent;
  return Colors.greenAccent;
}

Color _changeColor(double value) => value < 0 ? Colors.redAccent : const Color(0xFF3CFFB2);

class CoinRadarData {
  final String name;
  final double changePercent, fundingRate, lastPrice, markPrice, indexPrice, volume24h;
  final int score;
  final String biasLabel, note;

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

  factory CoinRadarData.seed({required String name, required double changePercent}) {
    final score = _calculateScore(
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
    final changePercent = _parseDouble(json['change_percentage']);
    final fundingRate = _parseDouble(json['funding_rate']);
    final lastPrice = _parseDouble(json['last']);
    final markPrice = _parseDouble(json['mark_price']);
    final indexPrice = _parseDouble(json['index_price']);
    final volume24h = _parseDouble(json['volume_24h_quote'] ?? json['volume_24h'] ?? 0);

    final score = _calculateScore(
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
      note: _noteText(score, changePercent, fundingRate, markPrice, indexPrice),
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
      final divergence = ((markPrice - indexPrice) / indexPrice).abs() * 100;
      score += math.min(divergence * 22, 14);
    }

    if (volume24h > 0) {
      final volumeBoost = math.max(0, math.min((math.log(volume24h + 1) - 10) * 2.2, 10));
      score += volumeBoost;
    }

    return score.clamp(0, 100).round();
  }

  static String _biasLabel(int score) {
    if (score >= 75) return 'Çok güçlü short';
    if (score >= 60) return 'Güçlü short';
    if (score >= 45) return 'İzlemeye değer';
    if (score >= 30) return 'Zayıf baskı';
    return 'Nötr';
  }

  static String _noteText(int score, double changePercent, double fundingRate, double markPrice, double indexPrice) {
    final divergence = indexPrice == 0 ? 0 : ((markPrice - indexPrice) / indexPrice).abs() * 100;
    if (score >= 75) return 'Pump güçlü, funding şişmiş. Sert short takibi.';
    if (score >= 60) return 'Yükseliş ve funding birlikte ısınıyor.';
    if (score >= 45) return 'İzlenebilir short baskısı oluşuyor.';
    if (changePercent < 0) return 'Zaten zayıflamış, short avantajı düşebilir.';
    if (divergence > 0.20) return 'Fiyat farkı var, volatilite yükselebilir.';
    if (fundingRate > 0) return 'Funding pozitif ama sinyal orta güçte.';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final AnimationController _logoController;
  late final Animation<double> _textOpacity, _logoOpacity, _logoScale, _logoGlow, _logoTranslateY;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

    _textOpacity = CurvedAnimation(parent: _textController, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    _logoOpacity = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));
    _logoGlow = Tween<double>(begin: 0.45, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoTranslateY = Tween<double>(begin: -180, end: 0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));

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
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFEDEDED), Color(0xFFFFB300)],
          ).createShader(bounds),
          child: const Text(
            'SHORT RADAR PRO',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.1),
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
                      color: const Color(0xFF7B2CFF).withOpacity(0.22 * _logoGlow.value),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF2E63).withOpacity(0.20 * _logoGlow.value),
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
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }

  Widget _glowCircle({
    required double size,
    required Color color,
    double opacity = 0.12,
    double blurRadius = 80,
    double spreadRadius = 30,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity + 0.08),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.15,
            colors: [Color(0xFF0B0B13), Color(0xFF050507), Colors.black],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -80, left: -50, child: _glowCircle(size: 220, color: const Color(0xFF243CFF))),
            Positioned(
              right: -70,
              bottom: 120,
              child: _glowCircle(
                size: 240,
                color: const Color(0xFFFF2E63),
                opacity: 0.10,
                blurRadius: 90,
                spreadRadius: 35,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildAnimatedLogo(), const SizedBox(height: 28), _buildSplashText()],
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

  @override
  void initState() {
    super.initState();
    radarLeader = coins.first;
    fetchCoins();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) fetchCoins();
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
      final allCoins = await _fetchAllCoins();
      if (allCoins.isEmpty) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri boş döndü';
        });
        return;
      }

      final sortedByChange = [...allCoins]..sort((a, b) => b.changePercent.compareTo(a.changePercent));
      final sortedByScore = [...allCoins]
        ..sort((a, b) {
          final scoreCompare = b.score.compareTo(a.score);
          return scoreCompare != 0 ? scoreCompare : b.changePercent.compareTo(a.changePercent);
        });

      setState(() {
        coins = sortedByChange.take(10).toList();
        radarLeader = sortedByScore.first;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorText = 'Canlı veri alınamadı';
      });
    }
  }

  Widget _miniInfo(String title, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarHero() {
    final leader = radarLeader;
    if (leader == null) return const SizedBox(height: 150);

    final scoreColor = _scoreColor(leader.score);

    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          Positioned(top: 0, right: 0, child: _liveBadge(isLoading)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _glassBox(
                borderColor: scoreColor.withOpacity(0.75),
                radius: 24,
                opacity: 0.55,
                boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.18), blurRadius: 18, spreadRadius: 1)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                      border: Border.all(color: scoreColor, width: 3),
                      boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.35), blurRadius: 16, spreadRadius: 2)],
                    ),
                    child: Text(
                      '${leader.score}',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EN GÜÇLÜ SHORT ADAYI',
                          style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leader.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
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

  Widget _buildCoinCard(int index, CoinRadarData coin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailPage(coinData: coin, leaderData: radarLeader)),
          );
        },
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF07122A), Color(0xFF091933), Color(0xFF07122A)],
            ),
            border: Border.all(color: const Color(0xFF3EA6FF), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x663EA6FF), blurRadius: 10, spreadRadius: 1),
              BoxShadow(color: Color(0x3300FFFF), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF123D9B),
                    border: Border.all(color: const Color(0xFF5AA8FF), width: 1.6),
                    boxShadow: const [BoxShadow(color: Color(0x663EA6FF), blurRadius: 8, spreadRadius: 1)],
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Short skoru: ${coin.score} • ${coin.biasLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  coin.changeText,
                  style: TextStyle(color: _changeColor(coin.changePercent), fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/bg.png', fit: BoxFit.cover)),
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
                      decoration: _glassBox(borderColor: Colors.orangeAccent.withOpacity(0.45), opacity: 0.32),
                      child: Row(
                        children: [
                          const Icon(Icons.radar_rounded, color: Colors.orangeAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              radarLeader!.note,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (errorText.isNotEmpty) ...[const SizedBox(height: 10), _errorBox(errorText)],
                  const SizedBox(height: 12),
                  ...coins.asMap().entries.map((entry) => _buildCoinCard(entry.key + 1, entry.value)),
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

  const DetailPage({super.key, required this.coinData, this.leaderData});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Timer? _detailTimer;
  bool detailLoading = true;
  String detailError = '';
  late CoinRadarData selectedCoin;
  late CoinRadarData heroCoin;

  @override
  void initState() {
    super.initState();
    selectedCoin = widget.coinData;
    heroCoin = widget.leaderData ?? widget.coinData;
    fetchDetail();
    _detailTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) fetchDetail();
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
      final allCoins = await _fetchAllCoins();
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

      final sortedByScore = [...allCoins]
        ..sort((a, b) {
          final scoreCompare = b.score.compareTo(a.score);
          return scoreCompare != 0 ? scoreCompare : b.changePercent.compareTo(a.changePercent);
        });

      setState(() {
        selectedCoin = detailItem!;
        heroCoin = sortedByScore.first;
        detailLoading = false;
      });
    } catch (_) {
      setState(() {
        detailLoading = false;
        detailError = 'Detay verisi alınamadı';
      });
    }
  }

  Widget metricBox(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _glassBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: valueColor ?? Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF09101E), const Color(0xFF101B32).withOpacity(0.95), const Color(0xFF140B18)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, spreadRadius: 2)],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _glassBox(borderColor: Colors.orangeAccent.withOpacity(0.55), opacity: 0.55),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                    border: Border.all(color: Colors.orangeAccent, width: 2.5),
                  ),
                  child: Text(
                    '${heroCoin.score}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EN GÜÇLÜ SHORT ADAYI',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        heroCoin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Funding: ${heroCoin.fundingText} • Değişim: ${heroCoin.changeText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBar(int greenFlex, int redFlex) {
    return Container(
      height: 14,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            flex: greenFlex,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.65),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
              ),
            ),
          ),
          Expanded(
            flex: redFlex,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.85),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final redFlex = selectedCoin.score.clamp(10, 90);
    final greenFlex = (100 - redFlex).clamp(10, 90);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/bg.png', fit: BoxFit.cover)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _liveBadge(detailLoading, readyText: 'Canlı Detay'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildHeroCard(),
                  const SizedBox(height: 20),
                  if (detailError.isNotEmpty) ...[_errorBox(detailError), const SizedBox(height: 16)],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _glassBox(borderColor: Colors.redAccent.withOpacity(0.4)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedCoin.name,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              selectedCoin.changeText,
                              style: TextStyle(
                                color: _changeColor(selectedCoin.changePercent),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Short skoru: ${selectedCoin.score} • ${selectedCoin.biasLabel}',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildScoreBar(greenFlex, redFlex),
                        const SizedBox(height: 10),
                        Text(
                          selectedCoin.note,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        valueColor: selectedCoin.fundingRate < 0 ? Colors.redAccent : Colors.orangeAccent,
                      ),
                      metricBox('Short skoru', '${selectedCoin.score}', valueColor: Colors.orangeAccent),
                      metricBox(
                        'Mark-Index farkı',
                        _formatPercent(selectedCoin.divergencePercent, digits: 3),
                        valueColor: Colors.cyanAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 190,
                    decoration: _glassBox(borderColor: Colors.orangeAccent.withOpacity(0.4)),
                    child: CustomPaint(
                      painter: ChartPainter(isBullish: selectedCoin.changePercent >= 0),
                      child: Center(
                        child: Text(
                          selectedCoin.biasLabel,
                          style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CANLI DETAY EKRANI',
                          style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${selectedCoin.name} için son fiyat, funding, mark-index farkı ve short skoru canlı güncelleniyor.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final bool isBullish;
  ChartPainter({required this.isBullish});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 1;

    for (double i = 0; i <= size.width; i += size.width / 6) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i <= size.height; i += size.height / 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final mainColor = isBullish ? Colors.redAccent : Colors.greenAccent;
    final glowColor = isBullish ? Colors.orangeAccent : Colors.greenAccent;

    final linePaint = Paint()..color = mainColor..strokeWidth = 3..style = PaintingStyle.stroke;
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.35)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();

    if (isBullish) {
      path.moveTo(0, size.height * 0.18);
      path.lineTo(size.width * 0.10, size.height * 0.23);
      path.lineTo(size.width * 0.20, size.height * 0.29);
      path.lineTo(size.width * 0.32, size.height * 0.38);
      path.lineTo(size.width * 0.46, size.height * 0.48);
      path.lineTo(size.width * 0.60, size.height * 0.57);
      path.lineTo(size.width * 0.76, size.height * 0.70);
      path.lineTo(size.width, size.height * 0.86);
    } else {
      path.moveTo(0, size.height * 0.82);
      path.lineTo(size.width * 0.12, size.height * 0.74);
      path.lineTo(size.width * 0.24, size.height * 0.66);
      path.lineTo(size.width * 0.40, size.height * 0.56);
      path.lineTo(size.width * 0.58, size.height * 0.41);
      path.lineTo(size.width * 0.74, size.height * 0.29);
      path.lineTo(size.width, size.height * 0.16);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) => oldDelegate.isBullish != isBullish;
}
