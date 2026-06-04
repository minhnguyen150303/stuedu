import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class QlsvImportFinalGradesScreen extends StatefulWidget {
  final String classId;
  final String className;

  const QlsvImportFinalGradesScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<QlsvImportFinalGradesScreen> createState() =>
      _QlsvImportFinalGradesScreenState();
}

class _QlsvImportFinalGradesScreenState
    extends State<QlsvImportFinalGradesScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final QlsvRepository _repo;

  bool _loading = false;
  bool _importing = false;

  String? _fileName;
  List<ImportFinalGradeRow> _rows = [];
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
  }

  String _cellToString(ex.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  double? _parseScore(String value) {
    final text = value.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _pickExcelFile() async {
    setState(() {
      _loading = true;
      _result = null;
      _rows = [];
    });

    try {
      final picked = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );

      if (picked == null || picked.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }

      final path = picked.files.single.path!;
      final bytes = await File(path).readAsBytes();
      final excel = ex.Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null) {
        throw Exception('File Excel không có sheet dữ liệu');
      }

      final parsedRows = <ImportFinalGradeRow>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        String get(int index) {
          if (index >= row.length) return '';
          return _cellToString(row[index]);
        }

        final studentCode = get(0);
        final scoreFinalText = get(1);

        if (studentCode.isEmpty && scoreFinalText.isEmpty) {
          continue;
        }

        final scoreFinal = _parseScore(scoreFinalText);
        final errors = <String>[];

        if (studentCode.isEmpty) errors.add('Thiếu mã sinh viên');

        if (scoreFinal == null || scoreFinal < 0 || scoreFinal > 10) {
          errors.add('Điểm cuối kỳ phải từ 0 đến 10');
        }

        parsedRows.add(
          ImportFinalGradeRow(
            rowNumber: i + 1,
            studentCode: studentCode,
            studentId: '',
            fullName: '',
            scoreFinal: scoreFinal,
            errors: errors,
          ),
        );
      }

      final checkResult = await _repo.checkImportFinalGrades(
        classId: widget.classId,
        rows: parsedRows.map((e) => e.toPayload()).toList(),
      );

      final serverRows = List<Map<String, dynamic>>.from(
        ((checkResult['results'] ?? []) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      final checkedRows = serverRows.map((item) {
        return ImportFinalGradeRow(
          rowNumber: int.tryParse((item['rowNumber'] ?? '').toString()) ?? 0,
          studentCode: (item['studentCode'] ?? '').toString(),
          studentId: (item['studentId'] ?? '').toString(),
          fullName: (item['fullName'] ?? '').toString(),
          scoreFinal: double.tryParse((item['scoreFinal'] ?? '').toString()),
          errors: List<String>.from(item['errors'] ?? []),
        );
      }).toList();

      setState(() {
        _fileName = picked.files.single.name;
        _rows = checkedRows;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _show('Lỗi đọc Excel: $e');
    }
  }

  List<Map<String, dynamic>> _validRowsPayload() {
    return _rows.where((r) => r.isValid).map((r) => r.toPayload()).toList();
  }

  Future<void> _importGrades() async {
    final validRows = _validRowsPayload();

    if (validRows.isEmpty) {
      _show('Không có dòng hợp lệ để import');
      return;
    }

    setState(() {
      _importing = true;
      _result = null;
    });

    try {
      final result = await _repo.importFinalGrades(
        classId: widget.classId,
        rows: validRows,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _importing = false;
      });

      _show('Import điểm cuối kỳ hoàn tất');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _show('Lỗi import: $e');
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((e) => e.isValid).length;
    final invalidCount = _rows.length - validCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: _primary),
        title: const Text(
          'Import điểm cuối kỳ',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mẫu cột Excel',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'studentCode | scoreFinal',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lớp đang nhập: ${widget.className}',
                          style: const TextStyle(
                            color: _primary,
                            height: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lưu ý: Sinh viên phải có đủ điểm chuyên cần và giữa kỳ trước khi nhập điểm cuối kỳ.',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _loading || _importing
                                ? null
                                : _pickExcelFile,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(
                              _loading
                                  ? 'Đang đọc file...'
                                  : (_fileName == null
                                        ? 'Chọn file Excel'
                                        : 'Đổi file Excel: $_fileName'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Hợp lệ',
                            value: validCount.toString(),
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Có lỗi',
                            value: invalidCount.toString(),
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Tổng',
                            value: _rows.length.toString(),
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _ResultBox(result: _result!),
              ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa chọn file Excel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _ImportRowCard(row: _rows[index]);
                      },
                    ),
            ),
            if (_rows.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _importing || validCount == 0
                        ? null
                        : _importGrades,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _importing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(
                      _importing
                          ? 'Đang import...'
                          : 'Import $validCount dòng hợp lệ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ImportFinalGradeRow {
  final int rowNumber;
  final String studentCode;
  final String studentId;
  final String fullName;
  final double? scoreFinal;
  final List<String> errors;

  const ImportFinalGradeRow({
    required this.rowNumber,
    required this.studentCode,
    required this.studentId,
    required this.fullName,
    required this.scoreFinal,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;

  Map<String, dynamic> toPayload() {
    return {
      'rowNumber': rowNumber,
      'studentCode': studentCode,
      'scoreFinal': scoreFinal,
    };
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRowCard extends StatelessWidget {
  final ImportFinalGradeRow row;

  const _ImportRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final valid = row.isValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valid ? Colors.white : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: valid ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dòng ${row.rowNumber}: ${row.studentCode}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            row.fullName.isEmpty ? 'Chưa xác định sinh viên' : row.fullName,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Điểm cuối kỳ: ${row.scoreFinal ?? '--'}',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (row.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...row.errors.map(
              (e) => Text(
                '• $e',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultBox({required this.result});

  @override
  Widget build(BuildContext context) {
    final success = result['success'] ?? 0;
    final failed = result['failed'] ?? 0;
    final invalid = result['invalid'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        'Kết quả: lưu thành công $success, lỗi $failed, không hợp lệ $invalid',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
