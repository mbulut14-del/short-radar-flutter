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

/// 🔹 ANA SAYFA
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
    {"name": "ETH_USDT", "change": "+19.40%"},
    {"name": "BTC_USDT", "change": "+17.80%"},
    {"name": "XRP_USDT", "change": "+15.20%"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                /// 🔥 ÜST KART (PNG)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/hero.png'),
                ),

                const SizedBox(height: 20),

                /// 🔹 COIN LİSTESİ (10 ADET)
                ...coins.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  var coin = entry.value;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPage(
                            coin: coin["name"]!,
                            change: coin["change"]!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue,
                            child: Text("$index"),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              coin["name"]!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            coin["change"]!,
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔥 DETAY SAYFASI (FULL)
class DetailPage extends StatelessWidget {
  final String coin;
  final String change;

  const DetailPage({super.key, required this.coin, required this.change});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// 🔙 GERİ
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  /// 🔥 HERO KART
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/hero.png'),
                  ),

                  const SizedBox(height: 20),

                  /// 📊 LONG SHORT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("Long / Short",
                                style: TextStyle(color: Colors.white)),
                            Text("73%",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                            Container(
                              height: 10,
                              width: 250,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 📉 GRAFİK
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(
                      painter: ChartPainter(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// ⚠️ SİNYAL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          "SHORT İÇİN GÜÇLÜ SİNYAL!",
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "RSI yüksek, satış baskısı bekleniyor.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 📉 FAKE GRAFİK
class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.3);

    for (double i = 0; i < size.width; i += 20) {
      double y = size.height * (0.3 + (i / size.width) * 0.5);
      path.lineTo(i, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
