import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'qlsv_import_exam_schedules_screen.dart';

class QlsvExamSchedulesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const QlsvExamSchedulesScreen({super.key, required this.profile});

  @override
  State<QlsvExamSchedulesScreen> createState() =>
      _QlsvExamSchedulesScreenState();
}

class _QlsvExamSchedulesScreenState extends State<QlsvExamSchedulesScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final QlsvRepository _repo;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _examSchedules = [];
  List<Map<String, dynamic>> _classes = [];
  String _statusFilter = 'all'; // all | upcoming | finished

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final courses = await _repo.getCourses();
      final semesters = await _repo.getSemesterCycles();
      final exams = await _repo.getExamSchedules();

      // Chỉ lấy lớp active vì chỉ lớp đang học mới cần lập lịch thi
      final classes = await _repo.getClasses(adminState: 'active');

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _semesters = semesters;
        _examSchedules = exams;
        _classes = classes;
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

  String _courseName(String courseId) {
    try {
      final course = _courses.firstWhere(
        (e) => (e['id'] ?? '').toString() == courseId,
      );

      final code = (course['courseCode'] ?? '').toString();
      final name = (course['courseName'] ?? '').toString();

      return code.isEmpty ? name : '$code - $name';
    } catch (_) {
      return courseId;
    }
  }

  String _semesterName(String semesterId) {
    try {
      final s = _semesters.firstWhere(
        (e) => (e['id'] ?? '').toString() == semesterId,
      );

      final year = (s['yearNumber'] ?? '').toString();
      final term = (s['termNumber'] ?? '').toString();

      return 'Năm $year - Kỳ $term';
    } catch (_) {
      return semesterId;
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Chưa có lịch';

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  bool _isExamFinished(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  String _examStatusText(dynamic value) {
    return _isExamFinished(value) ? 'Đã thi' : 'Chưa thi';
  }

  Color _examStatusColor(dynamic value) {
    return _isExamFinished(value)
        ? const Color(0xFF64748B)
        : const Color(0xFF16A34A);
  }

  List<Map<String, dynamic>> get _filteredExamSchedules {
    if (_statusFilter == 'finished') {
      return _examSchedules
          .where((e) => _isExamFinished(e['examDate']))
          .toList();
    }

    if (_statusFilter == 'upcoming') {
      return _examSchedules
          .where((e) => !_isExamFinished(e['examDate']))
          .toList();
    }

    return _examSchedules;
  }

  Map<String, dynamic>? _findSemesterByCourse(String courseId) {
    final courseClasses = _classes
        .where((c) => (c['courseId'] ?? '').toString() == courseId)
        .toList();

    if (courseClasses.isEmpty) return null;

    courseClasses.sort((a, b) {
      final ayA = (a['academicYearSnapshot'] ?? '').toString();
      final ayB = (b['academicYearSnapshot'] ?? '').toString();

      final termA =
          int.tryParse((a['termNumberSnapshot'] ?? 0).toString()) ?? 0;
      final termB =
          int.tryParse((b['termNumberSnapshot'] ?? 0).toString()) ?? 0;

      final cmp = ayB.compareTo(ayA);
      if (cmp != 0) return cmp;

      return termB.compareTo(termA);
    });

    final semesterId = (courseClasses.first['semesterId'] ?? '').toString();

    try {
      return _semesters.firstWhere(
        (s) => (s['id'] ?? '').toString() == semesterId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _pickExamDateTime({
    required DateTime minDate,
    DateTime? initial,
  }) async {
    final safeMin = DateTime(minDate.year, minDate.month, minDate.day);
    final safeMax = safeMin.add(const Duration(days: 15));

    final safeInitial =
        initial != null &&
            !initial.isBefore(safeMin) &&
            !initial.isAfter(safeMax)
        ? initial
        : safeMin.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: safeMin,
      lastDate: safeMax,
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF3F5FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _showExamScheduleForm({Map<String, dynamic>? item}) async {
    String? selectedCourseId = (item?['courseId'] ?? '').toString().isEmpty
        ? null
        : item!['courseId'].toString();

    Map<String, dynamic>? selectedSemester;
    DateTime? minExamDate;

    void resolveSemesterAndRange() {
      if (selectedCourseId == null || selectedCourseId!.isEmpty) {
        selectedSemester = null;
        minExamDate = null;
        return;
      }

      selectedSemester = _findSemesterByCourse(selectedCourseId!);

      if (selectedSemester == null) {
        minExamDate = null;
        return;
      }

      minExamDate = _parseDate(selectedSemester!['studyEndAt']);
    }

    resolveSemesterAndRange();

    DateTime? examDate = item?['examDate'] == null
        ? null
        : DateTime.tryParse(item!['examDate'].toString())?.toLocal();

    final roomCtrl = TextEditingController(
      text: (item?['examRoom'] ?? '').toString(),
    );

    final noteCtrl = TextEditingController(
      text: (item?['note'] ?? '').toString(),
    );

    bool saving = false;

    final activeCourseIds = _classes
        .map((c) => (c['courseId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final scheduledCourseIds = _examSchedules
        .map((e) => (e['courseId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final availableCourses = _courses.where((course) {
      final id = (course['id'] ?? '').toString();

      final isActiveCourse = activeCourseIds.contains(id);
      final alreadyScheduled = scheduledCourseIds.contains(id);

      // Khi sửa lịch thi cũ thì vẫn phải hiện môn đang sửa
      final isCurrentEditingCourse = id == selectedCourseId;

      return isActiveCourse && (!alreadyScheduled || isCurrentEditingCourse);
    }).toList();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7DCE7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item == null ? 'Thêm lịch thi' : 'Sửa lịch thi',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 18),

                      DropdownButtonFormField<String>(
                        value: selectedCourseId,
                        isExpanded: true,
                        decoration: _inputDecoration('Môn học'),
                        items: availableCourses.map((course) {
                          final id = (course['id'] ?? '').toString();
                          final code = (course['courseCode'] ?? '').toString();
                          final name = (course['courseName'] ?? '').toString();

                          return DropdownMenuItem(
                            value: id,
                            child: Text(code.isEmpty ? name : '$code - $name'),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                setSheetState(() {
                                  selectedCourseId = value;
                                  resolveSemesterAndRange();
                                  examDate = null;
                                });
                              },
                      ),

                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          selectedSemester == null
                              ? 'Học kỳ: tự động xác định sau khi chọn môn học'
                              : 'Học kỳ: ${_semesterName((selectedSemester!['id'] ?? '').toString())}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),

                      if (minExamDate != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Khoảng thi: ${DateFormat('dd/MM/yyyy').format(minExamDate!)} - '
                          '${DateFormat('dd/MM/yyyy').format(minExamDate!.add(const Duration(days: 15)))}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      InkWell(
                        onTap: saving
                            ? null
                            : () async {
                                if (selectedCourseId == null ||
                                    selectedCourseId!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vui lòng chọn môn học trước',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (selectedSemester == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không tìm thấy học kỳ của môn học này',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (minExamDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không xác định được ngày kết thúc học kỳ',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final picked = await _pickExamDateTime(
                                  minDate: minExamDate!,
                                  initial: examDate,
                                );

                                if (picked != null) {
                                  setSheetState(() {
                                    examDate = picked;
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _inputDecoration('Ngày giờ thi'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  examDate == null
                                      ? 'Chọn ngày giờ thi'
                                      : DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(examDate!),
                                  style: TextStyle(
                                    color: examDate == null
                                        ? Colors.black45
                                        : Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.calendar_month_rounded),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: roomCtrl,
                        decoration: _inputDecoration('Phòng thi'),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration('Ghi chú'),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext, false),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (selectedCourseId == null ||
                                          selectedCourseId!.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Vui lòng chọn môn học',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (selectedSemester == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Không tìm thấy học kỳ của môn học này',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (examDate == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Vui lòng chọn ngày giờ thi',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (roomCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Vui lòng nhập phòng thi',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.pop(sheetContext, true);
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                              ),
                              child: Text(item == null ? 'Thêm' : 'Lưu'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      if (item == null) {
        await _repo.createExamSchedule(
          courseId: selectedCourseId!,
          semesterId: (selectedSemester!['id'] ?? '').toString(),
          examDate: examDate!,
          examRoom: roomCtrl.text.trim(),
          note: noteCtrl.text.trim(),
        );
      } else {
        await _repo.updateExamSchedule(
          id: item['id'].toString(),
          courseId: selectedCourseId!,
          semesterId: (selectedSemester!['id'] ?? '').toString(),
          examDate: examDate!,
          examRoom: roomCtrl.text.trim(),
          note: noteCtrl.text.trim(),
        );
      }

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Đã thêm lịch thi' : 'Đã cập nhật lịch thi',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteExamSchedule(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch thi'),
        content: const Text('Bạn có chắc muốn xóa lịch thi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.deleteExamSchedule(id);
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa lịch thi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa lịch thi lỗi: $e')));
    }
  }

  Widget _buildStatusFilterBar() {
    final total = _examSchedules.length;
    final upcoming = _examSchedules
        .where((e) => !_isExamFinished(e['examDate']))
        .length;
    final finished = _examSchedules
        .where((e) => _isExamFinished(e['examDate']))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _StatusFilterChip(
            text: 'Tất cả',
            count: total,
            selected: _statusFilter == 'all',
            color: _primary,
            onTap: () => setState(() => _statusFilter = 'all'),
          ),
          _StatusFilterChip(
            text: 'Chưa thi',
            count: upcoming,
            selected: _statusFilter == 'upcoming',
            color: const Color(0xFF16A34A),
            onTap: () => setState(() => _statusFilter = 'upcoming'),
          ),
          _StatusFilterChip(
            text: 'Đã thi',
            count: finished,
            selected: _statusFilter == 'finished',
            color: const Color(0xFF64748B),
            onTap: () => setState(() => _statusFilter = 'finished'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Quản lý lịch thi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import_exam_excel',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const QlsvImportExamSchedulesScreen(),
                ),
              );

              if (changed == true) {
                await _loadData();
              }
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import Excel'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_exam_schedule',
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            onPressed: () => _showExamScheduleForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm lịch thi'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildStatusFilterBar(),
                  Expanded(
                    child: _filteredExamSchedules.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              _EmptyCard(
                                message: _statusFilter == 'upcoming'
                                    ? 'Không có lịch thi chưa thi'
                                    : _statusFilter == 'finished'
                                    ? 'Không có lịch thi đã thi'
                                    : 'Chưa có lịch thi nào',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                            itemCount: _filteredExamSchedules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredExamSchedules[index];

                              final courseId = (item['courseId'] ?? '')
                                  .toString();
                              final semesterId = (item['semesterId'] ?? '')
                                  .toString();

                              return _ExamCard(
                                courseName: _courseName(courseId),
                                semesterName: _semesterName(semesterId),
                                examDate: _formatDateTime(item['examDate']),
                                room: (item['examRoom'] ?? '').toString(),
                                note: (item['note'] ?? '').toString(),
                                statusText: _examStatusText(item['examDate']),
                                statusColor: _examStatusColor(item['examDate']),
                                isFinished: _isExamFinished(item['examDate']),
                                onEdit: () => _showExamScheduleForm(item: item),
                                onDelete: () => _deleteExamSchedule(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final String courseName;
  final String semesterName;
  final String examDate;
  final String room;
  final String note;
  final String statusText;
  final Color statusColor;
  final bool isFinished;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExamCard({
    required this.courseName,
    required this.semesterName,
    required this.examDate,
    required this.room,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.statusText,
    required this.statusColor,
    required this.isFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFinished ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFinished ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFinished
                      ? Icons.event_available_rounded
                      : Icons.event_note_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.22)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            semesterName,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thời gian thi: $examDate',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Phòng thi: ${room.isEmpty ? 'Chưa cập nhật' : room}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú: $note',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String text;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.text,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
