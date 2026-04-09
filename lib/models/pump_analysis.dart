
import 'candle_data.dart';

class PumpAnalysis {
  final bool isParabolic;
  final bool isOverExtended;
  final bool isFakePump;
  final double pumpStrength;

  const PumpAnalysis({
    required this.isParabolic,
    required this.isOverExtended,
    required this.isFakePump,
    required this.pumpStrength,
  });

  static PumpAnalysis analyze(List<CandleData> candles) {
    if (candles.length < 10) {
      return const PumpAnalysis(
        isParabolic: false,
        isOverExtended: false,
        isFakePump: false,
        pumpStrength: 0,
      );
    }

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final priceChange = ((last.close - prev.close) / prev.close) * 100;

    final isStrongCandle = priceChange > 2;
    final isBigWick = last.upperWick > last.bodySize * 1.5;

    final isParabolic = candles
        .sublist(candles.length - 5)
        .every((c) => c.isBullish);

    final isOverExtended = priceChange > 5;

    final isFakePump = isBigWick && isStrongCandle;

    final pumpStrength = priceChange.clamp(0, 10);

    return PumpAnalysis(
      isParabolic: isParabolic,
      isOverExtended: isOverExtended,
      isFakePump: isFakePump,
      pumpStrength: pumpStrength.toDouble(),
    );
  }
}
