import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Map<String, String>> coins = const [
    {"name": "KOMA_USDT", "change": "+58.22%"},
    {"name": "BULLA_USDT", "change": "+44.77%"},
    {"name": "PLAY_USDT", "change": "+34.27%"},
    {"name": "APR_USDT", "change": "+31.12%"},
    {"name": "TRU_USDT", "change": "+28.90%"},
    {"name": "DOGE_USDT", "change": "+25.61%"},
    {"name": "SOL_USDT", "change": "+22.10%"},
    {"name": "ETH_USDT", "change": "+19.85%"},
    {"name": "BTC_USDT", "change": "+17.40%"},
    {"name": "XRP_USDT", "change": "+15.12%"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔥 ARKA PLAN
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🔥 TÜM SAYFA
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                // 🔴 ÜST KART (BÜYÜTÜLDÜ)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/hero.png',
                    width: double.infinity,
                    height: 200, // 🔥 BURASI BÜYÜDÜ
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 12),

                // 🔵 LİSTE
                ...coins.map((coin) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF071A2F),
                            Color(0xFF0A2540),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            // 🔵 NUMARA
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.blueAccent, width: 2),
                              ),
                              child: const Center(
                                child: Text(
                                  "1",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 🟢 COIN ADI
                            Expanded(
                              child: Text(
                                coin["name"]!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // 🟢 YÜZDE
                            Text(
                              coin["change"]!,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
