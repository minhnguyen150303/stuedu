import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/sources/remote/api_client.dart';

import '../../admin/views/admin_home_screen.dart';
import '../../student/views/student_home_screen.dart';
import '../../teacher/views/teacher_home_screen.dart';
import 'welcome_screen.dart';
import '../../../core/services/push_notification_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _screenFuture;

  @override
  void initState() {
    super.initState();
    _screenFuture = _resolveScreen();
  }

  Future<Widget> _resolveScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const WelcomeScreen();
    }

    try {
      final api = ApiClient(AppConfig.baseUrl);
      final repo = AuthRepository(api);
      final profile = await repo.loginWithCurrentUser(user);
      await PushNotificationService.saveTokenToBackend();

      final role = (profile['role'] ?? 'student').toString();

      if (role == 'admin') {
        return AdminHomeScreen(profile: profile);
      }
      if (role == 'teacher') {
        return TeacherHomeScreen(profile: profile);
      }
      return StudentHomeScreen(profile: profile);
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return const WelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _screenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data ?? const WelcomeScreen();
      },
    );
  }
}
