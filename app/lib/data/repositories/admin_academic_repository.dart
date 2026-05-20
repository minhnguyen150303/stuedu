import 'package:firebase_auth/firebase_auth.dart';
import '../sources/remote/api_client.dart';

class AdminAcademicRepository {
  final ApiClient api;

  AdminAcademicRepository(this.api);

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null) {
      throw Exception('Chưa đăng nhập');
    }

    api.setToken(token);
  }

  Future<List<Map<String, dynamic>>> getMajors() async {
    await _attachToken();
    final data = await api.get('/majors');
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createMajor({
    required String name,
    String? description,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/majors',
      data: {'name': name, 'description': description ?? ''},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateMajor({
    required String id,
    String? name,
    String? description,
  }) async {
    await _attachToken();
    final data = await api.patch(
      '/majors/$id',
      data: {'name': name, 'description': description}
        ..removeWhere((key, value) => value == null),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> deleteMajor(String id) async {
    await _attachToken();
    final data = await api.delete('/majors/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getSemesters({
    required String majorId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/semesters',
      queryParameters: {'majorId': majorId},
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createSemester({
    required String majorId,
    required int yearNumber,
    required int termNumber,
    required String academicYear,
    required String registrationOpenAt,
    required String registrationCloseAt,
    required String studyStartAt,
    required String studyEndAt,
    bool isManualLocked = false,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/semesters',
      data: {
        'majorId': majorId,
        'yearNumber': yearNumber,
        'termNumber': termNumber,
        'academicYear': academicYear,
        'registrationOpenAt': registrationOpenAt,
        'registrationCloseAt': registrationCloseAt,
        'studyStartAt': studyStartAt,
        'studyEndAt': studyEndAt,
        'isManualLocked': isManualLocked,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> setCurrentSemester(String id) async {
    await _attachToken();
    final data = await api.patch('/semesters/$id/set-current');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getSemesterCycles({
    required String majorId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/semester-cycles',
      queryParameters: {'majorId': majorId},
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getSemesterHistory({
    required String majorId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/semester-cycles/history',
      queryParameters: {'majorId': majorId},
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createSemesterCycle({
    required String majorId,
    required int yearNumber,
    required int termNumber,
    required int registrationOpenMonth,
    required int registrationOpenDay,
    required int registrationCloseMonth,
    required int registrationCloseDay,
    required int studyStartMonth,
    required int studyStartDay,
    required int studyEndMonth,
    required int studyEndDay,
    bool isActive = true,
    bool isManualLocked = false,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/semester-cycles',
      data: {
        'majorId': majorId,
        'yearNumber': yearNumber,
        'termNumber': termNumber,
        'registrationOpenMonth': registrationOpenMonth,
        'registrationOpenDay': registrationOpenDay,
        'registrationCloseMonth': registrationCloseMonth,
        'registrationCloseDay': registrationCloseDay,
        'studyStartMonth': studyStartMonth,
        'studyStartDay': studyStartDay,
        'studyEndMonth': studyEndMonth,
        'studyEndDay': studyEndDay,
        'isActive': isActive,
        'isManualLocked': isManualLocked,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateSemesterCycle({
    required String id,
    int? yearNumber,
    int? termNumber,
    int? registrationOpenMonth,
    int? registrationOpenDay,
    int? registrationCloseMonth,
    int? registrationCloseDay,
    int? studyStartMonth,
    int? studyStartDay,
    int? studyEndMonth,
    int? studyEndDay,
    bool? isActive,
    bool? isManualLocked,
  }) async {
    await _attachToken();
    final data = await api.patch(
      '/semester-cycles/$id',
      data: {
        'yearNumber': yearNumber,
        'termNumber': termNumber,
        'registrationOpenMonth': registrationOpenMonth,
        'registrationOpenDay': registrationOpenDay,
        'registrationCloseMonth': registrationCloseMonth,
        'registrationCloseDay': registrationCloseDay,
        'studyStartMonth': studyStartMonth,
        'studyStartDay': studyStartDay,
        'studyEndMonth': studyEndMonth,
        'studyEndDay': studyEndDay,
        'isActive': isActive,
        'isManualLocked': isManualLocked,
      }..removeWhere((key, value) => value == null),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> deleteSemesterCycle(String id) async {
    await _attachToken();
    final data = await api.delete('/semester-cycles/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getCourses({
    required String majorId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/courses',
      queryParameters: {'majorId': majorId},
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createCourse({
    required String majorId,
    required String courseName,
    required String courseCode,
    required int credits,
    String? description,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/courses',
      data: {
        'majorId': majorId,
        'courseName': courseName,
        'courseCode': courseCode,
        'credits': credits,
        'description': description ?? '',
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateCourse({
    required String id,
    String? courseName,
    String? courseCode,
    int? credits,
    String? description,
    String? majorId,
  }) async {
    await _attachToken();
    final data = await api.patch(
      '/courses/$id',
      data: {
        'courseName': courseName,
        'courseCode': courseCode,
        'credits': credits,
        'description': description,
        'majorId': majorId,
      }..removeWhere((key, value) => value == null),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getCurriculum({
    required String majorId,
    required String semesterId,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/curriculum',
      queryParameters: {'majorId': majorId, 'semesterId': semesterId},
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> addCourseToCurriculum({
    required String majorId,
    required String semesterId,
    required String courseId,
  }) async {
    await _attachToken();
    final data = await api.post(
      '/curriculum',
      data: {
        'majorId': majorId,
        'semesterId': semesterId,
        'courseId': courseId,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateCurriculumItem({
    required String id,
    bool? isVisible,
    String? majorId,
    String? semesterId,
    String? courseId,
  }) async {
    await _attachToken();
    final data = await api.patch(
      '/curriculum/$id',
      data: {
        'isVisible': isVisible,
        'majorId': majorId,
        'semesterId': semesterId,
        'courseId': courseId,
      }..removeWhere((key, value) => value == null),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> removeCurriculumItem(String id) async {
    await _attachToken();
    final data = await api.delete('/curriculum/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getClassLifecycles({
    String? majorId,
    String? yearNumber,
    String? termNumber,
    String? courseId,
    String? hidden,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/class-lifecycles',
      queryParameters: {
        'majorId': majorId,
        'yearNumber': yearNumber,
        'termNumber': termNumber,
        'courseId': courseId,
        'hidden': hidden,
      }..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createClassLifecycle({
    required String courseId,
    required String teacherId,
    required String classCode,
    required String room,
    required List<Map<String, dynamic>> schedule,
    required int maxStudents,
    required String majorId,
    required int yearNumber,
    required int termNumber,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/class-lifecycles',
      data: {
        'courseId': courseId,
        'teacherId': teacherId,
        'classCode': classCode,
        'room': room,
        'schedule': schedule,
        'maxStudents': maxStudents,
        'majorId': majorId,
        'yearNumber': yearNumber,
        'termNumber': termNumber,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateClassLifecycle({
    required String id,
    String? courseId,
    String? teacherId,
    String? classCode,
    String? room,
    List<Map<String, dynamic>>? schedule,
    int? maxStudents,
    String? majorId,
    int? yearNumber,
    int? termNumber,
    bool? isHidden,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/class-lifecycles/$id',
      data: {
        'courseId': courseId,
        'teacherId': teacherId,
        'classCode': classCode,
        'room': room,
        'schedule': schedule,
        'maxStudents': maxStudents,
        'majorId': majorId,
        'yearNumber': yearNumber,
        'termNumber': termNumber,
        'isHidden': isHidden,
      }..removeWhere((key, value) => value == null),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> hideClassLifecycle(String id) async {
    await _attachToken();

    final data = await api.patch('/class-lifecycles/$id/hide', data: {});

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> replaceClassLifecycle({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    await _attachToken();

    final data = await api.post('/class-lifecycles/$id/replace', data: payload);

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getClasses({
    String? courseId,
    String? semesterId,
    String? adminState,
    String? academicYearSnapshot,
    bool? isVisibleForRegistration,
    String? teacherId,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/classes',
      queryParameters: {
        'courseId': courseId,
        'semesterId': semesterId,
        'adminState': adminState,
        'academicYearSnapshot': academicYearSnapshot,
        'isVisibleForRegistration': isVisibleForRegistration,
        'teacherId': teacherId,
      }..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> createClass({
    required String courseId,
    required String semesterId,
    required String teacherId,
    required String classCode,
    required String room,
    required int maxStudents,
    required List<Map<String, dynamic>> schedule,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/classes',
      data: {
        'courseId': courseId,
        'semesterId': semesterId,
        'teacherId': teacherId,
        'classCode': classCode,
        'room': room,
        'maxStudents': maxStudents,
        'schedule': schedule,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateClass({
    required String id,
    String? courseId,
    String? semesterId,
    String? teacherId,
    String? classCode,
    String? room,
    int? maxStudents,
    List<Map<String, dynamic>>? schedule,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/classes/$id',
      data: {
        'courseId': courseId,
        'semesterId': semesterId,
        'teacherId': teacherId,
        'classCode': classCode,
        'room': room,
        'maxStudents': maxStudents,
        'schedule': schedule,
      }..removeWhere((key, value) => value == null),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> archiveClass(String id) async {
    await _attachToken();

    final data = await api.patch('/classes/$id/archive');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getStudents({
    String? q,
    String? majorId,
    int page = 1,
    int limit = 50,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/admin/users',
      queryParameters: {
        'role': 'student',
        'q': q,
        'majorId': majorId,
        'page': page,
        'limit': limit,
      }..removeWhere((key, value) => value == null || value == ''),
    );

    final map = Map<String, dynamic>.from(data as Map);
    final items = List<Map<String, dynamic>>.from(
      (map['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );

    return items;
  }

  Future<Map<String, dynamic>> addStudentToClass({
    required String classId,
    required String studentId,
  }) async {
    await _attachToken();

    final data = await api.post(
      '/classes/$classId/students',
      data: {'studentId': studentId},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getAvailableStudentsForClass({
    required String classId,
    String? q,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/classes/$classId/available-students',
      queryParameters: {'q': q}
        ..removeWhere((key, value) => value == null || value == ''),
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> toggleClassVisibility({
    required String id,
    required bool isVisibleForRegistration,
  }) async {
    await _attachToken();

    final data = await api.patch(
      '/classes/$id/visibility',
      data: {'isVisibleForRegistration': isVisibleForRegistration},
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> removeStudentFromClass({
    required String classId,
    required String studentId,
  }) async {
    await _attachToken();

    final data = await api.delete('/classes/$classId/students/$studentId');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getTeachers() async {
    await _attachToken();

    final data = await api.get(
      '/admin/users',
      queryParameters: {'role': 'teacher', 'page': 1, 'limit': 100},
    );

    final map = Map<String, dynamic>.from(data as Map);
    final items = List<Map<String, dynamic>>.from(
      (map['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );

    return items;
  }

  Future<List<Map<String, dynamic>>> getEnrollments({
    required String classId,
    String? status,
  }) async {
    await _attachToken();
    final data = await api.get(
      '/enrollments',
      queryParameters: {'classId': classId, 'status': status}
        ..removeWhere((key, value) => value == null || value == ''),
    );
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> getUserDetail(String uid) async {
    await _attachToken();
    final data = await api.get('/admin/users/$uid');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getTeachersByMajor({
    required String majorId,
  }) async {
    await _attachToken();

    final data = await api.get(
      '/admin/teachers/by-major',
      queryParameters: {'majorId': majorId},
    );

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }
}
