import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/coin_radar_data.dart';
import '../services/detail_data_service.dart';
import '../services/decision_engine.dart';
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
  bool firstLoad = true;
  Timer? _timer;

  static const String url =
      'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers';

  @override
  void initState() {
    super.initState();
    fetchCoins();

    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      fetchCoins(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchCoins({bool silent = false}) async {
    if (!silent) {
      setState(() => firstLoad = true);
    }

    try {
      final res = await http.get(Uri.parse(url));
      final List data = json.decode(res.body);

      final all = data
          .whereType<Map<String, dynamic>>()
          .map(CoinRadarData.fromJson)
          .toList();

      all.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      final top10 = all.take(10).toList();

      final List<HomeCoinView> temp = [];

      for (final coin in top10) {
        try {
          final bundle = await DetailDataService.load(
            contractName: coin.name,
            selectedInterval: '5m',
            fallbackCoin: coin,
          );

          final decision = DecisionEngine().build(
            oiPriceSignal: bundle.oiPriceSignal,
            oiDirection: bundle.selectedCoin.oiDirection,
            priceDirection: bundle.priceDirection,
            orderFlowDirection: bundle.orderFlowDirection,
            pumpAnalysis: bundle.pumpAnalysis,
            entryTiming: bundle.entryTiming,
            setupResult: bundle.setupResult,
            visibleCandles: bundle.visibleCandles,
          );

          temp.add(
            HomeCoinView(
              coin: coin,
              score: decision.finalScore,
              label: decision.scoreClass,
              action: decision.action,
            ),
          );
        } catch (_) {}
      }

      setState(() {
        coins = temp;
        firstLoad = false;
      });
    } catch (_) {
      setState(() => firstLoad = false);
    }
  }

  Widget buildCard(int index, HomeCoinView item) {
    final coin = item.coin;

    return GestureDetector(
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
        margin: const EdgeInsets.only(bottom: 10),
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent),
          color: Colors.black.withOpacity(0.6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text('$index',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coin.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),

                    Text(coin.lastPriceText,
                        style: const TextStyle(color: Colors.white70)),

                    Text(
                      'Short skoru: ${item.score.toStringAsFixed(0)} • ${item.label}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),

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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (firstLoad) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: coins
            .asMap()
            .entries
            .map((e) => buildCard(e.key + 1, e.value))
            .toList(),
      ),
    );
  }
}
