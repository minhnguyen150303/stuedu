const { db } = require("../config/firebase");
const { cloudinary } = require("../config/cloudinary");
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

function buildMaterialDownloadUrl(file = {}) {
    const publicId = (file.publicId || "").toString();

    if (!publicId) {
        return (file.downloadUrl || file.url || "").toString();
    }

    const resourceType = (file.resourceType || "raw").toString();
    const originalName = (file.originalName || "download").toString();

    return cloudinary.url(publicId, {
        resource_type: resourceType,
        type: "upload",
        secure: true,
        flags: `attachment:${originalName}`,
    });
}

function normalizeMaterial(file = {}) {
    return {
        url: file.url || "",
        downloadUrl: file.downloadUrl || buildMaterialDownloadUrl(file),
        publicId: file.publicId || null,
        resourceType: file.resourceType || "raw",
        originalName: file.originalName || null,
        format: file.format || null,
    };
}

async function listMaterials(query) {
    let ref = db.collection("materials");

    if (query.classId) {
        ref = ref.where("classId", "==", query.classId);
    }

    const snap = await ref.get();

    return snap.docs.map((d) => {
        const data = d.data() || {};
        const file = normalizeMaterial(data);

        return {
            id: d.id,
            classId: data.classId || "",
            title: data.title || "",
            type: data.type || "file",

            url: file.url,
            downloadUrl: file.downloadUrl,
            publicId: file.publicId,
            resourceType: file.resourceType,
            originalName: file.originalName,
            format: file.format,

            uploadedBy: data.uploadedBy || "",
            createdAt: toISOStringSafe(data.createdAt),
            updatedAt: toISOStringSafe(data.updatedAt),
        };
    });
}

async function createMaterial(uid, data) {
    const file = normalizeMaterial(data);

    const docRef = await db.collection("materials").add({
        classId: data.classId,
        title: data.title,
        type: data.type || "file",

        url: file.url,
        downloadUrl: file.downloadUrl,
        publicId: file.publicId,
        resourceType: file.resourceType,
        originalName: file.originalName,
        format: file.format,

        uploadedBy: uid,
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id };
}

async function updateMaterial(id, data) {
    const ref = db.collection("materials").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        throw new Error("Material not found");
    }

    const oldData = snap.data() || {};

    const oldPublicId = oldData.publicId;
    const oldResourceType = oldData.resourceType || "raw";

    const newPublicId = data.publicId;
    const newResourceType = data.resourceType || "raw";

    if (oldPublicId && newPublicId && oldPublicId !== newPublicId) {
        await deleteCloudinaryFile(oldPublicId, oldResourceType);
    }

    const file = normalizeMaterial(data);

    const payload = {
        classId: data.classId,
        title: data.title,
        type: data.type || "file",

        url: file.url,
        downloadUrl: file.downloadUrl,
        publicId: file.publicId,
        resourceType: file.resourceType,
        originalName: file.originalName,
        format: file.format,

        updatedAt: new Date(),
    };

    await ref.update(payload);

    return { id };
}

async function deleteMaterial(id) {
    const ref = db.collection("materials").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        throw new Error("Material not found");
    }

    const data = snap.data() || {};

    if (data.publicId) {
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