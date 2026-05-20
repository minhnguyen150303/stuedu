const { db } = require("../config/firebase");
const { deleteCloudinaryFile } = require("./uploads.service");

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

async function listMaterials(query) {
    let ref = db.collection("materials");
    if (query.classId) ref = ref.where("classId", "==", query.classId);

    const snap = await ref.get();

    return snap.docs.map((d) => {
        const data = d.data() || {};
        return {
            id: d.id,
            classId: data.classId || "",
            title: data.title || "",
            type: data.type || "",
            url: data.url || "",
            publicId: data.publicId || null,
            resourceType: data.resourceType || "raw",
            originalName: data.originalName || null,
            format: data.format || null,
            uploadedBy: data.uploadedBy || "",
            createdAt: toISOStringSafe(data.createdAt),
            updatedAt: toISOStringSafe(data.updatedAt),
        };
    });
}

async function createMaterial(uid, data) {
    const docRef = await db.collection("materials").add({
        classId: data.classId,
        title: data.title,
        type: data.type,
        url: data.url,
        publicId: data.publicId || null,
        resourceType: data.resourceType || "raw",
        originalName: data.originalName || null,
        format: data.format || null,
        uploadedBy: uid,
        createdAt: new Date(),
    });
    return { id: docRef.id };
}

async function updateMaterial(id, data) {
    const ref = db.collection("materials").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        throw new Error("Material not found");
    }

    const oldData = snap.data();

    const oldPublicId = oldData?.publicId;
    const oldResourceType = oldData?.resourceType || "raw";

    const newPublicId = data.publicId;
    const newResourceType = data.resourceType || "raw";

    if (
        oldPublicId &&
        newPublicId &&
        oldPublicId !== newPublicId
    ) {
        await deleteCloudinaryFile(oldPublicId, oldResourceType);
    }

    const payload = {
        classId: data.classId,
        title: data.title,
        type: data.type,
        url: data.url,
        updatedAt: new Date(),
    };

    if (data.publicId !== undefined) payload.publicId = data.publicId;
    if (data.resourceType !== undefined) payload.resourceType = data.resourceType;
    if (data.originalName !== undefined) payload.originalName = data.originalName;
    if (data.format !== undefined) payload.format = data.format;

    await ref.update(payload);
    return { id };
}

async function deleteMaterial(id) {
    const ref = db.collection("materials").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        throw new Error("Material not found");
    }

    const data = snap.data();

    if (data?.publicId) {
        await deleteCloudinaryFile(
            data.publicId,
            data.resourceType || "raw"
        );
    }

    await ref.delete();
    return { id };
}

module.exports = {
    listMaterials,
    createMaterial,
    updateMaterial,
    deleteMaterial,
};