import 'dart:math';

import 'candle_data.dart';
import 'entry_timing_result.dart';

class EntryTiming {
  static EntryTimingResult analyze(List<CandleData> candles) {
    if (candles.length < 3) {
      return const EntryTimingResult(
        signal: 'Bekle',
        score: 0,
        ready: false,
        reasons: ['Yetersiz veri var.'],
      );
    }

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];

    int score = 0;
    final List<String> reasons = [];

    final double body = (last.close - last.open).abs();
    final double prevBody = (prev.close - prev.open).abs();
    final double upperWick = last.high - max(last.open, last.close);
    final double range = (last.high - last.low).abs();

    final bool hasUpperWick = upperWick > body * 0.8;
    final bool redClose = last.close < last.open;
    final bool closeNotNearTop =
        range > 0 ? ((last.high - last.close) / range) > 0.25 : false;
    final bool lowerHigh = last.high < prev.high || prev.high < prev2.high;
    final bool bodyShrinking = body > 0 && body < prevBody;
    final bool closeBelowPrev = last.close < prev.close;

    if (hasUpperWick) {
      score += 20;
      reasons.add('Son mumda belirgin üst fitil var.');
    }

    if (redClose) {
      score += 15;
      reasons.add('Son mum kırmızı kapanmış.');
    }

    if (closeNotNearTop) {
      score += 20;
      reasons.add('Kapanış tepeye yakın değil.');
    }

    if (lowerHigh) {
      score += 20;
      reasons.add('Kısa vadede lower-high oluşmuş.');
    }

    if (bodyShrinking) {
      score += 10;
      reasons.add('Mum gövdesi zayıflamaya başlamış.');
    }

    if (closeBelowPrev) {
      score += 15;
      reasons.add('Son kapanış önceki mumun altında.');
    }

    // =========================
    // 🔥 VOLUME ANALİZİ (YENİ)
    // =========================

    if (candles.length >= 6) {
      double avgVolume = 0;

      for (int i = candles.length - 6; i < candles.length - 1; i++) {
        avgVolume += candles[i].volume;
      }

      avgVolume /= 5;

      final double lastVolume = last.volume;

      if (lastVolume > avgVolume * 1.3) {
        score += 10;
        reasons.add('Hacim artıyor (hareket destekli).');
      } else if (lastVolume < avgVolume * 0.8) {
        reasons.add('Hacim düşüyor (zayıf hareket).');
      }
    }

    // =========================

    if (score > 100) score = 100;

    final bool ready = score >= 70;

    final String signal;
    if (score >= 70) {
      signal = 'Giriş uygun';
    } else if (score >= 45) {
      signal = 'Hazır';
    } else {
      signal = 'Bekle';
    }

    if (reasons.isEmpty) {
      reasons.add('Şimdilik giriş için net zayıflama oluşmamış.');
    }

    return EntryTimingResult(
      signal: signal,
      score: score,
      ready: ready,
      reasons: reasons,
    );
  }
}
