const { db } = require("../config/firebase");

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

function getSemesterName(yearNumber, termNumber) {
    return `HK${termNumber} năm ${yearNumber}`;
}

function getSemesterStatus(semester) {
    const now = new Date();

    const registrationOpenAt = new Date(semester.registrationOpenAt);
    const registrationCloseAt = new Date(semester.registrationCloseAt);
    const studyStartAt = new Date(semester.studyStartAt);
    const studyEndAt = new Date(semester.studyEndAt);

    if (semester.isManualLocked) return "locked";
    if (now < registrationOpenAt) return "upcoming";
    if (now <= registrationCloseAt) return "registration_open";
    if (now < studyStartAt) return "registration_closed";
    if (now <= studyEndAt) return "studying";
    return "finished";
}

function mapSemesterDoc(doc) {
    const data = doc.data() || {};

    const item = {
        id: doc.id,
        majorId: data.majorId || "",
        yearNumber: data.yearNumber ?? null,
        termNumber: data.termNumber ?? null,
        name: data.name || "",
        academicYear: data.academicYear || "",
        registrationOpenAt: toISOStringSafe(data.registrationOpenAt),
        registrationCloseAt: toISOStringSafe(data.registrationCloseAt),
        studyStartAt: toISOStringSafe(data.studyStartAt),
        studyEndAt: toISOStringSafe(data.studyEndAt),
        isManualLocked: data.isManualLocked === true,
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
    };

    return {
        ...item,
        status: getSemesterStatus(item),
    };
}

async function listSemesters(query = {}) {
    let ref = db.collection("semesters");

    if (query.majorId) {
        ref = ref.where("majorId", "==", query.majorId);
    }

    const snap = await ref.get();
    return snap.docs.map(mapSemesterDoc);
}

async function getCurrentSemester(query = {}) {
    let ref = db.collection("semesters");

    if (query.majorId) {
        ref = ref.where("majorId", "==", query.majorId);
    }

    const snap = await ref.get();

    const items = snap.docs.map(mapSemesterDoc);
    const current = items.find((x) => x.status === "studying");

    return current || null;
}

async function createSemester(data) {
    const name = getSemesterName(
        Number(data.yearNumber),
        Number(data.termNumber)
    );

    const docRef = await db.collection("semesters").add({
        majorId: data.majorId,
        yearNumber: Number(data.yearNumber),
        termNumber: Number(data.termNumber),
        name,
        academicYear: data.academicYear,
        registrationOpenAt: new Date(data.registrationOpenAt),
        registrationCloseAt: new Date(data.registrationCloseAt),
        studyStartAt: new Date(data.studyStartAt),
        studyEndAt: new Date(data.studyEndAt),
        isManualLocked: !!data.isManualLocked,
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id, name };
}

async function updateSemester(id, patch) {
    const ref = db.collection("semesters").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Semester not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};

    const nextYearNumber = patch.yearNumber !== undefined
        ? Number(patch.yearNumber)
        : Number(current.yearNumber);

    const nextTermNumber = patch.termNumber !== undefined
        ? Number(patch.termNumber)
        : Number(current.termNumber);

    const payload = {
        updatedAt: new Date(),
        name: getSemesterName(nextYearNumber, nextTermNumber),
    };

    if (patch.majorId !== undefined) payload.majorId = patch.majorId;
    if (patch.yearNumber !== undefined) payload.yearNumber = Number(patch.yearNumber);
    if (patch.termNumber !== undefined) payload.termNumber = Number(patch.termNumber);
    if (patch.academicYear !== undefined) payload.academicYear = patch.academicYear;
    if (patch.registrationOpenAt !== undefined) {
        payload.registrationOpenAt = new Date(patch.registrationOpenAt);
    }
    if (patch.registrationCloseAt !== undefined) {
        payload.registrationCloseAt = new Date(patch.registrationCloseAt);
    }
    if (patch.studyStartAt !== undefined) {
        payload.studyStartAt = new Date(patch.studyStartAt);
    }
    if (patch.studyEndAt !== undefined) {
        payload.studyEndAt = new Date(patch.studyEndAt);
    }
    if (patch.isManualLocked !== undefined) {
        payload.isManualLocked = !!patch.isManualLocked;
    }

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return mapSemesterDoc(after);
}

async function deleteSemester(id) {
    const ref = db.collection("semesters").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Semester not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();
    return { id, deleted: true };
}

async function setCurrentSemester(semesterId) {
    const ref = db.collection("semesters").doc(semesterId);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Semester not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.set(
        {
            isManualLocked: false,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return mapSemesterDoc(after);
}

module.exports = {
    listSemesters,
    getCurrentSemester,
    createSemester,
    updateSemester,
    deleteSemester,
    setCurrentSemester,
};