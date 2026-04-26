import '../models/candle_data.dart';
import '../models/final_trade_decision.dart';

class DecisionEngine {
  const DecisionEngine();

  // 🔴 Büyük kırmızı mum başlangıcı
  bool _bigRedStart(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final isRed = last.close < last.open;
    if (!isRed) return false;

    final body = (last.open - last.close).abs();
    final range = (last.high - last.low).abs();
    final bodyRatio = range == 0 ? 0 : body / range;

    final strongBody = bodyRatio > 0.3;
    final lowerClose = last.close < prev.close;
    final lowerHigh = last.high < prev.high;

    return strongBody && (lowerClose || lowerHigh);
  }

  // 📉 Tepe zayıflama
  bool _topWeakening(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final lowerHigh = last.high < prev.high;
    final momentumLoss = last.close <= prev.close;

    return lowerHigh || momentumLoss;
  }

  FinalTradeDecision build({
    required List<CandleData> visibleCandles,
  }) {
    String action;
    String summary;

    if (_bigRedStart(visibleCandles)) {
      action = 'Short giriş';
      summary = 'Büyük kırmızı mum başladı. Satış momentumu geldi.';
    } else if (_topWeakening(visibleCandles)) {
      action = 'Short hazırlığı';
      summary = 'Tepe zayıflıyor. Short için hazırlık.';
    } else {
      action = 'Bekle';
      summary = 'Net bir fırsat yok.';
    }

    return FinalTradeDecision(
      finalScore: 0,
      scoreClass: '',
      confidence: 0,
      primarySignal: '',
      tradeBias: '',
      action: action,
      summary: summary,
      oiScore: 0,
      priceScore: 0,
      orderFlowScore: 0,
      volumeScore: 0,
      liquidationScore: 0,
      momentumScore: 0,
      marketReadBullets: [],
      entryNotes: [],
      warnings: [],
      triggerConditions: [],
    );
  }
}
