import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/repositories/admin_academic_repository.dart';
import '../../../../data/sources/remote/api_client.dart';
import 'class_management_screen.dart';

class SemesterCoursesScreen extends StatefulWidget {
  final Map<String, dynamic> major;
  final Map<String, dynamic> semester;

  const SemesterCoursesScreen({
    super.key,
    required this.major,
    required this.semester,
  });

  @override
  State<SemesterCoursesScreen> createState() => _SemesterCoursesScreenState();
}

class _SemesterCoursesScreenState extends State<SemesterCoursesScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminAcademicRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  Future<List<Map<String, dynamic>>> _loadCoursesInSemester() async {
    final curriculum = await _repo.getCurriculum(
      majorId: widget.major['id'].toString(),
      semesterId: widget.semester['id'].toString(),
    );

    final allCourses = await _repo.getCourses(
      majorId: widget.major['id'].toString(),
    );

    final curriculumByCourseId = <String, Map<String, dynamic>>{
      for (final item in curriculum) item['courseId'].toString(): item,
    };

    return allCourses
        .where((c) => curriculumByCourseId.containsKey(c['id'].toString()))
        .map((course) {
          final curriculumItem = curriculumByCourseId[course['id'].toString()];
          return {
            ...course,
            'curriculumItemId': curriculumItem?['id'],
            'isVisible': curriculumItem?['isVisible'] != false,
          };
        })
        .toList();
  }

  Future<void> _toggleCourseVisibility(Map<String, dynamic> course) async {
    final curriculumItemId = course['curriculumItemId']?.toString();
    final currentVisible = course['isVisible'] != false;

    if (curriculumItemId == null || curriculumItemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy liên kết môn học - học kỳ'),
        ),
      );
      return;
    }

    final nextVisible = !currentVisible;

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
                    color: nextVisible
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFFF4DB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nextVisible
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFFCD34D),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    nextVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 34,
                    color: nextVisible
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  nextVisible ? 'Hiện lại môn học?' : 'Ẩn môn học?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nextVisible
                      ? 'Môn học sẽ hiển thị lại cho admin và sinh viên.'
                      : 'Môn học sẽ bị ẩn khỏi học kỳ này. Sinh viên sẽ không thấy môn học và không đăng ký lớp của môn này được nữa.',
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
                            backgroundColor: nextVisible
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFB45309),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            nextVisible ? 'Hiện lại' : 'Ẩn',
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
      await _repo.updateCurriculumItem(
        id: curriculumItemId,
        isVisible: nextVisible,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextVisible ? 'Đã hiện lại môn học' : 'Đã ẩn môn học'),
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

  Future<void> _showAddCourseForm() async {
    final courseNameController = TextEditingController();
    final courseCodeController = TextEditingController();
    final descriptionController = TextEditingController();
    final creditsController = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.65,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                        width: 56,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DEE8),
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
                          child: const Icon(
                            Icons.add_circle_rounded,
                            color: _primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Thêm môn học',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 30,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _CourseFieldLabel('Tên môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: courseNameController,
                      hintText: 'Ví dụ: Cấu trúc dữ liệu và Giải thuật',
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Mô tả môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: descriptionController,
                      hintText: 'Nhập mô tả ngắn cho môn học',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Mã môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: courseCodeController,
                      hintText: 'VD: CS101',
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Số tín chỉ'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: creditsController,
                      hintText: 'Nhập số tín chỉ (vd: 3)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
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
                          child: FilledButton(
                            onPressed: () {
                              if (courseNameController.text.trim().isEmpty ||
                                  courseCodeController.text.trim().isEmpty ||
                                  creditsController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng nhập đầy đủ thông tin',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final credits = int.tryParse(
                                creditsController.text.trim(),
                              );
                              if (credits == null || credits <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Số tín chỉ không hợp lệ'),
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
                            child: const Text(
                              'Lưu',
                              style: TextStyle(
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

    if (ok != true) return;

    try {
      final created = await _repo.createCourse(
        majorId: widget.major['id'].toString(),
        courseName: courseNameController.text.trim(),
        courseCode: courseCodeController.text.trim(),
        credits: int.parse(creditsController.text.trim()),
        description: descriptionController.text.trim(),
      );

      await _repo.addCourseToCurriculum(
        majorId: widget.major['id'].toString(),
        semesterId: widget.semester['id'].toString(),
        courseId: created['id'].toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm môn học vào học kỳ')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _showEditCourseForm(Map<String, dynamic> course) async {
    final courseNameController = TextEditingController(
      text: (course['courseName'] ?? '').toString(),
    );
    final courseCodeController = TextEditingController(
      text: (course['courseCode'] ?? '').toString(),
    );
    final descriptionController = TextEditingController(
      text: (course['description'] ?? '').toString(),
    );
    final creditsController = TextEditingController(
      text: (course['credits'] ?? '').toString(),
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.65,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                        width: 56,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DEE8),
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
                          child: const Icon(
                            Icons.edit_rounded,
                            color: _primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Sửa môn học',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 30,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _CourseFieldLabel('Tên môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: courseNameController,
                      hintText: 'Ví dụ: Cấu trúc dữ liệu và Giải thuật',
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Mô tả môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: descriptionController,
                      hintText: 'Nhập mô tả ngắn cho môn học',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Mã môn học'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: courseCodeController,
                      hintText: 'VD: CS101',
                    ),
                    const SizedBox(height: 22),
                    const _CourseFieldLabel('Số tín chỉ'),
                    const SizedBox(height: 10),
                    _CourseTextField(
                      controller: creditsController,
                      hintText: 'Nhập số tín chỉ (vd: 3)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
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
                          child: FilledButton(
                            onPressed: () {
                              if (courseNameController.text.trim().isEmpty ||
                                  courseCodeController.text.trim().isEmpty ||
                                  creditsController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng nhập đầy đủ thông tin',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final credits = int.tryParse(
                                creditsController.text.trim(),
                              );
                              if (credits == null || credits <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Số tín chỉ không hợp lệ'),
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
                            child: const Text(
                              'Lưu',
                              style: TextStyle(
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

    if (ok != true) return;

    try {
      await _repo.updateCourse(
        id: course['id'].toString(),
        courseName: courseNameController.text.trim(),
        courseCode: courseCodeController.text.trim(),
        credits: int.parse(creditsController.text.trim()),
        description: descriptionController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật môn học')));
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
    final semesterName = (widget.semester['name'] ?? '').toString();

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
                              'Quản lý môn học',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$majorName • $semesterName',
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
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadCoursesInSemester(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  }

                  final items = snapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Môn học hiện tại',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Quản lý môn học thuộc học kỳ này',
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
                              onPressed: _showAddCourseForm,
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
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 32),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 42,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Chưa có môn học nào trong học kỳ này',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ...items.map((course) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CourseCard(
                            course: course,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassManagementScreen(
                                    major: widget.major,
                                    semester: widget.semester,
                                    course: course,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            onEdit: () => _showEditCourseForm(course),
                            onToggleVisibility: () =>
                                _toggleCourseVisibility(course),
                          ),
                        );
                      }),
                    ],
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

class _CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleVisibility;

  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onEdit,
    required this.onToggleVisibility,
  });

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  static const _primary = Color(0xFF1B2A8A);

  bool _showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    final isVisible = course['isVisible'] != false;
    final courseName = (course['courseName'] ?? '').toString();
    final courseCode = (course['courseCode'] ?? course['id'] ?? 'IT0000')
        .toString();
    final credits = (course['credits'] ?? 0).toString();
    final description = (course['description'] ?? '').toString().trim();

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isVisible ? Colors.white : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isVisible
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFFCD34D),
            width: isVisible ? 1 : 1.3,
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
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: isVisible
                    ? const Color(0xFFEDEFF6)
                    : const Color(0xFFFFF4DB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isVisible
                    ? Icons.menu_book_rounded
                    : Icons.visibility_off_rounded,
                color: isVisible ? _primary : const Color(0xFFB45309),
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
                          courseName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isVisible
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF92400E),
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

                  const SizedBox(height: 6),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CourseChip(
                        icon: Icons.tag_rounded,
                        text: courseCode,
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                      _CourseChip(
                        icon: Icons.star_rounded,
                        text: '$credits tín chỉ',
                        color: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF3E8FF),
                      ),
                      if (!isVisible)
                        const _CourseChip(
                          icon: Icons.visibility_off_rounded,
                          text: 'Đã ẩn',
                          color: Color(0xFFB45309),
                          bgColor: Color(0xFFFFF4DB),
                        ),
                    ],
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isVisible
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isVisible
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 17,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Mô tả môn học',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 7),

                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: _showFullDescription ? null : 2,
                            overflow: _showFullDescription
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),

                          if (description.length > 80) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showFullDescription = !_showFullDescription;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _showFullDescription
                                          ? 'Thu gọn'
                                          : 'Xem thêm',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: _primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _showFullDescription
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: _primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _CourseActionButton(
                          icon: Icons.edit_rounded,
                          text: 'Sửa',
                          foregroundColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          onPressed: widget.onEdit,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CourseActionButton(
                          icon: isVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          text: isVisible ? 'Ẩn' : 'Hiện lại',
                          foregroundColor: isVisible
                              ? const Color(0xFFB45309)
                              : const Color(0xFF2563EB),
                          backgroundColor: isVisible
                              ? const Color(0xFFFFF4DB)
                              : const Color(0xFFEFF6FF),
                          borderColor: isVisible
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFBFDBFE),
                          onPressed: widget.onToggleVisibility,
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

class _CourseChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  const _CourseChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _CourseActionButton({
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

class _CourseFieldLabel extends StatelessWidget {
  final String text;

  const _CourseFieldLabel(this.text);

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

class _CourseTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _CourseTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFA2AEC0), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF3F5FA),
        contentPadding: EdgeInsets.fromLTRB(
          18,
          maxLines > 1 ? 14 : 18,
          18,
          maxLines > 1 ? 14 : 18,
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
