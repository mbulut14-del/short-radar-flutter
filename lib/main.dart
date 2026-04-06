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
          // 🔴 ARKA PLAN
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // 🔴 ANA İÇERİK
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 🔴 HERO (EN GÜÇLÜ SHORT)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    'assets/hero.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(),

                // 🔵 LİST (ALT)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/list.png',
                    fit: BoxFit.contain,
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
