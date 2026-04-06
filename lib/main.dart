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
                  child: SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/hero.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: coins.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CoinCard(
                          index: index + 1,
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
  final int index;
  final String name;
  final String change;

  const _CoinCard({
    required this.index,
    required this.name,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      width: double.infinity,
      child: Stack(
        children: [
          // Siyah kutuyu kırp
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1.0,
                heightFactor: 0.24,
                child: Image.asset(
                  'assets/list.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),

          // Eski gömülü adı kapat
          Positioned(
            left: 88,
            top: 24,
            child: Container(
              width: 190,
              height: 26,
              color: const Color(0xFF081126),
            ),
          ),

          // Eski gömülü yüzdeliği kapat
          Positioned(
            right: 26,
            top: 24,
            child: Container(
              width: 120,
              height: 26,
              color: const Color(0xFF081126),
            ),
          ),

          // Sol sıra numarası
          Positioned(
            left: 22,
            top: 22,
            child: SizedBox(
              width: 26,
              child: Text(
                "$index",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Coin adı sola hizalı
          Positioned(
            left: 92,
            top: 22,
            right: 140,
            child: Text(
              name,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Yüzde sağda
          Positioned(
            right: 34,
            top: 22,
            child: Text(
              change,
              textAlign: TextAlign.right,
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
