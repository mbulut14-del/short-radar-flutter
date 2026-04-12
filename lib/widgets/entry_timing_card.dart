import 'package:flutter/material.dart';
import '../models/entry_timing_result.dart';

class EntryTimingCard extends StatelessWidget {
  final EntryTimingResult result;

  const EntryTimingCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final topReasons = result.reasons.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GİRİŞ ZAMANI',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Skor',
            '${result.score}/100',
            valueColor: Colors.orangeAccent,
          ),
          const SizedBox(height: 8),
          _row(
            'Short hazır mı',
            result.ready ? 'Evet' : 'Hayır',
            valueColor: result.ready ? Colors.greenAccent : Colors.white70,
          ),
          if (topReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Sinyaller',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...topReasons.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
}
