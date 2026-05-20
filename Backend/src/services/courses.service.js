const { db } = require("../config/firebase");

async function listCourses(query = {}) {
    let ref = db.collection("courses");
    if (query.majorId) ref = ref.where("majorId", "==", query.majorId);
    const snap = await ref.get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function createCourse(data) {
    const duplicate = await db.collection("courses")
        .where("majorId", "==", data.majorId)
        .where("courseCode", "==", data.courseCode)
        .limit(1)
        .get();

    if (!duplicate.empty) {
        const err = new Error("Course code already exists");
        err.statusCode = 409;
        throw err;
    }

    const docRef = await db.collection("courses").add({
        courseName: data.courseName,
        courseCode: data.courseCode,
        credits: Number(data.credits),
        description: data.description || "",
        majorId: data.majorId,
        createdAt: new Date(),
    });
    return { id: docRef.id };
}

async function updateCourse(id, patch) {
    const ref = db.collection("courses").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Course not found");
        err.statusCode = 404;
        throw err;
    }

    const current = snap.data() || {};

    if (patch.courseCode !== undefined) {
        const duplicate = await db.collection("courses")
            .where("majorId", "==", patch.majorId ?? current.majorId)
            .where("courseCode", "==", patch.courseCode)
            .limit(10)
            .get();

        const existedOther = duplicate.docs.find((d) => d.id !== id);
        if (existedOther) {
            const err = new Error("Course code already exists");
            err.statusCode = 409;
            throw err;
        }
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.courseName !== undefined) {
        payload.courseName = patch.courseName;
    }
    if (patch.courseCode !== undefined) {
        payload.courseCode = patch.courseCode;
    }
    if (patch.credits !== undefined) {
        payload.credits = Number(patch.credits);
    }
    if (patch.description !== undefined) {
        payload.description = patch.description;
    }
    if (patch.majorId !== undefined) {
        payload.majorId = patch.majorId;
    }

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return { id, ...after.data() };
}

async function deleteCourse(id) {
    const ref = db.collection("courses").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Course not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();
    return { id, deleted: true };
}

module.exports = { listCourses, createCourse, updateCourse, deleteCourse };