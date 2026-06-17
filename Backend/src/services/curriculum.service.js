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

async function listCurriculum(query = {}) {
    let ref = db.collection("curriculum");

    if (query.majorId) {
        ref = ref.where("majorId", "==", query.majorId);
    }

    if (query.semesterId) {
        ref = ref.where("semesterId", "==", query.semesterId);
    }

    const snap = await ref.get();

    let items = snap.docs.map((d) => {
        const data = d.data() || {};
        return {
            id: d.id,
            majorId: data.majorId || "",
            semesterId: data.semesterId || "",
            courseId: data.courseId || "",
            isVisible: data.isVisible !== false,
            createdAt: data.createdAt || null,
            updatedAt: data.updatedAt || null,
        };
    });

    if (query.visibleOnly === "true") {
        items = items.filter((x) => x.isVisible === true);
    }

    return items;
}

async function createCurriculumItem(data) {
    const exists = await db.collection("curriculum")
        .where("majorId", "==", data.majorId)
        .where("semesterId", "==", data.semesterId)
        .where("courseId", "==", data.courseId)
        .limit(1)
        .get();

    if (!exists.empty) {
        const err = new Error("Curriculum item already exists");
        err.statusCode = 409;
        throw err;
    }

    const docRef = await db.collection("curriculum").add({
        majorId: data.majorId,
        semesterId: data.semesterId,
        courseId: data.courseId,
        isVisible: data.isVisible !== false,
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id };
}

async function updateCurriculumItem(id, patch) {
    const ref = db.collection("curriculum").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Curriculum item not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};

    if (patch.isVisible === false) {
        const semesterId = current.semesterId || patch.semesterId;

        if (!semesterId) {
            const err = new Error("Không tìm thấy học kỳ của môn học");
            err.statusCode = 400;
            throw err;
        }

        const semesterSnap = await db
            .collection("semester_cycles")
            .doc(semesterId)
            .get();

        if (!semesterSnap.exists) {
            const err = new Error("Semester cycle not found");
            err.statusCode = 404;
            throw err;
        }

        const semester = semesterSnap.data() || {};
        const status = getCycleStatus(semester);

        if (status !== "finished") {
            const err = new Error(
                "Học kỳ chưa kết thúc nên không thể ẩn môn học. Chỉ được ẩn môn học sau khi học kỳ đã kết thúc."
            );
            err.statusCode = 400;
            throw err;
        }
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.majorId !== undefined) payload.majorId = patch.majorId;
    if (patch.semesterId !== undefined) payload.semesterId = patch.semesterId;
    if (patch.courseId !== undefined) payload.courseId = patch.courseId;
    if (patch.isVisible !== undefined) payload.isVisible = !!patch.isVisible;

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return { id, ...after.data() };
}

async function deleteCurriculumItem(id) {
    const ref = db.collection("curriculum").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Curriculum item not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();
    return { id, deleted: true };
}

module.exports = {
    listCurriculum,
    createCurriculumItem,
    updateCurriculumItem,
    deleteCurriculumItem,
};