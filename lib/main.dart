import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'pages/splash_screen.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'models/coin_radar_data.dart';

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

  await _startForegroundService(); // 🔥 BURASI ÖNEMLİ

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

// 🔥 FOREGROUND SERVICE BAŞLAT
Future<void> _startForegroundService() async {
  await FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'short_service',
      channelName: 'Short Radar Service',
      channelDescription: 'Piyasa izleniyor',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
    ),
  );

  await FlutterForegroundTask.startService(
    notificationTitle: 'Short Radar aktif',
    notificationText: 'Arka planda çalışıyor...',
    callback: startCallback,
  );
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShortRadarTaskHandler());
}

// 🔥 TASK HANDLER
class ShortRadarTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // 🔥 TEST NOTIFICATION
    if (DateTime.now().second % 15 == 0) {
      _sendTestNotification();
    }
  }

  Future<void> _sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'short_alert_channel',
      'Short Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "SHORT RADAR",
      "Arka planda çalışıyor 🚀",
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
