import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/coin_radar_data.dart';
import 'detail_page.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CoinRadarData> coins = [];

  CoinRadarData? radarLeader;
  bool isLoading = true;
  String errorText = '';
  Timer? _refreshTimer;

  String? lastNotifiedCoin;
  DateTime? lastNotifyTime;

  // ✅ Her coin için OI geçmişi
  final Map<String, List<double>> _oiHistory = {};

  // ✅ Her coin için fiyat geçmişi
  final Map<String, List<double>> _priceHistory = {};

  // ✅ Hesaplanan yön ve sinyal cache
  final Map<String, String> _oiDirectionMap = {};
  final Map<String, String> _priceDirectionMap = {};
  final Map<String, String> _oiPriceSignalMap = {};

  static const int _historyLimit = 360; // 30dk / 5sn

  @override
  void initState() {
    super.initState();
    fetchCoins();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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

  void _updateOiHistory(String symbol, double oi) {
    final history = _oiHistory.putIfAbsent(symbol, () => <double>[]);

    history.add(oi);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  void _updatePriceHistory(String symbol, double price) {
    final history = _priceHistory.putIfAbsent(symbol, () => <double>[]);

    history.add(price);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  String _calculateDirectionFromHistory(List<double>? history) {
    if (history == null || history.length < 2) {
      return 'FLAT';
    }

    final double first = history.first;
    final double last = history.last;

    if (first <= 0) return 'FLAT';

    final double changePercent = ((last - first) / first) * 100;

    if (changePercent > 1) return 'UP';
    if (changePercent < -1) return 'DOWN';
    return 'FLAT';
  }

  String _calculateOiDirection(String symbol) {
    return _calculateDirectionFromHistory(_oiHistory[symbol]);
  }

  String _calculatePriceDirection(String symbol) {
    return _calculateDirectionFromHistory(_priceHistory[symbol]);
  }

  String _calculateOiPriceSignal({
    required String oiDirection,
    required String priceDirection,
  }) {
    if (oiDirection == 'UP' && priceDirection == 'DOWN') {
      return 'STRONG_SHORT';
    }
    if (oiDirection == 'UP' && priceDirection == 'UP') {
      return 'PUMP_RISK';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'UP') {
      return 'SHORT_SQUEEZE';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'DOWN') {
      return 'WEAK_DROP';
    }
    return 'NEUTRAL';
  }

  CoinRadarData _withOiDirection(CoinRadarData coin, String direction) {
    return CoinRadarData(
      name: coin.name,
      changePercent: coin.changePercent,
      fundingRate: coin.fundingRate,
      lastPrice: coin.lastPrice,
      markPrice: coin.markPrice,
      indexPrice: coin.indexPrice,
      volume24h: coin.volume24h,
      openInterest: coin.openInterest,
      oiDirection: direction,
      score: coin.score,
      biasLabel: coin.biasLabel,
      note: coin.note,
    );
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

      final List<CoinRadarData> rawCoins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (rawCoins.isEmpty) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri boş döndü';
        });
        return;
      }

      final List<CoinRadarData> allCoins = rawCoins.map((coin) {
        _updateOiHistory(coin.name, coin.openInterest);
        _updatePriceHistory(coin.name, coin.lastPrice);

        final String oiDirection = _calculateOiDirection(coin.name);
        final String priceDirection = _calculatePriceDirection(coin.name);
        final String oiPriceSignal = _calculateOiPriceSignal(
          oiDirection: oiDirection,
          priceDirection: priceDirection,
        );

        _oiDirectionMap[coin.name] = oiDirection;
        _priceDirectionMap[coin.name] = priceDirection;
        _oiPriceSignalMap[coin.name] = oiPriceSignal;

        return _withOiDirection(coin, oiDirection);
      }).toList();

      final List<CoinRadarData> sortedByChange = [...allCoins]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final List<CoinRadarData> sortedByScore = [...allCoins]
        ..sort((a, b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return b.changePercent.compareTo(a.changePercent);
        });

      final CoinRadarData leader = sortedByScore.first;

      setState(() {
        coins = sortedByChange.take(10).toList();
        radarLeader = leader;
        isLoading = false;
        errorText = '';
      });

      if (leader.score >= 70 && leader.fundingRate > 0) {
        final now = DateTime.now();

        final bool isSameCoin = lastNotifiedCoin == leader.name;
        final bool isTooSoon = lastNotifyTime != null &&
            now.difference(lastNotifyTime!).inMinutes < 30;

        if (!isSameCoin || !isTooSoon) {
          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
            'short_channel',
            'Short Alerts',
            importance: Importance.max,
            priority: Priority.high,
          );

          const NotificationDetails details =
              NotificationDetails(android: androidDetails);

          await notificationsPlugin.show(
            0,
            'SHORT BAŞLIYOR 🚨',
            '${leader.name} güçlü short sinyali veriyor',
            details,
          );

          lastNotifiedCoin = leader.name;
          lastNotifyTime = now;
        }
      }
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

  Widget _buildRadarHero() {
    final CoinRadarData? leader = radarLeader;
    if (leader == null) {
      return SizedBox(
        height: 150,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    color:
                        isLoading ? Colors.orangeAccent : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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

  Widget _buildInfoCard() {
    if (radarLeader == null) return const SizedBox.shrink();

    return Container(
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
    );
  }

  Widget _buildErrorCard() {
    if (errorText.isEmpty) return const SizedBox.shrink();

    return Container(
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
    );
  }

  Widget _buildCoinCard(int index, CoinRadarData coin) {
    final String oiDirection = _oiDirectionMap[coin.name] ?? coin.oiDirection;
    final String priceDirection = _priceDirectionMap[coin.name] ?? 'FLAT';
    final String oiPriceSignal = _oiPriceSignalMap[coin.name] ?? 'NEUTRAL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailPage(
                coinData: coin,
                oiDirection: oiDirection,
                priceDirection: priceDirection,
                oiPriceSignal: oiPriceSignal,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        coin.lastPriceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
  }

  Widget _buildInitialLoadingState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            ),
            SizedBox(height: 14),
            Text(
              'Short fırsatları analiz ediliyor...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showInitialLoader = coins.isEmpty && isLoading;

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
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildErrorCard(),
                  ],
                  const SizedBox(height: 12),
                  if (showInitialLoader)
                    _buildInitialLoadingState()
                  else
                    ...coins.asMap().entries.map((entry) {
                      final int index = entry.key + 1;
                      final CoinRadarData coin = entry.value;
                      return _buildCoinCard(index, coin);
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
