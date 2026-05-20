const admin = require("firebase-admin");
const { db } = require("../config/firebase");

function chunkArray(items, size) {
    const result = [];
    for (let i = 0; i < items.length; i += size) {
        result.push(items.slice(i, i + size));
    }
    return result;
}

async function removeInvalidTokensFromUsers(invalidTokens) {
    const cleanInvalidTokens = [...new Set((invalidTokens || []).filter(Boolean))];
    if (cleanInvalidTokens.length === 0) return;

    const usersSnap = await db.collection("users").get();

    let batch = db.batch();
    let opCount = 0;

    for (const userDoc of usersSnap.docs) {
        const data = userDoc.data() || {};
        const userTokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];

        const matched = userTokens.filter((t) => cleanInvalidTokens.includes(t));
        if (matched.length === 0) continue;

        for (const token of matched) {
            batch.update(userDoc.ref, {
                fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
                updatedAt: new Date(),
            });

            opCount += 1;

            if (opCount >= 450) {
                await batch.commit();
                batch = db.batch();
                opCount = 0;
            }
        }
    }

    if (opCount > 0) {
        await batch.commit();
    }
}

async function sendPushToTokens({ tokens, title, body, data = {} }) {
    const cleanTokens = [...new Set((tokens || []).filter(Boolean))];

    if (cleanTokens.length === 0) {
        return {
            successCount: 0,
            failureCount: 0,
            invalidTokens: [],
        };
    }

    const chunks = chunkArray(cleanTokens, 500);

    let successCount = 0;
    let failureCount = 0;
    const invalidTokens = [];

    for (const tokenChunk of chunks) {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokenChunk,
            notification: {
                title,
                body,
            },
            data,
            android: {
                priority: "high",
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                    },
                },
            },
        });

        successCount += response.successCount;
        failureCount += response.failureCount;

        response.responses.forEach((item, index) => {
            if (!item.success) {
                const code = item.error?.code || "";
                if (
                    code.includes("invalid-registration-token") ||
                    code.includes("registration-token-not-registered")
                ) {
                    invalidTokens.push(tokenChunk[index]);
                }
            }
        });
    }

    await removeInvalidTokensFromUsers(invalidTokens);

    return {
        successCount,
        failureCount,
        invalidTokens,
    };
}

module.exports = {
    sendPushToTokens,
};