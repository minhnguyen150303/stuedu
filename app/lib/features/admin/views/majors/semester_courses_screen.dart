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
      builder: (context) => AlertDialog(
        title: Text(nextVisible ? 'Hiện lại môn học' : 'Ẩn môn học'),
        content: Text(
          nextVisible
              ? 'Môn học sẽ hiển thị lại cho admin và sinh viên.'
              : 'Môn học sẽ bị ẩn khỏi học kỳ này. Sinh viên sẽ không thấy môn học và không đăng ký lớp của môn này được nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              nextVisible ? 'Hiện lại' : 'Ẩn',
              style: TextStyle(
                color: nextVisible ? Colors.blue : Colors.orange,
              ),
            ),
          ),
        ],
      ),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                        const Expanded(
                          child: Text(
                            'Thêm môn học',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 34,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: Color(0xFFE7ECF4)),

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
                              minimumSize: const Size.fromHeight(58),
                              elevation: 6,
                              shadowColor: const Color(0x33000000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Lưu',
                              style: TextStyle(
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                        const Expanded(
                          child: Text(
                            'Sửa môn học',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 34,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: Color(0xFFE7ECF4)),

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
                              minimumSize: const Size.fromHeight(58),
                              elevation: 6,
                              shadowColor: const Color(0x33000000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Lưu',
                              style: TextStyle(
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        title: const Text(
          'Danh sách Môn học',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFEFF2F7),
            padding: const EdgeInsets.all(16),
            child: Text(
              '$majorName  ›  $semesterName  ›  Môn học',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Môn học hiện tại',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddCourseForm,
                          icon: const Icon(Icons.add_circle_rounded),
                          label: const Text('Thêm mới'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('Chưa có môn học nào trong học kỳ này'),
                        ),
                      ),
                    ...items.map((course) {
                      final isVisible = course['isVisible'] != false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDCE2EE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDEFF6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.code_rounded,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (course['courseName'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${course['courseCode'] ?? course['id'] ?? 'IT0000'} • ${course['credits'] ?? 0} Tín chỉ',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    if ((course['description'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        (course['description'] ?? '')
                                            .toString(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (!isVisible) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF4DB),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Đã ẩn',
                                          style: TextStyle(
                                            color: Color(0xFFB45309),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        OutlinedButton(
                                          onPressed: () =>
                                              _showEditCourseForm(course),
                                          child: const Text('Sửa'),
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton(
                                          onPressed: () =>
                                              _toggleCourseVisibility(course),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isVisible
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                          child: Text(
                                            isVisible ? 'Ẩn' : 'Hiện lại',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
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
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
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
