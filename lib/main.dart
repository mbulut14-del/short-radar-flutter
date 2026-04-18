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
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15000,
      isOnceEvent: false,
      autoRunOnBoot: true,
    ),
  );

  final isRunning = await FlutterForegroundTask.isRunningService;
  if (isRunning) return;

  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'Short Radar aktif',
    notificationText: 'Piyasa taranıyor...',
    callback: startCallback,
  );

  debugPrint("SERVICE START: $result");
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

class ShortRadarTaskHandler extends TaskHandler {
  late FlutterLocalNotificationsPlugin _localNotifications;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
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

  Future<void> _checkMarket() async {
    try {
      final response = await http.get(
        Uri.parse('https://fx-api.gateio.ws/api/v4/futures/usdt/tickers'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return;

      final List<dynamic> parsed = json.decode(response.body);

      final List<CoinRadarData> coins = parsed
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['contract'] ?? '').toString().isNotEmpty)
          .map(CoinRadarData.fromJson)
          .toList();

      if (coins.isEmpty) return;

      // 🔥 EN BASİT TEST
      final sorted = [...coins]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final top10 = sorted.take(10);

      for (final coin in top10) {
        if (coin.changePercent > 20) {
          await _sendNotification(coin.name, coin.changePercent);
        }
      }
    } catch (e) {
      debugPrint("BACKGROUND ERROR: $e");
    }
  }

  Future<void> _sendNotification(String coin, double value) async {
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
        '🔥 TEST ALERT',
        '$coin • %${value.toStringAsFixed(1)}',
        details,
      );
    } catch (e) {
      debugPrint("NOTIFICATION ERROR: $e");
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
