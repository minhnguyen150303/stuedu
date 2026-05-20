const { db } = require("../config/firebase");

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

async function createNotification(data) {
    const receiverType = (data.receiverType || "").toString();

    if (receiverType === "all") {
        const usersSnap = await db.collection("users").get();

        const targets = usersSnap.docs.filter((doc) => {
            const user = doc.data() || {};
            const role = (user.role || "").toString();
            const isActive = user.isActive !== false;

            return isActive && (
                role === "student" ||
                role === "teacher" ||
                role === "admin"
            );
        });

        if (targets.length === 0) {
            return {
                broadcast: true,
                createdCount: 0,
            };
        }

        let createdCount = 0;
        let batch = db.batch();
        let opCount = 0;

        for (const userDoc of targets) {
            const ref = db.collection("notifications").doc();

            batch.set(ref, {
                receiverId: userDoc.id,
                receiverType: "individual",
                title: data.title,
                body: data.body,
                isRead: false,
                createdAt: new Date(),
                source: "admin_broadcast",
            });

            createdCount += 1;
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
            broadcast: true,
            createdCount,
        };
    }

    const docRef = await db.collection("notifications").add({
        receiverId: data.receiverId,
        receiverType: data.receiverType,
        title: data.title,
        body: data.body,
        isRead: false,
        createdAt: new Date(),
        source: "admin_manual",
    });

    return {
        id: docRef.id,
        broadcast: false,
    };
}

async function listNotifications(query) {
    let ref = db.collection("notifications");

    if (query.receiverId) {
        ref = ref.where("receiverId", "==", query.receiverId);
    }

    const snap = await ref.get();

    const items = snap.docs.map((d) => {
        const data = d.data() || {};
        return {
            id: d.id,
            receiverId: data.receiverId || "",
            receiverType: data.receiverType || "",
            title: data.title || "",
            body: data.body || "",
            isRead: data.isRead === true,
            source: data.source || "",
            createdAt: toISOStringSafe(data.createdAt),
        };
    });

    items.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    return items;
}

async function markRead(id, actor) {
    const ref = db.collection("notifications").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        throw new Error("Notification not found");
    }

    const data = snap.data() || {};
    const role = (actor?.role || "").toString();
    const ownerId = (data.receiverId || "").toString();

    if (role !== "admin" && ownerId !== actor.uid) {
        throw new Error("Forbidden");
    }

    await ref.update({
        isRead: true,
        updatedAt: new Date(),
    });

    return { id, isRead: true };
}

module.exports = { createNotification, listNotifications, markRead };