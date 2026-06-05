import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/repositories/admin_academic_repository.dart';
import '../../../../data/sources/remote/api_client.dart';
import 'class_students_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  final Map<String, dynamic> major;
  final Map<String, dynamic> semester;
  final Map<String, dynamic> course;

  const ClassManagementScreen({
    super.key,
    required this.major,
    required this.semester,
    required this.course,
  });

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminAcademicRepository _repo;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  bool get _canManageLifecycle {
    final semesterStatus = (widget.semester['status'] ?? '').toString();
    return ['upcoming', 'finished'].contains(semesterStatus);
  }

  String get _semesterStatusLabel {
    final semesterStatus = (widget.semester['status'] ?? '').toString();
    switch (semesterStatus) {
      case 'upcoming':
        return 'Học kỳ đang chuẩn bị';
      case 'registration_open':
        return 'Học kỳ đang mở đăng ký';
      case 'studying':
        return 'Học kỳ đang học';
      case 'finished':
        return 'Học kỳ đã kết thúc';
      case 'registration_closed':
        return 'Học kỳ đã đóng đăng ký';
      case 'locked':
        return 'Học kỳ bị khóa';
      default:
        return 'Trạng thái học kỳ: $semesterStatus';
    }
  }

  String get _semesterOperationalStatus {
    return (widget.semester['status'] ?? '').toString();
  }

  String _classLifecycleLabel(Map<String, dynamic> cls) {
    final adminState = (cls['adminState'] ?? 'draft').toString();

    switch (adminState) {
      case 'draft':
        return 'Chuẩn bị';
      case 'active':
        return 'Đang học';
      case 'archived':
        return 'Lịch sử';
      default:
        return 'Không rõ';
    }
  }

  Color _classLifecycleBg(Map<String, dynamic> cls) {
    final adminState = (cls['adminState'] ?? 'draft').toString();

    switch (adminState) {
      case 'draft':
        return const Color(0xFFEDEBFF);
      case 'active':
        return const Color(0xFFDBEAFE);
      case 'archived':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color _classLifecycleTextColor(Map<String, dynamic> cls) {
    final adminState = (cls['adminState'] ?? 'draft').toString();

    switch (adminState) {
      case 'draft':
        return const Color(0xFF5B21B6);
      case 'active':
        return const Color(0xFF1D4ED8);
      case 'archived':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF374151);
    }
  }

  bool _isClassVisible(Map<String, dynamic> cls) {
    return cls['isVisibleForRegistration'] != false;
  }

  bool _isLifecycleHidden(Map<String, dynamic> cls) {
    return cls['hidden'] == true || cls['isHidden'] == true;
  }

  String _visibilityLabel(Map<String, dynamic> cls) {
    final visible = _isClassVisible(cls);
    return visible ? 'Hiển thị' : 'Đã ẩn';
  }

  Color _visibilityBg(Map<String, dynamic> cls) {
    final visible = _isClassVisible(cls);
    return visible ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0);
  }

  Color _visibilityTextColor(Map<String, dynamic> cls) {
    final visible = _isClassVisible(cls);
    return visible ? const Color(0xFF166534) : const Color(0xFF475569);
  }

  String _scheduleText(List<dynamic> schedule) {
    if (schedule.isEmpty) return '--';

    final parts = schedule.map((e) {
      final item = Map<String, dynamic>.from(e as Map);
      final day = _dayLabel((item['dayOfWeek'] as num?)?.toInt());
      final start = (item['startTime'] ?? '--').toString();
      final end = (item['endTime'] ?? '--').toString();
      return '$day $start-$end';
    }).toList();

    return parts.join(' • ');
  }

  String _dayLabel(int? day) {
    switch (day) {
      case 2:
        return 'T2';
      case 3:
        return 'T3';
      case 4:
        return 'T4';
      case 5:
        return 'T5';
      case 6:
        return 'T6';
      case 7:
        return 'T7';
      case 8:
        return 'CN';
      default:
        return '--';
    }
  }

  String _safeDateTime(String? value) {
    if (value == null || value.isEmpty) return '--';
    try {
      final dt = DateTime.parse(value).toLocal();
      final d =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final t =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d • $t';
    } catch (_) {
      return '--';
    }
  }

  Future<Map<String, String>> _loadTeacherNameById() async {
    final teachers = await _repo.getTeachers();
    return <String, String>{
      for (final t in teachers)
        t['uid'].toString(): (t['fullName'] ?? 'Chưa rõ').toString(),
    };
  }

  Future<List<Map<String, dynamic>>> _loadLifecycleItems() async {
    final teacherNameById = await _loadTeacherNameById();

    final items = await _repo.getClassLifecycles(
      majorId: widget.major['id'].toString(),
      courseId: widget.course['id'].toString(),
      yearNumber: (widget.semester['yearNumber'] ?? '').toString(),
      termNumber: (widget.semester['termNumber'] ?? '').toString(),
      hidden: 'all',
    );

    final enriched = items.map((item) {
      final teacherId = (item['teacherId'] ?? '').toString();
      return {...item, 'teacherName': teacherNameById[teacherId] ?? teacherId};
    }).toList();

    enriched.sort((a, b) {
      final codeA = (a['classCode'] ?? '').toString();
      final codeB = (b['classCode'] ?? '').toString();
      return codeA.compareTo(codeB);
    });

    return enriched;
  }

  Future<List<Map<String, dynamic>>> _loadRunningClasses() async {
    final teacherNameById = await _loadTeacherNameById();

    final draftClasses = await _repo.getClasses(
      courseId: widget.course['id'].toString(),
      semesterId: widget.semester['id'].toString(),
      academicYearSnapshot: (widget.semester['academicYear'] ?? '').toString(),
      adminState: 'draft',
    );

    final activeClasses = await _repo.getClasses(
      courseId: widget.course['id'].toString(),
      semesterId: widget.semester['id'].toString(),
      academicYearSnapshot: (widget.semester['academicYear'] ?? '').toString(),
      adminState: 'active',
    );

    final classes = [...draftClasses, ...activeClasses];
    final enriched = <Map<String, dynamic>>[];

    for (final cls in classes) {
      final classId = cls['id'].toString();

      int currentStudents = 0;
      try {
        final enrollments = await _repo.getEnrollments(
          classId: classId,
          status: 'approved',
        );
        currentStudents = enrollments.length;
      } catch (_) {
        currentStudents = 0;
      }

      final teacherId = (cls['teacherId'] ?? '').toString();

      enriched.add({
        ...cls,
        'teacherName': teacherNameById[teacherId] ?? teacherId,
        'currentStudents': currentStudents,
      });
    }

    enriched.sort((a, b) {
      const rank = {'draft': 0, 'active': 1};
      final ra = rank[(a['adminState'] ?? 'draft').toString()] ?? 99;
      final rb = rank[(b['adminState'] ?? 'draft').toString()] ?? 99;
      if (ra != rb) return ra.compareTo(rb);

      final codeA = (a['classCode'] ?? '').toString();
      final codeB = (b['classCode'] ?? '').toString();
      return codeA.compareTo(codeB);
    });

    return enriched;
  }

  Future<List<Map<String, dynamic>>> _loadHistoryClasses() async {
    final teacherNameById = await _loadTeacherNameById();

    final classes = await _repo.getClasses(
      courseId: widget.course['id'].toString(),
      adminState: 'archived',
    );

    final enriched = <Map<String, dynamic>>[];

    for (final cls in classes) {
      final classId = cls['id'].toString();

      int currentStudents = 0;
      try {
        final enrollments = await _repo.getEnrollments(
          classId: classId,
          status: 'approved',
        );
        currentStudents = enrollments.length;
      } catch (_) {
        currentStudents = 0;
      }

      final teacherId = (cls['teacherId'] ?? '').toString();

      enriched.add({
        ...cls,
        'teacherName': teacherNameById[teacherId] ?? teacherId,
        'currentStudents': currentStudents,
        'academicYearSnapshot':
            (cls['academicYearSnapshot'] ??
                    widget.semester['academicYear'] ??
                    '')
                .toString(),
        'yearNumberSnapshot':
            cls['yearNumberSnapshot'] ?? widget.semester['yearNumber'],
        'termNumberSnapshot':
            cls['termNumberSnapshot'] ?? widget.semester['termNumber'],
      });
    }

    enriched.sort((a, b) {
      final yearA = (a['academicYearSnapshot'] ?? '').toString();
      final yearB = (b['academicYearSnapshot'] ?? '').toString();

      if (yearA != yearB) {
        return yearB.compareTo(yearA);
      }

      final termA = (a['termNumberSnapshot'] as num?)?.toInt() ?? 0;
      final termB = (b['termNumberSnapshot'] as num?)?.toInt() ?? 0;

      if (termA != termB) {
        return termB.compareTo(termA);
      }

      final dateA = (a['updatedAt'] ?? '').toString();
      final dateB = (b['updatedAt'] ?? '').toString();

      return dateB.compareTo(dateA);
    });

    return enriched;
  }

  Future<List<Map<String, dynamic>>> _loadItemsByTab() async {
    switch (_tab) {
      case 0:
        return _loadLifecycleItems();
      case 1:
        return _loadRunningClasses();
      case 2:
        return _loadHistoryClasses();
      default:
        return [];
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  void _showComingSoon(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Map<String, String> _mapLifecycleFieldErrors(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('lifecycle classcode already exists') ||
        msg.contains('classcode already exists') ||
        msg.contains('class code already exists')) {
      return {
        'classCode': 'Mã lớp đã tồn tại trong cùng môn học của học kỳ này.',
      };
    }

    if (msg.contains('room conflict')) {
      return {
        'room': 'Phòng học đã bị trùng với lớp khác trong cùng khung giờ.',
      };
    }

    if (msg.contains('teacher schedule conflict')) {
      return {
        'teacher':
            'Giảng viên đã bị trùng lịch với lớp khác trong cùng khung giờ.',
      };
    }

    if (msg.contains('same course') ||
        msg.contains('schedule conflict with another lifecycle')) {
      return {'schedule': 'Lịch học bị trùng với lớp khác của cùng môn.'};
    }

    if (msg.contains('schedule')) {
      return {'schedule': 'Lịch học bị trùng hoặc không hợp lệ.'};
    }

    if (msg.contains('semester not found')) {
      return {'submit': 'Không tìm thấy học kỳ hoặc chu kỳ học kỳ.'};
    }

    return {'submit': 'Không thể lưu lớp mẫu. Vui lòng kiểm tra lại dữ liệu.'};
  }

  Future<void> _showCreateLifecycleForm() async {
    final classCodeController = TextEditingController();
    final roomController = TextEditingController();
    final maxStudentsController = TextEditingController(text: '50');

    final Set<int> selectedDays = {2};
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String? selectedTeacherId;

    String? classCodeError;
    String? teacherError;
    String? roomError;
    String? maxStudentsError;
    String? daysError;
    String? timeError;
    String? submitError;
    bool submitting = false;

    String formatTime(TimeOfDay? t) {
      if (t == null) return '--:--';
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    Future<void> pickStartTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0),
      );

      if (picked != null) {
        setSheetState(() {
          startTime = picked;
          timeError = null;
          submitError = null;
        });
      }
    }

    Future<void> pickEndTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
      );

      if (picked != null) {
        setSheetState(() {
          endTime = picked;
          timeError = null;
          submitError = null;
        });
      }
    }

    final teachersFuture = _repo.getTeachers();

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
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: teachersFuture,
                    builder: (context, snapshot) {
                      final teachers = snapshot.data ?? [];

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7DCE7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDEFF6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.add_home_work_rounded,
                                    color: _primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Thêm lớp mẫu',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: submitting
                                      ? null
                                      : () =>
                                            Navigator.pop(sheetContext, false),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            _ClassField(
                              label: 'Mã lớp',
                              controller: classCodeController,
                              hintText: 'Ví dụ: L01',
                              errorText: classCodeError,
                              onChanged: (_) {
                                if (classCodeError != null ||
                                    submitError != null) {
                                  setSheetState(() {
                                    classCodeError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _ClassField(
                              label: 'Phòng học',
                              controller: roomController,
                              hintText: 'Ví dụ: A101',
                              errorText: roomError,
                              onChanged: (_) {
                                if (roomError != null || submitError != null) {
                                  setSheetState(() {
                                    roomError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _ClassField(
                              label: 'Sĩ số tối đa',
                              controller: maxStudentsController,
                              hintText: 'Ví dụ: 50',
                              keyboardType: TextInputType.number,
                              errorText: maxStudentsError,
                              onChanged: (_) {
                                if (maxStudentsError != null ||
                                    submitError != null) {
                                  setSheetState(() {
                                    maxStudentsError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Giảng viên',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: teacherError != null
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: teacherError != null
                                    ? const Color(0xFFFFF5F5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: teacherError != null
                                      ? Colors.red
                                      : const Color(0xFFD9DDEA),
                                  width: teacherError != null ? 1.8 : 1.4,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedTeacherId,
                                  isExpanded: true,
                                  hint: const Text('Chọn giảng viên'),
                                  items: teachers.map((t) {
                                    final uid = t['uid'].toString();
                                    final fullName =
                                        (t['fullName'] ?? 'Chưa rõ').toString();

                                    return DropdownMenuItem<String>(
                                      value: uid,
                                      child: Text(fullName),
                                    );
                                  }).toList(),
                                  onChanged:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? null
                                      : (value) {
                                          setSheetState(() {
                                            selectedTeacherId = value;
                                            teacherError = null;
                                            submitError = null;
                                          });
                                        },
                                ),
                              ),
                            ),
                            if (teacherError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  teacherError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Thứ học',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: daysError != null
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [2, 3, 4, 5, 6, 7, 8].map((day) {
                                final selected = selectedDays.contains(day);

                                return FilterChip(
                                  label: Text(_dayLabel(day)),
                                  selected: selected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      if (selected) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }

                                      daysError = null;
                                      submitError = null;
                                    });
                                  },
                                  selectedColor: const Color(0xFFEDEBFF),
                                  backgroundColor: Colors.white,
                                  checkmarkColor: _primary,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? _primary
                                        : const Color(0xFF334155),
                                    fontWeight: FontWeight.w800,
                                  ),
                                  side: BorderSide(
                                    color: daysError != null
                                        ? Colors.red
                                        : selected
                                        ? _primary
                                        : const Color(0xFFD9DDEA),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (daysError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  daysError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _SelectBox(
                                    label: 'Giờ bắt đầu',
                                    value: formatTime(startTime),
                                    onTap: () => pickStartTime(setSheetState),
                                    hasError: timeError != null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SelectBox(
                                    label: 'Giờ kết thúc',
                                    value: formatTime(endTime),
                                    onTap: () => pickEndTime(setSheetState),
                                    hasError: timeError != null,
                                  ),
                                ),
                              ],
                            ),
                            if (timeError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  timeError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            if (submitError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  submitError!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: submitting
                                        ? null
                                        : () => Navigator.pop(
                                            sheetContext,
                                            false,
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF334155),
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Hủy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: submitting
                                        ? null
                                        : () async {
                                            setSheetState(() {
                                              classCodeError = null;
                                              teacherError = null;
                                              roomError = null;
                                              maxStudentsError = null;
                                              daysError = null;
                                              timeError = null;
                                              submitError = null;
                                            });

                                            final classCode =
                                                classCodeController.text.trim();
                                            final room = roomController.text
                                                .trim();
                                            final maxStudents = int.tryParse(
                                              maxStudentsController.text.trim(),
                                            );

                                            bool hasError = false;

                                            if (classCode.isEmpty) {
                                              classCodeError =
                                                  'Vui lòng nhập mã lớp';
                                              hasError = true;
                                            }

                                            if (selectedTeacherId == null ||
                                                selectedTeacherId!.isEmpty) {
                                              teacherError =
                                                  'Vui lòng chọn giảng viên';
                                              hasError = true;
                                            }

                                            if (room.isEmpty) {
                                              roomError =
                                                  'Vui lòng nhập phòng học';
                                              hasError = true;
                                            }

                                            if (maxStudents == null ||
                                                maxStudents <= 0) {
                                              maxStudentsError =
                                                  'Sĩ số tối đa phải là số lớn hơn 0';
                                              hasError = true;
                                            }

                                            if (selectedDays.isEmpty) {
                                              daysError =
                                                  'Vui lòng chọn ít nhất 1 ngày học';
                                              hasError = true;
                                            }

                                            if (startTime == null ||
                                                endTime == null) {
                                              timeError =
                                                  'Vui lòng chọn giờ bắt đầu và kết thúc';
                                              hasError = true;
                                            } else {
                                              final start =
                                                  '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                                              final end =
                                                  '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                                              if (start.compareTo(end) >= 0) {
                                                timeError =
                                                    'Giờ bắt đầu phải nhỏ hơn giờ kết thúc';
                                                hasError = true;
                                              }
                                            }

                                            if (hasError) {
                                              setSheetState(() {});
                                              return;
                                            }

                                            final start =
                                                '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                                            final end =
                                                '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                                            try {
                                              setSheetState(
                                                () => submitting = true,
                                              );

                                              await _repo.createClassLifecycle(
                                                courseId: widget.course['id']
                                                    .toString(),
                                                teacherId: selectedTeacherId!,
                                                classCode: classCode,
                                                room: room,
                                                maxStudents: maxStudents!,
                                                schedule: selectedDays
                                                    .map(
                                                      (day) => {
                                                        'dayOfWeek': day,
                                                        'startTime': start,
                                                        'endTime': end,
                                                      },
                                                    )
                                                    .toList(),
                                                majorId: widget.major['id']
                                                    .toString(),
                                                yearNumber:
                                                    (widget.semester['yearNumber']
                                                            as num)
                                                        .toInt(),
                                                termNumber:
                                                    (widget.semester['termNumber']
                                                            as num)
                                                        .toInt(),
                                              );

                                              if (!mounted) return;
                                              Navigator.pop(sheetContext, true);
                                            } catch (e) {
                                              final fieldErrors =
                                                  _mapLifecycleFieldErrors(e);

                                              setSheetState(() {
                                                classCodeError =
                                                    fieldErrors['classCode'];
                                                teacherError =
                                                    fieldErrors['teacher'];
                                                roomError = fieldErrors['room'];
                                                daysError =
                                                    fieldErrors['schedule'];
                                                timeError =
                                                    fieldErrors['schedule'];
                                                submitError =
                                                    fieldErrors['submit'];
                                              });
                                            } finally {
                                              if (mounted) {
                                                setSheetState(
                                                  () => submitting = false,
                                                );
                                              }
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _primary,
                                      minimumSize: const Size.fromHeight(56),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: submitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Lưu lớp mẫu',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
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
              ),
            );
          },
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm lớp mẫu')));
      setState(() {});
    }
  }

  Future<void> _showEditLifecycleForm(Map<String, dynamic> cls) async {
    final classCodeController = TextEditingController(
      text: (cls['classCode'] ?? '').toString(),
    );
    final roomController = TextEditingController(
      text: (cls['room'] ?? '').toString(),
    );
    final maxStudentsController = TextEditingController(
      text: ((cls['maxStudents'] ?? 50) as num).toInt().toString(),
    );

    final rawSchedule = List<Map<String, dynamic>>.from(
      ((cls['schedule'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    final Set<int> selectedDays = rawSchedule
        .map((e) => (e['dayOfWeek'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    TimeOfDay? startTime;
    TimeOfDay? endTime;

    if (rawSchedule.isNotEmpty) {
      final first = rawSchedule.first;
      final start = (first['startTime'] ?? '').toString();
      final end = (first['endTime'] ?? '').toString();

      TimeOfDay? parseTime(String value) {
        try {
          final parts = value.split(':');
          if (parts.length != 2) return null;

          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        } catch (_) {
          return null;
        }
      }

      startTime = parseTime(start);
      endTime = parseTime(end);
    }

    String? selectedTeacherId = (cls['teacherId'] ?? '').toString();

    String? classCodeError;
    String? teacherError;
    String? roomError;
    String? maxStudentsError;
    String? daysError;
    String? timeError;
    String? submitError;
    bool submitting = false;

    String formatTime(TimeOfDay? t) {
      if (t == null) return '--:--';
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    Future<void> pickStartTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0),
      );

      if (picked != null) {
        setSheetState(() {
          startTime = picked;
          timeError = null;
          submitError = null;
        });
      }
    }

    Future<void> pickEndTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
      );

      if (picked != null) {
        setSheetState(() {
          endTime = picked;
          timeError = null;
          submitError = null;
        });
      }
    }

    final teachersFuture = _repo.getTeachers();

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
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: teachersFuture,
                    builder: (context, snapshot) {
                      final teachers = snapshot.data ?? [];

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7DCE7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDEFF6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.edit_calendar_rounded,
                                    color: _primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Sửa lớp mẫu',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: submitting
                                      ? null
                                      : () =>
                                            Navigator.pop(sheetContext, false),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            _ClassField(
                              label: 'Mã lớp',
                              controller: classCodeController,
                              hintText: 'Ví dụ: L01',
                              errorText: classCodeError,
                              onChanged: (_) {
                                if (classCodeError != null ||
                                    submitError != null) {
                                  setSheetState(() {
                                    classCodeError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _ClassField(
                              label: 'Phòng học',
                              controller: roomController,
                              hintText: 'Ví dụ: A101',
                              errorText: roomError,
                              onChanged: (_) {
                                if (roomError != null || submitError != null) {
                                  setSheetState(() {
                                    roomError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _ClassField(
                              label: 'Sĩ số tối đa',
                              controller: maxStudentsController,
                              hintText: 'Ví dụ: 50',
                              keyboardType: TextInputType.number,
                              errorText: maxStudentsError,
                              onChanged: (_) {
                                if (maxStudentsError != null ||
                                    submitError != null) {
                                  setSheetState(() {
                                    maxStudentsError = null;
                                    submitError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Giảng viên',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: teacherError != null
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: teacherError != null
                                    ? const Color(0xFFFFF5F5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: teacherError != null
                                      ? Colors.red
                                      : const Color(0xFFD9DDEA),
                                  width: teacherError != null ? 1.8 : 1.4,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      selectedTeacherId != null &&
                                          selectedTeacherId!.isNotEmpty
                                      ? selectedTeacherId
                                      : null,
                                  isExpanded: true,
                                  hint: const Text('Chọn giảng viên'),
                                  items: teachers.map((t) {
                                    final uid = t['uid'].toString();
                                    final fullName =
                                        (t['fullName'] ?? 'Chưa rõ').toString();

                                    return DropdownMenuItem<String>(
                                      value: uid,
                                      child: Text(fullName),
                                    );
                                  }).toList(),
                                  onChanged:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? null
                                      : (value) {
                                          setSheetState(() {
                                            selectedTeacherId = value;
                                            teacherError = null;
                                            submitError = null;
                                          });
                                        },
                                ),
                              ),
                            ),
                            if (teacherError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  teacherError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Thứ học',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: daysError != null
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [2, 3, 4, 5, 6, 7, 8].map((day) {
                                final selected = selectedDays.contains(day);

                                return FilterChip(
                                  label: Text(_dayLabel(day)),
                                  selected: selected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      if (selected) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }

                                      daysError = null;
                                      submitError = null;
                                    });
                                  },
                                  selectedColor: const Color(0xFFEDEBFF),
                                  backgroundColor: Colors.white,
                                  checkmarkColor: _primary,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? _primary
                                        : const Color(0xFF334155),
                                    fontWeight: FontWeight.w800,
                                  ),
                                  side: BorderSide(
                                    color: daysError != null
                                        ? Colors.red
                                        : selected
                                        ? _primary
                                        : const Color(0xFFD9DDEA),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (daysError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  daysError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _SelectBox(
                                    label: 'Giờ bắt đầu',
                                    value: formatTime(startTime),
                                    onTap: () => pickStartTime(setSheetState),
                                    hasError: timeError != null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SelectBox(
                                    label: 'Giờ kết thúc',
                                    value: formatTime(endTime),
                                    onTap: () => pickEndTime(setSheetState),
                                    hasError: timeError != null,
                                  ),
                                ),
                              ],
                            ),
                            if (timeError != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  timeError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            if (submitError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  submitError!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: submitting
                                        ? null
                                        : () => Navigator.pop(
                                            sheetContext,
                                            false,
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF334155),
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Hủy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: submitting
                                        ? null
                                        : () async {
                                            setSheetState(() {
                                              classCodeError = null;
                                              teacherError = null;
                                              roomError = null;
                                              maxStudentsError = null;
                                              daysError = null;
                                              timeError = null;
                                              submitError = null;
                                            });

                                            final classCode =
                                                classCodeController.text.trim();
                                            final room = roomController.text
                                                .trim();
                                            final maxStudents = int.tryParse(
                                              maxStudentsController.text.trim(),
                                            );

                                            bool hasError = false;

                                            if (classCode.isEmpty) {
                                              classCodeError =
                                                  'Vui lòng nhập mã lớp';
                                              hasError = true;
                                            }

                                            if (selectedTeacherId == null ||
                                                selectedTeacherId!.isEmpty) {
                                              teacherError =
                                                  'Vui lòng chọn giảng viên';
                                              hasError = true;
                                            }

                                            if (room.isEmpty) {
                                              roomError =
                                                  'Vui lòng nhập phòng học';
                                              hasError = true;
                                            }

                                            if (maxStudents == null ||
                                                maxStudents <= 0) {
                                              maxStudentsError =
                                                  'Sĩ số tối đa phải là số lớn hơn 0';
                                              hasError = true;
                                            }

                                            if (selectedDays.isEmpty) {
                                              daysError =
                                                  'Vui lòng chọn ít nhất 1 ngày học';
                                              hasError = true;
                                            }

                                            if (startTime == null ||
                                                endTime == null) {
                                              timeError =
                                                  'Vui lòng chọn giờ bắt đầu và kết thúc';
                                              hasError = true;
                                            } else {
                                              final start =
                                                  '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                                              final end =
                                                  '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                                              if (start.compareTo(end) >= 0) {
                                                timeError =
                                                    'Giờ bắt đầu phải nhỏ hơn giờ kết thúc';
                                                hasError = true;
                                              }
                                            }

                                            if (hasError) {
                                              setSheetState(() {});
                                              return;
                                            }

                                            final start =
                                                '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                                            final end =
                                                '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                                            try {
                                              setSheetState(
                                                () => submitting = true,
                                              );

                                              await _repo.updateClassLifecycle(
                                                id: cls['id'].toString(),
                                                teacherId: selectedTeacherId!,
                                                classCode: classCode,
                                                room: room,
                                                maxStudents: maxStudents!,
                                                schedule: selectedDays
                                                    .map(
                                                      (day) => {
                                                        'dayOfWeek': day,
                                                        'startTime': start,
                                                        'endTime': end,
                                                      },
                                                    )
                                                    .toList(),
                                              );

                                              if (!mounted) return;
                                              Navigator.pop(sheetContext, true);
                                            } catch (e) {
                                              final fieldErrors =
                                                  _mapLifecycleFieldErrors(e);

                                              setSheetState(() {
                                                classCodeError =
                                                    fieldErrors['classCode'];
                                                teacherError =
                                                    fieldErrors['teacher'];
                                                roomError = fieldErrors['room'];
                                                daysError =
                                                    fieldErrors['schedule'];
                                                timeError =
                                                    fieldErrors['schedule'];
                                                submitError =
                                                    fieldErrors['submit'];
                                              });
                                            } finally {
                                              if (mounted) {
                                                setSheetState(
                                                  () => submitting = false,
                                                );
                                              }
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _primary,
                                      minimumSize: const Size.fromHeight(56),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: submitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Lưu thay đổi',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
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
              ),
            );
          },
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật lớp mẫu')));
      setState(() {});
    }
  }

  Future<void> _showClassActions(Map<String, dynamic> cls) async {
    final isVisible = _isClassVisible(cls);
    final isLifecycleHidden = _isLifecycleHidden(cls);
    final isLifecycleTab = _tab == 0;
    final isRunningTab = _tab == 1;
    final isHistoryTab = _tab == 2;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFF6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: _primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tác vụ lớp ${(cls['classCode'] ?? '').toString()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isLifecycleTab && !_canManageLifecycle)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Không thể thao tác lớp mẫu trong lúc học kỳ đang học. Chỉ được tạo, sửa hoặc ẩn khi học kỳ đang chuẩn bị hoặc đã kết thúc.',
                            style: TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isLifecycleTab && !_canManageLifecycle)
                  const SizedBox(height: 10),
                if (isLifecycleTab && _canManageLifecycle)
                  _ActionTile(
                    icon: Icons.edit_rounded,
                    label: 'Sửa lớp mẫu',
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    onTap: () => Navigator.pop(sheetContext, 'editLifecycle'),
                  ),
                if (isLifecycleTab && _canManageLifecycle)
                  _ActionTile(
                    icon: isLifecycleHidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    label: isLifecycleHidden ? 'Hiện lớp mẫu' : 'Ẩn lớp mẫu',
                    color: isLifecycleHidden
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFB45309),
                    bgColor: isLifecycleHidden
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFFF4DB),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      isLifecycleHidden ? 'showLifecycle' : 'hideLifecycle',
                    ),
                  ),
                if (isRunningTab)
                  _ActionTile(
                    icon: Icons.people_alt_rounded,
                    label: 'Xem danh sách sinh viên',
                    color: const Color(0xFF1B2A8A),
                    bgColor: const Color(0xFFEDEFF6),
                    onTap: () => Navigator.pop(sheetContext, 'students'),
                  ),
                if (isRunningTab)
                  _ActionTile(
                    icon: isVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    label: isVisible ? 'Ẩn lớp' : 'Hiện lớp',
                    color: isVisible
                        ? const Color(0xFFB45309)
                        : const Color(0xFF2563EB),
                    bgColor: isVisible
                        ? const Color(0xFFFFF4DB)
                        : const Color(0xFFEFF6FF),
                    onTap: () =>
                        Navigator.pop(sheetContext, 'toggleVisibility'),
                  ),
                if (isHistoryTab)
                  _ActionTile(
                    icon: Icons.history_rounded,
                    label: 'Xem dữ liệu lịch sử',
                    color: const Color(0xFF64748B),
                    bgColor: const Color(0xFFF1F5F9),
                    onTap: () => Navigator.pop(sheetContext, 'students'),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'students':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassStudentsScreen(
              classItem: {...cls, 'courseName': widget.course['courseName']},
              semester: widget.semester,
            ),
          ),
        );
        await _refresh();
        break;

      case 'editLifecycle':
        await _showEditLifecycleForm(cls);
        break;

      case 'hideLifecycle':
        await _confirmAndRun(
          title: 'Ẩn lớp mẫu',
          content:
              'Lớp mẫu này sẽ không còn được dùng để tự động sinh lớp mới trong các chu kỳ tiếp theo.',
          actionLabel: 'Ẩn lớp mẫu',
          onConfirmed: () => _repo.hideClassLifecycle(cls['id'].toString()),
          successMessage: 'Đã ẩn lớp mẫu',
        );
        break;
      case 'showLifecycle':
        await _confirmAndRun(
          title: 'Hiện lớp mẫu',
          content:
              'Lớp mẫu này sẽ được dùng lại để tự động sinh lớp mới trong các chu kỳ tiếp theo.',
          actionLabel: 'Hiện lớp mẫu',
          onConfirmed: () => _repo.showClassLifecycle(cls['id'].toString()),
          successMessage: 'Đã hiện lớp mẫu',
        );
        break;
      case 'toggleVisibility':
        final nextValue = !_isClassVisible(cls);

        await _confirmAndRun(
          title: nextValue ? 'Hiện lớp' : 'Ẩn lớp',
          content: nextValue
              ? 'Lớp sẽ hiện lại trong danh sách để sinh viên có thể đăng ký.'
              : 'Lớp sẽ bị ẩn khỏi danh sách đăng ký của sinh viên, nhưng dữ liệu cũ vẫn được giữ lại.',
          actionLabel: nextValue ? 'Hiện lớp' : 'Ẩn lớp',
          onConfirmed: () => _repo.toggleClassVisibility(
            id: cls['id'].toString(),
            isVisibleForRegistration: nextValue,
          ),
          successMessage: nextValue ? 'Đã hiện lớp' : 'Đã ẩn lớp',
        );
        break;
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required String actionLabel,
    required Future<dynamic> Function() onConfirmed,
    required String successMessage,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCD34D),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: const Color(0xFFF8FAFC),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB45309),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    try {
      await onConfirmed();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseName = (widget.course['courseName'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: const Color(0xFFF5F7FB),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quản lý lớp học',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              courseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _canManageLifecycle
                                ? const Color(0xFFEDEBFF)
                                : const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            _canManageLifecycle
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            color: _canManageLifecycle
                                ? const Color(0xFF5B21B6)
                                : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _semesterStatusLabel,
                            style: TextStyle(
                              color: _canManageLifecycle
                                  ? const Color(0xFF5B21B6)
                                  : const Color(0xFFB45309),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2F7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _ClassTab(
                          label: 'Lớp mẫu',
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        _ClassTab(
                          label: 'Đang học',
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                        _ClassTab(
                          label: 'Lịch sử',
                          selected: _tab == 2,
                          onTap: () => setState(() => _tab = 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadItemsByTab(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  }

                  final items = snapshot.data ?? [];

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tab == 0
                                        ? 'Danh sách lớp mẫu'
                                        : _tab == 1
                                        ? 'Danh sách lớp đang học'
                                        : 'Danh sách lớp lịch sử',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${items.length.toString().padLeft(2, '0')} lớp',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_tab == 0 && _canManageLifecycle)
                              SizedBox(
                                height: 44,
                                child: FilledButton.icon(
                                  onPressed: _showCreateLifecycleForm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text(
                                    'Thêm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_tab == 0 && !_canManageLifecycle)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFB45309),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Học kỳ hiện không cho phép tạo hoặc chỉnh sửa lớp mẫu. Chỉ thao tác khi học kỳ đang chuẩn bị hoặc đã kết thúc.',
                                    style: TextStyle(
                                      color: Color(0xFF9A3412),
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.inbox_rounded,
                                  size: 44,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _tab == 0
                                      ? 'Chưa có lớp mẫu nào'
                                      : _tab == 1
                                      ? 'Chưa có lớp đang học nào'
                                      : 'Chưa có lớp lịch sử nào',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ...items.map((cls) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ClassCard(
                              cls: cls,
                              tab: _tab,
                              scheduleText: _scheduleText,
                              safeDateTime: _safeDateTime,
                              classLifecycleLabel: _classLifecycleLabel,
                              classLifecycleBg: _classLifecycleBg,
                              classLifecycleTextColor: _classLifecycleTextColor,
                              visibilityLabel: _visibilityLabel,
                              visibilityBg: _visibilityBg,
                              visibilityTextColor: _visibilityTextColor,
                              onTap: () => _showClassActions(cls),
                            ),
                          );
                        }),
                      ],
                    ),
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

class _ClassTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ClassTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: selected ? _primary : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> cls;
  final int tab;
  final String Function(List<dynamic>) scheduleText;
  final String Function(String?) safeDateTime;
  final String Function(Map<String, dynamic>) classLifecycleLabel;
  final Color Function(Map<String, dynamic>) classLifecycleBg;
  final Color Function(Map<String, dynamic>) classLifecycleTextColor;
  final String Function(Map<String, dynamic>) visibilityLabel;
  final Color Function(Map<String, dynamic>) visibilityBg;
  final Color Function(Map<String, dynamic>) visibilityTextColor;
  final VoidCallback onTap;

  const _ClassCard({
    required this.cls,
    required this.tab,
    required this.scheduleText,
    required this.safeDateTime,
    required this.classLifecycleLabel,
    required this.classLifecycleBg,
    required this.classLifecycleTextColor,
    required this.visibilityLabel,
    required this.visibilityBg,
    required this.visibilityTextColor,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final classCode = (cls['classCode'] ?? '').toString();
    final teacherName = (cls['teacherName'] ?? 'Chưa rõ').toString();
    final currentStudents = (cls['currentStudents'] as num?)?.toInt() ?? 0;
    final maxStudents = (cls['maxStudents'] as num?)?.toInt() ?? 0;
    final room = (cls['room'] ?? '--').toString();
    final schedule = List<dynamic>.from((cls['schedule'] as List?) ?? const []);
    final academicYear = (cls['academicYearSnapshot'] ?? '').toString();
    final yearNumber = cls['yearNumberSnapshot'];
    final termNumber = cls['termNumberSnapshot'];

    final historyLabelParts = <String>[];

    if (academicYear.isNotEmpty) {
      historyLabelParts.add('Năm học $academicYear');
    }

    if (yearNumber != null) {
      historyLabelParts.add('Năm $yearNumber');
    }

    if (termNumber != null) {
      historyLabelParts.add('HK$termNumber');
    }

    final historyLabel = historyLabelParts.join(' • ');
    final isLifecycleTab = tab == 0;
    final isRunningTab = tab == 1;
    final isHistoryTab = tab == 2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: _primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lớp $classCode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.meeting_room_rounded,
                  text: 'Phòng $room',
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
                _InfoChip(
                  icon: Icons.people_alt_rounded,
                  text: '$currentStudents/$maxStudents SV',
                  color: const Color(0xFF0F9B63),
                  bgColor: const Color(0xFFE7F7EE),
                ),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  text: scheduleText(schedule),
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                ),
                if (isHistoryTab && historyLabel.isNotEmpty)
                  _InfoChip(
                    icon: Icons.calendar_month_rounded,
                    text: historyLabel,
                    color: const Color(0xFF475569),
                    bgColor: const Color(0xFFF1F5F9),
                  ),
                if (isLifecycleTab &&
                    (cls['hidden'] == true || cls['isHidden'] == true))
                  const _InfoChip(
                    icon: Icons.visibility_off_rounded,
                    text: 'Đã ẩn',
                    color: Color(0xFFB45309),
                    bgColor: Color(0xFFFFF4DB),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  text: classLifecycleLabel(cls),
                  bgColor: classLifecycleBg(cls),
                  color: classLifecycleTextColor(cls),
                ),
                if (isRunningTab)
                  _StatusPill(
                    text: visibilityLabel(cls),
                    bgColor: visibilityBg(cls),
                    color: visibilityTextColor(cls),
                  ),
                if (isLifecycleTab &&
                    (cls['hidden'] == true || cls['isHidden'] == true))
                  const _StatusPill(
                    text: 'Đã ẩn',
                    bgColor: Color(0xFFFFF4DB),
                    color: Color(0xFFB45309),
                  ),
                _StatusPill(
                  text:
                      'Cập nhật: ${safeDateTime((cls['updatedAt'] ?? cls['createdAt'] ?? '').toString())}',
                  bgColor: const Color(0xFFF1F5F9),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color color;

  const _StatusPill({
    required this.text,
    required this.bgColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 64,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _ClassField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: hasError ? Colors.red : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            errorText: errorText,
            filled: true,
            fillColor: hasError ? const Color(0xFFFFF5F5) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFD9DDEA),
                width: hasError ? 1.8 : 1.4,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFD9DDEA),
                width: hasError ? 1.8 : 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1B2A8A),
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool hasError;

  const _SelectBox({
    required this.label,
    required this.value,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasError ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError ? Colors.red : const Color(0xFFD9DDEA),
            width: hasError ? 1.8 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: hasError ? Colors.red : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF1B2A8A),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
