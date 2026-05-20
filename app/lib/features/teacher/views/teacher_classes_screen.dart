import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import 'teacher_schedule_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_class_detail_screen.dart';
import 'teacher_settings_screen.dart';

class TeacherClassesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const TeacherClassesScreen({super.key, required this.profile});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1B2A8A);

  late final TeacherRepository _repo;
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _teachingClasses = [];
  List<Map<String, dynamic>> _historyClasses = [];

  @override
  void initState() {
    super.initState();
    _repo = TeacherRepository(ApiClient(AppConfig.baseUrl));
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teacherId = (widget.profile['uid'] ?? '').toString();
      if (teacherId.isEmpty) {
        throw Exception('Thiếu teacherId');
      }

      final classes = await _repo.getMyClasses(teacherId: teacherId);
      final courses = await _repo.getCourses();

      final courseNameById = <String, String>{
        for (final c in courses)
          c['id'].toString(): (c['courseName'] ?? 'Chưa rõ môn').toString(),
      };

      final enriched = classes.map((cls) {
        return {
          ...cls,
          'courseName':
              courseNameById[cls['courseId'].toString()] ?? 'Chưa rõ môn',
        };
      }).toList();

      final teaching = enriched.where((c) {
        final state = (c['adminState'] ?? '').toString();
        return state == 'active';
      }).toList();

      final history = enriched.where((c) {
        final state = (c['adminState'] ?? '').toString();
        return state == 'archived';
      }).toList();

      setState(() {
        _allClasses = enriched;
        _teachingClasses = teaching;
        _historyClasses = history;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _buildSemesterLabel(Map<String, dynamic> item) {
    final term = item['termNumberSnapshot'];
    final year = item['academicYearSnapshot'];

    if (term != null && year != null && '$year'.isNotEmpty) {
      return 'HK$term • $year';
    }

    if (year != null && '$year'.isNotEmpty) {
      return year.toString();
    }

    return 'Chưa có học kỳ';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherHomeScreen(profile: widget.profile),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherScheduleScreen(profile: widget.profile),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherSettingsScreen(profile: widget.profile),
              ),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Có lỗi xảy ra:\n$_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildClassList(_teachingClasses),
                        _buildClassList(_historyClasses),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF101828),
              size: 28,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Quản lý lớp học',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF101828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        labelColor: _primary,
        unselectedLabelColor: Colors.blueGrey,
        indicatorColor: _primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Lớp đang dạy'),
          Tab(text: 'Lịch sử'),
        ],
      ),
    );
  }

  Widget _buildClassList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadClasses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Không có lớp nào trong mục này.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildClassCard(items[index], index);
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item, int index) {
    final classCode = (item['classCode'] ?? '').toString();
    final courseName = (item['courseName'] ?? 'Chưa rõ môn').toString();
    final semesterLabel = _buildSemesterLabel(item);
    final room = (item['room'] ?? '--').toString();
    final state = (item['adminState'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  classCode.isEmpty ? 'NO-CODE' : classCode,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: state == 'active'
                      ? const Color(0xFFE8F7EC)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state == 'active' ? 'Đang dạy' : 'Đã kết thúc',
                  style: TextStyle(
                    color: state == 'active'
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            courseName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Phòng học: $room',
            style: const TextStyle(fontSize: 15, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 6),
          Text(
            'Học kỳ: $semesterLabel',
            style: const TextStyle(fontSize: 15, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cập nhật gần đây',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF98A2B3),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherClassDetailScreen(
                        profile: widget.profile,
                        classItem: item,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'View Class',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
