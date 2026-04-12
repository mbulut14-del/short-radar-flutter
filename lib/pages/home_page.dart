import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/coin_radar_data.dart';
import 'detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CoinRadarData> coins = [];

  CoinRadarData? radarLeader;
  bool isLoading = true;
  String errorText = '';
  Timer? _refreshTimer;

  String? lastNotifiedCoin;
  DateTime? lastNotifyTime;

  final Map<String, List<double>> _oiHistory = {};
  final Map<String, List<double>> _priceHistory = {};

  final Map<String, String> _oiDirectionMap = {};
  final Map<String, String> _priceDirectionMap = {};
  final Map<String, String> _oiPriceSignalMap = {};

  final Map<String, String> _orderFlowMap = {};
  final Map<String, double> _bestBidPriceMap = {};
  final Map<String, double> _bestAskPriceMap = {};
  final Map<String, double> _bestBidSizeMap = {};
  final Map<String, double> _bestAskSizeMap = {};

  WebSocket? _bookTickerSocket;
  StreamSubscription<dynamic>? _bookTickerSubscription;
  Timer? _bookTickerReconnectTimer;
  bool _isConnectingBookTicker = false;
  bool _manuallyClosedBookTicker = false;

  final Set<String> _desiredBookTickerSymbols = <String>{};
  final Set<String> _subscribedBookTickerSymbols = <String>{};

  static const int _historyLimit = 360;
  static const String _gateUsdtWsUrl = 'wss://fx-ws.gateio.ws/v4/ws/usdt';

  @override
  void initState() {
    super.initState();
    _connectBookTicker();
    fetchCoins();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        fetchCoins();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    _bookTickerReconnectTimer?.cancel();
    _bookTickerSubscription?.cancel();
    _manuallyClosedBookTicker = true;
    _bookTickerSocket?.close();

    super.dispose();
  }

  void _updateOiHistory(String symbol, double oi) {
    final history = _oiHistory.putIfAbsent(symbol, () => <double>[]);
    history.add(oi);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  void _updatePriceHistory(String symbol, double price) {
    final history = _priceHistory.putIfAbsent(symbol, () => <double>[]);
    history.add(price);

    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  String _calculateDirectionFromHistory(List<double>? history) {
    if (history == null || history.length < 2) {
      return 'FLAT';
    }

    final double first = history.first;
    final double last = history.last;

    if (first <= 0) return 'FLAT';

    final double changePercent = ((last - first) / first) * 100;

    if (changePercent > 1) return 'UP';
    if (changePercent < -1) return 'DOWN';
    return 'FLAT';
  }

  String _calculateOiDirection(String symbol) {
    return _calculateDirectionFromHistory(_oiHistory[symbol]);
  }

  String _calculatePriceDirection(String symbol) {
    return _calculateDirectionFromHistory(_priceHistory[symbol]);
  }

  String _calculateOiPriceSignal({
    required String oiDirection,
    required String priceDirection,
  }) {
    if (oiDirection == 'UP' && priceDirection == 'DOWN') {
      return 'STRONG_SHORT';
    }
    if (oiDirection == 'UP' && priceDirection == 'UP') {
      return 'PUMP_RISK';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'UP') {
      return 'SHORT_SQUEEZE';
    }
    if (oiDirection == 'DOWN' && priceDirection == 'DOWN') {
      return 'WEAK_DROP';
    }
    return 'NEUTRAL';
  }

  String _calculateOrderFlow(double bid, double ask) {
    if (bid > ask * 1.2) return 'BUY_PRESSURE';
    if (ask > bid * 1.2) return 'SELL_PRESSURE';
    return 'NEUTRAL';
  }

  void _updateOrderFlowForSymbol(String symbol) {
    final double bidSize = _bestBidSizeMap[symbol] ?? 0;
    final double askSize = _bestAskSizeMap[symbol] ?? 0;

    if (bidSize <= 0 && askSize <= 0) {
      _orderFlowMap[symbol] = 'NEUTRAL';
      return;
    }

    _orderFlowMap[symbol] = _calculateOrderFlow(bidSize, askSize);
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  CoinRadarData _withOiDirection(CoinRadarData coin, String direction) {
    return CoinRadarData(
      name: coin.name,
      changePercent: coin.changePercent,
      fundingRate: coin.fundingRate,
      lastPrice: coin.lastPrice,
      markPrice: coin.markPrice,
      indexPrice: coin.indexPrice,
      volume24h: coin.volume24h,
      openInterest: coin.openInterest,
      oiDirection: direction,
      score: coin.score,
      biasLabel: coin.biasLabel,
      note: coin.note,
    );
  }

  Future<void> _connectBookTicker() async {
    if (_isConnectingBookTicker) return;
    if (_bookTickerSocket != null) return;

    _isConnectingBookTicker = true;

    try {
      final socket = await WebSocket.connect(
        _gateUsdtWsUrl,
        headers: const {
          'X-Gate-Channel-Id': 'short-radar-book-ticker',
        },
      );

      socket.pingInterval = const Duration(seconds: 10);

      _bookTickerSocket = socket;
      _subscribedBookTickerSymbols.clear();

      _bookTickerSubscription = socket.listen(
        _handleBookTickerMessage,
        onDone: _handleBookTickerClosed,
        onError: (_) => _handleBookTickerClosed(),
        cancelOnError: true,
      );

      _syncBookTickerSubscriptions();
    } catch (_) {
      _scheduleBookTickerReconnect();
    } finally {
      _isConnectingBookTicker = false;
    }
  }

  void _handleBookTickerClosed() {
    _bookTickerSubscription?.cancel();
    _bookTickerSubscription = null;
    _bookTickerSocket = null;
    _subscribedBookTickerSymbols.clear();

    if (!_manuallyClosedBookTicker) {
      _scheduleBookTickerReconnect();
    }
  }

  void _scheduleBookTickerReconnect() {
    _bookTickerReconnectTimer?.cancel();
    _bookTickerReconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _connectBookTicker();
      }
    });
  }

  void _sendBookTickerMessage({
    required String event,
    required String symbol,
  }) {
    final socket = _bookTickerSocket;
    if (socket == null) return;

    final Map<String, dynamic> message = {
      'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'channel': 'futures.book_ticker',
      'event': event,
      'payload': [symbol],
    };

    socket.add(jsonEncode(message));
  }

  void _syncBookTickerSubscriptions() {
    final socket = _bookTickerSocket;
    if (socket == null) return;

    final Set<String> toSubscribe =
        _desiredBookTickerSymbols.difference(_subscribedBookTickerSymbols);
    final Set<String> toUnsubscribe =
        _subscribedBookTickerSymbols.difference(_desiredBookTickerSymbols);

    for (final symbol in toSubscribe) {
      _sendBookTickerMessage(event: 'subscribe', symbol: symbol);
      _subscribedBookTickerSymbols.add(symbol);
    }

    for (final symbol in toUnsubscribe) {
      _sendBookTickerMessage(event: 'unsubscribe', symbol: symbol);
      _subscribedBookTickerSymbols.remove(symbol);
    }
  }

  void _handleBookTickerMessage(dynamic rawMessage) {
    try {
      final String messageText;
      if (rawMessage is String) {
        messageText = rawMessage;
      } else if (rawMessage is List<int>) {
        messageText = utf8.decode(rawMessage);
      } else {
        return;
      }

      final dynamic decoded = jsonDecode(messageText);
      if (decoded is! Map<String, dynamic>) return;

      if (decoded['channel'] != 'futures.book_ticker') return;
      if (decoded['event'] != 'update') return;

      final dynamic result = decoded['result'];
      if (result is! Map<String, dynamic>) return;

      final String symbol = (result['s'] ?? '').toString();
      if (symbol.isEmpty) return;

      _bestBidPriceMap[symbol] = _parseToDouble(result['b']);
      _bestAskPriceMap[symbol] = _parseToDouble(result['a']);
      _bestBidSizeMap[symbol] = _parseToDouble(result['B']);
      _bestAskSizeMap[symbol] = _parseToDouble(result['A']);

      _updateOrderFlowForSymbol(symbol);

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> fetchCoins() async {
    setState(() {
      isLoading = true;
      errorText = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri alınamadı';
        });
        return;
      }

      final List<dynamic> parsed = json.decode(response.body);

      final List<CoinRadarData> rawCoins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (rawCoins.isEmpty) {
        setState(() {
          isLoading = false;
          errorText = 'Canlı veri boş döndü';
        });
        return;
      }

      final List<CoinRadarData> allCoins = rawCoins.map((coin) {
        _updateOiHistory(coin.name, coin.openInterest);
        _updatePriceHistory(coin.name, coin.lastPrice);

        final String oiDirection = _calculateOiDirection(coin.name);
        final String priceDirection = _calculatePriceDirection(coin.name);
        final String oiPriceSignal = _calculateOiPriceSignal(
          oiDirection: oiDirection,
          priceDirection: priceDirection,
        );

        _oiDirectionMap[coin.name] = oiDirection;
        _priceDirectionMap[coin.name] = priceDirection;
        _oiPriceSignalMap[coin.name] = oiPriceSignal;

        _updateOrderFlowForSymbol(coin.name);

        return _withOiDirection(coin, oiDirection);
      }).toList();

      final List<CoinRadarData> sortedByChange = [...allCoins]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final List<CoinRadarData> sortedByScore = [...allCoins]
        ..sort((a, b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) return scoreCompare;
          return b.changePercent.compareTo(a.changePercent);
        });

      final CoinRadarData leader = sortedByScore.first;
      final List<CoinRadarData> topCoins = sortedByChange.take(10).toList();

      _desiredBookTickerSymbols
        ..clear()
        ..addAll(topCoins.map((e) => e.name));

      _syncBookTickerSubscriptions();

      setState(() {
        coins = topCoins;
        radarLeader = leader;
        isLoading = false;
        errorText = '';
      });

      if (leader.score >= 70 && leader.fundingRate > 0) {
        final now = DateTime.now();

        final bool isSameCoin = lastNotifiedCoin == leader.name;
        final bool isTooSoon = lastNotifyTime != null &&
            now.difference(lastNotifyTime!).inMinutes < 30;

        if (!isSameCoin || !isTooSoon) {
          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
            'short_channel',
            'Short Alerts',
            importance: Importance.max,
            priority: Priority.high,
          );

          const NotificationDetails details =
              NotificationDetails(android: androidDetails);

          await notificationsPlugin.show(
            0,
            'SHORT BAŞLIYOR 🚨',
            '${leader.name} güçlü short sinyali veriyor',
            details,
          );

          lastNotifiedCoin = leader.name;
          lastNotifyTime = now;
        }
      }
    } catch (_) {
      setState(() {
        isLoading = false;
        errorText = 'Canlı veri alınamadı';
      });
    }
  }

  Widget _miniInfo(String title, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    if (errorText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.5),
        ),
      ),
      child: Text(
        errorText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCoinCard(int index, CoinRadarData coin) {
    final String oiDirection = _oiDirectionMap[coin.name] ?? coin.oiDirection;
    final String priceDirection = _priceDirectionMap[coin.name] ?? 'FLAT';
    final String oiPriceSignal = _oiPriceSignalMap[coin.name] ?? 'NEUTRAL';
    final String orderFlowDirection = _orderFlowMap[coin.name] ?? 'NEUTRAL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailPage(
                coinData: coin,
                oiDirection: oiDirection,
                priceDirection: priceDirection,
                oiPriceSignal: oiPriceSignal,
                orderFlowDirection: orderFlowDirection,
              ),
            ),
          );
        },
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF07122A),
                Color(0xFF091933),
                Color(0xFF07122A),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF3EA6FF),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x663EA6FF),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Color(0x3300FFFF),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF123D9B),
                    border: Border.all(
                      color: const Color(0xFF5AA8FF),
                      width: 1.6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x663EA6FF),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coin.lastPriceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Short skoru: ${coin.score} • ${coin.biasLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  coin.changeText,
                  style: TextStyle(
                    color: coin.changePercent < 0
                        ? Colors.redAccent
                        : const Color(0xFF3CFFB2),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoadingState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            ),
            SizedBox(height: 14),
            Text(
              'Short fırsatları analiz ediliyor...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showInitialLoader = coins.isEmpty && isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: fetchCoins,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildErrorCard(),
                  ],
                  const SizedBox(height: 12),
                  if (showInitialLoader)
                    _buildInitialLoadingState()
                  else
                    ...coins.asMap().entries.map((entry) {
                      final int index = entry.key + 1;
                      final CoinRadarData coin = entry.value;
                      return _buildCoinCard(index, coin);
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
