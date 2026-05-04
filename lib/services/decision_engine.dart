import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/final_trade_decision.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';

enum KararDurumu {
  bekle,
  shortHazir,
  shortGiris,
  gecersiz,
}

class DecisionEngine {
  const DecisionEngine();

  double _clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  bool _isRed(CandleData candle) => candle.close < candle.open;

  bool _isGreen(CandleData candle) => candle.close > candle.open;

  double _bodyRatio(CandleData candle) {
    final double range = (candle.high - candle.low).abs();
    if (range == 0) return 0;
    return (candle.close - candle.open).abs() / range;
  }

  double _upperWickRatio(CandleData candle) {
    final double range = (candle.high - candle.low).abs();
    if (range == 0) return 0;
    return candle.upperWick / range;
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
    return _upperWickRatio(last) >= 0.30;
  }

  double _highestHighBeforeLast(List<CandleData> candles, {int lookback = 10}) {
    if (candles.length < 2) return 0;

    final int end = candles.length - 1;
    final int start = (end - lookback).clamp(0, end);

    double highest = candles[start].high;

    for (int i = start; i < end; i++) {
      if (candles[i].high > highest) {
        highest = candles[i].high;
      }
    }

    return highest;
  }

  bool _hasStrongRecentPump(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final int end = candles.length - 1;
    final int start = (end - 8).clamp(0, end);

    final double firstClose = candles[start].close;
    double highestHigh = candles[start].high;
    int greenCount = 0;

    for (int i = start; i <= end; i++) {
      if (candles[i].high > highestHigh) {
        highestHigh = candles[i].high;
      }

      if (_isGreen(candles[i])) {
        greenCount++;
      }
    }

    if (firstClose <= 0) return false;

    final double pumpPercent = ((highestHigh - firstClose) / firstClose) * 100;

    return pumpPercent >= 18 || greenCount >= 4;
  }

  bool _bigRedStart(List<CandleData> candles) {
    if (candles.length < 2) return false;

    final CandleData last = candles.last;
    if (!_isRed(last)) return false;

    final bool meaningfulBody = _bodyRatio(last) >= 0.22;
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

  bool _topReversalShortStart({
    required List<CandleData> candles,
    required String orderFlowDirection,
  }) {
    if (candles.length < 3) return false;

    final CandleData last = candles.last;
    final CandleData prev = candles[candles.length - 2];

    final bool strongPump = _hasStrongRecentPump(candles);
    if (!strongPump) return false;

    if (orderFlowDirection == 'BUY_PRESSURE') {
      return false;
    }

    final double recentTop = _highestHighBeforeLast(candles);
    if (recentTop <= 0) return false;

    final bool nearTop =
        last.high >= recentTop * 0.90 || prev.high >= recentTop * 0.95;

    final bool failedToTakeTop = last.high < recentTop && last.close < recentTop;
    final bool redCandle = _isRed(last);
    final bool meaningfulBody = _bodyRatio(last) >= 0.18;
    final bool upperRejection = _upperWickRatio(last) >= 0.22;
    final bool lowerClose = last.close < prev.close;
    final bool lowerHigh = last.high < prev.high;

    return nearTop &&
        failedToTakeTop &&
        redCandle &&
        meaningfulBody &&
        (upperRejection || lowerClose || lowerHigh);
  }

  bool _lowerHighBreakStart({
    required List<CandleData> candles,
    required String orderFlowDirection,
    required String priceDirection,
  }) {
    if (candles.length < 3) return false;

    final bool strongPump = _hasStrongRecentPump(candles);
    if (!strongPump) return false;

    if (orderFlowDirection == 'BUY_PRESSURE') {
      return false;
    }

    final bool lowerHigh = _hasLowerHigh(candles);
    final bool lowerClose = _hasLowerClose(candles);
    final bool sellFlow = orderFlowDirection == 'SELL_PRESSURE';
    final bool priceDown = priceDirection == 'DOWN';

    return lowerHigh && lowerClose && (sellFlow || priceDown);
  }

  KararDurumu _detectEntryState({
    required List<CandleData> candles,
    required String orderFlowDirection,
    required String oiPriceSignal,
    required String priceDirection,
  }) {
    final bool shortSqueezeRisk = oiPriceSignal == 'SHORT_SQUEEZE';
    final bool earlyAccumulationRisk =
        oiPriceSignal == 'EARLY_ACCUMULATION' &&
            orderFlowDirection != 'SELL_PRESSURE';

    if (shortSqueezeRisk || earlyAccumulationRisk) {
      return KararDurumu.gecersiz;
    }

    final bool topReversal = _topReversalShortStart(
      candles: candles,
      orderFlowDirection: orderFlowDirection,
    );

    final bool lowerHighBreak = _lowerHighBreakStart(
      candles: candles,
      orderFlowDirection: orderFlowDirection,
      priceDirection: priceDirection,
    );

    final bool bigRedStart = _bigRedStart(candles);
    final bool topWeakening = _topWeakening(candles);

    if (topReversal || lowerHighBreak) {
      return KararDurumu.shortGiris;
    }

    if (bigRedStart && orderFlowDirection == 'SELL_PRESSURE') {
      return KararDurumu.shortGiris;
    }

    if (bigRedStart || topWeakening) {
      return KararDurumu.shortHazir;
    }

    return KararDurumu.bekle;
  }

  double _scoreFromState({
    required bool bigRedStart,
    required bool topWeakening,
    required bool topReversal,
    required bool lowerHighBreak,
    required String orderFlowDirection,
    required String oiPriceSignal,
    required String priceDirection,
    required String oiDirection,
  }) {
    double score = 25;

    if (topWeakening) score += 28;
    if (bigRedStart) score += 30;
    if (topReversal) score += 35;
    if (lowerHighBreak) score += 32;

    if (orderFlowDirection == 'SELL_PRESSURE') score += 14;
    if (priceDirection == 'DOWN') score += 10;
    if (oiDirection == 'UP') score += 5;

    if (oiPriceSignal == 'FAKE_PUMP' ||
        oiPriceSignal == 'EARLY_DISTRIBUTION' ||
        oiPriceSignal == 'STRONG_SHORT' ||
        oiPriceSignal == 'WEAK_DROP') {
      score += 8;
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      score -= 30;
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION' &&
        orderFlowDirection != 'SELL_PRESSURE') {
      score -= 22;
    }

    return _clampScore(score);
  }

  String _scoreClassFromAction(String action) {
    switch (action) {
      case 'SHORT GİRİŞ':
        return 'Giriş anı';
      case 'SHORT HAZIR':
        return 'Hazırlık var';
      case 'GEÇERSİZ':
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

    final bool topReversal = _topReversalShortStart(
      candles: visibleCandles,
      orderFlowDirection: orderFlowDirection,
    );

    final bool lowerHighBreak = _lowerHighBreakStart(
      candles: visibleCandles,
      orderFlowDirection: orderFlowDirection,
      priceDirection: priceDirection,
    );

    final KararDurumu kararDurumu = _detectEntryState(
      candles: visibleCandles,
      orderFlowDirection: orderFlowDirection,
      oiPriceSignal: oiPriceSignal,
      priceDirection: priceDirection,
    );

    final String action;
    final String summary;
    final List<String> marketReadBullets = <String>[];
    final List<String> entryNotes = <String>[];
    final List<String> warnings = <String>[];
    final List<String> triggerConditions = <String>[];

    switch (kararDurumu) {
      case KararDurumu.shortGiris:
        action = 'SHORT GİRİŞ';
        summary = 'Tepe dönüşü veya satış başlangıcı yakalandı. Short giriş bölgesi aktif.';
        break;

      case KararDurumu.shortHazir:
        action = 'SHORT HAZIR';
        summary = 'Tepe zayıflıyor. Giriş için satış teyidi izleniyor.';
        break;

      case KararDurumu.gecersiz:
        action = 'GEÇERSİZ';
        summary = 'Ters sinyal var. Short kurulumu şu an zayıf.';
        break;

      case KararDurumu.bekle:
        action = 'BEKLE';
        summary = 'Şu an net short giriş anı yok. İzleme modu.';
        break;
    }

    if (oiDirection == 'UP') {
      marketReadBullets.add('Açık pozisyon artıyor, piyasaya yeni pozisyon girişi var.');
    } else if (oiDirection == 'DOWN') {
      marketReadBullets.add('Açık pozisyon düşüyor, pozisyon çözülmesi görülüyor.');
    } else {
      marketReadBullets.add('Açık pozisyon yatay, güçlü yön teyidi sınırlı.');
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
      marketReadBullets.add('Emir akışı tarafında belirgin üstünlük yok.');
    }

    if (_hasStrongRecentPump(visibleCandles)) {
      marketReadBullets.add('Öncesinde güçlü yükseliş var; tepe dönüşü ihtimali izleniyor.');
    }

    if (_hasLowerHigh(visibleCandles)) {
      marketReadBullets.add('Daha düşük tepe oluştu, tepe gücü zayıflıyor.');
    }

    if (_hasUpperRejection(visibleCandles)) {
      marketReadBullets.add('Üst fitil / tepeden ret var, alıcılar yukarı taşıyamıyor.');
    }

    if (topReversal) {
      marketReadBullets.add('Tepe bölgesinde ilk satış dönüşü yakalandı.');
    }

    if (lowerHighBreak) {
      marketReadBullets.add('Daha düşük tepe sonrası zayıf kapanış geldi.');
    }

    if (oiPriceSignal == 'SHORT_SQUEEZE') {
      marketReadBullets.add('Short sıkıştırma riski var; short tarafı için negatif filtre oluşuyor.');
      warnings.add('Short sıkıştırma riski short girişini zayıflatıyor.');
    }

    if (oiPriceSignal == 'EARLY_ACCUMULATION' &&
        orderFlowDirection != 'SELL_PRESSURE') {
      marketReadBullets.add('Erken toplama sinyali var; satış baskısı netleşmeden short zayıf kalır.');
      warnings.add('Erken toplama sinyali short girişini zayıflatıyor.');
    }

    if (kararDurumu == KararDurumu.shortGiris) {
      entryNotes.add('SHORT GİRİŞ: tepe dönüşü veya satış başlangıcı aktif.');
      entryNotes.add('Bu bilgi emir açtırmaz; anlık piyasa durumunu gösterir. Karar kullanıcıya aittir.');
    } else if (kararDurumu == KararDurumu.shortHazir) {
      entryNotes.add('SHORT HAZIR: yapı oluşuyor ama tam giriş teyidi bekleniyor.');
      entryNotes.add('Daha düşük tepe, zayıf kapanış ve satış baskısı takip edilmeli.');
    } else if (kararDurumu == KararDurumu.gecersiz) {
      entryNotes.add('GEÇERSİZ: short kurulumu ters sinyal nedeniyle zayıfladı.');
      entryNotes.add('Yeni satış baskısı oluşmadan giriş kovalanmamalı.');
    } else {
      entryNotes.add('BEKLE: net short hazırlığı veya giriş anı yok.');
    }

    if (orderFlowDirection == 'BUY_PRESSURE' && action != 'BEKLE') {
      warnings.add('Emir akışı alıcı tarafında; acele etmeden izlenmeli.');
    }

    if (kararDurumu == KararDurumu.shortGiris) {
      triggerConditions.add('Tepe dönüşü veya satış başlangıcı yakalandı');
      triggerConditions.add('Daha düşük tepe / zayıf kapanış takip edildi');
      triggerConditions.add('Alıcı baskısı zayıfladı');
    } else if (kararDurumu == KararDurumu.shortHazir) {
      triggerConditions.add('Daha düşük tepe yapısının sürmesi');
      triggerConditions.add('Zayıf kapanış veya satış teyidi');
      triggerConditions.add('Emir akışının satış tarafına dönmesi');
      triggerConditions.add('Tepeden ret yapısının devam etmesi');
    } else if (kararDurumu == KararDurumu.gecersiz) {
      triggerConditions.add('Ters sinyalin kaybolması');
      triggerConditions.add('Erken toplama / sıkıştırma riskinin bitmesi');
      triggerConditions.add('Yeni satış baskısı oluşması');
    } else {
      triggerConditions.add('Tepe zayıflaması');
      triggerConditions.add('Daha düşük tepe oluşması');
      triggerConditions.add('Satış baskısının belirginleşmesi');
    }

    final double finalScore = _scoreFromState(
      bigRedStart: bigRedStart,
      topWeakening: topWeakening,
      topReversal: topReversal,
      lowerHighBreak: lowerHighBreak,
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
      tradeBias: action == 'SHORT GİRİŞ' || action == 'SHORT HAZIR'
          ? 'SHORT'
          : action == 'GEÇERSİZ'
              ? 'GEÇERSİZ'
              : 'NÖTR',
      action: action,
      summary: summary,
      oiScore: oiDirection == 'UP' ? 65 : (oiDirection == 'DOWN' ? 35 : 50),
      priceScore: priceDirection == 'DOWN' ? 75 : (priceDirection == 'UP' ? 45 : 50),
      orderFlowScore: orderFlowDirection == 'SELL_PRESSURE'
          ? 80
          : (orderFlowDirection == 'BUY_PRESSURE' ? 30 : 50),
      volumeScore: 50,
      liquidationScore: 50,
      momentumScore: topReversal || lowerHighBreak
          ? 95
          : bigRedStart
              ? 90
              : topWeakening
                  ? 70
                  : 35,
      marketReadBullets: marketReadBullets,
      entryNotes: entryNotes,
      warnings: warnings,
      triggerConditions: triggerConditions,
    );
  }
}
