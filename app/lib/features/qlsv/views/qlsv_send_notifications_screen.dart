import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class QlsvSendNotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const QlsvSendNotificationsScreen({super.key, required this.profile});

  @override
  State<QlsvSendNotificationsScreen> createState() =>
      _QlsvSendNotificationsScreenState();
}

class _QlsvSendNotificationsScreenState
    extends State<QlsvSendNotificationsScreen> {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _danger = Color(0xFFEF4444);
  static const _success = Color(0xFF16A34A);

  late final QlsvRepository _repo;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();

  String _targetType = 'all';
  final List<String> _selectedRoles = [];
  final List<Map<String, dynamic>> _selectedUsers = [];

  bool _loadingUsers = false;
  List<Map<String, dynamic>> _userResults = [];

  bool _sending = false;
  bool _loadingList = true;

  List<Map<String, dynamic>> _campaigns = [];
  String? _editingId;

  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
    _loadCampaigns();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _loadingList = true;
    });

    try {
      final items = await _repo.getNotificationCampaigns();

      if (!mounted) return;

      setState(() {
        _campaigns = items;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải danh sách: $e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingList = false;
      });
    }
  }

  Future<void> _searchUsers() async {
    final q = _userSearchCtrl.text.trim();

    setState(() {
      _loadingUsers = true;
    });

    try {
      final data = await _repo.getUsers(
        q: q.isEmpty ? null : q,
        page: 1,
        limit: 20,
      );

      final rawItems = data['items'] ?? data['data'] ?? data['users'] ?? [];
      final items = (rawItems as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        _userResults = items;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingUsers = false;
        _userResults = [];
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tải được người dùng: $e')));
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung')),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      Map<String, dynamic> result;

      if (_editingId == null) {
        final targetUserIds = _selectedUsers
            .map((e) => (e['uid'] ?? e['id'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toList();

        if (_targetType == 'role' && _selectedRoles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn ít nhất 1 vai trò')),
          );
          setState(() {
            _sending = false;
          });
          return;
        }

        if (_targetType == 'users' && targetUserIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn ít nhất 1 người nhận')),
          );
          setState(() {
            _sending = false;
          });
          return;
        }

        result = await _repo.createNotificationCampaign(
          title: title,
          body: body,
          targetType: _targetType,
          targetRoles: _selectedRoles,
          targetUserIds: targetUserIds,
        );
      } else {
        result = await _repo.updateNotificationCampaign(
          id: _editingId!,
          title: title,
          body: body,
        );
      }

      if (!mounted) return;

      final createdCount = result['createdCount'];
      final updatedCount = result['updatedCount'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingId == null
                ? (createdCount != null
                      ? 'Đã gửi thông báo tới $createdCount người dùng'
                      : 'Đã gửi thông báo')
                : (updatedCount != null
                      ? 'Đã cập nhật và đồng bộ $updatedCount thông báo'
                      : 'Đã cập nhật thông báo'),
          ),
        ),
      );

      _titleCtrl.clear();
      _bodyCtrl.clear();
      _userSearchCtrl.clear();

      setState(() {
        _editingId = null;
        _targetType = 'all';
        _selectedRoles.clear();
        _selectedUsers.clear();
        _userResults.clear();
      });

      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      _editingId = (item['id'] ?? '').toString();
      _titleCtrl.text = (item['title'] ?? '').toString();
      _bodyCtrl.text = (item['body'] ?? '').toString();
    });
  }

  void _cancelEdit() {
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _userSearchCtrl.clear();

    setState(() {
      _editingId = null;
      _targetType = 'all';
      _selectedRoles.clear();
      _selectedUsers.clear();
      _userResults.clear();
    });
  }

  Future<void> _deleteCampaign(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Xóa thông báo',
          style: TextStyle(fontWeight: FontWeight.w900, color: _textDark),
        ),
        content: const Text(
          'Bạn có chắc muốn xóa thông báo này không? Thông báo sẽ bị xóa khỏi toàn bộ người nhận.',
          style: TextStyle(
            color: _textMuted,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Xóa'),
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final result = await _repo.deleteNotificationCampaign(id);

      if (!mounted) return;

      final deletedCount = result['deletedCount'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount != null
                ? 'Đã xóa và đồng bộ $deletedCount thông báo'
                : 'Đã xóa thông báo',
          ),
        ),
      );

      if (_editingId == id) {
        _cancelEdit();
      }

      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  String _formatDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return 'Không rõ thời gian';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final date = parsed.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.hour)}:${two(date.minute)}  ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _danger),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2A8A), Color(0xFF3146C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý thông báo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tạo, sửa và đồng bộ thông báo tới người dùng',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeaderStat(label: 'Đã gửi', value: _campaigns.length.toString()),
              const SizedBox(width: 10),
              _HeaderStat(
                label: 'Trạng thái',
                value: _isEditing ? 'Sửa' : 'Tạo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Người nhận',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TargetChip(
                label: 'Tất cả',
                selected: _targetType == 'all',
                onTap: () {
                  setState(() {
                    _targetType = 'all';
                    _selectedRoles.clear();
                    _selectedUsers.clear();
                    _userResults.clear();
                  });
                },
              ),
              _TargetChip(
                label: 'Theo vai trò',
                selected: _targetType == 'role',
                onTap: () {
                  setState(() {
                    _targetType = 'role';
                    _selectedUsers.clear();
                    _userResults.clear();
                  });
                },
              ),
              _TargetChip(
                label: 'Chọn người',
                selected: _targetType == 'users',
                onTap: () {
                  setState(() {
                    _targetType = 'users';
                    _selectedRoles.clear();
                  });
                  _searchUsers();
                },
              ),
            ],
          ),
          if (_targetType == 'role') ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RoleCheckChip(
                  label: 'Sinh viên',
                  value: 'student',
                  selectedValues: _selectedRoles,
                  onChanged: () => setState(() {}),
                ),
                _RoleCheckChip(
                  label: 'Giảng viên',
                  value: 'teacher',
                  selectedValues: _selectedRoles,
                  onChanged: () => setState(() {}),
                ),
                _RoleCheckChip(
                  label: 'QLSV',
                  value: 'qlsv',
                  selectedValues: _selectedRoles,
                  onChanged: () => setState(() {}),
                ),
                _RoleCheckChip(
                  label: 'Admin',
                  value: 'admin',
                  selectedValues: _selectedRoles,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ],
          if (_targetType == 'users') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _userSearchCtrl,
              onSubmitted: (_) => _searchUsers(),
              decoration: InputDecoration(
                hintText: 'Tìm tên, email, mã sinh viên...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _searchUsers,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _primary, width: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedUsers.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUsers.map((u) {
                  final name = (u['fullName'] ?? u['email'] ?? '').toString();

                  return Chip(
                    label: Text(name),
                    deleteIcon: const Icon(Icons.close_rounded, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedUsers.removeWhere(
                          (x) =>
                              (x['uid'] ?? x['id'] ?? '').toString() ==
                              (u['uid'] ?? u['id'] ?? '').toString(),
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (_loadingUsers)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: _userResults.map((u) {
                  final uid = (u['uid'] ?? u['id'] ?? '').toString();
                  final name = (u['fullName'] ?? 'Chưa có tên').toString();
                  final email = (u['email'] ?? '').toString();
                  final role = (u['role'] ?? '').toString();

                  final selected = _selectedUsers.any(
                    (x) => (x['uid'] ?? x['id'] ?? '').toString() == uid,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEDEFF6) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? _primary : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedUsers.removeWhere(
                              (x) =>
                                  (x['uid'] ?? x['id'] ?? '').toString() == uid,
                            );
                          } else {
                            _selectedUsers.add(u);
                          }
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEDEFF6),
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text('$email • ${_roleLabel(role)}'),
                      trailing: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? _primary : const Color(0xFF94A3B8),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (_isEditing ? _success : _primary).withOpacity(
                  0.1,
                ),
                child: Icon(
                  _isEditing
                      ? Icons.edit_note_rounded
                      : Icons.add_alert_rounded,
                  color: _isEditing ? _success : _primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEditing ? 'Chỉnh sửa thông báo' : 'Tạo thông báo mới',
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Đang sửa',
                    style: TextStyle(
                      color: _success,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Tiêu đề',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF23324D),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'Nhập tiêu đề thông báo',
              icon: Icons.title_rounded,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nội dung',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF23324D),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            maxLines: 6,
            decoration: _inputDecoration(
              hint: 'Nhập nội dung thông báo',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 18),
          if (!_isEditing) ...[
            _buildTargetSelector(),
            const SizedBox(height: 22),
          ] else
            const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sending ? null : _sendNotification,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEditing ? Icons.save_rounded : Icons.send_rounded,
                        ),
                  label: Text(
                    _sending
                        ? 'Đang xử lý...'
                        : (_isEditing ? 'Cập nhật' : 'Gửi thông báo'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: OutlinedButton(
                    onPressed: _sending ? null : _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Icon(Icons.close_rounded, color: _textMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignList() {
    if (_loadingList) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 14),
            Text(
              'Đang tải danh sách thông báo...',
              style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (_campaigns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFEFF4FF),
              child: Icon(
                Icons.notifications_off_rounded,
                color: _primary,
                size: 34,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Chưa có thông báo nào',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Thông báo sau khi gửi sẽ hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _campaigns.map((item) {
        return _CampaignCard(
          item: item,
          isEditing: _editingId == (item['id'] ?? '').toString(),
          onEdit: () => _startEdit(item),
          onDelete: () => _deleteCampaign(item),
          formatDate: _formatDate,
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Danh sách thông báo đã gửi',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: _loadingList ? null : _loadCampaigns,
          icon: const Icon(Icons.refresh_rounded),
          color: _primary,
          tooltip: 'Làm mới',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Quản lý thông báo',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _loadCampaigns,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFormCard(),
            const SizedBox(height: 20),
            _buildSectionTitle(),
            const SizedBox(height: 8),
            _buildCampaignList(),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  static const _primary = Color(0xFF1B2A8A);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _danger = Color(0xFFEF4444);
  static const _success = Color(0xFF16A34A);

  final Map<String, dynamic> item;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(dynamic value) formatDate;

  const _CampaignCard({
    required this.item,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? 'Thông báo').toString();
    final body = (item['body'] ?? '').toString();
    final audienceText = (item['audienceText'] ?? 'Tất cả người dùng')
        .toString();
    final receiverCount =
        int.tryParse((item['receiverCount'] ?? 0).toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEditing ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEditing ? _success : const Color(0xFFE2E8F0),
          width: isEditing ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isEditing
                    ? _success.withOpacity(0.1)
                    : _primary.withOpacity(0.08),
                child: Icon(
                  isEditing ? Icons.edit_rounded : Icons.campaign_rounded,
                  color: isEditing ? _success : _primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              if (isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Đang sửa',
                    style: TextStyle(
                      color: _success,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 16,
                      color: _primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        audienceText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (receiverCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '$receiverCount người nhận',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Gửi lúc: ${formatDate(item['createdAt'])}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Sửa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: Color(0xFFD7DDF0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Xóa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RoleCheckChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> selectedValues;
  final VoidCallback onChanged;

  const _RoleCheckChip({
    required this.label,
    required this.value,
    required this.selectedValues,
    required this.onChanged,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    final selected = selectedValues.contains(value);

    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFEDEFF6),
      checkmarkColor: _primary,
      labelStyle: TextStyle(
        color: selected ? _primary : const Color(0xFF334155),
        fontWeight: FontWeight.w900,
      ),
      onSelected: (_) {
        if (selected) {
          selectedValues.remove(value);
        } else {
          selectedValues.add(value);
        }

        onChanged();
      },
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'student':
      return 'Sinh viên';
    case 'teacher':
      return 'Giảng viên';
    case 'qlsv':
      return 'QLSV';
    case 'admin':
      return 'Admin';
    default:
      return 'Không rõ';
  }
}
