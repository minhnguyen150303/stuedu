import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class AdminProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const AdminProfileScreen({super.key, required this.profile});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminRepository _repo;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _repo = AdminRepository(ApiClient(AppConfig.baseUrl));
    _future = _repo.getMyProfile();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getMyProfile();
    });
  }

  String _initials(String name) {
    final safe = name.trim();
    if (safe.isEmpty) return '?';
    final parts = safe.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(
      text: (user['fullName'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (user['phoneNumber'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (user['address'] ?? '').toString(),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
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
                const Text(
                  'Sửa thông tin cá nhân',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                _EditField(
                  label: 'Họ tên',
                  controller: nameCtrl,
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: 'Số điện thoại',
                  controller: phoneCtrl,
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: 'Địa chỉ',
                  controller: addressCtrl,
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
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

    await _repo.updateMyProfile(
      fullName: nameCtrl.text.trim(),
      phoneNumber: phoneCtrl.text.trim(),
      address: addressCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ')));

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _primary),
        title: const Text(
          'Thông tin quản trị viên',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Không tải được hồ sơ\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final user = snapshot.data ?? {};
          final fullName = (user['fullName'] ?? '').toString();
          final email = (user['email'] ?? '').toString();
          final avatarUrl = (user['avatarUrl'] ?? '').toString();
          final phone = (user['phoneNumber'] ?? '').toString();
          final address = (user['address'] ?? '').toString();
          final department = (user['department'] ?? '').toString();
          final uid = (user['uid'] ?? '').toString();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 72,
                        backgroundColor: const Color(0xFFE8EDF5),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                _initials(fullName),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: _primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        fullName.isEmpty ? 'Chưa có tên' : fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _Tag(
                        text: 'QUẢN TRỊ VIÊN',
                        bg: Color(0xFFEAEAFE),
                        color: _primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'THÔNG TIN TÀI KHOẢN',
                  children: [
                    _InfoRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'User ID',
                      value: uid,
                    ),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      label: 'Số điện thoại',
                      value: phone.isEmpty ? 'Chưa có dữ liệu' : phone,
                    ),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      label: 'Địa chỉ',
                      value: address.isEmpty ? 'Chưa có dữ liệu' : address,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => _editProfile(user),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text(
                      'Sửa thông tin',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color color;

  const _Tag({required this.text, required this.bg, required this.color});

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
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
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
              letterSpacing: 1.3,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;

  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF3F5FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
