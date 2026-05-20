import 'package:flutter/material.dart';

import '../../../data/sources/remote/api_client.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../auth/views/login_screen.dart';
import '../../../core/config/app_config.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _primary = Color(0xFF1B2A8A);
  static const _bg = Color(0xFFF5F7FB);
  static const _card = Colors.white;

  void _goLogin(BuildContext context) {
    final api = ApiClient(AppConfig.baseUrl);
    final repo = AuthRepository(api);
    final vm = AuthViewModel(repo);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(viewModel: vm)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TopBar(
                onHelp: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trợ giúp: chức năng chưa triển khai'),
                    ),
                  );
                },
                onLanguage: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ngôn ngữ: chức năng chưa triển khai'),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              const _IntroPanel(),

              const SizedBox(height: 22),

              const Text(
                'Quản lý học tập\nthông minh\ntrong một ứng dụng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Nền tảng hỗ trợ sinh viên, giảng viên và quản trị viên theo dõi lớp học, bài tập, tài liệu và kết quả học tập một cách rõ ràng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 22),

              _PrimaryButton(
                text: 'Đăng nhập',
                onPressed: () => _goLogin(context),
              ),

              const SizedBox(height: 24),

              const _FeatureCard(
                icon: Icons.calendar_today_rounded,
                title: 'Quản lý lớp học',
                subtitle:
                    'Theo dõi lịch học, danh sách lớp và hoạt động học tập trong từng học phần.',
              ),

              const SizedBox(height: 12),

              const _FeatureCard(
                icon: Icons.description_rounded,
                title: 'Tài liệu và bài tập',
                subtitle:
                    'Truy cập tài liệu, nhận bài tập và quản lý tiến độ nộp bài nhanh chóng.',
              ),

              const SizedBox(height: 12),

              const _FeatureCard(
                icon: Icons.show_chart_rounded,
                title: 'Thống kê học tập',
                subtitle:
                    'Theo dõi GPA, tín chỉ, điểm số và tiến độ học tập bằng các biểu đồ trực quan.',
              ),

              const SizedBox(height: 18),
              const Divider(height: 22),

              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onHelp;
  final VoidCallback onLanguage;

  const _TopBar({required this.onHelp, required this.onLanguage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: WelcomeScreen._primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Colors.black12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'StuEdu',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        TextButton(onPressed: onHelp, child: const Text('Trợ giúp')),
        IconButton(
          onPressed: onLanguage,
          icon: const Icon(Icons.language_rounded),
        ),
      ],
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2A8A), Color(0xFF3146C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black12,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Học tập rõ ràng hơn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Lớp học, điểm số, bài tập và thông báo được gom trong một hệ thống.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: WelcomeScreen._primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: WelcomeScreen._card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Colors.black12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: WelcomeScreen._primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.3,
                    fontWeight: FontWeight.w500,
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          '© 2026 StuEdu Learning Systems. All rights reserved.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
