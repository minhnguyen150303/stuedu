import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class StudentGpaProgressScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentGpaProgressScreen({super.key, required this.profile});

  @override
  State<StudentGpaProgressScreen> createState() =>
      _StudentGpaProgressScreenState();
}

enum _TrendMode { semester, year }

class _StudentGpaProgressScreenState extends State<StudentGpaProgressScreen> {
  late final StudentRepository _repo;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  _TrendMode _trendMode = _TrendMode.semester;

  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await _repo.getGpaProgress();

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _summary {
    return Map<String, dynamic>.from((_data?['summary'] as Map?) ?? const {});
  }

  List<Map<String, dynamic>> get _trendBySemester {
    return List<Map<String, dynamic>>.from(
      ((_data?['trendBySemester'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _trendByYear {
    return List<Map<String, dynamic>>.from(
      ((_data?['trendByYear'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _letterDistribution {
    return List<Map<String, dynamic>>.from(
      ((_data?['letterDistribution'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _grades {
    return List<Map<String, dynamic>>.from(
      ((_data?['grades'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gpa4 = _toDouble(_summary['gpa4']);
    final maxGpa = _toDouble(_summary['maxGpa'] ?? 4);
    final percent = _toDouble(_summary['percent']);
    final totalSubjects = _toInt(_summary['totalSubjects']);
    final passedSubjects = _toInt(_summary['passedSubjects']);
    final failedSubjects = _toInt(_summary['failedSubjects']);

    final trendItems = _trendMode == _TrendMode.semester
        ? _trendBySemester
        : _trendByYear;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Biểu đồ GPA',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                children: [
                  _HeaderCard(
                    gpa4: gpa4,
                    maxGpa: maxGpa,
                    percent: percent,
                    totalSubjects: totalSubjects,
                  ),

                  const SizedBox(height: 16),

                  _SectionTitle(
                    title: 'Tổng GPA hiện tại',
                    subtitle:
                        'GPA hiện tại đang đạt bao nhiêu phần trăm so với mức 4.0',
                  ),

                  const SizedBox(height: 10),

                  _CurrentGpaChartCard(
                    gpa4: gpa4,
                    maxGpa: maxGpa,
                    percent: percent,
                    passedSubjects: passedSubjects,
                    failedSubjects: failedSubjects,
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Xu hướng GPA',
                    subtitle: 'Xem GPA trung bình theo từng kỳ hoặc từng năm',
                  ),

                  const SizedBox(height: 10),

                  _TrendSwitch(
                    value: _trendMode,
                    onChanged: (value) {
                      setState(() {
                        _trendMode = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  _GpaLineChartCard(
                    title: _trendMode == _TrendMode.semester
                        ? 'GPA trung bình theo kỳ'
                        : 'GPA trung bình theo năm',
                    items: trendItems,
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Phân bố điểm chữ',
                    subtitle:
                        'Số lượng môn theo từng thang A, B+, B, C+, C, D+, D, F',
                  ),

                  const SizedBox(height: 10),

                  _LetterDistributionCard(items: _letterDistribution),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Chi tiết môn học',
                    subtitle: 'Danh sách các môn đã được nhập điểm',
                  ),

                  const SizedBox(height: 10),

                  _GradeListCard(grades: _grades),
                ],
              ),
            ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class _HeaderCard extends StatelessWidget {
  final double gpa4;
  final double maxGpa;
  final double percent;
  final int totalSubjects;

  const _HeaderCard({
    required this.gpa4,
    required this.maxGpa,
    required this.percent,
    required this.totalSubjects,
  });

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
              Icons.query_stats_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theo dõi GPA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatGpa(gpa4)}/${_formatGpa(maxGpa)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đạt ${percent.toStringAsFixed(0)}% mức tối đa • $totalSubjects môn đã có điểm',
                  style: const TextStyle(color: Colors.white70, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatGpa(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _CurrentGpaChartCard extends StatelessWidget {
  final double gpa4;
  final double maxGpa;
  final double percent;
  final int passedSubjects;
  final int failedSubjects;

  const _CurrentGpaChartCard({
    required this.gpa4,
    required this.maxGpa,
    required this.percent,
    required this.passedSubjects,
    required this.failedSubjects,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxGpa <= 0 ? 0.0 : (gpa4 / maxGpa).clamp(0.0, 1.0);

    return _Card(
      child: Row(
        children: [
          _DonutChart(
            size: 138,
            progress: progress,
            color: const Color(0xFF1B2A8A),
            centerText: '${percent.toStringAsFixed(0)}%',
            bottomText: '${_formatGpa(gpa4)}/4',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _MetricLine(
                  label: 'GPA hiện tại',
                  value: '${_formatGpa(gpa4)}/4',
                ),
                _MetricLine(label: 'Mức tối đa', value: '4/4'),
                _MetricLine(label: 'Môn đạt', value: passedSubjects.toString()),
                _MetricLine(
                  label: 'Môn chưa đạt',
                  value: failedSubjects.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatGpa(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _TrendSwitch extends StatelessWidget {
  final _TrendMode value;
  final ValueChanged<_TrendMode> onChanged;

  const _TrendSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchItem(
              text: 'Theo kỳ',
              selected: value == _TrendMode.semester,
              onTap: () => onChanged(_TrendMode.semester),
            ),
          ),
          Expanded(
            child: _SwitchItem(
              text: 'Theo năm',
              selected: value == _TrendMode.year,
              onTap: () => onChanged(_TrendMode.year),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SwitchItem({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? const Color(0xFF1B2A8A) : Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GpaLineChartCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _GpaLineChartCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(message: 'Chưa có dữ liệu GPA để vẽ biểu đồ.');
    }

    final points = items.map((item) {
      return _LinePoint(
        label: (item['label'] ?? '').toString(),
        value: _toDouble(item['gpa4']),
      );
    }).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: CustomPaint(
              painter: _LineChartPainter(points: points),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: points.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECF6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${p.label}: ${p.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1B2A8A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
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
}

class _LetterDistributionCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _LetterDistributionCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(message: 'Chưa có dữ liệu điểm chữ.');
    }

    final bars = items.map((item) {
      return _BarItem(
        label: (item['letter'] ?? '').toString(),
        value: _toDouble(item['count']),
      );
    }).toList();

    final total = bars.fold<double>(0, (sum, item) => sum + item.value);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số môn theo thang điểm chữ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Tổng ${total.toInt()} môn đã có điểm',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          SizedBox(height: 220, child: _BarChart(items: bars)),
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

class _GradeListCard extends StatelessWidget {
  final List<Map<String, dynamic>> grades;

  const _GradeListCard({required this.grades});

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const _EmptyCard(message: 'Chưa có môn nào được nhập điểm.');
    }

    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < grades.length; i++) ...[
            _GradeTile(item: grades[i]),
            if (i != grades.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _GradeTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final courseName = (item['courseName'] ?? 'Môn học').toString();
    final courseCode = (item['courseCode'] ?? '').toString();
    final totalTen = _toDouble(item['totalTen']);
    final gpa4 = _toDouble(item['gpa4']);
    final letter = (item['letterGrade'] ?? '').toString();

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _letterColor(letter).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              letter.isEmpty ? '-' : letter,
              style: TextStyle(
                color: _letterColor(letter),
                fontWeight: FontWeight.w900,
              ),
            ),
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
                courseCode,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${totalTen.toStringAsFixed(1)}/10',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              '${gpa4.toStringAsFixed(1)}/4',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static Color _letterColor(String letter) {
    if (letter == 'A') return Colors.green;
    if (letter == 'B+' || letter == 'B') return Colors.blue;
    if (letter == 'C+' || letter == 'C') return Colors.orange;
    if (letter == 'D+' || letter == 'D') return Colors.deepOrange;
    return Colors.red;
  }
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
        painter: _DonutPainter(progress: progress.clamp(0, 1), color: color),
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

class _LinePoint {
  final String label;
  final double value;

  const _LinePoint({required this.label, required this.value});
}

class _LineChartPainter extends CustomPainter {
  final List<_LinePoint> points;

  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final left = 34.0;
    final right = 12.0;
    final top = 18.0;
    final bottom = 44.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.black12.withOpacity(0.08)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF1B2A8A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF1B2A8A)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i <= 4; i++) {
      final y = top + chartHeight - chartHeight * i / 4;

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: i.toString(),
        style: const TextStyle(fontSize: 10, color: Colors.black45),
      );
      textPainter.layout();

      textPainter.paint(canvas, Offset(left - 24, y - textPainter.height / 2));
    }

    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    if (points.isEmpty) return;

    final offsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (points.length - 1);

      final value = points[i].value.clamp(0, 4);
      final y = top + chartHeight - (value / 4) * chartHeight;

      offsets.add(Offset(x, y));
    }

    if (offsets.length == 1) {
      canvas.drawCircle(offsets.first, 5, dotPaint);
    } else {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);

      for (int i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }

      canvas.drawPath(path, linePaint);

      for (final offset in offsets) {
        canvas.drawCircle(offset, 5, dotPaint);
        canvas.drawCircle(
          offset,
          8,
          Paint()
            ..color = const Color(0xFF1B2A8A).withOpacity(0.12)
            ..style = PaintingStyle.fill,
        );
      }
    }

    for (int i = 0; i < points.length; i++) {
      final label = _shortenLabel(points[i].label);

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout(maxWidth: 58);

      textPainter.paint(
        canvas,
        Offset(offsets[i].dx - textPainter.width / 2, top + chartHeight + 10),
      );
    }
  }

  String _shortenLabel(String label) {
    if (label.length <= 10) return label;

    final parts = label.split('•').map((e) => e.trim()).toList();

    if (parts.isNotEmpty) {
      return parts.last;
    }

    return '${label.substring(0, 8)}...';
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return true;
  }
}

class _BarItem {
  final String label;
  final double value;

  const _BarItem({required this.label, required this.value});
}

class _BarChart extends StatelessWidget {
  final List<_BarItem> items;

  const _BarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.isEmpty
        ? 1.0
        : items
              .map((e) => e.value)
              .reduce(math.max)
              .clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: items.map((item) {
        final factor = item.value <= 0 ? 0.04 : item.value / maxValue;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  item.value.toInt().toString(),
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
                      heightFactor: factor.clamp(0.04, 1.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A8A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
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

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Card(
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
        const SizedBox(height: 14),
        const Text(
          'Không tải được biểu đồ GPA',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
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
