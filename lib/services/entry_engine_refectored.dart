import '../models/candle_data.dart';

class EntryEngineState {
bool hadPump;
bool weaknessSeen;
bool breakStarted;
int breakdownConfirmations;
String phase;
List<String> reasons;
double score;

EntryEngineState({
  this.hadPump = false,
  this.weaknessSeen = false,
  this.breakStarted = false,
  this.breakdownConfirmations = 0,
  this.phase = 'SEARCHING',
  List<String>? reasons,
  this.score = 0,
}) : reasons = reasons ?? <String>[];

void reset() {
  hadPump = false;
  weaknessSeen = false;
  breakStarted = false;
  breakdownConfirmations = 0;
  phase = 'SEARCHING';
  reasons = <String>[];
  score = 0;
}
}

class EntryEngineSnapshot {
final bool hadPump;
final bool weaknessSeen;
final bool breakStarted;
final int breakdownConfirmations;
final String phase;
final double score;
final List<String> reasons;

const EntryEngineSnapshot({
  required this.hadPump,
  required this.weaknessSeen,
  required this.breakStarted,
  required this.breakdownConfirmations,
  required this.phase,
  required this.score,
  required this.reasons,
});
}


class EntryEngine {
  double _clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }
  \ndouble _bodySize(CandleData candle) {
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

  bool _detectPumpNow(List<CandleData> candles) {
    if (candles.length < 5) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev4 = candles[candles.length - 5];

    if (prev4.close <= 0) return false;

    final double risePct = ((last.high - prev4.close) / prev4.close) * 100;
    final int greenCount = [
      candles[candles.length - 5].close > candles[candles.length - 5].open,
      candles[candles.length - 4].close > candles[candles.length - 4].open,
      candles[candles.length - 3].close > candles[candles.length - 3].open,
      candles[candles.length - 2].close > candles[candles.length - 2].open,
    ].where((e) => e).length;

    return risePct >= 4.0 && greenCount >= 3;
  }

  bool _detectWeaknessNow(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    final bool prevReject =
        _hasBigUpperWick(prev, minRatio: 0.35) &&
        _hasWeakClose(prev, maxCloseRatio: 0.58);
    final bool lastReject =
        _hasBigUpperWick(last, minRatio: 0.35) &&
        _hasWeakClose(last, maxCloseRatio: 0.58);
    final bool lowerHigh = last.high < prev.high;
    final bool redPressure = last.close < last.open;

    return prevReject || (lastReject && lowerHigh) || (lowerHigh && redPressure);
  }

  bool _detectBreakdownNow(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];
    final CandleData prev3 = candles[candles.length - 4];

    final bool lowerHigh = last.high < prev.high;
    final bool weakClose = _hasWeakClose(last, maxCloseRatio: 0.55);
    final bool redBody = last.close < last.open;
    final double support = prev2.low < prev3.low ? prev2.low : prev3.low;
    final bool supportBreak = support > 0 && last.close < support;
    final bool belowPrevMid = last.close < (prev.low + (_rangeSize(prev) * 0.5));

    return (lowerHigh && redBody && weakClose) ||
        (lowerHigh && belowPrevMid) ||
        supportBreak;
  }

  bool _detectRecoveryInvalidation(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    final bool strongGreenRecovery =
        last.close > last.open &&
        _bodySize(last) > 0 &&
        _bodySize(last) >= _rangeSize(last) * 0.45;
    final bool reclaimedPrevHigh = last.close > prev.high;
    final bool strongCloseNearHigh = !_hasWeakClose(last, maxCloseRatio: 0.75);

    return strongGreenRecovery && reclaimedPrevHigh && strongCloseNearHigh;
  }

  EntryEngineSnapshot _evaluateEntryEngine(List<CandleData> candles) {
    final EntryEngineState state = _entryEngineState;

    if (candles.length < 5) {
      state.reset();
      return EntryEngineSnapshot(
        hadPump: false,
        weaknessSeen: false,
        breakStarted: false,
        breakdownConfirmations: 0,
        phase: 'SEARCHING',
        score: 0,
        reasons: const <String>[],
      );
    }

    final bool pumpNow = _detectPumpNow(candles);
    final bool weaknessNow = _detectWeaknessNow(candles);
    final bool breakdownNow = _detectBreakdownNow(candles);
    final bool invalidated = _detectRecoveryInvalidation(candles);

    final List<String> reasons = [];

    if (invalidated) {
      state.reset();
      state.phase = 'INVALIDATED';
      state.reasons = <String>[
        'Kırılma denemesi sonrası güçlü yukarı toparlama geldi.'
      ];
      state.score = 18;
      return EntryEngineSnapshot(
        hadPump: state.hadPump,
        weaknessSeen: state.weaknessSeen,
        breakStarted: state.breakStarted,
        breakdownConfirmations: state.breakdownConfirmations,
        phase: state.phase,
        score: state.score,
        reasons: List<String>.from(state.reasons),
      );
    }

    if (pumpNow) {
      state.hadPump = true;
      state.phase = 'PUMP_TRACKING';
      reasons.add('Önce güçlü pump tespit edildi.');
    }

    if (state.hadPump && weaknessNow) {
      state.weaknessSeen = true;
      state.phase = 'WEAKNESS_TRACKING';
      reasons.add('Pump sonrası ilk zayıflama başladı.');
    }

    if (state.hadPump && state.weaknessSeen && breakdownNow) {
      state.breakStarted = true;
      state.breakdownConfirmations += 1;
      state.phase = 'BREAK_READY';
      reasons.add('İlk kırılma başladı.');
      if (state.breakdownConfirmations >= 2) {
        reasons.add('Kırılma ikinci kez teyit aldı.');
      }
    } else if (!breakdownNow && state.breakdownConfirmations > 0) {
      state.breakdownConfirmations = 1;
    }

    if (!state.hadPump && !pumpNow) {
      state.phase = 'SEARCHING';
      state.reasons = <String>[];
      state.score = 0;
      return EntryEngineSnapshot(
        hadPump: state.hadPump,
        weaknessSeen: state.weaknessSeen,
        breakStarted: state.breakStarted,
        breakdownConfirmations: state.breakdownConfirmations,
        phase: state.phase,
        score: state.score,
        reasons: List<String>.from(state.reasons),
      );
    }

    double score = 0;

    if (state.hadPump) score += 26;
    if (state.weaknessSeen) score += 24;
    if (state.breakStarted) score += 26;
    if (state.breakdownConfirmations >= 2) score += 12;

    if (pumpNow) score += 6;
    if (weaknessNow) score += 8;
    if (breakdownNow) score += 12;

    score = _clampScore(score);

    if (reasons.isEmpty) {
      if (state.phase == 'PUMP_TRACKING') {
        reasons.add('Pump izleniyor, zayıflama bekleniyor.');
      } else if (state.phase == 'WEAKNESS_TRACKING') {
        reasons.add('İlk zayıflama izlendi, kırılma teyidi bekleniyor.');
      } else if (state.phase == 'BREAK_READY') {
        reasons.add('Entry engine kırılma modunda.');
      }
    }

    state.score = score;
    state.reasons = reasons;

    return EntryEngineSnapshot(
      hadPump: state.hadPump,
      weaknessSeen: state.weaknessSeen,
      breakStarted: state.breakStarted,
      breakdownConfirmations: state.breakdownConfirmations,
      phase: state.phase,
      score: state.score,
      reasons: List<String>.from(state.reasons),
    );
  }

}
