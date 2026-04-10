
import 'candle_data.dart';
import 'entry_timing_result.dart';

class EntryTiming {
  static EntryTimingResult analyze(List<CandleData> candles) {
    if (candles.length < 4) {
      return const EntryTimingResult(
        score: 0,
        ready: false,
        signal: 'Bekle',
        reasons: ['Entry timing için veri yetersiz.'],
      );
    }

    final recent =
        candles.length > 6 ? candles.sublist(candles.length - 6) : candles;

    final last = recent[recent.length - 1];
    final prev = recent[recent.length - 2];
    final prev2 = recent[recent.length - 3];

    int score = 0;
    final reasons = <String>[];

    final bool upperWickHeavy =
        last.upperWick > last.bodySize * 1.2 && last.upperWick > 0;
    final bool redCandle = !last.isBullish;
    final bool weakClose =
        last.range > 0 && ((last.high - last.close) / last.range) > 0.45;
    final bool lowerHigh = prev.high < prev2.high;
    final bool closeBelowPrev = last.close < prev.close;
    final bool failedBreakout = last.high > prev.high && last.close < prev.high;

    if (upperWickHeavy) {
      score += 20;
      reasons.add('Son mumda belirgin üst fitil var.');
    }

    if (redCandle) {
      score += 15;
      reasons.add('Son mum kırmızı kapanmış.');
    }

    if (weakClose) {
      score += 15;
      reasons.add('Kapanış tepeye yakın değil.');
    }

    if (lowerHigh) {
      score += 20;
      reasons.add('Kısa vadede lower-high oluşmuş.');
    }

    if (closeBelowPrev) {
      score += 15;
      reasons.add('Son kapanış önceki mumun altında.');
    }

    if (failedBreakout) {
      score += 15;
      reasons.add('Yeni high denenmiş ama taşınamamış.');
    }

    if
