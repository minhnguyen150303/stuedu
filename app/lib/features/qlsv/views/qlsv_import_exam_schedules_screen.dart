import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/qlsv_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class QlsvImportExamSchedulesScreen extends StatefulWidget {
  const QlsvImportExamSchedulesScreen({super.key});

  @override
  State<QlsvImportExamSchedulesScreen> createState() =>
      _QlsvImportExamSchedulesScreenState();
}

class _QlsvImportExamSchedulesScreenState
    extends State<QlsvImportExamSchedulesScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final QlsvRepository _repo;

  bool _loading = false;
  bool _importing = false;

  String? _fileName;
  List<ImportExamRow> _rows = [];
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _repo = QlsvRepository(ApiClient(AppConfig.baseUrl));
  }

  String _cellToString(ex.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';

    // Excel date kiểu DateCellValue
    if (value is ex.DateCellValue) {
      final d = DateTime(value.year, value.month, value.day);
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    // Excel date time
    if (value is ex.DateTimeCellValue) {
      final d = DateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
      );
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    return value.toString().trim();
  }

  String _normalizeDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';

    try {
      // dd/MM/yyyy
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          if (day < 1 || day > 31 || month < 1 || month > 12) return text;

          return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
        }
      }

      // yyyy-MM-dd
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(text)) {
        final parts = text.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
      }

      // Excel serial date
      final serial = double.tryParse(text);
      if (serial != null && serial > 20000 && serial < 60000) {
        final base = DateTime(1899, 12, 30);
        final dt = base.add(Duration(days: serial.floor()));
        return DateFormat('yyyy-MM-dd').format(dt);
      }
    } catch (_) {}

    return text;
  }

  String _normalizeTime(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';

    final parts = text.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final number = double.tryParse(text);
    if (number != null && number > 0 && number < 1) {
      final totalMinutes = (number * 24 * 60).round();
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    return text;
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

      final parsedRows = <ImportExamRow>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        String get(int index) {
          if (index >= row.length) return '';
          return _cellToString(row[index]);
        }

        final courseCode = get(0);
        final examDate = _normalizeDate(get(1));
        final examTime = _normalizeTime(get(2));
        final examRoom = get(3);
        final note = get(4);

        if (courseCode.isEmpty &&
            examDate.isEmpty &&
            examTime.isEmpty &&
            examRoom.isEmpty &&
            note.isEmpty) {
          continue;
        }

        final errors = <String>[];

        if (courseCode.isEmpty) errors.add('Thiếu mã môn học');
        if (examDate.isEmpty) errors.add('Thiếu ngày thi');
        if (examTime.isEmpty) errors.add('Thiếu giờ thi');
        if (examRoom.isEmpty) errors.add('Thiếu phòng thi');

        parsedRows.add(
          ImportExamRow(
            rowNumber: i + 1,
            courseCode: courseCode,
            courseId: '',
            courseName: '',
            semesterId: '',
            examDate: examDate,
            examTime: examTime,
            examRoom: examRoom,
            note: note,
            errors: errors,
          ),
        );
      }

      final checkResult = await _repo.checkImportExamSchedules(
        rows: parsedRows.map((e) => e.toPayload()).toList(),
      );

      final serverRows = List<Map<String, dynamic>>.from(
        ((checkResult['results'] ?? []) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      final checkedRows = serverRows.map((item) {
        return ImportExamRow(
          rowNumber: int.tryParse((item['rowNumber'] ?? '').toString()) ?? 0,
          courseCode: (item['courseCode'] ?? '').toString(),
          courseId: (item['courseId'] ?? '').toString(),
          courseName: (item['courseName'] ?? '').toString(),
          semesterId: (item['semesterId'] ?? '').toString(),
          examDate: (item['examDate'] ?? '').toString(),
          examTime: (item['examTime'] ?? '').toString(),
          examRoom: (item['examRoom'] ?? '').toString(),
          note: (item['note'] ?? '').toString(),
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

  Future<void> _importExamSchedules() async {
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
      final result = await _repo.importExamSchedules(rows: validRows);

      if (!mounted) return;

      setState(() {
        _result = result;
        _importing = false;
      });

      _show('Import lịch thi hoàn tất');
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

  String _displayExamDate(String value) {
    if (value.isEmpty) return '--';

    final dt = DateTime.tryParse(value);
    if (dt == null) return value;

    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
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
          'Import lịch thi',
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
                          'courseCode | examDate | examTime | examRoom | note',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ví dụ: CT101 | 20/06/2026 | 08:00 | P301 | Thi cuối kỳ',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lưu ý: Mỗi môn trong học kỳ chỉ được có một lịch thi.',
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
                        return _ImportRowCard(
                          row: _rows[index],
                          displayDate: _displayExamDate,
                        );
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
                        : _importExamSchedules,
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

class ImportExamRow {
  final int rowNumber;
  final String courseCode;
  final String courseId;
  final String courseName;
  final String semesterId;
  final String examDate;
  final String examTime;
  final String examRoom;
  final String note;
  final List<String> errors;

  const ImportExamRow({
    required this.rowNumber,
    required this.courseCode,
    required this.courseId,
    required this.courseName,
    required this.semesterId,
    required this.examDate,
    required this.examTime,
    required this.examRoom,
    required this.note,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;

  Map<String, dynamic> toPayload() {
    return {
      'rowNumber': rowNumber,
      'courseCode': courseCode,
      'examDate': examDate,
      'examTime': examTime,
      'examRoom': examRoom,
      'note': note,
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
  final ImportExamRow row;
  final String Function(String) displayDate;

  const _ImportRowCard({required this.row, required this.displayDate});

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
            'Dòng ${row.rowNumber}: ${row.courseCode}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            row.courseName.isEmpty ? 'Chưa xác định môn học' : row.courseName,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thời gian: ${displayDate(row.examDate)} • Phòng: ${row.examRoom.isEmpty ? '--' : row.examRoom}',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (row.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú: ${row.note}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
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
        'Kết quả: tạo thành công $success, lỗi $failed, không hợp lệ $invalid',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
