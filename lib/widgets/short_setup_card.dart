import 'package:flutter/material.dart';

class ShortSetupCard extends StatelessWidget {
  final String entry;
  final String stopLoss;
  final String target1;
  final String target2;
  final String rr;
  final String riskPercent;

  const ShortSetupCard({
    super.key,
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.rr,
    required this.riskPercent,
  });

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  double _parsePercent(String value) {
    final cleaned = value.replaceAll('%', '').replaceAll(',', '.').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final double risk = _parsePercent(riskPercent);

    double leverage;
    if (risk <= 2) {
      leverage = 10;
    } else if (risk <= 4) {
      leverage = 5;
    } else {
      leverage = 3;
    }

    final double loss5x = risk * 5;
    final double loss10x = risk * 10;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHORT SETUP',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _row('Giriş', entry),
          const SizedBox(height: 8),
          _row('Stop loss', stopLoss, valueColor: Colors.redAccent),
          const SizedBox(height: 8),
          _row('Hedef 1', target1, valueColor: Colors.greenAccent),
          const SizedBox(height: 8),
          _row('Hedef 2', target2, valueColor: Colors.greenAccent),
          const SizedBox(height: 8),
          _row('Risk / Ödül', rr, valueColor: Colors.orangeAccent),
          const SizedBox(height: 8),
          _row('Risk %', riskPercent, valueColor: Colors.redAccent),
          const SizedBox(height: 8),
          _row(
            'Önerilen Kaldıraç',
            '${leverage.toInt()}x',
            valueColor: Colors.orangeAccent,
          ),
          const SizedBox(height: 8),
          _row(
            '5x max kayıp',
            '${loss5x.toStringAsFixed(2)}%',
            valueColor: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          _row(
            '10x max kayıp',
            '${loss10x.toStringAsFixed(2)}%',
            valueColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}
