
class EntryEngineState {
  bool pumpDetected = false;
  bool weaknessDetected = false;
  bool breakdownConfirmed = false;

  DateTime? pumpTime;
}

class EntryEngineSnapshot {
  final bool isEarly;
  final bool isReady;
  final bool isWeak;

  EntryEngineSnapshot({
    required this.isEarly,
    required this.isReady,
    required this.isWeak,
  });
}

EntryEngineSnapshot runEntryEngine({
  required EntryEngineState state,
  required double priceChange,
  required double volume,
  required double rsi,
  required String orderFlow,
}) {
  // 🔥 PUMP DETECTION
  if (priceChange > 3 && volume > 1.5) {
    state.pumpDetected = true;
    state.pumpTime = DateTime.now();
  }

  // 🔻 WEAKNESS
  if (state.pumpDetected && rsi > 80 && orderFlow == "SELL_PRESSURE") {
    state.weaknessDetected = true;
  }

  // 💥 BREAKDOWN
  if (state.weaknessDetected && priceChange < 0) {
    state.breakdownConfirmed = true;
  }

  return EntryEngineSnapshot(
    isEarly: state.pumpDetected && !state.weaknessDetected,
    isReady: state.weaknessDetected && !state.breakdownConfirmed,
    isWeak: state.breakdownConfirmed,
  );
}
