import 'package:flutter/material.dart';

class ShortSetupCard extends StatelessWidget {
  final String entry;
  final String stopLoss;
  final String target1;
  final String target2;
  final String rr;

  const ShortSetupCard({
    super.key,
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.rr,
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

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
