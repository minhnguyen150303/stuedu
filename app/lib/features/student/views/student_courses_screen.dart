import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'student_classes_screen.dart';
import 'student_grades_screen.dart';
import 'student_home_screen.dart';
import 'student_settings_screen.dart';

class StudentCoursesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentCoursesScreen({super.key, required this.profile});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  static const _bg = Color(0xFFF5F7FB);

  late final StudentRepository _repo;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  int? _selectedYear;
  Map<String, dynamic>? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _loadData();
  }

  String _weekdayLabel(dynamic code) {
    final value = int.tryParse(code.toString()) ?? 0;
    switch (value) {
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

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  Widget _buildSelectedCourseInfo(Map<String, dynamic> course) {
    final classes = List<Map<String, dynamic>>.from(
      ((course['classes'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    final courseCode = (course['courseCode'] ?? '').toString();
    final courseName = (course['courseName'] ?? '').toString();
    final description = (course['description'] ?? '').toString().trim();
    final credits = _toInt(course['credits']);
    final suggestedYear = _toInt(course['suggestedYear']);
    final totalClasses = classes.length;

    final totalMaxStudents = classes.fold<int>(
      0,
      (sum, cls) => sum + _toInt(cls['maxStudents']),
    );

    final totalEnrolled = classes.fold<int>(
      0,
      (sum, cls) =>
          sum +
          _toInt(
            cls['enrolledCount'] ??
                cls['currentStudents'] ??
                cls['approvedCount'] ??
                0,
          ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseCode.isEmpty ? 'Mã môn chưa cập nhật' : courseCode,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      courseName.isEmpty ? 'Tên môn chưa cập nhật' : courseName,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.star_rounded, text: '$credits tín chỉ'),
              _InfoChip(
                icon: Icons.school_rounded,
                text: suggestedYear > 0 ? 'Năm $suggestedYear' : 'Chưa rõ năm',
              ),
              _InfoChip(
                icon: Icons.groups_rounded,
                text: '$totalClasses lớp mở',
              ),
              _InfoChip(
                icon: Icons.person_add_alt_1_rounded,
                text: totalMaxStudents > 0
                    ? '$totalEnrolled/$totalMaxStudents đã đăng ký'
                    : '$totalEnrolled đã đăng ký',
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Mô tả môn học',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF475569),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final data = await _repo.getCourseRegistrationData();

      if (!mounted) return;

      final availableYears = List<int>.from(
        ((data['availableYears'] as List?) ?? const []).map(
          (e) => (e as num).toInt(),
        ),
      );

      setState(() {
        _data = data;
        _selectedYear = availableYears.isNotEmpty ? availableYears.last : null;
        _selectedCourse = null;
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

  Future<void> _registerClass(String classId) async {
    try {
      await _repo.registerCourseClass(classId: classId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng ký thành công!')));

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng ký thất bại: $e')));
    }
  }

  List<Map<String, dynamic>> _filteredCourses() {
    final items = List<Map<String, dynamic>>.from(
      ((_data?['items'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    if (_selectedYear == null) return items;

    return items.where((item) {
      final year = (item['suggestedYear'] ?? 0) as num;
      return year.toInt() == _selectedYear;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Courses',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadData)
          : _buildContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (i) {
          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StudentHomeScreen(profile: widget.profile),
              ),
            );
            return;
          }

          if (i == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StudentClassesScreen(profile: widget.profile),
              ),
            );
            return;
          }

          if (i == 2) return;

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
          NavigationDestination(
            icon: Icon(Icons.star_rounded),
            label: 'Grades',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Setting',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final registrationEnabled = _data?['registrationEnabled'] == true;
    final message = (_data?['message'] ?? '').toString();
    final selectedSemester = Map<String, dynamic>.from(
      (_data?['selectedSemester'] as Map?) ?? const {},
    );

    final availableYears = List<int>.from(
      ((_data?['availableYears'] as List?) ?? const []).map(
        (e) => (e as num).toInt(),
      ),
    );

    final courses = _filteredCourses();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: registrationEnabled
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: registrationEnabled
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _DropdownCard<int>(
                  label: 'Năm đăng ký',
                  value: _selectedYear,
                  items: availableYears,
                  itemLabel: (x) => 'Năm $x',
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                      _selectedCourse = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Học kỳ hiện tại',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'HK${selectedSemester['termNumber'] ?? "-"} • Năm ${selectedSemester['yearNumber'] ?? "-"}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (courses.isEmpty)
            const _EmptyCard(message: 'Không có môn học phù hợp để hiển thị.')
          else ...[
            const Text(
              'Chọn môn học',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ...courses.map((course) {
              final completed = course['completed'] == true;
              final canRegister = course['canRegister'] == true;
              final enrolledStatus = (course['enrolledStatus'] ?? '')
                  .toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      _selectedCourse = course;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedCourse?['courseId'] == course['courseId']
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            _selectedCourse?['courseId'] == course['courseId']
                            ? const Color(0xFF93C5FD)
                            : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (course['courseCode'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (course['courseName'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${course['credits'] ?? 0} tín chỉ • Năm ${course['suggestedYear'] ?? "-"}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (completed)
                          const _StatusBadge(
                            text: 'Đã học xong',
                            bg: Color(0xFFDCFCE7),
                            fg: Color(0xFF166534),
                          )
                        else if (enrolledStatus == 'pending')
                          const _StatusBadge(
                            text: 'Đang chờ duyệt',
                            bg: Color(0xFFFEF3C7),
                            fg: Color(0xFF92400E),
                          )
                        else if (enrolledStatus == 'approved')
                          const _StatusBadge(
                            text: 'Đã đăng ký',
                            bg: Color(0xFFDBEAFE),
                            fg: Color(0xFF1D4ED8),
                          )
                        else if (canRegister)
                          const _StatusBadge(
                            text: 'Có thể đăng ký',
                            bg: Color(0xFFE0E7FF),
                            fg: Color(0xFF3730A3),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 18),

          if (_selectedCourse != null) ...[
            _buildSelectedCourseInfo(_selectedCourse!),
            const SizedBox(height: 18),

            const Text(
              'Chọn lớp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ...List<Map<String, dynamic>>.from(
              ((_selectedCourse!['classes'] as List?) ?? const []).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            ).map((cls) {
              final alreadyEnrolled = cls['alreadyEnrolled'] == true;

              final maxStudents = _toInt(cls['maxStudents']);
              final enrolledCount = _toInt(
                cls['enrolledCount'] ??
                    cls['currentStudents'] ??
                    cls['approvedCount'] ??
                    0,
              );
              final pendingCount = _toInt(cls['pendingCount']);
              final registeredCount = _toInt(
                cls['registeredCount'] ?? enrolledCount + pendingCount,
              );

              final isFull = maxStudents > 0 && enrolledCount >= maxStudents;
              final progressValue = maxStudents > 0
                  ? (enrolledCount / maxStudents).clamp(0.0, 1.0).toDouble()
                  : 0.0;

              final disabled =
                  (_selectedCourse!['completed'] == true) ||
                  alreadyEnrolled ||
                  isFull ||
                  !registrationEnabled;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                          Expanded(
                            child: Text(
                              (cls['classCode'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          _StatusBadge(
                            text: isFull ? 'Đã đủ sĩ số' : 'Còn chỗ',
                            bg: isFull
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            fg: isFull
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Phòng: ${(cls['room'] ?? '').toString().isEmpty ? "Chưa cập nhật" : cls['room']}',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Năm mở lớp: ${cls['yearNumber'] ?? "-"}',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        maxStudents > 0
                            ? 'Sĩ số: $enrolledCount/$maxStudents sinh viên đã đăng ký'
                            : 'Sĩ số đã đăng ký: $enrolledCount sinh viên',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Có $pendingCount sinh viên đang chờ duyệt, tổng đăng ký: $registeredCount',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (maxStudents > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFull
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ...List<Map<String, dynamic>>.from(
                        ((cls['schedule'] as List?) ?? const []).map(
                          (e) => Map<String, dynamic>.from(e as Map),
                        ),
                      ).map((s) {
                        final day = (s['dayOfWeek'] ?? '').toString();
                        final start = (s['startTime'] ?? '').toString();
                        final end = (s['endTime'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${_weekdayLabel(day)} • $start - $end',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: disabled
                              ? null
                              : () => _registerClass(
                                  (cls['id'] ?? '').toString(),
                                ),
                          child: Text(
                            alreadyEnrolled
                                ? 'Đã đăng ký lớp này'
                                : isFull
                                ? 'Lớp đã đủ sĩ số'
                                : 'Đăng ký lớp',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final void Function(T? value) onChanged;

  const _DropdownCard({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items: items.map((item) {
          return DropdownMenuItem<T>(value: item, child: Text(itemLabel(item)));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusBadge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
          'Không tải được danh sách đăng ký tín chỉ',
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
