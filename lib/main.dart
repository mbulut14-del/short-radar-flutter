import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';

import 'models/coin_radar_data.dart';

import 'services/decision_engine.dart';
import 'services/detail_data_service.dart';

// 🔥 GLOBAL
late final FlutterLocalNotificationsPlugin notificationsPlugin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  notificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const initSettings = InitializationSettings(android: androidSettings);

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
      channelId: 'short_service',
      channelName: 'Short Radar Service',
      channelDescription: 'Piyasa izleniyor',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15000,
      isOnceEvent: false,
      autoRunOnBoot: true,
    ),
  );

  final bool isRunning = await FlutterForegroundTask.isRunningService;
  if (isRunning) return;

  await FlutterForegroundTask.startService(
    notificationTitle: 'Short Radar aktif',
    notificationText: 'Piyasa taranıyor...',
    callback: startCallback,
  );
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

class ShortRadarTaskHandler extends TaskHandler {
  int _lastNotifiedMinute = -1;
  late FlutterLocalNotificationsPlugin _localNotifications;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // 🔥 CRITICAL: Background isolate için notification init
    _localNotifications = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    await _checkMarket();
  }

  CoinRadarData _fallbackCoin() {
    return const CoinRadarData(
      name: 'BTC_USDT',
      changePercent: 0,
      fundingRate: 0,
      lastPrice: 0,
      markPrice: 0,
      indexPrice: 0,
      volume24h: 0,
      openInterest: 0,
      oiDirection: 'FLAT',
      score: 0,
      biasLabel: '-',
      note: '',
    );
  }

  Future<void> _checkMarket() async {
    try {
      final bundle = await DetailDataService.load(
        contractName: 'BTC_USDT',
        selectedInterval: '5m',
        fallbackCoin: _fallbackCoin(),
      );

      final decision = DecisionEngine().build(
        oiPriceSignal: 'NEUTRAL',
        oiDirection: bundle.selectedCoin.oiDirection,
        priceDirection: 'FLAT',
        orderFlowDirection: 'NEUTRAL',
        pumpAnalysis: bundle.pumpAnalysis,
        entryTiming: bundle.entryTiming,
        setupResult: bundle.setupResult,
        visibleCandles: bundle.visibleCandles,
      );

      final int nowMinute = DateTime.now().minute;

      if (decision.action == 'ENTER SHORT' &&
          decision.finalScore >= 85 &&
          _lastNotifiedMinute != nowMinute) {
        _lastNotifiedMinute = nowMinute;

        await _sendNotification(decision);
      }
    } catch (e) {
      // ❗ Artık sessiz yutmuyoruz
      print("BACKGROUND ERROR: $e");
    }
  }

  Future<void> _sendNotification(dynamic decision) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'short_alert_channel',
        'Short Alerts',
        importance: Importance.max,
        priority: Priority.high,
      );

      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🔥 SHORT FIRSAT',
        '${decision.scoreClass} • ${decision.finalScore.toStringAsFixed(0)}',
        details,
      );
    } catch (e) {
      print("NOTIFICATION ERROR: $e");
    }
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}
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
          final coin = settings.arguments as CoinRadarData;

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
