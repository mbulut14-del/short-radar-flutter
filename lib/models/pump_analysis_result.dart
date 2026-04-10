class PumpAnalysisResult {
  final String pumpType; // Fake / Real / Uncertain
  final int pumpScore; // 0 - 100
  final int entryScore; // 0 - 100
  final bool shortReady; // giriş uygun mu
  final String entrySignal; // Bekle / Hazır / Giriş uygun
  final List<String> reasons; // açıklamalar

  const PumpAnalysisResult({
    required this.pumpType,
    required this.pumpScore,
    required this.entryScore,
    required this.shortReady,
    required this.entrySignal,
    required this.reasons,
  });
}
