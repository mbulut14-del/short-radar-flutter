import 'package:flutter/material.dart';
import '../models/short_setup_result.dart';

class RiskPanelCard extends StatelessWidget {
  final ShortSetupResult result;

  const RiskPanelCard({
    super.key,
    required this.result,
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

  String _formatPercent(double value, {int digits = 2}) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
  }

  @override
  Widget build(BuildContext context) {
    final double stopDistancePercent =
        ((result.stopLoss - result.entry) / result.entry) * 100;
    final double targetDistancePercent =
        ((result.entry - result.target2) / result.entry) * 100;

    Color riskColor;
    String riskText;

    if (result.rr >= 1.5 && stopDistancePercent <= 3.0) {
      riskColor = Colors.greenAccent;
      riskText = 'Kontrollü';
    } else if (result.rr >= 1.0 && stopDistancePercent <= 4.5) {
      riskColor = Colors.orangeAccent;
      riskText = 'Orta';
    } else {
      riskColor = Colors.redAccent;
      riskText = 'Yüksek';
    }

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
            'GERÇEK RİSK PANELİ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Stop mesafesi',
            _formatPercent(stopDistancePercent),
            valueColor: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          _row(
            'Hedef mesafesi',
            _formatPercent(targetDistancePercent),
            valueColor: Colors.greenAccent,
          ),
          const SizedBox(height: 8),
          _row(
            'Risk seviyesi',
            riskText,
            valueColor: riskColor,
          ),
          const SizedBox(height: 8),
          _row(
            'Tahmini yön',
            result.status,
            valueColor: riskColor,
          ),
        ],
      ),
    );
  }
}
