import '../models/candle_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import '../services/analysis_engine.dart';

class FinalScoreResult {
  final double score;
  final String label;
  final String summary;

  const FinalScoreResult({
    required this.score,
    required this.label,
    required this.summary,
  });
}

class FinalTradeDecision {
  final double finalScore;
  final String scoreClass;
  final double confidence;
  final String primarySignal;
  final String tradeBias;
  final String action;
  final String summary;

  final double oiScore;
  final double priceScore;
  final double orderFlowScore;
  final double volumeScore;
  final double liquidationScore;
  final double momentumScore;

  final List<String> marketReadBullets;
  final List<String> entryNotes;
  final List<String> warnings;
  final List<String> triggerConditions;

  const FinalTradeDecision({
    required this.finalScore,
    required this.scoreClass,
    required this.confidence,
    required this.primarySignal,
    required this.tradeBias,
    required this.action,
    required this.summary,
    required this.oiScore,
    required this.priceScore,
    required this.orderFlowScore,
    required this.volumeScore,
    required this.liquidationScore,
    required this.momentumScore,
    required this.marketReadBullets,
    required this.entryNotes,
    required this.warnings,
    required this.triggerConditions,
  });

  FinalScoreResult toLegacyScoreResult() {
    return FinalScoreResult(
      score: finalScore,
      label: scoreClass,
      summary: summary,
    );
  }
}

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

class FinalTradeDecisionService {
  static String safeLower(dynamic value) {
    if (value is String) {
      return value.toLowerCase();
    }
    return '';
  }

  static double clampScore(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }
}
