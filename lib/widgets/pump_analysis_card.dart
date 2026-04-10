
import 'package:flutter/material.dart';
import '../models/pump_analysis_result.dart';

class PumpAnalysisCard extends StatelessWidget {
  final PumpAnalysisResult result;

  const PumpAnalysisCard({
    super.key,
    required this.result,
  });

  Color _getPumpColor() {
    switch (result.pumpType) {
      case "FAKE":
        return Colors.redAccent;
      case "REAL":
        return Colors.greenAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  String _getPumpText() {
    switch (result.pumpType) {
      case "FAKE":
        return "Fake Pump";
      case "REAL":
        return "Gerçek Pump";
      default:
        return "Belirsiz";
    }
  }

  String _getEntryText() {
    if (!result.shortReady) return "Bekle";

    if (result.entryScore > 70) return "Giriş uygun";
    if (result.entryScore > 50) return "Hazırlanıyor";

    return "Zayıf";
  }

  Color _getEntryColor() {
    if (!result.shortReady) return Colors.grey;

    if (result.entryScore > 70) return Colors.greenAccent;
    if (result.entryScore > 50) return Colors.orangeAccent;

    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔥 BAŞLIK
          const Text(
            "PUMP ANALİZİ",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 12),

          /// 📊 PUMP TİPİ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Pump tipi", style: TextStyle(color: Colors.white70)),
              Text(
                _getPumpText(),
                style: TextStyle(
                  color: _getPumpColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// ⚡ SCORE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Pump skoru", style: TextStyle(color: Colors.white70)),
              Text(
                result.pumpScore.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// ⏱ ENTRY
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Giriş zamanı", style: TextStyle(color: Colors.white70)),
              Text(
                _getEntryText(),
                style: TextStyle(
                  color: _getEntryColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 🧠 REASONS
          const Text(
            "Neden?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          ...result.reasons.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• $e",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
