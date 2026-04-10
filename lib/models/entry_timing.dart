class EntryTiming {
  static EntryTimingResult analyze({
    required List<CandleData> candles,
  }) {
    if (candles.isEmpty) {
      return const EntryTimingResult(
        isReady: false,
        score: 0,
        status: "Veri yok",
        reasons: ["Candle verisi bulunamadı"],
      );
    }

    final last = candles.last;

    int score = 0;
    List<String> reasons = [];

    // Üst fitil kontrolü
    final upperWick = last.high - (last.open > last.close ? last.open : last.close);
    final body = (last.open - last.close).abs();

    if (upperWick > body) {
      score += 30;
      reasons.add("Son mumda belirgin üst fitil var.");
    }

    // Kırmızı mum
    if (last.close < last.open) {
      score += 20;
      reasons.add("Son mum kırmızı kapanmış.");
    }

    // Tepeden uzak kapanış
    if ((last.high - last.close) / last.high > 0.01) {
      score += 15;
      reasons.add("Kapanış tepeye yakın değil.");
    }

    // Basit lower-high kontrolü
    if (candles.length >= 3) {
      final prev = candles[candles.length - 2];
      if (last.high < prev.high) {
        score += 20;
        reasons.add("Kısa vadede lower-high oluşmuş.");
      }
    }

    // Hazır mı?
    final isReady = score >= 70;

    String status;
    if (isReady) {
      status = "Giriş uygun";
    } else if (score >= 50) {
      status = "Hazırlanıyor";
    } else {
      status = "Bekle";
    }

    return EntryTimingResult(
      isReady: isReady,
      score: score,
      status: status,
      reasons: reasons,
    );
  }
}
