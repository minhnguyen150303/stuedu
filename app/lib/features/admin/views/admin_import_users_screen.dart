import 'dart:io';

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';

class AdminImportUsersScreen extends StatefulWidget {
  const AdminImportUsersScreen({super.key});

  @override
  State<AdminImportUsersScreen> createState() => _AdminImportUsersScreenState();
}

class _AdminImportUsersScreenState extends State<AdminImportUsersScreen> {
  static const _primary = Color(0xFF1B2A8A);

  late final AdminRepository _repo;

  bool _loading = false;
  bool _importing = false;

  String? _fileName;
  List<ImportUserRow> _rows = [];
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _repo = AdminRepository(ApiClient(AppConfig.baseUrl));
  }

  String _cellToString(ex.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  int? _parseYear(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _pickExcelFile() async {
    setState(() {
      _loading = true;
      _result = null;
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

      final parsedRows = <ImportUserRow>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        String get(int index) {
          if (index >= row.length) return '';
          return _cellToString(row[index]);
        }

        final fullName = get(0);
        final email = get(1).toLowerCase();
        final role = get(2).toLowerCase();
        final loginProvider = get(3).toLowerCase().isEmpty
            ? 'google'
            : get(3).toLowerCase();
        final password = get(4);
        final phoneNumber = get(5);
        final address = get(6);
        final majorId = get(7);
        final department = get(8);
        final studentCode = get(9);
        final year = _parseYear(get(10));
        final className = get(11);

        if (fullName.isEmpty && email.isEmpty) {
          continue;
        }

        final errors = <String>[];

        if (fullName.isEmpty) errors.add('Thiếu họ tên');
        if (email.isEmpty || !email.contains('@'))
          errors.add('Email không hợp lệ');

        if (!['student', 'teacher', 'admin'].contains(role)) {
          errors.add('Role phải là student/teacher/admin');
        }

        if (!['google', 'password'].contains(loginProvider)) {
          errors.add('loginProvider phải là google/password');
        }

        if (loginProvider == 'password' && password.length < 6) {
          errors.add('Password tối thiểu 6 ký tự');
        }

        if ((role == 'student' || role == 'teacher') && majorId.isEmpty) {
          errors.add('Thiếu majorId');
        }

        if (role == 'student') {
          if (studentCode.isEmpty) errors.add('Thiếu mã sinh viên');
          if (year == null) errors.add('Thiếu năm học');
          if (className.isEmpty) errors.add('Thiếu lớp hành chính');
        }

        parsedRows.add(
          ImportUserRow(
            rowNumber: i + 1,
            fullName: fullName,
            email: email,
            role: role,
            loginProvider: loginProvider,
            password: password,
            phoneNumber: phoneNumber,
            address: address,
            majorId: majorId,
            department: department,
            studentCode: studentCode,
            year: year,
            className: className,
            errors: errors,
          ),
        );
      }

      final checkResult = await _repo.checkImportUsers(
        users: parsedRows.map((e) => e.toPayload()).toList(),
      );

      final checkMap = {
        for (final item in checkResult)
          (item['email'] ?? '').toString().toLowerCase(): item,
      };

      final checkedRows = parsedRows.map((row) {
        final item = checkMap[row.email.toLowerCase()];
        final serverErrors = item == null
            ? <String>[]
            : List<String>.from(item['errors'] ?? []);

        return row.copyWith(errors: [...row.errors, ...serverErrors]);
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

  List<Map<String, dynamic>> _validUsersPayload() {
    return _rows.where((r) => r.isValid).map((r) => r.toPayload()).toList();
  }

  Future<void> _importUsers() async {
    final validUsers = _validUsersPayload();

    if (validUsers.isEmpty) {
      _show('Không có dòng hợp lệ để import');
      return;
    }

    setState(() {
      _importing = true;
      _result = null;
    });

    try {
      final result = await _repo.importUsers(users: validUsers);

      if (!mounted) return;

      setState(() {
        _result = result;
        _importing = false;
      });

      _show('Import hoàn tất');
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
          'Import người dùng từ Excel',
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
                          'fullName | email | role | loginProvider | password | phoneNumber | address | majorId | department | studentCode | year | className',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
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
                        final row = _rows[index];
                        return _ImportRowCard(row: row);
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
                        : _importUsers,
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
                        : const Icon(Icons.group_add_rounded),
                    label: Text(
                      _importing
                          ? 'Đang import...'
                          : 'Import $validCount người dùng hợp lệ',
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

class ImportUserRow {
  final int rowNumber;
  final String fullName;
  final String email;
  final String role;
  final String loginProvider;
  final String password;
  final String phoneNumber;
  final String address;
  final String majorId;
  final String department;
  final String studentCode;
  final int? year;
  final String className;
  final List<String> errors;

  const ImportUserRow({
    required this.rowNumber,
    required this.fullName,
    required this.email,
    required this.role,
    required this.loginProvider,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.majorId,
    required this.department,
    required this.studentCode,
    required this.year,
    required this.className,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;

  ImportUserRow copyWith({List<String>? errors}) {
    return ImportUserRow(
      rowNumber: rowNumber,
      fullName: fullName,
      email: email,
      role: role,
      loginProvider: loginProvider,
      password: password,
      phoneNumber: phoneNumber,
      address: address,
      majorId: majorId,
      department: department,
      studentCode: studentCode,
      year: year,
      className: className,
      errors: errors ?? this.errors,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'fullName': fullName,
      'email': email,
      'role': role,
      'loginProvider': loginProvider,
      if (password.isNotEmpty) 'password': password,
      'phoneNumber': phoneNumber,
      'address': address,
      'majorId': majorId,
      'department': department,
      if (role == 'student')
        'studentInfo': {
          'studentCode': studentCode,
          'year': year,
          'className': className,
          'majorId': majorId,
        },
      if (role == 'teacher') 'teacherInfo': {'majorId': majorId},
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
  final ImportUserRow row;

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
            'Dòng ${row.rowNumber}: ${row.fullName}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${row.email} • ${row.role} • ${row.loginProvider}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
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
    final created = result['created'] ?? 0;
    final pending = result['pending'] ?? 0;
    final failed = result['failed'] ?? 0;
    final duplicate = result['duplicate'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        'Kết quả: tạo trực tiếp $created, chờ Google $pending, trùng email $duplicate, lỗi $failed',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
