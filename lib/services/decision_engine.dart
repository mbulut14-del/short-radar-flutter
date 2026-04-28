import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';

class DecisionEngine {
  const DecisionEngine();

  double _clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  bool _isRed(CandleData candle) => candle.close < candle.open;

  double _bodyRatio(CandleData candle) {
    final double range = (candle.high - candle.low).abs();
    if (range == 0) return 0;
    return (candle.close - candle.open).abs() / range;
  }

  bool _hasLowerHigh(List<CandleData> candles) {
    if (candles.length < 2) return false;
    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];
    return last.high < prev.high;
  }

  bool _hasLowerClose(List<CandleData> candles) {
    if (candles.length < 2) return false;
    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];
    return last.close < prev.close;
  }

  bool _hasMomentumLoss(List<CandleData> candles) {
    if (candles.length < 2) return false;
    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];
    return last.close <= prev.close || last.high <= prev.high;
  }

  bool _hasUpperRejection(List<CandleData> candles) {
    if (candles.isEmpty) return false;
    final CandleData last = candles.last;
    final double range = (last.high - last.low).abs();
    if (range == 0) return false;
    return (last.upperWick / range) >= 0.30;
  }

  bool _bigRedStart(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles.last;
    if (!_isRed(last)) return false;

    final bool meaningfulBody = _bodyRatio(last) >= 0.28;
    final bool lowerClose = _hasLowerClose(candles);
    final bool lowerHigh = _hasLowerHigh(candles);
    final bool upperRejection = _hasUpperRejection(candles);

    return meaningfulBody && (lowerClose || lowerHigh || upperRejection);
  }

  bool _topWeakening(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];

    final bool lowerHigh = _hasLowerHigh(candles);
    final bool momentumLoss = _hasMomentumLoss(candles);
    final bool redAfterGreen = _isRed(last) && prev.close > prev.open;
    final bool upperRejection = _hasUpperRejection(candles);

    return lowerHigh || momentumLoss || redAfterGreen || upperRejection;
  }

  double _scoreFromState({
    required bool bigRedStart,
    required bool topWeakening,
    required String orderFlowDirection,
    required String oiPriceSignal,
    required String priceDirection,
    required String oiDirection,
  }) {
    double score = 25;

    if (topWeakening) score += 35;
    if (bigRedStart) score += 35;
    if (orderFlowDirection == 'SELL_PRESSURE') score += 12;
    if (priceDirection == 'DOWN') score += 8;
    if (oiDirection == 'UP') score += 5;

    if (oiPriceSignal == 'FAKE_PUMP' ||
        oiPriceSignal == 'EARLY_DISTRIBUTION' ||
        oiPriceSignal == 'STRONG_SHORT' ||
        oiPriceSignal == 'WEAK_DROP') {
      score += 8;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION') {
      score -= 18;
    }

    return _clampScore(score);
  }

  String _scoreClassFromAction(String action) {
    switch (action) {
      case 'Short giriş':
        return 'Giriş anı';
      case 'Short hazırlığı':
        return 'Hazırlık var';
      default:
        return 'Bekle';
    }
  }

  FinalTradeDecision build({
    required String oiPriceSignal,
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required PumpAnalysisResult? pumpAnalysis,
    required EntryTimingResult? entryTiming,
    required ShortSetupResult? setupResult,
    required List<CandleData> visibleCandles,
  }) {
    final bool bigRedStart = _bigRedStart(visibleCandles);
    final bool topWeakening = _topWeakening(visibleCandles);

    final bool dangerousLongSide =
        oiPriceSignal == 'SHORT_SQUEEZE' || oiPriceSignal == 'EARLY_ACCUMULATION';

    final String action;
    final String summary;
    final List<String> marketReadBullets = <String>[];
    final List<String> entryNotes = <String>[];
    final List<String> warnings = <String>[];
    final List<String> triggerConditions = <String>[];

    if (bigRedStart && !dangerousLongSide) {
      action = 'Short giriş';
      summary = 'Büyük kırmızı mum başlangıcı yakalandı. Satış momentumu devreye giriyor.';
    } else if (topWeakening && !dangerousLongSide) {
      action = 'Short hazırlığı';
      summary = 'Tepe zayıflıyor. Büyük kırmızı mum başlangıcı için takip et.';
    } else {
      action = 'Bekle';
      summary = 'Şu an net short anı yok. Sistem sadece izleme modunda.';
    }

    if (oiDirection == 'UP') {
      marketReadBullets.add('Open interest artıyor, piyasaya yeni pozisyon girişi var.');
    } else if (oiDirection == 'DOWN') {
      marketReadBullets.add('Open interest düşüyor, pozisyon çözülmesi görülüyor.');
    } else {
      marketReadBullets.add('Open interest yatay, bu tarafta güçlü teyit yok.');
    }

    if (priceDirection == 'DOWN') {
      marketReadBullets.add('Fiyat aşağı yönlü baskı gösteriyor.');
    } else if (priceDirection == 'UP') {
      marketReadBullets.add('Fiyat yukarı gidiyor; tepe zayıflaması varsa short hazırlığı takip edilir.');
    } else {
      marketReadBullets.add('Fiyat yatay, net kırılım henüz yok.');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      marketReadBullets.add('Emir akışı satış baskısını destekliyor.');
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      marketReadBullets.add('Emir akışı alıcı tarafında; short için dikkat gerekir.');
    } else {
      marketReadBullets.add('Emir akışında belirgin üstünlük yok.');
    }

    if (_hasLowerHigh(visibleCandles)) {
      marketReadBullets.add('Daha düşük tepe oluştu, tepe gücü zayıflıyor.');
    }

    if (_hasUpperRejection(visibleCandles)) {
      marketReadBullets.add('Üst fitil / tepeden ret var, alıcılar yukarı taşıyamıyor.');
    }

    if (bigRedStart) {
      entryNotes.add('Büyük kırmızı mum başlangıcı görüldü.');
      entryNotes.add('Bu bilgi giriş izni değil; anlık piyasa durumudur. Karar kullanıcıya aittir.');
    } else if (topWeakening) {
      entryNotes.add('Short hazırlığı var. Büyük kırmızı mum başlangıcı takip edilmeli.');
    } else {
      entryNotes.add('Net short hazırlığı veya giriş anı yok.');
    }

    if (dangerousLongSide) {
      final String riskText = oiPriceSignal == 'SHORT_SQUEEZE' ? 'short sıkıştırma riski' : 'erken toplama';
      warnings.add('Short tarafı için ters sinyal var: ' + riskText);
    }

    if (orderFlowDirection == 'BUY_PRESSURE' && action != 'Bekle') {
      warnings.add('Emir akışı alıcı tarafında; acele etmeden izlenmeli.');
    }

    if (action == 'Short hazırlığı') {
      triggerConditions.add('Büyük kırmızı mum başlangıcı');
      triggerConditions.add('Daha düşük tepe yapısının bozulmaması');
      triggerConditions.add('Satış baskısının devam etmesi');
    } else if (action == 'Short giriş') {
      triggerConditions.add('Satış momentumu başladı');
      triggerConditions.add('Kırmızı mum gövdesi anlamlı hale geldi');
      triggerConditions.add('Karar kullanıcıya aittir');
    } else {
      triggerConditions.add('Tepe zayıflaması');
      triggerConditions.add('Satış baskısının belirginleşmesi');
      triggerConditions.add('Büyük kırmızı mum başlangıcı');
    }

    final double finalScore = _scoreFromState(
      bigRedStart: bigRedStart,
      topWeakening: topWeakening,
      orderFlowDirection: orderFlowDirection,
      oiPriceSignal: oiPriceSignal,
      priceDirection: priceDirection,
      oiDirection: oiDirection,
    );

    return FinalTradeDecision(
      finalScore: finalScore,
      scoreClass: _scoreClassFromAction(action),
      confidence: finalScore,
      primarySignal: action,
      tradeBias: action == 'Bekle' ? 'Nötr' : 'Short yönlü',
      action: action,
      summary: summary,
      oiScore: oiDirection == 'UP' ? 65 : (oiDirection == 'DOWN' ? 35 : 50),
      priceScore: priceDirection == 'DOWN' ? 75 : (priceDirection == 'UP' ? 45 : 50),
      orderFlowScore: orderFlowDirection == 'SELL_PRESSURE'
          ? 80
          : (orderFlowDirection == 'BUY_PRESSURE' ? 30 : 50),
      volumeScore: 50,
      liquidationScore: 50,
      momentumScore: bigRedStart ? 90 : (topWeakening ? 70 : 35),
      marketReadBullets: marketReadBullets,
      entryNotes: entryNotes,
      warnings: warnings,
      triggerConditions: triggerConditions,
    );
  }
}
