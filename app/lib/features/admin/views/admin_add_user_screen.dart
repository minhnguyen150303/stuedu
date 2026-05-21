import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/admin_academic_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'admin_import_users_screen.dart';

class AdminAddUserScreen extends StatefulWidget {
  const AdminAddUserScreen({super.key});

  @override
  State<AdminAddUserScreen> createState() => _AdminAddUserScreenState();
}

class _AdminAddUserScreenState extends State<AdminAddUserScreen> {
  static const _primary = Color(0xFF1B2A8A);

  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _studentCodeCtrl = TextEditingController();
  final _classNameCtrl = TextEditingController();

  late final AdminRepository _repo;
  late final AdminAcademicRepository _academicRepo;

  bool _loading = false;
  bool _loadingMajors = false;

  String _role = 'student';
  String _loginProvider = 'google';
  String? _majorId;
  String? _department;
  int? _studentYear;
  String? _emailError;

  List<Map<String, dynamic>> _majors = [];

  @override
  void initState() {
    super.initState();

    final api = ApiClient(AppConfig.baseUrl);
    _repo = AdminRepository(api);
    _academicRepo = AdminAcademicRepository(ApiClient(AppConfig.baseUrl));

    _loadMajors();
  }

  Future<void> _loadMajors() async {
    try {
      setState(() => _loadingMajors = true);
      final data = await _academicRepo.getMajors();

      if (!mounted) return;
      setState(() {
        _majors = data;
        _loadingMajors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMajors = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _studentCodeCtrl.dispose();
    _classNameCtrl.dispose();
    super.dispose();
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_role == 'student' || _role == 'teacher') &&
        (_majorId == null || _majorId!.isEmpty)) {
      _show('Vui lòng chọn chuyên ngành');
      return;
    }

    if (_role == 'student' && _studentYear == null) {
      _show('Vui lòng chọn năm học của sinh viên');
      return;
    }

    setState(() => _loading = true);

    try {
      Map<String, dynamic>? studentInfo;
      Map<String, dynamic>? teacherInfo;

      if (_role == 'student') {
        studentInfo = {
          'studentCode': _studentCodeCtrl.text.trim(),
          'className': _classNameCtrl.text.trim(),
          'year': _studentYear,
          'majorId': _majorId,
        };
      }

      if (_role == 'teacher') {
        teacherInfo = {'majorId': _majorId};
      }

      final result = await _repo.createUser(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: _role,
        loginProvider: _loginProvider,
        password: _loginProvider == 'password'
            ? _passwordCtrl.text.trim()
            : null,
        phoneNumber: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        department: _department,
        majorId: _majorId,
        studentInfo: studentInfo,
        teacherInfo: teacherInfo,
      );

      if (!mounted) return;

      final pending = result['pending'] == true;

      _show(
        pending
            ? 'Đã cấp quyền. User sẽ được tạo hồ sơ khi đăng nhập Google lần đầu.'
            : 'Đã tạo tài khoản thành công.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().toLowerCase();

      setState(() {
        if (msg.contains('email') &&
            (msg.contains('already') ||
                msg.contains('exists') ||
                msg.contains('pending') ||
                msg.contains('tồn tại') ||
                msg.contains('trùng'))) {
          _emailError = 'Gmail đã tồn tại trong hệ thống!';
        }
      });

      if (_emailError == null) {
        _show('Lỗi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == 'student';
    final isTeacher = _role == 'teacher';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        title: const Text(
          'Thêm người dùng',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
        actions: [
          IconButton(
            tooltip: 'Import Excel',
            onPressed: _loading
                ? null
                : () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminImportUsersScreen(),
                      ),
                    );

                    if (changed == true && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Thông tin đăng nhập'),

                      TextFormField(
                        controller: _fullNameCtrl,
                        decoration: _inputDecoration(
                          'Họ tên',
                          Icons.person_rounded,
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Nhập họ tên';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() {
                              _emailError = null;
                            });
                          }
                        },
                        decoration: _inputDecoration(
                          'Email / Gmail',
                          Icons.email_rounded,
                        ).copyWith(errorText: _emailError),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Nhập email';
                          if (!s.contains('@')) return 'Email không hợp lệ';
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _loginProvider,
                        decoration: _inputDecoration(
                          'Hình thức đăng nhập',
                          Icons.login_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'google',
                            child: Text('Google - cấp quyền bằng Gmail'),
                          ),
                          DropdownMenuItem(
                            value: 'password',
                            child: Text('Email / Password'),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() {
                                  _loginProvider = value ?? 'google';
                                });
                              },
                      ),

                      if (_loginProvider == 'password') ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: _inputDecoration(
                            'Mật khẩu tạm thời',
                            Icons.lock_rounded,
                          ),
                          validator: (v) {
                            if (_loginProvider != 'password') return null;
                            final s = (v ?? '').trim();
                            if (s.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 18),
                      _sectionTitle('Vai trò và hồ sơ'),

                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: _inputDecoration(
                          'Vai trò',
                          Icons.badge_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Sinh viên'),
                          ),
                          DropdownMenuItem(
                            value: 'teacher',
                            child: Text('Giảng viên'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Quản trị viên'),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() {
                                  _role = value ?? 'student';
                                  _majorId = null;
                                  _department = null;
                                  _studentYear = null;
                                });
                              },
                      ),

                      if (isStudent || isTeacher) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _majorId,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            'Chuyên ngành',
                            Icons.account_tree_rounded,
                          ),
                          items: _majors.map((major) {
                            final id = (major['id'] ?? '').toString();
                            final name = (major['name'] ?? '').toString();

                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: _loadingMajors || _loading
                              ? null
                              : (value) {
                                  final selected = _majors.firstWhere(
                                    (m) => (m['id'] ?? '').toString() == value,
                                    orElse: () => <String, dynamic>{},
                                  );

                                  setState(() {
                                    _majorId = value;
                                    _department = (selected['name'] ?? '')
                                        .toString();
                                  });
                                },
                          validator: (_) {
                            if ((isStudent || isTeacher) &&
                                (_majorId == null || _majorId!.isEmpty)) {
                              return 'Chọn chuyên ngành';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(
                          'Số điện thoại',
                          Icons.phone_rounded,
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _addressCtrl,
                        decoration: _inputDecoration(
                          'Địa chỉ',
                          Icons.location_on_rounded,
                        ),
                      ),

                      if (isStudent) ...[
                        const SizedBox(height: 18),
                        _sectionTitle('Thông tin sinh viên'),

                        TextFormField(
                          controller: _studentCodeCtrl,
                          decoration: _inputDecoration(
                            'Mã sinh viên',
                            Icons.confirmation_number_rounded,
                          ),
                          validator: (v) {
                            if (!isStudent) return null;
                            if ((v ?? '').trim().isEmpty) {
                              return 'Nhập mã sinh viên';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        DropdownButtonFormField<int>(
                          value: _studentYear,
                          decoration: _inputDecoration(
                            'Năm học',
                            Icons.calendar_month_rounded,
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Năm 1')),
                            DropdownMenuItem(value: 2, child: Text('Năm 2')),
                            DropdownMenuItem(value: 3, child: Text('Năm 3')),
                            DropdownMenuItem(value: 4, child: Text('Năm 4')),
                            DropdownMenuItem(value: 5, child: Text('Năm 5')),
                          ],
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(() => _studentYear = value);
                                },
                          validator: (_) {
                            if (isStudent && _studentYear == null) {
                              return 'Chọn năm học';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _classNameCtrl,
                          decoration: _inputDecoration(
                            'Lớp hành chính',
                            Icons.groups_rounded,
                          ),
                          validator: (v) {
                            if (!isStudent) return null;
                            if ((v ?? '').trim().isEmpty) {
                              return 'Nhập lớp hành chính';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      _loading ? 'Đang tạo...' : 'Tạo người dùng',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
