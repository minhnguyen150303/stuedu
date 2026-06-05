import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class TeacherNotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const TeacherNotificationsScreen({super.key, required this.profile});

  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _danger = Color(0xFFEF4444);

  late final TeacherRepository _repo;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  int get _unreadCount =>
      _items.where((e) => e['isRead'] != true).toList().length;

  @override
  void initState() {
    super.initState();
    _repo = TeacherRepository(ApiClient(AppConfig.baseUrl));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repo.getMyNotifications();

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _repo.markNotificationRead(id);
      await _load();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đánh dấu đã đọc thông báo này'),
        ),
      );
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2A8A), Color(0xFF3146C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Trung tâm thông báo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(label: 'Tổng', value: _items.length.toString()),
              const SizedBox(width: 10),
              _HeaderStat(label: 'Chưa đọc', value: _unreadCount.toString()),
              const SizedBox(width: 10),
              _HeaderStat(
                label: 'Đã đọc',
                value: (_items.length - _unreadCount).toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateView({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = _primary,
    bool showRetry = false,
  }) {
    return Container(
      width: double.infinity,
      height: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textMuted,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isRead = item['isRead'] == true;
    final title = (item['title'] ?? 'Thông báo').toString();
    final body = (item['body'] ?? '').toString();

    return InkWell(
      onTap: () async {
        if (!isRead) {
          await _markRead(item['id'].toString());
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : _primary,
            width: isRead ? 1 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? 0.035 : 0.07),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isRead
                  ? const Color(0xFFF1F5F9)
                  : _primary.withOpacity(0.1),
              child: Icon(
                isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: isRead ? _textMuted : _primary,
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
                          title,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 16,
                            fontWeight: isRead
                                ? FontWeight.w800
                                : FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: _danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: const TextStyle(
                        color: _textMuted,
                        height: 1.45,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                          _formatDate(item['createdAt']),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Mới',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
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

  int _itemCount() {
    if (_error != null || _items.isEmpty) return 2;
    return _items.length + 1;
  }

  Widget _buildListItem(BuildContext context, int index) {
    if (index == 0) return _buildHeader();

    if (_error != null) {
      return _buildStateView(
        icon: Icons.error_outline_rounded,
        title: 'Không tải được thông báo',
        subtitle: _error!,
        iconColor: _danger,
        showRetry: true,
      );
    }

    if (_items.isEmpty) {
      return _buildStateView(
        icon: Icons.notifications_off_rounded,
        title: 'Chưa có thông báo',
        subtitle: 'Các thông báo mới sẽ hiển thị tại đây.',
      );
    }

    return _buildNotificationCard(_items[index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _primary),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: _textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _itemCount(),
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: _buildListItem,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
