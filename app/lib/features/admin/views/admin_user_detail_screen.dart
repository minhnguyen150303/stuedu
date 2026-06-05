import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/admin_academic_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'package:intl/intl.dart';

String formatDateString(dynamic value) {
  if (value == null) return 'Chưa có dữ liệu';

  try {
    final dt = DateTime.parse(value.toString()).toLocal();
    return DateFormat('dd/MM/yyyy').format(dt);
  } catch (_) {
    return 'Chưa có dữ liệu';
  }
}

class AdminUserDetailScreen extends StatefulWidget {
  final String uid;

  const AdminUserDetailScreen({super.key, required this.uid});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late final AdminRepository _repo;
  late Future<AdminUserDetail> _future;

  @override
  void initState() {
    super.initState();
    _repo = AdminRepository(ApiClient(AppConfig.baseUrl));
    _future = _loadDetail();
  }

  Future<AdminUserDetail> _loadDetail() async {
    final data = await _repo.getUserDetail(widget.uid);
    return AdminUserDetail.fromMap(data);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadDetail();
    });
  }

  Future<void> _toggleLock(AdminUserDetail user) async {
    final shouldLock = user.isActive;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ActionConfirmDialog(
        icon: Icons.lock_rounded,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFCE7E7),
        title: shouldLock ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?',
        message: shouldLock
            ? 'User sẽ tạm thời không đăng nhập được.\nBạn có chắc chắn muốn tiếp tục?'
            : 'User sẽ được phép đăng nhập lại.\nBạn có chắc chắn muốn tiếp tục?',
        confirmText: shouldLock ? 'Khóa' : 'Mở khóa',
        confirmBg: const Color(0xFF1B2A8A),
        confirmTextColor: Colors.white,
        cancelText: 'Hủy',
        confirmFirst: false,
      ),
    );

    if (ok != true) return;

    try {
      await _repo.lockUser(uid: user.uid, disabled: shouldLock);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldLock ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản',
          ),
        ),
      );
      await _refresh();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteUser(AdminUserDetail user) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ActionConfirmDialog(
        icon: Icons.warning_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFCE7E7),
        title: 'Xóa tài khoản?',
        message:
            'Hành động này không thể hoàn tác và toàn bộ dữ liệu của "${user.fullName}" sẽ bị mất. Bạn có chắc chắn muốn tiếp tục?',
        confirmText: 'Xóa',
        confirmBg: const Color(0xFFEF2222),
        confirmTextColor: Colors.white,
        cancelText: 'Hủy',
        confirmFirst: true,
      ),
    );

    if (ok != true) return;

    try {
      await _repo.deleteUser(user.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa user')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _editUser(AdminUserDetail user) async {
    final fullNameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final addressController = TextEditingController(text: user.address ?? '');

    final studentCodeController = TextEditingController(
      text: user.studentInfo?.studentCode ?? '',
    );
    final yearController = TextEditingController(
      text: user.studentInfo?.year?.toString() ?? '',
    );
    final classNameController = TextEditingController(
      text: user.studentInfo?.className ?? '',
    );

    final academicRepo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
    final majorsFuture = academicRepo.getMajors();

    String? selectedMajorId = user.majorId.isNotEmpty ? user.majorId : null;
    String? selectedDepartment = (user.department ?? '').isNotEmpty
        ? user.department
        : null;

    final isStudent = user.roleLabel.toLowerCase() == 'student';

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.7,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DCE6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, false),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 30,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Edit Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            MediaQuery.of(sheetContext).viewInsets.bottom +
                                MediaQuery.of(sheetContext).padding.bottom +
                                24,
                          ),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 74,
                                    backgroundColor: const Color(0xFFE8EDF5),
                                    backgroundImage:
                                        user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty
                                        ? NetworkImage(user.avatarUrl!)
                                        : null,
                                    child:
                                        (user.avatarUrl == null ||
                                            user.avatarUrl!.isEmpty)
                                        ? Text(
                                            user.initials,
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1B2A8A),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: InkWell(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Change photo: chưa triển khai',
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B2A8A),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x22000000),
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Change Photo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2A8A),
                                ),
                              ),
                              const SizedBox(height: 28),

                              _EditField(
                                label: 'Full Name',
                                controller: fullNameController,
                                hintText: 'Enter full name',
                              ),
                              const SizedBox(height: 18),

                              _EditField(
                                label: 'Phone Number',
                                controller: phoneController,
                                hintText: 'Enter phone number',
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 18),

                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: majorsFuture,
                                builder: (context, snapshot) {
                                  final majors = snapshot.data ?? [];

                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Chuyên ngành',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF23324D),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                        value:
                                            selectedMajorId != null &&
                                                selectedMajorId!.isNotEmpty
                                            ? selectedMajorId
                                            : null,
                                        decoration: InputDecoration(
                                          hintText: 'Chọn chuyên ngành',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 15,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF3F5FA),
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                18,
                                                18,
                                                18,
                                                18,
                                              ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD9E0EC),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1B2A8A),
                                              width: 1.8,
                                            ),
                                          ),
                                        ),
                                        items: majors.map((m) {
                                          final id = (m['id'] ?? '').toString();
                                          final name = (m['name'] ?? '')
                                              .toString();

                                          return DropdownMenuItem<String>(
                                            value: id,
                                            child: Text(name),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setSheetState(() {
                                            selectedMajorId = value;

                                            final selectedMajor = majors
                                                .firstWhere(
                                                  (m) =>
                                                      (m['id'] ?? '')
                                                          .toString() ==
                                                      value,
                                                  orElse: () =>
                                                      <String, dynamic>{},
                                                );

                                            selectedDepartment =
                                                (selectedMajor['name'] ?? '')
                                                    .toString();
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),

                              _EditField(
                                label: 'Address',
                                controller: addressController,
                                hintText:
                                    'Enter your full office or home address',
                                maxLines: 1,
                              ),

                              if (isStudent) ...[
                                const SizedBox(height: 18),
                                _EditField(
                                  label: 'Student Code',
                                  controller: studentCodeController,
                                  hintText: 'Enter student code',
                                ),
                                const SizedBox(height: 18),
                                _EditField(
                                  label: 'Academic Year',
                                  controller: yearController,
                                  hintText: 'Enter academic year',
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 18),
                                _EditField(
                                  label: 'Class Name',
                                  controller: classNameController,
                                  hintText: 'Enter class name',
                                ),
                              ],

                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(sheetContext, false),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(58),
                                        side: const BorderSide(
                                          color: Color(0xFFD9DDEA),
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Hủy',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1B2A8A),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(sheetContext, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1B2A8A,
                                        ),
                                        minimumSize: const Size.fromHeight(58),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (updated != true) return;

    try {
      Map<String, dynamic>? studentInfoData;

      if (isStudent) {
        studentInfoData = {
          'studentCode': studentCodeController.text.trim(),
          'year': int.tryParse(yearController.text.trim()),
          'className': classNameController.text.trim(),
        }..removeWhere((key, value) => value == null || value == '');
      }

      if (isStudent && (selectedMajorId == null || selectedMajorId!.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn chuyên ngành')),
        );
        return;
      }

      await _repo.updateUser(
        uid: user.uid,
        fullName: fullNameController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        department: selectedDepartment,
        majorId: selectedMajorId,
        address: addressController.text.trim(),
        studentInfo: studentInfoData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật user')));

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  String _scoreText(dynamic value) {
    final n = num.tryParse((value ?? '').toString());
    if (n == null) return '--';

    final text = n.toStringAsFixed(2);
    return text.replaceAll(RegExp(r'\.?0+$'), '');
  }

  Color _learningStatusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('pass') || s.contains('đạt')) {
      return const Color(0xFF16A34A);
    }

    if (s.contains('fail') || s.contains('trượt') || s.contains('nợ')) {
      return const Color(0xFFDC2626);
    }

    return const Color(0xFFF59E0B);
  }

  Widget _buildLearningOverview(AdminUserDetail user) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _repo.getStudentLearningOverview(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SectionCard(
            title: 'TÌNH HÌNH HỌC TẬP',
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return _SectionCard(
            title: 'TÌNH HÌNH HỌC TẬP',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                'Không tải được tình hình học tập\n${snapshot.error}',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final summary = Map<String, dynamic>.from(
          (data['summary'] as Map?) ?? const {},
        );

        final items = ((data['items'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        return _SectionCard(
          title: 'TÌNH HÌNH HỌC TẬP',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _LearningStatBox(
                      label: 'Tổng môn',
                      value: '${summary['totalSubjects'] ?? 0}',
                      color: const Color(0xFF1B2A8A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LearningStatBox(
                      label: 'Đã đạt',
                      value: '${summary['passedSubjects'] ?? 0}',
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _LearningStatBox(
                      label: 'Không đạt',
                      value: '${summary['failedSubjects'] ?? 0}',
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LearningStatBox(
                      label: 'GPA hệ 4',
                      value: _scoreText(summary['avgGpa4']),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Sinh viên chưa có dữ liệu điểm.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final status = (item['status'] ?? 'Chưa đủ điểm').toString();
                  final color = _learningStatusColor(status);

                  final courseName = (item['courseName'] ?? 'Môn học')
                      .toString();
                  final classCode = (item['classCode'] ?? '').toString();
                  final courseCode = (item['courseCode'] ?? '').toString();
                  final credits = item['credits'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                courseName,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (courseCode.isNotEmpty) courseCode,
                            if (classCode.isNotEmpty) 'Lớp $classCode',
                            '$credits tín chỉ',
                          ].join(' • '),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ScoreMiniBox(
                                label: 'CC',
                                value: _scoreText(item['scoreProcess']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ScoreMiniBox(
                                label: 'GK',
                                value: _scoreText(item['scoreMid']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ScoreMiniBox(
                                label: 'CK',
                                value: _scoreText(item['scoreFinal']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ScoreMiniBox(
                                label: 'TK',
                                value: _scoreText(item['totalTen']),
                                strong: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1B2A8A)),
        ),
        title: const Text(
          'User Details',
          style: TextStyle(
            color: Color(0xFF0D1633),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6D7B92)),
          ),
        ],
      ),
      body: FutureBuilder<AdminUserDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được chi tiết user\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final user = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFDDE3EE)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 86,
                            backgroundColor: const Color(0xFFE8EDF5),
                            backgroundImage:
                                user.avatarUrl != null &&
                                    user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child:
                                (user.avatarUrl == null ||
                                    user.avatarUrl!.isEmpty)
                                ? Text(
                                    user.initials,
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1B2A8A),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: user.isActive
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        user.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1633),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6D7B92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _TagChip(
                            text: user.roleLabel.toUpperCase(),
                            bg: const Color(0xFFEAEAFE),
                            textColor: const Color(0xFF1B2A8A),
                          ),
                          _TagChip(
                            text: user.isActive ? 'ACTIVE' : 'LOCKED',
                            bg: user.isActive
                                ? const Color(0xFFDDF3E5)
                                : const Color(0xFFE5E7EB),
                            textColor: user.isActive
                                ? const Color(0xFF15803D)
                                : const Color(0xFF4B5563),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'ACCOUNT INFORMATION',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Joined Date',
                        value: user.joinedDate ?? 'Chưa có dữ liệu',
                      ),
                      const _InfoDivider(),
                      _InfoRow(
                        icon: Icons.school_rounded,
                        label: 'Department',
                        value: user.department ?? 'Chưa có dữ liệu',
                      ),
                      const _InfoDivider(),
                      _InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone Number',
                        value: user.phoneNumber ?? 'Chưa có dữ liệu',
                      ),
                      const _InfoDivider(),
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        label: 'Address',
                        value: user.address ?? 'Chưa có dữ liệu',
                      ),
                    ],
                  ),
                ),
                if (user.studentInfo != null) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'STUDENT INFORMATION',
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Student Code',
                          value:
                              user.studentInfo?.studentCode ??
                              'Chưa có dữ liệu',
                        ),
                        const _InfoDivider(),
                        _InfoRow(
                          icon: Icons.auto_stories_rounded,
                          label: 'Academic Year',
                          value: user.studentInfo?.year != null
                              ? 'Năm ${user.studentInfo!.year}'
                              : 'Chưa có dữ liệu',
                        ),
                        const _InfoDivider(),
                        _InfoRow(
                          icon: Icons.groups_rounded,
                          label: 'Class',
                          value:
                              user.studentInfo?.className ?? 'Chưa có dữ liệu',
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isStudent) ...[
                  const SizedBox(height: 12),
                  _buildLearningOverview(user),
                ],

                const SizedBox(height: 12),
                _SectionCard(
                  title: 'MANAGEMENT ACTIONS',
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.edit_rounded,
                        iconBg: const Color(0xFFEAEAFE),
                        iconColor: const Color(0xFF1B2A8A),
                        title: 'Edit Profile',
                        subtitle: 'Update info and role',
                        onTap: () => _editUser(user),
                      ),
                      const SizedBox(height: 16),
                      _ActionTile(
                        icon: Icons.lock_rounded,
                        iconBg: const Color(0xFFF8EDC1),
                        iconColor: const Color(0xFFD97706),
                        title: user.isActive
                            ? 'Lock Account'
                            : 'Unlock Account',
                        subtitle: user.isActive
                            ? 'Temporarily disable access'
                            : 'Allow user to sign in again',
                        onTap: () => _toggleLock(user),
                      ),
                      const SizedBox(height: 16),
                      _DangerActionTile(
                        icon: Icons.delete_rounded,
                        title: 'Delete User',
                        subtitle: 'Permanently remove records',
                        onTap: () => _deleteUser(user),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F7FB),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE5EAF2));
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color textColor;

  const _TagChip({
    required this.text,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF23324D),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
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
              borderSide: const BorderSide(
                color: Color(0xFFD9E0EC),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF1B2A8A),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE3EE)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DangerActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          border: Border.all(color: const Color(0xFFF6C8CE)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFF87171),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF87171),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String message;
  final String confirmText;
  final Color confirmBg;
  final Color confirmTextColor;
  final String cancelText;
  final bool confirmFirst;

  const _ActionConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmBg,
    required this.confirmTextColor,
    this.cancelText = 'Hủy',
    this.confirmFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final cancelButton = SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF3F5F9),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          cancelText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
      ),
    );

    final confirmButton = SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(
          backgroundColor: confirmBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 4,
          shadowColor: const Color(0x22000000),
        ),
        child: Text(
          confirmText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: confirmTextColor,
          ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 44),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: confirmFirst
                    ? [confirmButton, const SizedBox(height: 18), cancelButton]
                    : [cancelButton, const SizedBox(height: 18), confirmButton],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LearningStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreMiniBox extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _ScoreMiniBox({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = strong ? const Color(0xFF1B2A8A) : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserDetail {
  final String uid;
  final String fullName;
  final String email;
  final String roleLabel;
  final String? avatarUrl;
  final bool isActive;
  final String? joinedDate;
  final String? department;
  final String majorId;
  final String? phoneNumber;
  final String? address;
  final StudentInfo? studentInfo;

  const AdminUserDetail({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.roleLabel,
    required this.majorId,
    this.avatarUrl,
    this.isActive = true,
    this.joinedDate,
    this.department,
    this.phoneNumber,
    this.address,
    this.studentInfo,
  });

  factory AdminUserDetail.fromMap(Map<String, dynamic> map) {
    final role = (map['role'] ?? '').toString();
    final avatarUrl = (map['avatarUrl'] ?? '').toString();

    return AdminUserDetail(
      uid: (map['uid'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      roleLabel: role.isEmpty
          ? 'Unknown'
          : '${role[0].toUpperCase()}${role.substring(1)}',
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      isActive: map['isActive'] != false,
      joinedDate: formatDateString(map['createdAt']),
      department: (map['department'] ?? '').toString().trim().isEmpty
          ? null
          : (map['department'] as String),
      majorId: (map['majorId'] ?? '').toString(),
      phoneNumber: (map['phoneNumber'] ?? '').toString().trim().isEmpty
          ? null
          : (map['phoneNumber'] as String),
      address: (map['address'] ?? '').toString().trim().isEmpty
          ? null
          : (map['address'] as String),
      studentInfo: map['studentInfo'] is Map
          ? StudentInfo.fromMap(Map<String, dynamic>.from(map['studentInfo']))
          : null,
    );
  }

  String get initials {
    final safeName = fullName.trim();
    if (safeName.isEmpty) return '?';
    final parts = safeName.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return parts.first[0].toUpperCase();
  }

  bool get isStudent {
    final role = roleLabel.toLowerCase().trim();
    return role == 'student' || role == 'sinh viên' || role.contains('student');
  }
}

class StudentInfo {
  final String? studentCode;
  final int? year;
  final String? className;

  const StudentInfo({this.studentCode, this.year, this.className});

  factory StudentInfo.fromMap(Map<String, dynamic> map) {
    return StudentInfo(
      studentCode: (map['studentCode'] ?? '').toString().trim().isEmpty
          ? null
          : (map['studentCode'] as String),
      year: map['year'] is num ? (map['year'] as num).toInt() : null,
      className: (map['className'] ?? '').toString().trim().isEmpty
          ? null
          : (map['className'] as String),
    );
  }
}
