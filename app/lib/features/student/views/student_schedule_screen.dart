import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class StudentScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentScheduleScreen({super.key, required this.profile});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF2D3FA8);
  static const _bg = Color(0xFFF6F7FB);

  late final StudentRepository _repo;
  late final TabController _tabController;

  bool _loadingWeek = true;
  String? _errorWeek;
  Map<String, dynamic>? _weekData;
  int _selectedDayIndex = 0;

  bool _loadingMonth = true;
  String? _errorMonth;
  Map<String, dynamic>? _monthData;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedMonthDate;

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _tabController = TabController(length: 2, vsync: this);
    _loadWeek();
    _loadMonth(month: _visibleMonth);
  }

  Future<void> _loadWeek({DateTime? date}) async {
    setState(() {
      _loadingWeek = true;
      _errorWeek = null;
    });

    try {
      final data = await _repo.getWeeklySchedule(date: date?.toIso8601String());

      if (!mounted) return;

      final days = List<Map<String, dynamic>>.from(
        ((data['days'] as List?) ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      int selected = 0;
      final today = DateTime.now();

      for (int i = 0; i < days.length; i++) {
        final dt = DateTime.tryParse(
          (days[i]['date'] ?? '').toString(),
        )?.toLocal();
        if (dt != null &&
            dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          selected = i;
          break;
        }
      }

      setState(() {
        _weekData = data;
        _selectedDayIndex = selected;
        _loadingWeek = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorWeek = e.toString();
        _loadingWeek = false;
      });
    }
  }

  Future<void> _loadMonth({DateTime? month}) async {
    final target = month ?? _visibleMonth;

    setState(() {
      _loadingMonth = true;
      _errorMonth = null;
      _visibleMonth = DateTime(target.year, target.month);
    });

    try {
      final monthText =
          '${target.year}-${target.month.toString().padLeft(2, '0')}';
      final data = await _repo.getMonthlySchedule(month: monthText);

      if (!mounted) return;

      final cells = _buildMonthCells(data, _visibleMonth);
      final today = DateTime.now();

      DateTime? selected;
      if (_selectedMonthDate != null &&
          _selectedMonthDate!.year == _visibleMonth.year &&
          _selectedMonthDate!.month == _visibleMonth.month) {
        selected = _selectedMonthDate;
      } else {
        final hasToday = cells.any((e) {
          final d = e.date;
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day &&
              d.month == _visibleMonth.month;
        });

        if (hasToday &&
            today.year == _visibleMonth.year &&
            today.month == _visibleMonth.month) {
          selected = DateTime(today.year, today.month, today.day);
        } else {
          final firstCurrentMonth = cells.firstWhere(
            (e) => e.date.month == _visibleMonth.month,
            orElse: () => _MonthCellData(
              date: DateTime(_visibleMonth.year, _visibleMonth.month, 1),
              isCurrentMonth: true,
              lessons: const [],
            ),
          );
          selected = DateTime(
            firstCurrentMonth.date.year,
            firstCurrentMonth.date.month,
            firstCurrentMonth.date.day,
          );
        }
      }

      setState(() {
        _monthData = data;
        _selectedMonthDate = selected;
        _loadingMonth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMonth = e.toString();
        _loadingMonth = false;
      });
    }
  }

  void _goPrevMonth() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    _loadMonth(month: prev);
  }

  void _goNextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    _loadMonth(month: next);
  }

  void _goTodayMonth() {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month);
    _selectedMonthDate = DateTime(now.year, now.month, now.day);
    _loadMonth(month: target);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Lịch học',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: Colors.black54,
          indicatorColor: _primary,
          tabs: const [
            Tab(text: 'Lịch tuần'),
            Tab(text: 'Lịch tháng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeekTab(), _buildMonthTab()],
      ),
    );
  }

  Widget _buildWeekTab() {
    if (_loadingWeek) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorWeek != null) {
      return _ScheduleErrorView(message: _errorWeek!, onRetry: _loadWeek);
    }

    final days = List<Map<String, dynamic>>.from(
      (((_weekData?['days']) as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    if (days.isEmpty) {
      return _ScheduleErrorView(
        message: 'Không có dữ liệu lịch học',
        onRetry: _loadWeek,
      );
    }

    final selectedDay = days[_selectedDayIndex];
    final selectedDate = DateTime.tryParse(
      (selectedDay['date'] ?? '').toString(),
    )?.toLocal();

    final lessons = List<Map<String, dynamic>>.from(
      ((selectedDay['lessons'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    return RefreshIndicator(
      onRefresh: _loadWeek,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          _WeekHeader(date: selectedDate),
          const SizedBox(height: 14),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final item = days[index];
                final date = DateTime.tryParse(
                  (item['date'] ?? '').toString(),
                )?.toLocal();

                final selected = index == _selectedDayIndex;
                final hasLesson =
                    ((item['lessons'] as List?) ?? const []).isNotEmpty;

                return _WeekDayChip(
                  date: date,
                  selected: selected,
                  hasLesson: hasLesson,
                  onTap: () => setState(() => _selectedDayIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Lịch học',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 14),
          if (lessons.isEmpty)
            const _EmptyScheduleCard(message: 'Ngày này không có lịch học')
          else
            ...lessons.map((lesson) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ScheduleLessonCard(
                  startTime: (lesson['startTime'] ?? '').toString(),
                  endTime: (lesson['endTime'] ?? '').toString(),
                  title: _buildLessonTitle(lesson),
                  subtitle: _buildWeekLessonSubtitle(lesson),
                  isOnline: _isOnlineLesson(lesson),
                  isLive: _isLiveLesson(lesson),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMonthTab() {
    if (_loadingMonth) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMonth != null) {
      return _ScheduleErrorView(
        message: _errorMonth!,
        onRetry: () => _loadMonth(month: _visibleMonth),
      );
    }

    final cells = _buildMonthCells(_monthData, _visibleMonth);
    final selectedDate =
        _selectedMonthDate ??
        DateTime(_visibleMonth.year, _visibleMonth.month, 1);

    final selectedLessons = _lessonsOfSelectedDate(cells, selectedDate);

    return RefreshIndicator(
      onRefresh: () => _loadMonth(month: _visibleMonth),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _MonthHeader(
            month: _visibleMonth,
            onPrev: _goPrevMonth,
            onNext: _goNextMonth,
          ),
          const SizedBox(height: 16),
          const _MonthWeekdayRow(),
          const SizedBox(height: 8),
          _MonthGrid(
            cells: cells,
            visibleMonth: _visibleMonth,
            selectedDate: selectedDate,
            onSelectDate: (date) {
              setState(() {
                _selectedMonthDate = DateTime(date.year, date.month, date.day);
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngày ${selectedDate.day} tháng ${selectedDate.month}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              TextButton(
                onPressed: _goTodayMonth,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF0FF),
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Hôm nay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedLessons.isEmpty)
            const _EmptyScheduleCard(message: 'Ngày này không có lịch học')
          else
            ...selectedLessons.map((lesson) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MonthLessonCard(
                  startTime: (lesson['startTime'] ?? '').toString(),
                  endTime: (lesson['endTime'] ?? '').toString(),
                  title: _buildLessonTitle(lesson),
                  scheduleText: _buildMonthLessonScheduleText(
                    lesson,
                    selectedDate,
                  ),
                  roomText: _buildRoomText(lesson),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _lessonsOfSelectedDate(
    List<_MonthCellData> cells,
    DateTime selectedDate,
  ) {
    for (final cell in cells) {
      final d = cell.date;
      if (d.year == selectedDate.year &&
          d.month == selectedDate.month &&
          d.day == selectedDate.day) {
        return cell.lessons;
      }
    }
    return const [];
  }

  static String _buildLessonTitle(Map<String, dynamic> lesson) {
    final classCode = (lesson['classCode'] ?? '').toString().trim();
    final courseName = (lesson['courseName'] ?? 'Môn học').toString().trim();

    if (classCode.isEmpty) return courseName;
    return '$classCode - $courseName';
  }

  static String _buildWeekLessonSubtitle(Map<String, dynamic> lesson) {
    final room = (lesson['room'] ?? '').toString().trim();
    final date = DateTime.tryParse(
      (lesson['date'] ?? '').toString(),
    )?.toLocal();

    final weekday = _weekdayVi(date);
    final periodOrTime = _buildLessonTimeOrPeriodText(lesson);
    final place = _isOnlineLesson(lesson)
        ? 'Online Session'
        : (room.isNotEmpty ? room : 'Đang cập nhật');

    final parts = <String>[
      if (weekday.isNotEmpty) weekday,
      if (periodOrTime.isNotEmpty) periodOrTime,
      place,
    ];

    return parts.join(', ');
  }

  static String _buildLessonTimeOrPeriodText(Map<String, dynamic> lesson) {
    final startPeriod = lesson['startPeriod'];
    final endPeriod = lesson['endPeriod'];

    final hasStartPeriod =
        startPeriod != null && startPeriod.toString().trim().isNotEmpty;
    final hasEndPeriod =
        endPeriod != null && endPeriod.toString().trim().isNotEmpty;

    if (hasStartPeriod && hasEndPeriod) {
      return 'tiết $startPeriod-$endPeriod';
    }

    if (hasStartPeriod) {
      return 'tiết $startPeriod';
    }

    final start = (lesson['startTime'] ?? '').toString().trim();
    final end = (lesson['endTime'] ?? '').toString().trim();
    final timeRange = _formatTimeRange(start, end);

    return timeRange;
  }

  static String _buildMonthLessonScheduleText(
    Map<String, dynamic> lesson,
    DateTime selectedDate,
  ) {
    final weekday = _weekdayVi(selectedDate);
    final start = (lesson['startTime'] ?? '').toString().trim();
    final end = (lesson['endTime'] ?? '').toString().trim();

    final timeRange = _formatTimeRange(start, end);

    final parts = <String>[
      if (weekday.isNotEmpty) weekday,
      if (timeRange.isNotEmpty) timeRange,
    ];

    return parts.join(', ');
  }

  static String _formatHourText(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.isEmpty) return time;

    final hour = int.tryParse(parts[0]);
    if (hour == null) return time;

    return '${hour}h';
  }

  static String _formatTimeRange(String start, String end) {
    final startText = _formatHourText(start);
    final endText = _formatHourText(end);

    if (startText.isNotEmpty && endText.isNotEmpty) {
      return '$startText-$endText';
    }
    if (startText.isNotEmpty) return startText;
    if (endText.isNotEmpty) return endText;
    return '';
  }

  static String _buildRoomText(Map<String, dynamic> lesson) {
    final room = (lesson['room'] ?? '').toString().trim();
    if (_isOnlineLesson(lesson)) return 'Online Session';
    if (room.isEmpty) return 'Đang cập nhật phòng';
    return 'Phòng: $room';
  }

  static String _buildPeriodText(Map<String, dynamic> lesson) {
    final startPeriod = lesson['startPeriod'];
    final endPeriod = lesson['endPeriod'];

    if (startPeriod != null && endPeriod != null) {
      return 'tiết $startPeriod-$endPeriod';
    }

    final period = (lesson['period'] ?? '').toString().trim();
    if (period.isNotEmpty) return 'tiết $period';

    return '';
  }

  static bool _isOnlineLesson(Map<String, dynamic> lesson) {
    final room = (lesson['room'] ?? '').toString().toLowerCase();
    final raw = lesson.toString().toLowerCase();
    return room.contains('online') ||
        room.contains('zoom') ||
        room.contains('meet') ||
        raw.contains('online');
  }

  static bool _isLiveLesson(Map<String, dynamic> lesson) {
    final date = DateTime.tryParse(
      (lesson['date'] ?? '').toString(),
    )?.toLocal();
    if (date == null) return false;

    final start = _combineDateAndTime(
      date,
      (lesson['startTime'] ?? '').toString(),
    );
    final end = _combineDateAndTime(date, (lesson['endTime'] ?? '').toString());

    if (start == null || end == null) return false;

    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  static DateTime? _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String _weekdayVi(DateTime? date) {
    if (date == null) return '';
    const names = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ nhật',
    };
    return names[date.weekday] ?? '';
  }

  static String _weekdayCalendarShortVi(int weekday) {
    const names = {
      1: 'T2',
      2: 'T3',
      3: 'T4',
      4: 'T5',
      5: 'T6',
      6: 'T7',
      7: 'CN',
    };
    return names[weekday] ?? '';
  }

  static String _monthYearVi(DateTime date) {
    return 'Tháng ${date.month}, ${date.year}';
  }

  static List<_MonthCellData> _buildMonthCells(
    Map<String, dynamic>? raw,
    DateTime visibleMonth,
  ) {
    final normalized = <String, List<Map<String, dynamic>>>{};

    final dynamic daysRaw = raw?['days'] ?? raw?['dates'] ?? raw?['items'];

    if (daysRaw is List) {
      for (final entry in daysRaw) {
        if (entry is! Map) continue;
        final item = Map<String, dynamic>.from(entry);

        final dateStr = (item['date'] ?? '').toString();
        final lessons = List<Map<String, dynamic>>.from(
          ((item['lessons'] as List?) ?? const []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );

        if (dateStr.isNotEmpty) {
          normalized[_dateKey(DateTime.tryParse(dateStr)?.toLocal())] = lessons;
        }
      }
    }

    final dynamic lessonsRaw =
        raw?['lessons'] ?? raw?['events'] ?? raw?['schedules'];

    if (lessonsRaw is List) {
      for (final entry in lessonsRaw) {
        if (entry is! Map) continue;
        final lesson = Map<String, dynamic>.from(entry);
        final date = DateTime.tryParse(
          (lesson['date'] ?? '').toString(),
        )?.toLocal();
        if (date == null) continue;
        final key = _dateKey(date);
        normalized.putIfAbsent(key, () => []);
        normalized[key]!.add(lesson);
      }
    }

    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final start = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );

    final lastOfMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    final end = lastOfMonth.add(Duration(days: 7 - lastOfMonth.weekday));

    final cells = <_MonthCellData>[];
    for (
      DateTime d = start;
      !d.isAfter(end.subtract(const Duration(days: 1)));
      d = d.add(const Duration(days: 1))
    ) {
      final date = DateTime(d.year, d.month, d.day);
      cells.add(
        _MonthCellData(
          date: date,
          isCurrentMonth: date.month == visibleMonth.month,
          lessons: normalized[_dateKey(date)] ?? const [],
        ),
      );
    }

    return cells;
  }

  static String _dateKey(DateTime? date) {
    if (date == null) return '';
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _WeekHeader extends StatelessWidget {
  final DateTime? date;

  const _WeekHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? 'Không xác định'
        : '${date!.day} Tháng ${date!.month}, ${date!.year}';

    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF2D3142),
      ),
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  final DateTime? date;
  final bool selected;
  final bool hasLesson;
  final VoidCallback onTap;

  const _WeekDayChip({
    required this.date,
    required this.selected,
    required this.hasLesson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = (date == null) ? '--' : dayNames[date!.weekday - 1];
    final day = date?.day.toString() ?? '--';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9AA1AE),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2D3FA8) : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2D3FA8).withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF4A4F5D),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasLesson ? const Color(0xFF64A8FF) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleLessonCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String title;
  final String subtitle;
  final bool isOnline;
  final bool isLive;

  const _ScheduleLessonCard({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.subtitle,
    required this.isOnline,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLive ? const Color(0xFFD8DDF8) : Colors.transparent;
    final bgColor = isLive ? const Color(0xFFF7F8FF) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  startTime.isEmpty ? '--:--' : startTime,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF31374A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 1.2,
                  height: 18,
                  color: const Color(0xFFD9DCE5),
                ),
                const SizedBox(height: 8),
                Text(
                  endTime.isEmpty ? '--:--' : endTime,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7F8796),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 70, color: const Color(0xFFE6E8EF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: Color(0xFF232734),
                        ),
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE05A6B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFFF8B8B)
                            : const Color(0xFF64A8FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isOnline
                              ? const Color(0xFFB06A6A)
                              : const Color(0xFF7E8796),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthNavButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Expanded(
          child: Center(
            child: Text(
              _StudentScheduleScreenState._monthYearVi(month),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3142),
              ),
            ),
          ),
        ),
        _MonthNavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF545B6D)),
      ),
    );
  }
}

class _MonthWeekdayRow extends StatelessWidget {
  const _MonthWeekdayRow();

  @override
  Widget build(BuildContext context) {
    final labels = List.generate(
      7,
      (index) => _StudentScheduleScreenState._weekdayCalendarShortVi(index + 1),
    );

    return Row(
      children: labels.map((label) {
        final isSunday = label == 'CN';
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSunday
                    ? const Color(0xFFE94C63)
                    : const Color(0xFFB0B6C5),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final List<_MonthCellData> cells;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const _MonthGrid({
    required this.cells,
    required this.visibleMonth,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<_MonthCellData>>[];

    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7).clamp(0, cells.length);
      rows.add(cells.sublist(i, end));
    }

    return Column(
      children: rows.map((week) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              ...week.map((cell) {
                final isSelected =
                    cell.date.year == selectedDate.year &&
                    cell.date.month == selectedDate.month &&
                    cell.date.day == selectedDate.day;

                final isSunday = cell.date.weekday == DateTime.sunday;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelectDate(cell.date),
                    child: SizedBox(
                      height: 46,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE83A63)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${cell.date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : !cell.isCurrentMonth
                                    ? const Color(0xFFD6DAE4)
                                    : isSunday
                                    ? const Color(0xFFE94C63)
                                    : const Color(0xFF31374A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: cell.lessons.isNotEmpty
                                  ? const Color(0xFF64A8FF)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              ...List.generate(
                7 - week.length,
                (_) => const Expanded(child: SizedBox(height: 46)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MonthLessonCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String title;
  final String scheduleText;
  final String roomText;

  const _MonthLessonCard({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.scheduleText,
    required this.roomText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECF3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Column(
              children: [
                Text(
                  startTime.isEmpty ? '--:--' : startTime,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4050A8),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ĐẾN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBEC4D3),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  endTime.isEmpty ? '--:--' : endTime,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4050A8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE8EAF2),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF232734),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Color(0xFF98A1B3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        scheduleText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F7787),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Color(0xFF98A1B3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        roomText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F7787),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyScheduleCard extends StatelessWidget {
  final String message;

  const _EmptyScheduleCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9ECF3)),
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

class _ScheduleErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ScheduleErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.calendar_month_rounded,
          size: 72,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Không tải được lịch học',
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

class _MonthCellData {
  final DateTime date;
  final bool isCurrentMonth;
  final List<Map<String, dynamic>> lessons;

  const _MonthCellData({
    required this.date,
    required this.isCurrentMonth,
    required this.lessons,
  });
}
