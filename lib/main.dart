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

  final List<Map<String, String>> coins = const [
    {"name": "KOMA_USDT", "change": "+58.22%"},
    {"name": "BULLA_USDT", "change": "+44.77%"},
    {"name": "PLAY_USDT", "change": "+34.27%"},
    {"name": "APR_USDT", "change": "+31.12%"},
    {"name": "TRU_USDT", "change": "+28.90%"},
    {"name": "DOGE_USDT", "change": "+25.61%"},
  ];

  @override
  Widget build(BuildContext context) {
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
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 🔴 ÜST KART
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/hero.png',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 12),

                // 🔵 COIN LIST
                ...coins.map((coin) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailPage(
                              coinName: coin["name"]!,
                              change: coin["change"]!,
                            ),
                          ),
                        );
                      },
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
                              Expanded(
                                child: Text(
                                  coin["name"]!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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

// 🔥 DETAY SAYFASI (ŞU AN BOŞ AMA HAZIR)
class DetailPage extends StatelessWidget {
  final String coinName;
  final String change;

  const DetailPage({
    super.key,
    required this.coinName,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
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
                // 🔙 GERİ BUTONU
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 🔥 COIN DETAY
                Text(
                  coinName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  change,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "DETAYLAR BURAYA GELECEK",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
