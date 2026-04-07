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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/hero.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                /// TOP CARD
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.orange],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "APR_USDT\nPUAN: 70",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// LONG SHORT BAR
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Long / Short",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: 0.73,
                        backgroundColor: Colors.green,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.red),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "73%",
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// SIGNAL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        "SHORT İÇİN GÜÇLÜ SİNYAL!",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "RSI yüksek, funding pozitif.\nSatış baskısı bekleniyor.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// LIST
                ...List.generate(6, (i) {
                  final coins = [
                    "KOMA_USDT",
                    "BULLA_USDT",
                    "PLAY_USDT",
                    "APR_USDT",
                    "TRU_USDT",
                    "DOGE_USDT"
                  ];

                  final changes = [
                    "+58.22%",
                    "+44.77%",
                    "+34.27%",
                    "+31.12%",
                    "+28.90%",
                    "+25.61%"
                  ];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text("${i + 1}"),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            coins[i],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          changes[i],
                          style: const TextStyle(color: Colors.green),
                        )
                      ],
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
