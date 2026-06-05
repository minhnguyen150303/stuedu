const { db } = require("../config/firebase");

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

async function assertUniqueLifecycleClassCode({
    courseId,
    classCode,
    majorId,
    yearNumber,
    termNumber,
    ignoreLifecycleId = null,
}) {
    const snap = await db.collection("class_lifecycles")
        .where("courseId", "==", courseId)
        .where("classCode", "==", classCode)
        .where("majorId", "==", majorId)
        .where("yearNumber", "==", Number(yearNumber))
        .where("termNumber", "==", Number(termNumber))
        .where("isHidden", "==", false)
        .get();

    const duplicated = snap.docs.find((d) => d.id !== ignoreLifecycleId);

    if (duplicated) {
        const err = new Error("Lifecycle classCode already exists in this course");
        err.statusCode = 409;
        throw err;
    }
}

async function assertNoLifecycleTeacherConflict({
    teacherId,
    termNumber,
    schedule,
    ignoreLifecycleId = null,
}) {
    const snap = await db.collection("class_lifecycles")
        .where("teacherId", "==", teacherId)
        .where("termNumber", "==", Number(termNumber))
        .where("isHidden", "==", false)
        .get();

    const conflicted = snap.docs
        .filter((d) => d.id !== ignoreLifecycleId)
        .find((d) => {
            const item = d.data() || {};
            return schedulesOverlap(
                Array.isArray(schedule) ? schedule : [],
                Array.isArray(item.schedule) ? item.schedule : []
            );
        });

    if (conflicted) {
        const data = conflicted.data() || {};
        const err = new Error(
            `Teacher schedule conflict with lifecycle ${data.classCode || conflicted.id}`
        );
        err.statusCode = 409;
        throw err;
    }
}

async function assertNoLifecycleRoomConflict({
    room,
    termNumber,
    schedule,
    ignoreLifecycleId = null,
}) {
    const snap = await db.collection("class_lifecycles")
        .where("room", "==", room)
        .where("termNumber", "==", Number(termNumber))
        .where("isHidden", "==", false)
        .get();

    const conflicted = snap.docs
        .filter((d) => d.id !== ignoreLifecycleId)
        .find((d) => {
            const item = d.data() || {};
            return schedulesOverlap(
                Array.isArray(schedule) ? schedule : [],
                Array.isArray(item.schedule) ? item.schedule : []
            );
        });

    if (conflicted) {
        const data = conflicted.data() || {};
        const err = new Error(
            `Room conflict with lifecycle ${data.classCode || conflicted.id}`
        );
        err.statusCode = 409;
        throw err;
    }
}

async function assertNoLifecycleCourseScheduleConflict({
    courseId,
    majorId,
    yearNumber,
    termNumber,
    schedule,
    ignoreLifecycleId = null,
}) {
    const snap = await db.collection("class_lifecycles")
        .where("courseId", "==", courseId)
        .where("majorId", "==", majorId)
        .where("yearNumber", "==", Number(yearNumber))
        .where("termNumber", "==", Number(termNumber))
        .where("isHidden", "==", false)
        .get();

    const conflicted = snap.docs
        .filter((d) => d.id !== ignoreLifecycleId)
        .find((d) => {
            const item = d.data() || {};
            return schedulesOverlap(
                Array.isArray(schedule) ? schedule : [],
                Array.isArray(item.schedule) ? item.schedule : []
            );
        });

    if (conflicted) {
        const data = conflicted.data() || {};
        const err = new Error(
            `Schedule conflict with another lifecycle of the same course: ${data.classCode || conflicted.id}`
        );
        err.statusCode = 409;
        throw err;
    }
}

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

function mapLifecycleDoc(doc) {
    const data = doc.data() || {};
    return {
        id: doc.id,
        courseId: data.courseId || "",
        teacherId: data.teacherId || "",
        classCode: data.classCode || "",
        room: data.room || "",
        schedule: Array.isArray(data.schedule) ? data.schedule : [],
        maxStudents: data.maxStudents ?? 0,
        majorId: data.majorId || "",
        yearNumber: data.yearNumber ?? null,
        termNumber: data.termNumber ?? null,
        isHidden: data.isHidden === true,
        replacedByLifecycleId: data.replacedByLifecycleId || null,
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
    };
}

async function listClassLifecycles(query = {}) {
    let ref = db.collection("class_lifecycles");

    if (query.majorId) ref = ref.where("majorId", "==", query.majorId);
    if (query.yearNumber) ref = ref.where("yearNumber", "==", Number(query.yearNumber));
    if (query.termNumber) ref = ref.where("termNumber", "==", Number(query.termNumber));
    if (query.courseId) ref = ref.where("courseId", "==", query.courseId);

    const snap = await ref.get();
    let items = snap.docs.map(mapLifecycleDoc);

    if (query.hidden === "true") {
        items = items.filter((x) => x.isHidden === true);
    } else if (query.hidden === "false") {
        items = items.filter((x) => x.isHidden === false);
    } else if (query.hidden === "all") {
        // lấy tất cả, không lọc
    } else {
        items = items.filter((x) => x.isHidden === false);
    }

    return items;
}

async function createClassLifecycle(data) {
    await assertUniqueLifecycleClassCode({
        courseId: data.courseId,
        classCode: data.classCode,
        majorId: data.majorId,
        yearNumber: data.yearNumber,
        termNumber: data.termNumber,
    });

    await assertNoLifecycleTeacherConflict({
        teacherId: data.teacherId,
        termNumber: data.termNumber,
        schedule: data.schedule,
    });

    await assertNoLifecycleRoomConflict({
        room: data.room,
        termNumber: data.termNumber,
        schedule: data.schedule,
    });

    await assertNoLifecycleCourseScheduleConflict({
        courseId: data.courseId,
        majorId: data.majorId,
        yearNumber: data.yearNumber,
        termNumber: data.termNumber,
        schedule: data.schedule,
    });

    const docRef = await db.collection("class_lifecycles").add({
        courseId: data.courseId,
        teacherId: data.teacherId,
        classCode: data.classCode,
        room: data.room,
        schedule: Array.isArray(data.schedule) ? data.schedule : [],
        maxStudents: Number(data.maxStudents),
        majorId: data.majorId,
        yearNumber: Number(data.yearNumber),
        termNumber: Number(data.termNumber),
        isHidden: false,
        replacedByLifecycleId: null,
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    const after = await docRef.get();
    return mapLifecycleDoc(after);
}

async function updateClassLifecycle(id, patch) {
    const ref = db.collection("class_lifecycles").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Lifecycle not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};
    if (current.isHidden === true) {
        const err = new Error("Hidden lifecycle cannot be edited");
        err.statusCode = 409;
        throw err;
    }

    const nextCourseId = patch.courseId ?? current.courseId;
    const nextTeacherId = patch.teacherId ?? current.teacherId;
    const nextClassCode = patch.classCode ?? current.classCode;
    const nextRoom = patch.room ?? current.room;
    const nextSchedule = patch.schedule ?? current.schedule;
    const nextMaxStudents = patch.maxStudents ?? current.maxStudents;
    const nextMajorId = patch.majorId ?? current.majorId;
    const nextYearNumber = patch.yearNumber ?? current.yearNumber;
    const nextTermNumber = patch.termNumber ?? current.termNumber;

    await assertUniqueLifecycleClassCode({
        courseId: nextCourseId,
        classCode: nextClassCode,
        majorId: nextMajorId,
        yearNumber: nextYearNumber,
        termNumber: nextTermNumber,
        ignoreLifecycleId: id,
    });

    await assertNoLifecycleTeacherConflict({
        teacherId: nextTeacherId,
        termNumber: nextTermNumber,
        schedule: nextSchedule,
        ignoreLifecycleId: id,
    });

    await assertNoLifecycleRoomConflict({
        room: nextRoom,
        termNumber: nextTermNumber,
        schedule: nextSchedule,
        ignoreLifecycleId: id,
    });

    await assertNoLifecycleCourseScheduleConflict({
        courseId: nextCourseId,
        majorId: nextMajorId,
        yearNumber: nextYearNumber,
        termNumber: nextTermNumber,
        schedule: nextSchedule,
        ignoreLifecycleId: id,
    });

    await ref.set(
        {
            courseId: nextCourseId,
            teacherId: nextTeacherId,
            classCode: nextClassCode,
            room: nextRoom,
            schedule: Array.isArray(nextSchedule) ? nextSchedule : [],
            maxStudents: Number(nextMaxStudents),
            majorId: nextMajorId,
            yearNumber: Number(nextYearNumber),
            termNumber: Number(nextTermNumber),
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return mapLifecycleDoc(after);
}

async function hideClassLifecycle(id) {
    const ref = db.collection("class_lifecycles").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Lifecycle not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.set(
        {
            isHidden: true,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return mapLifecycleDoc(after);
}

async function showClassLifecycle(id) {
    const ref = db.collection("class_lifecycles").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Lifecycle not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.set(
        {
            isHidden: false,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return mapLifecycleDoc(after);
}

async function replaceClassLifecycle(oldId, newData) {
    const oldRef = db.collection("class_lifecycles").doc(oldId);
    const oldSnap = await oldRef.get();

    if (!oldSnap.exists) {
        const err = new Error("Lifecycle not found");
        err.statusCode = 404;
        throw err;
    }

    const oldLife = oldSnap.data() || {};

    const created = await createClassLifecycle({
        courseId: newData.courseId ?? oldLife.courseId,
        teacherId: newData.teacherId ?? oldLife.teacherId,
        classCode: newData.classCode ?? oldLife.classCode,
        room: newData.room ?? oldLife.room,
        schedule: newData.schedule ?? oldLife.schedule,
        maxStudents: newData.maxStudents ?? oldLife.maxStudents,
        majorId: newData.majorId ?? oldLife.majorId,
        yearNumber: newData.yearNumber ?? oldLife.yearNumber,
        termNumber: newData.termNumber ?? oldLife.termNumber,
    });

    await oldRef.set(
        {
            isHidden: true,
            replacedByLifecycleId: created.id,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    return {
        oldLifecycleId: oldId,
        newLifecycle: created,
    };
}

module.exports = {
    listClassLifecycles,
    createClassLifecycle,
    updateClassLifecycle,
    hideClassLifecycle,
    replaceClassLifecycle,
    showClassLifecycle,
};