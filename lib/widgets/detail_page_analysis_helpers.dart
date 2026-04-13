import 'package:flutter/material.dart';
import '../services/analysis_engine.dart';

class DetailPageAnalysisHelpers {
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
        return 'OI ve fiyat yatay kalırken alış baskısı öne çıkıyor. Erken bir birikim olabilir.';
      case 'EARLY_DISTRIBUTION':
        return 'OI ve fiyat yatay kalırken satış baskısı öne çıkıyor. Erken bir dağılım olabilir.';
      default:
        return 'Şu an net bir baskı veya güçlü fırsat görünmüyor.';
    }
  }

  static String getMarketStateTitle({
    required String oiPriceSignal,
    required String orderFlowDirection,
  }) {
    final String signal = oiPriceSignal.toUpperCase();
    final String flow = normalizeOrderFlow(orderFlowDirection);

    if (signal == 'STRONG_SHORT' && flow == 'SELL_PRESSURE') {
      return 'Satış baskısı destekleniyor';
    }
    if (signal == 'STRONG_SHORT' && flow == 'BUY_PRESSURE') {
      return 'Karşı alım tepkisi var';
    }
    if (signal == 'PUMP_RISK' && flow == 'SELL_PRESSURE') {
      return 'Yukarı hareket şüpheli';
    }
    if (signal == 'PUMP_RISK' && flow == 'BUY_PRESSURE') {
      return 'Yukarı hareket destek buluyor';
    }
    if (signal == 'SHORT_SQUEEZE' && flow == 'BUY_PRESSURE') {
      return 'Yukarı baskı destekleniyor';
    }
    if (signal == 'SHORT_SQUEEZE' && flow == 'SELL_PRESSURE') {
      return 'Squeeze zayıflıyor olabilir';
    }
    if (signal == 'WEAK_DROP' && flow == 'SELL_PRESSURE') {
      return 'Düşüş var ama sınırlı';
    }
    if (signal == 'WEAK_DROP' && flow == 'BUY_PRESSURE') {
      return 'Düşüşe tepki geliyor';
    }
    if (signal == 'EARLY_ACCUMULATION') {
      return 'Erken birikim sinyali';
    }
    if (signal == 'EARLY_DISTRIBUTION') {
      return 'Erken dağılım sinyali';
    }
    if (flow == 'SELL_PRESSURE') {
      return 'Satış tarafı önde';
    }
    if (flow == 'BUY_PRESSURE') {
      return 'Alış tarafı önde';
    }
    return 'Net baskı yok';
  }

  static String getMarketStateDescription({
    required String oiPriceSignal,
    required String orderFlowDirection,
  }) {
    final String signal = oiPriceSignal.toUpperCase();
    final String flow = normalizeOrderFlow(orderFlowDirection);

    if (signal == 'STRONG_SHORT' && flow == 'SELL_PRESSURE') {
      return 'OI ve fiyat short yönünde hizalanırken emir akışında da satış tarafı daha baskın görünüyor.';
    }
    if (signal == 'STRONG_SHORT' && flow == 'BUY_PRESSURE') {
      return 'Short baskısı sinyali var ancak emir akışında alıcılar karşılık veriyor. Baskı tek yönlü değil.';
    }
    if (signal == 'PUMP_RISK' && flow == 'SELL_PRESSURE') {
      return 'Fiyat yükselse de emir akışı satış tarafına yaslanıyor. Yukarı hareket zayıflayabilir.';
    }
    if (signal == 'PUMP_RISK' && flow == 'BUY_PRESSURE') {
      return 'Yukarı hareket emir akışından destek görüyor. Buna rağmen OI artışı nedeniyle yapı temkinli izlenmeli.';
    }
    if (signal == 'SHORT_SQUEEZE' && flow == 'BUY_PRESSURE') {
      return 'Fiyat yukarı itilirken alım tarafı da baskın. Sıkışma etkisi daha görünür olabilir.';
    }
    if (signal == 'SHORT_SQUEEZE' && flow == 'SELL_PRESSURE') {
      return 'Squeeze sinyali var ama emir akışı bunu tam desteklemiyor. Hareket gücü sınırlı kalabilir.';
    }
    if (signal == 'WEAK_DROP' && flow == 'SELL_PRESSURE') {
      return 'Aşağı yönlü hareket sürüyor ancak yapı güçlü değil. Satış baskısı var ama kuvveti sınırlı.';
    }
    if (signal == 'WEAK_DROP' && flow == 'BUY_PRESSURE') {
      return 'Düşüş görülse de emir akışında alıcılar devreye giriyor. Hareketin devamı zayıflayabilir.';
    }
    if (signal == 'EARLY_ACCUMULATION') {
      return 'Fiyat ve OI henüz net yön üretmiyor ancak alış tarafı erken üstünlük kuruyor olabilir.';
    }
    if (signal == 'EARLY_DISTRIBUTION') {
      return 'Fiyat ve OI henüz net yön üretmiyor ancak satış tarafı erken üstünlük kuruyor olabilir.';
    }
    if (flow == 'SELL_PRESSURE') {
      return 'Fiyat ve OI tarafı net bir yön üretmese de emir akışında satış tarafı daha baskın görünüyor.';
    }
    if (flow == 'BUY_PRESSURE') {
      return 'Fiyat ve OI tarafı net bir yön üretmese de emir akışında alış tarafı daha baskın görünüyor.';
    }
    return 'Pozisyon akışı ve fiyat ilişkisi net bir baskı üretmiyor. Emir tarafında da belirgin üstünlük görünmüyor.';
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
}
