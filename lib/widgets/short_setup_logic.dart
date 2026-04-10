import 'package:flutter/material.dart';
import '../models/short_setup_result.dart';

Widget buildShortSetup(ShortSetupResult setup) {
  final riskPercent = ((setup.stopLoss - setup.entry) / setup.entry) * 100;

  double leverage;
  if (riskPercent <= 2) {
    leverage = 10;
  } else if (riskPercent <= 4) {
    leverage = 5;
  } else {
    leverage = 3;
  }

  final double loss5x = riskPercent * 5;
  final double loss10x = riskPercent * 10;

  Widget row(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    children: [
      row("Giriş", setup.entry.toStringAsFixed(6), Colors.white),
      row("Stop loss", setup.stopLoss.toStringAsFixed(6), Colors.redAccent),
      row("Hedef 1", setup.target1.toStringAsFixed(6), Colors.greenAccent),
      row("Hedef 2", setup.target2.toStringAsFixed(6), Colors.greenAccent),
      row("Risk / Ödül", setup.rr.toStringAsFixed(2), Colors.orangeAccent),
      row("Risk %", "${riskPercent.toStringAsFixed(2)}%", Colors.redAccent),
      row("Önerilen Kaldıraç", "${leverage.toInt()}x", Colors.orangeAccent),
      const SizedBox(height: 8),
      row("5x max kayıp", "${loss5x.toStringAsFixed(2)}%", Colors.redAccent),
      row("10x max kayıp", "${loss10x.toStringAsFixed(2)}%", Colors.redAccent),
    ],
  );
}
