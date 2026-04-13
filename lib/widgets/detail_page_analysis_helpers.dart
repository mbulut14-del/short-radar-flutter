import 'package:flutter/material.dart';
import '../services/analysis_engine.dart';

class DetailPageAnalysisHelpers {

  // ===== ENGINE WRAPPER (GEÇİŞ İÇİN)

  static String normalizeDirection(String value) {
    return AnalysisEngine.normalizeDirection(value);
  }

  static String normalizeOrderFlow(String value) {
    return AnalysisEngine.normalizeOrderFlow(value);
  }

  static String getCombinedSignal({
    required String oiDirection,
    required String priceDirection,
    required String orderFlow,
  }) {
    return AnalysisEngine.getCombinedSignal(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlow: orderFlow,
    );
  }

  static double getSignalStrength({
    required String oiDirection,
    required String priceDirection,
    required String orderFlow,
  }) {
    return AnalysisEngine.getSignalStrength(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlow: orderFlow,
    );
  }

  // ===== OI HELPERS

  static String getOiDirection({
    required String oiDirection,
    required String openInterestDisplay,
  }) {
    final String fromParam = normalizeDirection(oiDirection);
    if (fromParam != 'FLAT') return fromParam.toLowerCase();

    final String trimmed = openInterestDisplay.trim();
    if (trimmed.endsWith('↑')) return 'up';
    if (trimmed.endsWith('↓')) return 'down';
    return 'flat';
  }

  static Color getOiColor({
    required String oiDirection,
    required String openInterestDisplay,
  }) {
    switch (getOiDirection(
      oiDirection: oiDirection,
      openInterestDisplay: openInterestDisplay,
    )) {
      case 'up':
        return Colors.greenAccent;
      case 'down':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  static String getOiArrow({
    required String oiDirection,
    required String openInterestDisplay,
  }) {
    switch (getOiDirection(
      oiDirection: oiDirection,
      openInterestDisplay: openInterestDisplay,
    )) {
      case 'up':
        return '▲';
      case 'down':
        return '▼';
      default:
        return '■';
    }
  }

  static String getOiValue(String openInterestDisplay) {
    final List<String> parts = openInterestDisplay.trim().split(' ');
    if (parts.isEmpty) return '-';

    final String last = parts.last;
    if (last == '↑' || last == '↓' || last == '-' || last == '↔️') {
      return parts.sublist(0, parts.length - 1).join(' ').trim();
    }

    return openInterestDisplay.trim();
  }

  static String getPriceDirectionLabel(String priceDirection) {
    switch (normalizeDirection(priceDirection)) {
      case 'UP':
        return '↑ Yükseliyor';
      case 'DOWN':
        return '↓ Düşüyor';
      default:
        return '→ Yatay';
    }
  }

  static Color getPriceDirectionColor(String priceDirection) {
    switch (normalizeDirection(priceDirection)) {
      case 'UP':
        return Colors.greenAccent;
      case 'DOWN':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  static String getOrderFlowLabel(String orderFlowDirection) {
    switch (normalizeOrderFlow(orderFlowDirection)) {
      case 'BUY_PRESSURE':
        return '↑ Alış baskısı';
      case 'SELL_PRESSURE':
        return '↓ Satış baskısı';
      default:
        return '→ Nötr';
    }
  }

  static Color getOrderFlowColor(String orderFlowDirection) {
    switch (normalizeOrderFlow(orderFlowDirection)) {
      case 'BUY_PRESSURE':
        return Colors.greenAccent;
      case 'SELL_PRESSURE':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  static String getSignalTitle(String oiPriceSignal) {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return 'Güçlü Short Baskısı';
      case 'PUMP_RISK':
        return 'Fake Pump Riski';
      case 'SHORT_SQUEEZE':
        return 'Short Squeeze Riski';
      case 'WEAK_DROP':
        return 'Zayıf Hareket';
      case 'EARLY_ACCUMULATION':
        return 'Erken Toplanma';
      case 'EARLY_DISTRIBUTION':
        return 'Erken Dağılım';
      default:
        return 'Kararsız / Nötr';
    }
  }

  static String getSignalDescription(String oiPriceSignal) {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return 'OI artarken fiyat düşüyor. Satış baskısı güçleniyor olabilir.';
      case 'PUMP_RISK':
        return 'OI ve fiyat birlikte yükseliyor. Hareket tuzak pump olabilir.';
      case 'SHORT_SQUEEZE':
        return 'OI düşerken fiyat yükseliyor. Short kapanışları fiyatı yukarı itiyor olabilir.';
      case 'WEAK_DROP':
        return 'OI ve fiyat birlikte düşüyor. Hareket var ama baskı zayıf olabilir.';
      case 'EARLY_ACCUMULATION':
        return 'OI ve fiyat yatay kalırken alış baskısı öne çıkıyor.';
      case 'EARLY_DISTRIBUTION':
        return 'OI ve fiyat yatay kalırken satış baskısı öne çıkıyor.';
      default:
        return 'Şu an net bir baskı veya güçlü fırsat görünmüyor.';
    }
  }

  static Color getSignalColor(String oiPriceSignal) {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return Colors.redAccent;
      case 'PUMP_RISK':
        return Colors.orangeAccent;
      case 'SHORT_SQUEEZE':
        return Colors.purpleAccent;
      case 'WEAK_DROP':
        return Colors.amberAccent;
      case 'EARLY_ACCUMULATION':
        return Colors.greenAccent;
      case 'EARLY_DISTRIBUTION':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  static IconData getSignalIcon(String oiPriceSignal) {
    switch (oiPriceSignal.toUpperCase()) {
      case 'STRONG_SHORT':
        return Icons.south_rounded;
      case 'PUMP_RISK':
        return Icons.warning_amber_rounded;
      case 'SHORT_SQUEEZE':
        return Icons.north_rounded;
      case 'WEAK_DROP':
        return Icons.trending_down_rounded;
      case 'EARLY_ACCUMULATION':
        return Icons.north_east_rounded;
      case 'EARLY_DISTRIBUTION':
        return Icons.south_east_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  // ===== UI (KORUNDU)

  static Widget buildOiPriceAnalysisCard({
    required String oiDirection,
    required String priceDirection,
    required String orderFlowDirection,
    required String openInterestDisplay,
  }) {

    final String signal = getCombinedSignal(
      oiDirection: oiDirection,
      priceDirection: priceDirection,
      orderFlow: orderFlowDirection,
    );

    final Color signalColor = getSignalColor(signal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: signalColor.withOpacity(0.55), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getSignalTitle(signal),
            style: TextStyle(
              color: signalColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            getSignalDescription(signal),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
