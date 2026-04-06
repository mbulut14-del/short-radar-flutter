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
      height: 88,
      width: double.infinity,
      child: Stack(
        children: [
          // list.png içindeki siyah dış alanları kırp
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: Image.asset('assets/list.png'),
              ),
            ),
          ),

          // Eski gömülü coin adını kapat
          Positioned(
            left: 88,
            top: 22,
            child: Container(
              width: 210,
              height: 28,
              color: const Color(0xFF081126),
            ),
          ),

          // Eski gömülü yüzdeyi kapat
          Positioned(
            right: 26,
            top: 22,
            child: Container(
              width: 120,
              height: 28,
              color: const Color(0xFF081126),
            ),
          ),

          // Yeni coin adı
          Positioned(
            left: 92,
            top: 20,
            right: 150,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Yeni yüzde
          Positioned(
            right: 30,
            top: 20,
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
