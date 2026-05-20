const { db } = require("../config/firebase");

async function listMajors() {
    const snap = await db.collection("majors").get();
    return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

async function createMajor(data) {
    const docRef = await db.collection("majors").add({
        name: data.name,
        description: data.description || "",
        createdAt: new Date(),
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

async function deleteMajor(id) {
    const ref = db.collection("majors").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Major not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();
    return { id, deleted: true };
}

module.exports = {
    listMajors,
    createMajor,
    updateMajor,
    deleteMajor,
};