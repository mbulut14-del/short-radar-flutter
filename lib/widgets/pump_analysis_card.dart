import 'package:flutter/material.dart';
import '../models/pump_analysis_result.dart';

class PumpAnalysisCard extends StatelessWidget {
  final PumpAnalysisResult result;
  final double? finalScore;

  const PumpAnalysisCard({
    super.key,
    required this.result,
    this.finalScore,
  });

  bool get _isLowConfidence => finalScore != null && finalScore! < 40;
  bool get _isMediumConfidence =>
      finalScore != null && finalScore! >= 40 && finalScore! < 70;

  Color _getPumpColor() {
    if (_isLowConfidence) {
      return Colors.orangeAccent;
    }

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
    if (_isLowConfidence) {
      switch (result.pumpType) {
        case "FAKE":
          return "Şişme ihtimali";
        case "REAL":
          return "Güçlü yükseliş";
        default:
          return "Belirsiz";
      }
    }

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
    if (_isLowConfidence) {
      return "Henüz uygun değil";
    }

    if (_isMediumConfidence) {
      if (!result.shortReady) return "Bekle";
      if (result.entryScore > 70) return "İzlenmeli";
      if (result.entryScore > 50) return "Hazırlanıyor";
      return "Zayıf";
    }

    if (!result.shortReady) return "Bekle";

    if (result.entryScore > 70) return "Giriş uygun";
    if (result.entryScore > 50) return "Hazırlanıyor";

    return "Zayıf";
  }

  Color _getEntryColor() {
    if (_isLowConfidence) return Colors.grey;

    if (_isMediumConfidence) {
      if (!result.shortReady) return Colors.grey;
      if (result.entryScore > 70) return Colors.orangeAccent;
      if (result.entryScore > 50) return Colors.orangeAccent;
      return Colors.redAccent;
    }

    if (!result.shortReady) return Colors.grey;

    if (result.entryScore > 70) return Colors.greenAccent;
    if (result.entryScore > 50) return Colors.orangeAccent;

    return Colors.redAccent;
  }

  String _getSectionTitle() {
    if (_isLowConfidence) return "PUMP GÖZLEMİ";
    if (_isMediumConfidence) return "PUMP ERKEN SİNYALİ";
    return "PUMP ANALİZİ";
  }

  String _getIntroText() {
    if (_isLowConfidence) {
      return "Pump yapısı izleniyor, ancak merkezi karar short girişi için henüz uygun değil.";
    }
    if (_isMediumConfidence) {
      return "Pump sonrası zayıflama ihtimali var, ancak giriş teyidi henüz tamamlanmış değil.";
    }
    return "";
  }

  List<String> _getFilteredReasons() {
    final List<String> allReasons = result.reasons;

    bool isPumpReason(String text) {
      final String lower = text.toLowerCase();

      final List<String> keepKeywords = [
        'pump',
        'şişme',
        'gövde küçül',
        'kapanış zayıf',
        'yeni high denen',
        'new high',
      ];

      final List<String> removeKeywords = [
        'üst fitil',
        'satış baskısı',
        'momentum',
        'kırmızı mum',
        'önceki mumun altında',
        'taşınamamış',
        'lower-high',
        'lower high',
      ];

      final bool hasKeep = keepKeywords.any(lower.contains);
      final bool hasRemove = removeKeywords.any(lower.contains);

      return hasKeep && !hasRemove;
    }

    final List<String> filtered =
        allReasons.where(isPumpReason).take(3).toList();

    if (filtered.isNotEmpty) {
      return filtered;
    }

    return allReasons.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reasons = _getFilteredReasons();
    final String intro = _getIntroText();

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
          Text(
            _getSectionTitle(),
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (intro.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              intro,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
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
          if (reasons.isNotEmpty) ...[
            Text(
              _isLowConfidence ? "Gözlem Notları" : "Neden?",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...reasons.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• $e",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
