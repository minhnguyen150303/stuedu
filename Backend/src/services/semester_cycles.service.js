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

function getCycleName(yearNumber, termNumber) {
    return `HK${termNumber} năm ${yearNumber}`;
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

function getAcademicYearLabel(startYear) {
    return `${startYear}-${startYear + 1}`;
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    // Quy ước:
    // Tháng 7-12 thuộc năm bắt đầu năm học
    // Tháng 1-6 thuộc năm sau
    return month >= 7 ? academicStartYear : academicStartYear + 1;
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

    const registrationOpenAt = buildUtcDate(
        registrationOpenYear,
        cycle.registrationOpenMonth,
        cycle.registrationOpenDay
    );

    const registrationCloseAt = buildUtcDate(
        registrationCloseYear,
        cycle.registrationCloseMonth,
        cycle.registrationCloseDay,
        true
    );

    const studyStartAt = buildUtcDate(
        studyStartYear,
        cycle.studyStartMonth,
        cycle.studyStartDay
    );

    const studyEndAt = buildUtcDate(
        studyEndYear,
        cycle.studyEndMonth,
        cycle.studyEndDay,
        true
    );

    return {
        registrationOpenAt,
        registrationCloseAt,
        studyStartAt,
        studyEndAt,
        academicYear: getAcademicYearLabel(academicStartYear),
    };
}

function getCycleStatus(item) {
    const now = new Date();

    if (item.isActive === false) return "inactive";
    if (item.isManualLocked === true) return "locked";
    if (now < item.registrationOpenAt) return "upcoming";
    if (now <= item.registrationCloseAt) return "registration_open";
    if (now < item.studyStartAt) return "registration_closed";
    if (now <= item.studyEndAt) return "studying";
    return "finished";
}

async function ensureHistoryIfFinished(cycleView) {
    if (cycleView.status !== "finished") return;

    const exists = await db
        .collection("semester_history")
        .where("cycleId", "==", cycleView.id)
        .where("academicYear", "==", cycleView.academicYear)
        .limit(1)
        .get();

    if (!exists.empty) return;

    await db.collection("semester_history").add({
        cycleId: cycleView.id,
        majorId: cycleView.majorId,
        yearNumber: cycleView.yearNumber,
        termNumber: cycleView.termNumber,
        name: cycleView.name,
        academicYear: cycleView.academicYear,
        registrationOpenAt: cycleView.registrationOpenAt,
        registrationCloseAt: cycleView.registrationCloseAt,
        studyStartAt: cycleView.studyStartAt,
        studyEndAt: cycleView.studyEndAt,
        status: "finished",
        createdAt: new Date(),
        archivedAt: new Date(),
    });
}

function mapCycleDoc(doc, academicStartYear) {
    const data = doc.data() || {};

    const raw = {
        id: doc.id,
        majorId: data.majorId || "",
        yearNumber: data.yearNumber ?? null,
        termNumber: data.termNumber ?? null,
        registrationOpenMonth: data.registrationOpenMonth ?? null,
        registrationOpenDay: data.registrationOpenDay ?? null,
        registrationCloseMonth: data.registrationCloseMonth ?? null,
        registrationCloseDay: data.registrationCloseDay ?? null,
        studyStartMonth: data.studyStartMonth ?? null,
        studyStartDay: data.studyStartDay ?? null,
        studyEndMonth: data.studyEndMonth ?? null,
        studyEndDay: data.studyEndDay ?? null,
        isActive: data.isActive !== false,
        isManualLocked: data.isManualLocked === true,
        classesGenerated: data.classesGenerated === true,
        classesGeneratedAt: toISOStringSafe(data.classesGeneratedAt),
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
    };

    const timeline = resolveCycleTimeline(raw, academicStartYear);

    const item = {
        ...raw,
        name: getCycleName(raw.yearNumber, raw.termNumber),
        academicYear: timeline.academicYear,
        registrationOpenAt: timeline.registrationOpenAt.toISOString(),
        registrationCloseAt: timeline.registrationCloseAt.toISOString(),
        studyStartAt: timeline.studyStartAt.toISOString(),
        studyEndAt: timeline.studyEndAt.toISOString(),
    };

    return {
        ...item,
        status: getCycleStatus({
            ...item,
            registrationOpenAt: timeline.registrationOpenAt,
            registrationCloseAt: timeline.registrationCloseAt,
            studyStartAt: timeline.studyStartAt,
            studyEndAt: timeline.studyEndAt,
        }),
    };
}

async function listSemesterCycles(query = {}) {
    let ref = db.collection("semester_cycles");

    if (query.majorId) {
        ref = ref.where("majorId", "==", query.majorId);
    }

    const snap = await ref.get();
    const academicStartYear = getAcademicStartYear();

    const items = snap.docs.map((doc) => mapCycleDoc(doc, academicStartYear));

    for (const item of items) {
        await ensureHistoryIfFinished(item);
    }

    items.sort((a, b) => {
        if (a.yearNumber !== b.yearNumber) return a.yearNumber - b.yearNumber;
        return a.termNumber - b.termNumber;
    });

    return items;
}

async function createSemesterCycle(data) {
    const duplicate = await db
        .collection("semester_cycles")
        .where("majorId", "==", data.majorId)
        .where("yearNumber", "==", Number(data.yearNumber))
        .where("termNumber", "==", Number(data.termNumber))
        .limit(1)
        .get();

    if (!duplicate.empty) {
        const err = new Error("Semester cycle already exists");
        err.statusCode = 409;
        throw err;
    }

    const docRef = await db.collection("semester_cycles").add({
        majorId: data.majorId,
        yearNumber: Number(data.yearNumber),
        termNumber: Number(data.termNumber),
        registrationOpenMonth: Number(data.registrationOpenMonth),
        registrationOpenDay: Number(data.registrationOpenDay),
        registrationCloseMonth: Number(data.registrationCloseMonth),
        registrationCloseDay: Number(data.registrationCloseDay),
        studyStartMonth: Number(data.studyStartMonth),
        studyStartDay: Number(data.studyStartDay),
        studyEndMonth: Number(data.studyEndMonth),
        studyEndDay: Number(data.studyEndDay),
        isActive: data.isActive !== false,
        isManualLocked: !!data.isManualLocked,

        classesGenerated: false,
        classesGeneratedAt: null,

        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id };
}

async function updateSemesterCycle(id, patch) {
    const ref = db.collection("semester_cycles").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Semester cycle not found");
        err.statusCode = 404;
        throw err;
    }

    const currentData = snap.data() || {};

    if (patch.isActive === false) {
        const academicStartYear = getAcademicStartYear();
        const currentView = mapCycleDoc(snap, academicStartYear);

        if (currentView.status !== "finished") {
            const err = new Error(
                "Học kỳ chưa kết thúc nên không thể ẩn. Chỉ được ẩn học kỳ sau khi học kỳ đã kết thúc."
            );
            err.statusCode = 400;
            throw err;
        }
    }

    const payload = {
        updatedAt: new Date(),
    };

    const fields = [
        "majorId",
        "yearNumber",
        "termNumber",
        "registrationOpenMonth",
        "registrationOpenDay",
        "registrationCloseMonth",
        "registrationCloseDay",
        "studyStartMonth",
        "studyStartDay",
        "studyEndMonth",
        "studyEndDay",
        "isActive",
        "isManualLocked",
    ];

    for (const key of fields) {
        if (patch[key] !== undefined) {
            payload[key] = patch[key];
        }
    }

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return { id, ...after.data() };
}

async function deleteSemesterCycle(id) {
    const ref = db.collection("semester_cycles").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Semester cycle not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();
    return { id, deleted: true };
}

async function listSemesterHistory(query = {}) {
    let ref = db.collection("semester_history");

    if (query.majorId) {
        ref = ref.where("majorId", "==", query.majorId);
    }

    const snap = await ref.get();

    const items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            id: doc.id,
            cycleId: data.cycleId || "",
            majorId: data.majorId || "",
            yearNumber: data.yearNumber ?? null,
            termNumber: data.termNumber ?? null,
            name: data.name || "",
            academicYear: data.academicYear || "",
            registrationOpenAt: toISOStringSafe(data.registrationOpenAt),
            registrationCloseAt: toISOStringSafe(data.registrationCloseAt),
            studyStartAt: toISOStringSafe(data.studyStartAt),
            studyEndAt: toISOStringSafe(data.studyEndAt),
            status: data.status || "finished",
            createdAt: toISOStringSafe(data.createdAt),
            archivedAt: toISOStringSafe(data.archivedAt),
        };
    });

    items.sort((a, b) => {
        const aTime = new Date(a.studyEndAt || 0).getTime();
        const bTime = new Date(b.studyEndAt || 0).getTime();
        return bTime - aTime; // mới nhất lên trước
    });

    return items;
}

module.exports = {
    listSemesterCycles,
    createSemesterCycle,
    updateSemesterCycle,
    deleteSemesterCycle,
    listSemesterHistory,
};