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

    if (_detectPumpNow(candles)) {
      state.pumpDetected = true;
      state.pumpTime = DateTime.now();
      state.invalidated = false;
      reasons.add("Pump detected");
    }

    if (state.pumpDetected && _detectWeaknessNow(candles)) {
      state.weaknessDetected = true;
      state.weaknessTime = DateTime.now();
      reasons.add("Weakness detected (wick + momentum loss)");
    }

    if (state.weaknessDetected && _detectBreakdownNow(candles)) {
      state.breakdownDetected = true;
      state.breakdownConfirmations += 1;
      reasons.add("Real breakdown (low broken)");
    }

    if (_detectRecoveryInvalidation(candles)) {
      state.invalidated = true;
      state.breakdownDetected = false;
      state.breakdownConfirmations = 0;
      reasons.add("Strong recovery → invalidation");
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

  // 🔥 1. PUMP
  bool _detectPumpNow(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final change = (last.close - prev.close) / prev.close * 100;

    return change > 3;
  }

  // 🔥 2. GERÇEK ZAYIFLAMA
  bool _detectWeaknessNow(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final body = (last.close - last.open).abs();
    final range = (last.high - last.low);

    if (range == 0) return false;

    final upperWick = last.high - last.close;

    final smallBody = body / range < 0.4;
    final bigUpperWick = upperWick / range > 0.4;

    final momentumLoss = last.close <= prev.close;

    return smallBody && bigUpperWick && momentumLoss;
  }

  // 🔥 3. GERÇEK BREAKDOWN
  bool _detectBreakdownNow(List<dynamic> candles) {
    if (candles.length < 4) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];
    final prev2 = candles[candles.length - 3];

    final previousLow = prev2.low;

    final strongRed =
        last.close < last.open &&
        ((last.open - last.close) / (last.high - last.low)) > 0.6;

    final lowBroken = last.close < previousLow;

    return strongRed && lowBroken;
  }

  // 🔥 4. INVALIDATION (SQUEEZE)
  bool _detectRecoveryInvalidation(List<dynamic> candles) {
    if (candles.length < 3) return false;

    final last = candles.last;
    final prev = candles[candles.length - 2];

    final change = (last.close - prev.close) / prev.close * 100;

    final strongGreen = last.close > last.open &&
        ((last.close - last.open) / (last.high - last.low)) > 0.6;

    return change > 2 && strongGreen;
  }
}
