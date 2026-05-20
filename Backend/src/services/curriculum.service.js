const { db } = require("../config/firebase");

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