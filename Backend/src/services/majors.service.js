const { db } = require("../config/firebase");

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
    return Number(month) >= 7 ? academicStartYear : academicStartYear + 1;
}

function resolveCycleTimeline(cycle, academicStartYear) {
    const registrationOpenYear = getDateYearForAcademicCycle(
        Number(cycle.registrationOpenMonth),
        academicStartYear
    );

    const registrationCloseYear = getDateYearForAcademicCycle(
        Number(cycle.registrationCloseMonth),
        academicStartYear
    );

    const studyStartYear = getDateYearForAcademicCycle(
        Number(cycle.studyStartMonth),
        academicStartYear
    );

    const studyEndYear = getDateYearForAcademicCycle(
        Number(cycle.studyEndMonth),
        academicStartYear
    );

    return {
        registrationOpenAt: buildUtcDate(
            registrationOpenYear,
            Number(cycle.registrationOpenMonth),
            Number(cycle.registrationOpenDay)
        ),
        registrationCloseAt: buildUtcDate(
            registrationCloseYear,
            Number(cycle.registrationCloseMonth),
            Number(cycle.registrationCloseDay),
            true
        ),
        studyStartAt: buildUtcDate(
            studyStartYear,
            Number(cycle.studyStartMonth),
            Number(cycle.studyStartDay)
        ),
        studyEndAt: buildUtcDate(
            studyEndYear,
            Number(cycle.studyEndMonth),
            Number(cycle.studyEndDay),
            true
        ),
    };
}

function getCycleStatus(cycle) {
    const now = new Date();

    if (cycle.isActive === false) return "inactive";
    if (cycle.isManualLocked === true) return "locked";

    const academicStartYear = getAcademicStartYear();
    const timeline = resolveCycleTimeline(cycle, academicStartYear);

    if (now < timeline.registrationOpenAt) return "upcoming";
    if (now <= timeline.registrationCloseAt) return "registration_open";
    if (now < timeline.studyStartAt) return "registration_closed";
    if (now <= timeline.studyEndAt) return "studying";

    return "finished";
}

function getCycleLabel(cycle) {
    const yearNumber = cycle.yearNumber ?? "";
    const termNumber = cycle.termNumber ?? "";
    return `HK${termNumber} năm ${yearNumber}`;
}

async function listMajors() {
    const snap = await db.collection("majors").get();

    return snap.docs.map((d) => {
        const data = d.data() || {};

        return {
            id: d.id,
            ...data,
            isActive: data.isActive !== false,
            hidden: data.hidden === true,
        };
    });
}

async function createMajor(data) {
    const docRef = await db.collection("majors").add({
        name: data.name,
        description: data.description || "",
        isActive: true,
        hidden: false,
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id };
}

async function updateMajor(id, patch) {
    const ref = db.collection("majors").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Major not found");
        err.statusCode = 404;
        throw err;
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.name !== undefined) payload.name = patch.name;
    if (patch.description !== undefined) payload.description = patch.description;

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return { id, ...after.data() };
}

async function hideMajor(id) {
    const ref = db.collection("majors").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Major not found");
        err.statusCode = 404;
        throw err;
    }

    const cyclesSnap = await db
        .collection("semester_cycles")
        .where("majorId", "==", id)
        .get();

    const blockingCycles = [];

    for (const doc of cyclesSnap.docs) {
        const cycle = doc.data() || {};
        const status = getCycleStatus(cycle);

        if (status !== "finished" && status !== "inactive") {
            blockingCycles.push({
                id: doc.id,
                name: getCycleLabel(cycle),
                status,
            });
        }
    }

    if (blockingCycles.length > 0) {
        const names = blockingCycles
            .map((x) => `${x.name} (${x.status})`)
            .join(", ");

        const err = new Error(
            `Không thể ẩn chuyên ngành vì còn học kỳ chưa kết thúc: ${names}. Chỉ được ẩn khi tất cả học kỳ đã kết thúc.`
        );
        err.statusCode = 400;
        throw err;
    }

    await ref.set(
        {
            isActive: false,
            hidden: true,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();

    return {
        id,
        ...after.data(),
    };
}

async function showMajor(id) {
    const ref = db.collection("majors").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Major not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.set(
        {
            isActive: true,
            hidden: false,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();

    return {
        id,
        ...after.data(),
    };
}

// Giữ lại tên deleteMajor để route cũ DELETE /majors/:id không xóa thật nữa.
// Từ giờ deleteMajor = ẩn chuyên ngành.
async function deleteMajor(id) {
    return hideMajor(id);
}

module.exports = {
    listMajors,
    createMajor,
    updateMajor,
    hideMajor,
    showMajor,
    deleteMajor,
};