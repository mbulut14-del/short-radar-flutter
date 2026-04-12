import 'package:flutter/material.dart';

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_result.dart';
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

  // ✅ HomePage'den gelen canlı yön/sinyal verileri
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;

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
  });

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
  }

  String _normalizeDirection(String value) {
    final String v = value.trim().toUpperCase();

    if (v == 'UP') return 'UP';
    if (v == 'DOWN') return 'DOWN';
    return 'FLAT';
  }

  String _getOiDirection() {
    final String fromParam = _normalizeDirection(oiDirection);
    if (fromParam != 'FLAT') return fromParam.toLowerCase();

    final String trimmed = openInterestDisplay.trim();
    if (trimmed.endsWith('↑')) return 'up';
    if (trimmed.endsWith('↓')) return 'down';
    return 'flat';
  }

  Color _getOiColor() {
    switch (_getOiDirection()) {
      case 'up':
        return Colors.greenAccent;
      case 'down':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  String _getOiArrow() {
    switch (_getOiDirection()) {
      case 'up':
        return '▲';
      case 'down':
        return '▼';
      default:
        return '■';
    }
  }

  String _getOiValue() {
    final List<String> parts = openInterestDisplay.trim().split(' ');
    if (parts.isEmpty) return '-';

    final String last = parts.last;
    if (last == '↑' || last == '↓' || last == '-' || last == '↔️') {
      return parts.sublist(0, parts.length - 1).join(' ').trim();
    }

    return openInterestDisplay.trim();
  }

  String _getPriceDirectionLabel() {
    switch (_normalizeDirection(priceDirection)) {
      case 'UP':
        return '↑ Yükseliyor';
      case 'DOWN':
        return '↓ Düşüyor';
      default:
        return '→ Yatay';
    }
  }

  Color _getPriceDirectionColor() {
    switch (_normalizeDirection(priceDirection)) {
      case 'UP':
        return Colors.greenAccent;
      case 'DOWN':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  String _getSignalTitle() {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return 'Güçlü Short Baskısı';
      case 'PUMP_RISK':
        return 'Fake Pump Riski';
      case 'SHORT_SQUEEZE':
        return 'Short Squeeze Riski';
      case 'WEAK_DROP':
        return 'Zayıf Hareket';
      default:
        return 'Kararsız / Nötr';
    }
  }

  String _getSignalDescription() {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return 'OI artarken fiyat düşüyor. Satış baskısı güçleniyor olabilir.';
      case 'PUMP_RISK':
        return 'OI ve fiyat birlikte yükseliyor. Hareket tuzak pump olabilir.';
      case 'SHORT_SQUEEZE':
        return 'OI düşerken fiyat yükseliyor. Short kapanışları fiyatı yukarı itiyor olabilir.';
      case 'WEAK_DROP':
        return 'OI ve fiyat birlikte düşüyor. Hareket var ama baskı zayıf olabilir.';
      default:
        return 'Şu an net bir baskı veya güçlü fırsat görünmüyor.';
    }
  }

  Color _getSignalColor() {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return Colors.redAccent;
      case 'PUMP_RISK':
        return Colors.orangeAccent;
      case 'SHORT_SQUEEZE':
        return Colors.purpleAccent;
      case 'WEAK_DROP':
        return Colors.amberAccent;
      default:
        return Colors.white70;
    }
  }

  IconData _getSignalIcon() {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return Icons.south_rounded;
      case 'PUMP_RISK':
        return Icons.warning_amber_rounded;
      case 'SHORT_SQUEEZE':
        return Icons.north_rounded;
      case 'WEAK_DROP':
        return Icons.trending_down_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  String _getOiDirectionLabel() {
    switch (_getOiDirection()) {
      case 'up':
        return '↑ Artıyor';
      case 'down':
        return '↓ Düşüyor';
      default:
        return '→ Yatay';
    }
  }

  Widget _buildOpenInterestBox() {
    final Color valueColor = _getOiColor();
    final String arrow = _getOiArrow();

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
            _getOiValue(),
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

  Widget _buildOiPriceAnalysisCard() {
    final Color signalColor = _getSignalColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: signalColor.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: signalColor.withOpacity(0.10),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OI + Fiyat Analizi',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _getSignalIcon(),
                color: signalColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getSignalTitle(),
                  style: TextStyle(
                    color: signalColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getSignalDescription(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniBadge(
                label: 'OI Yönü',
                value: _getOiDirectionLabel(),
                valueColor: _getOiColor(),
              ),
              _buildMiniBadge(
                label: 'Fiyat Yönü',
                value: _getPriceDirectionLabel(),
                valueColor: _getPriceDirectionColor(),
              ),
              _buildMiniBadge(
                label: 'Sinyal',
                value: oiPriceSignal.toUpperCase(),
                valueColor: signalColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
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
              child: Container(
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
                  detailError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
            SetupStatusCard(setup: setupResult!),
            const SizedBox(height: 12),

            // ✅ ANA KARAR KARTI ÖNE ALINDI
            _buildOiPriceAnalysisCard(),
            const SizedBox(height: 12),

            // ✅ Pump analizi artık destek kartı
            if (pumpAnalysis != null) ...[
              PumpAnalysisCard(result: pumpAnalysis!),
              const SizedBox(height: 12),
            ],

            // ✅ Giriş zamanı kartı kaldırıldı

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
              child: Container(
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
              ),
            ),
        ],
      ),
    );
  }
}
