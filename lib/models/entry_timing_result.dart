class EntryTimingResult {
  final String signal;
  final int score;
  final bool ready;
  final List<String> reasons;

  const EntryTimingResult({
    required this.signal,
    required this.score,
    required this.ready,
    required this.reasons,
  });
}
