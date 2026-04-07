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
      home: const HomePage(),
    );
  }
}

class CoinItem {
  final String name;
  final double change;

  const CoinItem(this.name, this.change);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const topCoin = CoinItem('APR_USDT', 34.27);

  static const coins = [
    CoinItem('KOMA_USDT', 58.22),
    CoinItem('BULLA_USDT', 44.77),
    CoinItem('PLAY_USDT', 34.27),
    CoinItem('APR_USDT', 31.12),
    CoinItem('TRU_USDT', 28.90),
    CoinItem('DOGE_USDT', 25.61),
    CoinItem('WIF_USDT', 23.48),
    CoinItem('PEPE_USDT', 21.76),
    CoinItem('BONK_USDT', 19.84),
    CoinItem('FLOKI_USDT', 17.93),
  ];

  @override
  Widget build
