import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/coin_radar_data.dart';
import '../services/detail_data_service.dart';
import 'detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class HomeCoinView {
  final CoinRadarData coin;
  final double score;
  final String label;
  final String action;

  HomeCoinView({
    required this.coin,
    required this.score,
    required this.label,
    required this.action,
  });
}

class _HomePageState extends State<HomePage> {
  List<HomeCoinView> coins = [];

  bool isLoading = true;
  String errorText = '';
  Timer? _refreshTimer;

  static const String _url =
      'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers';

  @override
  void initState() {
    super.initState();
    fetchCoins();

    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      fetchCoins();
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
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode != 200) {
        throw Exception('API error');
      }

      final List<dynamic> parsed = json.decode(response.body);

      final List<CoinRadarData> allCoins = parsed
          .whereType<Map<String, dynamic>>()
          .map(CoinRadarData.fromJson)
          .toList();

      allCoins.sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final top10 = allCoins.take(10).toList();

      final List<HomeCoinView> result = [];

      for (final coin in top10) {
        try {
          final bundle = await DetailDataService.load(
            contractName: coin.name,
            selectedInterval: '5m',
            fallbackCoin: coin,
          );

          final decision = _buildDecision(bundle);

          result.add(
            HomeCoinView(
              coin: coin,
              score: decision['score'],
              label: decision['label'],
              action: decision['action'],
            ),
          );
        } catch (_) {
          // coin skip
        }
      }

      setState(() {
        coins = result;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorText = 'Veri alınamadı';
      });
    }
  }

  /// 🔥 DETAIL MANTIĞININ MİNİ VERSİYONU
  Map<String, dynamic> _buildDecision(DetailDataBundle bundle) {
    final setup = bundle.setupResult;
    final pump = bundle.pumpAnalysis;
    final entry = bundle.entryTiming;

    double score = 0;

    if (setup != null) score += 40;
    if (pump != null) score += 20;
    if (entry != null) score += 20;

    score = score.clamp(0, 100);

    String label;
    if (score >= 85) {
      label = 'Güçlü fırsat';
    } else if (score >= 70) {
      label = 'Kurulum var';
    } else if (score >= 40) {
      label = 'İzlenmeli';
    } else {
      label = 'Zayıf';
    }

    String action = 'WATCH';
    if (score >= 85) {
      action = 'ENTER SHORT';
    } else if (score >= 70) {
      action = 'PREPARE SHORT';
    }

    return {
      'score': score,
      'label': label,
      'action': action,
    };
  }

  Widget _buildCard(int index, HomeCoinView item) {
    final coin = item.coin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailPage(
                coinData: coin,
                oiDirection: 'FLAT',
              ),
            ),
          );
        },
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.6),
            border: Border.all(color: Colors.blueAccent),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  '$index',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),

                /// COIN
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coin.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        coin.lastPriceText,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Short skoru: ${item.score.toStringAsFixed(0)} • ${item.label}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                /// CHANGE
                Text(
                  coin.changeText,
                  style: TextStyle(
                    color: coin.changePercent > 0
                        ? Colors.green
                        : Colors.red,
                  ),
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorText.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(errorText)),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: coins
            .asMap()
            .entries
            .map((e) => _buildCard(e.key + 1, e.value))
            .toList(),
      ),
    );
  }
}
