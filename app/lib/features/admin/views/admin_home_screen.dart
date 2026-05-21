import 'dart:io';
import 'admin_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/views/welcome_screen.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_academic_repository.dart';
import 'admin_users_screen.dart';
import 'majors/admin_majors_screen.dart';
import 'admin_send_notification_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_add_user_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const AdminHomeScreen({super.key, required this.profile});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;
  late Future<Map<String, dynamic>> _statsFuture;
  int _unreadCount = 0;

  void _reloadStats() {
    final api = ApiClient(AppConfig.baseUrl);
    final repo = AdminRepository(api);

    setState(() {
      _statsFuture = repo.getUserStats();
    });
  }

  Future<void> _showAddUserComingSoon() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminAddUserScreen()),
    );

    if (changed == true) {
      _reloadStats();
      await _loadUnreadCount();
    }
  }

  Future<void> _refreshDashboard() async {
    final api = ApiClient(AppConfig.baseUrl);
    final repo = AdminRepository(api);

    setState(() {
      _statsFuture = repo.getUserStats();
    });

    await _loadUnreadCount();
  }

  Future<void> _showCreateMajorForm() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Thêm chuyên ngành',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                _AdminMajorField(
                  label: 'Tên chuyên ngành',
                  controller: nameController,
                  hintText: 'Nhập tên chuyên ngành',
                ),
                const SizedBox(height: 16),
                _AdminMajorField(
                  label: 'Mô tả',
                  controller: descController,
                  hintText: 'Nhập mô tả',
                  maxLines: 3,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B2A8A),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    final name = nameController.text.trim();
    final description = descController.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên chuyên ngành')),
      );
      return;
    }

    try {
      final api = ApiClient(AppConfig.baseUrl);
      final repo = AdminAcademicRepository(api);

      await repo.createMajor(name: name, description: description);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm chuyên ngành')));

      _reloadStats();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    final api = ApiClient(AppConfig.baseUrl);
    final repo = AdminRepository(api);
    _statsFuture = repo.getUserStats();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final api = ApiClient(AppConfig.baseUrl);
      final repo = AdminRepository(api);
      final count = await repo.getUnreadNotificationCount();

      if (!mounted) return;
      setState(() {
        _unreadCount = count;
      });
    } catch (_) {}
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
    final fullName = (widget.profile['fullName'] ?? 'Administrator') as String;

    final pages = [
      _DashboardTab(
        fullName: fullName,
        statsFuture: _statsFuture,
        unreadCount: _unreadCount,
        onAddUser: _showAddUserComingSoon,
        onCreateMajor: _showCreateMajorForm,
        onRefresh: _refreshDashboard,
        onOpenNotifications: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminNotificationsScreen(profile: widget.profile),
            ),
          );
          await _loadUnreadCount();
        },
      ),
      const _UsersTab(),
      const AdminMajorsScreen(),
      AdminSendNotificationsScreen(profile: widget.profile),
      AdminSettingsScreen(profile: widget.profile),
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

class _DashboardTab extends StatelessWidget {
  final String fullName;
  final Future<Map<String, dynamic>> statsFuture;
  final int unreadCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onAddUser;
  final VoidCallback onCreateMajor;
  final Future<void> Function() onRefresh;

  const _DashboardTab({
    required this.fullName,
    required this.statsFuture,
    required this.unreadCount,
    required this.onOpenNotifications,
    required this.onAddUser,
    required this.onCreateMajor,
    required this.onRefresh,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture,
      builder: (context, snapshot) {
        final totalStudents =
            snapshot.data?['totalStudents']?.toString() ?? '--';
        final totalTeachers =
            snapshot.data?['totalTeachers']?.toString() ?? '--';
        final totalMajors = snapshot.data?['totalMajors']?.toString() ?? '--';

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(
                  fullName: fullName,
                  unreadCount: unreadCount,
                  onOpenNotifications: onOpenNotifications,
                ),

                const SizedBox(height: 16),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      "Không tải được thống kê người dùng",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.groups_rounded,
                        title: "Sinh viên",
                        value: totalStudents,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.badge_outlined,
                        title: "Giảng viên",
                        value: totalTeachers,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _StatCardWide(
                  icon: Icons.account_tree_rounded,
                  title: "Chuyên ngành",
                  value: totalMajors,
                ),

                const SizedBox(height: 26),

                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: _primary, size: 26),
                    SizedBox(width: 8),
                    Text(
                      "Thao tác nhanh",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _QuickActionCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: "Thêm người dùng",
                  subtitle: "Tạo tài khoản sinh viên hoặc giảng viên",
                  onTap: onAddUser,
                ),

                const SizedBox(height: 12),

                _QuickActionCard(
                  icon: Icons.account_tree_rounded,
                  title: "Thêm chuyên ngành",
                  subtitle: "Tạo chuyên ngành mới cho chương trình đào tạo",
                  onTap: onCreateMajor,
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final String fullName;
  final int unreadCount;
  final VoidCallback onOpenNotifications;

  const _TopBar({
    required this.fullName,
    required this.unreadCount,
    required this.onOpenNotifications,
  });

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
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    color: Colors.black12,
                    offset: Offset(0, 5),
                  ),
                ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
          border: Border.all(
            color: const Color(0xFFD2D6EA),
            width: 2,
            style: BorderStyle.solid,
          ),
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

class _AdminMajorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  const _AdminMajorField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF3F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
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
          label: "TRANG CHỦ",
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_rounded),
          label: "NGƯỜI DÙNG",
        ),
        NavigationDestination(icon: Icon(Icons.folder_rounded), label: "NGÀNH"),
        NavigationDestination(
          icon: Icon(Icons.notifications_rounded),
          label: "THÔNG BÁO",
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_rounded),
          label: "CÀI ĐẶT",
        ),
      ],
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return const AdminUsersScreen();
  }
}
