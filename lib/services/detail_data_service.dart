import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/candle_data.dart';
import '../models/coin_radar_data.dart';
import '../models/entry_timing.dart';
import '../models/entry_timing_result.dart';
import '../models/pump_analysis.dart';
import '../models/pump_analysis_result.dart';
import '../models/short_setup_logic.dart';
import '../models/short_setup_result.dart';

class DetailDataBundle {
  final CoinRadarData selectedCoin;
  final List<CandleData> candles;
  final List<CandleData> visibleCandles;
  final ShortSetupResult setupResult;
  final PumpAnalysisResult pumpAnalysis;
  final EntryTimingResult entryTiming;

  const DetailDataBundle({
    required this.selectedCoin,
    required this.candles,
    required this.visibleCandles,
    required this.setupResult,
    required this.pumpAnalysis,
    required this.entryTiming,
  });
}

class DetailDataService {
  static final Map<String, DetailDataBundle> _lastValidDataMap = {};

  static String apiInterval(String value) {
    switch (value) {
      case '12h':
        return '1d';
      default:
        return value;
    }
  }

  static String _cacheKey({
    required String contractName,
    required String selectedInterval,
  }) {
    return '$contractName|$selectedInterval';
  }

  static double _bodySize(CandleData candle) {
    return (candle.close - candle.open).abs();
  }

  static double _rangeSize(CandleData candle) {
    return (candle.high - candle.low).abs();
  }

  static double _upperWickSize(CandleData candle) {
    final double bodyTop =
        candle.close >= candle.open ? candle.close : candle.open;
    return candle.high - bodyTop;
  }

  static double _safeVolume(CandleData candle) {
    return candle.volume < 0 ? 0 : candle.volume;
  }

  static bool _hasUpperWickRejection(List<CandleData> candles) {
    if (candles.isEmpty) return false;

    final CandleData last = candles.last;
    final double range = _rangeSize(last);
    if (range <= 0) return false;

    final double upperWickRatio = _upperWickSize(last) / range;
    final bool weakClose = last.close <= (last.low + range * 0.60);

    return upperWickRatio >= 0.35 && weakClose;
  }

  static bool _hasFailedBreakout(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];

    final double recentHigh =
        [prev.high, prev2.high].reduce((a, b) => a > b ? a : b);

    final bool madeNewHigh = last.high > recentHigh;
    final bool weakClose = last.close < last.high;
    final bool lostMomentum = _bodySize(last) < _bodySize(prev);

    return madeNewHigh && weakClose && lostMomentum;
  }

  static bool _hasShrinkingBodyWithRisingVolume(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];

    final double lastBody = _bodySize(last);
    final double prevBody = _bodySize(prev);

    final double lastVolume = _safeVolume(last);
    final double avgPrevVolume = (_safeVolume(prev) + _safeVolume(prev2)) / 2;

    final bool bodyShrinking = prevBody > 0 && lastBody < prevBody * 0.85;
    final bool volumeRising =
        avgPrevVolume > 0 && lastVolume > avgPrevVolume * 1.10;

    return bodyShrinking && volumeRising;
  }

  static bool _hasPreviousLowBreakdown(List<CandleData> candles) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];

    final double triggerLow = prev.low < prev2.low ? prev.low : prev2.low;

    return last.close < triggerLow;
  }

  static bool _hasLowerHigh(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    return last.high < prev.high;
  }

  static bool _hasTwoWeakCloses(List<CandleData> candles) {
    if (candles.length < 3) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];

    return last.close < last.open && prev.close < prev.open;
  }

  static bool _hasOiPriceExhaustion(
    List<CandleData> candles,
    CoinRadarData coin,
  ) {
    if (candles.length < 4) return false;

    final CandleData last = candles[candles.length - 1];
    final CandleData prev = candles[candles.length - 2];
    final CandleData prev2 = candles[candles.length - 3];

    final double currentPrice = coin.lastPrice;
    final double markPrice = coin.markPrice;
    final double indexPrice = coin.indexPrice;
    final double openInterest = coin.openInterest;

    final bool priceExtended =
        currentPrice > 0 &&
        prev2.close > 0 &&
        currentPrice > prev2.close * 1.08;

    final bool bodyShrinking =
        _bodySize(prev) > 0 && _bodySize(last) < _bodySize(prev) * 0.85;

    final bool weakContinuation =
        last.close <= prev.close && last.high >= prev.high;

    final bool markIndexGapWide = markPrice > 0 &&
        indexPrice > 0 &&
        ((markPrice - indexPrice).abs() / indexPrice) >= 0.0025;

    final bool oiMeaningful = openInterest > 0;

    return oiMeaningful &&
        priceExtended &&
        bodyShrinking &&
        weakContinuation &&
        markIndexGapWide;
  }

  static int _marketWeaknessScore(
    List<CandleData> candles,
    CoinRadarData coin,
  ) {
    int score = 0;

    if (_hasUpperWickRejection(candles)) score += 2;
    if (_hasFailedBreakout(candles)) score += 2;
    if (_hasShrinkingBodyWithRisingVolume(candles)) score += 2;
    if (_hasPreviousLowBreakdown(candles)) score += 3;
    if (_hasLowerHigh(candles)) score += 1;
    if (_hasTwoWeakCloses(candles)) score += 2;
    if (_hasOiPriceExhaustion(candles, coin)) score += 2;

    return score;
  }

  static List<CandleData> _selectAnalysisCandles(
    List<CandleData> candles,
    CoinRadarData coin,
  ) {
    if (candles.length <= 18) return candles;

    final int weaknessScore = _marketWeaknessScore(candles, coin);

    int analysisWindow = 40;

    if (weaknessScore >= 8) {
      analysisWindow = 18;
    } else if (weaknessScore >= 5) {
      analysisWindow = 24;
    } else if (weaknessScore >= 3) {
      analysisWindow = 30;
    } else {
      analysisWindow = 40;
    }

    if (candles.length <= analysisWindow) return candles;
    return candles.sublist(candles.length - analysisWindow);
  }

  static List<CandleData> _buildFallbackCandles(CoinRadarData coin) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final double basePrice = coin.lastPrice > 0 ? coin.lastPrice : 1.0;
    final double high = coin.markPrice > 0 ? coin.markPrice : basePrice;
    final double low = coin.indexPrice > 0
        ? coin.indexPrice < basePrice
            ? coin.indexPrice
            : basePrice * 0.995
        : basePrice * 0.995;

    return <CandleData>[
      CandleData(
        timestamp: now - 900,
        open: basePrice,
        high: high,
        low: low,
        close: basePrice,
        volume: coin.volume24h > 0 ? coin.volume24h : 0,
      ),
      CandleData(
        timestamp: now - 600,
        open: basePrice,
        high: high,
        low: low,
        close: basePrice,
        volume: coin.volume24h > 0 ? coin.volume24h : 0,
      ),
      CandleData(
        timestamp: now - 300,
        open: basePrice,
        high: high,
        low: low,
        close: basePrice,
        volume: coin.volume24h > 0 ? coin.volume24h : 0,
      ),
      CandleData(
        timestamp: now,
        open: basePrice,
        high: high,
        low: low,
        close: basePrice,
        volume: coin.volume24h > 0 ? coin.volume24h : 0,
      ),
    ];
  }

  static DetailDataBundle _buildSafeFallbackBundle(CoinRadarData fallbackCoin) {
    final List<CandleData> fallbackCandles = _buildFallbackCandles(fallbackCoin);

    final ShortSetupResult fallbackSetup = ShortSetupLogic.build(
      candles: fallbackCandles,
      coin: fallbackCoin,
    );

    final PumpAnalysisResult fallbackPump =
        PumpAnalysis.analyze(fallbackCandles);

    final EntryTimingResult fallbackEntry =
        EntryTiming.analyze(fallbackCandles);

    return DetailDataBundle(
      selectedCoin: fallbackCoin,
      candles: fallbackCandles,
      visibleCandles: fallbackCandles,
      setupResult: fallbackSetup,
      pumpAnalysis: fallbackPump,
      entryTiming: fallbackEntry,
    );
  }

  static Future<DetailDataBundle> load({
    required String contractName,
    required String selectedInterval,
    required CoinRadarData fallbackCoin,
  }) async {
    final String cacheKey = _cacheKey(
      contractName: contractName,
      selectedInterval: selectedInterval,
    );

    try {
      final tickerUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers',
      );

      final candlesUri = Uri.parse(
        'https://fx-api.gateio.ws/api/v4/futures/usdt/candlesticks'
        '?contract=${Uri.encodeQueryComponent(contractName)}'
        '&interval=${Uri.encodeQueryComponent(apiInterval(selectedInterval))}'
        '&limit=120',
      );

      final responses = await Future.wait([
        http.get(
          tickerUri,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10)),
        http.get(
          candlesUri,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10)),
      ]);

      final tickerResponse = responses[0];
      final candleResponse = responses[1];

      if (tickerResponse.statusCode != 200 || candleResponse.statusCode != 200) {
        throw Exception('Detay verisi alınamadı');
      }

      final dynamic parsedTicker = json.decode(tickerResponse.body);
      final dynamic parsedCandles = json.decode(candleResponse.body);

      if (parsedTicker is! List || parsedCandles is! List) {
        throw Exception('API veri formatı beklenen gibi değil');
      }

      final List<CoinRadarData> allCoins = parsedTicker
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      CoinRadarData? detailItem;
      for (final coin in allCoins) {
        if (coin.name == contractName) {
          detailItem = coin;
          break;
        }
      }

      detailItem ??= fallbackCoin;

      final List<CandleData> newCandles = [];
      for (final raw in parsedCandles) {
        try {
          newCandles.add(CandleData.fromApi(raw));
        } catch (_) {}
      }

      newCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (newCandles.isEmpty) {
        throw Exception('Grafik verisi bulunamadı');
      }

      final List<CandleData> zoomCandles = newCandles.length > 40
          ? newCandles.sublist(newCandles.length - 40)
          : newCandles;

      final List<CandleData> analysisCandles =
          _selectAnalysisCandles(newCandles, detailItem);

      final ShortSetupResult newSetup = ShortSetupLogic.build(
        candles: analysisCandles,
        coin: detailItem,
      );

      final PumpAnalysisResult newPumpAnalysis =
          PumpAnalysis.analyze(analysisCandles);

      final EntryTimingResult newEntryTiming =
          EntryTiming.analyze(analysisCandles);

      final DetailDataBundle bundle = DetailDataBundle(
        selectedCoin: detailItem,
        candles: newCandles,
        visibleCandles: zoomCandles,
        setupResult: newSetup,
        pumpAnalysis: newPumpAnalysis,
        entryTiming: newEntryTiming,
      );

      _lastValidDataMap[cacheKey] = bundle;
      return bundle;
    } catch (e) {
      debugPrint('DETAIL DATA ERROR [$contractName][$selectedInterval]: $e');

      final DetailDataBundle? cachedBundle = _lastValidDataMap[cacheKey];
      if (cachedBundle != null) {
        return cachedBundle;
      }

      return _buildSafeFallbackBundle(fallbackCoin);
    }
  }
}
