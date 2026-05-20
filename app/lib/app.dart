import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/auth_gate.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class StuEduApp extends StatelessWidget {
  const StuEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey, // 👈 thêm dòng này
      debugShowCheckedModeBanner: false,
      title: 'StuEdu',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
