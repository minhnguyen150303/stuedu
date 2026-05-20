import 'package:flutter/material.dart';
import '../../../data/repositories/teacher_repository.dart';

class TeacherHomeViewModel extends ChangeNotifier {
  final TeacherRepository _repo;

  TeacherHomeViewModel(this._repo);

  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> myClasses = [];
  List<Map<String, dynamic>> todaySchedule = [];
  List<Map<String, dynamic>> assignmentActivities = [];
  int totalRecentSubmissions = 0;

  int activeClassCount = 0;
  int draftClassCount = 0;
  int archivedClassCount = 0;

  Future<void> loadHome({required Map<String, dynamic> profile}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final teacherId = (profile['uid'] ?? '').toString();
      if (teacherId.isEmpty) {
        throw Exception('Thiếu teacherId');
      }

      final classes = await _repo.getMyClasses(teacherId: teacherId);
      final courses = await _repo.getCourses();

      final courseNameById = <String, String>{
        for (final c in courses)
          c['id'].toString(): (c['courseName'] ?? 'Chưa rõ môn').toString(),
      };

      myClasses = classes
          .map((cls) {
            return {
              ...cls,
              'courseName':
                  courseNameById[cls['courseId'].toString()] ?? 'Chưa rõ môn',
            };
          })
          .where((cls) => (cls['adminState'] ?? '').toString() == 'active')
          .toList();

      activeClassCount = myClasses
          .where((e) => (e['adminState'] ?? 'draft').toString() == 'active')
          .length;

      draftClassCount = myClasses
          .where((e) => (e['adminState'] ?? 'draft').toString() == 'draft')
          .length;

      archivedClassCount = myClasses
          .where((e) => (e['adminState'] ?? '').toString() == 'archived')
          .length;

      todaySchedule = buildScheduleForDate(DateTime.now());
      await _loadAssignmentActivities();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAssignmentActivities() async {
    final items = <Map<String, dynamic>>[];
    int total = 0;

    for (final cls in myClasses) {
      final classId = (cls['id'] ?? '').toString();
      if (classId.isEmpty) continue;

      final assignments = await _repo.getAssignments(classId: classId);

      for (final assignment in assignments) {
        final submissionCount =
            int.tryParse((assignment['submissionCount'] ?? 0).toString()) ?? 0;

        if (submissionCount <= 0) continue;

        total += submissionCount;

        items.add({
          ...assignment,
          'classId': classId,
          'classCode': cls['classCode'],
          'courseName': cls['courseName'],
          'room': cls['room'],
        });
      }
    }

    items.sort((a, b) {
      final da = DateTime.tryParse((a['latestSubmittedAt'] ?? '').toString());
      final db = DateTime.tryParse((b['latestSubmittedAt'] ?? '').toString());

      return (db ?? DateTime(1970)).compareTo(da ?? DateTime(1970));
    });

    assignmentActivities = items.take(5).toList();
    totalRecentSubmissions = total;
  }

  String getSessionLabel(String startTime) {
    final parts = startTime.split(':');
    if (parts.length != 2) return 'Sáng';

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final totalMinutes = hour * 60 + minute;

    return totalMinutes < 12 * 60 ? 'Sáng' : 'Chiều';
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isDateWithinClassRange(Map<String, dynamic> cls, DateTime date) {
    if ((cls['adminState'] ?? '').toString() != 'active') {
      return false;
    }

    final timeline = cls['semesterTimeline'];
    if (timeline is! Map) {
      return true;
    }

    DateTime? start;
    DateTime? end;

    try {
      final startRaw = timeline['studyStartAt'];
      final endRaw = timeline['studyEndAt'];

      if (startRaw != null) {
        final parsed = DateTime.parse(startRaw.toString());
        start = DateTime.utc(parsed.year, parsed.month, parsed.day);
      }

      if (endRaw != null) {
        final parsed = DateTime.parse(endRaw.toString());
        end = DateTime.utc(parsed.year, parsed.month, parsed.day);
      }
    } catch (_) {
      return true;
    }

    final target = DateTime.utc(date.year, date.month, date.day);

    if (start != null && target.isBefore(start)) {
      return false;
    }

    if (end != null && target.isAfter(end)) {
      return false;
    }

    return true;
  }

  List<Map<String, dynamic>> buildScheduleForDate(DateTime date) {
    final apiDay = _mapWeekdayToApi(date.weekday);
    final result = <Map<String, dynamic>>[];

    for (final cls in myClasses) {
      if (!_isDateWithinClassRange(cls, date)) continue;

      final rawSchedule = cls['schedule'];
      if (rawSchedule is! List) continue;

      for (final raw in rawSchedule) {
        if (raw is! Map) continue;

        final item = Map<String, dynamic>.from(raw);
        final dayOfWeek = (item['dayOfWeek'] as num?)?.toInt();

        if (dayOfWeek == apiDay) {
          result.add({
            'classId': cls['id'],
            'classCode': (cls['classCode'] ?? '').toString(),
            'courseName': (cls['courseName'] ?? 'Chưa rõ môn').toString(),
            'room': (cls['room'] ?? '').toString(),
            'startTime': (item['startTime'] ?? '').toString(),
            'endTime': (item['endTime'] ?? '').toString(),
            'adminState': (cls['adminState'] ?? 'draft').toString(),
            'dayOfWeek': dayOfWeek,
          });
        }
      }
    }

    result.sort((a, b) {
      final aStart = (a['startTime'] ?? '').toString();
      final bStart = (b['startTime'] ?? '').toString();
      return aStart.compareTo(bStart);
    });

    return result;
  }

  List<DateTime> getTeachingDaysInMonth(DateTime month) {
    final days = <DateTime>[];
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (buildScheduleForDate(date).isNotEmpty) {
        days.add(date);
      }
    }

    return days;
  }

  int _mapWeekdayToApi(int weekday) {
    // Flutter: 1=Mon ... 7=Sun
    // Backend: 2=Mon ... 8=Sun
    return weekday == 7 ? 8 : weekday + 1;
  }
}
