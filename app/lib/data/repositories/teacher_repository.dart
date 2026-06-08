import 'package:firebase_auth/firebase_auth.dart';
import '../sources/remote/api_client.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class TeacherRepository {
  final ApiClient _api;

  TeacherRepository(this._api);

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null) {
      throw Exception('Chưa đăng nhập');
    }

    _api.setToken(token);
  }

  Future<List<Map<String, dynamic>>> getMyClasses({
    required String teacherId,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/classes',
      queryParameters: {'teacherId': teacherId},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getCourses() async {
    await _attachToken();

    final data = await _api.get('/courses');

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getEnrollments({
    String? classId,
    String? status,
  }) async {
    await _attachToken();

    final query = <String, dynamic>{};
    if (classId != null && classId.isNotEmpty) query['classId'] = classId;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final data = await _api.get('/enrollments', queryParameters: query);

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getClassUsers({
    required String classId,
    String? status,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/enrollments/class/$classId/users',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getMaterials({
    required String classId,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/materials',
      queryParameters: {'classId': classId},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getAssignments({
    required String classId,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/assignments',
      queryParameters: {'classId': classId},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getGrades({
    required String classId,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/grades',
      queryParameters: {'classId': classId},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<void> createMaterial({
    required String classId,
    required String title,
    required String type,
    required String url,
    String? downloadUrl,
    String? publicId,
    String? resourceType,
    String? originalName,
    String? format,
  }) async {
    await _attachToken();

    await _api.post(
      '/materials',
      data: {
        'classId': classId,
        'title': title,
        'type': type,
        'url': url,
        'downloadUrl': downloadUrl,
        'publicId': publicId,
        'resourceType': resourceType,
        'originalName': originalName,
        'format': format,
      },
    );
  }

  Future<void> updateMaterial({
    required String id,
    required String classId,
    required String title,
    required String type,
    required String url,
    String? downloadUrl,
    String? publicId,
    String? resourceType,
    String? originalName,
    String? format,
  }) async {
    await _attachToken();

    await _api.put(
      '/materials/$id',
      data: {
        'classId': classId,
        'title': title,
        'type': type,
        'url': url,
        'downloadUrl': downloadUrl,
        'publicId': publicId,
        'resourceType': resourceType,
        'originalName': originalName,
        'format': format,
      },
    );
  }

  Future<void> deleteMaterial(String id) async {
    await _attachToken();
    await _api.delete('/materials/$id');
  }

  Future<void> createAssignment({
    required String classId,
    required String title,
    required String content,
    required DateTime deadline,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _attachToken();

    await _api.post(
      '/assignments',
      data: {
        'classId': classId,
        'title': title,
        'content': content,
        'deadline': deadline.toIso8601String(),
        'attachments': attachments,
      },
    );
  }

  Future<void> updateAssignment({
    required String id,
    required String classId,
    required String title,
    required String content,
    required DateTime deadline,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    await _attachToken();

    await _api.put(
      '/assignments/$id',
      data: {
        'classId': classId,
        'title': title,
        'content': content,
        'deadline': deadline.toIso8601String(),
        'attachments': attachments,
      },
    );
  }

  Future<void> deleteAssignment(String id) async {
    await _attachToken();
    await _api.delete('/assignments/$id');
  }

  Future<Map<String, dynamic>> gradeAssignmentSubmission({
    required String assignmentId,
    required String studentId,
    required double assignmentScore,
  }) async {
    await _attachToken();

    final data = await _api.patch(
      '/assignments/$assignmentId/submissions/$studentId/grade',
      data: {'assignmentScore': assignmentScore},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> upsertGrade({
    required String classId,
    required String studentId,
    required double scoreProcess,
    required double scoreMid,
  }) async {
    await _attachToken();

    await _api.post(
      '/grades',
      data: {
        'classId': classId,
        'studentId': studentId,
        'scoreProcess': scoreProcess,
        'scoreMid': scoreMid,
      },
    );
  }

  Future<Map<String, dynamic>> uploadFileDetailed(File file) async {
    await _attachToken();

    final fileName = file.path.split('/').last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final data = await _api.post('/uploads/single', data: formData);

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Upload thất bại');
  }

  Future<String> uploadFile(File file) async {
    final data = await uploadFileDetailed(file);

    if (data['url'] != null) {
      return data['url'].toString();
    }

    throw Exception('Upload thất bại');
  }

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    await _attachToken();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Chưa đăng nhập');
    }

    final data = await _api.get(
      '/notifications',
      queryParameters: {'receiverId': uid},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<int> getUnreadNotificationCount() async {
    final items = await getMyNotifications();
    return items.where((e) => e['isRead'] != true).length;
  }

  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    await _attachToken();
    final data = await _api.patch('/notifications/$id/read');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    await _attachToken();

    final data = await _api.get('/teachers/me/profile');

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateMyProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
  }) async {
    await _attachToken();

    final data = await _api.patch(
      '/teachers/me/profile',
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'address': address,
        'avatarUrl': avatarUrl,
      }..removeWhere((key, value) => value == null),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkImportGrades({
    required String classId,
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await _api.post(
      '/grades/import/check',
      data: {'classId': classId, 'rows': rows},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> importGrades({
    required String classId,
    required List<Map<String, dynamic>> rows,
  }) async {
    await _attachToken();

    final data = await _api.post(
      '/grades/import',
      data: {'classId': classId, 'rows': rows},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getAvailableStudentsForClass({
    required String classId,
    String? q,
  }) async {
    await _attachToken();

    final data = await _api.get(
      '/classes/$classId/available-students',
      queryParameters: {if (q != null && q.trim().isNotEmpty) 'q': q.trim()},
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> addStudentToClass({
    required String classId,
    required String studentId,
  }) async {
    await _attachToken();

    final data = await _api.post(
      '/classes/$classId/students',
      data: {'studentId': studentId},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> removeStudentFromClass({
    required String classId,
    required String studentId,
  }) async {
    await _attachToken();

    final data = await _api.delete('/classes/$classId/students/$studentId');

    return Map<String, dynamic>.from(data as Map);
  }
}
