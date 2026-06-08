const { db } = require("../config/firebase");

function toDateSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate();
    if (value instanceof Date) return value;

    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
}

function toISOStringSafe(value) {
    const d = toDateSafe(value);
    return d ? d.toISOString() : null;
}

function toUtcDateKey(value) {
    const d = toDateSafe(value);
    if (!d) return "";
    return [
        d.getUTCFullYear(),
        String(d.getUTCMonth() + 1).padStart(2, "0"),
        String(d.getUTCDate()).padStart(2, "0"),
    ].join("-");
}

function toLocalDateKey(date) {
    if (!date) return "";
    return [
        date.getFullYear(),
        String(date.getMonth() + 1).padStart(2, "0"),
        String(date.getDate()).padStart(2, "0"),
    ].join("-");
}

function getTodayDayOfWeekCode() {
    const jsDay = new Date().getDay(); // 0=CN, 1=T2, ..., 6=T7
    if (jsDay === 0) return 8; // backend dùng CN=8
    return jsDay + 1; // T2=2 ... T7=7
}

function tenToFour(totalTen) {
    const score = Number(totalTen || 0);

    if (score >= 8.5) return 4.0;
    if (score >= 8.0) return 3.5;
    if (score >= 7.0) return 3.0;
    if (score >= 6.5) return 2.5;
    if (score >= 5.5) return 2.0;
    if (score >= 5.0) return 1.5;
    if (score >= 4.0) return 1.0;
    return 0.0;
}

function tenToLetter(totalTen) {
    const score = Number(totalTen || 0);

    if (score >= 8.5) return "A";
    if (score >= 7.0) return "B";
    if (score >= 5.5) return "C";
    if (score >= 4.0) return "D";
    return "F";
}

function tenToLetterDetailed(totalTen) {
    const score = Number(totalTen || 0);

    if (score >= 8.5) return "A";
    if (score >= 8.0) return "B+";
    if (score >= 7.0) return "B";
    if (score >= 6.5) return "C+";
    if (score >= 5.5) return "C";
    if (score >= 5.0) return "D+";
    if (score >= 4.0) return "D";
    return "F";
}

function round(value, digits = 2) {
    const factor = Math.pow(10, digits);
    return Math.round(value * factor) / factor;
}

function parseAcademicYearStart(academicYear) {
    const match = String(academicYear || "").match(/^(\d{4})-(\d{4})$/);
    return match ? Number(match[1]) : 0;
}

function getClassTermSortValue(cls = {}) {
    const academicStart = parseAcademicYearStart(cls.academicYearSnapshot);
    const yearNumber = Number(cls.yearNumberSnapshot || 0);
    const termNumber = Number(cls.termNumberSnapshot || 0);

    return academicStart * 100 + yearNumber * 10 + termNumber;
}

function buildSemesterKeyFromClass(cls = {}) {
    const academicYear = (cls.academicYearSnapshot || "").toString();
    const yearNumber = Number(cls.yearNumberSnapshot || 0);
    const termNumber = Number(cls.termNumberSnapshot || 0);

    return [
        academicYear || "unknown-year",
        `Y${yearNumber || "?"}`,
        `T${termNumber || "?"}`,
    ].join("-");
}

function buildSemesterLabelFromClass(cls = {}) {
    const academicYear = (cls.academicYearSnapshot || "").toString();
    const yearNumber = Number(cls.yearNumberSnapshot || 0);
    const termNumber = Number(cls.termNumberSnapshot || 0);

    return [
        academicYear || "Chưa rõ năm học",
        yearNumber ? `Năm ${yearNumber}` : "Chưa rõ năm",
        termNumber ? `HK${termNumber}` : "Chưa rõ kỳ",
    ].join(" • ");
}

function isPassingGrade(grade = {}) {
    const status = (grade.status || "").toString();

    if (status === "Pass") return true;
    if (status === "Fail") return false;

    return Number(grade.totalTen || 0) >= 5;
}

function isFailingGrade(grade = {}) {
    const status = (grade.status || "").toString();

    if (status === "Fail") return true;
    if (status === "Pass") return false;

    return Number(grade.totalTen || 0) < 5;
}

function passFailByTotalTen(totalTen) {
    return Number(totalTen || 0) >= 5 ? "Pass" : "Fail";
}

function getTrendSortValue(academicYear, yearNumber, termNumber) {
    const match = String(academicYear || "").match(/^(\d{4})-(\d{4})$/);
    const academicStart = match ? Number(match[1]) : 0;

    return (
        academicStart * 100 +
        Number(yearNumber || 0) * 10 +
        Number(termNumber || 0)
    );
}

function createWeightedBucket(extra = {}) {
    return {
        ...extra,
        totalWeightedGpa: 0,
        totalCredits: 0,
        subjectCount: 0,
    };
}

function addGradeToBucket(bucket, gpa4, credits) {
    const safeCredits = Number(credits || 0) > 0 ? Number(credits) : 1;

    bucket.totalWeightedGpa += Number(gpa4 || 0) * safeCredits;
    bucket.totalCredits += safeCredits;
    bucket.subjectCount += 1;
}

function finalizeBucket(bucket) {
    const gpa4 = bucket.totalCredits > 0
        ? round(bucket.totalWeightedGpa / bucket.totalCredits, 2)
        : 0;

    const {
        totalWeightedGpa,
        sort,
        ...rest
    } = bucket;

    return {
        ...rest,
        gpa4,
        credits: bucket.totalCredits,
        subjectCount: bucket.subjectCount,
    };
}

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function isSameLocalDate(a, b) {
    const da = toDateSafe(a);
    const db = toDateSafe(b);

    if (!da || !db) return false;

    return (
        da.getFullYear() === db.getFullYear() &&
        da.getMonth() === db.getMonth() &&
        da.getDate() === db.getDate()
    );
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    return month >= 7 ? academicStartYear : academicStartYear + 1;
}

function buildUtcDate(year, month, day, isEndOfDay = false) {
    if (isEndOfDay) {
        return new Date(Date.UTC(year, month - 1, day, 23, 59, 59));
    }
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0));
}

function getWeekStart(date = new Date()) {
    const d = new Date(date);
    const day = d.getDay(); // 0=Sun, 1=Mon...
    const diff = day === 0 ? -6 : 1 - day; // về thứ 2
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() + diff);
    return d;
}

function addDays(date, days) {
    const d = new Date(date);
    d.setDate(d.getDate() + days);
    return d;
}

function toSystemDayOfWeek(jsDate) {
    const jsDay = jsDate.getDay(); // 0..6
    if (jsDay === 0) return 8;
    return jsDay + 1; // Mon=2 ... Sat=7
}

function isDateWithinStudyTimeline(date, semesterTimeline) {
    if (!date || !semesterTimeline) return true;

    const currentKey = toLocalDateKey(date);
    const startKey = toUtcDateKey(semesterTimeline.studyStartAt);
    const endKey = toUtcDateKey(semesterTimeline.studyEndAt);

    if (!startKey || !endKey) return true;

    return currentKey >= startKey && currentKey <= endKey;
}

async function getSemesterTimelineMapByIds(semesterIds = []) {
    const map = {};

    for (const semesterId of semesterIds) {
        if (!semesterId || map[semesterId]) continue;

        const snap = await db.collection("semester_cycles").doc(semesterId).get();
        if (!snap.exists) continue;

        const data = snap.data() || {};
        const academicStartYear = getAcademicStartYear();

        const studyStartMonth = Number(data.studyStartMonth);
        const studyStartDay = Number(data.studyStartDay);
        const studyEndMonth = Number(data.studyEndMonth);
        const studyEndDay = Number(data.studyEndDay);

        if (
            !studyStartMonth || !studyStartDay ||
            !studyEndMonth || !studyEndDay
        ) {
            continue;
        }

        const studyStartYear = getDateYearForAcademicCycle(
            studyStartMonth,
            academicStartYear
        );

        const studyEndYear = getDateYearForAcademicCycle(
            studyEndMonth,
            academicStartYear
        );

        map[semesterId] = {
            studyStartAt: buildUtcDate(
                studyStartYear,
                studyStartMonth,
                studyStartDay
            ).toISOString(),
            studyEndAt: buildUtcDate(
                studyEndYear,
                studyEndMonth,
                studyEndDay,
                true
            ).toISOString(),
        };
    }

    return map;
}

async function getStudentProfile(studentId) {
    const ref = db.collection("users").doc(studentId);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Student not found");
        err.statusCode = 404;
        throw err;
    }

    const data = snap.data() || {};

    if (data.role !== "student") {
        const err = new Error("User is not a student");
        err.statusCode = 403;
        throw err;
    }

    const majorId = (
        data.majorId ||
        data.studentInfo?.majorId ||
        ""
    ).toString();

    let majorName = "";
    if (majorId) {
        const majorSnap = await db.collection("majors").doc(majorId).get();
        if (majorSnap.exists) {
            majorName = (majorSnap.data()?.name || "").toString();
        }
    }

    return {
        uid: snap.id,
        fullName: data.fullName || "",
        email: data.email || "",
        avatarUrl: data.avatarUrl || "",
        role: data.role || "",
        majorId,
        majorName,
        studentInfo: data.studentInfo || null,
    };
}

async function getTotalMajorCredits(majorId) {
    if (!majorId) return 0;

    const snap = await db.collection("courses")
        .where("majorId", "==", majorId)
        .get();

    let total = 0;
    for (const doc of snap.docs) {
        const data = doc.data() || {};
        total += Number(data.credits || 0);
    }

    return total;
}

async function getApprovedEnrollments(studentId) {
    const snap = await db.collection("enrollments")
        .where("studentId", "==", studentId)
        .where("status", "==", "approved")
        .get();

    return snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
    }));
}

async function getClassMapByIds(classIds = []) {
    const map = {};

    for (const classId of classIds) {
        if (!classId || map[classId]) continue;

        const snap = await db.collection("classes").doc(classId).get();
        if (snap.exists) {
            map[classId] = {
                id: snap.id,
                ...snap.data(),
            };
        }
    }

    return map;
}

async function getCourseMapByIds(courseIds = []) {
    const map = {};

    for (const courseId of courseIds) {
        if (!courseId || map[courseId]) continue;

        const snap = await db.collection("courses").doc(courseId).get();
        if (snap.exists) {
            map[courseId] = {
                id: snap.id,
                ...snap.data(),
            };
        }
    }

    return map;
}

async function getExamSchedulesByCourseIds(courseIds = []) {
    const map = {};

    for (const courseId of courseIds) {
        if (!courseId || map[courseId]) continue;

        const snap = await db.collection("exam_schedules")
            .where("courseId", "==", courseId)
            .get();

        map[courseId] = snap.docs.map((doc) => {
            const data = doc.data() || {};

            return {
                id: doc.id,
                courseId: data.courseId || "",
                semesterId: data.semesterId || "",
                examDate: toISOStringSafe(data.examDate),
                examRoom: data.examRoom || "",
                examType: data.examType || "final",
                note: data.note || "",
            };
        });
    }

    return map;
}

async function getCurriculumCourseIdsByMajor(majorId) {
    if (!majorId) return [];

    const snap = await db.collection("curriculum")
        .where("majorId", "==", majorId)
        .get();

    const courseIds = [];

    for (const doc of snap.docs) {
        const data = doc.data() || {};
        const courseId = (data.courseId || "").toString();

        if (!courseId) continue;
        if (data.isVisible === false) continue;

        courseIds.push(courseId);
    }

    return [...new Set(courseIds)];
}

async function getTodaySchedule(studentId) {
    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const semesterIds = classes.map((c) => c.semesterId).filter(Boolean);
    const semesterTimelineMap = await getSemesterTimelineMapByIds(semesterIds);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const today = new Date();
    const todayCode = getTodayDayOfWeekCode();

    const items = classes.flatMap((cls) => {
        const schedule = Array.isArray(cls.schedule) ? cls.schedule : [];
        const course = courseMap[cls.courseId] || {};
        const semesterTimeline = semesterTimelineMap[cls.semesterId] || null;

        if (!isDateWithinStudyTimeline(today, semesterTimeline)) {
            return [];
        }

        return schedule
            .filter((s) => Number(s.dayOfWeek) === todayCode)
            .map((s) => ({
                classId: cls.id,
                classCode: cls.classCode || "",
                courseId: cls.courseId || "",
                courseName: course.courseName || "",
                credits: Number(course.credits || 0),
                room: cls.room || "",
                teacherId: cls.teacherId || "",
                startTime: s.startTime || "",
                endTime: s.endTime || "",
                startPeriod: s.startPeriod ?? "",
                endPeriod: s.endPeriod ?? "",
                dayOfWeek: Number(s.dayOfWeek),
                date: today.toISOString(),
                semesterId: cls.semesterId || "",
                semesterTimeline,
            }));
    });

    items.sort((a, b) => a.startTime.localeCompare(b.startTime));
    return items;
}

async function getUpcomingAssignments(studentId, limit = 10) {
    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const now = new Date();
    const items = [];

    for (const cls of classes) {
        const snap = await db.collection("assignments")
            .where("classId", "==", cls.id)
            .get();

        const course = courseMap[cls.courseId] || {};

        for (const doc of snap.docs) {
            const data = doc.data() || {};
            const deadline = toDateSafe(data.deadline);

            if (!deadline) continue;
            if (deadline < now) continue;

            items.push({
                id: doc.id,
                classId: cls.id,
                classCode: cls.classCode || "",
                courseId: cls.courseId || "",
                courseName: course.courseName || "",
                title: data.title || "",
                content: data.content || "",
                deadline: deadline.toISOString(),
                attachments: Array.isArray(data.attachments) ? data.attachments : [],
                createdAt: toISOStringSafe(data.createdAt),
            });
        }
    }

    items.sort((a, b) => new Date(a.deadline) - new Date(b.deadline));
    return items.slice(0, Math.max(limit, 1));
}

async function getMyClasses(studentId) {
    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const items = classes.map((cls) => {
        const course = courseMap[cls.courseId] || {};

        return {
            id: cls.id,
            classCode: cls.classCode || "",
            classId: cls.id,
            courseId: cls.courseId || "",
            courseName: course.courseName || "",
            courseCode: course.courseCode || "",
            credits: Number(course.credits || 0),
            teacherId: cls.teacherId || "",
            room: cls.room || "",
            schedule: Array.isArray(cls.schedule) ? cls.schedule : [],
            adminState: cls.adminState || "draft",
            semesterId: cls.semesterId || "",
            academicYearSnapshot: cls.academicYearSnapshot || "",
            termNumberSnapshot: cls.termNumberSnapshot ?? null,
            yearNumberSnapshot: cls.yearNumberSnapshot ?? null,
        };
    });

    items.sort((a, b) => a.classCode.localeCompare(b.classCode));
    return items;
}

async function getMyGrades(studentId) {
    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const snap = await db.collection("grades")
        .where("studentId", "==", studentId)
        .get();

    const items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        const cls = classMap[data.classId] || {};
        const course = courseMap[cls.courseId] || {};

        const totalTen = Number(data.totalTen || 0);
        const gpa4 = tenToFour(totalTen);
        const letterGrade = tenToLetter(totalTen);

        return {
            id: doc.id,
            classId: data.classId || "",
            classCode: cls.classCode || "",
            courseId: cls.courseId || "",
            courseName: course.courseName || "",
            courseCode: course.courseCode || "",
            credits: Number(course.credits || 0),
            scoreProcess: Number(data.scoreProcess || 0),
            scoreMid: Number(data.scoreMid || 0),
            scoreFinal: Number(data.scoreFinal || 0),
            totalTen,
            gpa4,
            letterGrade,
            status: data.status || "",
            updatedAt: toISOStringSafe(data.updatedAt),
        };
    });

    items.sort((a, b) => a.courseName.localeCompare(b.courseName));
    return items;
}

async function getCreditProgress(studentId) {
    const student = await getStudentProfile(studentId);

    const majorId = (student.majorId || "").toString();

    if (!majorId) {
        const err = new Error("Student major is missing");
        err.statusCode = 409;
        throw err;
    }

    const requiredCredits = await getTotalMajorCredits(majorId);

    let curriculumCourseIds = await getCurriculumCourseIdsByMajor(majorId);

    // Fallback: nếu curriculum chưa nhập đủ, lấy toàn bộ courses theo ngành.
    if (curriculumCourseIds.length === 0) {
        const courseSnap = await db.collection("courses")
            .where("majorId", "==", majorId)
            .get();

        curriculumCourseIds = courseSnap.docs
            .map((doc) => doc.id)
            .filter(Boolean);
    }

    const curriculumCourseMap = await getCourseMapByIds(curriculumCourseIds);

    // Loại bỏ curriculum item trỏ tới course đã bị xóa / course rỗng / course 0 tín chỉ
    curriculumCourseIds = curriculumCourseIds.filter((courseId) => {
        const course = curriculumCourseMap[courseId];

        if (!course) return false;

        const courseName = (course.courseName || "").toString().trim();
        const courseCode = (course.courseCode || "").toString().trim();
        const credits = Number(course.credits || 0);

        return (courseName || courseCode) && credits > 0;
    });

    const curriculumCourseSet = new Set(curriculumCourseIds);

    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const enrolledCourseIds = classes
        .map((cls) => (cls.courseId || "").toString())
        .filter(Boolean);

    const enrolledCourseMap = await getCourseMapByIds(enrolledCourseIds);

    const gradeSnap = await db.collection("grades")
        .where("studentId", "==", studentId)
        .get();

    const gradeByCourseId = new Map();

    for (const doc of gradeSnap.docs) {
        const grade = doc.data() || {};
        const classId = (grade.classId || "").toString();
        const cls = classMap[classId] || {};

        const courseId = (cls.courseId || "").toString();
        if (!courseId) continue;

        const current = gradeByCourseId.get(courseId);

        // Nếu cùng môn có nhiều lần học:
        // - ưu tiên bản Pass
        // - nếu chưa Pass, giữ bản điểm mới hơn theo updatedAt
        if (!current) {
            gradeByCourseId.set(courseId, {
                id: doc.id,
                ...grade,
                classId,
                courseId,
                class: cls,
            });
            continue;
        }

        const currentPass = isPassingGrade(current);
        const nextPass = isPassingGrade(grade);

        if (!currentPass && nextPass) {
            gradeByCourseId.set(courseId, {
                id: doc.id,
                ...grade,
                classId,
                courseId,
                class: cls,
            });
            continue;
        }

        const currentUpdated = toDateSafe(current.updatedAt) || new Date(0);
        const nextUpdated = toDateSafe(grade.updatedAt) || new Date(0);

        if (!currentPass && !nextPass && nextUpdated > currentUpdated) {
            gradeByCourseId.set(courseId, {
                id: doc.id,
                ...grade,
                classId,
                courseId,
                class: cls,
            });
        }
    }

    const inProgressCourseIds = new Set();

    for (const cls of classes) {
        const courseId = (cls.courseId || "").toString();
        if (!courseId) continue;

        const grade = gradeByCourseId.get(courseId);

        // Nếu đã có điểm Pass/Fail thì không còn tính là đang học.
        if (grade) continue;

        const adminState = (cls.adminState || "").toString();

        // active/draft đều có thể là lớp đã đăng ký nhưng chưa có điểm.
        // archived mà chưa có điểm thì không nên tính đang học.
        if (adminState !== "archived") {
            inProgressCourseIds.add(courseId);
        }
    }

    const earnedCourseIds = new Set();
    const failedCourseIds = new Set();

    for (const [courseId, grade] of gradeByCourseId.entries()) {
        if (isPassingGrade(grade)) {
            earnedCourseIds.add(courseId);
            continue;
        }

        if (isFailingGrade(grade)) {
            failedCourseIds.add(courseId);
        }
    }

    // Nếu một môn đã Pass rồi thì không tính nợ nữa.
    for (const courseId of earnedCourseIds) {
        failedCourseIds.delete(courseId);
        inProgressCourseIds.delete(courseId);
    }

    // Nếu môn đang học lại thì vẫn có thể đang học, không tính là chưa học.
    const notStartedCourseIds = new Set();

    for (const courseId of curriculumCourseSet) {
        if (earnedCourseIds.has(courseId)) continue;
        if (failedCourseIds.has(courseId)) continue;
        if (inProgressCourseIds.has(courseId)) continue;

        notStartedCourseIds.add(courseId);
    }

    function getCourseCredits(courseId) {
        const course =
            curriculumCourseMap[courseId] ||
            enrolledCourseMap[courseId] ||
            {};

        return Number(course.credits || 0);
    }

    function sumCredits(courseIds) {
        let total = 0;

        for (const courseId of courseIds) {
            total += getCourseCredits(courseId);
        }

        return total;
    }

    const earnedCredits = sumCredits(earnedCourseIds);
    const inProgressCredits = sumCredits(inProgressCourseIds);
    const failedCredits = sumCredits(failedCourseIds);
    const notStartedCredits = Math.max(
        requiredCredits - earnedCredits - inProgressCredits - failedCredits,
        0
    );

    const remainingCredits = Math.max(requiredCredits - earnedCredits, 0);

    const completionPercent = requiredCredits > 0
        ? round((earnedCredits / requiredCredits) * 100, 2)
        : 0;

    const heatmapSemesterMap = new Map();
    const heatmapYearMap = new Map();

    for (const [courseId, grade] of gradeByCourseId.entries()) {
        if (!isPassingGrade(grade)) continue;

        const cls = grade.class || {};
        const course = curriculumCourseMap[courseId] || enrolledCourseMap[courseId] || {};
        const credits = Number(course.credits || 0);

        if (credits <= 0) continue;

        const semesterKey = buildSemesterKeyFromClass(cls);

        if (!heatmapSemesterMap.has(semesterKey)) {
            heatmapSemesterMap.set(semesterKey, {
                key: semesterKey,
                label: buildSemesterLabelFromClass(cls),
                academicYear: cls.academicYearSnapshot || "",
                yearNumber: Number(cls.yearNumberSnapshot || 0) || null,
                termNumber: Number(cls.termNumberSnapshot || 0) || null,
                earnedCredits: 0,
                courseCount: 0,
                sort: getClassTermSortValue(cls),
            });
        }

        const semesterItem = heatmapSemesterMap.get(semesterKey);
        semesterItem.earnedCredits += credits;
        semesterItem.courseCount += 1;

        const yearNumber = Number(cls.yearNumberSnapshot || 0);
        const yearKey = yearNumber ? `year-${yearNumber}` : "year-unknown";

        if (!heatmapYearMap.has(yearKey)) {
            heatmapYearMap.set(yearKey, {
                key: yearKey,
                label: yearNumber ? `Năm ${yearNumber}` : "Chưa rõ năm",
                yearNumber: yearNumber || null,
                earnedCredits: 0,
                courseCount: 0,
                sort: yearNumber || 999,
            });
        }

        const yearItem = heatmapYearMap.get(yearKey);
        yearItem.earnedCredits += credits;
        yearItem.courseCount += 1;
    }

    const heatmapBySemester = Array.from(heatmapSemesterMap.values())
        .sort((a, b) => a.sort - b.sort)
        .map((item) => {
            const { sort, ...rest } = item;
            return rest;
        });

    const heatmapByYear = Array.from(heatmapYearMap.values())
        .sort((a, b) => a.sort - b.sort)
        .map((item) => {
            const { sort, ...rest } = item;
            return rest;
        });

    const courseDetails = [];

    for (const courseId of curriculumCourseSet) {
        const course = curriculumCourseMap[courseId] || {};

        const courseName = (course.courseName || "").toString().trim();
        const courseCode = (course.courseCode || "").toString().trim();
        const credits = Number(course.credits || 0);

        // Chặn course lỗi / course đã bị xóa / item curriculum rỗng
        if ((!courseName && !courseCode) || credits <= 0) {
            continue;
        }

        let status = "not_started";
        let statusLabel = "Chưa học";

        if (earnedCourseIds.has(courseId)) {
            status = "earned";
            statusLabel = "Đã đạt";
        } else if (inProgressCourseIds.has(courseId)) {
            status = "in_progress";
            statusLabel = "Đang học";
        } else if (failedCourseIds.has(courseId)) {
            status = "failed";
            statusLabel = "Nợ";
        }

        const grade = gradeByCourseId.get(courseId) || null;

        courseDetails.push({
            courseId,
            courseName,
            courseCode,
            credits,
            status,
            statusLabel,
            totalTen: grade ? Number(grade.totalTen || 0) : null,
            gradeStatus: grade ? (grade.status || "") : null,
        });
    }

    courseDetails.sort((a, b) => {
        if (a.status !== b.status) {
            const order = {
                earned: 1,
                in_progress: 2,
                failed: 3,
                not_started: 4,
            };

            return (order[a.status] || 99) - (order[b.status] || 99);
        }

        return a.courseCode.localeCompare(b.courseCode);
    });

    return {
        summary: {
            requiredCredits,
            earnedCredits,
            inProgressCredits,
            failedCredits,
            notStartedCredits,
            remainingCredits,
            completionPercent,
            currentRegisteredCredits: inProgressCredits,
            totalCurriculumCourses: curriculumCourseSet.size,
            earnedCourseCount: earnedCourseIds.size,
            inProgressCourseCount: inProgressCourseIds.size,
            failedCourseCount: failedCourseIds.size,
            notStartedCourseCount: notStartedCourseIds.size,
        },
        distribution: [
            {
                key: "earned",
                label: "Đã đạt",
                credits: earnedCredits,
                courseCount: earnedCourseIds.size,
            },
            {
                key: "inProgress",
                label: "Đang học",
                credits: inProgressCredits,
                courseCount: inProgressCourseIds.size,
            },
            {
                key: "failed",
                label: "Nợ",
                credits: failedCredits,
                courseCount: failedCourseIds.size,
            },
            {
                key: "notStarted",
                label: "Chưa học",
                credits: notStartedCredits,
                courseCount: notStartedCourseIds.size,
            },
        ],
        heatmapBySemester,
        heatmapByYear,
        courseDetails,
    };
}

async function getGpaProgress(studentId) {
    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const gradeSnap = await db.collection("grades")
        .where("studentId", "==", studentId)
        .get();

    const letterOrder = ["A", "B+", "B", "C+", "C", "D+", "D", "F"];

    const letterCounts = {};
    for (const letter of letterOrder) {
        letterCounts[letter] = 0;
    }

    const semesterBuckets = new Map();
    const yearBuckets = new Map();

    const gradeItems = [];

    let totalWeightedGpa = 0;
    let totalCredits = 0;
    let passedSubjects = 0;
    let failedSubjects = 0;

    for (const doc of gradeSnap.docs) {
        const grade = doc.data() || {};

        const classId = (grade.classId || "").toString();
        const cls = classMap[classId] || {};
        const course = courseMap[cls.courseId] || {};

        const credits = Number(course.credits || 0);
        const totalTen = Number(grade.totalTen || 0);
        const gpa4 = tenToFour(totalTen);
        const letterGrade = tenToLetterDetailed(totalTen);
        const status = (grade.status || passFailByTotalTen(totalTen)).toString();

        if (letterCounts[letterGrade] != null) {
            letterCounts[letterGrade] += 1;
        }

        if (status === "Pass") {
            passedSubjects += 1;
        } else {
            failedSubjects += 1;
        }

        const creditsForGpa = credits > 0 ? credits : 1;

        totalWeightedGpa += gpa4 * creditsForGpa;
        totalCredits += creditsForGpa;

        const academicYear = (cls.academicYearSnapshot || "").toString();
        const yearNumber = Number(cls.yearNumberSnapshot || 0);
        const termNumber = Number(cls.termNumberSnapshot || 0);

        const semesterKey = [
            academicYear || "unknown-year",
            `Y${yearNumber || "?"}`,
            `T${termNumber || "?"}`,
        ].join("-");

        const semesterLabel = [
            academicYear || "Chưa rõ năm học",
            yearNumber ? `Năm ${yearNumber}` : "Chưa rõ năm",
            termNumber ? `HK${termNumber}` : "Chưa rõ kỳ",
        ].join(" • ");

        if (!semesterBuckets.has(semesterKey)) {
            semesterBuckets.set(
                semesterKey,
                createWeightedBucket({
                    key: semesterKey,
                    label: semesterLabel,
                    academicYear,
                    yearNumber: yearNumber || null,
                    termNumber: termNumber || null,
                    sort: getTrendSortValue(academicYear, yearNumber, termNumber),
                })
            );
        }

        addGradeToBucket(
            semesterBuckets.get(semesterKey),
            gpa4,
            creditsForGpa
        );

        const yearKey = yearNumber ? `year-${yearNumber}` : "year-unknown";
        const yearLabel = yearNumber ? `Năm ${yearNumber}` : "Chưa rõ năm";

        if (!yearBuckets.has(yearKey)) {
            yearBuckets.set(
                yearKey,
                createWeightedBucket({
                    key: yearKey,
                    label: yearLabel,
                    yearNumber: yearNumber || null,
                    sort: yearNumber || 999,
                })
            );
        }

        addGradeToBucket(
            yearBuckets.get(yearKey),
            gpa4,
            creditsForGpa
        );

        gradeItems.push({
            id: doc.id,
            classId,
            classCode: cls.classCode || "",
            courseId: cls.courseId || "",
            courseName: course.courseName || "",
            courseCode: course.courseCode || "",
            credits,
            scoreProcess: Number(grade.scoreProcess || 0),
            scoreMid: Number(grade.scoreMid || 0),
            scoreFinal: Number(grade.scoreFinal || 0),
            totalTen,
            gpa4,
            letterGrade,
            status,
            academicYearSnapshot: academicYear,
            yearNumberSnapshot: yearNumber || null,
            termNumberSnapshot: termNumber || null,
            updatedAt: toISOStringSafe(grade.updatedAt),
        });
    }

    const currentGpa4 = totalCredits > 0
        ? round(totalWeightedGpa / totalCredits, 2)
        : 0;

    const trendBySemester = Array.from(semesterBuckets.values())
        .sort((a, b) => a.sort - b.sort)
        .map(finalizeBucket);

    const trendByYear = Array.from(yearBuckets.values())
        .sort((a, b) => a.sort - b.sort)
        .map(finalizeBucket);

    const letterDistribution = letterOrder.map((letter) => ({
        letter,
        count: letterCounts[letter] || 0,
    }));

    gradeItems.sort((a, b) => {
        const yearA = a.yearNumberSnapshot || 999;
        const yearB = b.yearNumberSnapshot || 999;
        if (yearA !== yearB) return yearA - yearB;

        const termA = a.termNumberSnapshot || 999;
        const termB = b.termNumberSnapshot || 999;
        if (termA !== termB) return termA - termB;

        return a.courseName.localeCompare(b.courseName);
    });

    return {
        summary: {
            gpa4: currentGpa4,
            maxGpa: 4,
            percent: round((currentGpa4 / 4) * 100, 2),
            totalSubjects: gradeSnap.size,
            passedSubjects,
            failedSubjects,
            totalCredits,
        },
        trendBySemester,
        trendByYear,
        letterDistribution,
        grades: gradeItems,
    };
}

async function getMyNotifications(studentId) {
    const snap = await db.collection("notifications")
        .where("receiverId", "==", studentId)
        .get();

    const items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            id: doc.id,
            receiverId: data.receiverId || "",
            receiverType: data.receiverType || "",
            title: data.title || "",
            body: data.body || "",
            isRead: data.isRead === true,
            createdAt: toISOStringSafe(data.createdAt),
        };
    });

    items.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    return items;
}

// async function getStudentHome(studentId) {
//     const student = await getStudentProfile(studentId);
//     const enrollments = await getApprovedEnrollments(studentId);

//     const classIds = enrollments.map((e) => e.classId).filter(Boolean);
//     const classMap = await getClassMapByIds(classIds);
//     const classes = Object.values(classMap);

//     const courseIds = classes.map((c) => c.courseId).filter(Boolean);
//     const courseMap = await getCourseMapByIds(courseIds);

//     let registeredCredits = 0;
//     for (const cls of classes) {
//         const course = courseMap[cls.courseId] || {};
//         registeredCredits += Number(course.credits || 0);
//     }

//     const totalMajorCredits = await getTotalMajorCredits(student.majorId);

//     const gradeSnap = await db.collection("grades")
//         .where("studentId", "==", studentId)
//         .get();

//     const grades = gradeSnap.docs.map((d) => ({
//         id: d.id,
//         ...d.data(),
//     }));

//     let totalFourWeighted = 0;
//     let totalCreditsForGpa = 0;

//     for (const g of grades) {
//         const cls = classMap[g.classId] || null;
//         if (!cls) continue;

//         const course = courseMap[cls.courseId] || {};
//         const credits = Number(course.credits || 0);
//         if (credits <= 0) continue;

//         const totalTen = Number(g.totalTen || 0);
//         const gpa4 = tenToFour(totalTen);

//         totalFourWeighted += gpa4 * credits;
//         totalCreditsForGpa += credits;
//     }

//     const gpa4 = totalCreditsForGpa > 0
//         ? round(totalFourWeighted / totalCreditsForGpa, 2)
//         : 0;

//     const todaySchedule = await getTodaySchedule(studentId);
//     const upcomingDeadlines = await getUpcomingAssignments(studentId, 5);

//     // Lấy tiến độ tín chỉ chuẩn: đã đạt / đang học / nợ / chưa học
//     const creditProgress = await getCreditProgress(studentId);
//     const creditSummary = creditProgress.summary || {};

//     return {
//         student,
//         summary: {
//             gpa4,

//             // Giữ field cũ để không vỡ app cũ
//             registeredCredits,

//             // Field mới dùng cho Home
//             earnedCredits: creditSummary.earnedCredits ?? 0,
//             inProgressCredits: creditSummary.inProgressCredits ?? 0,
//             failedCredits: creditSummary.failedCredits ?? 0,
//             notStartedCredits: creditSummary.notStartedCredits ?? 0,

//             totalMajorCredits: creditSummary.requiredCredits || totalMajorCredits,
//             approvedClassCount: classes.length,
//         },
//         todaySchedule,
//         upcomingDeadlines,
//     };
// }

function isCurrentLearningClass(cls = {}) {
    const adminState = (cls.adminState || "").toString();
    const status = (cls.status || "").toString();
    const semesterStatus = (
        cls.semesterStatus ||
        cls.cycleStatus ||
        cls.semesterCycleStatus ||
        ""
    ).toString();

    if (cls.isArchived === true) return false;
    if (cls.archived === true) return false;

    if (adminState === "archived") return false;
    if (adminState === "history") return false;
    if (adminState === "finished") return false;

    if (status === "archived") return false;
    if (status === "history") return false;
    if (status === "finished") return false;

    if (semesterStatus === "finished") return false;
    if (semesterStatus === "locked") return false;

    return true;
}

async function getStudentHome(studentId) {
    const student = await getStudentProfile(studentId);
    const enrollments = await getApprovedEnrollments(studentId);

    const classIds = enrollments.map((e) => e.classId).filter(Boolean);
    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);
    const currentClasses = classes.filter(isCurrentLearningClass);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    let registeredCredits = 0;
    for (const cls of classes) {
        const course = courseMap[cls.courseId] || {};
        registeredCredits += Number(course.credits || 0);
    }

    const gradeSnap = await db.collection("grades")
        .where("studentId", "==", studentId)
        .get();

    let totalFourWeighted = 0;
    let totalCreditsForGpa = 0;

    for (const doc of gradeSnap.docs) {
        const g = doc.data() || {};
        const cls = classMap[g.classId] || null;
        if (!cls) continue;

        const course = courseMap[cls.courseId] || {};
        const credits = Number(course.credits || 0);
        if (credits <= 0) continue;

        const totalTen = Number(g.totalTen || 0);
        const gpa4Item = tenToFour(totalTen);

        totalFourWeighted += gpa4Item * credits;
        totalCreditsForGpa += credits;
    }

    const gpa4 = totalCreditsForGpa > 0
        ? round(totalFourWeighted / totalCreditsForGpa, 2)
        : 0;

    const todaySchedule = await getTodaySchedule(studentId);
    const upcomingDeadlines = await getUpcomingAssignments(studentId, 5);

    const creditProgress = await getCreditProgress(studentId);
    const creditSummary = creditProgress.summary || {};

    return {
        student,
        summary: {
            gpa4,
            registeredCredits,

            earnedCredits: creditSummary.earnedCredits ?? 0,
            inProgressCredits: creditSummary.inProgressCredits ?? 0,
            failedCredits: creditSummary.failedCredits ?? 0,
            notStartedCredits: creditSummary.notStartedCredits ?? 0,

            totalMajorCredits: creditSummary.requiredCredits ?? 0,
            approvedClassCount: currentClasses.length,
            historyClassCount: classes.length - currentClasses.length,
        },
        todaySchedule,
        upcomingDeadlines,
    };
}

async function getWeeklySchedule(studentId, dateText = null) {
    const baseDate = dateText ? new Date(dateText) : new Date();
    const weekStart = getWeekStart(baseDate);
    const weekDates = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const semesterIds = classes.map((c) => c.semesterId).filter(Boolean);
    const semesterTimelineMap = await getSemesterTimelineMapByIds(semesterIds);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const examMap = await getExamSchedulesByCourseIds(courseIds);

    const days = weekDates.map((date) => {
        const systemDay = toSystemDayOfWeek(date);

        const lessons = classes.flatMap((cls) => {
            const schedule = Array.isArray(cls.schedule) ? cls.schedule : [];
            const course = courseMap[cls.courseId] || {};
            const semesterTimeline = semesterTimelineMap[cls.semesterId] || null;

            if (!isDateWithinStudyTimeline(date, semesterTimeline)) {
                return [];
            }

            return schedule
                .filter((s) => Number(s.dayOfWeek) === systemDay)
                .map((s) => ({
                    classId: cls.id,
                    classCode: cls.classCode || "",
                    courseId: cls.courseId || "",
                    courseName: course.courseName || "",
                    courseCode: course.courseCode || "",
                    credits: Number(course.credits || 0),
                    room: cls.room || "",
                    teacherId: cls.teacherId || "",
                    startTime: s.startTime || "",
                    endTime: s.endTime || "",
                    startPeriod: s.startPeriod ?? "",
                    endPeriod: s.endPeriod ?? "",
                    dayOfWeek: Number(s.dayOfWeek),
                    date: date.toISOString(),
                    semesterId: cls.semesterId || "",
                    semesterTimeline,
                }));
        });

        lessons.sort((a, b) => a.startTime.localeCompare(b.startTime));

        const exams = classes.flatMap((cls) => {
            const course = courseMap[cls.courseId] || {};
            const courseExams = examMap[cls.courseId] || [];

            return courseExams
                .filter((exam) => {
                    if (exam.semesterId && cls.semesterId) {
                        return exam.semesterId === cls.semesterId &&
                            isSameLocalDate(exam.examDate, date);
                    }

                    return isSameLocalDate(exam.examDate, date);
                })
                .map((exam) => ({
                    ...exam,
                    classId: cls.id,
                    classCode: cls.classCode || "",
                    courseName: course.courseName || "",
                    courseCode: course.courseCode || "",
                    credits: Number(course.credits || 0),
                    room: exam.examRoom || "",
                    date: exam.examDate,
                }));
        });

        exams.sort((a, b) => new Date(a.examDate || 0) - new Date(b.examDate || 0));

        return {
            date: date.toISOString(),
            dayOfWeek: systemDay,
            lessons,
            exams,
        };
    });

    return {
        weekStart: weekStart.toISOString(),
        weekEnd: addDays(weekStart, 6).toISOString(),
        today: new Date().toISOString(),
        days,
    };
}

async function getMonthlySchedule(studentId, monthText = null) {
    const now = new Date();

    let year = now.getFullYear();
    let month = now.getMonth() + 1;

    if (monthText && /^\d{4}-\d{2}$/.test(monthText)) {
        const parts = monthText.split("-");
        year = Number(parts[0]);
        month = Number(parts[1]);
    }

    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);

    const enrollments = await getApprovedEnrollments(studentId);
    const classIds = enrollments.map((e) => e.classId).filter(Boolean);

    const classMap = await getClassMapByIds(classIds);
    const classes = Object.values(classMap);

    const courseIds = classes.map((c) => c.courseId).filter(Boolean);
    const courseMap = await getCourseMapByIds(courseIds);

    const examMap = await getExamSchedulesByCourseIds(courseIds);

    const semesterIds = classes.map((c) => c.semesterId).filter(Boolean);
    const semesterTimelineMap = await getSemesterTimelineMapByIds(semesterIds);

    const days = [];

    for (let day = 1; day <= lastDay.getDate(); day++) {
        const date = new Date(year, month - 1, day);
        const systemDay = toSystemDayOfWeek(date);

        const lessons = classes.flatMap((cls) => {
            const schedule = Array.isArray(cls.schedule) ? cls.schedule : [];
            const course = courseMap[cls.courseId] || {};
            const semesterTimeline = semesterTimelineMap[cls.semesterId] || null;

            if (!isDateWithinStudyTimeline(date, semesterTimeline)) {
                return [];
            }

            return schedule
                .filter((s) => Number(s.dayOfWeek) === systemDay)
                .map((s) => ({
                    classId: cls.id,
                    classCode: cls.classCode || "",
                    courseId: cls.courseId || "",
                    courseName: course.courseName || "",
                    courseCode: course.courseCode || "",
                    credits: Number(course.credits || 0),
                    room: cls.room || "",
                    teacherId: cls.teacherId || "",
                    startTime: s.startTime || "",
                    endTime: s.endTime || "",
                    startPeriod: s.startPeriod ?? "",
                    endPeriod: s.endPeriod ?? "",
                    dayOfWeek: Number(s.dayOfWeek),
                    date: date.toISOString(),
                    semesterId: cls.semesterId || "",
                    semesterTimeline,
                }));
        });

        lessons.sort((a, b) => a.startTime.localeCompare(b.startTime));

        const exams = classes.flatMap((cls) => {
            const course = courseMap[cls.courseId] || {};
            const courseExams = examMap[cls.courseId] || [];

            return courseExams
                .filter((exam) => {
                    if (exam.semesterId && cls.semesterId) {
                        return exam.semesterId === cls.semesterId &&
                            isSameLocalDate(exam.examDate, date);
                    }

                    return isSameLocalDate(exam.examDate, date);
                })
                .map((exam) => ({
                    ...exam,
                    classId: cls.id,
                    classCode: cls.classCode || "",
                    courseName: course.courseName || "",
                    courseCode: course.courseCode || "",
                    credits: Number(course.credits || 0),
                    room: exam.examRoom || "",
                    date: exam.examDate,
                }));
        });

        exams.sort((a, b) => new Date(a.examDate || 0) - new Date(b.examDate || 0));

        days.push({
            date: date.toISOString(),
            dayOfWeek: systemDay,
            lessons,
            exams,
        });
    }

    return {
        month: `${year}-${String(month).padStart(2, "0")}`,
        firstDay: firstDay.toISOString(),
        lastDay: lastDay.toISOString(),
        days,
    };
}

module.exports = {
    getStudentHome,
    getMyClasses,
    getTodaySchedule,
    getUpcomingAssignments,
    getMyGrades,
    getCreditProgress,
    getGpaProgress,
    getMyNotifications,
    getWeeklySchedule,
    getMonthlySchedule,
};