import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'student_home_screen.dart';
import 'student_classes_screen.dart';
import 'student_settings_screen.dart';
import 'student_courses_screen.dart';
import 'student_grade_analytics_screen.dart';

class StudentGradesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentGradesScreen({super.key, required this.profile});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  static const _bg = Color(0xFFF5F7FB);
  late final StudentRepository _repo;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    try {
      final data = await _repo.getMyGrades();

      if (!mounted) return;
      setState(() {
        _grades = data;
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

  void _openGradeAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentGradeAnalyticsScreen(
          profile: widget.profile,
          grades: _grades,
        ),
      ),
    );
  }

  Color _gradeColor(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        return const Color(0xFF16A34A);
      case 'B':
        return const Color(0xFF2563EB);
      case 'C':
        return const Color(0xFFD97706);
      case 'D':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFDC2626);
    }
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
          'Grades',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: _grades.isEmpty ? null : _openGradeAnalytics,
              icon: const Icon(Icons.bar_chart_rounded, size: 20),
              label: const Text('Biểu đồ'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1B2A8A),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadGrades)
          : RefreshIndicator(
              onRefresh: _loadGrades,
              child: _grades.isEmpty
                  ? ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      children: [
                        _EmptyCard(message: 'Chưa có điểm nào được cập nhật.'),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _grades.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final item = _grades[index];
                        final letter = (item['letterGrade'] ?? 'N/A')
                            .toString();
                        final color = _gradeColor(letter);
                        final status = (item['status'] ?? '').toString();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['courseCode'] ?? 'Môn học')
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (item['courseName'] ?? 'Không rõ')
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Lớp: ${(item['classCode'] ?? '').toString()}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ScoreBox(
                                      label: 'Chuyên cần',
                                      value: '${item['scoreProcess'] ?? 0}',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ScoreBox(
                                      label: 'Giữa kỳ',
                                      value: '${item['scoreMid'] ?? 0}',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ScoreBox(
                                      label: 'Cuối kỳ',
                                      value: '${item['scoreFinal'] ?? 0}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoChip(
                                      label: 'Tín chỉ',
                                      value: '${item['credits'] ?? 0}',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _InfoChip(
                                      label: 'Hệ 4',
                                      value: '${item['gpa4'] ?? 0}',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _InfoChip(
                                      label: 'Kết quả',
                                      value: status,
                                      valueColor: status.toLowerCase() == 'pass'
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
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

          if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StudentCoursesScreen(profile: widget.profile),
              ),
            );
            return;
          }

          if (i == 3) return;

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
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: valueColor ?? const Color(0xFF0F172A),
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
          'Không tải được bảng điểm',
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
