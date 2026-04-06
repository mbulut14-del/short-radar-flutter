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
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = constraints.maxHeight;
                final heroHeight = screenHeight * 0.24;
                final listHeight = screenHeight * 0.10;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/hero.png',
                          width: double.infinity,
                          height: heroHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Image.asset(
                          'assets/list.png',
                          width: double.infinity,
                          height: listHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Image.asset(
                          'assets/list.png',
                          width: double.infinity,
                          height: listHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Image.asset(
                          'assets/list.png',
                          width: double.infinity,
                          height: listHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Image.asset(
                          'assets/list.png',
                          width: double.infinity,
                          height: listHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Image.asset(
                          'assets/list.png',
                          width: double.infinity,
                          height: listHeight,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
