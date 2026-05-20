import 'dart:math' as math;
import 'package:flutter/material.dart';

class StudentGradeAnalyticsScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> grades;

  const StudentGradeAnalyticsScreen({
    super.key,
    required this.profile,
    required this.grades,
  });

  static const _bg = Color(0xFFF5F7FB);
  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final stats = _GradeStats.fromGrades(grades);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        title: const Text(
          'Biểu đồ điểm',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: grades.isEmpty
          ? const _EmptyView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
              children: [
                _HeaderCard(stats: stats),
                const SizedBox(height: 16),

                const _SectionTitle(
                  title: 'Tỷ lệ môn đạt',
                  subtitle: 'Số môn đã đạt so với tổng số môn đã có điểm',
                ),
                const SizedBox(height: 10),
                _PassFailDonutCard(stats: stats),

                const SizedBox(height: 18),

                const _SectionTitle(
                  title: 'Trung bình thành phần điểm',
                  subtitle:
                      'So sánh điểm chuyên cần, giữa kỳ và cuối kỳ trên toàn bộ môn',
                ),
                const SizedBox(height: 10),
                _ComponentAverageBarCard(stats: stats),

                const SizedBox(height: 18),

                const _SectionTitle(
                  title: 'Điểm tổng từng môn',
                  subtitle: 'Cột càng cao nghĩa là điểm tổng môn đó càng tốt',
                ),
                const SizedBox(height: 10),
                _SubjectTotalBarCard(grades: grades),

                const SizedBox(height: 18),

                const _SectionTitle(
                  title: 'Môn cần cải thiện',
                  subtitle:
                      'Các môn điểm thấp, chưa đạt hoặc có điểm cuối kỳ yếu',
                ),
                const SizedBox(height: 10),
                _WeakSubjectCard(grades: grades),
              ],
            ),
    );
  }
}

class _GradeStats {
  final int totalSubjects;
  final int passedSubjects;
  final int failedSubjects;

  final double averageTen;
  final double averageGpa4;

  final double averageProcess;
  final double averageMid;
  final double averageFinal;

  const _GradeStats({
    required this.totalSubjects,
    required this.passedSubjects,
    required this.failedSubjects,
    required this.averageTen,
    required this.averageGpa4,
    required this.averageProcess,
    required this.averageMid,
    required this.averageFinal,
  });

  factory _GradeStats.fromGrades(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) {
      return const _GradeStats(
        totalSubjects: 0,
        passedSubjects: 0,
        failedSubjects: 0,
        averageTen: 0,
        averageGpa4: 0,
        averageProcess: 0,
        averageMid: 0,
        averageFinal: 0,
      );
    }

    double totalTen = 0;
    double totalGpa4 = 0;
    double totalProcess = 0;
    double totalMid = 0;
    double totalFinal = 0;

    int passed = 0;
    int failed = 0;

    for (final grade in grades) {
      final status = (grade['status'] ?? '').toString().toLowerCase();
      final total = _toDouble(grade['totalTen']);

      totalTen += total;
      totalGpa4 += _toDouble(grade['gpa4']);
      totalProcess += _toDouble(grade['scoreProcess']);
      totalMid += _toDouble(grade['scoreMid']);
      totalFinal += _toDouble(grade['scoreFinal']);

      if (status == 'pass' || total >= 5) {
        passed++;
      } else {
        failed++;
      }
    }

    final count = grades.length;

    return _GradeStats(
      totalSubjects: count,
      passedSubjects: passed,
      failedSubjects: failed,
      averageTen: totalTen / count,
      averageGpa4: totalGpa4 / count,
      averageProcess: totalProcess / count,
      averageMid: totalMid / count,
      averageFinal: totalFinal / count,
    );
  }

  double get passRate {
    if (totalSubjects <= 0) return 0;
    return passedSubjects / totalSubjects;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _HeaderCard extends StatelessWidget {
  final _GradeStats stats;

  const _HeaderCard({required this.stats});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phân tích điểm số',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.averageTen.toStringAsFixed(1)}/10',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GPA TB ${stats.averageGpa4.toStringAsFixed(2)}/4 • Đạt ${stats.passedSubjects} môn • Chưa đạt ${stats.failedSubjects} môn',
                  style: const TextStyle(color: Colors.white70, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassFailDonutCard extends StatelessWidget {
  final _GradeStats stats;

  const _PassFailDonutCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          _DonutChart(
            size: 138,
            progress: stats.passRate,
            color: const Color(0xFF16A34A),
            centerText: '${(stats.passRate * 100).toStringAsFixed(0)}%',
            bottomText: '${stats.passedSubjects}/${stats.totalSubjects} môn',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _MetricLine(
                  label: 'Tổng số môn',
                  value: '${stats.totalSubjects}',
                  color: const Color(0xFF1B2A8A),
                ),
                _MetricLine(
                  label: 'Đã đạt',
                  value: '${stats.passedSubjects}',
                  color: Colors.green,
                ),
                _MetricLine(
                  label: 'Chưa đạt',
                  value: '${stats.failedSubjects}',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentAverageBarCard extends StatelessWidget {
  final _GradeStats stats;

  const _ComponentAverageBarCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _BarItem(label: 'Chuyên\ncần', value: stats.averageProcess),
      _BarItem(label: 'Giữa\nkỳ', value: stats.averageMid),
      _BarItem(label: 'Cuối\nkỳ', value: stats.averageFinal),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trung bình trên thang 10',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: _ScoreBarChart(
              items: items,
              maxValue: 10,
              showCourseCount: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTotalBarCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const _SubjectTotalBarCard({required this.grades});

  @override
  Widget build(BuildContext context) {
    final sorted = [...grades];

    sorted.sort((a, b) {
      final da = DateTime.tryParse((a['updatedAt'] ?? '').toString());
      final db = DateTime.tryParse((b['updatedAt'] ?? '').toString());
      return (db ?? DateTime(1970)).compareTo(da ?? DateTime(1970));
    });

    final items = sorted.take(10).map((grade) {
      final code = (grade['courseCode'] ?? grade['classCode'] ?? 'Môn')
          .toString();

      return _BarItem(
        label: _shortCode(code),
        value: _toDouble(grade['totalTen']),
        subLabel: (grade['letterGrade'] ?? '').toString(),
      );
    }).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tối đa 10 môn gần nhất',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Dùng để so sánh nhanh môn nào đang cao hoặc thấp.',
            style: TextStyle(color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            child: _ScoreBarChart(
              items: items,
              maxValue: 10,
              showCourseCount: false,
            ),
          ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _shortCode(String value) {
    final text = value.trim();
    if (text.length <= 8) return text;
    return '${text.substring(0, 8)}...';
  }
}

class _WeakSubjectCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const _WeakSubjectCard({required this.grades});

  @override
  Widget build(BuildContext context) {
    final weak = grades.where((grade) {
      final totalTen = _toDouble(grade['totalTen']);
      final finalScore = _toDouble(grade['scoreFinal']);
      final status = (grade['status'] ?? '').toString().toLowerCase();

      return status == 'fail' || totalTen < 6.5 || finalScore < 5;
    }).toList();

    weak.sort((a, b) {
      final ta = _toDouble(a['totalTen']);
      final tb = _toDouble(b['totalTen']);
      return ta.compareTo(tb);
    });

    if (weak.isEmpty) {
      return const _Card(
        child: Text(
          'Không có môn nào cần cảnh báo. Kết quả hiện tại khá ổn.',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      );
    }

    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < weak.length; i++) ...[
            _WeakSubjectTile(item: weak[i]),
            if (i != weak.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _WeakSubjectTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _WeakSubjectTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final courseName = (item['courseName'] ?? 'Môn học').toString();
    final courseCode = (item['courseCode'] ?? '').toString();
    final totalTen = _toDouble(item['totalTen']);
    final finalScore = _toDouble(item['scoreFinal']);
    final status = (item['status'] ?? '').toString();

    final reason = _reasonText(
      totalTen: totalTen,
      finalScore: finalScore,
      status: status,
    );

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEAEA),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '$courseCode • $reason',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${totalTen.toStringAsFixed(1)}/10',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  static String _reasonText({
    required double totalTen,
    required double finalScore,
    required String status,
  }) {
    if (status.toLowerCase() == 'fail') return 'Chưa đạt';
    if (finalScore < 5) return 'Cuối kỳ yếu';
    if (totalTen < 6.5) return 'Điểm tổng thấp';
    return 'Cần chú ý';
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _ScoreBarChart extends StatelessWidget {
  final List<_BarItem> items;
  final double maxValue;
  final bool showCourseCount;

  const _ScoreBarChart({
    required this.items,
    required this.maxValue,
    required this.showCourseCount,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxValue <= 0 ? 10.0 : maxValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: items.map((item) {
        final factor = item.value <= 0 ? 0.04 : item.value / safeMax;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  item.value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: factor.clamp(0.04, 1.0).toDouble(),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A8A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if ((item.subLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subLabel!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final String? subLabel;

  const _BarItem({required this.label, required this.value, this.subLabel});
}

class _DonutChart extends StatelessWidget {
  final double size;
  final double progress;
  final Color color;
  final String centerText;
  final String bottomText;

  const _DonutChart({
    required this.size,
    required this.progress,
    required this.color,
    required this.centerText,
    required this.bottomText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          progress: progress.clamp(0, 1).toDouble(),
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bottomText,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DonutPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;

    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final bgPaint = Paint()
      ..color = Colors.black12.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Colors.black12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Chưa có điểm nào để phân tích.',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
      ),
    );
  }
}
