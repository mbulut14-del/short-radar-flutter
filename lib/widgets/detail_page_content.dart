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
import 'short_setup_card.dart';

class DetailPageContent extends StatelessWidget {
  final String contractName;
  final Widget spinner;
  final String selectedInterval;
  final Future Function(String value) onIntervalChanged;
  final String detailError;
  final bool detailLoading;
  final bool hasData;

  final ShortSetupResult? setupResult;
  final PumpAnalysisResult? pumpAnalysis;
  final EntryTimingResult? entryTiming;
  final List visibleCandles;
  final CoinRadarData selectedCoin;

  final String openInterestDisplay;
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;

  final double? finalScore;
  final String? finalScoreLabel;
  final String? finalScoreSummary;

  final double? decisionConfidence;
  final String? decisionPrimarySignal;
  final String? decisionTradeBias;
  final String? decisionAction;

  final double? oiComponentScore;
  final double? priceComponentScore;
  final double? orderFlowComponentScore;
  final double? volumeComponentScore;
  final double? liquidationComponentScore;
  final double? momentumComponentScore;

  final List? marketReadBullets;
  final List? entryNotes;
  final List? warnings;
  final List? triggerConditions;

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
    this.finalScore,
    this.finalScoreLabel,
    this.finalScoreSummary,
    this.decisionConfidence,
    this.decisionPrimarySignal,
    this.decisionTradeBias,
    this.decisionAction,
    this.oiComponentScore,
    this.priceComponentScore,
    this.orderFlowComponentScore,
    this.volumeComponentScore,
    this.liquidationComponentScore,
    this.momentumComponentScore,
    this.marketReadBullets,
    this.entryNotes,
    this.warnings,
    this.triggerConditions,
  });

  String _formatPrice(double value, {int digits = 6}) {
    if (value == 0) return '-';
    return value.toStringAsFixed(digits);
  }

  Widget _cardShell({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
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
          color: active ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.orangeAccent.withOpacity(0.85) : Colors.white.withOpacity(0.12),
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

  Color _getFinalScoreColor(double score) {
    if (score >= 85) return Colors.greenAccent;
    if (score >= 70) return Colors.lightGreenAccent;
    if (score >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getFinalScoreHint(double score) {
    if (score >= 85) {
      return 'Güçlü short fırsatı var. Sistem sadece durumu gösterir, karar kullanıcıya aittir.';
    }

    if (score >= 70) {
      return 'Short kurulumu oluşuyor. Büyük kırmızı mum başlangıcı veya satış devamı takip edilmeli.';
    }

    if (score >= 40) {
      return 'Erken short işaretleri var. Tepe zayıflaması takip edilmeli.';
    }

    return 'Net short fırsatı yok. Şimdilik bekle.';
  }

  bool _shouldShowShortSetupCard() {
    if (setupResult == null) return false;
    if (decisionAction == null) return finalScore != null && finalScore! >= 70;

    final String action = _normalizeAction(decisionAction!);
    return action == 'Short hazırlığı' || action == 'Short giriş';
  }

  bool _shouldShowWhyCard() {
    if (setupResult == null) return false;
    if (setupResult!.reasons.isEmpty) return false;
    if (finalScore == null) return true;
    return finalScore! >= 40;
  }

  bool _shouldShowTriggerWaitCard() {
    final String action = _normalizeAction(decisionAction ?? '');
    return action == 'Short hazırlığı';
  }

  bool _hasDecisionMeta() {
    return decisionConfidence != null ||
        decisionPrimarySignal != null ||
        decisionTradeBias != null ||
        decisionAction != null;
  }

  bool _hasComponentScores() {
    return oiComponentScore != null ||
        priceComponentScore != null ||
        orderFlowComponentScore != null ||
        volumeComponentScore != null ||
        liquidationComponentScore != null ||
        momentumComponentScore != null;
  }

  bool _hasMarketRead() {
    return marketReadBullets != null && marketReadBullets!.isNotEmpty;
  }

  bool _hasEntryNotes() {
    return entryNotes != null && entryNotes!.isNotEmpty;
  }

  bool _hasWarnings() {
    return warnings != null && warnings!.isNotEmpty;
  }

  bool _hasTriggerConditions() {
    return triggerConditions != null && triggerConditions!.isNotEmpty;
  }

  String _getAnalysisSectionTitle() {
    return 'ALT ANALİZLER';
  }

  String _getAnalysisSectionSubtitle() {
    return 'Bu bölüm karar vermek için değil, mevcut piyasa durumunu okumak için gösterilir.';
  }

  String _normalizeSignal(String value) {
    switch (value) {
      case 'STRONG_SHORT':
        return 'Güçlü short';
      case 'FAKE_PUMP':
        return 'Fake pump';
      case 'SHORT_SQUEEZE':
        return 'Short sıkıştırma riski';
      case 'WEAK_DROP':
        return 'Zayıf düşüş';
      case 'EARLY_ACCUMULATION':
        return 'Erken toplama';
      case 'EARLY_DISTRIBUTION':
        return 'Erken dağıtım';
      case 'NEUTRAL':
        return 'Nötr';
      default:
        return value.trim().isEmpty ? 'Nötr' : value;
    }
  }

  String _normalizeBias(String value) {
    switch (value) {
      case 'SHORT':
        return 'Short yönlü';
      case 'NEUTRAL':
        return 'Nötr';
      case 'NO SHORT EDGE':
        return 'Short avantajı yok';
      default:
        return value.trim().isEmpty ? 'Nötr' : value;
    }
  }

  String _normalizeAction(String value) {
    switch (value) {
      case 'ENTER SHORT':
        return 'Short giriş';
      case 'PREPARE SHORT':
        return 'Short hazırlığı';
      case 'WATCH':
        return 'Bekle';
      case 'NO TRADE':
        return 'İşlem yok';
      default:
        return value.trim().isEmpty ? 'Bekle' : value;
    }
  }

  Color _getBiasColor(String value) {
    final String text = _normalizeBias(value);
    if (text == 'Short yönlü') return Colors.redAccent;
    if
