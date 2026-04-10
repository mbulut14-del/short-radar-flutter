import 'candle_data.dart';
import 'pump_analysis_result.dart';

class PumpAnalysis {
  static PumpAnalysisResult analyze(List<CandleData> candles) {
    if (candles.length < 6) {
      return const PumpAnalysisResult(
        pumpType: 'Belirsiz',
        pumpScore: 0,
        entryScore: 0,
        shortReady: false,
        entrySignal: 'Bekle',
        reasons: ['Pump analizi için veri yetersiz.'],
      );
    }

    final recent =
        candles.length > 8 ? candles.sublist(candles.length - 8) : candles;

    final last = recent[recent.length - 1];
    final prev = recent[recent.length - 2];
    final prev2 = recent[recent.length - 3];

    int pumpScore = 0;
    int entryScore = 0;
    final reasons = <String>[];

    final bool strongRun = recent.where((c) => c.isBullish).length >= 5;
    final bool upperWickHeavy =
        last.upperWick > last.bodySize * 1.2 && last.upperWick > 0;
    final bool momentumLoss = last.close <= prev.close;
    final bool lowerHigh = prev.high < prev2.high;
    final bool smallBodyAfterRun = strongRun && last.bodySize < prev.bodySize;
    final bool lastRedAfterRun = strongRun && !last.isBullish;
    final bool weakClose =
        last.range > 0 && ((last.high - last.close) / last.range) > 0.45;
    final bool failedBreakout = last.high > prev.high && last.close < prev.high;

    if (strongRun) {
      pumpScore += 20;
      reasons.add('Son mumlarda güçlü pump yapısı var.');
    }

    if (upperWickHeavy) {
      pumpScore += 20;
      entryScore += 25;
      reasons.add('Son mumda üst fitil belirgin, satış baskısı artıyor.');
    }

    if (momentumLoss) {
      pumpScore += 15;
      entryScore += 20;
      reasons.add('Momentum zayıflamaya başlamış.');
    }

    if (lowerHigh) {
      pumpScore += 15;
      entryScore += 20;
      reasons.add('Son yapıda lower-high oluşmuş.');
    }

    if (smallBodyAfterRun) {
      pumpScore += 10;
      entryScore += 10;
      reasons.add('Pump sonrası gövde küçülmüş.');
    }

    if (lastRedAfterRun) {
      pumpScore += 10;
      entryScore += 15;
      reasons.add('Yükseliş sonrası kırmızı mum gelmiş.');
    }

    if (weakClose) {
      pumpScore += 10;
      entryScore += 10;
      reasons.add('Kapanış tepeye yakın değil, zayıf kalmış.');
    }

    if (failedBreakout) {
      pumpScore += 10;
      entryScore += 15;
      reasons.add('Yeni high denenmiş ama kapanış zayıf kalmış.');
    }

    if (pumpScore > 100) pumpScore = 100;
    if (entryScore > 100) entryScore = 100;

    String pumpType;
    if (pumpScore >= 70) {
      pumpType = 'Fake pump';
    } else if (pumpScore >= 45) {
      pumpType = 'İzlenmeli';
    } else {
      pumpType = 'Gerçek pump';
    }

    String entrySignal;
    bool shortReady;

    if (entryScore >= 70) {
      entrySignal = 'Giriş uygun';
      shortReady = true;
    } else if (entryScore >= 45) {
      entrySignal = 'Hazır';
      shortReady = false;
    } else {
      entrySignal = 'Bekle';
      shortReady = false;
    }

    return PumpAnalysisResult(
      pumpType: pumpType,
      pumpScore: pumpScore,
      entryScore: entryScore,
      shortReady: shortReady,
      entrySignal: entrySignal,
      reasons: reasons.isEmpty
          ? ['Şimdilik net fake pump zayıflaması görülmüyor.']
          : reasons,
    );
  }
}
