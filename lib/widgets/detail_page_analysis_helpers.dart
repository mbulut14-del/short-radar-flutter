import 'package:flutter/material.dart';

class DetailPageAnalysisHelpers {
  static String normalizeDirection(String value) {
    final String v = value.trim().toUpperCase();

    if (v == 'UP') return 'UP';
    if (v == 'DOWN') return 'DOWN';
    return 'FLAT';
  }

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
    switch (
        getOiDirection(
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
    switch (
        getOiDirection(
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
      default:
        return Icons.remove_rounded;
    }
  }

  static String getOiDirectionLabel({
    required String oiDirection,
    required String openInterestDisplay,
  }) {
    switch (
        getOiDirection(
          oiDirection: oiDirection,
          openInterestDisplay: openInterestDisplay,
        )) {
      case 'up':
        return '↑ Artıyor';
      case 'down':
        return '↓ Düşüyor';
      default:
        return '→ Yatay';
    }
  }

  static Widget buildMiniBadge({
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

  static Widget buildOpenInterestBox({
    required String oiDirection,
    required String openInterestDisplay,
  }) {
    final Color valueColor = getOiColor(
      oiDirection: oiDirection,
      openInterestDisplay: openInterestDisplay,
    );

    final String arrow = getOiArrow(
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
            getOiValue(openInterestDisplay),
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

  static Widget buildOiPriceAnalysisCard({
    required String oiDirection,
    required String priceDirection,
    required String oiPriceSignal,
    required String openInterestDisplay,
  }) {
    final Color signalColor = getSignalColor(oiPriceSignal);

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
                getSignalIcon(oiPriceSignal),
                color: signalColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  getSignalTitle(oiPriceSignal),
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
            getSignalDescription(oiPriceSignal),
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
              buildMiniBadge(
                label: 'OI Yönü',
                value: getOiDirectionLabel(
                  oiDirection: oiDirection,
                  openInterestDisplay: openInterestDisplay,
                ),
                valueColor: getOiColor(
                  oiDirection: oiDirection,
                  openInterestDisplay: openInterestDisplay,
                ),
              ),
              buildMiniBadge(
                label: 'Fiyat Yönü',
                value: getPriceDirectionLabel(priceDirection),
                valueColor: getPriceDirectionColor(priceDirection),
              ),
              buildMiniBadge(
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
}
