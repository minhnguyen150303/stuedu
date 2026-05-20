import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class AdminSendNotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const AdminSendNotificationsScreen({super.key, required this.profile});

  @override
  State<AdminSendNotificationsScreen> createState() =>
      _AdminSendNotificationsScreenState();
}

class _AdminSendNotificationsScreenState
    extends State<AdminSendNotificationsScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminRepository _repo;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  List<Map<String, dynamic>> _campaigns = [];
  String? _editingId;
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _repo = AdminRepository(ApiClient(AppConfig.baseUrl));
    _loadCampaigns();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
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

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      Map<String, dynamic> result;

      if (_editingId == null) {
        result = await _repo.createNotificationCampaign(
          title: title,
          body: body,
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
                      : 'Đã tạo thông báo')
                : (updatedCount != null
                      ? 'Đã cập nhật và đồng bộ $updatedCount thông báo'
                      : 'Đã cập nhật thông báo'),
          ),
        ),
      );

      _titleCtrl.clear();
      _bodyCtrl.clear();

      setState(() {
        _editingId = null;
      });

      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      _editingId = (item['id'] ?? '').toString();
      _titleCtrl.text = (item['title'] ?? '').toString();
      _bodyCtrl.text = (item['body'] ?? '').toString();
    });
  }

  Future<void> _deleteCampaign(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thông báo'),
        content: const Text(
          'Bạn có chắc muốn xóa thông báo này không? Thông báo sẽ bị xóa khỏi toàn bộ người nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
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
        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() {
          _editingId = null;
        });
      }

      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  void _cancelEdit() {
    _titleCtrl.clear();
    _bodyCtrl.clear();
    setState(() {
      _editingId = null;
    });
  }

  Widget _buildCampaignList() {
    if (_loadingList) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_campaigns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Chưa có thông báo nào đã gửi.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: _campaigns.map((item) {
        final title = (item['title'] ?? '').toString();
        final body = (item['body'] ?? '').toString();
        final createdAt = (item['createdAt'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                createdAt,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _startEdit(item),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Sửa'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _deleteCampaign(item),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Xóa'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Quản lý thông báo',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tạo thông báo mới',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tiêu đề',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF23324D),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nhập tiêu đề thông báo',
                    filled: true,
                    fillColor: const Color(0xFFF3F5FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nội dung',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF23324D),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Nhập nội dung thông báo',
                    filled: true,
                    fillColor: const Color(0xFFF3F5FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendNotification,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending
                          ? 'Đang xử lý...'
                          : (_editingId == null
                                ? 'Gửi thông báo'
                                : 'Cập nhật thông báo'),
                    ),
                  ),
                ),
                if (_editingId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _cancelEdit,
                      child: const Text('Hủy chỉnh sửa'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Danh sách thông báo đã gửi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _buildCampaignList(),
        ],
      ),
    );
  }
}
