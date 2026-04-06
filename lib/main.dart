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
                const SizedBox(height: 10),
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
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: coins.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CoinCard(
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

class CoinCard extends StatelessWidget {
  final int index;
  final String name;
  final String change;

  const CoinCard({
    super.key,
    required this.index,
    required this.name,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
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
              width: 42,
              height: 42,
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
                "$index",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              change,
              style: const TextStyle(
                color: Color(0xFF3CFFB2),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
