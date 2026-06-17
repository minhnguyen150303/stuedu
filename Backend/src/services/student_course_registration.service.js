const { db } = require("../config/firebase");
const classChatSyncService = require("./class_chat_sync.service");

function buildUtcDate(year, month, day, isEndOfDay = false) {
    if (isEndOfDay) {
        return new Date(Date.UTC(year, month - 1, day, 23, 59, 59));
    }
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0));
}

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    return month >= 7 ? academicStartYear : academicStartYear + 1;
}

function resolveCycleTimeline(cycle, academicStartYear) {
    const registrationOpenAt = buildUtcDate(
        getDateYearForAcademicCycle(cycle.registrationOpenMonth, academicStartYear),
        cycle.registrationOpenMonth,
        cycle.registrationOpenDay
    );

    const registrationCloseAt = buildUtcDate(
        getDateYearForAcademicCycle(cycle.registrationCloseMonth, academicStartYear),
        cycle.registrationCloseMonth,
        cycle.registrationCloseDay,
        true
    );

    const studyStartAt = buildUtcDate(
        getDateYearForAcademicCycle(cycle.studyStartMonth, academicStartYear),
        cycle.studyStartMonth,
        cycle.studyStartDay
    );

    const studyEndAt = buildUtcDate(
        getDateYearForAcademicCycle(cycle.studyEndMonth, academicStartYear),
        cycle.studyEndMonth,
        cycle.studyEndDay,
        true
    );

    return {
        registrationOpenAt,
        registrationCloseAt,
        studyStartAt,
        studyEndAt,
    };
}

function getSemesterCycleStatus(cycle) {
    const now = new Date();
    const academicStartYear = getAcademicStartYear(now);
    const timeline = resolveCycleTimeline(cycle, academicStartYear);

    if (cycle.isActive === false) return "inactive";
    if (cycle.isManualLocked === true) return "locked";
    if (now < timeline.registrationOpenAt) return "upcoming";
    if (now <= timeline.registrationCloseAt) return "registration_open";
    if (now < timeline.studyStartAt) return "registration_closed";
    if (now <= timeline.studyEndAt) return "studying";
    return "finished";
}

function getStatusMessage(status) {
    if (status === "studying") {
        return "Đang trong thời gian học, chưa phải thời gian đăng ký tín chỉ";
    }

    if (["upcoming", "registration_closed", "finished", "inactive", "locked"].includes(status)) {
        return "Chưa đến thời gian đăng ký tín chỉ";
    }

    return "Đang mở đăng ký tín chỉ";
}

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

async function getStudentProfile(studentId) {
    const snap = await db.collection("users").doc(studentId).get();

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
        data.studentInfo?.majorId ||
        data.majorId ||
        ""
    ).toString();

    const year = Number(data.studentInfo?.year || 0);

    return {
        uid: snap.id,
        fullName: data.fullName || "",
        email: data.email || "",
        majorId,
        studentYear: year,
    };
}

async function getCurrentCycleForMajor(majorId) {
    const snap = await db.collection("semester_cycles")
        .where("majorId", "==", majorId)
        .get();

    if (snap.empty) {
        return null;
    }

    const items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        const status = getSemesterCycleStatus(data);

        return {
            id: doc.id,
            ...data,
            status,
        };
    });

    const current = items.find((x) => x.status === "registration_open");
    if (current) return current;

    const studying = items.find((x) => x.status === "studying");
    if (studying) return studying;

    const upcoming = items.find((x) => x.status === "upcoming");
    if (upcoming) return upcoming;

    const registrationClosed = items.find((x) => x.status === "registration_closed");
    if (registrationClosed) return registrationClosed;

    const finished = items.find((x) => x.status === "finished");
    if (finished) return finished;

    return items[0] || null;
}

async function getPassedCourseIds(studentId) {
    const snap = await db.collection("grades")
        .where("studentId", "==", studentId)
        .get();

    const classIds = snap.docs.map((d) => (d.data()?.classId || "").toString()).filter(Boolean);

    const classMap = {};
    for (const classId of classIds) {
        if (classMap[classId]) continue;
        const classSnap = await db.collection("classes").doc(classId).get();
        if (classSnap.exists) {
            classMap[classId] = classSnap.data() || {};
        }
    }

    const passedCourseIds = new Set();

    for (const doc of snap.docs) {
        const grade = doc.data() || {};
        if ((grade.status || "").toString() !== "Pass") continue;

        const cls = classMap[(grade.classId || "").toString()] || {};
        const courseId = (cls.courseId || "").toString();
        if (courseId) {
            passedCourseIds.add(courseId);
        }
    }

    return passedCourseIds;
}

async function getStudentEnrollmentsInSemester(studentId, semesterId) {
    const enrollmentSnap = await db.collection("enrollments")
        .where("studentId", "==", studentId)
        .get();

    const results = [];

    for (const doc of enrollmentSnap.docs) {
        const e = doc.data() || {};
        const classId = (e.classId || "").toString();
        if (!classId) continue;

        const classSnap = await db.collection("classes").doc(classId).get();
        if (!classSnap.exists) continue;

        const cls = classSnap.data() || {};
        if ((cls.semesterId || "").toString() !== semesterId) continue;

        results.push({
            id: doc.id,
            classId,
            courseId: (cls.courseId || "").toString(),
            status: (e.status || "").toString(),
        });
    }

    return results;
}

async function getEnrollmentCountMapByClassIds(classIds = []) {
    const uniqueClassIds = [...new Set(classIds.filter(Boolean))];
    const result = {};

    for (const classId of uniqueClassIds) {
        const snap = await db.collection("enrollments")
            .where("classId", "==", classId)
            .get();

        let approvedCount = 0;
        let pendingCount = 0;

        for (const doc of snap.docs) {
            const status = (doc.data()?.status || "").toString();

            if (status === "approved") {
                approvedCount += 1;
            } else if (status === "pending") {
                pendingCount += 1;
            }
        }

        result[classId] = {
            approvedCount,
            pendingCount,
            registeredCount: approvedCount + pendingCount,
        };
    }

    return result;
}

async function listStudentCourseRegistration(studentId) {
    const student = await getStudentProfile(studentId);

    if (!student.majorId) {
        const err = new Error("Student major is missing");
        err.statusCode = 409;
        throw err;
    }

    if (!student.studentYear) {
        const err = new Error("Student year is missing");
        err.statusCode = 409;
        throw err;
    }

    const cycle = await getCurrentCycleForMajor(student.majorId);

    if (!cycle) {
        return {
            registrationEnabled: false,
            semesterStatus: "unavailable",
            message: "Chưa có học kỳ nào khả dụng",
            studentYear: student.studentYear,
            availableYears: [],
            selectedSemester: null,
            items: [],
        };
    }

    const semesterStatus = cycle.status;
    const message = getStatusMessage(semesterStatus);
    const registrationEnabled = semesterStatus === "registration_open";

    const availableYears = [1, 2, 3, 4, 5];

    const selectedSemester = {
        semesterId: cycle.id,
        yearNumber: Number(cycle.yearNumber || 0),
        termNumber: Number(cycle.termNumber || 0),
        status: semesterStatus,
    };

    if (!registrationEnabled) {
        return {
            registrationEnabled: false,
            semesterStatus,
            message,
            studentYear: student.studentYear,
            availableYears,
            selectedSemester,
            items: [],
        };
    }

    const curriculumSnap = await db.collection("curriculum")
        .where("majorId", "==", student.majorId)
        .where("semesterId", "==", cycle.id)
        .get();

    const curriculumItems = curriculumSnap.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() || {}),
    })).filter((x) => x.isVisible !== false);

    const passedCourseIds = await getPassedCourseIds(studentId);
    const enrollments = await getStudentEnrollmentsInSemester(studentId, cycle.id);

    const courseMap = {};
    const classBuckets = {};

    for (const item of curriculumItems) {
        const courseId = (item.courseId || "").toString();
        if (!courseId) continue;

        if (!courseMap[courseId]) {
            const courseSnap = await db.collection("courses").doc(courseId).get();
            if (courseSnap.exists) {
                courseMap[courseId] = {
                    id: courseSnap.id,
                    ...(courseSnap.data() || {}),
                };
            }
        }
    }

    const classSnap = await db.collection("classes")
        .where("semesterId", "==", cycle.id)
        .where("isVisibleForRegistration", "==", true)
        .get();

    const visibleClassDocs = classSnap.docs.filter((doc) => {
        const cls = doc.data() || {};
        const courseId = (cls.courseId || "").toString();
        const yearNumberSnapshot = Number(cls.yearNumberSnapshot || 0);
        const adminState = (cls.adminState || "draft").toString();

        if (!courseId) return false;
        if (adminState === "archived") return false;
        if (yearNumberSnapshot > student.studentYear) return false;

        return true;
    });

    const enrollmentCountMap = await getEnrollmentCountMapByClassIds(
        visibleClassDocs.map((doc) => doc.id)
    );

    for (const doc of visibleClassDocs) {
        const cls = doc.data() || {};
        const courseId = (cls.courseId || "").toString();
        const yearNumberSnapshot = Number(cls.yearNumberSnapshot || 0);
        const maxStudents = Number(cls.maxStudents || 0);

        const counts = enrollmentCountMap[doc.id] || {
            approvedCount: 0,
            pendingCount: 0,
            registeredCount: 0,
        };

        if (!classBuckets[courseId]) classBuckets[courseId] = [];
        classBuckets[courseId].push({
            id: doc.id,
            courseId,
            classCode: cls.classCode || "",
            room: cls.room || "",
            schedule: Array.isArray(cls.schedule) ? cls.schedule : [],

            maxStudents,
            approvedCount: counts.approvedCount,
            pendingCount: counts.pendingCount,
            registeredCount: counts.registeredCount,

            // đặt thêm nhiều tên field để Flutter dễ đọc, tránh lỗi lệch tên
            enrolledCount: counts.approvedCount,
            currentStudents: counts.approvedCount,
            availableSlots: Math.max(maxStudents - counts.approvedCount, 0),

            yearNumber: yearNumberSnapshot,
            termNumber: Number(cls.termNumberSnapshot || 0),
            adminState: (cls.adminState || "draft").toString(),
        });
    }

    const items = Object.keys(courseMap).map((courseId) => {
        const course = courseMap[courseId] || {};
        const courseYear = Number(cycle.yearNumber || 0);
        const completed = passedCourseIds.has(courseId);

        const enrollmentForCourse = enrollments.find((e) => e.courseId === courseId);
        const enrolledStatus = enrollmentForCourse?.status || null;

        const classes = (classBuckets[courseId] || []).map((cls) => ({
            ...cls,
            alreadyEnrolled:
                enrollmentForCourse != null &&
                enrollmentForCourse.classId === cls.id &&
                ["pending", "approved"].includes(enrolledStatus || ""),
        }));

        classes.sort((a, b) => {
            return (a.classCode || "")
                .toString()
                .localeCompare((b.classCode || "").toString());
        });

        return {
            courseId,
            courseCode: course.courseCode || "",
            courseName: course.courseName || "",
            description: course.description || "",
            credits: Number(course.credits || 0),
            majorId: course.majorId || student.majorId,
            suggestedYear: courseYear,
            completed,
            completedLabel: completed ? "Đã học xong" : null,
            enrolledStatus,
            canRegister: !completed && !["pending", "approved"].includes(enrolledStatus || ""),
            classes,
        };
    }).filter((x) => x.suggestedYear <= student.studentYear);

    items.sort((a, b) => {
        if (a.suggestedYear !== b.suggestedYear) return a.suggestedYear - b.suggestedYear;
        return a.courseCode.localeCompare(b.courseCode);
    });

    return {
        registrationEnabled: true,
        semesterStatus,
        message,
        studentYear: student.studentYear,
        availableYears,
        selectedSemester,
        items,
    };
}

async function registerStudentToClass(studentId, classId) {
    const student = await getStudentProfile(studentId);

    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};

    if ((cls.adminState || "draft").toString() === "archived") {
        const err = new Error("Lớp đã lưu trữ, không thể đăng ký");
        err.statusCode = 409;
        throw err;
    }

    if (cls.isVisibleForRegistration === false) {
        const err = new Error("Lớp hiện không mở cho đăng ký");
        err.statusCode = 409;
        throw err;
    }

    const cycleSnap = await db.collection("semester_cycles")
        .doc((cls.semesterId || "").toString())
        .get();

    if (!cycleSnap.exists) {
        const err = new Error("Semester cycle not found");
        err.statusCode = 404;
        throw err;
    }

    const cycle = cycleSnap.data() || {};
    const status = getSemesterCycleStatus(cycle);

    if (status !== "registration_open") {
        const err = new Error(getStatusMessage(status));
        err.statusCode = 409;
        throw err;
    }

    const courseSnap = await db.collection("courses")
        .doc((cls.courseId || "").toString())
        .get();

    if (!courseSnap.exists) {
        const err = new Error("Course not found");
        err.statusCode = 404;
        throw err;
    }

    const course = courseSnap.data() || {};
    const classMajorId = (course.majorId || "").toString();

    if ((student.majorId || "").toString() !== classMajorId) {
        const err = new Error("Sinh viên không cùng chuyên ngành với lớp học");
        err.statusCode = 409;
        throw err;
    }

    const requiredYear = Number(cls.yearNumberSnapshot || 0);
    if (student.studentYear < requiredYear) {
        const err = new Error(
            `Sinh viên chưa đủ năm đào tạo để đăng ký lớp này. Yêu cầu năm ${requiredYear}, hiện tại sinh viên năm ${student.studentYear}`
        );
        err.statusCode = 409;
        throw err;
    }

    const passedCourseIds = await getPassedCourseIds(studentId);
    if (passedCourseIds.has((cls.courseId || "").toString())) {
        const err = new Error("Môn học này sinh viên đã học xong");
        err.statusCode = 409;
        throw err;
    }

    const siblingClassesSnap = await db.collection("classes")
        .where("courseId", "==", (cls.courseId || "").toString())
        .where("semesterId", "==", (cls.semesterId || "").toString())
        .get();

    const siblingClassIds = siblingClassesSnap.docs.map((d) => d.id);

    let existingEnrollmentDoc = null;

    for (const siblingClassId of siblingClassIds) {
        const enrollmentSnap = await db.collection("enrollments")
            .where("classId", "==", siblingClassId)
            .where("studentId", "==", studentId)
            .limit(1)
            .get();

        if (enrollmentSnap.empty) continue;

        const doc = enrollmentSnap.docs[0];
        const existed = doc.data() || {};
        const existedStatus = (existed.status || "").toString();

        if (!["approved", "pending"].includes(existedStatus)) {
            continue;
        }

        if (siblingClassId === classId) {
            return {
                id: doc.id,
                status: "approved",
                already: true,
            };
        }

        existingEnrollmentDoc = doc;
        break;
    }

    const approvedSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("status", "==", "approved")
        .get();

    const approvedCount = approvedSnap.size;
    const maxStudents = Number(cls.maxStudents || 0);

    if (approvedCount >= maxStudents) {
        const err = new Error("Lớp đã đủ sĩ số");
        err.statusCode = 409;
        throw err;
    }

    let oldClassId = null;

    if (existingEnrollmentDoc) {
        const oldData = existingEnrollmentDoc.data() || {};
        oldClassId = (oldData.classId || "").toString();

        await existingEnrollmentDoc.ref.delete();
    }

    const docRef = await db.collection("enrollments").add({
        classId,
        studentId,
        status: "approved",
        enrollDate: new Date(),
        approvedAt: new Date(),
        source: "student_self_register",
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    await classChatSyncService.syncClassChatMembers(classId);

    if (oldClassId && oldClassId !== classId) {
        await classChatSyncService.syncClassChatMembers(oldClassId);
    }

    return {
        id: docRef.id,
        status: "approved",
        already: false,
    };
}

module.exports = {
    listStudentCourseRegistration,
    registerStudentToClass,
};