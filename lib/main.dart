import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'models/candle_data.dart';
import 'models/coin_radar_data.dart';
import 'services/decision_engine.dart';

// 🔥 GLOBAL
late final FlutterLocalNotificationsPlugin notificationsPlugin;

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
      channelId: 'short_service',
      channelName: 'Short Radar Service',
      channelDescription: 'Piyasa izleniyor',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
      enableVibration: true,
      playSound: false,
      showWhen: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
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
    notificationText: 'Arka planda çalışıyor...',
    callback: startCallback,
  );
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

class ShortRadarTaskHandler extends TaskHandler {
  int _lastNotifiedMinute = -1;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    _checkDecisionAndNotify();
  }

  Future<void> _checkDecisionAndNotify() async {
    final decision = const DecisionEngine().build(
      oiPriceSignal: 'STRONG_SHORT',
      oiDirection: 'UP',
      priceDirection: 'DOWN',
      orderFlowDirection: 'SELL_PRESSURE',
      pumpAnalysis: null,
      entryTiming: null,
      setupResult: null,
      visibleCandles: <CandleData>[],
    );

    final int nowMinute = DateTime.now().minute;

    if (decision.action == 'ENTER SHORT' &&
        decision.finalScore >= 85 &&
        _lastNotifiedMinute != nowMinute) {
      _lastNotifiedMinute = nowMinute;
      await _sendRealNotification(decision);
    }
  }

  Future<void> _sendRealNotification(dynamic decision) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'short_alert_channel',
      'Short Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🔥 SHORT FIRSAT',
      '${decision.scoreClass} • Score ${decision.finalScore.toStringAsFixed(0)} • ${decision.action}',
      details,
    );
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
