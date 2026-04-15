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
  static EntryEngineSnapshot evaluate({
    required EntryEngineState state,
