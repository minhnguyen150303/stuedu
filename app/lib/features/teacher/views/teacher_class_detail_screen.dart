import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/teacher_chat_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'teacher_classes_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_schedule_screen.dart';
import 'teacher_settings_screen.dart';

class TeacherClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> classItem;

  const TeacherClassDetailScreen({
    super.key,
    required this.profile,
    required this.classItem,
  });

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1B2A8A);

  static const MethodChannel _downloadsChannel = MethodChannel(
    'stu_edu/downloads',
  );

  late final TeacherRepository _repo;
  late final TeacherChatRepository _chatRepo;
  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _repo = TeacherRepository(ApiClient(AppConfig.baseUrl));
    _chatRepo = TeacherChatRepository();
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final classId = widget.classItem['id'].toString();

      final students = await _repo.getClassUsers(
        classId: classId,
        status: 'approved',
      );

      final materials = await _repo.getMaterials(classId: classId);
      final assignments = await _repo.getAssignments(classId: classId);
      final grades = await _repo.getGrades(classId: classId);

      setState(() {
        _students = students;
        _materials = materials;
        _assignments = assignments;
        _grades = grades;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  int _totalSubmissions() {
    int total = 0;

    for (final item in _assignments) {
      total += int.tryParse((item['submissionCount'] ?? 0).toString()) ?? 0;
    }

    return total;
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Chưa có hạn';

    try {
      DateTime dt;

      if (value is DateTime) {
        dt = value;
      } else if (value is String) {
        dt = DateTime.parse(value).toLocal();
      } else if (value is Map<String, dynamic>) {
        if (value.containsKey('_seconds')) {
          final seconds = (value['_seconds'] as num).toInt();
          final nanoseconds = ((value['_nanoseconds'] ?? 0) as num).toInt();
          dt = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        } else if (value.containsKey('seconds')) {
          final seconds = (value['seconds'] as num).toInt();
          final nanoseconds = ((value['nanoseconds'] ?? 0) as num).toInt();
          dt = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        } else {
          return value.toString();
        }
      } else {
        return value.toString();
      }

      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is DateTime) return value.toLocal();

      if (value is Timestamp) {
        return value.toDate().toLocal();
      }

      if (value is String) {
        return DateTime.tryParse(value)?.toLocal();
      }

      if (value is Map<String, dynamic>) {
        if (value.containsKey('_seconds')) {
          final seconds = (value['_seconds'] as num).toInt();
          final nanoseconds = ((value['_nanoseconds'] ?? 0) as num).toInt();

          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        }

        if (value.containsKey('seconds')) {
          final seconds = (value['seconds'] as num).toInt();
          final nanoseconds = ((value['nanoseconds'] ?? 0) as num).toInt();

          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        }
      }

      return DateTime.tryParse(value.toString())?.toLocal();
    } catch (_) {
      return null;
    }
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

  String _detectMaterialTypeFromUrl(String url) {
    final lower = url.toLowerCase();

    if (_isImageUrl(lower)) return 'image';
    if (_isPdfUrl(lower)) return 'pdf';

    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'doc';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'sheet';
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return 'slide';
    if (lower.endsWith('.txt')) return 'text';
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return 'archive';
    }

    return 'file';
  }

  IconData _iconForMaterialType(String type) {
    switch (type) {
      case 'image':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
        return Icons.description_outlined;
      case 'sheet':
        return Icons.table_chart_outlined;
      case 'slide':
        return Icons.slideshow_outlined;
      case 'text':
        return Icons.notes_outlined;
      case 'archive':
        return Icons.folder_zip_outlined;
      default:
        return Icons.attach_file;
    }
  }

  Color _colorForMaterialType(String type) {
    switch (type) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'image':
        return const Color(0xFF7C3AED);
      case 'doc':
        return const Color(0xFF2563EB);
      case 'sheet':
        return const Color(0xFF16A34A);
      case 'slide':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF475569);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    if (lower.endsWith('.zip')) return 'application/zip';

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
      {'fileName': fileName, 'mimeType': mimeType, 'bytes': bytes},
    );

    return result;
  }

  Future<void> _openAndroidDownloadedFile({
    required String uri,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return;

    await _downloadsChannel.invokeMethod('openDownloadedFile', {
      'uri': uri,
      'mimeType': mimeType,
    });
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    try {
      final primaryUrl = (attachment['url'] ?? attachment['fileUrl'] ?? '')
          .toString()
          .trim();

      final fallbackUrl = (attachment['downloadUrl'] ?? '').toString().trim();

      if (primaryUrl.isEmpty && fallbackUrl.isEmpty) {
        throw Exception('Không tìm thấy URL file');
      }

      final rawName = _attachmentName(attachment).trim();

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

        final savedUri = await _saveToAndroidDownloads(
          bytes: bytes,
          fileName: safeName,
          mimeType: mimeType,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu vào Downloads, đang mở file...'),
          ),
        );

        if (savedUri != null && savedUri.isNotEmpty) {
          await _openAndroidDownloadedFile(uri: savedUri, mimeType: mimeType);
        }

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

  void _showImagePreview(String imageUrl) {
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

  Widget _buildAttachmentPreviewList(List<String> attachments) {
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
          children: attachments.map((url) {
            if (_isImageUrl(url)) {
              return InkWell(
                onTap: () => _showImagePreview(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            }

            return InkWell(
              onTap: () => _downloadAttachment({'url': url}),
              child: Container(
                width: 88,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isPdfUrl(url) ? Icons.picture_as_pdf : Icons.attach_file,
                      color: _isPdfUrl(url)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF475569),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isPdfUrl(url) ? 'PDF' : 'File',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _extractAttachmentMaps(dynamic raw) {
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
            'downloadUrl': '',
          };
        })
        .where((e) => (e['url'] ?? '').toString().trim().isNotEmpty)
        .toList();
  }

  String _attachmentName(Map<String, dynamic> item) {
    final originalName = (item['originalName'] ?? '').toString().trim();
    if (originalName.isNotEmpty) return originalName;

    final url = (item['url'] ?? item['fileUrl'] ?? item['downloadUrl'] ?? '')
        .toString()
        .trim();

    final uri = Uri.tryParse(url);

    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      final decoded = Uri.decodeComponent(last);

      if (decoded.trim().isNotEmpty) {
        return decoded.split('?').first;
      }
    }

    return 'Tệp đính kèm';
  }

  Widget _buildFileTile({
    required Map<String, dynamic> file,
    required String label,
    required Color color,
  }) {
    final url = (file['downloadUrl'] ?? file['url'] ?? file['fileUrl'] ?? '')
        .toString()
        .trim();

    final previewUrl = (file['url'] ?? file['fileUrl'] ?? '').toString().trim();
    final name = _attachmentName(file);
    final isImage = _isImageUrl(previewUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          if (isImage)
            InkWell(
              onTap: () => _showImagePreview(previewUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  previewUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fileIconBox(color),
                ),
              ),
            )
          else
            _fileIconBox(color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: url.isEmpty ? null : () => _downloadAttachment(file),
            icon: const Icon(Icons.download_rounded),
            color: color,
            tooltip: 'Tải xuống',
          ),
        ],
      ),
    );
  }

  Widget _fileIconBox(Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Icon(Icons.attach_file_rounded, color: color),
    );
  }

  Widget _buildTeacherFilesSection(List<Map<String, dynamic>> attachments) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: const [
            Icon(Icons.folder_rounded, size: 18, color: Color(0xFF1B2A8A)),
            SizedBox(width: 6),
            Text(
              'Tệp giáo viên tải lên',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...attachments.map(
          (file) => _buildFileTile(
            file: file,
            label: 'Đề bài / tài liệu',
            color: const Color(0xFF1B2A8A),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSubmissionsSection(Map<String, dynamic> assignment) {
    final submissionsRaw = (assignment['submissions'] as List?) ?? const [];

    final submissions = submissionsRaw
        .map((e) {
          if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where((e) => e.isNotEmpty)
        .toList();

    if (submissions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            children: const [
              Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
              SizedBox(width: 6),
              Text(
                'Bài sinh viên nộp',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Chưa có sinh viên nào nộp bài.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.people_alt_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(width: 6),
            Text(
              'Bài sinh viên nộp (${submissions.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...submissions.map((submission) {
          final student = Map<String, dynamic>.from(
            (submission['student'] as Map?) ?? const {},
          );

          final studentName = (student['fullName'] ?? 'Sinh viên').toString();
          final studentCode = (student['studentCode'] ?? '').toString();
          final submittedAt = _formatDateTime(submission['submittedAt']);

          final file = Map<String, dynamic>.from(
            (submission['file'] as Map?) ??
                {
                  'url': submission['fileUrl'],
                  'downloadUrl': submission['downloadUrl'],
                  'originalName': submission['originalName'],
                  'resourceType': submission['resourceType'],
                  'format': submission['format'],
                },
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            studentCode.isEmpty
                                ? 'Nộp lúc: $submittedAt'
                                : '$studentCode • $submittedAt',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildFileTile(
                  file: file,
                  label: 'Bài làm sinh viên',
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<DateTime?> _pickDeadlineDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final safeInitial = initial != null && initial.isAfter(now) ? initial : now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Map<String, dynamic>? _findGradeByStudent(String studentId) {
    try {
      return _grades.firstWhere(
        (g) => (g['studentId'] ?? '').toString() == studentId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final classCode = (widget.classItem['classCode'] ?? '').toString();
    final courseName = (widget.classItem['courseName'] ?? 'Chưa rõ môn')
        .toString();
    final room = (widget.classItem['room'] ?? '--').toString();
    final maxStudents =
        int.tryParse(
          (widget.classItem['capacity'] ??
                  widget.classItem['maxStudents'] ??
                  widget.classItem['studentLimit'] ??
                  50)
              .toString(),
        ) ??
        50;
    final studentCountText = '${_students.length}/$maxStudents sinh viên';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherHomeScreen(profile: widget.profile),
              ),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherScheduleScreen(profile: widget.profile),
              ),
              (route) => false,
            );
          } else if (index == 2) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherClassesScreen(profile: widget.profile),
              ),
              (route) => false,
            );
          } else if (index == 3) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherSettingsScreen(profile: widget.profile),
              ),
              (route) => false,
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Setting',
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chi tiết lớp học',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9E7FA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            classCode.isEmpty ? 'L' : classCode.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
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
                                'Phòng học • $room',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sĩ số • $studentCountText',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
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
                                        color: _primary,
                                        fontWeight: FontWeight.w800,
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
                ),
                const SizedBox(height: 20),
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
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                      _buildStudentList(_students),
                      _buildAssignmentTab(),
                      _buildMaterialTab(),
                      _buildGradeTab(),
                      _TeacherClassChatTab(
                        classId: widget.classItem['id'].toString(),
                        profile: widget.profile,
                        chatRepo: _chatRepo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Không có dữ liệu.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final user = Map<String, dynamic>.from((item['user'] ?? {}) as Map);
        final fullName = (user['fullName'] ?? 'Chưa rõ tên').toString();
        final avatarUrl = (user['avatarUrl'] ?? '').toString();
        final studentCode =
            (user['studentInfo']?['studentCode'] ?? user['uid'] ?? '')
                .toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE9E7FA),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: _primary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $studentCode',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                      ),
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

  Widget _buildMaterialTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đang có ${_materials.length} tài liệu',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475467),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateMaterialSheet,
                icon: const Icon(Icons.add),
                label: const Text('Thêm tài liệu'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _materials.isEmpty
              ? const Center(child: Text('Chưa có tài liệu'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    final item = _materials[index];
                    final url = (item['url'] ?? '').toString();

                    final materialFile = <String, dynamic>{
                      'url': url,
                      'downloadUrl': item['downloadUrl'],
                      'originalName':
                          item['originalName'] ?? item['title'] ?? 'Tai_lieu',
                      'resourceType':
                          item['resourceType'] ?? item['type'] ?? '',
                      'format': item['format'] ?? '',
                    };

                    final detectedType = _detectMaterialTypeFromUrl(url);
                    final materialColor = _colorForMaterialType(detectedType);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _iconForMaterialType(detectedType),
                                  color: materialColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (item['title'] ?? 'Tài liệu').toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showEditMaterialDialog(item);
                                    } else if (value == 'delete') {
                                      await _deleteMaterial(
                                        item['id'].toString(),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Sửa'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Xóa'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loại file: $detectedType',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),
                            _buildFileTile(
                              file: materialFile,
                              label: 'Tài liệu lớp học',
                              color: materialColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _detectMaterialTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return 'image';
    }

    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'doc';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'sheet';
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return 'slide';
    if (lower.endsWith('.txt')) return 'text';
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return 'archive';
    }

    return 'file';
  }

  Widget _buildSheetTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 18, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 18, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildSheetButton({
    required String text,
    required VoidCallback? onPressed,
    required bool filled,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: filled ? 3 : 0,
            backgroundColor: filled ? const Color(0xFFF97316) : Colors.white,
            foregroundColor: filled ? Colors.white : const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: filled
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFD9E2EC), width: 1.5),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String title, VoidCallback onClose) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Text(
                'close',
                style: TextStyle(fontSize: 18, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showCreateMaterialSheet() async {
    final titleController = TextEditingController();

    File? selectedFile;
    String? selectedFileName;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.78,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: _buildSheetHeader(
                            'Thêm tài liệu',
                            () => Navigator.pop(context),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tiêu đề',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildSheetTextField(
                                  controller: titleController,
                                  hintText: 'Nhập tiêu đề tài liệu',
                                ),
                                const SizedBox(height: 30),
                                const Text(
                                  'Tệp đính kèm',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () async {
                                          final result =
                                              await FilePicker.pickFiles(
                                                allowMultiple: false,
                                                type: FileType.any,
                                              );

                                          if (result != null &&
                                              result.files.single.path !=
                                                  null) {
                                            setLocalState(() {
                                              selectedFile = File(
                                                result.files.single.path!,
                                              );
                                              selectedFileName =
                                                  result.files.single.name;
                                            });
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 28,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFD3DCE6),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 84,
                                          height: 84,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFBE9E1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.upload_outlined,
                                            color: Color(0xFFF97316),
                                            size: 38,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          selectedFileName ??
                                              'Chọn file từ thiết bị',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'PDF, DOCX, hoặc JPG (Tối đa 25MB)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildSheetButton(
                                text: 'Hủy',
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                filled: false,
                                flex: 3,
                              ),
                              const SizedBox(width: 16),
                              _buildSheetButton(
                                text: isSaving ? 'Đang lưu...' : 'Lưu tài liệu',
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        try {
                                          if (titleController.text
                                              .trim()
                                              .isEmpty) {
                                            throw Exception(
                                              'Vui lòng nhập tiêu đề',
                                            );
                                          }

                                          if (selectedFile == null ||
                                              selectedFileName == null) {
                                            throw Exception(
                                              'Vui lòng chọn file',
                                            );
                                          }

                                          setLocalState(() {
                                            isSaving = true;
                                          });

                                          final uploaded = await _repo
                                              .uploadFileDetailed(
                                                selectedFile!,
                                              );

                                          final url = (uploaded['url'] ?? '')
                                              .toString();
                                          final publicId =
                                              (uploaded['publicId'] ?? '')
                                                  .toString();
                                          final resourceType =
                                              (uploaded['resourceType'] ??
                                                      'raw')
                                                  .toString();
                                          final originalName =
                                              (uploaded['originalName'] ??
                                                      selectedFileName!)
                                                  .toString();
                                          final format = uploaded['format']
                                              ?.toString();

                                          final type =
                                              _detectMaterialTypeFromFileName(
                                                originalName,
                                              );

                                          await _repo.createMaterial(
                                            classId: widget.classItem['id']
                                                .toString(),
                                            title: titleController.text.trim(),
                                            type: type,
                                            url: url,
                                            publicId: publicId,
                                            resourceType: resourceType,
                                            originalName: originalName,
                                            format: format,
                                          );

                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          await _loadData();

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Đã thêm tài liệu'),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Lưu tài liệu thất bại: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setLocalState(() {
                                              isSaving = false;
                                            });
                                          }
                                        }
                                      },
                                filled: true,
                                flex: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateAssignmentSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    List<File> selectedFiles = [];
    List<String> selectedFileNames = [];
    DateTime? deadline;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.9,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: _buildSheetHeader(
                            'Tạo bài tập',
                            () => Navigator.pop(context),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tiêu đề',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildSheetTextField(
                                  controller: titleController,
                                  hintText: 'Nhập tiêu đề bài tập',
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'Mô tả',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildSheetTextField(
                                  controller: contentController,
                                  hintText: 'Nhập mô tả chi tiết bài tập...',
                                  maxLines: 6,
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'Đính kèm',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () async {
                                          final result =
                                              await FilePicker.pickFiles(
                                                allowMultiple: false,
                                                type: FileType.any,
                                              );

                                          if (result != null) {
                                            setLocalState(() {
                                              selectedFiles = result.files
                                                  .where((f) => f.path != null)
                                                  .map((f) => File(f.path!))
                                                  .toList();

                                              selectedFileNames = result.files
                                                  .where((f) => f.path != null)
                                                  .map((f) => f.name)
                                                  .toList();
                                            });
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFD3DCE6),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.attach_file,
                                          size: 30,
                                          color: Color(0xFF334155),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            selectedFileNames.isEmpty
                                                ? 'Chọn file đính kèm'
                                                : selectedFileNames.join(', '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'Hạn nộp',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () async {
                                          final picked =
                                              await _pickDeadlineDateTime(
                                                deadline,
                                              );
                                          if (picked != null) {
                                            setLocalState(() {
                                              deadline = picked;
                                            });
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFD9E2EC),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            deadline == null
                                                ? 'mm/dd/yyyy, --:-- --'
                                                : DateFormat(
                                                    'dd/MM/yyyy HH:mm',
                                                  ).format(deadline!),
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: deadline == null
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_month_outlined,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gợi ý: Chọn ngày và giờ học sinh cần hoàn thành bài.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildSheetButton(
                                text: 'Hủy',
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                filled: false,
                              ),
                              const SizedBox(width: 16),
                              _buildSheetButton(
                                text: isSaving ? 'Đang lưu...' : 'Lưu',
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        try {
                                          if (titleController.text
                                              .trim()
                                              .isEmpty) {
                                            throw Exception(
                                              'Vui lòng nhập tiêu đề',
                                            );
                                          }

                                          if (contentController.text
                                              .trim()
                                              .isEmpty) {
                                            throw Exception(
                                              'Vui lòng nhập mô tả',
                                            );
                                          }

                                          if (deadline == null) {
                                            throw Exception(
                                              'Vui lòng chọn hạn nộp',
                                            );
                                          }

                                          setLocalState(() {
                                            isSaving = true;
                                          });

                                          final attachments =
                                              <Map<String, dynamic>>[];

                                          for (final file in selectedFiles) {
                                            final uploaded = await _repo
                                                .uploadFileDetailed(file);

                                            attachments.add({
                                              'url': (uploaded['url'] ?? '')
                                                  .toString(),
                                              'publicId':
                                                  (uploaded['publicId'] ?? '')
                                                      .toString(),
                                              'resourceType':
                                                  (uploaded['resourceType'] ??
                                                          'raw')
                                                      .toString(),
                                              'originalName':
                                                  (uploaded['originalName'] ??
                                                          '')
                                                      .toString(),
                                              'format': uploaded['format']
                                                  ?.toString(),
                                            });
                                          }

                                          await _repo.createAssignment(
                                            classId: widget.classItem['id']
                                                .toString(),
                                            title: titleController.text.trim(),
                                            content: contentController.text
                                                .trim(),
                                            deadline: deadline!,
                                            attachments: attachments,
                                          );

                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          await _loadData();

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Đã tạo bài tập'),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Tạo bài tập thất bại: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setLocalState(() {
                                              isSaving = false;
                                            });
                                          }
                                        }
                                      },
                                filled: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignmentTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Có ${_assignments.length} bài tập • ${_totalSubmissions()} lượt nộp',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475467),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateAssignmentSheet,
                icon: const Icon(Icons.add),
                label: const Text('Tạo bài tập'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _assignments.isEmpty
              ? const Center(child: Text('Chưa có bài tập'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final item = _assignments[index];
                    final attachments = _extractAttachmentMaps(
                      item['attachments'],
                    );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDEBFF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    (item['title'] ?? 'Bài tập').toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showEditAssignmentDialog(item);
                                    } else if (value == 'delete') {
                                      await _deleteAssignment(
                                        item['id'].toString(),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Sửa'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Xóa'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text((item['content'] ?? '').toString()),
                            const SizedBox(height: 8),
                            Text(
                              'Hạn nộp: ${_formatDateTime(item['deadline'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475467),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildSubmissionCountChip(item),
                            _buildTeacherFilesSection(attachments),
                            _buildStudentSubmissionsSection(item),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubmissionCountChip(Map<String, dynamic> item) {
    final submissionCount =
        int.tryParse((item['submissionCount'] ?? 0).toString()) ?? 0;

    final totalStudents = _students.length;

    final deadline = _parseDateTime(item['deadline']);
    final isExpired = deadline != null && DateTime.now().isAfter(deadline);

    final percent = totalStudents <= 0
        ? 0.0
        : (submissionCount / totalStudents).clamp(0.0, 1.0).toDouble();

    Color color;
    String statusText;
    IconData icon;

    if (totalStudents == 0) {
      color = const Color(0xFF64748B);
      statusText = 'Chưa có sinh viên';
      icon = Icons.group_off_rounded;
    } else if (submissionCount >= totalStudents) {
      color = const Color(0xFF16A34A);
      statusText = 'Đã nộp đủ';
      icon = Icons.check_circle_rounded;
    } else if (isExpired) {
      color = const Color(0xFFDC2626);
      statusText = 'Quá hạn';
      icon = Icons.warning_amber_rounded;
    } else if (submissionCount == 0) {
      color = const Color(0xFFDC2626);
      statusText = 'Chưa ai nộp';
      icon = Icons.error_outline_rounded;
    } else {
      color = const Color(0xFFF59E0B);
      statusText = 'Đang nộp';
      icon = Icons.upload_file_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã nộp: $submissionCount/$totalStudents sinh viên',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài tập'),
        content: const Text('Bạn có chắc muốn xóa bài tập này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.deleteAssignment(id);
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa bài tập')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa bài tập thất bại: $e')));
    }
  }

  Future<void> _showEditAssignmentDialog(Map<String, dynamic> item) async {
    final titleController = TextEditingController(
      text: (item['title'] ?? '').toString(),
    );
    final contentController = TextEditingController(
      text: (item['content'] ?? '').toString(),
    );

    DateTime? deadline;
    final rawDeadline = item['deadline'];

    try {
      if (rawDeadline is DateTime) {
        deadline = rawDeadline;
      } else if (rawDeadline is String) {
        deadline = DateTime.tryParse(rawDeadline)?.toLocal();
      } else if (rawDeadline is Map<String, dynamic>) {
        if (rawDeadline.containsKey('_seconds')) {
          final seconds = (rawDeadline['_seconds'] as num).toInt();
          final nanoseconds = ((rawDeadline['_nanoseconds'] ?? 0) as num)
              .toInt();

          deadline = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        } else if (rawDeadline.containsKey('seconds')) {
          final seconds = (rawDeadline['seconds'] as num).toInt();
          final nanoseconds = ((rawDeadline['nanoseconds'] ?? 0) as num)
              .toInt();

          deadline = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
            isUtc: true,
          ).toLocal();
        }
      }
    } catch (_) {}

    List<Map<String, dynamic>> attachments =
        ((item['attachments'] as List?) ?? []).map((e) {
          if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
          if (e is Map) return Map<String, dynamic>.from(e);
          return {'url': e.toString()};
        }).toList();

    List<File> newFiles = [];
    List<String> newFileNames = [];
    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Sửa bài tập'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deadline == null
                                ? 'Chưa chọn hạn nộp'
                                : 'Hạn nộp: ${_formatDateTime(deadline)}',
                          ),
                        ),
                        TextButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final picked = await _pickDeadlineDateTime(
                                    deadline,
                                  );
                                  if (picked != null) {
                                    setLocalState(() {
                                      deadline = picked;
                                    });
                                  }
                                },
                          child: const Text('Chọn ngày giờ'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tệp hiện có (${attachments.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...attachments.map(
                      (file) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (file['originalName'] ?? file['url'] ?? '')
                              .toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setLocalState(() {
                              attachments.remove(file);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.pickFiles(
                                allowMultiple: false,
                                type: FileType.any,
                              );

                              if (result != null) {
                                setLocalState(() {
                                  newFiles = result.files
                                      .where((f) => f.path != null)
                                      .map((f) => File(f.path!))
                                      .toList();

                                  newFileNames = result.files
                                      .where((f) => f.path != null)
                                      .map((f) => f.name)
                                      .toList();
                                });
                              }
                            },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Chọn thêm file'),
                    ),
                    if (newFileNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...newFileNames.map((name) => Text('• $name')),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          try {
                            if (titleController.text.trim().isEmpty) {
                              throw Exception('Vui lòng nhập tiêu đề');
                            }

                            if (contentController.text.trim().isEmpty) {
                              throw Exception('Vui lòng nhập mô tả');
                            }

                            if (deadline == null) {
                              throw Exception('Vui lòng chọn hạn nộp');
                            }

                            setLocalState(() {
                              isUploading = true;
                            });

                            final uploadedFiles = <Map<String, dynamic>>[];
                            for (final file in newFiles) {
                              final uploaded = await _repo.uploadFileDetailed(
                                file,
                              );

                              uploadedFiles.add({
                                'url': (uploaded['url'] ?? '').toString(),
                                'publicId': (uploaded['publicId'] ?? '')
                                    .toString(),
                                'resourceType':
                                    (uploaded['resourceType'] ?? 'raw')
                                        .toString(),
                                'originalName': (uploaded['originalName'] ?? '')
                                    .toString(),
                                'format': uploaded['format']?.toString(),
                              });
                            }

                            await _repo.updateAssignment(
                              id: item['id'].toString(),
                              classId: widget.classItem['id'].toString(),
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              deadline: deadline!,
                              attachments: [...attachments, ...uploadedFiles],
                            );

                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadData();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã cập nhật bài tập'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cập nhật bài tập lỗi: $e'),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setLocalState(() {
                                isUploading = false;
                              });
                            }
                          }
                        },
                  child: Text(isUploading ? 'Đang lưu...' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMaterial(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: const Text('Bạn có chắc muốn xóa tài liệu này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.deleteMaterial(id);
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa tài liệu')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa tài liệu thất bại: $e')));
    }
  }

  Future<void> _showEditMaterialDialog(Map<String, dynamic> item) async {
    final titleController = TextEditingController(
      text: (item['title'] ?? '').toString(),
    );

    File? selectedFile;
    String? selectedFileName;
    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Sửa tài liệu'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'File hiện tại: ${(item['originalName'] ?? item['url'] ?? '').toString()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.pickFiles(
                                allowMultiple: false,
                                type: FileType.any,
                              );

                              if (result != null &&
                                  result.files.single.path != null) {
                                setLocalState(() {
                                  selectedFile = File(
                                    result.files.single.path!,
                                  );
                                  selectedFileName = result.files.single.name;
                                });
                              }
                            },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Chọn file mới'),
                    ),
                    if (selectedFileName != null) ...[
                      const SizedBox(height: 8),
                      Text('Đã chọn: $selectedFileName'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          try {
                            if (titleController.text.trim().isEmpty) {
                              throw Exception('Vui lòng nhập tiêu đề');
                            }

                            String finalUrl = (item['url'] ?? '').toString();
                            String? publicId = item['publicId']?.toString();
                            String resourceType =
                                (item['resourceType'] ?? 'raw').toString();
                            String? originalName = item['originalName']
                                ?.toString();
                            String? format = item['format']?.toString();

                            setLocalState(() {
                              isUploading = true;
                            });

                            if (selectedFile != null) {
                              final uploaded = await _repo.uploadFileDetailed(
                                selectedFile!,
                              );

                              finalUrl = (uploaded['url'] ?? '').toString();
                              publicId = (uploaded['publicId'] ?? '')
                                  .toString();
                              resourceType = (uploaded['resourceType'] ?? 'raw')
                                  .toString();
                              originalName =
                                  (uploaded['originalName'] ??
                                          selectedFileName ??
                                          '')
                                      .toString();
                              format = uploaded['format']?.toString();
                            }

                            if (finalUrl.isEmpty) {
                              throw Exception('URL tài liệu không hợp lệ');
                            }

                            final detectedType =
                                _detectMaterialTypeFromFileName(
                                  originalName ?? finalUrl,
                                );

                            await _repo.updateMaterial(
                              id: item['id'].toString(),
                              classId: widget.classItem['id'].toString(),
                              title: titleController.text.trim(),
                              type: detectedType,
                              url: finalUrl,
                              publicId: publicId,
                              resourceType: resourceType,
                              originalName: originalName,
                              format: format,
                            );

                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadData();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã cập nhật tài liệu'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cập nhật tài liệu lỗi: $e'),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setLocalState(() {
                                isUploading = false;
                              });
                            }
                          }
                        },
                  child: Text(isUploading ? 'Đang lưu...' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScoreField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '--',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeTab() {
    if (_students.isEmpty) {
      return const Center(child: Text('Chưa có sinh viên'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final item = _students[index];
        final user = Map<String, dynamic>.from((item['user'] ?? {}) as Map);
        final studentId = (item['studentId'] ?? user['uid'] ?? '').toString();
        final fullName = (user['fullName'] ?? 'Chưa rõ tên').toString();
        final avatarUrl = (user['avatarUrl'] ?? '').toString();
        final studentCode =
            (user['studentInfo']?['studentCode'] ?? user['uid'] ?? '')
                .toString();

        final grade = _findGradeByStudent(studentId);

        final processController = TextEditingController(
          text: (grade?['scoreProcess'] ?? '').toString(),
        );
        final midController = TextEditingController(
          text: (grade?['scoreMid'] ?? '').toString(),
        );
        final finalController = TextEditingController(
          text: (grade?['scoreFinal'] ?? '').toString(),
        );

        final status = (grade?['status'] ?? 'Chưa chấm').toString();
        final totalTen = (grade?['totalTen'] ?? '--').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE9E7FA),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: _primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trạng thái: $status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: status == 'Pass'
                                ? Colors.green
                                : status == 'Fail'
                                ? Colors.red
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'ID: $studentCode',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildScoreField('CHUYÊN CẦN', processController),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScoreField('GIỮA KỲ', midController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScoreField('CUỐI KỲ', finalController)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng kết: $totalTen',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2A8A),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _repo.upsertGrade(
                          classId: widget.classItem['id'].toString(),
                          studentId: studentId,
                          scoreProcess:
                              double.tryParse(processController.text.trim()) ??
                              0,
                          scoreMid:
                              double.tryParse(midController.text.trim()) ?? 0,
                          scoreFinal:
                              double.tryParse(finalController.text.trim()) ?? 0,
                        );

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã lưu điểm cho $fullName')),
                        );
                        await _loadData();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lưu điểm thất bại: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu điểm'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _TeacherClassChatTab extends StatefulWidget {
  final String classId;
  final Map<String, dynamic> profile;
  final TeacherChatRepository chatRepo;

  const _TeacherClassChatTab({
    required this.classId,
    required this.profile,
    required this.chatRepo,
  });

  @override
  State<_TeacherClassChatTab> createState() => _TeacherClassChatTabState();
}

class _TeacherClassChatTabState extends State<_TeacherClassChatTab> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      await widget.chatRepo.sendMessage(
        classId: widget.classId,
        text: text,
        profile: widget.profile,
      );

      _messageCtrl.clear();

      await Future.delayed(const Duration(milliseconds: 100));

      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gửi tin nhắn thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  bool _isMine(Map<String, dynamic> item) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return (item['senderId'] ?? '').toString() == myUid;
  }

  bool _isTeacher(Map<String, dynamic> item) {
    return (item['senderRole'] ?? '').toString() == 'teacher';
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

    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} $hh:$mm';
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

  Future<void> _toggleLock(bool currentLocked) async {
    try {
      await widget.chatRepo.setChatLocked(
        classId: widget.classId,
        locked: !currentLocked,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật trạng thái chat thất bại: $e')),
      );
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isLocked
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLocked
                      ? const Color(0xFFFED7AA)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLocked ? Icons.lock_rounded : Icons.chat_bubble_rounded,
                    color: isLocked
                        ? const Color(0xFF9A3412)
                        : const Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLocked ? 'Chat lớp đang bị khóa.' : 'Chat lớp đang mở.',
                      style: TextStyle(
                        color: isLocked
                            ? const Color(0xFF9A3412)
                            : const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleLock(isLocked),
                    child: Text(isLocked ? 'Mở' : 'Khóa'),
                  ),
                ],
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

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(
                        _scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];

                      final mine = _isMine(item);
                      final teacher = _isTeacher(item);
                      final deleted = item['deleted'] == true;

                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: deleted
                                ? const Color(0xFFF1F5F9)
                                : mine
                                ? const Color(0xFF1B2A8A)
                                : teacher
                                ? const Color(0xFFFFF7ED)
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
                                        (item['senderName'] ?? 'Người dùng')
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
                              if (!mine && !deleted) const SizedBox(height: 4),
                              Text(
                                deleted
                                    ? 'Tin nhắn đã bị xóa'
                                    : (item['text'] ?? '').toString(),
                                style: TextStyle(
                                  color: deleted
                                      ? const Color(0xFF64748B)
                                      : mine
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                  fontStyle: deleted
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!deleted)
                                    InkWell(
                                      onTap: () => _deleteMessage(item),
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 8),
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
                child: Row(
                  children: [
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
                        onSubmitted: (_) {
                          if (!isLocked) {
                            _send();
                          }
                        },
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
              ),
            ),
          ],
        );
      },
    );
  }
}
