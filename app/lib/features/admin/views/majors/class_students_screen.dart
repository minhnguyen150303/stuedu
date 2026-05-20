import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/repositories/admin_academic_repository.dart';
import '../../../../data/sources/remote/api_client.dart';

class ClassStudentsScreen extends StatefulWidget {
  final Map<String, dynamic> classItem;
  final Map<String, dynamic> semester;

  const ClassStudentsScreen({
    super.key,
    required this.classItem,
    required this.semester,
  });

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  static const _primary = Color(0xFF1B2A8A);
  late final AdminAcademicRepository _repo;
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  final int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  bool get _canAddStudent {
    final semesterStatus = (widget.semester['status'] ?? '').toString();
    final adminState = (widget.classItem['adminState'] ?? 'draft').toString();

    return adminState != 'archived' &&
        (semesterStatus == 'registration_open' || semesterStatus == 'studying');
  }

  Future<List<Map<String, dynamic>>> _loadStudents() async {
    final enrollments = await _repo.getEnrollments(
      classId: widget.classItem['id'].toString(),
      status: 'approved',
    );

    final result = <Map<String, dynamic>>[];
    for (final e in enrollments) {
      final uid = (e['studentId'] ?? '').toString();
      if (uid.isEmpty) continue;
      final user = await _repo.getUserDetail(uid);
      result.add(user);
    }
    return result;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAddStudentDialog() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddStudentBottomSheet(
        repo: _repo,
        classId: widget.classItem['id'].toString(),
      ),
    );

    if (selected == null) return;

    try {
      await _repo.addStudentToClass(
        classId: widget.classItem['id'].toString(),
        studentId: selected['uid'].toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm sinh viên vào lớp')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _removeStudent(Map<String, dynamic> student) async {
    final studentId = (student['uid'] ?? '').toString();
    final name = (student['fullName'] ?? 'Sinh viên').toString();

    if (studentId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sinh viên khỏi lớp?'),
        content: Text(
          'Sinh viên "$name" sẽ bị xóa khỏi lớp này.\n'
          'Điểm trong lớp cũng sẽ bị xóa.\n'
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.removeStudentFromClass(
        classId: widget.classItem['id'].toString(),
        studentId: studentId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa sinh viên khỏi lớp')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final classCode = (widget.classItem['classCode'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        title: Text(
          'Danh sách Sinh viên lớp $classCode',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadStudents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          var students = snapshot.data ?? [];
          final q = _searchController.text.trim().toLowerCase();

          if (q.isNotEmpty) {
            students = students.where((s) {
              final name = (s['fullName'] ?? '').toString().toLowerCase();
              final email = (s['email'] ?? '').toString().toLowerCase();

              final raw = s['studentInfo'];
              final studentInfo = raw is Map<String, dynamic>
                  ? raw
                  : raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};

              final studentCode = (studentInfo['studentCode'] ?? '')
                  .toString()
                  .toLowerCase();

              return name.contains(q) ||
                  email.contains(q) ||
                  studentCode.contains(q);
            }).toList();
          }

          final total = students.length;
          final start = (_page - 1) * _pageSize;
          final end = (start + _pageSize) > total ? total : (start + _pageSize);
          final pageItems = students.sublist(
            start.clamp(0, total),
            end.clamp(0, total),
          );
          final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                Text(
                  'Tổng cộng $total sinh viên trong lớp',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Xuất Excel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _canAddStudent ? _openAddStudentDialog : null,
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm Sinh viên'),
                    ),
                  ],
                ),
                if (!_canAddStudent) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Chỉ được thêm sinh viên khi học kỳ đang mở đăng ký hoặc đang học.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFDCE2EE)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() => _page = 1),
                          decoration: const InputDecoration(
                            hintText: 'Tìm theo tên hoặc MSSV...',
                            prefixIcon: Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Color(0xFFF3F5FA),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...pageItems.map((student) {
                        final name = (student['fullName'] ?? '').toString();
                        final email = (student['email'] ?? '').toString();

                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFEDEFF6),
                                child: Text(
                                  _initials(name),
                                  style: const TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(email),
                              trailing: IconButton(
                                onPressed:
                                    (widget.classItem['adminState'] ?? 'draft')
                                            .toString() ==
                                        'archived'
                                    ? null
                                    : () => _removeStudent(student),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Đang hiển thị ${total == 0 ? 0 : start + 1}-$end trong số $total sinh viên',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _page > 1
                                      ? () => setState(() => _page--)
                                      : null,
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                for (int p = 1; p <= totalPages && p <= 5; p++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: InkWell(
                                      onTap: () => setState(() => _page = p),
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: p == _page
                                              ? _primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$p',
                                            style: TextStyle(
                                              color: p == _page
                                                  ? Colors.white
                                                  : const Color(0xFF334155),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: _page < totalPages
                                      ? () => setState(() => _page++)
                                      : null,
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}';
    return parts.first[0];
  }
}

class _AddStudentBottomSheet extends StatefulWidget {
  final AdminAcademicRepository repo;
  final String classId;

  const _AddStudentBottomSheet({
    super.key,
    required this.repo,
    required this.classId,
  });

  @override
  State<_AddStudentBottomSheet> createState() => _AddStudentBottomSheetState();
}

class _AddStudentBottomSheetState extends State<_AddStudentBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({String? q}) async {
    setState(() => _loading = true);
    try {
      final data = await widget.repo.getAvailableStudentsForClass(
        classId: widget.classId,
        q: q,
      );

      setState(() => _students = data);
    } catch (_) {
      setState(() => _students = []);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _studentSubtitle(Map<String, dynamic> s) {
    final raw = s['studentInfo'];
    final studentInfo = raw is Map<String, dynamic>
        ? raw
        : raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final studentCode = (studentInfo['studentCode'] ?? '').toString();
    final className = (studentInfo['className'] ?? '').toString();
    final year = (studentInfo['year'] ?? '').toString();

    final parts = <String>[];
    if (studentCode.isNotEmpty) parts.add(studentCode);
    if (className.isNotEmpty) parts.add(className);
    if (year.isNotEmpty) parts.add('Năm $year');

    return parts.isEmpty ? 'Không có thông tin' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Thêm sinh viên',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc MSSV',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => _loadStudents(q: _searchCtrl.text.trim()),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onSubmitted: (v) => _loadStudents(q: v.trim()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty
                  ? const Center(child: Text('Không có sinh viên phù hợp'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final s = _students[index];
                        final fullName = (s['fullName'] ?? 'Chưa có tên')
                            .toString();
                        final subtitle = _studentSubtitle(s);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(child: Icon(Icons.person)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, s);
                                },
                                child: const Text('Thêm'),
                              ),
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
