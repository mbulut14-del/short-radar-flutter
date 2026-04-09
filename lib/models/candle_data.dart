
import 'dart:math' as math;

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

class CandleData {
  final int timestamp;
  final double volume;
  final double close;
  final double high;
  final double low;
  final double open;

  const CandleData({
    required this.timestamp,
    required this.volume,
    required this.close,
    required this.high,
    required this.low,
    required this.open,
  });

  factory CandleData.fromJson(List<dynamic> raw) {
    return CandleData(
      timestamp: int.tryParse(raw[0].toString()) ?? 0,
      volume: _parseDouble(raw[1]),
      close: _parseDouble(raw[2]),
      high: _parseDouble(raw[3]),
      low: _parseDouble(raw[4]),
      open: _parseDouble(raw[5]),
    );
  }

  bool get isBullish => close >= open;

  double get bodySize => (close - open).abs();

  double get range => (high - low).abs();

  double get upperWick => high - math.max(open, close);

  double get lowerWick => math.min(open, close) - low;
}
