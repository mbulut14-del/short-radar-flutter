import '../models/candle_data.dart';

class StructureDetector {
  double _bodySize(CandleData candle) {
    return (candle.close - candle.open).abs();
  }

  double _rangeSize(CandleData candle) {
    return (candle.high - candle.low).abs();
  }

  double _upperWickSize(CandleData candle) {
    final double bodyTop =
        candle.close >= candle.open ? candle.close : candle.open;
    return candle.high - bodyTop;
  }

  bool _hasBigUpperWick(CandleData candle, {double minRatio = 0.35}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    return (_upperWickSize(candle) / range) >= minRatio;
  }

  bool _hasWeakClose(CandleData candle, {double maxCloseRatio = 0.60}) {
    final double range = _rangeSize(candle);
    if (range <= 0) return false;
    final double closePosition = (candle.close - candle.low) / range;
    return closePosition <= maxCloseRatio;
  }

  bool _hasVolumeExpansion(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];

    final double avgPrevVolume = (prev.volume + prev2.volume + prev3.volume) / 3;
    if (avgPrevVolume <= 0) return false;

    return last.volume >= avgPrevVolume * 1.15;
  }

  Map<String, dynamic> _detectPriceStructure(List<CandleData> candles) {
    if (candles.length < 6) {
      return {
        'detected': false,
        'score': 0.0,
        'label': 'NONE',
        'reasons': <String>[],
      };
    }

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];
    final CandleData prev4 = candles[candles.length - 5];

    double score = 0;
    final List<String> reasons = [];

    final double baseClose = prev4.close;
    final double topHigh = prev.high;
    final double lastClose = last.close;

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

    final int greenCount = [
      prev4.close > prev4.open,
      prev3.close > prev3.open,
      prev2.close > prev2.open,
      prev.close > prev.open,
    ].where((e) => e).length;

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

    if (last.close < last.open) {
      score += 8;
      reasons.add('Son mum kırmızı kapanmış.');
    }

    if (last.high < prev.high) {
      score += 8;
      reasons.add('Lower high oluşumu başladı.');
    }

    if (_bodySize(prev) > 0 &&
        _bodySize(last) > _bodySize(prev) * 1.05 &&
        last.close < last.open) {
      score += 8;
      reasons.add('Dönüş mumu gövde olarak güçleniyor.');
    }

    final double triggerLow = prev2.low < prev3.low ? prev2.low : prev3.low;
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

  Map<String, dynamic> _detectFirstBreak(List<CandleData> candles) {
    if (candles.length < 5) {
      return {
        'detected': false,
        'score': 0.0,
        'label': 'NONE',
        'reasons': <String>[],
      };
    }

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];
    final CandleData prev4 = candles[candles.length - 5];

    double score = 0;
    final List<String> reasons = [];

    final double baseClose = prev4.close;
    if (baseClose > 0) {
      final double pumpPct = ((prev.high - baseClose) / baseClose) * 100;
      if (pumpPct >= 6) {
        score += 18;
        reasons.add('Kırılma öncesi güçlü pump var.');
      } else if (pumpPct >= 3.5) {
        score += 12;
        reasons.add('Kırılma öncesi anlamlı yükseliş var.');
      }
    }

    if (_hasBigUpperWick(prev, minRatio: 0.40)) {
      score += 24;
      reasons.add('Önceki mumda güçlü üst wick oluştu.');
    }

    if (_hasWeakClose(prev, maxCloseRatio: 0.50)) {
      score += 18;
      reasons.add('Önceki mum zayıf kapanış yaptı.');
    }

    final double prevAvgVolume =
        (prev2.volume + prev3.volume + prev4.volume) / 3;
    if (prevAvgVolume > 0 && prev.volume >= prevAvgVolume * 1.20) {
      score += 14;
      reasons.add('Red mumunda hacim genişledi.');
    }

    if (last.high < prev.high) {
      score += 14;
      reasons.add('Son mum lower high üretiyor.');
    }

    if (last.close < last.open) {
      score += 8;
      reasons.add('Son mum kırmızı baskı gösteriyor.');
    }

    final double prevMid = prev.low + (_rangeSize(prev) * 0.5);
    if (last.close < prevMid) {
      score += 10;
      reasons.add('Son kapanış önceki mumun orta bandı altında.');
    }

    if (_bodySize(last) > 0 &&
        _bodySize(prev) > 0 &&
        _bodySize(last) >= _bodySize(prev) * 0.85 &&
        last.close < last.open) {
      score += 8;
      reasons.add('Satıcı gövdesi zayıflamıyor.');
    }

    score = score.clamp(0, 100).toDouble();

    String label = 'NONE';
    if (score >= 80) {
      label = 'FIRST_BREAK_STRONG';
    } else if (score >= 60) {
      label = 'FIRST_BREAK';
    } else if (score >= 40) {
      label = 'EARLY_WEAKENING';
    }

    return {
      'detected': score >= 60,
      'score': score,
      'label': label,
      'reasons': reasons,
    };
  }

}
