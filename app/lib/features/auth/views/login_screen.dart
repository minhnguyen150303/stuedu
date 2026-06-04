import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../view_models/auth_view_model.dart';
import '../../student/views/student_home_screen.dart';
import '../../admin/views/admin_home_screen.dart';
import '../../qlsv/views/qlsv_home_screen.dart';
import '../../teacher/views/teacher_home_screen.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import '../../../core/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  final AuthViewModel viewModel;

  const LoginScreen({super.key, required this.viewModel});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _primary = Color(0xFF1B2A8A);
  static const _darkText = Color(0xFF0F172A);
  static const _mutedText = Color(0xFF64748B);
  static const _bg = Color(0xFFF6F8FC);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _remember = false;
  bool _obscure = true;
  bool _loading = false;

  AuthViewModel get viewModel => widget.viewModel;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String> _saveTokenToFile(String token) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/firebase_id_token.txt');
    await file.writeAsString(token);
    return file.path;
  }

  String _prettyError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404) return "Tài khoản chưa được cấp quyền trong hệ thống.";
      if (code == 401) return "Phiên đăng nhập không hợp lệ. Thử lại nhé.";
      final beMsg = e.response?.data is Map
          ? (e.response?.data['error']?.toString())
          : null;
      return beMsg ?? "Lỗi mạng / máy chủ. Thử lại nhé.";
    }

    if (e.toString().contains('wrong-password')) return "Mật khẩu không đúng.";
    if (e.toString().contains('user-not-found')) {
      return "Không tìm thấy tài khoản.";
    }
    if (e.toString().contains('invalid-email')) return "Email không hợp lệ.";

    return "Đăng nhập thất bại: $e";
  }

  Future<void> _goHome(Map<String, dynamic> profile) async {
    final role = (profile['role'] ?? 'student') as String;

    final fcmToken = await PushNotificationService.getToken();

    if (fcmToken != null) {
      final repo = AdminRepository(ApiClient(AppConfig.baseUrl));
      await repo.saveFcmToken(fcmToken);
    }

    if (!mounted) return;

    Widget page;

    if (role == 'student') {
      page = StudentHomeScreen(profile: profile);
    } else if (role == 'admin') {
      page = AdminHomeScreen(profile: profile);
    } else if (role == 'teacher') {
      page = TeacherHomeScreen(profile: profile);
    } else if (role == 'qlsv') {
      page = QlsvHomeScreen(profile: profile);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Role chưa hỗ trợ')));
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  Future<void> _loginGoogle() async {
    setState(() => _loading = true);
    try {
      final profile = await viewModel.loginGoogle();

      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) {
        throw Exception('Không lấy được Firebase ID token');
      }

      print('TOKEN_LENGTH=${token.length}');
      print('FIREBASE_ID_TOKEN=$token');

      final savedPath = await _saveTokenToFile(token);
      print('TOKEN_SAVED=$savedPath');

      await _goHome(profile);
    } catch (e) {
      _show(_prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final profile = await viewModel.loginEmailPassword(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
      await _goHome(profile);
    } catch (e) {
      _show(_prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _mutedText),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _darkText,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEFF3FF), Color(0xFFF6F8FC)],
                    ),
                  ),
                ),
                Expanded(child: Container(color: _bg)),
              ],
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: _darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2946D3),
                                    Color(0xFF1B2A8A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.22),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "LOGIN",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Đăng nhập để tiếp tục sử dụng StuEdu",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.45,
                                color: _mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginGoogle,
                                icon: const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 30,
                                ),
                                label: const Text(
                                  "Sign in with Google",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _darkText,
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: const [
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    "OR",
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label("Email Address"),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !_loading,
                                    decoration: _inputDecoration(
                                      hintText: "name@example.com",
                                      icon: Icons.mail_outline_rounded,
                                    ),
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return "Nhập email";
                                      if (!s.contains('@')) {
                                        return "Email không hợp lệ";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _label("Password"),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: TextButton(
                                          onPressed: _loading
                                              ? null
                                              : () {
                                                  _show(
                                                    "Chưa làm chức năng quên mật khẩu (có thể dùng Firebase reset email).",
                                                  );
                                                },
                                          style: TextButton.styleFrom(
                                            foregroundColor: _primary,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 32),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            "Forgot password?",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    enabled: !_loading,
                                    decoration: _inputDecoration(
                                      hintText: "Enter your password",
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        onPressed: _loading
                                            ? null
                                            : () {
                                                setState(
                                                  () => _obscure = !_obscure,
                                                );
                                              },
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: _mutedText,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if ((v ?? '').isEmpty) {
                                        return "Nhập mật khẩu";
                                      }
                                      if ((v ?? '').length < 6) {
                                        return "Mật khẩu tối thiểu 6 ký tự";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 34,
                                        height: 34,
                                        child: Checkbox(
                                          value: _remember,
                                          activeColor: _primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          onChanged: _loading
                                              ? null
                                              : (v) {
                                                  setState(
                                                    () =>
                                                        _remember = v ?? false,
                                                  );
                                                },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Remember me",
                                        style: TextStyle(
                                          color: _darkText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _loginEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        disabledBackgroundColor: _primary
                                            .withOpacity(0.55),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "Sign In",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "© 2026 StuEdu Learning Systems. All rights reserved.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
