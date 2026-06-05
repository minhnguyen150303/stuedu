import 'package:flutter/material.dart';

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/views/welcome_screen.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'student_schedule_screen.dart';
import 'student_classes_screen.dart';
import 'student_settings_screen.dart';
import 'student_grades_screen.dart';
import 'student_courses_screen.dart';
import 'student_assignments_screen.dart';
import 'student_notifications_screen.dart';
import 'student_gpa_progress_screen.dart';
import 'student_credit_progress_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentHomeScreen({super.key, required this.profile});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final StudentRepository _repo;

  static Map<String, dynamic>? _cachedDashboard;
  static int _cachedUnreadCount = 0;
  static DateTime? _cachedAt;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));

    if (_cachedDashboard != null) {
      _dashboard = _cachedDashboard;
      _unreadCount = _cachedUnreadCount;
      _loading = false;

      final cachedAt = _cachedAt;
      final isOld =
          cachedAt == null ||
          DateTime.now().difference(cachedAt).inMinutes >= 2;

      if (isOld) {
        _loadDashboard(silent: true);
      }
    } else {
      _loadDashboard();
    }
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

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repo.getUnreadNotificationCount();

      _cachedUnreadCount = count;

      if (!mounted) return;

      setState(() {
        _unreadCount = count;
      });
    } catch (_) {}
  }

  void _openGpaProgressScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentGpaProgressScreen(profile: widget.profile),
      ),
    );
  }

  void _openCreditProgressScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentCreditProgressScreen(profile: widget.profile),
      ),
    );
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _repo.getHomeDashboard();

      if (!mounted) return;

      _cachedDashboard = data;
      _cachedAt = DateTime.now();

      setState(() {
        _dashboard = data;
        _loading = false;
        _error = null;
      });

      await _loadUnreadCount();
    } catch (e) {
      if (!mounted) return;

      if (_dashboard != null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = Map<String, dynamic>.from(
      (_dashboard?['student'] as Map?) ?? const {},
    );

    final fullName =
        (student['fullName'] ?? widget.profile['fullName'] ?? 'Student')
            .toString();

    final avatarUrl =
        (student['avatarUrl'] ?? widget.profile['avatarUrl'] ?? '').toString();

    final major =
        (student['majorName'] ??
                widget.profile['majorName'] ??
                widget.profile['studentInfo']?['majorName'] ??
                'Chuyên ngành')
            .toString();

    final yearValue =
        student['studentInfo']?['year'] ??
        widget.profile['studentInfo']?['year'] ??
        widget.profile['year'];

    final year = yearValue == null ? 'Năm học chưa cập nhật' : 'Năm $yearValue';

    final summary = Map<String, dynamic>.from(
      (_dashboard?['summary'] as Map?) ?? const {},
    );

    final rawGpa4 = double.tryParse((summary['gpa4'] ?? 0).toString()) ?? 0;

    final gpa4 = rawGpa4 == rawGpa4.roundToDouble()
        ? '${rawGpa4.toInt()}/4'
        : '${rawGpa4.toStringAsFixed(2)}/4';
    final completedCredits =
        (summary['earnedCredits'] ?? summary['registeredCredits'] ?? 0)
            .toString();

    final totalMajorCredits = (summary['totalMajorCredits'] ?? 0).toString();
    final approvedClassCount = (summary['approvedClassCount'] ?? 0).toString();

    final todaySchedule = List<Map<String, dynamic>>.from(
      ((_dashboard?['todaySchedule'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    final upcomingDeadlines = List<Map<String, dynamic>>.from(
      ((_dashboard?['upcomingDeadlines'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadDashboard)
              : RefreshIndicator(
                  onRefresh: () => _loadDashboard(),
                  child: _HomeTab(
                    fullName: fullName,
                    avatarUrl: avatarUrl,
                    major: major,
                    year: year,
                    gpa: gpa4,
                    gpaRaw: rawGpa4,
                    registeredCredits: completedCredits,
                    totalMajorCredits: totalMajorCredits,
                    approvedClassCount: approvedClassCount,
                    schedule: todaySchedule,
                    deadlines: upcomingDeadlines,
                    onOpenScheduleDetail: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentScheduleScreen(profile: widget.profile),
                        ),
                      );
                    },
                    onOpenAssignmentsDetail: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentAssignmentsScreen(profile: widget.profile),
                        ),
                      );
                    },
                    unreadCount: _unreadCount,
                    onOpenNotifications: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentNotificationsScreen(
                            profile: widget.profile,
                          ),
                        ),
                      );
                      await _loadUnreadCount();
                    },
                    onOpenGpaProgress: _openGpaProgressScreen,
                    onOpenCreditProgress: _openCreditProgressScreen,
                  ),
                ),
        ),
        bottomNavigationBar: _BottomNav(
          index: 0,
          onChanged: (i) {
            if (i == 0) return;

            if (i == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentClassesScreen(profile: widget.profile),
                ),
              );
              return;
            }

            if (i == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentCoursesScreen(profile: widget.profile),
                ),
              );
              return;
            }

            if (i == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentGradesScreen(profile: widget.profile),
                ),
              );
              return;
            }

            if (i == 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentSettingsScreen(profile: widget.profile),
                ),
              );
              return;
            }
          },
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String fullName;
  final String avatarUrl;
  final String major;
  final String year;
  final String gpa;
  final double gpaRaw;
  final String registeredCredits;
  final String totalMajorCredits;
  final String approvedClassCount;
  final List<Map<String, dynamic>> schedule;
  final List<Map<String, dynamic>> deadlines;
  final VoidCallback onOpenScheduleDetail;
  final VoidCallback onOpenAssignmentsDetail;
  final int unreadCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenGpaProgress;
  final VoidCallback onOpenCreditProgress;

  const _HomeTab({
    required this.fullName,
    required this.avatarUrl,
    required this.major,
    required this.year,
    required this.gpa,
    required this.gpaRaw,
    required this.registeredCredits,
    required this.totalMajorCredits,
    required this.approvedClassCount,
    required this.schedule,
    required this.deadlines,
    required this.onOpenScheduleDetail,
    required this.onOpenAssignmentsDetail,
    required this.unreadCount,
    required this.onOpenNotifications,
    required this.onOpenGpaProgress,
    required this.onOpenCreditProgress,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final scheduleItems = schedule
        .map(
          (e) => _ScheduleItem(
            time: _formatTimeRange(
              (e['startTime'] ?? '').toString(),
              (e['endTime'] ?? '').toString(),
            ),
            title: (e['courseName'] ?? 'Môn học').toString(),
            subtitle:
                '${(e['classCode'] ?? '').toString()} • Phòng ${(e['room'] ?? '').toString()}',
            tag: _buildScheduleTag(e),
          ),
        )
        .toList();

    final deadlineItems = deadlines
        .map(
          (e) => _DeadlineItem(
            title: (e['title'] ?? 'Bài tập').toString(),
            subtitle:
                '${(e['courseName'] ?? '').toString()} • ${(e['classCode'] ?? '').toString()}',
            right: _formatDeadlineText(e['deadline']),
            rightColor: _deadlineColor(e['deadline']),
            iconBg: const Color(0xFFFFF3D6),
            icon: Icons.assignment_rounded,
            iconColor: const Color(0xFFE0A100),
          ),
        )
        .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: _primary),
              ),
              const SizedBox(width: 10),
              const Text(
                "StuEdu",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpenNotifications,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF3FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 11,
                              height: 11,
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
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarView(avatarUrl: avatarUrl, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Xin chào, $fullName!",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$major • $year",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _StatCardSmall(
                  icon: Icons.star_rounded,
                  iconColor: _primary,
                  label: "GPA",
                  value: gpa,
                  barValue: (gpaRaw / 4).clamp(0, 1),
                  onTap: onOpenGpaProgress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCardSmall(
                  icon: Icons.menu_book_rounded,
                  iconColor: _primary,
                  label: "TÍN CHỈ",
                  value: "$registeredCredits/$totalMajorCredits",
                  barValue: _buildCreditsProgress(
                    registeredCredits,
                    totalMajorCredits,
                  ),
                  onTap: onOpenCreditProgress,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _AttendanceCard(
            title: "Lớp đang học",
            percentText: approvedClassCount,
            barValue: 1,
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Text(
                "Thời khóa biểu hôm nay:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _ActionButton(text: "Chi tiết", onPressed: onOpenScheduleDetail),
            ],
          ),

          const SizedBox(height: 10),
          if (scheduleItems.isEmpty)
            const _EmptyCard(message: 'Hôm nay không có thời khóa biểu')
          else
            for (final item in scheduleItems) ...[
              _ScheduleCard(item: item),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 8),

          Row(
            children: [
              const Text(
                "Hạn nộp bài tập:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _ActionButton(
                text: "Chi tiết",
                onPressed: onOpenAssignmentsDetail,
              ),
            ],
          ),

          const SizedBox(height: 10),
          if (deadlineItems.isEmpty)
            const _EmptyCard(message: 'Không có deadline sắp tới')
          else
            for (final d in deadlineItems) ...[
              _DeadlineCard(item: d),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static double _buildCreditsProgress(String done, String total) {
    final d = double.tryParse(done) ?? 0;
    final t = double.tryParse(total) ?? 0;
    if (t <= 0) return 0;
    return (d / t).clamp(0, 1);
  }

  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r"\s+"));
    return parts.isEmpty ? "Student" : parts.first;
  }

  static String _formatTimeRange(String start, String end) {
    if (start.isEmpty && end.isEmpty) return '--:--';
    if (end.isEmpty) return start;
    return '$start\n$end';
  }

  static String _buildScheduleTag(Map<String, dynamic> item) {
    final start = (item['startTime'] ?? '').toString();
    if (start.isEmpty) return 'TODAY';

    final hour = int.tryParse(start.split(':').first) ?? 0;
    if (hour < 12) return 'MORNING';
    if (hour < 18) return 'AFTERNOON';
    return 'EVENING';
  }

  static String _formatDeadlineText(dynamic raw) {
    if (raw == null) return 'Chưa có hạn';

    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'Chưa có hạn';

    final local = dt.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final dayDiff = targetDay.difference(today).inDays;

    if (local.isBefore(now)) {
      return 'Đã quá hạn';
    }

    if (dayDiff == 0) {
      return 'Hôm nay, ${_two(local.hour)}:${_two(local.minute)}';
    }

    if (dayDiff == 1) {
      return 'Ngày mai, ${_two(local.hour)}:${_two(local.minute)}';
    }

    return '${_two(local.day)}/${_two(local.month)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static Color _deadlineColor(dynamic raw) {
    if (raw == null) return Colors.black54;

    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return Colors.black54;

    final diff = dt.toLocal().difference(DateTime.now());

    if (diff.inSeconds < 0) return Colors.red;
    if (diff.inDays <= 1) return Colors.red;
    if (diff.inDays <= 3) return Colors.orange;
    return Colors.green;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _StatCardSmall extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double barValue;
  final VoidCallback? onTap;

  const _StatCardSmall({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.barValue,
    this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.6,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Colors.black38,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _MiniBar(value: barValue, color: _primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String title;
  final String percentText;
  final double barValue;

  const _AttendanceCard({
    required this.title,
    required this.percentText,
    required this.barValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF1B2A8A),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.6,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            percentText,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _MiniBar(value: barValue, color: Colors.green),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;

  const _MiniBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: Colors.black12.withOpacity(0.08),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(height: 6, color: color),
          ),
        ),
      ),
    );
  }
}

class _ScheduleItem {
  final String time;
  final String title;
  final String subtitle;
  final String tag;
  final bool muted;

  _ScheduleItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.muted = false,
  });
}

class _ScheduleCard extends StatelessWidget {
  final _ScheduleItem item;
  const _ScheduleCard({required this.item});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final opacity = item.muted ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                item.time,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(color: Colors.black54, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.tag,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineItem {
  final String title;
  final String subtitle;
  final String right;
  final Color rightColor;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;

  _DeadlineItem({
    required this.title,
    required this.subtitle,
    required this.right,
    required this.rightColor,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
  });
}

class _DeadlineCard extends StatelessWidget {
  final _DeadlineItem item;
  const _DeadlineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      item.right,
                      style: TextStyle(
                        color: item.rightColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.25),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.error_outline_rounded,
          size: 72,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Không tải được dữ liệu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
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
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.school_rounded),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_rounded),
          label: 'Courses',
        ),
        NavigationDestination(icon: Icon(Icons.star_rounded), label: 'Grades'),
        NavigationDestination(
          icon: Icon(Icons.settings_rounded),
          label: 'Setting',
        ),
      ],
    );
  }
}

class _AvatarView extends StatelessWidget {
  final String avatarUrl;
  final double size;

  const _AvatarView({required this.avatarUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF6),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: const Color(0xFF1B2A8A), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person_rounded,
                  size: 34,
                  color: Color(0xFF1B2A8A),
                );
              },
            )
          : const Icon(
              Icons.person_rounded,
              size: 34,
              color: Color(0xFF1B2A8A),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _ActionButton({required this.text, required this.onPressed});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECF6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: const [
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _primary),
            SizedBox(width: 4),
            Text(
              "Chi tiết",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
