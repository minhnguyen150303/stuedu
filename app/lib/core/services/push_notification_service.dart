import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/sources/remote/api_client.dart';
import '../config/app_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final local = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await local.initialize(initSettings);

  const channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'StuEdu notifications',
    importance: Importance.max,
  );

  await local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  final title =
      message.notification?.title ??
      message.data['title']?.toString() ??
      'StuEdu';

  final body =
      message.notification?.body ?? message.data['body']?.toString() ?? '';

  if (title.trim().isEmpty && body.trim().isEmpty) return;

  await local.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'StuEdu notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF1B2A8A),
        ticker: 'Thông báo mới',
        subText: message.data['subText']?.toString() ?? 'StuEdu',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText:
              message.data['summary']?.toString() ?? 'Thông báo hệ thống',
        ),
      ),
    ),
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'StuEdu notifications',
      importance: Importance.max,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;

      final title =
          notification?.title ?? message.data['title']?.toString() ?? 'StuEdu';

      final body = notification?.body ?? message.data['body']?.toString() ?? '';

      if (title.trim().isEmpty && body.trim().isEmpty) return;

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'StuEdu notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF1B2A8A),
            ticker: 'Thông báo mới',
            subText: message.data['subText']?.toString() ?? 'StuEdu',
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText:
                  message.data['summary']?.toString() ?? 'Thông báo hệ thống',
            ),
          ),
        ),
      );
    });

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await saveTokenToBackend(token);
    });
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTokenToBackend([String? providedToken]) async {
    final token = providedToken ?? await getToken();
    if (token == null || token.isEmpty) return;

    final api = ApiClient(AppConfig.baseUrl);

    await api.post(
      '/users/me/fcm-token',
      data: {'token': token},
      attachFirebaseToken: true,
    );
  }

  static Future<void> removeTokenFromBackend() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;

    final api = ApiClient(AppConfig.baseUrl);

    await api.delete(
      '/users/me/fcm-token',
      data: {'token': token},
      attachFirebaseToken: true,
    );
  }

  static Future<RemoteMessage?> getInitialMessage() {
    return FirebaseMessaging.instance.getInitialMessage();
  }

  static Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
