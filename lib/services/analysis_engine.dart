
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
}
        
