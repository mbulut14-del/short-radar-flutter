
import '../models/final_trade_decision.dart';

class DecisionEngineService {
  // 🔥 Coin bazlı buffer
  static final Map<String, List<FinalTradeDecision>> _buffers = {};

  // 🔥 Coin bazlı son karar zamanı
  static final Map<String, DateTime?> _lastDecisionTimes = {};

  static FinalTradeDecision processDecision({
    required String coin,
    required FinalTradeDecision newDecision,
  }) {
    final now = DateTime.now();

    _buffers.putIfAbsent(coin, () => []);
    _lastDecisionTimes.putIfAbsent(coin, () => null);

    final buffer = _buffers[coin]!;
    final lastTime = _lastDecisionTimes[coin];

    // İlk veri → direkt göster
    if (lastTime == null) {
      buffer.clear();
      buffer.add(newDecision);
      _lastDecisionTimes[coin] = now;
      return newDecision;
    }

    final diff = now.difference(lastTime).inMinutes;

    // 3 dk dolmadıysa → buffer'a ekle, eskiyi göster
    if (diff < 3) {
      buffer.add(newDecision);
      return buffer.last;
    }

    // 3 dk doldu → filtrelenmiş karar üret
    final filtered = _buildFilteredDecision(buffer);

    buffer.clear();
    buffer.add(filtered);
    _lastDecisionTimes[coin] = now;

    return filtered;
  }

  static FinalTradeDecision _buildFilteredDecision(
      List<FinalTradeDecision> buffer) {
    if (buffer.isEmpty) return buffer.last;

    double avgScore =
        buffer.map((e) => e.finalScore).reduce((a, b) => a + b) /
            buffer.length;

    double avgConfidence =
        buffer.map((e) => e.confidence).reduce((a, b) => a + b) /
            buffer.length;

    final last = buffer.last;

    return FinalTradeDecision(
      finalScore: avgScore,
      confidence: avgConfidence,
      signal: last.signal,
      bias: last.bias,
      action: last.action,
      oiScore: last.oiScore,
      priceScore: last.priceScore,
      orderFlowScore: last.orderFlowScore,
      volumeScore: last.volumeScore,
      liquidationScore: last.liquidationScore,
      momentumScore: last.momentumScore,
      marketRead: last.marketRead,
      entryNotes: last.entryNotes,
      warnings: last.warnings,
      triggerConditions: last.triggerConditions,
    );
  }
}
