const { db } = require("../config/firebase");
const classChatSyncService = require("./class_chat_sync.service");

async function createEnrollmentPending({ classId, studentId }) {
    // tránh join trùng
    const exist = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("studentId", "==", studentId)
        .limit(1).get();

    if (!exist.empty) {
        const ex = exist.docs[0];
        return { id: ex.id, status: ex.data().status, already: true };
    }

    const docRef = await db.collection("enrollments").add({
        classId,
        studentId,
        status: "pending",
        enrollDate: new Date(),
    });
    return { id: docRef.id, status: "pending" };
}

async function approveEnrollment(enrollmentId) {
    const ref = db.collection("enrollments").doc(enrollmentId);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Enrollment not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.update({
        status: "approved",
        approvedAt: new Date(),
    });

    const after = await ref.get();
    const enrollment = after.data() || {};

    const classId = (enrollment.classId || "").toString();
    if (classId) {
        await classChatSyncService.syncClassChatMembers(classId);
    }

    return { id: enrollmentId, status: "approved" };
}

async function addStudentToClassByAdmin({ classId, studentId, adminUid }) {
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};

    const siblingClassesSnap = await db.collection("classes")
        .where("courseId", "==", cls.courseId)
        .where("semesterId", "==", cls.semesterId)
        .get();

    const siblingClassIds = siblingClassesSnap.docs.map((d) => d.id);

    for (const siblingClassId of siblingClassIds) {
        const enrollmentSnap = await db.collection("enrollments")
            .where("classId", "==", siblingClassId)
            .where("studentId", "==", studentId)
            .limit(1)
            .get();

        if (!enrollmentSnap.empty) {
            const existed = enrollmentSnap.docs[0].data() || {};
            const existedStatus = (existed.status || "").toString();

            if (existedStatus === "approved" || existedStatus === "pending") {
                const err = new Error(
                    "Sinh viên đã đăng ký hoặc đã có ở lớp khác của cùng môn học trong học kỳ này"
                );
                err.statusCode = 409;
                throw err;
            }
        }
    }

    if ((cls.adminState || "draft") === "archived") {
        const err = new Error("Archived class cannot accept students");
        err.statusCode = 409;
        throw err;
    }

    const semesterStatus = await getSemesterCycleStatus(cls.semesterId);
    if (!["registration_open", "studying"].includes(semesterStatus)) {
        const err = new Error(
            "Chỉ được thêm sinh viên khi học kỳ đang mở đăng ký hoặc đang học"
        );
        err.statusCode = 409;
        throw err;
    }

    const courseRef = db.collection("courses").doc(cls.courseId);
    const courseSnap = await courseRef.get();

    if (!courseSnap.exists) {
        const err = new Error("Course not found");
        err.statusCode = 404;
        throw err;
    }

    const course = courseSnap.data() || {};
    const classMajorId = (course.majorId || "").toString();

    const userRef = db.collection("users").doc(studentId);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
        const err = new Error("Student not found");
        err.statusCode = 404;
        throw err;
    }

    const user = userSnap.data() || {};

    if (user.role !== "student") {
        const err = new Error("User is not a student");
        err.statusCode = 409;
        throw err;
    }

    const studentMajorId = (
        user.studentInfo?.majorId ||
        user.majorId ||
        ""
    ).toString();

    const studentYear = Number(user.studentInfo?.year || 0);
    const requiredYear = Number(cls.yearNumberSnapshot || 0);

    if (!studentYear) {
        const err = new Error("Student year is missing");
        err.statusCode = 409;
        throw err;
    }

    if (!requiredYear) {
        const err = new Error("Class year requirement is missing");
        err.statusCode = 409;
        throw err;
    }

    if (studentYear < requiredYear) {
        const err = new Error(
            `Sinh viên chưa đủ năm đào tạo để vào lớp này. Yêu cầu năm ${requiredYear}, hiện tại sinh viên năm ${studentYear}`
        );
        err.statusCode = 409;
        throw err;
    }

    if (!studentMajorId) {
        const err = new Error("Student major is missing");
        err.statusCode = 409;
        throw err;
    }

    if (classMajorId !== studentMajorId) {
        const err = new Error("Sinh viên không cùng chuyên ngành với lớp học");
        err.statusCode = 409;
        throw err;
    }

    const approvedSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("status", "==", "approved")
        .get();

    const approvedCount = approvedSnap.size;
    const maxStudents = Number(cls.maxStudents || 0);

    const existSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

    if (!existSnap.empty) {
        const doc = existSnap.docs[0];
        const exist = doc.data() || {};

        if (exist.status === "approved") {
            return {
                id: doc.id,
                status: "approved",
                already: true,
            };
        }

        if (approvedCount >= maxStudents) {
            const err = new Error("Class is full");
            err.statusCode = 409;
            throw err;
        }

        await db.collection("enrollments").doc(doc.id).update({
            status: "approved",
            approvedAt: new Date(),
            approvedBy: adminUid,
            updatedAt: new Date(),
            source: "admin_manual",
        });

        await classChatSyncService.syncClassChatMembers(classId);

        return {
            id: doc.id,
            status: "approved",
            already: false,
            upgradedFromPending: true,
        };
    }

    if (approvedCount >= maxStudents) {
        const err = new Error("Class is full");
        err.statusCode = 409;
        throw err;
    }

    const docRef = await db.collection("enrollments").add({
        classId,
        studentId,
        status: "approved",
        enrollDate: new Date(),
        approvedAt: new Date(),
        approvedBy: adminUid,
        source: "admin_manual",
    });

    await classChatSyncService.syncClassChatMembers(classId);

    return {
        id: docRef.id,
        status: "approved",
        already: false,
    };
}

async function listEnrollments(query) {
    let ref = db.collection("enrollments");
    if (query.classId) ref = ref.where("classId", "==", query.classId);
    if (query.studentId) ref = ref.where("studentId", "==", query.studentId);
    if (query.status) ref = ref.where("status", "==", query.status);
    const snap = await ref.get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function listAvailableStudentsForClass({ classId, q = "" }) {
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};

    const courseRef = db.collection("courses").doc(cls.courseId);
    const courseSnap = await courseRef.get();

    if (!courseSnap.exists) {
        const err = new Error("Course not found");
        err.statusCode = 404;
        throw err;
    }

    const course = courseSnap.data() || {};
    const classMajorId = (course.majorId || "").toString();
    const requiredYear = Number(cls.yearNumberSnapshot || 0);
    const keyword = (q || "").trim().toLowerCase();

    // Lấy toàn bộ sinh viên
    const usersSnap = await db.collection("users")
        .where("role", "==", "student")
        .get();

    let students = usersSnap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            uid: doc.id,
            fullName: data.fullName || "",
            email: data.email || "",
            department: data.department || "",
            majorId: data.majorId || "",
            studentInfo: data.studentInfo || null,
            isActive: data.isActive !== false,
        };
    });

    // Lọc theo chuyên ngành
    students = students.filter((u) => {
        const userMajorId = (
            u.majorId ||
            u.studentInfo?.majorId ||
            ""
        ).toString();

        return userMajorId === classMajorId;
    });

    // Lọc theo năm đào tạo
    students = students.filter((u) => {
        const studentYear = Number(u.studentInfo?.year || 0);
        return studentYear >= requiredYear;
    });

    // Lọc theo từ khóa tìm kiếm
    if (keyword) {
        students = students.filter((u) => {
            const studentCode = (u.studentInfo?.studentCode || "")
                .toString()
                .toLowerCase();

            return (
                (u.fullName || "").toLowerCase().includes(keyword) ||
                (u.email || "").toLowerCase().includes(keyword) ||
                studentCode.includes(keyword)
            );
        });
    }

    // Lấy toàn bộ lớp cùng môn + cùng học kỳ
    const siblingClassesSnap = await db.collection("classes")
        .where("courseId", "==", cls.courseId)
        .where("semesterId", "==", cls.semesterId)
        .get();

    const siblingClassIds = siblingClassesSnap.docs.map((d) => d.id);

    // Loại sinh viên đã pending/approved ở bất kỳ lớp nào trong nhóm
    const occupiedStudentIds = new Set();

    for (const siblingClassId of siblingClassIds) {
        const enrollmentsSnap = await db.collection("enrollments")
            .where("classId", "==", siblingClassId)
            .get();

        for (const doc of enrollmentsSnap.docs) {
            const e = doc.data() || {};
            const status = (e.status || "").toString();
            const studentId = (e.studentId || "").toString();

            if (
                studentId &&
                (status === "approved" || status === "pending")
            ) {
                occupiedStudentIds.add(studentId);
            }
        }
    }

    students = students.filter((u) => !occupiedStudentIds.has(u.uid));

    students.sort((a, b) => {
        const nameA = (a.fullName || "").toLowerCase();
        const nameB = (b.fullName || "").toLowerCase();
        return nameA.localeCompare(nameB);
    });

    return students;
}

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

async function getSemesterCycleStatus(semesterId) {
    const cycleRef = db.collection("semester_cycles").doc(semesterId);
    const cycleSnap = await cycleRef.get();

    if (!cycleSnap.exists) {
        const err = new Error("Semester cycle not found");
        err.statusCode = 404;
        throw err;
    }

    const cycle = cycleSnap.data() || {};
    const now = new Date();
    const academicStartYear = getAcademicStartYear(now);

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

    if (cycle.isActive === false) return "inactive";
    if (cycle.isManualLocked === true) return "locked";
    if (now < registrationOpenAt) return "upcoming";
    if (now <= registrationCloseAt) return "registration_open";
    if (now < studyStartAt) return "registration_closed";
    if (now <= studyEndAt) return "studying";
    return "finished";
}

async function removeStudentFromClassByAdmin({ classId, studentId }) {
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const enrollmentSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

    if (enrollmentSnap.empty) {
        const err = new Error("Student is not in this class");
        err.statusCode = 404;
        throw err;
    }

    const batch = db.batch();

    // Xóa enrollment
    const enrollmentDoc = enrollmentSnap.docs[0];
    batch.delete(enrollmentDoc.ref);

    // Xóa grade nếu có
    const gradeSnap = await db.collection("grades")
        .where("classId", "==", classId)
        .where("studentId", "==", studentId)
        .get();

    for (const doc of gradeSnap.docs) {
        batch.delete(doc.ref);
    }

    await batch.commit();

    await classChatSyncService.syncClassChatMembers(classId);

    return {
        classId,
        studentId,
        deletedEnrollment: true,
        deletedGrades: gradeSnap.size,
    };
}

async function listEnrollmentUsersByClass({ classId, status }) {
    let ref = db.collection("enrollments").where("classId", "==", classId);

    if (status) {
        ref = ref.where("status", "==", status);
    }

    const snap = await ref.get();
    const items = [];

    for (const doc of snap.docs) {
        const enrollment = doc.data() || {};
        const studentId = (enrollment.studentId || "").toString();

        let user = null;

        if (studentId) {
            const userSnap = await db.collection("users").doc(studentId).get();
            if (userSnap.exists) {
                const u = userSnap.data() || {};
                user = {
                    uid: userSnap.id,
                    fullName: u.fullName || "",
                    email: u.email || "",
                    avatarUrl: u.avatarUrl || "",
                    role: u.role || "",
                    majorId: u.majorId || "",
                    studentInfo: u.studentInfo || null,
                    isActive: u.isActive !== false,
                };
            }
        }

        items.push({
            id: doc.id,
            classId: enrollment.classId || "",
            studentId: enrollment.studentId || "",
            status: enrollment.status || "",
            enrollDate: enrollment.enrollDate || null,
            approvedAt: enrollment.approvedAt || null,
            approvedBy: enrollment.approvedBy || null,
            user,
        });
    }

    return items;
}

module.exports = {
    createEnrollmentPending,
    approveEnrollment,
    addStudentToClassByAdmin,
    removeStudentFromClassByAdmin,
    listAvailableStudentsForClass,
    listEnrollments,
    listEnrollmentUsersByClass,
};