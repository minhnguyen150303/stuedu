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

  int _tab = 0;
  List<Map<String, dynamic>> _lastCycleMaps = [];

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  Future<List<Map<String, dynamic>>> _loadSemesterCycles() {
    return _repo.getSemesterCycles(majorId: widget.major['id'].toString());
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
                    color: nextActive
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFFF4DB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nextActive
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFFCD34D),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    nextActive
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 34,
                    color: nextActive
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  nextActive ? 'Hiện lại học kỳ?' : 'Ẩn học kỳ?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nextActive
                      ? 'Học kỳ sẽ hiển thị lại trong danh sách hoạt động.'
                      : 'Học kỳ sẽ bị ẩn khỏi vận hành hiện tại, nhưng dữ liệu cũ vẫn được giữ lại.',
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
                            backgroundColor: nextActive
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFB45309),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            nextActive ? 'Hiện lại' : 'Ẩn',
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
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDEFF6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isEdit
                                    ? Icons.edit_calendar_rounded
                                    : Icons.add_circle_rounded,
                                color: _primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                isEdit ? 'Sửa học kỳ' : 'Thêm học kỳ',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
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
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF334155),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
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
                                  backgroundColor: _primary,
                                  minimumSize: const Size.fromHeight(56),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  isEdit ? 'Lưu' : 'Tạo',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(color: Color(0xFFF5F7FB)),
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
                              'Quản lý học kỳ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              majorName,
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
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2F7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _TopTab(
                          label: 'Danh sách học kỳ',
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        _TopTab(
                          label: 'Giảng viên',
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Danh sách học kỳ',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Quản lý các học kỳ đang vận hành',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 44,
                                  child: FilledButton.icon(
                                    onPressed: () => _showSemesterCycleForm(),
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
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                    ),
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
                            const SizedBox(height: 16),
                            if (semesters.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 32),
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 42,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Chưa có học kỳ nào',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFF6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: _primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 28,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
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
                  _SemesterInfoLine(
                    icon: Icons.app_registration_rounded,
                    text: 'Đăng ký: $registrationOpenAt - $registrationCloseAt',
                  ),
                  const SizedBox(height: 6),
                  _SemesterInfoLine(
                    icon: Icons.school_rounded,
                    text: 'Học: $studyStartAt - $studyEndAt',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
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
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SemesterActionButton(
                          icon: Icons.edit_rounded,
                          text: 'Sửa',
                          foregroundColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          onPressed: onEdit,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SemesterActionButton(
                          icon: isActive
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          text: isActive ? 'Ẩn' : 'Hiện lại',
                          foregroundColor: isActive
                              ? const Color(0xFFB45309)
                              : const Color(0xFF2563EB),
                          backgroundColor: isActive
                              ? const Color(0xFFFFF4DB)
                              : const Color(0xFFEFF6FF),
                          borderColor: isActive
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFBFDBFE),
                          onPressed: onToggleVisibility,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SemesterInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SemesterActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _SemesterActionButton({
    required this.icon,
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foregroundColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
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
