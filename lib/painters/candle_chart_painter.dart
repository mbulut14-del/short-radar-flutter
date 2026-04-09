import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/candle_data.dart';

class CandleChartPainter extends CustomPainter {
  final List<CandleData> candles;

  CandleChartPainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final double maxPrice = candles.map((e) => e.high).reduce(math.max);
    final double minPrice = candles.map((e) => e.low).reduce(math.min);
    final double priceRange = math.max(maxPrice - minPrice, 0.0000001);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 5; i++) {
      final double x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final int visibleCount = candles.length;
    final double candleSpace = size.width / visibleCount;
    final double bodyWidth = math.max(candleSpace * 0.62, 2.2);

    for (int i = 0; i < visibleCount; i++) {
      final CandleData candle = candles[i];
      final double centerX = (i * candleSpace) + candleSpace / 2;

      final double highY =
          (1 - ((candle.high - minPrice) / priceRange)) * size.height;
      final double lowY =
          (1 - ((candle.low - minPrice) / priceRange)) * size.height;
      final double openY =
          (1 - ((candle.open - minPrice) / priceRange)) * size.height;
      final double closeY =
          (1 - ((candle.close - minPrice) / priceRange)) * size.height;

      final bool bullish = candle.isBullish;
      final Color candleColor =
          bullish ? const Color(0xFF37E39C) : const Color(0xFFFF5C73);

      final Paint wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.2;

      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, lowY),
        wickPaint,
      );

      final double rectTop = math.min(openY, closeY);
      final double rectBottom = math.max(openY, closeY);

      final Rect bodyRect = Rect.fromLTWH(
        centerX - bodyWidth / 2,
        rectTop,
        bodyWidth,
        math.max(rectBottom - rectTop, 1.4),
      );

      final Paint bodyPaint = Paint()..color = candleColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(1.8)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}
