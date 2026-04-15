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
  reasons.add("Weakness detected");
}

if (state.weaknessDetected && _detectBreakdownNow(candles)) {
  state.breakdownDetected = true;
  state.breakdownConfirmations += 1;
  reasons.add("Breakdown confirmation");
}

if (_detectRecoveryInvalidation(candles)) {
  state.invalidated = true;
  state.breakdownDetected = false;
  state.breakdownConfirmations = 0;
  reasons.add("Invalidation detected");
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

final change = (last.close - prev.close) / prev.close * 100;

return change > 3;

}

bool _detectWeaknessNow(List<dynamic> candles) {
if (candles.length < 3) return false;

final last = candles.last;

return last.rsi > 80;

}

bool _detectBreakdownNow(List<dynamic> candles) {
if (candles.length < 3) return false;

final last = candles.last;
final prev = candles[candles.length - 2];

return last.close < prev.close;

}

bool _detectRecoveryInvalidation(List<dynamic> candles) {
if (candles.length < 3) return false;

final last = candles.last;
final prev = candles[candles.length - 2];

final change = (last.close - prev.close) / prev.close * 100;

return change > 2;

}
}
