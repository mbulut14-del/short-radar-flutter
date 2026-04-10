import 'dart:math';

import 'candle_data.dart';
import 'entry_timing_result.dart';

class EntryTiming {
  static EntryTimingResult analyze(List<CandleData> candles) {
    if (candles.length < 3) {
      return EntryTimingResult(
        timing: "WAIT",
        score: 0,
        reason: "Yetersiz veri",
      );
    }

    final last = candles[candles.length - 1];
    final prev = candles[candles.length - 2];

    int score = 0;

    /// 🔥 FAKE BREAKOUT FILTER
    bool fakeBreakoutRisk = false;

    final body = (last.close - last.open).abs();
    final upperWick = last.high - max(last.open, last.close);

    if (upperWick < body * 1.2) {
      fakeBreakoutRisk = true;
    }

    /// 🔹 Momentum zayıflama
    if (last.close <= prev.close) {
      score += 30;
    }

    /// 🔹 Üst fitil → satış baskısı
    if (upperWick > body * 1.5) {
      score += 30;
    }

    /// 🔹 Küçülen mum
    final prevBody = (prev.close - prev.open).abs();
    if (body < prevBody) {
      score += 20;
    }

    /// 🔹 Fake breakout kontrolü
    if (fakeBreakoutRisk) {
      score -= 30;
    }

    /// 🔥 ENTRY KARARI
    String timing;

    if (!fakeBreakoutRisk && score >= 80) {
      timing = "🔥 PERFECT SHORT";
    } else if (!fakeBreakoutRisk && score >= 60) {
      timing = "✅ READY";
    } else {
      timing = "⏳ WAIT";
    }

    return EntryTimingResult(
      timing: timing,
      score: score,
      reason: fakeBreakoutRisk
          ? "Fake breakout riski var"
          : "Momentum zayıflıyor",
    );
  }
}
