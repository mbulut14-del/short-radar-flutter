
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/candle_data.dart';
import '../models/short_setup_result.dart';

class CandleChartWidget extends StatefulWidget {
  final List<CandleData> candles;
  final ShortSetupResult? setupResult;

  const CandleChartWidget({
    super.key,
    required this.candles,
    required this.setupResult,
  });

  @override
  State<CandleChartWidget> createState() => _CandleChartWidgetState();
}

class _CandleChartWidgetState extends State<CandleChartWidget> {
  late TrackballBehavior _trackballBehavior;

  @override
  void initState() {
    super.initState();

    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      lineType: TrackballLineType.vertical,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        color: Colors.black87,
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
  }

  @override
  Widget build(BuildContext context) {
    final List<_ChartCandle> chartData = widget.candles
        .map(
          (c) => _ChartCandle(
            time: DateTime.fromMillisecondsSinceEpoch(
              c.timestamp * 1000,
              isUtc: true,
            ).toLocal(),
            open: c.open,
            high: c.high,
            low: c.low,
            close: c.close,
          ),
        )
        .toList();

    final double? lastPrice =
        chartData.isNotEmpty ? chartData.last.close : null;

    final List<PlotBand> plotBands = widget.setupResult == null
        ? []
        : [
            PlotBand(
              isVisible: true,
              start: widget.setupResult!.entry,
              end: widget.setupResult!.entry,
              borderWidth: 1.2,
              borderColor: Colors.blueAccent.withOpacity(0.95),
              dashArray: const <double>[6, 4],
            ),
            PlotBand(
              isVisible: true,
              start: widget.setupResult!.stopLoss,
              end: widget.setupResult!.stopLoss,
              borderWidth: 1.2,
              borderColor: Colors.redAccent.withOpacity(0.95),
              dashArray: const <double>[6, 4],
            ),
            PlotBand(
              isVisible: true,
              start: widget.setupResult!.target1,
              end: widget.setupResult!.target1,
              borderWidth: 1.2,
              borderColor: Colors.greenAccent.withOpacity(0.95),
              dashArray: const <double>[6, 4],
            ),
            PlotBand(
              isVisible: true,
              start: widget.setupResult!.target2,
              end: widget.setupResult!.target2,
              borderWidth: 1.2,
              borderColor: Colors.greenAccent.withOpacity(0.95),
              dashArray: const <double>[6, 4],
            ),
          ];

    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.35),
        ),
      ),
      child: Stack(
        children: [
          SfCartesianChart(
            plotAreaBorderWidth: 0,
            margin: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            trackballBehavior: _trackballBehavior,
            primaryXAxis: DateTimeAxis(
              majorGridLines: MajorGridLines(
                width: 0.6,
                color: Colors.white.withOpacity(0.06),
              ),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
              ),
              intervalType: DateTimeIntervalType.auto,
            ),
            primaryYAxis: NumericAxis(
              opposedPosition: true,
              decimalPlaces: 6,
              majorGridLines: MajorGridLines(
                width: 0.6,
                color: Colors.white.withOpacity(0.08),
              ),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 10,
              ),
              numberFormat: null,
              plotBands: plotBands,
            ),
            series: <CartesianSeries<_ChartCandle, DateTime>>[
              CandleSeries<_ChartCandle, DateTime>(
                dataSource: chartData,
                xValueMapper: (_ChartCandle data, _) => data.time,
                lowValueMapper: (_ChartCandle data, _) => data.low,
                highValueMapper: (_ChartCandle data, _) => data.high,
                openValueMapper: (_ChartCandle data, _) => data.open,
                closeValueMapper: (_ChartCandle data, _) => data.close,
                bearColor: Colors.redAccent,
                bullColor: Colors.greenAccent,
                enableSolidCandles: true,
                spacing: 0.12,
              ),
            ],
          ),
          if (lastPrice != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _formatPrice(lastPrice),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartCandle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  _ChartCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}
