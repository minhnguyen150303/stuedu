import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'student_home_screen.dart';
import 'student_class_detail_screen.dart';
import 'student_settings_screen.dart';
import 'student_grades_screen.dart';
import 'student_courses_screen.dart';

class StudentClassesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentClassesScreen({super.key, required this.profile});

  @override
  State<StudentClassesScreen> createState() => _StudentClassesScreenState();
}

class _StudentClassesScreenState extends State<StudentClassesScreen> {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);

  late final StudentRepository _repo;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _classes = [];

  int _tabIndex = 0; // 0 = đang học, 1 = lịch sử

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final data = await _repo.getMyClasses();

      if (!mounted) return;
      setState(() {
        _classes = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = _classes.where(_isActiveClass).toList();
    final historyItems = _classes.where((e) => !_isActiveClass(e)).toList();
    final visibleItems = _tabIndex == 0 ? activeItems : historyItems;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Lớp học của tôi',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadClasses)
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _TopSegmentTabs(
                    index: _tabIndex,
                    activeCount: activeItems.length,
                    historyCount: historyItems.length,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                  const SizedBox(height: 18),
                  if (visibleItems.isEmpty)
                    _EmptyCard(
                      message: _tabIndex == 0
                          ? 'Hiện chưa có lớp đang học.'
                          : 'Chưa có lớp trong lịch sử.',
                    )
                  else
                    ...visibleItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ClassCard(
                          profile: widget.profile,
                          item: item,
                          semesterLabel: _buildSemesterLabel(item),
                          roomText: _buildRoomText(item),
                          scheduleLines: _buildScheduleLines(item),
                          isHistory: _tabIndex == 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: _BottomNav(
        index: 1,
        onChanged: (i) {
          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StudentHomeScreen(profile: widget.profile),
              ),
            );
            return;
          }

          if (i == 1) return;

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
                builder: (_) => StudentSettingsScreen(profile: widget.profile),
              ),
            );
            return;
          }
        },
      ),
    );
  }

  bool _isActiveClass(Map<String, dynamic> item) {
    final adminState = (item['adminState'] ?? '').toString().toLowerCase();
    return adminState != 'completed' &&
        adminState != 'archived' &&
        adminState != 'cancelled';
  }

  String _buildSemesterLabel(Map<String, dynamic> item) {
    final term = item['termNumberSnapshot'];
    final year = item['academicYearSnapshot'];

    if (term != null &&
        '$term'.isNotEmpty &&
        year != null &&
        '$year'.isNotEmpty) {
      return 'HK$term • $year';
    }

    if (year != null && '$year'.isNotEmpty) {
      return '$year';
    }

    return _isActiveClass(item) ? 'ĐANG HỌC' : 'LỊCH SỬ';
  }

  String _buildRoomText(Map<String, dynamic> item) {
    final room = (item['room'] ?? '').toString().trim();
    if (room.isNotEmpty) return 'Phòng $room';
    return 'Chưa cập nhật phòng';
  }

  List<String> _buildScheduleLines(Map<String, dynamic> item) {
    final schedule = List<Map<String, dynamic>>.from(
      ((item['schedule'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    if (schedule.isEmpty) {
      return const ['Chưa có lịch học'];
    }

    schedule.sort((a, b) {
      final da = int.tryParse('${a['dayOfWeek']}') ?? 99;
      final db = int.tryParse('${b['dayOfWeek']}') ?? 99;
      if (da != db) return da.compareTo(db);

      final sa = (a['startTime'] ?? '').toString();
      final sb = (b['startTime'] ?? '').toString();
      return sa.compareTo(sb);
    });

    return schedule.map((s) {
      final day = _weekdayLabel(int.tryParse('${s['dayOfWeek']}') ?? 0);
      final start = (s['startTime'] ?? '').toString().trim();
      final end = (s['endTime'] ?? '').toString().trim();

      if (start.isEmpty && end.isEmpty) return day;
      if (end.isEmpty) return '$day • $start';
      return '$day • $start-$end';
    }).toList();
  }

  String _weekdayLabel(int code) {
    switch (code) {
      case 2:
        return 'Thứ 2';
      case 3:
        return 'Thứ 3';
      case 4:
        return 'Thứ 4';
      case 5:
        return 'Thứ 5';
      case 6:
        return 'Thứ 6';
      case 7:
        return 'Thứ 7';
      case 8:
        return 'Chủ nhật';
      default:
        return 'Chưa rõ';
    }
  }
}

class _TopSegmentTabs extends StatelessWidget {
  final int index;
  final int activeCount;
  final int historyCount;
  final ValueChanged<int> onChanged;

  const _TopSegmentTabs({
    required this.index,
    required this.activeCount,
    required this.historyCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFEFF3FA);
    const primary = Color(0xFF1B2A8A);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentItem(
              title: 'Lớp đang học',
              count: activeCount,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentItem(
              title: 'Lịch sử',
              count: historyCount,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B2A8A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? primary : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEDEBFF) : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? primary : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String semesterLabel;
  final String roomText;
  final List<String> scheduleLines;
  final bool isHistory;
  final Map<String, dynamic> profile;

  const _ClassCard({
    required this.item,
    required this.semesterLabel,
    required this.roomText,
    required this.scheduleLines,
    required this.isHistory,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final courseName = (item['courseName'] ?? 'Môn học').toString();
    final classCode = (item['classCode'] ?? '').toString();
    final credits = (item['credits'] ?? 0).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 108,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F4FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.menu_book_rounded,
              size: 42,
              color: Color(0xFF1B2A8A),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        courseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        semesterLabel,
                        style: const TextStyle(
                          color: Color(0xFF1B2A8A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  classCode.isEmpty
                      ? '$credits tín chỉ'
                      : '$classCode • $credits tín chỉ',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  roomText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                ...scheduleLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentClassDetailScreen(
                            profile: profile,
                            classItem: item,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isHistory ? 'Xem lại lớp' : 'Vào lớp',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'Không tải được danh sách lớp',
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
