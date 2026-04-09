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

  factory CandleData.fromApi(dynamic raw) {
    if (raw is List) {
      return CandleData(
        timestamp: int.tryParse(raw.isNotEmpty ? raw[0].toString() : '0') ?? 0,
        volume: _parseDouble(raw.length > 1 ? raw[1] : 0),
        close: _parseDouble(raw.length > 2 ? raw[2] : 0),
        high: _parseDouble(raw.length > 3 ? raw[3] : 0),
        low: _parseDouble(raw.length > 4 ? raw[4] : 0),
        open: _parseDouble(raw.length > 5 ? raw[5] : 0),
      );
    }

    if (raw is Map) {
      return CandleData(
        timestamp:
            int.tryParse((raw['t'] ?? raw['timestamp'] ?? 0).toString()) ?? 0,
        volume: _parseDouble(raw['v'] ?? raw['volume']),
        close: _parseDouble(raw['c'] ?? raw['close']),
        high: _parseDouble(raw['h'] ?? raw['high']),
        low: _parseDouble(raw['l'] ?? raw['low']),
        open: _parseDouble(raw['o'] ?? raw['open']),
      );
    }

    throw const FormatException('Unsupported candle format');
  }

  factory CandleData.fromJson(dynamic raw) {
    return CandleData.fromApi(raw);
  }

  bool get isBullish => close >= open;
  double get bodySize => (close - open).abs();
  double get range => (high - low).abs();
  double get upperWick => high - math.max(open, close);
  double get lowerWick => math.min(open, close) - low;
}
