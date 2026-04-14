class AnalysisEngine {
  static String normalizeDirection(String value) {
    final String v = value.trim().toUpperCase();

    if (v == 'UP') return 'UP';
    if (v == 'DOWN') return 'DOWN';
    return 'FLAT';
  }

  static String normalizeOrderFlow(String value) {
    final String v = value.trim().toUpperCase();

    if (v == 'BUY_PRESSURE') return 'BUY_PRESSURE';
    if (v == 'SELL_PRESSURE') return 'SELL_PRESSURE';
    return 'NEUTRAL';
  }

  static String getCombinedSignal({
    required String oiDirection,
    required String priceDirection,
    required String orderFlow,
  }) {
    final String oi = normalizeDirection(oiDirection);
    final String price = normalizeDirection(priceDirection);
    final String flow = normalizeOrderFlow(orderFlow);

    if (oi == 'UP' && price == 'DOWN' && flow == 'SELL_PRESSURE') {
      return 'STRONG_SHORT';
    }

    if (oi == 'UP' && price == 'UP' && flow == 'SELL_PRESSURE') {
      return 'PUMP_RISK';
    }

    if (oi == 'DOWN' && price == 'UP' && flow == 'BUY_PRESSURE') {
      return 'SHORT_SQUEEZE';
    }

    if (oi == 'DOWN' && price == 'DOWN' && flow == 'SELL_PRESSURE') {
      return 'WEAK_DROP';
    }

    if (oi == 'FLAT' && price == 'FLAT' && flow == 'BUY_PRESSURE') {
      return 'EARLY_ACCUMULATION';
    }

    if (oi == 'FLAT' && price == 'FLAT' && flow == 'SELL_PRESSURE') {
      return 'EARLY_DISTRIBUTION';
    }

    return 'NEUTRAL';
  }

  static double getSignalStrength({
    required String oiDirection,
    required String priceDirection,
    required String orderFlow,
  }) {
    final String oi = normalizeDirection(oiDirection);
    final String price = normalizeDirection(priceDirection);
    final String flow = normalizeOrderFlow(orderFlow);

    int score = 0;

    if (oi == 'UP') score++;
    if (price == 'DOWN') score++;
    if (flow == 'SELL_PRESSURE') score++;

    if (oi == 'DOWN') score++;
    if (price == 'UP') score++;
    if (flow == 'BUY_PRESSURE') score++;

    return score / 6;
  }

  static Map<String, dynamic> getSetupClassification({
    required String signal,
    required double strength,
    required String orderFlow,
  }) {
    double score = strength * 100;

    final String s = signal.toUpperCase();
    final String flow = orderFlow.toUpperCase();

    if (s == 'STRONG_SHORT') score += 25;
    if (s == 'PUMP_RISK') score += 10;
    if (s == 'SHORT_SQUEEZE') score += 10;
    if (s == 'EARLY_DISTRIBUTION') score += 20;
    if (s == 'EARLY_ACCUMULATION') score += 20;

    if (flow == 'SELL_PRESSURE' && s.contains('DISTRIBUTION')) {
      score += 15;
    }

    if (flow == 'BUY_PRESSURE' && s.contains('ACCUMULATION')) {
      score += 15;
    }

    if (flow == 'BUY_PRESSURE' && s.contains('SHORT')) {
      score -= 15;
    }

    if (flow == 'SELL_PRESSURE' && s.contains('ACCUMULATION')) {
      score -= 15;
    }

    score = score.clamp(0, 100);

    String label;
    if (score < 40) {
      label = 'Zayıf';
    } else if (score < 70) {
      label = 'İzlenmeli';
    } else if (score < 85) {
      label = 'Kurulum var';
    } else {
      label = 'Güçlü fırsat';
    }

    return {
      'score': score,
      'label': label,
    };
  }

  // 🔥 YENİ EKLENEN: EARLY SHORT DETECTION
  static bool detectEarlyShort(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final last = candles[candles.length - 1];
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    final double bodyTop = last.close > last.open ? last.close : last.open;
    final double upperWick = last.high - bodyTop;
    final double range = last.high - last.low;

    if (range == 0) return false;

    final double wickRatio = upperWick / range;

    final bool bigUpperWick = wickRatio > 0.35;

    final bool pumpBefore =
        prev.close > prev.open &&
        prev2.close > prev2.open &&
        last.high > prev.high;

    final bool weakClose = last.close < last.open;

    if (bigUpperWick && pumpBefore && weakClose) {
      return true;
    }

    return false;
  }
}
