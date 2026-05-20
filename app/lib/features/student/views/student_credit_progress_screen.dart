import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class StudentCreditProgressScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentCreditProgressScreen({super.key, required this.profile});

  @override
  State<StudentCreditProgressScreen> createState() =>
      _StudentCreditProgressScreenState();
}

enum _HeatmapMode { semester, year }

class _StudentCreditProgressScreenState
    extends State<StudentCreditProgressScreen> {
  late final StudentRepository _repo;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  _HeatmapMode _heatmapMode = _HeatmapMode.semester;

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

      final data = await _repo.getCreditProgress();

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

  List<Map<String, dynamic>> get _distribution {
    return List<Map<String, dynamic>>.from(
      ((_data?['distribution'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _heatmapBySemester {
    return List<Map<String, dynamic>>.from(
      ((_data?['heatmapBySemester'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _heatmapByYear {
    return List<Map<String, dynamic>>.from(
      ((_data?['heatmapByYear'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  List<Map<String, dynamic>> get _courseDetails {
    return List<Map<String, dynamic>>.from(
      ((_data?['courseDetails'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredCredits = _toDouble(_summary['requiredCredits']);
    final earnedCredits = _toDouble(_summary['earnedCredits']);
    final inProgressCredits = _toDouble(_summary['inProgressCredits']);
    final failedCredits = _toDouble(_summary['failedCredits']);
    final notStartedCredits = _toDouble(_summary['notStartedCredits']);
    final remainingCredits = _toDouble(_summary['remainingCredits']);
    final completionPercent = _toDouble(_summary['completionPercent']);

    final heatmapItems = _heatmapMode == _HeatmapMode.semester
        ? _heatmapBySemester
        : _heatmapByYear;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Tiến độ tín chỉ',
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
                    earnedCredits: earnedCredits,
                    requiredCredits: requiredCredits,
                    completionPercent: completionPercent,
                    inProgressCredits: inProgressCredits,
                    failedCredits: failedCredits,
                  ),

                  const SizedBox(height: 16),

                  _SectionTitle(
                    title: 'Tổng quan tín chỉ',
                    subtitle:
                        'Số tín chỉ đã đạt so với tổng tín chỉ cần hoàn thành chương trình',
                  ),

                  const SizedBox(height: 10),

                  _CreditDonutCard(
                    requiredCredits: requiredCredits,
                    earnedCredits: earnedCredits,
                    inProgressCredits: inProgressCredits,
                    failedCredits: failedCredits,
                    remainingCredits: notStartedCredits,
                    completionPercent: completionPercent,
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Phân bổ tín chỉ',
                    subtitle:
                        'Đã đạt, đang học, nợ và chưa học trong toàn bộ chương trình',
                  ),

                  const SizedBox(height: 10),

                  _StackedCreditCard(
                    distribution: _distribution,
                    requiredCredits: requiredCredits,
                    earnedCredits: earnedCredits,
                    inProgressCredits: inProgressCredits,
                    failedCredits: failedCredits,
                    notStartedCredits: notStartedCredits,
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Biểu đồ tín chỉ đã đạt',
                    subtitle:
                        'So sánh số tín chỉ đã hoàn thành theo từng học kỳ hoặc từng năm',
                  ),

                  const SizedBox(height: 10),

                  _HeatmapModeSwitch(
                    value: _heatmapMode,
                    onChanged: (value) {
                      setState(() {
                        _heatmapMode = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  _CreditTimelineBarCard(
                    title: _heatmapMode == _HeatmapMode.semester
                        ? 'Tín chỉ đã đạt theo học kỳ'
                        : 'Tín chỉ đã đạt theo năm',
                    items: heatmapItems,
                  ),

                  const SizedBox(height: 18),

                  _SectionTitle(
                    title: 'Chi tiết môn học',
                    subtitle:
                        'Trạng thái tín chỉ của từng môn trong chương trình',
                  ),

                  const SizedBox(height: 10),

                  _CourseDetailCard(courses: _courseDetails),
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
}

class _HeaderCard extends StatelessWidget {
  final double earnedCredits;
  final double requiredCredits;
  final double completionPercent;
  final double inProgressCredits;
  final double failedCredits;

  const _HeaderCard({
    required this.earnedCredits,
    required this.requiredCredits,
    required this.completionPercent,
    required this.inProgressCredits,
    required this.failedCredits,
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
              Icons.menu_book_rounded,
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
                  'Tiến độ tín chỉ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(earnedCredits)}/${_fmt(requiredCredits)} tín chỉ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hoàn thành ${completionPercent.toStringAsFixed(1)}% • Đang học ${_fmt(inProgressCredits)} TC • Nợ ${_fmt(failedCredits)} TC',
                  style: const TextStyle(color: Colors.white70, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _CreditDonutCard extends StatelessWidget {
  final double requiredCredits;
  final double earnedCredits;
  final double inProgressCredits;
  final double failedCredits;
  final double remainingCredits;
  final double completionPercent;

  const _CreditDonutCard({
    required this.requiredCredits,
    required this.earnedCredits,
    required this.inProgressCredits,
    required this.failedCredits,
    required this.remainingCredits,
    required this.completionPercent,
  });

  @override
  Widget build(BuildContext context) {
    final progress = requiredCredits <= 0
        ? 0.0
        : (earnedCredits / requiredCredits).clamp(0.0, 1.0).toDouble();

    return _Card(
      child: Row(
        children: [
          _DonutChart(
            size: 142,
            progress: progress,
            color: const Color(0xFF1B2A8A),
            centerText: '${completionPercent.toStringAsFixed(0)}%',
            bottomText: '${_fmt(earnedCredits)}/${_fmt(requiredCredits)}',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _MetricLine(
                  label: 'Đã đạt',
                  value: '${_fmt(earnedCredits)} TC',
                  color: Colors.green,
                ),
                _MetricLine(
                  label: 'Đang học',
                  value: '${_fmt(inProgressCredits)} TC',
                  color: Colors.blue,
                ),
                _MetricLine(
                  label: 'Nợ',
                  value: '${_fmt(failedCredits)} TC',
                  color: Colors.red,
                ),
                _MetricLine(
                  label: 'Chưa học',
                  value: '${_fmt(remainingCredits)} TC',
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _StackedCreditCard extends StatelessWidget {
  final List<Map<String, dynamic>> distribution;
  final double requiredCredits;
  final double earnedCredits;
  final double inProgressCredits;
  final double failedCredits;
  final double notStartedCredits;

  const _StackedCreditCard({
    required this.distribution,
    required this.requiredCredits,
    required this.earnedCredits,
    required this.inProgressCredits,
    required this.failedCredits,
    required this.notStartedCredits,
  });

  @override
  Widget build(BuildContext context) {
    final items = distribution.isNotEmpty
        ? distribution
        : [
            {'key': 'earned', 'label': 'Đã đạt', 'credits': earnedCredits},
            {
              'key': 'inProgress',
              'label': 'Đang học',
              'credits': inProgressCredits,
            },
            {'key': 'failed', 'label': 'Nợ', 'credits': failedCredits},
            {
              'key': 'notStarted',
              'label': 'Chưa học',
              'credits': notStartedCredits,
            },
          ];

    final total = requiredCredits > 0
        ? requiredCredits
        : items.fold<double>(
            0,
            (sum, item) => sum + _toDouble(item['credits']),
          );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cơ cấu tín chỉ chương trình',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _StackedBar(items: items, total: total),
          const SizedBox(height: 16),
          for (final item in items) ...[
            _LegendLine(
              color: _statusColor((item['key'] ?? '').toString()),
              label: (item['label'] ?? '').toString(),
              value:
                  '${_fmt(_toDouble(item['credits']))} TC • ${_toInt(item['courseCount'])} môn',
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String key) {
    if (key == 'earned') return Colors.green;
    if (key == 'inProgress') return Colors.blue;
    if (key == 'failed') return Colors.red;
    if (key == 'notStarted') return Colors.black26;
    return const Color(0xFF1B2A8A);
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

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _StackedBar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final double total;

  const _StackedBar({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1.0 : total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 22,
        child: Row(
          children: items.map((item) {
            final key = (item['key'] ?? '').toString();
            final credits = _toDouble(item['credits']);
            final widthFactor = (credits / safeTotal)
                .clamp(0.0, 1.0)
                .toDouble();

            if (widthFactor <= 0) {
              return const SizedBox.shrink();
            }

            return Expanded(
              flex: math.max((widthFactor * 1000).round(), 1),
              child: Container(color: _statusColor(key)),
            );
          }).toList(),
        ),
      ),
    );
  }

  static Color _statusColor(String key) {
    if (key == 'earned') return Colors.green;
    if (key == 'inProgress') return Colors.blue;
    if (key == 'failed') return Colors.red;
    if (key == 'notStarted') return Colors.black26;
    return const Color(0xFF1B2A8A);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _HeatmapModeSwitch extends StatelessWidget {
  final _HeatmapMode value;
  final ValueChanged<_HeatmapMode> onChanged;

  const _HeatmapModeSwitch({required this.value, required this.onChanged});

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
              selected: value == _HeatmapMode.semester,
              onTap: () => onChanged(_HeatmapMode.semester),
            ),
          ),
          Expanded(
            child: _SwitchItem(
              text: 'Theo năm',
              selected: value == _HeatmapMode.year,
              onTap: () => onChanged(_HeatmapMode.year),
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

class _CreditTimelineBarCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _CreditTimelineBarCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(
        message: 'Chưa có dữ liệu tín chỉ đã đạt để vẽ biểu đồ.',
      );
    }

    final bars = items.map((item) {
      return _TimelineBarItem(
        label: _shortLabel((item['label'] ?? '').toString()),
        fullLabel: (item['label'] ?? '').toString(),
        credits: _toDouble(item['earnedCredits']),
        courseCount: _toInt(item['courseCount']),
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
          const SizedBox(height: 6),
          const Text(
            'Cột càng cao nghĩa là kỳ/năm đó tích lũy được nhiều tín chỉ hơn.',
            style: TextStyle(color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 18),
          SizedBox(height: 230, child: _CreditVerticalBarChart(items: bars)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bars.map((item) {
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
                  '${item.fullLabel}: ${_fmt(item.credits)} TC',
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

  static String _shortLabel(String label) {
    final parts = label.split('•').map((e) => e.trim()).toList();

    if (parts.length >= 3) {
      return '${parts[1]}\n${parts[2]}';
    }

    if (parts.length == 2) {
      return '${parts[0]}\n${parts[1]}';
    }

    if (label.length <= 10) return label;

    return '${label.substring(0, 8)}...';
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

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _TimelineBarItem {
  final String label;
  final String fullLabel;
  final double credits;
  final int courseCount;

  const _TimelineBarItem({
    required this.label,
    required this.fullLabel,
    required this.credits,
    required this.courseCount,
  });
}

class _CreditVerticalBarChart extends StatelessWidget {
  final List<_TimelineBarItem> items;

  const _CreditVerticalBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.isEmpty
        ? 1.0
        : items
              .map((e) => e.credits)
              .reduce(math.max)
              .clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: items.map((item) {
        final factor = item.credits <= 0 ? 0.04 : item.credits / maxValue;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _fmt(item.credits),
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
                const SizedBox(height: 3),
                Text(
                  '${item.courseCount} môn',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _CourseDetailCard extends StatelessWidget {
  final List<Map<String, dynamic>> courses;

  const _CourseDetailCard({required this.courses});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _EmptyCard(
        message: 'Chưa có dữ liệu môn học trong chương trình.',
      );
    }

    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < courses.length; i++) ...[
            _CourseTile(item: courses[i]),
            if (i != courses.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _CourseTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final courseName = (item['courseName'] ?? 'Môn học').toString();
    final courseCode = (item['courseCode'] ?? '').toString();
    final credits = _toDouble(item['credits']);
    final status = (item['status'] ?? '').toString();
    final statusLabel = (item['statusLabel'] ?? '').toString();
    final totalTen = item['totalTen'];

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(_statusIcon(status), color: _statusColor(status)),
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
                '$courseCode • ${_fmt(credits)} tín chỉ',
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
              statusLabel,
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
            if (totalTen != null)
              Text(
                '${_toDouble(totalTen).toStringAsFixed(1)}/10',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }

  static Color _statusColor(String status) {
    if (status == 'earned') return Colors.green;
    if (status == 'in_progress') return Colors.blue;
    if (status == 'failed') return Colors.red;
    if (status == 'not_started') return Colors.black45;
    return const Color(0xFF1B2A8A);
  }

  static IconData _statusIcon(String status) {
    if (status == 'earned') return Icons.check_rounded;
    if (status == 'in_progress') return Icons.timelapse_rounded;
    if (status == 'failed') return Icons.warning_amber_rounded;
    if (status == 'not_started') return Icons.radio_button_unchecked_rounded;
    return Icons.menu_book_rounded;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
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

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
          'Không tải được tiến độ tín chỉ',
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
