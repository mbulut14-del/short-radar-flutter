class EntryTimingResult {
  final bool isReady;
  final int score;
  final String status;
  final List<String> reasons;

  const EntryTimingResult({
    required this.isReady,
    required this.score,
    required this.status,
    required this.reasons,
  });

  /// UI için kolay kullanım
  String get signal {
    if (isReady) return "Giriş uygun";
    if (score >= 50) return "Hazır";
    return "Bekle";
  }

  /// UI için hazır mı
  bool get ready => isReady;
}
