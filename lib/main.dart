import 'package:flutter/material.dart';

void main() {
  runApp(const ShortRadarApp());
}

class ShortRadarApp extends StatelessWidget {
  const ShortRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Short Radar',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF05060A), Color(0xFF0D0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SHORT RADAR",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔥 HERO CARD
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1A1F2E),
                        Color(0xFF0D0F1A)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.15,
                          child: Image.asset(
                            'assets/hero.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "EN GÜÇLÜ SHORT ADAYI",
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            Spacer(),
                            Text(
                              "Sinyal yok",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Şu an güçlü short adayı bulunamadı.",
                              style: TextStyle(color: Colors.white60),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "En Çok Yükselenler",
                  style: TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 10),

                // 🔥 COIN CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF141722),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue,
                        child: Text("1"),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "KOMA_USDT",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const Text(
                        "+53.75%",
                        style: TextStyle(color: Colors.green),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
