import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_classes_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_schedule_screen.dart';
import '../../auth/views/welcome_screen.dart';
import '../../../core/services/push_notification_service.dart';
import 'teacher_profile_screen.dart';

class TeacherSettingsScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const TeacherSettingsScreen({super.key, required this.profile});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PushNotificationService.removeTokenFromBackend();
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (profile['fullName'] ?? 'Giảng viên').toString();
    final avatarUrl = (profile['avatarUrl'] ?? '').toString();
    final email = (profile['email'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherHomeScreen(profile: profile),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherScheduleScreen(profile: profile),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherClassesScreen(profile: profile),
              ),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Setting',
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Setting',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE9ECF6),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.person_rounded,
                color: Color(0xFF7C3AED),
              ),
              title: const Text(
                'Thông tin cá nhân',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherProfileScreen(profile: profile),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}
