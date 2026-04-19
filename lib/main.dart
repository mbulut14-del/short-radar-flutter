import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';

import 'models/coin_radar_data.dart';

import 'services/decision_engine.dart';
import 'services/detail_data_service.dart';

late final FlutterLocalNotificationsPlugin notificationsPlugin;

const String _serviceChannelId = 'short_service';
const String _serviceChannelName = 'Short Radar Service';
const String _serviceChannelDescription = 'Piyasa izleniyor';

const String _alertChannelId = 'short_alert_channel';
const String _alertChannelName = 'Short Alerts';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  notificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(initSettings);

  await _requestNotificationPermission();
  await _startForegroundService();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermission() async {
  final androidImplementation =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();
  }
}

Future<void> _startForegroundService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: _serviceChannelId,
      channelName: _serviceChannelName,
      channelDescription: _serviceChannelDescription,
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15000,
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  final bool isRunning = await FlutterForegroundTask.isRunningService;
  if (isRunning) return;

  await FlutterForegroundTask.startService(
    notificationTitle: 'Short Radar aktif',
    notificationText: 'Arka planda piyasa taranıyor...',
    callback: startCallback,
  );
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

class ShortRadarTaskHandler extends TaskHandler {
  late FlutterLocalNotificationsPlugin _localNotifications;

  bool _isChecking = false;
  final Map<String, DateTime> _lastNotificationTimes = <String, DateTime>{};

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _notificationCooldown = Duration(minutes: 10);

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    _localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      await _checkMarket(sendPort);
    } catch (e) {
      debugPrint('BACKGROUND ERROR: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _checkMarket(SendPort? sendPort) async {
    final http.Response response = await http
        .get(
          Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      debugPrint('BACKGROUND ERROR: ticker status ${response.statusCode}');
      return;
    }

    final dynamic decoded = json.decode(response.body);
    if (decoded is! List) {
      debugPrint('BACKGROUND ERROR: ticker format invalid');
      return;
    }

    final List<CoinRadarData> rawCoins = decoded
        .whereType<Map<String, dynamic>>()
        .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
        .map(CoinRadarData.fromJson)
        .toList();

    if (rawCoins.isEmpty) {
      debugPrint('BACKGROUND ERROR: no coins parsed');
      return;
    }

    final List<CoinRadarData> sorted = <CoinRadarData>[...rawCoins]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

    final List<CoinRadarData> topCoins = sorted.take(10).toList();

    for (final CoinRadarData coin in topCoins) {
      try {
        final DetailDataBundle bundle = await DetailDataService.load(
          contractName: coin.name,
          selectedInterval: '5m',
          fallbackCoin: coin,
        );

        final decision = const DecisionEngine().build(
          oiPriceSignal: 'NEUTRAL',
          oiDirection: bundle.selectedCoin.oiDirection,
          priceDirection: 'FLAT',
          orderFlowDirection: 'NEUTRAL',
          pumpAnalysis: bundle.pumpAnalysis,
          entryTiming: bundle.entryTiming,
          setupResult: bundle.setupResult,
          visibleCandles: bundle.visibleCandles,
        );

        sendPort?.send({
          'coin': coin.name,
          'score': decision.finalScore,
          'action': decision.action,
          'summary': decision.summary,
        });

        if (_shouldNotify(coin.name, decision.finalScore, decision.action)) {
          await _sendNotification(
            coin: coin.name,
            score: decision.finalScore,
            action: decision.action,
          );
        }
      } catch (e) {
        debugPrint('BACKGROUND COIN ERROR [${coin.name}]: $e');
      }
    }
  }

  bool _shouldNotify(String coin, double score, String action) {
    if (score < 85) return false;
    if (action != 'ENTER SHORT' && action != 'PREPARE SHORT') return false;

    final DateTime now = DateTime.now();
    final DateTime? lastTime = _lastNotificationTimes[coin];

    if (lastTime != null && now.difference(lastTime) < _notificationCooldown) {
      return false;
    }

    _lastNotificationTimes[coin] = now;
    return true;
  }

  Future<void> _sendNotification({
    required String coin,
    required double score,
    required String action,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        importance: Importance.max,
        priority: Priority.high,
        onlyAlertOnce: true,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🔥 SHORT FIRSAT',
        '$coin • ${score.toStringAsFixed(0)} • $action',
        details,
      );
    } catch (e) {
      debugPrint('NOTIFICATION ERROR: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Short Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final CoinRadarData coin = settings.arguments as CoinRadarData;

          return MaterialPageRoute(
            builder: (_) => DetailPage(
              coinData: coin,
              oiDirection: 'FLAT',
            ),
          );
        }
        return null;
      },
    );
  }
}
