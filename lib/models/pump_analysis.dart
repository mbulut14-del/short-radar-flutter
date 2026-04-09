import 'candle_data.dart';

class PumpAnalysis {
  final String type;
  final ColorLevel level;
  final int score;
  final List<String> reasons;

  const PumpAnalysis({
    required this.type,
    required this.level,
    required this.score,
    required this.reasons,
  });

  bool get isFakePump => type == 'Fake pump';
  bool get isRealPump => type == 'Gerçek pump';

  static PumpAnalysis analyze(List<CandleData> candles) {
    if (candles.length < 6) {
      return const PumpAnalysis(
        type: 'Belirsiz',
        level: ColorLevel.neutral,
        score: 0,
        reasons: ['Pump analizi için veri yetersiz.'],
      );
    }

    final recent = candles.length > 8
        ? candles.sublist(candles.length - 8)
        : candles;

    final last = recent[recent.length - 1];
    final prev = recent[recent.length - 2];
    final prev2 = recent[recent.length - 3];

    int fakeScore = 0;
    final reasons = <String>[];

    final bool strongRun =
        recent.where((c) => c.isBullish).length >= 5;
    final bool upperWickHeavy =
        last.upperWick > last.bodySize * 1.2 && last.upperWick > 0;
    final bool momentumLoss = last.close <= prev.close;
    final bool lowerHigh = prev.high < prev2.high;
    final bool smallBodyAfterRun = strongRun && last.bodySize < prev.bodySize;
    final bool lastRedAfterRun = strongRun && !last.isBullish;

    if (strongRun) {
      fakeScore += 15;
      reasons.add('Son mumlarda güçlü pump serisi oluşmuş.');
    }

    if (upperWickHeavy) {
      fakeScore += 25;
      reasons.add('Son mumda üst fitil belirgin, satış baskısı var.');
    }

    if (momentumLoss) {
      fakeScore += 20;
      reasons.add('Son kapanış ivme kaybı gösteriyor.');
    }

    if (lowerHigh) {
      fakeScore += 18;
      reasons.add('Kısa vadede lower-high oluşumu var.');
    }

    if (smallBodyAfterRun) {
      fakeScore += 12;
      reasons.add('Pump sonrası gövde küçülmüş, güç zayıflıyor.');
    }

    if (lastRedAfterRun) {
      fakeScore += 20;
      reasons.add('Yükseliş sonrası kırmızı mum gelmiş.');
    }

    if (fakeScore >= 55) {
      return PumpAnalysis(
        type: 'Fake pump',
        level: ColorLevel.danger,
        score: fakeScore,
        reasons: reasons,
      );
    }

    if (strongRun && !upperWickHeavy && last.close >= prev.close) {
      return const PumpAnalysis(
        type: 'Gerçek pump',
        level: ColorLevel.safe,
        score: 25,
        reasons: [
          'Yükseliş devam ediyor.',
          'Üst fitil zayıf, momentum korunuyor.',
        ],
      );
    }

    return PumpAnalysis(
      type: 'Belirsiz',
      level: ColorLevel.neutral,
      score: fakeScore,
      reasons: reasons.isEmpty
          ? ['Net fake pump teyidi henüz oluşmadı.']
          : reasons,
    );
  }
}

enum ColorLevel {
  danger,
  neutral,
  safe,
}
