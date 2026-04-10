
import 'dart:convert';

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
  static String apiInterval(String value) {
    switch (value) {
      case '12h':
        return '1d';
      default:
        return value;
    }
  }

  static Future<DetailDataBundle> load({
    required String contractName,
    required String selectedInterval,
    required CoinRadarData fallbackCoin,
  }) async {
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
      http
          .get(
            tickerUri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10)),
      http
          .get(
            candlesUri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10)),
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

    final ShortSetupResult newSetup = ShortSetupLogic.build(
      candles: zoomCandles,
      coin: detailItem,
    );

    final PumpAnalysisResult newPumpAnalysis =
        PumpAnalysis.analyze(zoomCandles);

    final EntryTimingResult newEntryTiming =
        EntryTiming.analyze(zoomCandles);

    return DetailDataBundle(
      selectedCoin: detailItem,
      candles: newCandles,
      visibleCandles: zoomCandles,
      setupResult: newSetup,
      pumpAnalysis: newPumpAnalysis,
      entryTiming: newEntryTiming,
    );
  }
}
