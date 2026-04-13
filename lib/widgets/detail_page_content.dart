import 'package:flutter/material.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
import 'detail_page_analysis_helpers.dart';
import 'oi_price_analysis_card.dart';
import 'price_box.dart';
import 'pump_analysis_card.dart';
import 'risk_panel_card.dart';
import 'setup_status_card.dart';
import 'short_setup_card.dart';

class DetailPageContent extends StatelessWidget {
  final String contractName;
  final Widget spinner;
  final String selectedInterval;
  final Future<void> Function(String value) onIntervalChanged;
  final String detailError;
  final bool detailLoading;
  final bool hasData;
  final ShortSetupResult? setupResult;
  final PumpAnalysisResult? pumpAnalysis;
  final EntryTimingResult? entryTiming;
  final List<CandleData> visibleCandles;
  final CoinRadarData selectedCoin;
  final String openInterestDisplay;
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;

  const DetailPageContent({
    super.key,
    required this.contractName,
    required this.spinner,
    required this.selectedInterval,
    required this.onIntervalChanged,
    required this.detailError,
    required this.detailLoading,
    required this.hasData,
    required this.setupResult,
    required this.pumpAnalysis,
    required this.entryTiming,
    required this.visibleCandles,
    required this.selectedCoin,
    required this.openInterestDisplay,
    this.oiDirection = 'FLAT',
    this.priceDirection = 'FLAT',
    this.oiPriceSignal = 'NEUTRAL',
    this.orderFlowDirection = 'NEUTRAL',
  });

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }

  Widget _buildCenterState({
    required Widget child,
  }) {
    return SizedBox(
      height: 420,
      child: Center(child: child),
    );
  }

  Widget _timeframeChip(String value) {
    final bool active = selectedInterval == value;

    return GestureDetector(
      onTap: () async {
        if (selectedInterval == value) return;
        await onIntervalChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? Colors.orangeAccent.withOpacity(0.85)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildWhyCard() {
    final List<String> reasons = setupResult!.reasons.take(4).toList();

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEDEN?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.5),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWaitingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.45),
        ),
      ),
      child: const Text(
        'Detay verisi bekleniyor...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOpenInterestBox() {
    final Color valueColor = DetailPageAnalysisHelpers.getOiColor(
      oiDirection: oiDirection,
      openInterestDisplay: openInterestDisplay,
    );

    final String arrow = DetailPageAnalysisHelpers.getOiArrow(
      oiDirection: oiDirection,
      openInterestDisplay: openInterestDisplay,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'OI (Son 30dk - canlı) ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: arrow,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DetailPageAnalysisHelpers.getOiValue(openInterestDisplay),
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combinedSignal = DetailPageAnalysisHelpers.getCombinedSignal(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlow: orderFlowDirection,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contractName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              spinner,
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _timeframeChip('1h'),
              _timeframeChip('4h'),
              _timeframeChip('8h'),
              _timeframeChip('12h'),
            ],
          ),
          const SizedBox(height: 14),
          if (detailError.isNotEmpty && !hasData)
            _buildCenterState(
              child: _buildErrorBox(detailError),
            )
          else if (detailLoading && !hasData)
            _buildCenterState(
              child: const CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
              ),
            )
          else if (hasData) ...[
            if (detailError.isNotEmpty) ...[
              _buildErrorBox(detailError),
              const SizedBox(height: 14),
            ],
            SetupStatusCard(setup: setupResult!),
            const SizedBox(height: 12),

            OiPriceAnalysisCard(
              oiDirection: oiDirection,
              priceDirection: priceDirection,
              oiPriceSignal: combinedSignal,
              orderFlowDirection: orderFlowDirection,
              openInterestDisplay: openInterestDisplay,
            ),

            const SizedBox(height: 12),
            if (pumpAnalysis != null) ...[
              PumpAnalysisCard(result: pumpAnalysis!),
              const SizedBox(height: 12),
            ],
            ShortSetupCard(
              entry: _formatPrice(setupResult!.entry),
              stopLoss: _formatPrice(setupResult!.stopLoss),
              target1: _formatPrice(setupResult!.target1),
              target2: _formatPrice(setupResult!.target2),
              rr: setupResult!.rr.toStringAsFixed(2),
              riskPercent:
                  '${(((setupResult!.stopLoss - setupResult!.entry) / setupResult!.entry) * 100).toStringAsFixed(2)}%',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: PriceBox(
                    title: 'Son fiyat',
                    value: selectedCoin.lastPriceText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PriceBox(
                    title: 'Mark price',
                    value: selectedCoin.markPriceText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PriceBox(
                    title: 'Index price',
                    value: selectedCoin.indexPriceText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PriceBox(
                    title: 'Funding rate',
                    value: selectedCoin.fundingText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOpenInterestBox(),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            RiskPanelCard(result: setupResult!),
            const SizedBox(height: 18),
            _buildWhyCard(),
          ] else
            _buildCenterState(
              child: _buildWaitingBox(),
            ),
        ],
      ),
    );
  }
}
