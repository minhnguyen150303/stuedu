import 'package:firebase_auth/firebase_auth.dart';
import '../sources/remote/api_client.dart';

class AdminRepository {
  final ApiClient api;

  AdminRepository(this.api);

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null) {
      throw Exception('Chưa đăng nhập');
    }

    api.setToken(token);
  }

  Future<Map<String, dynamic>> getUserStats() async {
    await _attachToken();
    final data = await api.get('/admin/user-stats');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getUsers({
    String? q,
    String? role,
    String? majorId,
    int? yearNumber,
    int page = 1,
    int limit = 10,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/admin/users',
      queryParameters: {
        'q': q,
        'role': role,
        'majorId': majorId,
        'yearNumber': yearNumber,
        'page': page,
        'limit': limit,
      }..removeWhere((key, value) => value == null || value == ''),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getUserDetail(String uid) async {
    await _attachToken();
    final data = await api.get('/admin/users/$uid');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateUser({
    required String uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    String? department,
    String? majorId,
    String? avatarUrl,
    String? role,
    Map<String, dynamic>? studentInfo,
    Map<String, dynamic>? teacherInfo,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/admin/users/$uid',
      data: {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': address,
        'department': department,
        'majorId': majorId,
        'avatarUrl': avatarUrl,
        'role': role,
        'studentInfo': studentInfo,
        'teacherInfo': teacherInfo,
      }..removeWhere((key, value) => value == null),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> lockUser({
    required String uid,
    required bool disabled,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/admin/users/$uid/lock',
      data: {'disabled': disabled},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> deleteUser(String uid) async {
    await _attachToken();
    final data = await api.delete('/admin/users/$uid');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    await _attachToken();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Chưa đăng nhập');
    }

    final data = await api.get(
      '/notifications',
      queryParameters: {'receiverId': uid},
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<int> getUnreadNotificationCount() async {
    final items = await getMyNotifications();
    return items.where((e) => e['isRead'] != true).length;
  }

  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    await _attachToken();
    final data = await api.patch('/notifications/$id/read');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getNotificationCampaigns() async {
    await _attachToken();

    final data = await api.get('/notification-campaigns');

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createNotificationCampaign({
    required String title,
    required String body,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/notification-campaigns',
      data: {'title': title, 'body': body},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateNotificationCampaign({
    required String id,
    required String title,
    required String body,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/notification-campaigns/$id',
      data: {'title': title, 'body': body},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> deleteNotificationCampaign(String id) async {
    await _attachToken();

    final data = await api.delete('/notification-campaigns/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveFcmToken(String token) async {
    await _attachToken();

    await api.post('/users/me/fcm-token', data: {'token': token});
  }
}
