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

  Future<List<Map<String, dynamic>>> _loadMajors() => _repo.getMajors();

  Future<void> _showMajorForm({Map<String, dynamic>? major}) async {
    final nameController = TextEditingController(
      text: (major?['name'] ?? '').toString(),
    );
    final descController = TextEditingController(
      text: (major?['description'] ?? '').toString(),
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                  major == null ? 'Thêm chuyên ngành' : 'Sửa chuyên ngành',
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
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Lưu'),
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
      if (major == null) {
        await _repo.createMajor(
          name: nameController.text.trim(),
          description: descController.text.trim(),
        );
      } else {
        await _repo.updateMajor(
          id: major['id'].toString(),
          name: nameController.text.trim(),
          description: descController.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            major == null ? 'Đã thêm chuyên ngành' : 'Đã cập nhật chuyên ngành',
          ),
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

  Future<void> _deleteMajor(Map<String, dynamic> major) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chuyên ngành?'),
        content: Text(
          'Bạn sắp xóa "${major['name']}". Hành động này có thể ảnh hưởng dữ liệu liên quan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.deleteMajor(major['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa chuyên ngành')));
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
                        label: const Text('Thêm chuyên ngành'),
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
                        onDelete: () => _deleteMajor(major),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF3F5FA),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Đang hoạt động',
                    style: TextStyle(
                      color: Color(0xFF0F9B63),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Sửa'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onDetail,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Chi tiết'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
