import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';

enum EntryState {
  watch,
  readyShort,
  enterShort,
  invalid,
}

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

  EntryState _detectEntryState({
    required List<CandleData> candles,
    required String orderFlowDirection,
    required String oiPriceSignal,
    required bool dangerousLongSide,
  }) {
    final bool bigRedStart = _bigRedStart(candles);
    final bool topWeakening = _topWeakening(candles);
    final bool sellPressure = orderFlowDirection == 'SELL_PRESSURE';

    if (dangerousLongSide) {
      return EntryState.invalid;
    }

    if (bigRedStart && sellPressure) {
      return EntryState.enterShort;
    }

    if (bigRedStart || topWeakening) {
      return EntryState.readyShort;
    }

    return EntryState.watch;
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
      case 'ENTER_SHORT':
        return 'Giriş anı';
      case 'READY_SHORT':
        return 'Hazırlık var';
      case 'INVALID':
        return 'Geçersiz';
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
        oiPriceSignal == 'SHORT_SQUEEZE' ||
        oiPriceSignal == 'EARLY_ACCUMULATION';

    final EntryState entryState = _detectEntryState(
      candles: visibleCandles,
      orderFlowDirection: orderFlowDirection,
      oiPriceSignal: oiPriceSignal,
      dangerousLongSide: dangerousLongSide,
    );

    final String action;
    final String summary;
    final List<String> marketReadBullets = <String>[];
    final List<String> entryNotes = <String>[];
    final List<String> warnings = <String>[];
    final List<String> triggerConditions = <String>[];

    switch (entryState) {
      case EntryState.enterShort:
        action = 'ENTER_SHORT';
        summary = 'Giriş tetiklendi. Satış momentumu aktif.';
        break;

      case EntryState.readyShort:
        action = 'READY_SHORT';
        summary = 'Setup hazır. Kırılım ve satış teyidi bekleniyor.';
        break;

      case EntryState.invalid:
        action = 'INVALID';
        summary = 'Ters sinyal var. Short setup geçersiz veya zayıf.';
        break;

      case EntryState.watch:
        action = 'WATCH';
        summary = 'Şu an sadece izleme modunda. Net giriş izni yok.';
        break;
    }

    if (oiDirection == 'UP') {
      marketReadBullets.add('Open interest artıyor, piyasaya yeni pozisyon girişi var.');
    } else if (oiDirection == 'DOWN') {
      marketReadBullets.add('Open interest düşüyor, pozisyon çözülmesi görülüyor.');
    } else {
      marketReadBullets.add('Open interest yatay, güçlü yön teyidi sınırlı.');
    }

    if (priceDirection == 'DOWN') {
      marketReadBullets.add('Fiyat aşağı yönlü baskı gösteriyor.');
    } else if (priceDirection == 'UP') {
      marketReadBullets.add('Fiyat yukarı gidiyor; tepe zayıflaması varsa short hazırlığı takip edilir.');
    } else {
      marketReadBullets.add('Fiyat yatay seyirde, net kırılım henüz gelmemiş olabilir.');
    }

    if (orderFlowDirection == 'SELL_PRESSURE') {
      marketReadBullets.add('Emir akışı satış baskısını destekliyor.');
    } else if (orderFlowDirection == 'BUY_PRESSURE') {
      marketReadBullets.add('Emir akışı alıcı tarafında; short için dikkat gerekir.');
    } else {
      marketReadBullets.add('Order flow tarafında belirgin üstünlük yok.');
    }

    if (_hasLowerHigh(visibleCandles)) {
      marketReadBullets.add('Daha düşük tepe oluştu, tepe gücü zayıflıyor.');
    }

    if (_hasUpperRejection(visibleCandles)) {
      marketReadBullets.add('Üst fitil / tepeden ret var, alıcılar yukarı taşıyamıyor.');
    }

    if (dangerousLongSide) {
      final String riskText =
          oiPriceSignal == 'SHORT_SQUEEZE' ? 'short sıkıştırma riski' : 'erken toplama sinyali';
      marketReadBullets.add('$riskText var; short tarafı için negatif filtre oluşuyor.');
      warnings.add('$riskText short girişini zayıflatıyor.');
    }

    if (entryState == EntryState.enterShort) {
      entryNotes.add('ENTER_SHORT tetiklendi: satış momentumu aktif.');
      entryNotes.add('Bu bilgi giriş izni değil; anlık piyasa durumudur. Karar kullanıcıya aittir.');
    } else if (entryState == EntryState.readyShort) {
      entryNotes.add('READY_SHORT: setup hazır ama tam giriş teyidi bekleniyor.');
      entryNotes.add('Kırılım sonrası continuation mumu takip edilmeli.');
    } else if (entryState == EntryState.invalid) {
      entryNotes.add('INVALID: short setup ters sinyal nedeniyle zayıfladı.');
      entryNotes.add('Yeni setup oluşmadan giriş kovalanmamalı.');
    } else {
      entryNotes.add('WATCH: net short hazırlığı veya giriş anı yok.');
    }

    if (orderFlowDirection == 'BUY_PRESSURE' && action != 'WATCH') {
      warnings.add('Emir akışı alıcı tarafında; acele etmeden izlenmeli.');
    }

    if (entryState == EntryState.enterShort) {
      triggerConditions.add('Satış momentumu başladı');
      triggerConditions.add('Kırmızı mum gövdesi anlamlı hale geldi');
      triggerConditions.add('Order flow satış tarafını destekliyor');
    } else if (entryState == EntryState.readyShort) {
      triggerConditions.add('Kırılma sonrası continuation mumu');
      triggerConditions.add('Zayıf kapanış veya breakdown teyidi');
      triggerConditions.add('Satış baskısının devam etmesi');
      triggerConditions.add('Tepe bölgesinden gelen lower high yapısının sürmesi');
    } else if (entryState == EntryState.invalid) {
      triggerConditions.add('Ters sinyalin kaybolması');
      triggerConditions.add('Erken toplama / squeeze riskinin bitmesi');
      triggerConditions.add('Yeni satış baskısı oluşması');
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
      tradeBias: action == 'ENTER_SHORT' || action == 'READY_SHORT'
          ? 'Short yönlü'
          : action == 'INVALID'
              ? 'Geçersiz'
              : 'Nötr',
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
