import 'package:flutter/material.dart';
import '../view_models/teacher_home_view_model.dart';
import 'teacher_classes_screen.dart';
import 'teacher_home_screen.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'teacher_settings_screen.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final TeacherHomeViewModel? viewModel;

  const TeacherScheduleScreen({
    super.key,
    required this.profile,
    this.viewModel,
  });

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  late final TeacherHomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();

    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
    } else {
      final api = ApiClient(AppConfig.baseUrl);
      final repo = TeacherRepository(api);
      _vm = TeacherHomeViewModel(repo);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _vm.loadHome(profile: widget.profile);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final selectedItems = _vm.buildScheduleForDate(_selectedDate);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 1,
            onDestinationSelected: (index) {
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherHomeScreen(profile: widget.profile),
                  ),
                );
              } else if (index == 2) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TeacherClassesScreen(profile: widget.profile),
                  ),
                );
              } else if (index == 3) {
                Navigator.pushReplacement(
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
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F7FB),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F172A),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Thời khóa biểu',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
          body: _vm.isLoading
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
              : _buildScheduleTab(selectedItems),
        );
      },
    );
  }

  Widget _buildScheduleTab(List<Map<String, dynamic>> selectedItems) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 18),
        _buildMonthGrid(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ngày ${_selectedDate.day} tháng ${_selectedDate.month}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _visibleMonth = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                  );
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEDEBFF),
                foregroundColor: _primary,
              ),
              child: const Text(
                'Hôm nay',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (selectedItems.isEmpty)
          _buildEmptyCard()
        else
          ...selectedItems.map(_buildScheduleItemCard),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, size: 34),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Tháng ${_visibleMonth.month}, ${_visibleMonth.year}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_right_rounded, size: 34),
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final weekdayOffset = firstDay.weekday - 1; // Mon = 0
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final prevMonthDays = weekdayOffset;
    final totalCells = ((prevMonthDays + daysInMonth) / 7).ceil() * 7;

    final classDays = _vm
        .getTeachingDaysInMonth(_visibleMonth)
        .map((e) => DateTime(e.year, e.month, e.day))
        .toSet();

    const weekTitles = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: weekTitles
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          ...List.generate(totalCells ~/ 7, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNumber = cellIndex - prevMonthDays + 1;
                  final isCurrentMonth =
                      dayNumber >= 1 && dayNumber <= daysInMonth;

                  final date = isCurrentMonth
                      ? DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month,
                          dayNumber,
                        )
                      : null;

                  final isSelected =
                      date != null && _sameDate(date, _selectedDate);
                  final hasClass =
                      date != null &&
                      classDays.contains(
                        DateTime(date.year, date.month, date.day),
                      );

                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.8,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: date == null
                            ? null
                            : () {
                                setState(() {
                                  _selectedDate = date;
                                });
                              },
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE11D48)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  date == null ? '' : '${date.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: date == null
                                        ? Colors.transparent
                                        : isSelected
                                        ? Colors.white
                                        : (colIndex == 6
                                              ? const Color(0xFFE11D48)
                                              : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
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
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleItemCard(Map<String, dynamic> item) {
    final start = (item['startTime'] ?? '').toString();
    final end = (item['endTime'] ?? '').toString();
    final classCode = (item['classCode'] ?? '').toString();
    final courseName = (item['courseName'] ?? '').toString();
    final room = (item['room'] ?? '').toString();
    final session = _vm.getSessionLabel(start);
    final weekday = _weekdayTitle(_selectedDate.weekday, session);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ĐẾN',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  end,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 88,
            color: const Color(0xFFE5E7EB),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classCode.isEmpty ? courseName : '$classCode\n$courseName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        weekday,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phòng: $room',
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
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'Ngày này chưa có lịch dạy.',
        style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayTitle(int weekday, String session) {
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
}
