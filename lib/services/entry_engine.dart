class EntryEngineState {
  bool pumpDetected = false;
  bool weaknessDetected = false;
  bool breakdownDetected = false;
  bool invalidated = false;

  int breakdownConfirmations = 0;

  DateTime? pumpTime;
  DateTime? weaknessTime;
}

class EntryEngineSnapshot {
  final String phase;
  final int breakdownConfirmations;
  final List<String> reasons;

  EntryEngineSnapshot({
    required this.phase,
    required this.breakdownConfirmations,
    required this.reasons,
  });
}

class EntryEngine {
  EntryEngineSnapshot evaluate({
    required List<dynamic> candles,
    required EntryEngineState state,
  }) {
    final reasons = <String>[];

    if (candles.length < 3) {
      return EntryEngineSnapshot(
        phase: "IDLE",
        breakdownConfirmations: 0,
        reasons: reasons,
      );
    }

    final bool pumpNow = _detectPumpNow(candles);
    final bool weaknessNow = _detectWeaknessNow(candles);
    final bool breakdownNow = _detectBreakdownNow(candles);
    final bool invalidationNow = _detectRecoveryInvalidation(candles);

    if (pumpNow) {
      if (!state.pumpDetected) {
        reasons.add("Pump detected");
      }
      state.pumpDetected = true;
      state.pumpTime = DateTime.now();

      if (state.invalidated) {
        state.invalidated = false;
        reasons.add("Pump restarted after invalidation");
      }
    }

    if (state.pumpDetected && weaknessNow) {
      if (!state.weaknessDetected) {
        reasons.add("Weakness detected (wick + momentum loss)");
      }
      state.weaknessDetected = true;
      state.weaknessTime = DateTime.now();
    }

    if (state.weaknessDetected && breakdownNow) {
      state.breakdownDetected = true;
      state.breakdownConfirmations += 1;

      if (state.breakdownConfirmations == 1) {
        reasons.add("Real breakdown (support broken)");
      } else {
        reasons.add(
          "Breakdown confirmation +${state.breakdownConfirmations}",
        );
      }
    }

    if (invalidationNow) {
      final bool hadSetup =
          state.pumpDetected ||
          state.weaknessDetected ||
          state.breakdownDetected ||
          state.breakdownConfirmations > 0;

      if (hadSetup) {
        reasons.add("Strong recovery → invalidation");
      }

      state.invalidated = true;
      state.breakdownDetected = false;
      state.breakdownConfirmations = 0;
      state.weaknessDetected = false;
    }

    if (_shouldResetState(candles, state)) {
      reasons.add("Setup expired → reset");
      _resetState(state);
    }

    String phase = "IDLE";

    if (state.pumpDetected && !state.weaknessDetected) {
      phase = "PUMP_TRACKING";
    } else if (state.weaknessDetected && !state.breakdownDetected) {
      phase = "WEAKNESS_TRACKING";
    } else if (state.breakdownDetected) {
      phase = "BREAK_READY";
    }

    if (state.invalidated) {
      phase = "INVALIDATED";
    }

    return EntryEngineSnapshot(
      phase: phase,
      breakdownConfirmations: state.breakdownConfirmations,
      reasons: reasons,
    );
  }

  bool _detectPumpNow(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    if (prev.close == 0 || prev2.close == 0) return false;

    final double lastChange =
        ((last.close - prev.close) / prev.close) * 100;
    final double twoCandleChange =
        ((last.close - prev2.close) / prev2.close) * 100;

    final double lastRange = (last.high - last.low).abs();
    if (lastRange == 0) return false;

    final double bodyRatio =
        (last.close - last.open).abs() / lastRange;
    final bool strongGreen = last.close > last.open && bodyRatio >= 0.55;
    final bool priceExpansion = last.close > prev.close && prev.close >= prev2.close;

    return priceExpansion &&
        (lastChange >= 2.2 || twoCandleChange >= 4.0) &&
        strongGreen;
  }

  bool _detectWeaknessNow(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final double range = (last.high - last.low).abs();
    if (range == 0) return false;

    final double body = (last.close - last.open).abs();
    final double upperWick = last.high - (last.close > last.open ? last.close : last.open);

    final bool smallBody = body / range < 0.45;
    final bool bigUpperWick = upperWick / range > 0.35;
    final bool momentumLoss = last.close <= prev.close;
    final bool lowerHigh = last.high < prev.high;
    final bool bearishShift = last.close < last.open;

    return (smallBody && bigUpperWick && momentumLoss) ||
        (lowerHigh && momentumLoss) ||
        (bigUpperWick && bearishShift);
  }

  bool _detectBreakdownNow(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    final double range = (last.high - last.low).abs();
    if (range == 0) return false;

    final double bodyRatio =
        (last.open - last.close).abs() / range;

    final bool strongRed =
        last.close < last.open && bodyRatio >= 0.45;

    final bool closeBelowPrevLow = last.close < prev.low;
    final bool closeBelowPrev2Low = last.close < prev2.low;
    final bool lowerClose = last.close < prev.close;

    return strongRed &&
        lowerClose &&
        (closeBelowPrevLow || closeBelowPrev2Low);
  }

  bool _detectRecoveryInvalidation(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    if (prev.close == 0) return false;

    final double range = (last.high - last.low).abs();
    if (range == 0) return false;

    final double change =
        ((last.close - prev.close) / prev.close) * 100;

    final bool strongGreen = last.close > last.open &&
        ((last.close - last.open).abs() / range) >= 0.55;

    final bool breakoutAbovePrevHigh = last.close > prev.high;

    return strongGreen && change > 1.8 && breakoutAbovePrevHigh;
  }

  bool _shouldResetState(List<dynamic> candles, EntryEngineState state) {
    if (candles.length < 4) return false;

    if (!state.pumpDetected && !state.weaknessDetected && !state.breakdownDetected) {
      return false;
    }

    final last = candles.last;
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    final bool flatRecovery =
        last.close >= prev.close &&
        prev.close >= prev2.close &&
        last.close > last.open;

    final bool noMoreWeakness =
        last.high >= prev.high && last.close >= prev.close;

    return state.invalidated || (flatRecovery && noMoreWeakness);
  }

  void _resetState(EntryEngineState state) {
    state.pumpDetected = false;
    state.weaknessDetected = false;
    state.breakdownDetected = false;
    state.invalidated = false;
    state.breakdownConfirmations = 0;
    state.pumpTime = null;
    state.weaknessTime = null;
  }
}
