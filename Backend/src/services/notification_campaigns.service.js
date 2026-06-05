const { db } = require("../config/firebase");
const { sendPushToTokens } = require("./fcm.service");

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

function uniqueArray(items) {
    return [...new Set((items || []).filter(Boolean).map((x) => x.toString()))];
}

async function getUsersByIds(userIds = []) {
    const ids = uniqueArray(userIds);
    if (ids.length === 0) return [];

    const users = [];

    for (const uid of ids) {
        const snap = await db.collection("users").doc(uid).get();
        if (!snap.exists) continue;

        const user = snap.data() || {};
        if (user.isActive === false || user.disabled === true) continue;

        users.push({
            uid: snap.id,
            ...user,
        });
    }

    return users;
}

async function getUsersByRoles(roles = []) {
    const roleList = uniqueArray(roles);
    if (roleList.length === 0) return [];

    const map = new Map();

    for (const role of roleList) {
        const snap = await db
            .collection("users")
            .where("role", "==", role)
            .get();

        snap.forEach((doc) => {
            const user = doc.data() || {};
            if (user.isActive === false || user.disabled === true) return;

            map.set(doc.id, {
                uid: doc.id,
                ...user,
            });
        });
    }

    return [...map.values()];
}

async function getAllActiveUsers() {
    const snap = await db.collection("users").get();
    const users = [];

    snap.forEach((doc) => {
        const user = doc.data() || {};
        if (user.isActive === false || user.disabled === true) return;

        const role = (user.role || "").toString();

        if (!["student", "teacher", "admin", "qlsv"].includes(role)) return;

        users.push({
            uid: doc.id,
            ...user,
        });
    });

    return users;
}

async function getUsersByClassIds(classIds = []) {
    const ids = uniqueArray(classIds);
    if (ids.length === 0) return [];

    const studentIds = new Set();

    for (const classId of ids) {
        const snap = await db
            .collection("enrollments")
            .where("classId", "==", classId)
            .where("status", "==", "approved")
            .get();

        snap.forEach((doc) => {
            const data = doc.data() || {};
            if (data.studentId) {
                studentIds.add(data.studentId.toString());
            }
        });
    }

    return getUsersByIds([...studentIds]);
}

async function resolveTargets(data) {
    const targetType = (data.targetType || data.audience || "all").toString();

    if (targetType === "all") {
        return getAllActiveUsers();
    }

    if (targetType === "role" || targetType === "roles") {
        return getUsersByRoles(data.targetRoles || data.roles || []);
    }

    if (targetType === "users") {
        return getUsersByIds(data.targetUserIds || data.userIds || []);
    }

    if (targetType === "class" || targetType === "classes") {
        return getUsersByClassIds(data.targetClassIds || data.classIds || []);
    }

    const error = new Error("targetType không hợp lệ");
    error.status = 400;
    throw error;
}

function getAudienceLabel(data) {
    const targetType = (data.targetType || data.audience || "all").toString();

    if (targetType === "all") return "all";
    if (targetType === "role" || targetType === "roles") return "role";
    if (targetType === "users") return "users";
    if (targetType === "class" || targetType === "classes") return "class";

    return "all";
}

function roleToVietnamese(role) {
    const value = (role || "").toString();

    if (value === "student") return "Sinh viên";
    if (value === "teacher") return "Giảng viên";
    if (value === "admin") return "Admin";
    if (value === "qlsv") return "QLSV";

    return value;
}

async function buildAudienceText(data) {
    const audience = getAudienceLabel(data);

    if (audience === "all") {
        return "Tất cả người dùng";
    }

    if (audience === "role") {
        const roles = uniqueArray(data.targetRoles || data.roles || []);
        if (roles.length === 0) return "Theo vai trò";

        return `Theo vai trò: ${roles.map(roleToVietnamese).join(", ")}`;
    }

    if (audience === "users") {
        const ids = uniqueArray(data.targetUserIds || data.userIds || []);
        if (ids.length === 0) return "Chọn người nhận";

        const users = await getUsersByIds(ids);
        const names = users.slice(0, 5).map((u) => {
            return u.fullName || u.email || u.uid;
        });

        if (names.length === 0) {
            return `Chọn người nhận: ${ids.length} người`;
        }

        const more = ids.length > names.length
            ? ` và ${ids.length - names.length} người khác`
            : "";

        return `Chọn người: ${names.join(", ")}${more}`;
    }

    if (audience === "class") {
        const classIds = uniqueArray(data.targetClassIds || data.classIds || []);
        if (classIds.length === 0) return "Theo lớp";

        const classDocs = await Promise.all(
            classIds.slice(0, 5).map((id) => db.collection("classes").doc(id).get())
        );

        const names = classDocs
            .filter((doc) => doc.exists)
            .map((doc) => {
                const cls = doc.data() || {};
                return cls.classCode || cls.name || doc.id;
            });

        if (names.length === 0) {
            return `Theo lớp: ${classIds.length} lớp`;
        }

        const more = classIds.length > names.length
            ? ` và ${classIds.length - names.length} lớp khác`
            : "";

        return `Theo lớp: ${names.join(", ")}${more}`;
    }

    return "Không rõ người nhận";
}

async function createCampaign(data, actor) {
    const now = new Date();

    const title = (data.title || "").toString().trim();
    const body = (data.body || "").toString().trim();

    if (!title) {
        const error = new Error("Vui lòng nhập tiêu đề thông báo");
        error.status = 400;
        throw error;
    }

    if (!body) {
        const error = new Error("Vui lòng nhập nội dung thông báo");
        error.status = 400;
        throw error;
    }

    const targets = await resolveTargets(data);

    if (targets.length === 0) {
        const error = new Error("Không tìm thấy người nhận thông báo");
        error.status = 400;
        throw error;
    }

    const audience = getAudienceLabel(data);

    const targetUserIds = audience === "users"
        ? uniqueArray(data.targetUserIds || data.userIds || [])
        : [];

    const targetRoles = audience === "role"
        ? uniqueArray(data.targetRoles || data.roles || [])
        : [];

    const targetClassIds = audience === "class"
        ? uniqueArray(data.targetClassIds || data.classIds || [])
        : [];

    const campaignRef = db.collection("notification_campaigns").doc();

    const audienceText = await buildAudienceText({
        ...data,
        targetType: audience,
        targetUserIds,
        targetRoles,
        targetClassIds,
    });

    const campaignData = {
        title,
        body,
        audience,
        targetType: audience,
        targetUserIds,
        targetRoles,
        targetClassIds,
        receiverCount: targets.length,
        audienceText,
        createdBy: actor.uid,
        createdByRole: actor.role || "",
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
    };

    await campaignRef.set(campaignData);

    const allTokens = [];

    let batch = db.batch();
    let opCount = 0;
    let createdCount = 0;

    for (const user of targets) {
        const fcmTokens = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
        allTokens.push(...fcmTokens);

        const notifRef = db.collection("notifications").doc();

        batch.set(notifRef, {
            campaignId: campaignRef.id,
            receiverId: user.uid,
            receiverType: "individual",
            receiverRole: user.role || "",
            title,
            body,
            isRead: false,
            createdAt: now,
            updatedAt: now,
            source: "campaign",
        });

        opCount += 1;
        createdCount += 1;

        if (opCount >= 450) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
        }
    }

    if (opCount > 0) {
        await batch.commit();
    }

    const pushResult = await sendPushToTokens({
        tokens: allTokens,
        title,
        body,
        data: {
            type: "SYSTEM",
            screen: "notifications",
            campaignId: campaignRef.id,
        },
    });

    return {
        id: campaignRef.id,
        createdCount,
        receiverCount: targets.length,
        pushSuccessCount: pushResult.successCount,
        pushFailureCount: pushResult.failureCount,
    };
}

async function listCampaigns() {
    const snap = await db
        .collection("notification_campaigns")
        .where("isDeleted", "==", false)
        .get();

    const items = await Promise.all(
        snap.docs.map(async (doc) => {
            const data = doc.data() || {};

            const audience = data.audience || data.targetType || "all";

            const audienceText = data.audienceText || await buildAudienceText({
                ...data,
                targetType: audience,
            });

            return {
                id: doc.id,
                title: data.title || "",
                body: data.body || "",
                audience,
                targetType: audience,
                targetUserIds: data.targetUserIds || [],
                targetRoles: data.targetRoles || [],
                targetClassIds: data.targetClassIds || [],
                receiverCount: data.receiverCount || 0,
                audienceText,
                createdBy: data.createdBy || "",
                createdByRole: data.createdByRole || "",
                createdAt: toISOStringSafe(data.createdAt),
                updatedAt: toISOStringSafe(data.updatedAt),
                isDeleted: data.isDeleted === true,
            };
        })
    );

    items.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    return items;
}

async function updateCampaign(id, data) {
    const campaignRef = db.collection("notification_campaigns").doc(id);
    const campaignSnap = await campaignRef.get();

    if (!campaignSnap.exists) {
        throw new Error("Campaign not found");
    }

    const current = campaignSnap.data() || {};
    const now = new Date();

    const nextTitle = data.title ?? current.title ?? "";
    const nextBody = data.body ?? current.body ?? "";

    await campaignRef.update({
        title: nextTitle,
        body: nextBody,
        updatedAt: now,
    });

    const notifSnap = await db
        .collection("notifications")
        .where("campaignId", "==", id)
        .get();

    const receiverIds = [
        ...new Set(
            notifSnap.docs
                .map((doc) => {
                    const x = doc.data() || {};
                    return (x.receiverId || "").toString();
                })
                .filter(Boolean)
        ),
    ];

    const userDocs = await Promise.all(
        receiverIds.map((uid) => db.collection("users").doc(uid).get())
    );

    const allTokens = [];

    for (const userDoc of userDocs) {
        const user = userDoc.data() || {};
        const fcmTokens = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
        allTokens.push(...fcmTokens);
    }

    let batch = db.batch();
    let opCount = 0;

    for (const doc of notifSnap.docs) {
        batch.update(doc.ref, {
            title: nextTitle,
            body: nextBody,
            isRead: false,
            updatedAt: now,
        });

        opCount += 1;

        if (opCount >= 450) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
        }
    }

    if (opCount > 0) {
        await batch.commit();
    }

    const pushResult = await sendPushToTokens({
        tokens: allTokens,
        title: nextTitle,
        body: nextBody,
        data: {
            type: "SYSTEM",
            screen: "notifications",
            campaignId: id,
        },
    });

    return {
        id,
        title: nextTitle,
        body: nextBody,
        updatedAt: now.toISOString(),
        updatedCount: notifSnap.size,
        pushSuccessCount: pushResult.successCount,
        pushFailureCount: pushResult.failureCount,
    };
}

async function deleteCampaign(id) {
    const campaignRef = db.collection("notification_campaigns").doc(id);
    const campaignSnap = await campaignRef.get();

    if (!campaignSnap.exists) {
        throw new Error("Campaign not found");
    }

    await campaignRef.delete();

    const notifSnap = await db
        .collection("notifications")
        .where("campaignId", "==", id)
        .get();

    let batch = db.batch();
    let opCount = 0;

    for (const doc of notifSnap.docs) {
        batch.delete(doc.ref);
        opCount += 1;

        if (opCount >= 450) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
        }
    }

    if (opCount > 0) {
        await batch.commit();
    }

    return {
        id,
        deletedCount: notifSnap.size,
    };
}

module.exports = {
    createCampaign,
    listCampaigns,
    updateCampaign,
    deleteCampaign,
};