import 'candle_data.dart';
import 'entry_timing_result.dart';

class EntryTiming {
  static EntryTimingResult analyze(List<CandleData> candles) {
    if (candles.length < 3) {
      return EntryTimingResult(
        status: "Bekle",
        score: 0,
        signal: "Yetersiz veri",
      );
    }

    final last = candles[candles.length - 1];
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    int score = 0;
    String signal = "Zayıf";

    // 🔹 Üst fitil kontrolü
    final upperWick = last.high - (last.close > last.open ? last.close : last.open);
    final body = (last.close - last.open).abs();

    if (upperWick > body) {
      score += 20;
    }

    // 🔹 Kırmızı mum
    if (last.close < last.open) {
      score += 20;
    }

    // 🔹 Lower high
    if (last.high < prev.high) {
      score += 20;
    }

    // 🔹 Momentum kırılması
    if (prev.close < prev2.close) {
      score += 20;
    }

    // 🔹 Zayıf kapanış
    if (last.close < (last.high - (last.high - last.low) * 0.3)) {
      score += 20;
    }

    // 🔥 SONUÇ
    String status;

    if (score >= 70) {
      status = "Giriş uygun";
      signal = "Rejection başladı";
    } else if (score >= 40) {
      status = "Hazır";
      signal = "Zayıflama var";
    } else {
      status = "Bekle";
      signal = "Momentum güçlü";
    }

    return EntryTimingResult(
      status: status,
      score: score,
      signal: signal,
    );
  }
}
