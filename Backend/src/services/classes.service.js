const { db } = require("../config/firebase");

const EDITABLE_ADMIN_STATE = ["draft"];
const ACTIVE_FOR_CONFLICT_ADMIN_STATE = ["draft", "active"];

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
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

function resolveCycleTimeline(cycle, academicStartYear) {
    const registrationOpenYear = getDateYearForAcademicCycle(
        cycle.registrationOpenMonth,
        academicStartYear
    );

    const registrationCloseYear = getDateYearForAcademicCycle(
        cycle.registrationCloseMonth,
        academicStartYear
    );

    const studyStartYear = getDateYearForAcademicCycle(
        cycle.studyStartMonth,
        academicStartYear
    );

    const studyEndYear = getDateYearForAcademicCycle(
        cycle.studyEndMonth,
        academicStartYear
    );

    return {
        registrationOpenAt: buildUtcDate(
            registrationOpenYear,
            cycle.registrationOpenMonth,
            cycle.registrationOpenDay
        ),
        registrationCloseAt: buildUtcDate(
            registrationCloseYear,
            cycle.registrationCloseMonth,
            cycle.registrationCloseDay,
            true
        ),
        studyStartAt: buildUtcDate(
            studyStartYear,
            cycle.studyStartMonth,
            cycle.studyStartDay
        ),
        studyEndAt: buildUtcDate(
            studyEndYear,
            cycle.studyEndMonth,
            cycle.studyEndDay,
            true
        ),
    };
}

async function getSemesterTimeline(semesterId) {
    if (!semesterId) return null;

    const ref = db.collection("semester_cycles").doc(semesterId);
    const snap = await ref.get();

    if (!snap.exists) return null;

    const cycle = snap.data() || {};
    const academicStartYear = getAcademicStartYear();
    const timeline = resolveCycleTimeline(cycle, academicStartYear);

    return {
        registrationOpenAt: timeline.registrationOpenAt.toISOString(),
        registrationCloseAt: timeline.registrationCloseAt.toISOString(),
        studyStartAt: timeline.studyStartAt.toISOString(),
        studyEndAt: timeline.studyEndAt.toISOString(),
    };
}

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") {
        return value.toDate().toISOString();
    }
    if (value instanceof Date) {
        return value.toISOString();
    }
    return value;
}

function toMinutes(hhmm) {
    const [h, m] = String(hhmm).split(":").map(Number);
    return h * 60 + m;
}

function timeRangesOverlap(startA, endA, startB, endB) {
    return toMinutes(startA) < toMinutes(endB) &&
        toMinutes(startB) < toMinutes(endA);
}

function schedulesOverlap(scheduleA = [], scheduleB = []) {
    for (const a of scheduleA) {
        for (const b of scheduleB) {
            if (
                Number(a.dayOfWeek) === Number(b.dayOfWeek) &&
                timeRangesOverlap(a.startTime, a.endTime, b.startTime, b.endTime)
            ) {
                return true;
            }
        }
    }
    return false;
}

async function mapClassDoc(doc) {
    const data = doc.data() || {};
    const semesterTimeline = await getSemesterTimeline(data.semesterId || "");

    return {
        id: doc.id,
        lifecycleId: data.lifecycleId || null,
        courseId: data.courseId || "",
        semesterId: data.semesterId || "",
        teacherId: data.teacherId || "",
        classCode: data.classCode || "",
        room: data.room || "",
        schedule: Array.isArray(data.schedule) ? data.schedule : [],
        maxStudents: data.maxStudents ?? 0,

        adminState: data.adminState || "draft",
        isVisibleForRegistration: data.isVisibleForRegistration !== false,
        termNumberSnapshot: data.termNumberSnapshot ?? null,
        yearNumberSnapshot: data.yearNumberSnapshot ?? null,
        academicYearSnapshot: data.academicYearSnapshot || "",

        sourceClassId: data.sourceClassId || null,
        replacedByClassId: data.replacedByClassId || null,

        semesterTimeline,

        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
        archivedAt: toISOStringSafe(data.archivedAt),
    };
}

async function getSemesterSnapshot(semesterId, academicStartYear = null) {
    const cycleRef = db.collection("semester_cycles").doc(semesterId);
    const cycleSnap = await cycleRef.get();

    if (cycleSnap.exists) {
        const cycle = cycleSnap.data() || {};
        const startYear = academicStartYear ?? getAcademicStartYear();
        const timeline = resolveCycleTimeline(cycle, startYear);

        return {
            semesterId,
            termNumberSnapshot: Number(cycle.termNumber),
            yearNumberSnapshot: Number(cycle.yearNumber),
            academicYearSnapshot: timeline.academicYear,
            sourceType: "semester_cycle",
        };
    }

    const semesterRef = db.collection("semesters").doc(semesterId);
    const semesterSnap = await semesterRef.get();

    if (semesterSnap.exists) {
        const semester = semesterSnap.data() || {};
        return {
            semesterId,
            termNumberSnapshot: Number(semester.termNumber),
            yearNumberSnapshot: Number(semester.yearNumber),
            academicYearSnapshot: semester.academicYear || "",
            sourceType: "semester",
        };
    }

    const err = new Error("Semester not found");
    err.statusCode = 404;
    throw err;
}

async function ensureNoEnrollmentYet(classId) {
    const snap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .limit(1)
        .get();

    if (!snap.empty) {
        const err = new Error("Class already has enrollments and cannot be edited");
        err.statusCode = 409;
        throw err;
    }
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

    const academicStartYear = getAcademicStartYear();

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

function ensureEditableAdminState(adminState) {
    if (!EDITABLE_ADMIN_STATE.includes(adminState)) {
        const err = new Error("Only draft classes can be edited");
        err.statusCode = 409;
        throw err;
    }
}

function ensureSemesterAllowsDraftManagement(semesterStatus) {
    if (!["upcoming", "finished"].includes(semesterStatus)) {
        const err = new Error(
            "Classes can only be edited or replaced when semester is upcoming or finished"
        );
        err.statusCode = 409;
        throw err;
    }
}

async function assertUniqueClassCode({
    courseId,
    semesterId,
    classCode,
    ignoreClassId = null,
}) {
    const snap = await db.collection("classes")
        .where("courseId", "==", courseId)
        .where("semesterId", "==", semesterId)
        .where("classCode", "==", classCode)
        .limit(20)
        .get();

    const duplicated = snap.docs.find((d) => d.id !== ignoreClassId);
    if (duplicated) {
        const err = new Error("Class code already exists in this course and semester");
        err.statusCode = 409;
        throw err;
    }
}

async function assertNoTeacherConflict({
    teacherId,
    termNumberSnapshot,
    schedule,
    ignoreClassId = null,
}) {
    const snap = await db.collection("classes")
        .where("teacherId", "==", teacherId)
        .where("termNumberSnapshot", "==", termNumberSnapshot)
        .get();

    const items = snap.docs
        .filter((d) => d.id !== ignoreClassId)
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((x) => ACTIVE_FOR_CONFLICT_ADMIN_STATE.includes(x.adminState || "draft"));

    const conflicted = items.find((x) =>
        schedulesOverlap(schedule, Array.isArray(x.schedule) ? x.schedule : [])
    );

    if (conflicted) {
        const err = new Error(
            `Teacher schedule conflict with class ${conflicted.classCode || conflicted.id}`
        );
        err.statusCode = 409;
        throw err;
    }
}

async function assertNoRoomConflict({
    room,
    termNumberSnapshot,
    schedule,
    ignoreClassId = null,
}) {
    const snap = await db.collection("classes")
        .where("room", "==", room)
        .where("termNumberSnapshot", "==", termNumberSnapshot)
        .get();

    const items = snap.docs
        .filter((d) => d.id !== ignoreClassId)
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((x) => ACTIVE_FOR_CONFLICT_ADMIN_STATE.includes(x.adminState || "draft"));

    const conflicted = items.find((x) =>
        schedulesOverlap(schedule, Array.isArray(x.schedule) ? x.schedule : [])
    );

    if (conflicted) {
        const err = new Error(
            `Room conflict with class ${conflicted.classCode || conflicted.id}`
        );
        err.statusCode = 409;
        throw err;
    }
}

async function createClass(data) {
    const semesterSnapshot = await getSemesterSnapshot(data.semesterId);
    const semesterStatus = await getSemesterCycleStatus(data.semesterId);

    ensureSemesterAllowsDraftManagement(semesterStatus);

    await assertUniqueClassCode({
        courseId: data.courseId,
        semesterId: data.semesterId,
        classCode: data.classCode,
    });

    await assertNoTeacherConflict({
        teacherId: data.teacherId,
        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        schedule: data.schedule,
    });

    await assertNoRoomConflict({
        room: data.room,
        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        schedule: data.schedule,
    });

    const docRef = await db.collection("classes").add({
        courseId: data.courseId,
        semesterId: data.semesterId,
        teacherId: data.teacherId,
        classCode: data.classCode,
        room: data.room,
        schedule: Array.isArray(data.schedule) ? data.schedule : [],
        maxStudents: Number(data.maxStudents),

        adminState: data.adminState || "draft",
        isVisibleForRegistration: data.isVisibleForRegistration !== false,

        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        yearNumberSnapshot: semesterSnapshot.yearNumberSnapshot,
        academicYearSnapshot: semesterSnapshot.academicYearSnapshot,

        sourceClassId: data.sourceClassId || null,
        replacedByClassId: null,

        createdAt: new Date(),
        updatedAt: new Date(),
        archivedAt: null,
    });

    const after = await docRef.get();
    return await mapClassDoc(after);
}

async function listClasses(query = {}) {
    let ref = db.collection("classes");

    if (query.teacherId) ref = ref.where("teacherId", "==", query.teacherId);
    if (query.semesterId) ref = ref.where("semesterId", "==", query.semesterId);
    if (query.courseId) ref = ref.where("courseId", "==", query.courseId);
    if (query.adminState) ref = ref.where("adminState", "==", query.adminState);
    if (query.academicYearSnapshot) {
        ref = ref.where("academicYearSnapshot", "==", query.academicYearSnapshot);
    }
    if (query.isVisibleForRegistration != null) {
        ref = ref.where(
            "isVisibleForRegistration",
            "==",
            query.isVisibleForRegistration === "true" ||
            query.isVisibleForRegistration === true
        );
    }

    const snap = await ref.get();
    return await Promise.all(snap.docs.map((doc) => mapClassDoc(doc)));
}

async function updateClass(id, patch) {
    const ref = db.collection("classes").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};
    ensureEditableAdminState(current.adminState || "draft");
    await ensureNoEnrollmentYet(id);
    const semesterStatus = await getSemesterCycleStatus(current.semesterId);
    ensureSemesterAllowsDraftManagement(semesterStatus);

    const nextSemesterId = patch.semesterId ?? current.semesterId;
    const nextCourseId = patch.courseId ?? current.courseId;
    const nextTeacherId = patch.teacherId ?? current.teacherId;
    const nextClassCode = patch.classCode ?? current.classCode;
    const nextRoom = patch.room ?? current.room;
    const nextSchedule = patch.schedule ?? current.schedule;
    const nextMaxStudents = patch.maxStudents ?? current.maxStudents;

    const semesterSnapshot = await getSemesterSnapshot(nextSemesterId);

    await assertUniqueClassCode({
        courseId: nextCourseId,
        semesterId: nextSemesterId,
        classCode: nextClassCode,
        ignoreClassId: id,
    });

    await assertNoTeacherConflict({
        teacherId: nextTeacherId,
        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        schedule: nextSchedule,
        ignoreClassId: id,
    });

    await assertNoRoomConflict({
        room: nextRoom,
        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        schedule: nextSchedule,
        ignoreClassId: id,
    });

    const payload = {
        courseId: nextCourseId,
        semesterId: nextSemesterId,
        teacherId: nextTeacherId,
        classCode: nextClassCode,
        room: nextRoom,
        schedule: Array.isArray(nextSchedule) ? nextSchedule : [],
        maxStudents: Number(nextMaxStudents),

        termNumberSnapshot: semesterSnapshot.termNumberSnapshot,
        yearNumberSnapshot: semesterSnapshot.yearNumberSnapshot,
        academicYearSnapshot: semesterSnapshot.academicYearSnapshot,

        updatedAt: new Date(),
    };

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return await mapClassDoc(after);
}

async function archiveClass(id) {
    const ref = db.collection("classes").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};
    const adminState = current.adminState || "draft";

    ensureEditableAdminState(adminState);

    const semesterStatus = await getSemesterCycleStatus(current.semesterId);
    if (semesterStatus !== "finished") {
        const err = new Error("Classes can only be archived when semester is finished");
        err.statusCode = 409;
        throw err;
    }

    await ref.set(
        {
            adminState: "archived",
            archivedAt: new Date(),
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return await mapClassDoc(after);
}

async function replaceClass(oldId, newData) {
    const oldRef = db.collection("classes").doc(oldId);
    const oldSnap = await oldRef.get();

    if (!oldSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const oldClass = oldSnap.data() || {};
    ensureEditableAdminState(oldClass.adminState || "draft");

    const semesterStatus = await getSemesterCycleStatus(oldClass.semesterId);
    if (semesterStatus !== "finished") {
        const err = new Error("Classes can only be replaced when semester is finished");
        err.statusCode = 409;
        throw err;
    }

    const created = await createClass({
        courseId: newData.courseId ?? oldClass.courseId,
        semesterId: newData.semesterId ?? oldClass.semesterId,
        teacherId: newData.teacherId ?? oldClass.teacherId,
        classCode: newData.classCode,
        room: newData.room ?? oldClass.room,
        schedule: newData.schedule ?? oldClass.schedule,
        maxStudents: newData.maxStudents ?? oldClass.maxStudents,
        adminState: "draft",
        sourceClassId: oldId,
    });

    await oldRef.set(
        {
            adminState: "archived",
            replacedByClassId: created.id,
            archivedAt: new Date(),
            updatedAt: new Date(),
        },
        { merge: true }
    );

    return {
        oldClassId: oldId,
        newClass: created,
    };
}

async function reopenClassFromOld(oldId, overrideData = {}) {
    const oldRef = db.collection("classes").doc(oldId);
    const oldSnap = await oldRef.get();

    if (!oldSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const oldClass = oldSnap.data() || {};
    const semesterStatus = await getSemesterCycleStatus(oldClass.semesterId);

    if (semesterStatus !== "finished") {
        const err = new Error("New class life can only be created after semester is finished");
        err.statusCode = 409;
        throw err;
    }

    const created = await createClass({
        courseId: overrideData.courseId ?? oldClass.courseId,
        semesterId: overrideData.semesterId ?? oldClass.semesterId,
        teacherId: overrideData.teacherId ?? oldClass.teacherId,
        classCode: overrideData.classCode,
        room: overrideData.room ?? oldClass.room,
        schedule: overrideData.schedule ?? oldClass.schedule,
        maxStudents: overrideData.maxStudents ?? oldClass.maxStudents,
        adminState: "draft",
        sourceClassId: oldId,
    });

    return created;
}

async function toggleClassVisibility(id, isVisibleForRegistration) {
    const ref = db.collection("classes").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};

    // Chỉ cho ẩn/hiện lớp chưa archive
    if ((current.adminState || "draft") === "archived") {
        const err = new Error("Archived class cannot change visibility");
        err.statusCode = 409;
        throw err;
    }

    await ref.set(
        {
            isVisibleForRegistration: !!isVisibleForRegistration,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return await mapClassDoc(after);
}

async function findClassByCode(classCode) {
    const snap = await db.collection("classes")
        .where("classCode", "==", classCode)
        .limit(1)
        .get();

    if (snap.empty) return null;
    return await mapClassDoc(snap.docs[0]);
}

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function getAcademicYearLabel(startYear) {
    return `${startYear}-${startYear + 1}`;
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

function resolveCycleTimeline(cycle, academicStartYear) {
    const registrationOpenYear = getDateYearForAcademicCycle(
        cycle.registrationOpenMonth,
        academicStartYear
    );

    const registrationCloseYear = getDateYearForAcademicCycle(
        cycle.registrationCloseMonth,
        academicStartYear
    );

    const studyStartYear = getDateYearForAcademicCycle(
        cycle.studyStartMonth,
        academicStartYear
    );

    const studyEndYear = getDateYearForAcademicCycle(
        cycle.studyEndMonth,
        academicStartYear
    );

    return {
        registrationOpenAt: buildUtcDate(
            registrationOpenYear,
            cycle.registrationOpenMonth,
            cycle.registrationOpenDay
        ),
        registrationCloseAt: buildUtcDate(
            registrationCloseYear,
            cycle.registrationCloseMonth,
            cycle.registrationCloseDay,
            true
        ),
        studyStartAt: buildUtcDate(
            studyStartYear,
            cycle.studyStartMonth,
            cycle.studyStartDay
        ),
        studyEndAt: buildUtcDate(
            studyEndYear,
            cycle.studyEndMonth,
            cycle.studyEndDay,
            true
        ),
        academicYear: getAcademicYearLabel(academicStartYear),
    };
}

module.exports = {
    createClass,
    listClasses,
    updateClass,
    archiveClass,
    replaceClass,
    reopenClassFromOld,
    findClassByCode,
    toggleClassVisibility,
};