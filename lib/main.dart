import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = [
      {"name": "KOMA_USDT", "change": "+58.22%"},
      {"name": "BULLA_USDT", "change": "+44.77%"},
      {"name": "PLAY_USDT", "change": "+34.27%"},
      {"name": "APR_USDT", "change": "+31.12%"},
      {"name": "TRU_USDT", "change": "+28.90%"},
    ];

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
            child: Column(
              children: [
                const SizedBox(height: 12),

                // HERO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    'assets/hero.png',
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 16),

                // LİSTE
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: coins.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CoinCard(
                          name: coins[index]["name
