const { db } = require("../config/firebase");
const { sendPushToTokens } = require("./fcm.service");

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

async function createCampaign(data, actor) {
    const now = new Date();

    const campaignRef = db.collection("notification_campaigns").doc();

    const campaignData = {
        title: data.title,
        body: data.body,
        audience: "all",
        createdBy: actor.uid,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
    };

    await campaignRef.set(campaignData);

    const usersSnap = await db.collection("users").get();

    const targets = usersSnap.docs.filter((doc) => {
        const user = doc.data() || {};
        return user.isActive !== false;
    });

    const allTokens = [];

    let batch = db.batch();
    let opCount = 0;
    let createdCount = 0;

    for (const userDoc of targets) {
        const user = userDoc.data() || {};
        const fcmTokens = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
        allTokens.push(...fcmTokens);

        const notifRef = db.collection("notifications").doc();

        batch.set(notifRef, {
            campaignId: campaignRef.id,
            receiverId: userDoc.id,
            receiverType: "individual",
            title: data.title,
            body: data.body,
            isRead: false,
            createdAt: now,
            updatedAt: now,
            source: "admin_broadcast",
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
        title: data.title,
        body: data.body,
        data: {
            type: "SYSTEM",
            screen: "notifications",
            campaignId: campaignRef.id,
        },
    });

    return {
        id: campaignRef.id,
        createdCount,
        pushSuccessCount: pushResult.successCount,
        pushFailureCount: pushResult.failureCount,
    };
}

async function listCampaigns() {
    const snap = await db
        .collection("notification_campaigns")
        .where("isDeleted", "==", false)
        .get();

    const items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            id: doc.id,
            title: data.title || "",
            body: data.body || "",
            audience: data.audience || "all",
            createdBy: data.createdBy || "",
            createdAt: toISOStringSafe(data.createdAt),
            updatedAt: toISOStringSafe(data.updatedAt),
            isDeleted: data.isDeleted === true,
        };
    });

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