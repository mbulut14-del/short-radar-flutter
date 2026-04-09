import 'dart:math' as math;

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

String _formatPercent(double value, {int digits = 2}) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
}

String _formatFunding(double value) {
  final percent = value * 100;
  return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(4)}%';
}

class CoinRadarData {
  final String name;
  final double changePercent;
  final double fundingRate;
  final double lastPrice;
  final double markPrice;
  final double indexPrice;
  final double volume24h;
  final int score;
  final String biasLabel;
  final String note;

  const CoinRadarData({
    required this.name,
    required this.changePercent,
    required this.fundingRate,
    required this.lastPrice,
    required this.markPrice,
    required this.indexPrice,
    required this.volume24h,
    required this.score,
    required this.biasLabel,
    required this.note,
  });

  factory CoinRadarData.seed({
    required String name,
    required double changePercent,
  }) {
    final int score = _calculateScore(
      changePercent: changePercent,
      fundingRate: 0,
      markPrice: 0,
      indexPrice: 0,
      volume24h: 0,
    );

    return CoinRadarData(
      name: name,
      changePercent: changePercent,
      fundingRate: 0,
      lastPrice: 0,
      markPrice: 0,
      indexPrice: 0,
      volume24h: 0,
      score: score,
      biasLabel: _biasLabel(score),
      note: _noteText(score, changePercent, 0, 0, 0),
    );
  }

  factory CoinRadarData.fromJson(Map<String, dynamic> json) {
    final double changePercent = _parseDouble(json['change_percentage']);
    final double fundingRate = _parseDouble(json['funding_rate']);
    final double lastPrice = _parseDouble(json['last']);
    final double markPrice = _parseDouble(json['mark_price']);
    final double indexPrice = _parseDouble(json['index_price']);
    final double volume24h = _parseDouble(
      json['volume_24h_quote'] ?? json['volume_24h'] ?? 0,
    );

    final int score = _calculateScore(
      changePercent: changePercent,
      fundingRate: fundingRate,
      markPrice: markPrice,
      indexPrice: indexPrice,
      volume24h: volume24h,
    );

    return CoinRadarData(
      name: (json['contract'] ?? '').toString(),
      changePercent: changePercent,
      fundingRate: fundingRate,
      lastPrice: lastPrice,
      markPrice: markPrice,
      indexPrice: indexPrice,
      volume24h: volume24h,
      score: score,
      biasLabel: _biasLabel(score),
      note: _noteText(
        score,
        changePercent,
        fundingRate,
        markPrice,
        indexPrice,
      ),
    );
  }

  static int _calculateScore({
    required double changePercent,
    required double fundingRate,
    required double markPrice,
    required double indexPrice,
    required double volume24h,
  }) {
    double score = 0;

    if (changePercent > 0) {
      score += math.min(changePercent * 0.9, 48);
    } else {
      score += math.max(changePercent * 0.15, -10);
    }

    if (fundingRate > 0) {
      score += math.min(fundingRate * 10000, 28);
    } else if (fundingRate < 0) {
      score -= math.min(fundingRate.abs() * 5000, 10);
    }

    if (indexPrice != 0) {
      final double divergence =
          ((markPrice - indexPrice) / indexPrice).abs() * 100;
      score += math.min(divergence * 22, 14);
    }

    if (volume24h > 0) {
      final double volumeBoost = math.max(
        0,
        math.min((math.log(volume24h + 1) - 10) * 2.2, 10),
      );
      score += volumeBoost;
    }

    score = score.clamp(0, 100);
    return score.round();
  }

  static String _biasLabel(int score) {
    if (score >= 75) return 'Çok güçlü short';
    if (score >= 60) return 'Güçlü short';
    if (score >= 45) return 'İzlemeye değer';
    if (score >= 30) return 'Zayıf baskı';
    return 'Nötr';
  }

  static String _noteText(
    int score,
    double changePercent,
    double fundingRate,
    double markPrice,
    double indexPrice,
  ) {
    final double divergence = indexPrice == 0
        ? 0
        : ((markPrice - indexPrice) / indexPrice).abs() * 100;

    if (score >= 75) {
      return 'Pump güçlü, funding şişmiş. Sert short takibi.';
    }
    if (score >= 60) {
      return 'Yükseliş ve funding birlikte ısınıyor.';
    }
    if (score >= 45) {
      return 'İzlenebilir short baskısı oluşuyor.';
    }
    if (changePercent < 0) {
      return 'Zaten zayıflamış, short avantajı düşebilir.';
    }
    if (divergence > 0.20) {
      return 'Fiyat farkı var, volatilite yükselebilir.';
    }
    if (fundingRate > 0) {
      return 'Funding pozitif ama sinyal orta güçte.';
    }
    return 'Şimdilik net short baskısı zayıf.';
  }

  String get changeText => _formatPercent(changePercent);
  String get fundingText => _formatFunding(fundingRate);

  double get divergencePercent {
    if (indexPrice == 0) return 0;
    return ((markPrice - indexPrice) / indexPrice).abs() * 100;
  }

  String get lastPriceText => lastPrice == 0 ? '-' : lastPrice.toStringAsFixed(6);
  String get markPriceText => markPrice == 0 ? '-' : markPrice.toStringAsFixed(6);
  String get indexPriceText => indexPrice == 0 ? '-' : indexPrice.toStringAsFixed(6);
}
