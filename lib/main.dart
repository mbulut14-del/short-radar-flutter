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
          // Arka plan
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Ortadaki kart
          Center(
            child: Image.asset(
              'assets/hero.png',
              width: 350,
            ),
          ),

          // Alt liste
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Image.asset(
              'assets/list.png',
              height: 80,
            ),
          ),
        ],
      ),
    );
  }
}
