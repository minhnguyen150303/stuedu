import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/sources/remote/api_client.dart';

DateTime? _parseFlexibleDate(dynamic raw) {
  if (raw == null) return null;

  if (raw is String) {
    final dt = DateTime.tryParse(raw);
    return dt?.toLocal();
  }

  if (raw is Map) {
    final seconds = raw['_seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();
    }
  }

  final dt = DateTime.tryParse(raw.toString());
  return dt?.toLocal();
}

String _formatDateTimeVi(dynamic raw) {
  final dt = _parseFlexibleDate(raw);
  if (dt == null) return 'Chưa có hạn';

  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _extractAttachments(dynamic raw) {
  final list = (raw as List?) ?? const [];

  return list
      .map((e) {
        if (e is Map<String, dynamic>) {
          return Map<String, dynamic>.from(e);
        }

        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }

        return {
          'url': e.toString(),
          'originalName': '',
          'resourceType': '',
          'format': '',
        };
      })
      .where((e) {
        final url = (e['url'] ?? '').toString().trim();
        return url.isNotEmpty;
      })
      .toList();
}

String _attachmentDisplayName(Map<String, dynamic> attachment) {
  final originalName = (attachment['originalName'] ?? '').toString().trim();
  if (originalName.isNotEmpty) return originalName;

  final url = (attachment['url'] ?? '').toString().trim();
  final uri = Uri.tryParse(url);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.last;
  }

  return 'Tệp đính kèm';
}

class StudentAssignmentsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const StudentAssignmentsScreen({super.key, required this.profile});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);

  late final StudentRepository _repo;
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  String? _submittingAssignmentId;

  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final items = await _repo.getAllMyAssignments();

      if (!mounted) return;

      setState(() {
        _assignments = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _hasSubmission(Map<String, dynamic> item) {
    final submission = Map<String, dynamic>.from(
      (item['mySubmission'] as Map?) ?? const {},
    );
    return submission.isNotEmpty;
  }

  bool _isExpired(Map<String, dynamic> item) {
    final deadline = _parseFlexibleDate(item['deadline']);
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  Future<void> _submitAssignment(Map<String, dynamic> item) async {
    final assignmentId = (item['id'] ?? '').toString();
    if (assignmentId.isEmpty) {
      _show('Không tìm thấy assignmentId');
      return;
    }

    final deadline = _parseFlexibleDate(item['deadline']);
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _show('Bài tập đã hết hạn');
      return;
    }

    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      _show('Không đọc được file đã chọn');
      return;
    }

    setState(() {
      _submittingAssignmentId = assignmentId;
    });

    try {
      final uploaded = await _repo.uploadFileDetailed(File(path));
      await _repo.submitAssignment(
        assignmentId: assignmentId,
        uploadedFile: uploaded,
      );

      await _loadData();
      if (!mounted) return;
      _show('Nộp bài thành công');
    } catch (e) {
      if (!mounted) return;
      _show('Nộp bài thất bại: $e');
    } finally {
      if (mounted) {
        setState(() {
          _submittingAssignmentId = null;
        });
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByCourse(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final courseCode = (item['courseCode'] ?? '').toString().trim();
      final courseName = (item['courseName'] ?? 'Môn học').toString().trim();
      final key = courseCode.isEmpty ? courseName : '$courseCode • $courseName';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return grouped;
  }

  List<Map<String, dynamic>> get _activeItems {
    final items = _assignments.where((item) {
      return !_hasSubmission(item) && !_isExpired(item);
    }).toList();

    items.sort((a, b) {
      final da = _parseFlexibleDate(a['deadline']) ?? DateTime(2100);
      final db = _parseFlexibleDate(b['deadline']) ?? DateTime(2100);
      return da.compareTo(db);
    });

    return items;
  }

  List<Map<String, dynamic>> get _historyItems {
    final items = _assignments.where((item) {
      return _hasSubmission(item) || _isExpired(item);
    }).toList();

    items.sort((a, b) {
      final da = _parseFlexibleDate(a['deadline']) ?? DateTime(2100);
      final db = _parseFlexibleDate(b['deadline']) ?? DateTime(2100);
      return da.compareTo(db);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chi tiết bài tập',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadData)
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: _primary,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: _primary,
                  tabs: const [
                    Tab(text: 'Còn hạn chưa nộp'),
                    Tab(text: 'Đã nộp / Hết hạn'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _AssignmentsGroupedTab(
                        items: _activeItems,
                        submittingAssignmentId: _submittingAssignmentId,
                        onSubmit: _submitAssignment,
                        groupByCourse: _groupByCourse,
                        emptyMessage:
                            'Không có bài tập nào còn hạn và chưa nộp.',
                      ),
                      _AssignmentsGroupedTab(
                        items: _historyItems,
                        submittingAssignmentId: _submittingAssignmentId,
                        onSubmit: _submitAssignment,
                        groupByCourse: _groupByCourse,
                        emptyMessage: 'Chưa có bài tập đã nộp hoặc hết hạn.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AssignmentsGroupedTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? submittingAssignmentId;
  final Future<void> Function(Map<String, dynamic> item) onSubmit;
  final Map<String, List<Map<String, dynamic>>> Function(
    List<Map<String, dynamic>> items,
  )
  groupByCourse;
  final String emptyMessage;

  const _AssignmentsGroupedTab({
    required this.items,
    required this.submittingAssignmentId,
    required this.onSubmit,
    required this.groupByCourse,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyCenter(message: emptyMessage);
    }

    final grouped = groupByCourse(items);
    final keys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final groupItems = grouped[key] ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                ...groupItems.map((item) {
                  final assignmentId = (item['id'] ?? '').toString();
                  final deadline = _parseFlexibleDate(item['deadline']);
                  final isExpired =
                      deadline != null && DateTime.now().isAfter(deadline);

                  final submission = Map<String, dynamic>.from(
                    (item['mySubmission'] as Map?) ?? const {},
                  );
                  final hasSubmission = submission.isNotEmpty;
                  final submittedAt = _parseFlexibleDate(
                    submission['submittedAt'],
                  );
                  final isSubmitting = submittingAssignmentId == assignmentId;
                  final fileName = (submission['originalName'] ?? '')
                      .toString()
                      .trim();

                  final attachments = _extractAttachments(item['attachments']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] ?? 'Bài tập').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(item['classCode'] ?? '').toString()} • Hạn nộp: ${_formatDateTimeVi(item['deadline'])}',
                            style: TextStyle(
                              color: isExpired
                                  ? Colors.redAccent
                                  : Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (item['content'] ?? '').toString(),
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          if (attachments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Tệp đính kèm',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...attachments.map((attachment) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file_rounded),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _attachmentDisplayName(attachment),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 10),
                          if (hasSubmission)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F8FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD8E6FF),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bạn đã nộp bài',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B2A8A),
                                    ),
                                  ),
                                  if (fileName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'File: $fileName',
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                  if (submittedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lúc nộp: ${_formatDateTimeVi(submission['submittedAt'])}',
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          submission['assignmentScore'] == null
                                          ? const Color(0xFFFFFBEB)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            submission['assignmentScore'] ==
                                                null
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFBBF7D0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          submission['assignmentScore'] == null
                                              ? Icons.hourglass_bottom_rounded
                                              : Icons.check_circle_rounded,
                                          size: 18,
                                          color:
                                              submission['assignmentScore'] ==
                                                  null
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            submission['assignmentScore'] ==
                                                    null
                                                ? 'Giáo viên chưa chấm điểm bài tập'
                                                : 'Điểm bài tập: ${submission['assignmentScore']} / 10',
                                            style: TextStyle(
                                              color:
                                                  submission['assignmentScore'] ==
                                                      null
                                                  ? const Color(0xFF92400E)
                                                  : const Color(0xFF15803D),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (submission['gradedAt'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Đã chấm lúc: ${_formatDateTimeVi(submission['gradedAt'])}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (hasSubmission) const SizedBox(height: 12),
                          if (!isExpired)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () => onSubmit(item),
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file_rounded),
                                label: Text(
                                  isSubmitting
                                      ? 'Đang nộp...'
                                      : (hasSubmission
                                            ? 'Nộp lại bài'
                                            : 'Nộp bài'),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B2A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFECDD3),
                                ),
                              ),
                              child: const Text(
                                'Bài tập đã hết hạn',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCenter extends StatelessWidget {
  final String message;

  const _EmptyCenter({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.error_outline_rounded,
          size: 72,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Không tải được dữ liệu bài tập',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}
