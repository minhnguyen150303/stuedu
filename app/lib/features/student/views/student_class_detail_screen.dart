import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/repositories/student_chat_repository.dart';

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

bool _isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.contains('/image/upload/');
}

bool _isPdfUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.pdf') || lower.contains('.pdf?');
}

Future<void> _openUrlExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        final url = (e['url'] ?? e['downloadUrl'] ?? '').toString().trim();
        return url.isNotEmpty;
      })
      .toList();
}

String _attachmentDisplayName(Map<String, dynamic> attachment) {
  final originalName = (attachment['originalName'] ?? '').toString().trim();
  if (originalName.isNotEmpty) return originalName;

  final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '')
      .toString()
      .trim();

  final uri = Uri.tryParse(url);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.last;
  }

  return 'Tệp đính kèm';
}

bool _isImageAttachment(Map<String, dynamic> attachment) {
  final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final name = _attachmentDisplayName(attachment).toLowerCase();
  final resourceType = (attachment['resourceType'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final format = (attachment['format'] ?? '').toString().trim().toLowerCase();

  return resourceType == 'image' ||
      format == 'jpg' ||
      format == 'jpeg' ||
      format == 'png' ||
      format == 'webp' ||
      format == 'gif' ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png') ||
      name.endsWith('.webp') ||
      name.endsWith('.gif') ||
      _isImageUrl(url);
}

bool _isPdfAttachment(Map<String, dynamic> attachment) {
  final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final name = _attachmentDisplayName(attachment).toLowerCase();
  final format = (attachment['format'] ?? '').toString().trim().toLowerCase();

  return format == 'pdf' || name.endsWith('.pdf') || _isPdfUrl(url);
}

void _showAttachmentImagePreview(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tải được ảnh'),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildAssignmentAttachmentPreviewList(
  BuildContext context,
  List<Map<String, dynamic>> attachments,
  Future<void> Function(Map<String, dynamic> attachment) onDownload,
) {
  if (attachments.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      const Text(
        'Tệp đính kèm',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: attachments.map((attachment) {
          final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '')
              .toString()
              .trim();
          final fileName = _attachmentDisplayName(attachment);
          final isImage = _isImageAttachment(attachment);
          final isPdf = _isPdfAttachment(attachment);

          return Container(
            width: 140,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.attach_file,
                      size: 34,
                      color: isPdf
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF475569),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onDownload(attachment),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tải xuống'),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ],
  );
}

class StudentClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> classItem;

  const StudentClassDetailScreen({
    super.key,
    required this.profile,
    required this.classItem,
  });

  @override
  State<StudentClassDetailScreen> createState() =>
      _StudentClassDetailScreenState();
}

class _StudentClassDetailScreenState extends State<StudentClassDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);

  late final StudentChatRepository _chatRepo;
  late final StudentRepository _repo;
  static const MethodChannel _downloadsChannel = MethodChannel(
    'stu_edu/downloads',
  );
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  String? _submittingAssignmentId;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(ApiClient(AppConfig.baseUrl));
    _chatRepo = StudentChatRepository();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final classId =
        (widget.classItem['classId'] ?? widget.classItem['id'] ?? '')
            .toString();

    try {
      final results = await Future.wait([
        _repo.getClassStudents(classId),
        _repo.getClassAssignments(classId),
        _repo.getClassMaterials(classId),
        _repo.getMyGrades(),
      ]);

      if (!mounted) return;

      final allGrades = List<Map<String, dynamic>>.from(results[3] as List);
      final myClassGrades = allGrades
          .where((e) => '${e['classId']}' == classId)
          .toList();

      setState(() {
        _students = List<Map<String, dynamic>>.from(results[0] as List);
        _assignments = List<Map<String, dynamic>>.from(results[1] as List);
        _materials = List<Map<String, dynamic>>.from(results[2] as List);
        _grades = myClassGrades;
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

  String _joinPath(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return '$a$b';
    return '$a${Platform.pathSeparator}$b';
  }

  Future<String> _writeBytesToPath({
    required String fullPath,
    required Uint8List bytes,
  }) async {
    final file = File(fullPath);
    final parent = file.parent;

    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _resolveSavePath({required String safeFileName}) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Không tìm thấy thư mục Downloads');
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      return _joinPath(downloadsDir.path, safeFileName);
    }

    if (Platform.isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      return _joinPath(docsDir.path, safeFileName);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    return _joinPath(docsDir.path, safeFileName);
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.txt')) return 'text/plain';

    return 'application/octet-stream';
  }

  Future<String?> _saveToAndroidDownloads({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return null;

    final result = await _downloadsChannel.invokeMethod<String>(
      'saveToDownloads',
      {
        'fileName': fileName,
        'folderName': 'StuEdu',
        'mimeType': mimeType,
        'bytes': bytes,
      },
    );

    return result;
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    try {
      final primaryUrl =
          (attachment['downloadUrl'] ??
                  attachment['url'] ??
                  attachment['fileUrl'] ??
                  '')
              .toString()
              .trim();

      final fallbackUrl = (attachment['url'] ?? attachment['fileUrl'] ?? '')
          .toString()
          .trim();

      if (primaryUrl.isEmpty && fallbackUrl.isEmpty) {
        throw Exception('Không tìm thấy URL file');
      }

      final rawName = _attachmentDisplayName(attachment).trim();
      final safeName = _sanitizeFileName(
        rawName.isEmpty ? 'downloaded_file' : rawName,
      );

      Response<List<int>>? response;
      Object? lastError;

      for (final candidate in [primaryUrl, fallbackUrl]) {
        if (candidate.isEmpty) continue;

        try {
          response = await Dio().get<List<int>>(
            Uri.encodeFull(candidate),
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              receiveTimeout: const Duration(seconds: 60),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

          if (response.statusCode == 200 &&
              response.data != null &&
              response.data!.isNotEmpty) {
            break;
          }
        } catch (e) {
          lastError = e;
        }
      }

      if (response == null ||
          response.statusCode != 200 ||
          response.data == null ||
          response.data!.isEmpty) {
        throw Exception(
          'Không tải được file. ${lastError ?? "URL không hợp lệ hoặc server trả lỗi"}',
        );
      }

      final bytes = Uint8List.fromList(response.data!);

      if (Platform.isAndroid) {
        final mimeType = _guessMimeType(safeName);

        await _saveToAndroidDownloads(
          bytes: bytes,
          fileName: safeName,
          mimeType: mimeType,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tải file thành công vào Downloads: $safeName'),
          ),
        );

        return;
      }

      final savePath = await _resolveSavePath(safeFileName: safeName);
      final savedPath = await _writeBytesToPath(
        fullPath: savePath,
        bytes: bytes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã lưu file: $savedPath')));

      final result = await OpenFilex.open(savedPath);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã tải xong nhưng không mở được file: ${result.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tải file thất bại: $e')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courseName = (widget.classItem['courseName'] ?? 'Lớp học').toString();
    final room = (widget.classItem['room'] ?? '').toString();
    final classCode = (widget.classItem['classCode'] ?? '').toString();
    final studentCount = _students.length.toString();

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
          'Chi tiết lớp học',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _HeaderCard(
                    courseName: courseName,
                    room: room,
                    classCode: classCode,
                    studentCount: studentCount,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    dividerColor: Colors.transparent,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Sinh viên'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Bài tập'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Tài liệu'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Điểm'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Nhắn tin'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _StudentsTab(items: _students),
                      _AssignmentsTab(
                        items: _assignments,
                        submittingAssignmentId: _submittingAssignmentId,
                        onSubmit: _submitAssignment,
                        onDownload: _downloadAttachment,
                      ),
                      _MaterialsTab(
                        items: _materials,
                        onDownload: _downloadAttachment,
                      ),
                      _GradesTab(items: _grades),
                      _ClassChatTab(
                        classId:
                            (widget.classItem['classId'] ??
                                    widget.classItem['id'] ??
                                    '')
                                .toString(),
                        profile: widget.profile,
                        chatRepo: _chatRepo,
                        onUploadFile: _repo.uploadFileDetailed,
                        onDownloadAttachment: _downloadAttachment,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String courseName;
  final String room;
  final String classCode;
  final String studentCount;

  const _HeaderCard({
    required this.courseName,
    required this.room,
    required this.classCode,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFF),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Text(
              'L',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B2A8A),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phòng học • ${room.isEmpty ? "Chưa cập nhật" : room}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sĩ số • $studentCount sinh viên',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEBFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    classCode,
                    style: const TextStyle(
                      color: Color(0xFF1B2A8A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _StudentsTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyCenter(message: 'Không có dữ liệu.');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final row = items[i];
        final user = Map<String, dynamic>.from(
          (row['user'] as Map?) ?? const {},
        );
        final fullName = (user['fullName'] ?? '').toString();
        final studentCode = (user['studentInfo']?['studentCode'] ?? '')
            .toString();
        final email = (user['email'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEDEBFF),
                child: Text(
                  fullName.isEmpty ? '?' : fullName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF1B2A8A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studentCode.isNotEmpty ? studentCode : email,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? submittingAssignmentId;
  final Future<void> Function(Map<String, dynamic> item) onSubmit;
  final Future<void> Function(Map<String, dynamic> attachment) onDownload;

  const _AssignmentsTab({
    required this.items,
    required this.submittingAssignmentId,
    required this.onSubmit,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyCenter(message: 'Không có dữ liệu.');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        final assignmentId = (item['id'] ?? '').toString();
        final deadline = _parseFlexibleDate(item['deadline']);
        final isExpired = deadline != null && DateTime.now().isAfter(deadline);

        final submission = Map<String, dynamic>.from(
          (item['mySubmission'] as Map?) ?? const {},
        );
        final hasSubmission = submission.isNotEmpty;
        final submittedAt = _parseFlexibleDate(submission['submittedAt']);
        final isSubmitting = submittingAssignmentId == assignmentId;
        final fileName = (submission['originalName'] ?? '').toString().trim();

        final attachments = _extractAttachments(item['attachments']);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
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
                (item['content'] ?? '').toString(),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hạn nộp: ${_formatDateTimeVi(item['deadline'])}',
                      style: TextStyle(
                        color: isExpired ? Colors.redAccent : Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              if (attachments.isNotEmpty)
                _buildAssignmentAttachmentPreviewList(
                  context,
                  attachments,
                  onDownload,
                ),

              const SizedBox(height: 10),

              if (hasSubmission)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8E6FF)),
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
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                      ],
                      if (submittedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Lúc nộp: ${_formatDateTimeVi(submission['submittedAt'])}',
                          style: const TextStyle(color: Color(0xFF475569)),
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
                          color: submission['assignmentScore'] == null
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: submission['assignmentScore'] == null
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
                              color: submission['assignmentScore'] == null
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                submission['assignmentScore'] == null
                                    ? 'Giáo viên chưa chấm điểm bài tập'
                                    : 'Điểm bài tập: ${submission['assignmentScore']} / 10',
                                style: TextStyle(
                                  color: submission['assignmentScore'] == null
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF15803D),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (hasSubmission) const SizedBox(height: 12),

              if (!isExpired)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSubmitting ? null : () => onSubmit(item),
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
                          : (hasSubmission ? 'Nộp lại bài' : 'Nộp bài'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    border: Border.all(color: const Color(0xFFFECDD3)),
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
        );
      },
    );
  }
}

class _MaterialsTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> attachment) onDownload;

  const _MaterialsTab({required this.items, required this.onDownload});

  List<Map<String, dynamic>> _materialToAttachments(Map<String, dynamic> item) {
    final url = (item['url'] ?? '').toString().trim();
    final downloadUrl = (item['downloadUrl'] ?? url).toString().trim();

    if (url.isEmpty && downloadUrl.isEmpty) return const [];

    return [
      {
        'url': url.isNotEmpty ? url : downloadUrl,
        'downloadUrl': downloadUrl.isNotEmpty ? downloadUrl : url,
        'publicId': item['publicId'],
        'originalName': (item['originalName'] ?? item['title'] ?? 'Tai_lieu')
            .toString(),
        'resourceType': (item['resourceType'] ?? item['type'] ?? 'raw')
            .toString(),
        'format': (item['format'] ?? '').toString(),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyCenter(message: 'Không có dữ liệu.');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        final title = (item['title'] ?? 'Tài liệu').toString();
        final type = (item['type'] ?? '').toString();
        final createdAtText = _formatDateTimeVi(item['createdAt']);
        final attachments = _materialToAttachments(item);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                type.isEmpty ? 'Tài liệu môn học' : 'Loại: $type',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Giáo viên đăng lúc: $createdAtText',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (attachments.isNotEmpty)
                _buildAssignmentAttachmentPreviewList(
                  context,
                  attachments,
                  onDownload,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GradesTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _GradesTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyCenter(message: 'Không có dữ liệu.');

    final item = items.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradeRow(
          label: 'Điểm quá trình',
          value: '${item['scoreProcess'] ?? 0}',
        ),
        _GradeRow(label: 'Giữa kỳ', value: '${item['scoreMid'] ?? 0}'),
        _GradeRow(label: 'Cuối kỳ', value: '${item['scoreFinal'] ?? 0}'),
        _GradeRow(label: 'Tổng kết hệ 10', value: '${item['totalTen'] ?? 0}'),
        _GradeRow(label: 'Hệ 4', value: '${item['gpa4'] ?? 0}'),
        _GradeRow(label: 'Trạng thái', value: '${item['status'] ?? ''}'),
      ],
    );
  }
}

class _GradeRow extends StatelessWidget {
  final String label;
  final String value;

  const _GradeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
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
          'Không tải được dữ liệu lớp học',
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

class _ClassChatTab extends StatefulWidget {
  final String classId;
  final Map<String, dynamic> profile;
  final StudentChatRepository chatRepo;
  final Future<Map<String, dynamic>> Function(File file) onUploadFile;
  final Future<void> Function(Map<String, dynamic> attachment)
  onDownloadAttachment;

  const _ClassChatTab({
    required this.classId,
    required this.profile,
    required this.chatRepo,
    required this.onUploadFile,
    required this.onDownloadAttachment,
  });

  @override
  State<_ClassChatTab> createState() => _ClassChatTabState();
}

class _ClassChatTabState extends State<_ClassChatTab> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _sending = false;
  bool _uploadingAttachment = false;
  List<Map<String, dynamic>> _pendingAttachments = [];

  Future<void> _toggleLike(
    Map<String, dynamic> item, {
    required bool isLocked,
  }) async {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F172A),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chat đang khóa, không thể thả cảm xúc.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final messageId = (item['id'] ?? '').toString();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (messageId.isEmpty || myUid.isEmpty) return;

    final likedByRaw = item['likedBy'];
    final likedBy = likedByRaw is List
        ? likedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final liked = likedBy.contains(myUid);

    try {
      await widget.chatRepo.toggleLikeMessage(
        classId: widget.classId,
        messageId: messageId,
        uid: myUid,
        liked: liked,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Không thể thả cảm xúc lúc này.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickChatFile({required bool isLocked}) async {
    if (isLocked) {
      _showChatSnack(
        icon: Icons.lock_rounded,
        message: 'Chat đang khóa, không thể gửi tệp.',
        backgroundColor: const Color(0xFF0F172A),
      );
      return;
    }

    if (_uploadingAttachment || _sending) return;

    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      _showChatSnack(
        icon: Icons.error_outline_rounded,
        message: 'Không đọc được file đã chọn.',
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    setState(() {
      _uploadingAttachment = true;
    });

    try {
      final uploaded = await widget.onUploadFile(File(path));

      final attachment = <String, dynamic>{
        'url': (uploaded['url'] ?? '').toString(),
        'downloadUrl': uploaded['downloadUrl']?.toString(),
        'publicId': uploaded['publicId']?.toString(),
        'resourceType': (uploaded['resourceType'] ?? 'raw').toString(),
        'originalName': (uploaded['originalName'] ?? picked.files.single.name)
            .toString(),
        'format': uploaded['format']?.toString(),
        'size': picked.files.single.size,
      };

      if ((attachment['url'] ?? '').toString().isEmpty) {
        throw Exception('Upload không trả về URL');
      }

      if (!mounted) return;

      setState(() {
        _pendingAttachments = [attachment];
      });
    } catch (_) {
      if (!mounted) return;

      _showChatSnack(
        icon: Icons.error_outline_rounded,
        message: 'Upload file thất bại.',
        backgroundColor: const Color(0xFFDC2626),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
        });
      }
    }
  }

  void _removePendingAttachment() {
    setState(() {
      _pendingAttachments.clear();
    });
  }

  void _showChatSnack({
    required IconData icon,
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _messageAttachments(Map<String, dynamic> item) {
    final raw = item['attachments'];
    if (raw is! List) return [];

    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where(
          (e) => (e['url'] ?? e['downloadUrl'] ?? '').toString().isNotEmpty,
        )
        .toList();
  }

  Widget _buildPendingAttachmentPreview() {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();

    final file = _pendingAttachments.first;
    final name = _attachmentDisplayName(file);
    final url = (file['url'] ?? '').toString();
    final isImage = _isImageAttachment(file);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded),
              ),
            )
          else
            const Icon(Icons.attach_file_rounded, color: Color(0xFF1B2A8A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _removePendingAttachment,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageAttachments(
    List<Map<String, dynamic>> attachments, {
    required bool mine,
  }) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((attachment) {
        final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '')
            .toString();
        final name = _attachmentDisplayName(attachment);
        final isImage = _isImageAttachment(attachment);
        final isPdf = _isPdfAttachment(attachment);

        if (isImage) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _showAttachmentImagePreview(context, url),
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  width: 210,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 210,
                    height: 120,
                    alignment: Alignment.center,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.broken_image_rounded),
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => widget.onDownloadAttachment(attachment),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withOpacity(0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: mine ? Colors.white24 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.insert_drive_file_rounded,
                    color: isPdf
                        ? const Color(0xFFDC2626)
                        : (mine ? Colors.white : const Color(0xFF1B2A8A)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mine ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: mine ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();

    if ((text.isEmpty && _pendingAttachments.isEmpty) || _sending) return;

    final attachments = List<Map<String, dynamic>>.from(_pendingAttachments);

    setState(() => _sending = true);

    try {
      await widget.chatRepo.sendMessage(
        classId: widget.classId,
        text: text,
        profile: widget.profile,
        attachments: attachments,
      );

      _messageCtrl.clear();

      setState(() {
        _pendingAttachments.clear();
      });
    } catch (_) {
      if (!mounted) return;

      _showChatSnack(
        icon: Icons.error_outline_rounded,
        message: 'Gửi tin nhắn thất bại.',
        backgroundColor: const Color(0xFFDC2626),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMine(Map<String, dynamic> item) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return (item['senderId'] ?? '').toString() == myUid;
  }

  bool _isTeacher(Map<String, dynamic> item) {
    return (item['senderRole'] ?? '').toString() == 'teacher';
  }

  bool _canDelete(Map<String, dynamic> item) {
    final role = (widget.profile['role'] ?? '').toString();
    return role == 'teacher';
  }

  String _formatTime(dynamic raw) {
    DateTime? dt;

    if (raw is Timestamp) {
      dt = raw.toDate().toLocal();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw)?.toLocal();
    }

    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    if (diff == 0) return 'Hôm nay $hh:$mm';
    if (diff == -1) return 'Hôm qua $hh:$mm';

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  Future<void> _deleteMessage(Map<String, dynamic> item) async {
    final messageId = (item['id'] ?? '').toString();
    if (messageId.isEmpty) return;

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;

    try {
      await widget.chatRepo.softDeleteMessage(
        classId: widget.classId,
        messageId: messageId,
        deletedBy: myUid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa tin nhắn thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.classId.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy classId',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.chatRepo.streamClassChatRoom(widget.classId),
      builder: (context, roomSnapshot) {
        final roomData = roomSnapshot.data ?? const {};
        final isLocked = roomData['isLocked'] == true;

        return Column(
          children: [
            if (isLocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Text(
                  'Lớp đã kết thúc hoặc chưa mở học, chat chỉ còn chế độ xem.',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.chatRepo.streamClassMessages(widget.classId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Không tải được tin nhắn: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có tin nhắn nào trong lớp.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final mine = _isMine(item);
                      final teacher = _isTeacher(item);
                      final deleted = item['deleted'] == true;

                      final myUid =
                          FirebaseAuth.instance.currentUser?.uid ?? '';
                      final likedByRaw = item['likedBy'];
                      final likedBy = likedByRaw is List
                          ? likedByRaw.map((e) => e.toString()).toList()
                          : <String>[];

                      final liked = likedBy.contains(myUid);
                      final likeCount = likedBy.length;
                      final attachments = _messageAttachments(item);
                      final text = (item['text'] ?? '').toString();

                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onDoubleTap: deleted
                              ? null
                              : () => _toggleLike(item, isLocked: isLocked),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                decoration: BoxDecoration(
                                  color: deleted
                                      ? const Color(0xFFF1F5F9)
                                      : teacher
                                      ? const Color(0xFFFFF7ED)
                                      : mine
                                      ? const Color(0xFF1B2A8A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: mine || deleted
                                      ? null
                                      : Border.all(color: Colors.black12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!mine && !deleted)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (item['senderName'] ??
                                                      'Người dùng')
                                                  .toString(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: teacher
                                                    ? Colors.deepOrange
                                                    : const Color(0xFF1B2A8A),
                                              ),
                                            ),
                                          ),
                                          if (teacher)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEDD5),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Giảng viên',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.deepOrange,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    if (!mine && !deleted)
                                      const SizedBox(height: 4),
                                    if (deleted)
                                      Text(
                                        'Tin nhắn đã bị xóa',
                                        style: TextStyle(
                                          color: const Color(0xFF64748B),
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          height: 1.35,
                                        ),
                                      )
                                    else ...[
                                      _buildMessageAttachments(
                                        attachments,
                                        mine: mine,
                                      ),
                                      if (text.isNotEmpty)
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: mine
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 14,
                                            height: 1.35,
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (!deleted && _canDelete(item))
                                          InkWell(
                                            onTap: () => _deleteMessage(item),
                                            child: const Padding(
                                              padding: EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          _formatTime(item['createdAt']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: mine
                                                ? Colors.white70
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (!deleted)
                                Positioned(
                                  right: mine ? 6 : null,
                                  left: mine ? null : 6,
                                  bottom: -10,
                                  child: InkWell(
                                    onTap: () =>
                                        _toggleLike(item, isLocked: isLocked),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.08,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            liked
                                                ? Icons.thumb_up_alt_rounded
                                                : Icons.thumb_up_alt_outlined,
                                            size: 15,
                                            color: liked
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF94A3B8),
                                          ),
                                          if (likeCount > 0) ...[
                                            const SizedBox(width: 3),
                                            Text(
                                              '$likeCount',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPendingAttachmentPreview(),
                    Row(
                      children: [
                        IconButton(
                          onPressed: (_sending || _uploadingAttachment)
                              ? null
                              : () => _pickChatFile(isLocked: isLocked),
                          icon: _uploadingAttachment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          color: const Color(0xFF1B2A8A),
                          tooltip: 'Gửi ảnh/file',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageCtrl,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !isLocked && !_sending,
                            decoration: InputDecoration(
                              hintText: isLocked
                                  ? 'Chat đang bị khóa'
                                  : 'Nhắn vào nhóm lớp...',
                              filled: true,
                              fillColor: isLocked
                                  ? const Color(0xFFF1F5F9)
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            onSubmitted: (_) => isLocked ? null : _send(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: FilledButton(
                            onPressed: (_sending || isLocked) ? null : _send,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1B2A8A),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
