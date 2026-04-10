
import 'dart:math' as math;

import 'candle_data.dart';
import 'coin_radar_data.dart';
import 'short_setup_result.dart';

class ShortSetupLogic {
  static ShortSetupResult build({
    required List<CandleData> candles,
    required CoinRadarData coin,
  }) {
    final List<CandleData> recent = candles.length > 10
        ? candles.sublist(candles.length - 10)
        : candles;

    final CandleData last = recent.last;
    final CandleData prev =
        recent.length >= 2 ? recent[recent.length - 2] : last;
    final CandleData prev2 =
        recent.length >= 3 ? recent[recent.length - 3] : prev;

    final List<CandleData> swingWindow = recent.length > 5
        ? recent.sublist(recent.length - 5)
        : recent;

    final double swingHigh = swingWindow.map((e) => e.high).reduce(math.max);

    final double firstOpen = recent.first.open == 0 ? 1 : recent.first.open;
    final double priceRisePercent =
        ((last.close - recent.first.open) / firstOpen) * 100;

    final bool nearResistance =
        swingHigh > 0 && ((swingHigh - last.close) / swingHigh) * 100 < 1.40;

    final bool weakening =
        last.close <= prev.close || last.bodySize <= prev.bodySize;

    final bool upperWickSignal =
        last.range > 0 && last.upperWick > last.bodySize * 0.75;

    final bool lowerHigh = recent.length >= 3 && prev.high < prev2.high;
    final bool closeBelowPrev = last.close < prev.close;
    final bool failedBreakout =
        last.high > prev.high && last.close < prev.high;

    final bool divergenceWide = coin.divergencePercent > 0.08;
    final bool fundingPositive = coin.fundingRate > 0;
    final bool fundingHot = coin.fundingRate > 0.0008;
    final bool pumpStrong =
        priceRisePercent > 1.4 || coin.changePercent > 4.0;

    final bool lastGreenAndStrong =
        last.isBullish && last.bodySize > prev.bodySize;

    int strength = 0;
    int coreSignals = 0;
    int confirmSignals = 0;
    final List<String> reasons = [];

    if (nearResistance) {
      strength += 18;
      coreSignals++;
      reasons.add('Fiyat yakın direnç bölgesinde.');
    }

    if (upperWickSignal) {
      strength += 18;
      coreSignals++;
      reasons.add('Son mumda üst fitil satış baskısı gösteriyor.');
    }

    if (lowerHigh) {
      strength += 16;
      coreSignals++;
      reasons.add('Son yapıda lower-high oluşumu var.');
    }

    if (weakening) {
      strength += 14;
      coreSignals++;
      reasons.add('Kısa vadeli ivme zayıflıyor.');
    }

    if (closeBelowPrev) {
      strength += 10;
      confirmSignals++;
      reasons.add('Son kapanış önceki mumun altında.');
    }

    if (failedBreakout) {
      strength += 14;
      confirmSignals++;
      reasons.add('Yeni high denenmiş ama taşınamamış.');
    }

    if (divergenceWide) {
      strength += 12;
      confirmSignals++;
      reasons.add('Mark-index farkı genişlemiş durumda.');
    }

    if (pumpStrong) {
      strength += 10;
      confirmSignals++;
      reasons.add('Son mumlarda yukarı yönlü şişme var.');
    }

    if (fundingPositive) {
      strength += fundingHot ? 12 : 8;
      confirmSignals++;
      reasons.add('Funding pozitif, long tarafı kalabalık.');
    } else {
      strength -= 14;
    }

    if (lastGreenAndStrong && !upperWickSignal && !failedBreakout) {
      strength -= 18;
    }

    final double structuralStop = swingHigh * 1.003;
    final double percentCapStop = last.close * 1.028;
    final double stop = math.min(
      math.max(structuralStop, last.close * 1.008),
      percentCapStop,
    );

    final double entry = last.close;
    final double risk =
        math.max(stop - entry, math.max(entry * 0.001, 0.0000001));

    if (strength < 0) strength = 0;
    if (strength > 100) strength = 100;

    final bool hardReject =
        risk <= 0 ||
        !fundingPositive ||
        (lastGreenAndStrong && coreSignals < 2) ||
        (pumpStrong && coreSignals == 0);

    final double rrMultiplier;
    if (strength >= 85) {
      rrMultiplier = 2.4;
    } else if (strength >= 75) {
      rrMultiplier = 2.2;
    } else if (strength >= 65) {
      rrMultiplier = 2.0;
    } else if (strength >= 55) {
      rrMultiplier = 1.8;
    } else if (strength >= 45) {
      rrMultiplier = 1.6;
    } else {
      rrMultiplier = 1.4;
    }

    final double target1 = math.max(entry - (risk * 1.10), 0);
    final double target2 = math.max(entry - (risk * rrMultiplier), 0);

    final double reward =
        math.max(entry - target2, math.max(entry * 0.001, 0.0000001));
    final double rr = reward / risk;

    String status;
    if (hardReject || rr < 1.0) {
      status = 'Zayıf';
    } else if (coreSignals >= 3 &&
        confirmSignals >= 2 &&
        rr >= 1.5 &&
        strength >= 68) {
      status = 'Güçlü';
    } else if (coreSignals >= 2 &&
        confirmSignals >= 1 &&
        rr >= 1.15 &&
        strength >= 42) {
      status = 'Orta';
    } else {
      status = 'Zayıf';
    }

    final String summary;
    if (status == 'Güçlü') {
      summary = 'Rejection + zayıflama birlikte çalışıyor. Short setup güçlü.';
    } else if (status == 'Orta') {
      summary = 'Kurulum var ama teyit henüz tam güçlenmemiş.';
    } else {
      summary = 'Short setup zayıf. Şartlar henüz net değil.';
    }

    return ShortSetupResult(
      entry: entry,
      stopLoss: stop,
      target1: target1,
      target2: target2,
      rr: rr,
      status: status,
      summary: summary,
      reasons: reasons.isNotEmpty
          ? reasons
          : ['Veri var ama güçlü teyit sayısı şu an düşük.'],
    );
  }
}
