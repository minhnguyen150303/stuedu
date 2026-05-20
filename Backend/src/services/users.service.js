const { db } = require("../config/firebase");
const admin = require("firebase-admin");

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

async function ensureUserProfile({ uid, email, name, picture }) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User profile not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.update({
        email: email || snap.data().email || "",
        fullName: name || snap.data().fullName || "",
        avatarUrl: picture || snap.data().avatarUrl || "",
        updatedAt: new Date(),
    });

    const after = await ref.get();
    return { uid, ...after.data() };
}

async function updateMySettings(uid, patch) {
    const ref = db.collection("users").doc(uid);
    await ref.set(
        { settings: patch, updatedAt: new Date() },
        { merge: true }
    );
    const snap = await ref.get();
    return { uid, ...snap.data() };
}

async function addFcmToken(uid, token) {
    const ref = db.collection("users").doc(uid);
    await ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
        updatedAt: new Date(),
    });
    const snap = await ref.get();
    return { uid, ...snap.data() };
}

async function setUserRole(targetUid, role) {
    const ref = db.collection("users").doc(targetUid);
    await ref.set({ role, updatedAt: new Date() }, { merge: true });
    const snap = await ref.get();
    return { uid: targetUid, ...snap.data() };
}

// admin
async function getUserStats() {
    const studentsSnap = await db
        .collection("users")
        .where("role", "==", "student")
        .get();

    const teachersSnap = await db
        .collection("users")
        .where("role", "==", "teacher")
        .get();

    const majorsSnap = await db.collection("majors").get();

    return {
        totalStudents: studentsSnap.size,
        totalTeachers: teachersSnap.size,
        totalMajors: majorsSnap.size,
    };
}

async function listUsersForAdmin(query = {}) {
    const page = Math.max(Number(query.page || 1), 1);
    const limit = Math.max(Number(query.limit || 10), 1);
    const q = (query.q || "").trim().toLowerCase();
    const role = (query.role || "").trim().toLowerCase();
    const majorId = (query.majorId || "").trim();
    const department = (query.department || "").trim().toLowerCase();

    let ref = db.collection("users");

    if (role) {
        ref = ref.where("role", "==", role);
    }

    const snap = await ref.get();

    let items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            uid: doc.id,
            fullName: data.fullName || "",
            email: data.email || "",
            role: data.role || "",
            avatarUrl: data.avatarUrl || "",
            phoneNumber: data.phoneNumber || "",
            address: data.address || "",
            department: data.department || "",
            majorId: data.majorId || "",
            isActive: data.isActive !== false,
            studentInfo: data.studentInfo || null,
            teacherInfo: data.teacherInfo || null,
            createdAt: toISOStringSafe(data.createdAt),
            updatedAt: toISOStringSafe(data.updatedAt),
        };
    });

    if (q) {
        items = items.filter((u) =>
            u.uid.toLowerCase().includes(q) ||
            u.fullName.toLowerCase().includes(q) ||
            u.email.toLowerCase().includes(q)
        );
    }

    if (majorId) {
        items = items.filter((u) => {
            const userMajorId = (
                u.majorId ||
                u.studentInfo?.majorId ||
                ""
            ).toString();

            return userMajorId === majorId;
        });
    }

    if (department) {
        items = items.filter((u) => {
            const userDepartment = (u.department || "").toString().toLowerCase();
            return userDepartment === department;
        });
    }

    items.sort((a, b) => {
        const nameA = (a.fullName || "").toLowerCase();
        const nameB = (b.fullName || "").toLowerCase();
        return nameA.localeCompare(nameB);
    });

    const total = items.length;
    const totalPages = Math.max(Math.ceil(total / limit), 1);
    const start = (page - 1) * limit;
    const pagedItems = items.slice(start, start + limit);

    return {
        items: pagedItems,
        page,
        limit,
        total,
        totalPages,
    };
}

async function getUserDetailForAdmin(uid) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    const data = snap.data() || {};

    return {
        uid: snap.id,
        fullName: data.fullName || "",
        email: data.email || "",
        role: data.role || "",
        avatarUrl: data.avatarUrl || "",
        phoneNumber: data.phoneNumber || "",
        address: data.address || "",
        department: data.department || "",
        majorId: data.majorId || "",
        isActive: data.isActive !== false,
        studentInfo: data.studentInfo || null,
        teacherInfo: data.teacherInfo || null,
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
        lockedAt: toISOStringSafe(data.lockedAt),
    };
}

async function updateUserProfileByAdmin(uid, patch) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.fullName !== undefined) payload.fullName = patch.fullName;
    if (patch.avatarUrl !== undefined) payload.avatarUrl = patch.avatarUrl;
    if (patch.phoneNumber !== undefined) payload.phoneNumber = patch.phoneNumber;
    if (patch.address !== undefined) payload.address = patch.address;
    if (patch.department !== undefined) payload.department = patch.department;
    if (patch.majorId !== undefined) payload.majorId = patch.majorId;
    if (patch.studentInfo !== undefined) payload.studentInfo = patch.studentInfo;
    if (patch.teacherInfo !== undefined) payload.teacherInfo = patch.teacherInfo;
    if (patch.majorId !== undefined) payload.majorId = patch.majorId;

    if (patch.email !== undefined) {
        payload.email = patch.email;
        await admin.auth().updateUser(uid, { email: patch.email });
    }

    if (patch.role !== undefined) {
        payload.role = patch.role;
    }

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return { uid, ...after.data() };
}

async function setUserLockByAdmin(uid, disabled = true) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    await admin.auth().updateUser(uid, { disabled });
    await admin.auth().revokeRefreshTokens(uid);

    await ref.set(
        {
            isActive: !disabled,
            lockedAt: disabled ? new Date() : null,
            updatedAt: new Date(),
        },
        { merge: true }
    );

    const after = await ref.get();
    return { uid, ...after.data() };
}

async function deleteUserByAdmin(uid) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    await admin.auth().deleteUser(uid);
    await ref.delete();

    return { uid, deleted: true };
}

async function removeFcmToken(uid, token) {
    const ref = db.collection("users").doc(uid);
    await ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
        updatedAt: new Date(),
    });
    const snap = await ref.get();
    return { uid, ...snap.data() };
}

async function listTeachersByMajor(majorId) {
    if (!majorId) return [];

    const snap = await db.collection("users")
        .where("role", "==", "teacher")
        .get();

    let items = snap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            uid: doc.id,
            fullName: data.fullName || "",
            email: data.email || "",
            role: data.role || "",
            avatarUrl: data.avatarUrl || "",
            phoneNumber: data.phoneNumber || "",
            address: data.address || "",
            department: data.department || "",
            majorId: data.majorId || "",
            isActive: data.isActive !== false,
            teacherInfo: data.teacherInfo || null,
            createdAt: toISOStringSafe(data.createdAt),
            updatedAt: toISOStringSafe(data.updatedAt),
        };
    });

    items = items.filter((u) => {
        const userMajorId = (
            u.majorId ||
            u.teacherInfo?.majorId ||
            ""
        ).toString();

        return userMajorId === majorId;
    });

    items.sort((a, b) => {
        const nameA = (a.fullName || "").toLowerCase();
        const nameB = (b.fullName || "").toLowerCase();
        return nameA.localeCompare(nameB);
    });

    return items;
}

module.exports = {
    ensureUserProfile,
    updateMySettings,
    addFcmToken,
    setUserRole,
    getUserStats,
    listUsersForAdmin,
    getUserDetailForAdmin,
    updateUserProfileByAdmin,
    setUserLockByAdmin,
    deleteUserByAdmin,
    removeFcmToken,
    listTeachersByMajor,
};