import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'qlsv_import_final_grades_screen.dart';

class QlsvFinalGradesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const QlsvFinalGradesScreen({super.key, required this.profile});

  @override
  State<QlsvFinalGradesScreen> createState() => _QlsvFinalGradesScreenState();
}

class _QlsvFinalGradesScreenState extends State<QlsvFinalGradesScreen> {
  late final QlsvRepository _repo;

  static const MethodChannel _downloadsChannel = MethodChannel(
    'stu_edu/downloads',
  );

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _grades = [];

  Map<String, dynamic>? _selectedClass;

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _repo.getClasses();
      final courses = await _repo.getCourses();

      final courseNameById = {
        for (final c in courses)
          (c['id'] ?? '').toString(): (c['courseName'] ?? '').toString(),
      };

      final filteredClasses = classes.where((cls) {
        final state = (cls['adminState'] ?? '').toString();
        return state == 'active' || state == 'archived';
      }).toList();

      final enrichedClasses = filteredClasses.map((cls) {
        final courseId = (cls['courseId'] ?? '').toString();

        return {...cls, 'courseName': courseNameById[courseId] ?? courseId};
      }).toList();

      enrichedClasses.sort((a, b) {
        final courseA = (a['courseName'] ?? '').toString();
        final courseB = (b['courseName'] ?? '').toString();

        final courseCompare = courseA.compareTo(courseB);
        if (courseCompare != 0) return courseCompare;

        final codeA = (a['classCode'] ?? '').toString();
        final codeB = (b['classCode'] ?? '').toString();

        return _classCodeNumber(codeA).compareTo(_classCodeNumber(codeB));
      });

      if (!mounted) return;

      setState(() {
        _classes = enrichedClasses;
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

  int _classCodeNumber(String classCode) {
    final match = RegExp(r'\d+').firstMatch(classCode);
    if (match == null) return 999;
    return int.tryParse(match.group(0) ?? '') ?? 999;
  }

  Future<void> _selectClass(Map<String, dynamic> cls) async {
    setState(() {
      _selectedClass = cls;
      _loading = true;
      _students = [];
      _grades = [];
    });

    try {
      final classId = cls['id'].toString();

      final students = await _repo.getClassUsers(classId: classId);
      final grades = await _repo.getGrades(classId: classId);

      if (!mounted) return;

      setState(() {
        _students = students;
        _grades = grades;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _findGrade(String studentId) {
    try {
      return _grades.firstWhere(
        (g) => (g['studentId'] ?? '').toString() == studentId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFinalGrade({
    required String studentId,
    required double scoreFinal,
  }) async {
    final cls = _selectedClass;
    if (cls == null) return;

    try {
      await _repo.upsertFinalGrade(
        classId: cls['id'].toString(),
        studentId: studentId,
        scoreFinal: scoreFinal,
      );

      await _selectClass(cls);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu điểm cuối kỳ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lưu điểm lỗi: $e')));
    }
  }

  String _sanitizeFileName(String input) {
    final text = input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return text.isEmpty ? 'khong_ro' : text;
  }

  String _scoreText(dynamic value) {
    if (value == null) return '';

    final n = num.tryParse(value.toString());
    if (n == null) return value.toString();

    return n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _studentCodeOf(Map<String, dynamic> user) {
    final studentInfo = user['studentInfo'];

    if (studentInfo is Map) {
      return (studentInfo['studentCode'] ?? '').toString();
    }

    return '';
  }

  Future<void> _saveExcelToDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _downloadsChannel.invokeMethod<String>('saveToDownloads', {
      'fileName': fileName,
      'folderName': 'qlsv',
      'mimeType':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'bytes': bytes,
    });
  }

  Future<void> _exportFinalGradesExcel() async {
    final cls = _selectedClass;

    if (cls == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lớp trước')));
      return;
    }

    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lớp chưa có sinh viên để xuất file')),
      );
      return;
    }

    try {
      final classCode = (cls['classCode'] ?? 'lop').toString();
      final courseName = (cls['courseName'] ?? 'mon_hoc').toString();

      final safeCourseName = _sanitizeFileName(courseName);
      final safeClassCode = _sanitizeFileName(classCode);

      final fileName = 'tk_d_${safeCourseName}_$safeClassCode.xlsx';

      final excel = ex.Excel.createExcel();
      const sheetName = 'Tong ket diem';

      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      sheet.appendRow([
        ex.TextCellValue('STT'),
        ex.TextCellValue('Mã sinh viên'),
        ex.TextCellValue('Họ tên'),
        ex.TextCellValue('Điểm chuyên cần'),
        ex.TextCellValue('Điểm giữa kỳ'),
        ex.TextCellValue('Điểm cuối kỳ'),
        ex.TextCellValue('Tổng kết'),
        ex.TextCellValue('Trạng thái'),
      ]);

      for (int i = 0; i < _students.length; i++) {
        final item = _students[i];

        final user = Map<String, dynamic>.from(
          (item['user'] as Map?) ?? const {},
        );

        final studentId = (item['studentId'] ?? user['uid'] ?? '').toString();
        final fullName = (user['fullName'] ?? 'Sinh viên').toString();
        final studentCode = _studentCodeOf(user);

        final grade = _findGrade(studentId);

        sheet.appendRow([
          ex.IntCellValue(i + 1),
          ex.TextCellValue(studentCode),
          ex.TextCellValue(fullName),
          ex.TextCellValue(_scoreText(grade?['scoreProcess'])),
          ex.TextCellValue(_scoreText(grade?['scoreMid'])),
          ex.TextCellValue(_scoreText(grade?['scoreFinal'])),
          ex.TextCellValue(_scoreText(grade?['totalTen'])),
          ex.TextCellValue((grade?['status'] ?? 'Chưa đủ điểm').toString()),
        ]);
      }

      final encoded = excel.encode();

      if (encoded == null || encoded.isEmpty) {
        throw Exception('Không tạo được file Excel');
      }

      await _saveExcelToDownloads(
        bytes: Uint8List.fromList(encoded),
        fileName: fileName,
      );

      if (!mounted) return;

      _showExportSuccessDialog(fileName: fileName);
    } catch (e) {
      if (!mounted) return;

      _showExportErrorDialog(e.toString());
    }
  }

  void _showExportSuccessDialog({required String fileName}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                  width: 74,
                  height: 74,
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
                  'Xuất file thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'File điểm đã được lưu vào thư mục:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Downloads/qlsv',
                        style: TextStyle(
                          color: Color(0xFF1B2A8A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fileName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8A),
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

  void _showExportErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                  width: 74,
                  height: 74,
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
                  'Xuất file thất bại',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
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
    final selectedClass = _selectedClass;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Nhập điểm cuối kỳ',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : selectedClass == null
          ? _buildClassList()
          : _buildStudentGradeList(),
    );
  }

  Widget _buildClassList() {
    if (_classes.isEmpty) {
      return const Center(child: Text('Chưa có lớp học'));
    }

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final cls in _classes) {
      final courseId = (cls['courseId'] ?? '').toString();
      grouped.putIfAbsent(courseId, () => []);
      grouped[courseId]!.add(cls);
    }

    final courseGroups = grouped.entries.toList();

    courseGroups.sort((a, b) {
      final nameA = (a.value.first['courseName'] ?? '').toString();
      final nameB = (b.value.first['courseName'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courseGroups.length,
      itemBuilder: (context, index) {
        final group = courseGroups[index];
        final classes = group.value;

        classes.sort((a, b) {
          final codeA = (a['classCode'] ?? '').toString();
          final codeB = (b['classCode'] ?? '').toString();
          return _classCodeNumber(codeA).compareTo(_classCodeNumber(codeB));
        });

        final courseName = (classes.first['courseName'] ?? 'Môn học')
            .toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              courseName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('${classes.length} lớp'),
            children: classes.map((cls) {
              final classCode = (cls['classCode'] ?? '').toString();
              final room = (cls['room'] ?? '').toString();
              final state = (cls['adminState'] ?? '').toString();

              return ListTile(
                title: Text(
                  classCode.isEmpty ? 'Lớp chưa có mã' : classCode,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    if (room.isNotEmpty) 'Phòng: $room',
                    if (state == 'archived') 'Lịch sử',
                    if (state == 'active') 'Đang học',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _selectClass(cls),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStudentGradeList() {
    final cls = _selectedClass!;
    final title = '${cls['classCode'] ?? ''} - ${cls['courseName'] ?? ''}';

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedClass = null;
                        _students = [];
                        _grades = [];
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exportFinalGradesExcel,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('Xuất Excel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QlsvImportFinalGradesScreen(
                              classId: cls['id'].toString(),
                              className: title,
                            ),
                          ),
                        );

                        if (changed == true) {
                          await _selectClass(cls);
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Import'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? const Center(child: Text('Lớp chưa có sinh viên'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final item = _students[index];
                    final user = Map<String, dynamic>.from(
                      (item['user'] as Map?) ?? const {},
                    );

                    final studentId = (item['studentId'] ?? user['uid'] ?? '')
                        .toString();

                    final fullName = (user['fullName'] ?? 'Sinh viên')
                        .toString();

                    final studentCode =
                        (user['studentInfo']?['studentCode'] ?? '').toString();

                    final grade = _findGrade(studentId);

                    return _StudentFinalGradeCard(
                      fullName: fullName,
                      studentCode: studentCode,
                      scoreProcess: grade?['scoreProcess'],
                      scoreMid: grade?['scoreMid'],
                      scoreFinal: grade?['scoreFinal'],
                      totalTen: grade?['totalTen'],
                      status: grade?['status'],
                      onSave: (score) => _saveFinalGrade(
                        studentId: studentId,
                        scoreFinal: score,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StudentFinalGradeCard extends StatefulWidget {
  final String fullName;
  final String studentCode;
  final dynamic scoreProcess;
  final dynamic scoreMid;
  final dynamic scoreFinal;
  final dynamic totalTen;
  final dynamic status;
  final ValueChanged<double> onSave;

  const _StudentFinalGradeCard({
    required this.fullName,
    required this.studentCode,
    required this.scoreProcess,
    required this.scoreMid,
    required this.scoreFinal,
    required this.totalTen,
    required this.status,
    required this.onSave,
  });

  @override
  State<_StudentFinalGradeCard> createState() => _StudentFinalGradeCardState();
}

class _StudentFinalGradeCardState extends State<_StudentFinalGradeCard> {
  late final TextEditingController _finalCtrl;

  @override
  void initState() {
    super.initState();
    _finalCtrl = TextEditingController(
      text: widget.scoreFinal == null ? '' : widget.scoreFinal.toString(),
    );
  }

  @override
  void dispose() {
    _finalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.status ?? 'Chưa đủ điểm').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fullName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (widget.studentCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mã SV: ${widget.studentCode}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  label: 'Chuyên cần',
                  value: widget.scoreProcess == null
                      ? '--'
                      : '${widget.scoreProcess}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoBox(
                  label: 'Giữa kỳ',
                  value: widget.scoreMid == null ? '--' : '${widget.scoreMid}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoBox(
                  label: 'Tổng',
                  value: '${widget.totalTen ?? '--'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _finalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Điểm cuối kỳ',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kết quả: $status',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: status == 'Pass' ? Colors.green : Colors.red,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  final score = double.tryParse(_finalCtrl.text.trim());

                  if (score == null || score < 0 || score > 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Điểm cuối kỳ phải từ 0 đến 10'),
                      ),
                    );
                    return;
                  }

                  widget.onSave(score);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
