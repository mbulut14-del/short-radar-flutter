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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    'assets/hero.png',
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: coins.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CoinCard(
                          name: coins[index]["name"]!,
                          change: coins[index]["change"]!,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final String name;
  final String change;

  const _CoinCard({
    required this.name,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.center,
                heightFactor: 0.18,
                child: Image.asset(
                  'assets/list.png',
                  width: MediaQuery.of(context).size.width - 32,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
          Positioned(
            left: 92,
            top: 22,
            right: 150,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 22,
            child: Text(
              change,
              style: const TextStyle(
                color: Color(0xFF3CFFB2),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
