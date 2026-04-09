import 'package:flutter/material.dart';

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'models/coin_radar_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Short Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final coin = settings.arguments as CoinRadarData;

          return MaterialPageRoute(
            builder: (_) => DetailPage(coinData: coin),
          );
        }
        return null;
      },
    );
  }
}
