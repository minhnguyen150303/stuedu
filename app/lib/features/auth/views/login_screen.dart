import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../view_models/auth_view_model.dart';
import '../../student/views/student_home_screen.dart';
import '../../admin/views/admin_home_screen.dart';
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
    // BE trả 404 khi không có user profile
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404) return "Tài khoản chưa được cấp quyền trong hệ thống.";
      if (code == 401) return "Phiên đăng nhập không hợp lệ. Thử lại nhé.";
      final beMsg = e.response?.data is Map
          ? (e.response?.data['error']?.toString())
          : null;
      return beMsg ?? "Lỗi mạng / máy chủ. Thử lại nhé.";
    }

    // Firebase auth lỗi email/password
    if (e.toString().contains('wrong-password')) return "Mật khẩu không đúng.";
    if (e.toString().contains('user-not-found'))
      return "Không tìm thấy tài khoản.";
    if (e.toString().contains('invalid-email')) return "Email không hợp lệ.";

    return "Đăng nhập thất bại: $e";
  }

  Future<void> _goHome(Map<String, dynamic> profile) async {
    final role = (profile['role'] ?? 'student') as String;

    // ✅ LẤY FCM TOKEN
    final fcmToken = await PushNotificationService.getToken();

    // ✅ GỬI LÊN BE
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
      // TODO: nếu bạn muốn "remember me" thì lưu flag vào SharedPreferences ở đây
      await _goHome(profile);
    } catch (e) {
      _show(_prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Login"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9ECF6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 34,
                        color: Color(0xFF1B2A8A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "LMS Connect",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Empowering your learning journey",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),

                    // Google button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _loginGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 26),
                        label: const Text("Sign in with Google"),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "OR",
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Email Address",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: "name@example.com",
                              prefixIcon: const Icon(Icons.mail_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return "Nhập email";
                              if (!s.contains('@')) return "Email không hợp lệ";
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Password",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        _show(
                                          "Chưa làm chức năng quên mật khẩu (có thể dùng Firebase reset email).",
                                        );
                                      },
                                child: const Text("Forgot password?"),
                              ),
                            ],
                          ),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) return "Nhập mật khẩu";
                              if ((v ?? '').length < 6)
                                return "Mật khẩu tối thiểu 6 ký tự";
                              return null;
                            },
                          ),

                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: _remember,
                                onChanged: _loading
                                    ? null
                                    : (v) => setState(
                                        () => _remember = v ?? false,
                                      ),
                              ),
                              const Text("Remember me"),
                            ],
                          ),

                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _loginEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B2A8A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      _show(
                                        "Chưa làm Sign up (admin sẽ tạo user/profile trước).",
                                      );
                                    },
                              child: const Text(
                                "Don't have an account? Sign up for free",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
