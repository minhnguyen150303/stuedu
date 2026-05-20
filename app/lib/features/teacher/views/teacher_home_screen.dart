import 'package:flutter/material.dart';
import 'dart:io';
import '../../auth/views/welcome_screen.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import '../view_models/teacher_home_view_model.dart';
import 'teacher_classes_screen.dart';
import 'teacher_schedule_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_settings_screen.dart';
import 'teacher_notifications_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const TeacherHomeScreen({super.key, required this.profile});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);

  late final TeacherHomeViewModel _vm;
  late final TeacherRepository _repo;
  DateTime _selectedDate = DateTime.now();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    final api = ApiClient(AppConfig.baseUrl);
    _repo = TeacherRepository(api);
    _vm = TeacherHomeViewModel(_repo);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.loadHome(profile: widget.profile);
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repo.getUnreadNotificationCount();
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
    final fullName = (widget.profile['fullName'] ?? 'Giảng viên').toString();
    final avatarUrl = (widget.profile['avatarUrl'] ?? '').toString();

    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final selectedSchedule = _vm.buildScheduleForDate(_selectedDate);

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            await _handleBackPressed();
          },
          child: Scaffold(
            backgroundColor: _bg,
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) {
                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherScheduleScreen(
                        profile: widget.profile,
                        viewModel: _vm,
                      ),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeacherClassesScreen(profile: widget.profile),
                    ),
                  );
                } else if (index == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeacherSettingsScreen(profile: widget.profile),
                    ),
                  );
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
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
            body: SafeArea(
              child: _vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _vm.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Có lỗi xảy ra:\n${_vm.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _vm.loadHome(profile: widget.profile);
                        await _loadUnreadCount();
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        children: [
                          _buildHeader(
                            fullName: fullName,
                            avatarUrl: avatarUrl,
                          ),
                          const SizedBox(height: 18),
                          _buildWeekStrip(),
                          const SizedBox(height: 28),
                          _sectionTitle('Lịch dạy'),
                          const SizedBox(height: 14),
                          if (selectedSchedule.isEmpty)
                            _buildEmptyCard('Ngày này chưa có lịch dạy.')
                          else
                            ...selectedSchedule.map(_buildScheduleCard),
                          const SizedBox(height: 28),
                          _sectionTitle('Bài nộp gần đây'),
                          const SizedBox(height: 14),
                          _buildSubmissionActivity(),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({required String fullName, required String avatarUrl}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFE9ECF6),
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person, color: _primary, size: 28)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xin chào giảng viên,',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TeacherNotificationsScreen(profile: widget.profile),
              ),
            );
            await _loadUnreadCount();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF475569),
                size: 30,
              ),
              if (_unreadCount > 0)
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
    );
  }

  Widget _buildWeekStrip() {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday % 7),
    );

    final labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullDateLabel(_selectedDate),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isSelected = _isSameDate(date, _selectedDate);
              final hasClass = _vm.buildScheduleForDate(date).isNotEmpty;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.22),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: hasClass
                              ? const Color(0xFF60A5FA)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final courseName = (item['courseName'] ?? '').toString();
    final classCode = (item['classCode'] ?? '').toString();
    final room = (item['room'] ?? '').toString();
    final start = (item['startTime'] ?? '').toString();
    final end = (item['endTime'] ?? '').toString();

    final now = TimeOfDay.now();
    final isSelectedToday = _isSameDate(_selectedDate, DateTime.now());
    final isLive = isSelectedToday && _isCurrentTimeBetween(now, start, end);
    final session = _vm.getSessionLabel(start);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLive ? const Color(0xFFC7D2FE) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Column(
              children: [
                Text(
                  start,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '|',
                    style: TextStyle(fontSize: 18, color: Color(0xFFCBD5E1)),
                  ),
                ),
                Text(
                  end,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 72,
            color: const Color(0xFFE5E7EB),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classCode.isEmpty
                            ? courseName
                            : '$classCode - $courseName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: isLive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_viDayLabel(_selectedDate.weekday, session)}, Phòng: $room',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionActivity() {
    final items = _vm.assignmentActivities;

    if (items.isEmpty) {
      return _buildEmptyCard('Chưa có sinh viên nào nộp bài gần đây.');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          final title = (item['title'] ?? 'Bài tập').toString();
          final courseName = (item['courseName'] ?? 'Lớp học').toString();
          final classCode = (item['classCode'] ?? '').toString();
          final submissionCount =
              int.tryParse((item['submissionCount'] ?? 0).toString()) ?? 0;
          final latestSubmittedAt = _formatActivityTime(
            (item['latestSubmittedAt'] ?? '').toString(),
          );

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$submissionCount sinh viên đã nộp "$title"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (classCode.isNotEmpty) classCode,
                            courseName,
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestSubmittedAt,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
      ),
    );
  }

  bool _isCurrentTimeBetween(TimeOfDay now, String start, String end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startParts = start.split(':');
    final endParts = end.split(':');

    if (startParts.length != 2 || endParts.length != 2) return false;

    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _fullDateLabel(DateTime date) {
    return 'Ngày ${date.day} tháng ${date.month}, ${date.year}';
  }

  String _viDayLabel(int weekday, String session) {
    switch (weekday) {
      case DateTime.monday:
        return '$session thứ 2';
      case DateTime.tuesday:
        return '$session thứ 3';
      case DateTime.wednesday:
        return '$session thứ 4';
      case DateTime.thursday:
        return '$session thứ 5';
      case DateTime.friday:
        return '$session thứ 6';
      case DateTime.saturday:
        return '$session thứ 7';
      default:
        return 'Chủ nhật';
    }
  }

  String _formatActivityTime(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();

    if (dt == null) return 'Vừa cập nhật';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';

    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
