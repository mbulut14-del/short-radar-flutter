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

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static double _open(dynamic candle) {
    return _num(candle.open);
  }

  static double _high(dynamic candle) {
    return _num(candle.high);
  }

  static double _low(dynamic candle) {
    return _num(candle.low);
  }

  static double _close(dynamic candle) {
    return _num(candle.close);
  }

  static double _volume(dynamic candle) {
    try {
      return _num(candle.volume);
    } catch (_) {
      return 0;
    }
  }

  static double _bodySize(dynamic candle) {
    return (_close(candle) - _open(candle)).abs();
  }

  static double _rangeSize(dynamic candle) {
    return (_high(candle) - _low(candle)).abs();
  }

  static double _upperWickSize(dynamic candle) {
    final double bodyTop =
        _close(candle) >= _open(candle) ? _close(candle) : _open(candle);
    return _high(candle) - bodyTop;
  }

  static bool _isGreen(dynamic candle) {
    return _close(candle) > _open(candle);
  }

  static bool _isRed(dynamic candle) {
    return _close(candle) < _open(candle);
  }

  static bool _hasBigUpperWick(dynamic candle, {double minRatio = 0.35}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;

    final double wickRatio = _upperWickSize(candle) / range;
    return wickRatio >= minRatio;
  }

  static bool _hasWeakClose(dynamic candle, {double maxCloseRatio = 0.60}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;

    final double closePosition = (_close(candle) - _low(candle)) / range;
    return closePosition <= maxCloseRatio;
  }

  static bool _hasPumpBeforeTop(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final dynamic last = candles[candles.length - 1];
    final dynamic prev = candles[candles.length - 2];
    final dynamic prev2 = candles[candles.length - 3];
    final dynamic prev3 = candles[candles.length - 4];

    final bool twoGreen =
        _isGreen(prev) && (_isGreen(prev2) || _isGreen(prev3));

    final double baseClose = _close(prev3);
    if (baseClose <= 0) return false;

    final double risePct = ((_high(last) - baseClose) / baseClose) * 100;

    return twoGreen && risePct >= 4.0;
  }

  static bool _hasVolumeExpansion(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final dynamic last = candles[candles.length - 1];
    final dynamic prev = candles[candles.length - 2];
    final dynamic prev2 = candles[candles.length - 3];
    final dynamic prev3 = candles[candles.length - 4];

    final double lastVolume = _volume(last);
    final double avgPrevVolume =
        (_volume(prev) + _volume(prev2) + _volume(prev3)) / 3;

    if (avgPrevVolume <= 0) return false;

    return lastVolume >= avgPrevVolume * 1.15;
  }

  static bool detectEarlyShort(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final dynamic last = candles[candles.length - 1];

    final bool bigUpperWick = _hasBigUpperWick(last, minRatio: 0.35);
    final bool weakClose = _hasWeakClose(last, maxCloseRatio: 0.60);
    final bool pumpBefore = _hasPumpBeforeTop(candles);

    return bigUpperWick && weakClose && pumpBefore;
  }

  static Map<String, dynamic> detectPriceStructure(List<dynamic> candles) {
    if (candles.length < 6) {
      return {
        'detected': false,
        'score': 0.0,
        'label': 'NONE',
        'reasons': <String>[],
      };
    }

    final dynamic last = candles[candles.length - 1];
    final dynamic prev = candles[candles.length - 2];
    final dynamic prev2 = candles[candles.length - 3];
    final dynamic prev3 = candles[candles.length - 4];
    final dynamic prev4 = candles[candles.length - 5];

    double score = 0;
    final List<String> reasons = [];

    final double baseClose = _close(prev4);
    final double topHigh = _high(prev);
    final double lastClose = _close(last);

    if (baseClose > 0) {
      final double pumpPct = ((topHigh - baseClose) / baseClose) * 100;
      if (pumpPct >= 6) {
        score += 28;
        reasons.add('Öncesinde güçlü pump var.');
      } else if (pumpPct >= 4) {
        score += 20;
        reasons.add('Öncesinde anlamlı yükseliş var.');
      } else if (pumpPct >= 2.5) {
        score += 10;
        reasons.add('Kısa vadede yukarı şişme görülüyor.');
      }
    }

    final int greenCount = [_isGreen(prev4), _isGreen(prev3), _isGreen(prev2), _isGreen(prev)]
        .where((e) => e)
        .length;

    if (greenCount >= 3) {
      score += 12;
      reasons.add('Seri yeşil mumlarla yukarı taşınmış.');
    }

    if (_hasBigUpperWick(prev, minRatio: 0.35) &&
        _hasWeakClose(prev, maxCloseRatio: 0.62)) {
      score += 22;
      reasons.add('Tepe mumunda belirgin üst wick / exhaustion var.');
    } else if (_hasBigUpperWick(last, minRatio: 0.35) &&
        _hasWeakClose(last, maxCloseRatio: 0.62)) {
      score += 18;
      reasons.add('Son mumda yukarı reddedilme var.');
    }

    if (_hasVolumeExpansion(candles)) {
      score += 10;
      reasons.add('Hacim genişlemesi eşlik ediyor.');
    }

    if (_isRed(last)) {
      score += 8;
      reasons.add('Son mum kırmızı kapanmış.');
    }

    if (_high(last) < _high(prev)) {
      score += 8;
      reasons.add('Lower high oluşumu başladı.');
    }

    if (_bodySize(prev) > 0 && _bodySize(last) > _bodySize(prev) * 1.05 && _isRed(last)) {
      score += 8;
      reasons.add('Dönüş mumu gövde olarak güçleniyor.');
    }

    final double triggerLow =
        _low(prev2) < _low(prev3) ? _low(prev2) : _low(prev3);

    if (triggerLow > 0 && lastClose < triggerLow) {
      score += 14;
      reasons.add('Önceki destek altına sarkma var.');
    }

    score = score.clamp(0, 100).toDouble();

    String label = 'NONE';
    if (score >= 70) {
      label = 'EARLY_SHORT_STRONG';
    } else if (score >= 50) {
      label = 'EARLY_SHORT';
    } else if (score >= 35) {
      label = 'WEAK_TOP_FORMING';
    }

    return {
      'detected': score >= 50,
      'score': score,
      'label': label,
      'reasons': reasons,
    };
  }

  // 🚀 YENİ EKLENDİ
  static double calculateMomentumShift(List<dynamic> candles) {
    if (candles.length < 4) return 0;

    final dynamic last = candles[candles.length - 1];
    final dynamic prev = candles[candles.length - 2];
    final dynamic prev2 = candles[candles.length - 3];

    double score = 0;

    if (_isGreen(prev) && _isRed(last)) {
      score += 30;
    }

    if (_high(last) < _high(prev)) {
      score += 25;
    }

    if (_close(last) < _close(prev)) {
      score += 20;
    }

    if (_bodySize(prev) > 0 &&
        _bodySize(last) < _bodySize(prev) * 0.7) {
      score += 15;
    }

    if (_hasBigUpperWick(last, minRatio: 0.3)) {
      score += 10;
    }

    return score.clamp(0, 100).toDouble();
  }
}
