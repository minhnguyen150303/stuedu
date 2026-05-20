import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/sources/remote/api_client.dart';
import '../../../data/repositories/admin_academic_repository.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _primary = Color(0xFF1B2A8A);

  final TextEditingController _searchController = TextEditingController();

  late final AdminRepository _repo;
  late final AdminAcademicRepository _academicRepo;

  int _selectedFilter = 0;
  int _currentPage = 1;
  final int _limit = 10;

  List<Map<String, dynamic>> _majors = [];
  bool _loadingMajors = false;

  String? _selectedMajorId;
  int? _selectedYearNumber;

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
      setState(() {
        _loadingMajors = true;
      });

      final items = await _academicRepo.getMajors();

      if (!mounted) return;

      setState(() {
        _majors = items;
        _loadingMajors = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingMajors = false;
      });
    }
  }

  void _resetAdvancedFilters() {
    _selectedMajorId = null;
    _selectedYearNumber = null;
    _currentPage = 1;
  }

  String? get _roleFilter {
    switch (_selectedFilter) {
      case 1:
        return 'student';
      case 2:
        return 'teacher';
      default:
        return null;
    }
  }

  Widget _buildAdvancedFilters() {
    if (_selectedFilter == 0) {
      return const SizedBox.shrink();
    }

    final isStudent = _selectedFilter == 1;
    final isTeacher = _selectedFilter == 2;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isStudent
                ? 'Bộ lọc sinh viên'
                : isTeacher
                ? 'Bộ lọc giảng viên'
                : 'Bộ lọc',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedMajorId,
            isExpanded: true,
            decoration: _filterInputDecoration(
              label: 'Chuyên ngành',
              icon: Icons.account_tree_rounded,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Tất cả chuyên ngành'),
              ),
              ..._majors.map((major) {
                return DropdownMenuItem<String>(
                  value: (major['id'] ?? '').toString(),
                  child: Text((major['name'] ?? 'Chuyên ngành').toString()),
                );
              }),
            ],
            onChanged: _loadingMajors
                ? null
                : (value) {
                    setState(() {
                      _selectedMajorId = value;
                      _currentPage = 1;
                    });
                  },
          ),

          if (isStudent) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedYearNumber,
              isExpanded: true,
              decoration: _filterInputDecoration(
                label: 'Năm học',
                icon: Icons.calendar_month_rounded,
              ),
              items: const [
                DropdownMenuItem<int>(value: null, child: Text('Tất cả năm')),
                DropdownMenuItem<int>(value: 1, child: Text('Năm 1')),
                DropdownMenuItem<int>(value: 2, child: Text('Năm 2')),
                DropdownMenuItem<int>(value: 3, child: Text('Năm 3')),
                DropdownMenuItem<int>(value: 4, child: Text('Năm 4')),
                DropdownMenuItem<int>(value: 5, child: Text('Năm 5')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedYearNumber = value;
                  _currentPage = 1;
                });
              },
            ),
          ],

          if (_selectedMajorId != null || _selectedYearNumber != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedMajorId = null;
                    _selectedYearNumber = null;
                    _currentPage = 1;
                  });
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Xóa bộ lọc'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9DFEA)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Không tải được danh sách người dùng\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final items = (data['items'] as List? ?? [])
              .map((e) => _UserItem.fromMap(Map<String, dynamic>.from(e)))
              .toList();

          final total = (data['total'] as num?)?.toInt() ?? 0;
          final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
          final page = (data['page'] as num?)?.toInt() ?? 1;

          if (items.isEmpty) {
            return const SizedBox(
              height: 260,
              child: Center(
                child: Text(
                  'Không có người dùng nào',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D7B92),
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE3E8F1))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'NGƯỜI DÙNG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF66758E),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'VAI TRÒ\nHIỆN TẠI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF66758E),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE9EDF4),
                ),
                itemBuilder: (context, index) {
                  final user = items[index];

                  return _UserRow(
                    user: user,
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminUserDetailScreen(uid: user.uid),
                        ),
                      );

                      if (changed == true) {
                        setState(() {});
                      }
                    },
                  );
                },
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE3E8F1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hiển thị ${items.isEmpty ? 0 : ((page - 1) * _limit + 1)} - ${((page - 1) * _limit) + items.length} / $total người dùng',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6D7B92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _PageArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: page > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _PageNumber(label: '$page', selected: true, onTap: () {}),
                    const SizedBox(width: 8),
                    _PageArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: page < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _filterInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  Future<Map<String, dynamic>> _loadUsers() {
    final role = _roleFilter;

    final canFilterMajor = role == 'student' || role == 'teacher';
    final canFilterYear = role == 'student';

    return _repo.getUsers(
      q: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      role: role,
      majorId: canFilterMajor ? _selectedMajorId : null,
      yearNumber: canFilterYear ? _selectedYearNumber : null,
      page: _currentPage,
      limit: _limit,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onAddUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng thêm người dùng sẽ làm sau.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Quản lý người dùng',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0D1633),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _onAddUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text(
                            'Thêm người dùng',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() => _currentPage = 1),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 30,
                            color: Color(0xFF93A1B7),
                          ),
                          hintText: 'Tìm theo tên, email hoặc mã người dùng...',
                          hintStyle: TextStyle(
                            color: Color(0xFF6D7B92),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Tất cả',
                            selected: _selectedFilter == 0,
                            onTap: () => setState(() {
                              _selectedFilter = 0;
                              _resetAdvancedFilters();
                            }),
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Sinh viên',
                            selected: _selectedFilter == 1,
                            onTap: () => setState(() {
                              _selectedFilter = 1;
                              _selectedMajorId = null;
                              _selectedYearNumber = null;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Giảng viên',
                            selected: _selectedFilter == 2,
                            onTap: () => setState(() {
                              _selectedFilter = 2;
                              _selectedMajorId = null;
                              _selectedYearNumber = null;
                              _currentPage = 1;
                            }),
                          ),
                        ],
                      ),
                    ),
                    _buildAdvancedFilters(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildUsersPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF41536F),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final _UserItem user;
  final VoidCallback onTap;

  const _UserRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _UserAvatar(user: user),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1633),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6C7A92),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                user.roleText,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF41536F),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final _UserItem user;

  const _UserAvatar({required this.user});

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    if ((user.avatarImage ?? '').isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(user.avatarImage!),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFF0F1F8),
      child: Text(
        user.avatarText ?? user.initials,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PageArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9DFEA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: onTap == null
              ? const Color(0xFFB7C0CF)
              : const Color(0xFF5A6880),
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PageNumber({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFF1B2A8A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF41536F),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserItem {
  final String uid;
  final String name;
  final String email;
  final String roleText;
  final String? avatarText;
  final String? avatarImage;
  final bool isPending;

  const _UserItem({
    required this.uid,
    required this.name,
    required this.email,
    required this.roleText,
    this.avatarText,
    this.avatarImage,
    this.isPending = false,
  });

  static String _roleLabel(String role) {
    switch (role) {
      case 'student':
        return 'Sinh viên';
      case 'teacher':
        return 'Giảng viên';
      case 'admin':
        return 'Quản trị';
      default:
        return 'Không rõ';
    }
  }

  factory _UserItem.fromMap(Map<String, dynamic> map) {
    final role = (map['role'] ?? '').toString();
    final avatarUrl = (map['avatarUrl'] ?? '').toString();

    return _UserItem(
      uid: (map['uid'] ?? '').toString(),
      name: (map['fullName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      roleText: _roleLabel(role),
      avatarImage: avatarUrl.isEmpty ? null : avatarUrl,
      avatarText: null,
      isPending: false,
    );
  }

  String get initials {
    final safeName = name.trim();
    if (safeName.isEmpty) return '?';

    final parts = safeName.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}
