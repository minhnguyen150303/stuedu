import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/repositories/admin_academic_repository.dart';
import '../../../../data/sources/remote/api_client.dart';
import 'major_detail_screen.dart';

class AdminMajorsScreen extends StatefulWidget {
  const AdminMajorsScreen({super.key});

  @override
  State<AdminMajorsScreen> createState() => _AdminMajorsScreenState();
}

class _AdminMajorsScreenState extends State<AdminMajorsScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminAcademicRepository _repo;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadMajors() => _repo.getMajors();

  Future<void> _showMajorForm({Map<String, dynamic>? major}) async {
    final nameController = TextEditingController(
      text: (major?['name'] ?? '').toString(),
    );
    final descController = TextEditingController(
      text: (major?['description'] ?? '').toString(),
    );

    try {
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                            Text(
                              major == null
                                  ? 'Thêm chuyên ngành'
                                  : 'Sửa chuyên ngành',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _MajorField(
                              label: 'Tên chuyên ngành',
                              controller: nameController,
                              hintText: 'Nhập tên chuyên ngành',
                            ),
                            const SizedBox(height: 16),
                            _MajorField(
                              label: 'Mô tả',
                              controller: descController,
                              hintText: 'Nhập mô tả',
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFC),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                FocusScope.of(sheetContext).unfocus();

                                Future.delayed(
                                  const Duration(milliseconds: 120),
                                  () {
                                    if (Navigator.of(sheetContext).canPop()) {
                                      Navigator.of(sheetContext).pop(null);
                                    }
                                  },
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final name = nameController.text.trim();
                                final description = descController.text.trim();

                                if (name.isEmpty) {
                                  showDialog(
                                    context: sheetContext,
                                    barrierDismissible: true,
                                    builder: (context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        title: const Text(
                                          'Thiếu thông tin',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        content: const Text(
                                          'Vui lòng nhập tên chuyên ngành.',
                                        ),
                                        actions: [
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _primary,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Đã hiểu'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return;
                                }

                                FocusScope.of(sheetContext).unfocus();

                                Future.delayed(
                                  const Duration(milliseconds: 120),
                                  () {
                                    if (Navigator.of(sheetContext).canPop()) {
                                      Navigator.of(sheetContext).pop({
                                        'name': name,
                                        'description': description,
                                      });
                                    }
                                  },
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Lưu',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (result == null) return;

      final name = result['name'] ?? '';
      final description = result['description'] ?? '';

      if (major == null) {
        await _repo.createMajor(name: name, description: description);
      } else {
        await _repo.updateMajor(
          id: major['id'].toString(),
          name: name,
          description: description,
        );
      }

      if (!mounted) return;

      _showSuccessDialog(
        major == null
            ? 'Chuyên ngành mới đã được thêm vào hệ thống.'
            : 'Thông tin chuyên ngành đã được cập nhật.',
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      _showErrorDialog(_friendlyError(e));
    } finally {
      await Future.delayed(const Duration(milliseconds: 250));
      nameController.dispose();
      descController.dispose();
    }
  }

  Future<void> _toggleMajorVisibility(Map<String, dynamic> major) async {
    final isActive = major['isActive'] != false && major['hidden'] != true;
    final nextActive = !isActive;
    final majorName = (major['name'] ?? 'Chuyên ngành').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
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
                nextActive ? 'Hiện lại chuyên ngành?' : 'Ẩn chuyên ngành?',
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
                    ? 'Chuyên ngành "$majorName" sẽ hiển thị lại trong hệ thống.'
                    : 'Chuyên ngành "$majorName" sẽ bị ẩn khỏi danh sách hoạt động. Chỉ được ẩn khi tất cả học kỳ liên quan đã kết thúc.',
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
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
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
      ),
    );

    if (ok != true) return;

    try {
      if (nextActive) {
        await _repo.showMajor(major['id'].toString());
      } else {
        await _repo.hideMajor(major['id'].toString());
      }

      if (!mounted) return;

      _showSuccessDialog(
        nextActive
            ? 'Chuyên ngành đã được hiện lại trong hệ thống.'
            : 'Chuyên ngành đã được ẩn khỏi danh sách hoạt động.',
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      _showErrorDialog(_friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    var msg = error.toString();

    msg = msg
        .replaceAll('Exception: ', '')
        .replaceAll('DioException [bad response]: ', '')
        .replaceAll('DioException: ', '')
        .trim();

    final knownMessages = [
      'Không thể ẩn chuyên ngành',
      'Học kỳ chưa kết thúc',
      'Chỉ được ẩn',
      'Major not found',
      'Forbidden',
      'Unauthorized',
    ];

    for (final key in knownMessages) {
      final index = msg.indexOf(key);
      if (index >= 0) {
        msg = msg.substring(index).trim();
        break;
      }
    }

    if (msg.contains('400')) {
      return 'Không thể thực hiện thao tác này. Chuyên ngành chỉ được ẩn khi tất cả học kỳ liên quan đã kết thúc.';
    }

    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }

    if (msg.contains('404') || msg.contains('Major not found')) {
      return 'Không tìm thấy chuyên ngành này.';
    }

    if (msg.isEmpty) {
      return 'Có lỗi xảy ra, vui lòng thử lại.';
    }

    if (msg.length > 260) {
      return '${msg.substring(0, 260)}...';
    }

    return msg;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Đã hiểu',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF1F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: Color(0xFFDC2626),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Có lỗi xảy ra',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Quản lý Chuyên ngành',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showMajorForm(),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Thêm chuyên ngành',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Tìm kiếm chuyên ngành...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadMajors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  }

                  var items = snapshot.data ?? [];
                  final q = _searchController.text.trim().toLowerCase();

                  if (q.isNotEmpty) {
                    items = items.where((m) {
                      final name = (m['name'] ?? '').toString().toLowerCase();
                      final desc = (m['description'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(q) || desc.contains(q);
                    }).toList();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final major = items[index];

                      return _MajorCard(
                        major: major,
                        onEdit: () => _showMajorForm(major: major),
                        onDelete: () => _toggleMajorVisibility(major),
                        onDetail: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MajorDetailScreen(major: major),
                            ),
                          );
                          setState(() {});
                        },
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

class _MajorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  const _MajorField({
    required this.label,
    required this.controller,
    required this.hintText,
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
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF3F5FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _MajorCard extends StatelessWidget {
  final Map<String, dynamic> major;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetail;

  const _MajorCard({
    required this.major,
    required this.onEdit,
    required this.onDelete,
    required this.onDetail,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final name = (major['name'] ?? '').toString();
    final desc = (major['description'] ?? '').toString();
    final isActive = major['isActive'] != false && major['hidden'] != true;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFCD34D),
          width: isActive ? 1 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFEDEFF6)
                        : const Color(0xFFFFF4DB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.account_tree_rounded
                        : Icons.visibility_off_rounded,
                    color: isActive ? _primary : const Color(0xFFB45309),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: isActive
                          ? const Color(0xFF111827)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                desc.isEmpty ? 'Chưa có mô tả' : desc,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE7F7EE)
                      : const Color(0xFFFFF4DB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.check_circle_rounded
                          : Icons.visibility_off_rounded,
                      size: 15,
                      color: isActive
                          ? const Color(0xFF0F9B63)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'Đang hoạt động' : 'Đã ẩn',
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF0F9B63)
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    tooltip: 'Sửa',
                    icon: Icons.edit_rounded,
                    text: 'Sửa',
                    foregroundColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardActionButton(
                    tooltip: 'Chi tiết',
                    icon: Icons.visibility_rounded,
                    text: 'Chi tiết',
                    foregroundColor: _primary,
                    backgroundColor: const Color(0xFFEDEFF6),
                    borderColor: const Color(0xFFD8DDF0),
                    onPressed: onDetail,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardActionButton(
                    tooltip: isActive ? 'Ẩn' : 'Hiện lại',
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
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.tooltip,
    required this.icon,
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foregroundColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
