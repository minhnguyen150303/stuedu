import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await PushNotificationService.initialize();

  final initialMessage = await PushNotificationService.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('Initial push: ${initialMessage.data}');
  }

  PushNotificationService.onMessageOpenedApp.listen((message) {
    debugPrint('Opened from push: ${message.data}');
  });

  runApp(const StuEduApp());
}
