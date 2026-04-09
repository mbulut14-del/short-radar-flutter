
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/coin_radar_data.dart';
import 'detail_page.dart';

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

  @override
  void initState() {
    super.initState();
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
    try {
      final response = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
      );

      final List parsed = json.decode(response.body);

      final List<CoinRadarData> all = parsed
          .map((e) => CoinRadarData.fromJson(e))
          .toList();

      all.sort((a, b) => b.score.compareTo(a.score));

      setState(() {
        coins = all.take(10).toList();
        radarLeader = all.first;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = 'Veri alınamadı';
        isLoading = false;
      });
    }
  }

  Widget radarCard() {
    if (radarLeader == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            radarLeader!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            radarLeader!.biasLabel,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ],
      ),
    );
  }

  Widget coinItem(CoinRadarData coin) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(coinData: coin),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                coin.name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Text(
              '${coin.score}',
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  radarCard(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: coins.map(coinItem).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
