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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ARKA PLAN (FULL SCREEN)
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // ORTA ANA KART
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Image.asset(
                'assets/hero.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ALT LİSTE
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Image.asset(
              'assets/list.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
