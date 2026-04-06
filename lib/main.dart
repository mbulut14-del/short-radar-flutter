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
          // ARKA PLAN
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

                // HERO (ÜST KART)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    'assets/hero.png',
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 20),

                // LİSTE
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: Image.asset(
                            'assets/list.png',
                            width: double.infinity,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
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
