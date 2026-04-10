
class EntryTimingResult {
  final int score; // 0 - 100
  final bool ready;
  final String signal; // Bekle / Hazır / Giriş uygun
  final List<String> reasons;

  const EntryTimingResult({
    required this.score,
    required this.ready,
    required this.signal,
    required this.reasons,
  });
}
