class ShortSetupResult {
  final double entry;
  final double stopLoss;
  final double target1;
  final double target2;
  final double rr;
  final String status;
  final String summary;
  final List<String> reasons;

  const ShortSetupResult({
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.rr,
    required this.status,
    required this.summary,
    required this.reasons,
  });
}
