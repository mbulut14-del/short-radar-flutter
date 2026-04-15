
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
