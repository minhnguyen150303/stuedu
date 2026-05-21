import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../sources/remote/api_client.dart';

class StudentRepository {
  final ApiClient api;

  StudentRepository(this.api);

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }

    api.setToken(token);
  }

  Future<Map<String, dynamic>> getHomeDashboard() async {
    await _attachToken();
    final res = await api.get('/students/me/home');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> getMyClasses() async {
    await _attachToken();
    final res = await api.get('/students/me/classes');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getTodaySchedule() async {
    await _attachToken();
    final res = await api.get('/students/me/schedule-today');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingAssignments({
    int limit = 10,
  }) async {
    await _attachToken();
    final res = await api.get('/students/me/assignments/upcoming?limit=$limit');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getMyGrades() async {
    await _attachToken();
    final res = await api.get('/students/me/grades');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<Map<String, dynamic>> getGpaProgress() async {
    await _attachToken();

    final res = await api.get('/students/me/gpa-progress');

    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getCreditProgress() async {
    await _attachToken();

    final res = await api.get('/students/me/credit-progress');

    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    await _attachToken();
    final res = await api.get('/students/me/notifications');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<int> getUnreadNotificationCount() async {
    final items = await getMyNotifications();
    return items.where((e) => e['isRead'] != true).length;
  }

  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    await _attachToken();
    final res = await api.patch('/notifications/$id/read');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getWeeklySchedule({String? date}) async {
    await _attachToken();

    final res = await api.get(
      '/students/me/schedule-week',
      queryParameters: {if (date != null && date.isNotEmpty) 'date': date},
    );

    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getMonthlySchedule({String? month}) async {
    await _attachToken();

    final res = await api.get(
      '/students/me/schedule-month',
      queryParameters: {if (month != null && month.isNotEmpty) 'month': month},
    );

    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    await _attachToken();
    final res = await api.get(
      '/enrollments/class/$classId/users?status=approved',
    );
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getClassAssignments(String classId) async {
    await _attachToken();
    final res = await api.get('/assignments?classId=$classId');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<List<Map<String, dynamic>>> getClassMaterials(String classId) async {
    await _attachToken();
    final res = await api.get('/materials?classId=$classId');
    return List<Map<String, dynamic>>.from(
      (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<Map<String, dynamic>> uploadFileDetailed(File file) async {
    await _attachToken();

    final fileName = file.path.split('/').last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final data = await api.post('/uploads/single', data: formData);

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Upload thất bại');
  }

  Future<void> submitAssignment({
    required String assignmentId,
    required Map<String, dynamic> uploadedFile,
  }) async {
    await _attachToken();

    await api.post(
      '/assignments/$assignmentId/submit',
      data: {
        'fileUrl': uploadedFile['url'],
        'publicId': uploadedFile['publicId'],
        'resourceType': uploadedFile['resourceType'],
        'originalName': uploadedFile['originalName'],
        'format': uploadedFile['format'],
      },
    );
  }

  ///register
  Future<Map<String, dynamic>> getCourseRegistrationData() async {
    await _attachToken();
    final res = await api.get('/students/me/course-registration');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> registerCourseClass({
    required String classId,
  }) async {
    await _attachToken();
    final res = await api.post(
      '/students/me/course-registration',
      data: {'classId': classId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  //asign
  Future<List<Map<String, dynamic>>> getAllMyAssignments() async {
    await _attachToken();

    final classes = await getMyClasses();
    final List<Map<String, dynamic>> items = [];

    for (final cls in classes) {
      final classId = (cls['id'] ?? '').toString();
      if (classId.isEmpty) continue;

      final assignments = await getClassAssignments(classId);

      for (final item in assignments) {
        items.add({
          ...item,
          'classId': classId,
          'classCode': cls['classCode'],
          'courseId': cls['courseId'],
          'courseName': cls['courseName'],
          'courseCode': cls['courseCode'],
          'credits': cls['credits'],
        });
      }
    }

    return items;
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    await _attachToken();

    final res = await api.get('/students/me/profile');

    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateMyProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
  }) async {
    await _attachToken();

    final res = await api.patch(
      '/students/me/profile',
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'address': address,
        'avatarUrl': avatarUrl,
      }..removeWhere((key, value) => value == null),
    );

    return Map<String, dynamic>.from(res as Map);
  }
}
