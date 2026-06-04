import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/views/welcome_screen.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';

import 'qlsv_send_notifications_screen.dart';
import 'qlsv_final_grades_screen.dart';
import 'qlsv_settings_screen.dart';
import 'qlsv_notifications_screen.dart';
import 'qlsv_exam_schedules_screen.dart';

class QlsvHomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const QlsvHomeScreen({super.key, required this.profile});

  @override
  State<QlsvHomeScreen> createState() => _QlsvHomeScreenState();
}

class _QlsvHomeScreenState extends State<QlsvHomeScreen> {
  int _tab = 0;
  late final QlsvRepository _repo;
  late Future<Map<String, dynamic>> _statsFuture;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
    _statsFuture = _loadStats();
    _loadUnreadCount();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final classes = await _repo.getClasses();
    final exams = await _repo.getExamSchedules();

    final activeClasses = classes.where((e) {
      return (e['adminState'] ?? '').toString() == 'active';
    }).length;

    final archivedClasses = classes.where((e) {
      return (e['adminState'] ?? '').toString() == 'archived';
    }).length;

    return {
      'activeClasses': activeClasses,
      'archivedClasses': archivedClasses,
      'examSchedules': exams.length,
    };
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repo.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _statsFuture = _loadStats();
    });
    await _loadUnreadCount();
  }

  Future<void> _handleBackPressed() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn muốn đăng xuất hay thoát ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'logout'),
            child: const Text('Đăng xuất'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'exit'),
            child: const Text('Thoát app'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'logout') {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } else if (action == 'exit') {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (widget.profile['fullName'] ?? 'QLSV').toString();

    final pages = [
      _QlsvDashboardTab(
        fullName: fullName,
        statsFuture: _statsFuture,
        unreadCount: _unreadCount,
        onRefresh: _refreshDashboard,

        // Chuông: mở lịch sử thông báo
        onOpenNotifications: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QlsvNotificationsScreen(profile: widget.profile),
            ),
          );

          await _loadUnreadCount();
        },

        // Quick action: sang tab quản lý/gửi thông báo
        onOpenSendNotifications: () => setState(() => _tab = 1),

        onOpenExamSchedule: () => setState(() => _tab = 2),
        onOpenFinalGrades: () => setState(() => _tab = 3),
      ),
      QlsvSendNotificationsScreen(profile: widget.profile),
      QlsvExamSchedulesScreen(profile: widget.profile),
      QlsvFinalGradesScreen(profile: widget.profile),
      QlsvSettingsScreen(profile: widget.profile),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(child: pages[_tab]),
        bottomNavigationBar: _BottomNav(
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _QlsvDashboardTab extends StatelessWidget {
  final String fullName;
  final Future<Map<String, dynamic>> statsFuture;
  final int unreadCount;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSendNotifications;
  final VoidCallback onOpenExamSchedule;
  final VoidCallback onOpenFinalGrades;

  const _QlsvDashboardTab({
    required this.fullName,
    required this.statsFuture,
    required this.unreadCount,
    required this.onRefresh,
    required this.onOpenNotifications,
    required this.onOpenSendNotifications,
    required this.onOpenExamSchedule,
    required this.onOpenFinalGrades,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture,
      builder: (context, snapshot) {
        final activeClasses =
            snapshot.data?['activeClasses']?.toString() ?? '--';
        final archivedClasses =
            snapshot.data?['archivedClasses']?.toString() ?? '--';
        final examSchedules =
            snapshot.data?['examSchedules']?.toString() ?? '--';

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  unreadCount: unreadCount,
                  onOpenNotifications: onOpenNotifications,
                ),
                const SizedBox(height: 16),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.school_rounded,
                        title: 'Lớp đang học',
                        value: activeClasses,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.history_rounded,
                        title: 'Lớp lịch sử',
                        value: archivedClasses,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _StatCardWide(
                  icon: Icons.event_rounded,
                  title: 'Lịch thi',
                  value: examSchedules,
                ),

                const SizedBox(height: 26),

                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: _primary, size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Thao tác nhanh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _QuickActionCard(
                  icon: Icons.notifications_rounded,
                  title: 'Gửi thông báo',
                  subtitle: 'Tạo, sửa hoặc xóa thông báo toàn hệ thống',
                  onTap: onOpenSendNotifications,
                ),

                const SizedBox(height: 12),

                _QuickActionCard(
                  icon: Icons.event_rounded,
                  title: 'Quản lý lịch thi',
                  subtitle: 'Đặt lịch thi cuối kỳ theo từng môn học',
                  onTap: onOpenExamSchedule,
                ),

                const SizedBox(height: 12),

                _QuickActionCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Nhập điểm cuối kỳ',
                  subtitle: 'Nhập điểm thi và cập nhật kết quả học phần',
                  onTap: onOpenFinalGrades,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onOpenNotifications;

  const _TopBar({required this.unreadCount, required this.onOpenNotifications});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'StuEdu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onOpenNotifications,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 26,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 1,
          width: double.infinity,
          color: const Color(0xFFE5E7EB),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardWide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCardWide({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD2D6EA), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_customize_rounded),
          label: 'TRANG CHỦ',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_rounded),
          label: 'THÔNG BÁO',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_rounded),
          label: 'LỊCH THI',
        ),
        NavigationDestination(
          icon: Icon(Icons.edit_note_rounded),
          label: 'ĐIỂM THI',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_rounded),
          label: 'CÀI ĐẶT',
        ),
      ],
    );
  }
}

class _QlsvPlaceholder extends StatelessWidget {
  final String title;

  const _QlsvPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}
