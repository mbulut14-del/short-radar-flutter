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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05060A),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SHORT RADAR',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'EN GUCLU SHORT ADAYI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 230,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  image: const DecorationImage(
                    image: AssetImage('assets/hero.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FF4D00),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 46,
                      top: 95,
                      child: Text(
                        '58',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 175,
                      top: 44,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'EN GUCLU SHORT ADAYI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFA126),
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'RLS_USDT',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Puan: 58\nRSI: 80.9\nFunding: 0.0050%\nDegisim: %162.36\nKirmizi mum: Hayir',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Gate.io Vadeli En Cok Yukselenler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _coinCard('1', 'SIREN_USDT', '+163.67%', '77'),
              const SizedBox(height: 12),
              _coinCard('2', 'RLS_USDT', '+162.36%', '58'),
              const SizedBox(height: 12),
              _coinCard('3', 'D_USDT', '+74.59%', '30'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinCard(String rank, String coin, String change, String score) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FF6A2A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22FF5A1F),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF35A8FF), width: 6),
            ),
            alignment: Alignment.center,
            child: Text(
              rank,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coin,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6F6F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  change,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2DFFB2),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.only(right: 18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF6A45), width: 7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33FF6A45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              score,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
