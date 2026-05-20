import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/repositories/admin_academic_repository.dart';
import '../../../../data/sources/remote/api_client.dart';
import 'semester_courses_screen.dart';
import 'package:intl/intl.dart';

String formatDateVN(String? value) {
  if (value == null || value.isEmpty) return '--';
  try {
    final dt = DateTime.parse(value);
    return DateFormat('dd/MM/yyyy').format(dt);
  } catch (_) {
    return '--';
  }
}

String semesterStatusLabel(String status) {
  switch (status) {
    case 'upcoming':
      return 'Sắp mở';
    case 'registration_open':
      return 'Đang đăng ký';
    case 'registration_closed':
      return 'Đã đóng đăng ký';
    case 'studying':
      return 'Đang học';
    case 'finished':
      return 'Đã kết thúc';
    case 'locked':
      return 'Đã khóa';
    case 'inactive':
      return 'Ngưng hoạt động';
    default:
      return 'Không rõ';
  }
}

class MajorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> major;

  const MajorDetailScreen({super.key, required this.major});

  @override
  State<MajorDetailScreen> createState() => _MajorDetailScreenState();
}

class _MajorDetailScreenState extends State<MajorDetailScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminAcademicRepository _repo;

  int _tab = 1;
  List<Map<String, dynamic>> _lastCycleMaps = [];

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  Future<List<Map<String, dynamic>>> _loadSemesterCycles() {
    return _repo.getSemesterCycles(majorId: widget.major['id'].toString());
  }

  Future<List<Map<String, dynamic>>> _loadSemesterHistory() {
    return _repo.getSemesterHistory(majorId: widget.major['id'].toString());
  }

  Map<String, dynamic>? _findCycleMap(String id) {
    try {
      return _lastCycleMaps.firstWhere((e) => e['id'].toString() == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadTeachers() {
    return _repo.getTeachersByMajor(majorId: widget.major['id'].toString());
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Future<void> _toggleSemesterVisibility(Map<String, dynamic> item) async {
    final currentActive = item['isActive'] != false;
    final nextActive = !currentActive;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Hiện lại học kỳ' : 'Ẩn học kỳ'),
        content: Text(
          nextActive
              ? 'Học kỳ sẽ hiển thị lại trong danh sách hoạt động.'
              : 'Học kỳ sẽ bị ẩn khỏi vận hành hiện tại, nhưng dữ liệu cũ vẫn được giữ lại để xem lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              nextActive ? 'Hiện lại' : 'Ẩn',
              style: TextStyle(color: nextActive ? Colors.blue : Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.updateSemesterCycle(
        id: item['id'].toString(),
        isActive: nextActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextActive ? 'Đã hiện lại học kỳ' : 'Đã ẩn học kỳ'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _showSemesterCycleForm({Map<String, dynamic>? item}) async {
    final isEdit = item != null;

    int? selectedYearNumber = item != null
        ? (item['yearNumber'] as num?)?.toInt()
        : null;
    int selectedTerm = item != null
        ? (item['termNumber'] as num?)?.toInt() ?? 1
        : 1;

    int? regOpenDay;
    int? regOpenMonth;
    int? regCloseDay;
    int? regCloseMonth;
    int? studyStartDay;
    int? studyStartMonth;
    int? studyEndDay;
    int? studyEndMonth;

    if (isEdit) {
      final raw = _findCycleMap(item['id'].toString()) ?? item;

      final regOpen = DateTime.tryParse(
        (raw['registrationOpenAt'] ?? '').toString(),
      );
      final regClose = DateTime.tryParse(
        (raw['registrationCloseAt'] ?? '').toString(),
      );
      final studyStart = DateTime.tryParse(
        (raw['studyStartAt'] ?? '').toString(),
      );
      final studyEnd = DateTime.tryParse((raw['studyEndAt'] ?? '').toString());

      regOpenDay = regOpen?.day;
      regOpenMonth = regOpen?.month;
      regCloseDay = regClose?.day;
      regCloseMonth = regClose?.month;
      studyStartDay = studyStart?.day;
      studyStartMonth = studyStart?.month;
      studyEndDay = studyEnd?.day;
      studyEndMonth = studyEnd?.month;
    }

    Future<void> pickMonthDay({
      required BuildContext context,
      required int? initialDay,
      required int? initialMonth,
      required void Function(int day, int month) onPicked,
    }) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(
          now.year,
          initialMonth ?? now.month,
          initialDay ?? now.day,
        ),
        firstDate: DateTime(now.year, 1, 1),
        lastDate: DateTime(now.year, 12, 31),
      );

      if (picked != null) {
        onPicked(picked.day, picked.month);
      }
    }

    String formatMonthDay(int? day, int? month) {
      if (day == null || month == null) return '';
      return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}';
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.7,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      14,
                      20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 54,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7DCE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isEdit ? 'Sửa học kỳ' : 'Thêm học kỳ',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B2A8A),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const _SemesterFieldLabel('Năm đào tạo'),
                        const SizedBox(height: 10),
                        _SemesterDropdownField<int>(
                          hintText: 'Chọn năm đào tạo',
                          value: selectedYearNumber,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Năm 1')),
                            DropdownMenuItem(value: 2, child: Text('Năm 2')),
                            DropdownMenuItem(value: 3, child: Text('Năm 3')),
                            DropdownMenuItem(value: 4, child: Text('Năm 4')),
                            DropdownMenuItem(value: 5, child: Text('Năm 5')),
                          ],
                          onChanged: (value) {
                            setInnerState(() => selectedYearNumber = value);
                          },
                        ),

                        const SizedBox(height: 22),

                        const _SemesterFieldLabel('Học kỳ'),
                        const SizedBox(height: 10),
                        _SemesterDropdownField<int>(
                          value: selectedTerm,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Học kỳ 1')),
                            DropdownMenuItem(value: 2, child: Text('Học kỳ 2')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setInnerState(() => selectedTerm = value);
                            }
                          },
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SemesterFieldLabel('Mở đăng ký'),
                                  const SizedBox(height: 10),
                                  _SemesterDateField(
                                    value: formatMonthDay(
                                      regOpenDay,
                                      regOpenMonth,
                                    ),
                                    placeholder: 'dd/mm',
                                    onTap: () async {
                                      await pickMonthDay(
                                        context: context,
                                        initialDay: regOpenDay,
                                        initialMonth: regOpenMonth,
                                        onPicked: (day, month) {
                                          setInnerState(() {
                                            regOpenDay = day;
                                            regOpenMonth = month;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SemesterFieldLabel('Đóng đăng ký'),
                                  const SizedBox(height: 10),
                                  _SemesterDateField(
                                    value: formatMonthDay(
                                      regCloseDay,
                                      regCloseMonth,
                                    ),
                                    placeholder: 'dd/mm',
                                    onTap: () async {
                                      await pickMonthDay(
                                        context: context,
                                        initialDay: regCloseDay,
                                        initialMonth: regCloseMonth,
                                        onPicked: (day, month) {
                                          setInnerState(() {
                                            regCloseDay = day;
                                            regCloseMonth = month;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SemesterFieldLabel('Bắt đầu học'),
                                  const SizedBox(height: 10),
                                  _SemesterDateField(
                                    value: formatMonthDay(
                                      studyStartDay,
                                      studyStartMonth,
                                    ),
                                    placeholder: 'dd/mm',
                                    onTap: () async {
                                      await pickMonthDay(
                                        context: context,
                                        initialDay: studyStartDay,
                                        initialMonth: studyStartMonth,
                                        onPicked: (day, month) {
                                          setInnerState(() {
                                            studyStartDay = day;
                                            studyStartMonth = month;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SemesterFieldLabel('Kết thúc học'),
                                  const SizedBox(height: 10),
                                  _SemesterDateField(
                                    value: formatMonthDay(
                                      studyEndDay,
                                      studyEndMonth,
                                    ),
                                    placeholder: 'dd/mm',
                                    onTap: () async {
                                      await pickMonthDay(
                                        context: context,
                                        initialDay: studyEndDay,
                                        initialMonth: studyEndMonth,
                                        onPicked: (day, month) {
                                          setInnerState(() {
                                            studyEndDay = day;
                                            studyEndMonth = month;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(58),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: () {
                                  if (selectedYearNumber == null ||
                                      regOpenDay == null ||
                                      regOpenMonth == null ||
                                      regCloseDay == null ||
                                      regCloseMonth == null ||
                                      studyStartDay == null ||
                                      studyStartMonth == null ||
                                      studyEndDay == null ||
                                      studyEndMonth == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vui lòng nhập đầy đủ thông tin',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(sheetContext, true);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF232C97),
                                  minimumSize: const Size.fromHeight(58),
                                  elevation: 6,
                                  shadowColor: const Color(0x33000000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  isEdit ? 'Lưu' : 'Tạo',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
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
          },
        );
      },
    );

    if (ok != true) return;

    try {
      if (isEdit) {
        await _repo.updateSemesterCycle(
          id: item['id'].toString(),
          yearNumber: selectedYearNumber!,
          termNumber: selectedTerm,
          registrationOpenMonth: regOpenMonth!,
          registrationOpenDay: regOpenDay!,
          registrationCloseMonth: regCloseMonth!,
          registrationCloseDay: regCloseDay!,
          studyStartMonth: studyStartMonth!,
          studyStartDay: studyStartDay!,
          studyEndMonth: studyEndMonth!,
          studyEndDay: studyEndDay!,
        );
      } else {
        await _repo.createSemesterCycle(
          majorId: widget.major['id'].toString(),
          yearNumber: selectedYearNumber!,
          termNumber: selectedTerm,
          registrationOpenMonth: regOpenMonth!,
          registrationOpenDay: regOpenDay!,
          registrationCloseMonth: regCloseMonth!,
          registrationCloseDay: regCloseDay!,
          studyStartMonth: studyStartMonth!,
          studyStartDay: studyStartDay!,
          studyEndMonth: studyEndMonth!,
          studyEndDay: studyEndDay!,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Đã cập nhật học kỳ' : 'Đã thêm học kỳ'),
        ),
      );
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
    final majorName = (widget.major['name'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Học kỳ của Chuyên ngành',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$majorName  ›  Học kỳ',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _TopTab(
                        label: 'Lịch sử',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      _TopTab(
                        label: 'Danh sách Học\nkỳ',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                      _TopTab(
                        label: 'Giảng\nviên',
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _tab == 1
                  ? FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadSemesterCycles(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Lỗi: ${snapshot.error}'));
                        }

                        final semesters = snapshot.data ?? [];
                        _lastCycleMaps = List<Map<String, dynamic>>.from(
                          semesters,
                        );

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Các học kỳ đang mở',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _showSemesterCycleForm(),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFEDEBFF),
                                    foregroundColor: _primary,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm học kỳ'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (semesters.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text('Chưa có học kỳ nào'),
                                ),
                              ),
                            ...semesters.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _SemesterCard(
                                  semester: s,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SemesterCoursesScreen(
                                          major: widget.major,
                                          semester: s,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  onEdit: () => _showSemesterCycleForm(item: s),
                                  onToggleVisibility: () =>
                                      _toggleSemesterVisibility(s),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    )
                  : _tab == 0
                  ? FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadSemesterHistory(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Lỗi: ${snapshot.error}'));
                        }

                        final items = snapshot.data ?? [];

                        if (items.isEmpty) {
                          return const Center(
                            child: Text('Chưa có lịch sử học kỳ'),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                          children: items.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SemesterHistoryCard(semester: s),
                            );
                          }).toList(),
                        );
                      },
                    )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadTeachers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Lỗi: ${snapshot.error}'));
                        }

                        final teachers = snapshot.data ?? [];

                        if (teachers.isEmpty) {
                          return const Center(
                            child: Text(
                              'Chưa có giảng viên nào thuộc chuyên ngành này',
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          itemCount: teachers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final teacher = teachers[index];
                            final fullName =
                                (teacher['fullName'] ?? 'Chưa có tên')
                                    .toString();
                            final email = (teacher['email'] ?? '').toString();
                            final department = (teacher['department'] ?? '')
                                .toString();
                            final avatarUrl = (teacher['avatarUrl'] ?? '')
                                .toString();

                            final rawTeacherInfo = teacher['teacherInfo'];
                            final teacherInfo =
                                rawTeacherInfo is Map<String, dynamic>
                                ? rawTeacherInfo
                                : rawTeacherInfo is Map
                                ? Map<String, dynamic>.from(rawTeacherInfo)
                                : <String, dynamic>{};

                            final teacherCode =
                                (teacherInfo['teacherCode'] ?? '').toString();
                            final academicRank =
                                (teacherInfo['academicRank'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCE2EE),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFFEDEFF6),
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(
                                            _initials(fullName),
                                            style: const TextStyle(
                                              color: Color(0xFF1B2A8A),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (teacherCode.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Mã GV: $teacherCode',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                        if (department.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Khoa/Bộ môn: $department',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                        if (academicRank.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Học hàm/Học vị: $academicRank',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

class _TopTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopTab({
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
        child: Container(
          padding: const EdgeInsets.only(bottom: 12, top: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: selected ? _primary : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final Map<String, dynamic> semester;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleVisibility;

  const _SemesterCard({
    required this.semester,
    required this.onTap,
    required this.onEdit,
    required this.onToggleVisibility,
  });

  static const _primary = Color(0xFF1B2A8A);

  Color _statusColor(String status) {
    switch (status) {
      case 'registration_open':
        return const Color(0xFF0F9B63);
      case 'studying':
        return _primary;
      case 'finished':
        return const Color(0xFF94A3B8);
      case 'locked':
        return const Color(0xFFE53935);
      case 'upcoming':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'registration_open':
        return const Color(0xFFE7F7EE);
      case 'studying':
        return const Color(0xFFEDEBFF);
      case 'finished':
        return const Color(0xFFF1F5F9);
      case 'locked':
        return const Color(0xFFFFEEEE);
      case 'upcoming':
        return const Color(0xFFFFF4DB);
      default:
        return const Color(0xFFF3F5FA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (semester['name'] ?? '').toString();
    final academicYear = (semester['academicYear'] ?? '').toString();
    final status = (semester['status'] ?? '').toString();
    final isActive = semester['isActive'] != false;

    final registrationOpenAt = formatDateVN(
      semester['registrationOpenAt']?.toString(),
    );
    final registrationCloseAt = formatDateVN(
      semester['registrationCloseAt']?.toString(),
    );
    final studyStartAt = formatDateVN(semester['studyStartAt']?.toString());
    final studyEndAt = formatDateVN(semester['studyEndAt']?.toString());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE2EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFF6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: _primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Năm học $academicYear',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Đăng ký: $registrationOpenAt - $registrationCloseAt',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Học: $studyStartAt - $studyEndAt',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: !isActive
                              ? const Color(0xFFFFF4DB)
                              : _statusBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          !isActive ? 'Đã ẩn' : semesterStatusLabel(status),
                          style: TextStyle(
                            color: !isActive
                                ? const Color(0xFFB45309)
                                : _statusColor(status),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: onEdit,
                            child: const Text('Sửa'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: onToggleVisibility,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isActive
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            child: Text(isActive ? 'Ẩn' : 'Hiện lại'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 34),
          ],
        ),
      ),
    );
  }
}

class _SemesterHistoryCard extends StatelessWidget {
  final Map<String, dynamic> semester;

  const _SemesterHistoryCard({required this.semester});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final name = (semester['name'] ?? '').toString();
    final academicYear = (semester['academicYear'] ?? '').toString();

    final registrationOpenAt = formatDateVN(
      semester['registrationOpenAt']?.toString(),
    );
    final registrationCloseAt = formatDateVN(
      semester['registrationCloseAt']?.toString(),
    );
    final studyStartAt = formatDateVN(semester['studyStartAt']?.toString());
    final studyEndAt = formatDateVN(semester['studyEndAt']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFF6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.history_rounded, color: _primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Năm học $academicYear',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Đăng ký: $registrationOpenAt - $registrationCloseAt',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Học: $studyStartAt - $studyEndAt',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Đã kết thúc',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
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

class _SemesterFieldLabel extends StatelessWidget {
  final String text;

  const _SemesterFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF23324D),
      ),
    );
  }
}

class _SemesterDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;

  const _SemesterDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF1B2A8A),
        size: 28,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF3F5FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9E0EC), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1B2A8A), width: 1.8),
        ),
      ),
    );
  }
}

class _SemesterDateField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  final String placeholder;

  const _SemesterDateField({
    required this.value,
    required this.onTap,
    this.placeholder = 'dd/mm/yyyy',
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E0EC), width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value : placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const Icon(Icons.calendar_month_outlined, color: Color(0xFF1B2A8A)),
          ],
        ),
      ),
    );
  }
}
