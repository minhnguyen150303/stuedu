import 'package:firebase_auth/firebase_auth.dart';
import '../sources/remote/api_client.dart';

class QlsvRepository {
  final ApiClient api;

  QlsvRepository(this.api);

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null) {
      throw Exception('Chưa đăng nhập');
    }

    api.setToken(token);
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

  Future<List<Map<String, dynamic>>> getClasses({
    String? semesterId,
    String? courseId,
    String? adminState,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/classes',
      queryParameters: {
        'semesterId': semesterId,
        'courseId': courseId,
        'adminState': adminState,
      }..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getCourses({String? majorId}) async {
    await _attachToken();
    final data = await api.get(
      '/courses',
      queryParameters: {'majorId': majorId}
        ..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getSemesterCycles({
    String? majorId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/semester-cycles',
      queryParameters: {'majorId': majorId}
        ..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getExamSchedules({
    String? semesterId,
    String? courseId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/exam-schedules',
      queryParameters: {'semesterId': semesterId, 'courseId': courseId}
        ..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createExamSchedule({
    required String courseId,
    required String semesterId,
    required DateTime examDate,
    required String examRoom,
    String note = '',
  }) async {
    await _attachToken();
    final data = await api.post(
      '/exam-schedules',
      data: {
        'courseId': courseId,
        'semesterId': semesterId,
        'examDate': examDate.toIso8601String(),
        'examRoom': examRoom,
        'examType': 'final',
        'note': note,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateExamSchedule({
    required String id,
    required String courseId,
    required String semesterId,
    required DateTime examDate,
    required String examRoom,
    String note = '',
  }) async {
    await _attachToken();
    final data = await api.patch(
      '/exam-schedules/$id',
      data: {
        'courseId': courseId,
        'semesterId': semesterId,
        'examDate': examDate.toIso8601String(),
        'examRoom': examRoom,
        'note': note,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> deleteExamSchedule(String id) async {
    await _attachToken();

    final data = await api.delete('/exam-schedules/$id');

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> upsertFinalGrade({
    required String classId,
    required String studentId,
    required double scoreFinal,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/grades/final',
      data: {
        'classId': classId,
        'studentId': studentId,
        'scoreFinal': scoreFinal,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getClassUsers({
    required String classId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/enrollments/class/$classId/users',
      queryParameters: {'status': 'approved'},
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getGrades({
    required String classId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/grades',
      queryParameters: {'classId': classId},
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    await _attachToken();
    final data = await api.get('/users/me');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateMyProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/users/me',
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'address': address,
        'avatarUrl': avatarUrl,
      }..removeWhere((key, value) => value == null),
    );

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

  Future<Map<String, dynamic>> checkImportFinalGrades({
    required String classId,
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/grades/final/import/check',
      data: {'classId': classId, 'rows': rows},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> importFinalGrades({
    required String classId,
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/grades/final/import',
      data: {'classId': classId, 'rows': rows},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkImportExamSchedules({
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/exam-schedules/import/check',
      data: {'rows': rows},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> importExamSchedules({
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await api.post('/exam-schedules/import', data: {'rows': rows});

    return Map<String, dynamic>.from(data as Map);
  }
}
