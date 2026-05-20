const { admin, db } = require("../config/firebase");

async function getUserProfile(uid) {
    if (!uid) return null;

    const snap = await db.collection("users").doc(uid).get();
    if (!snap.exists) return null;

    const data = snap.data() || {};
    return {
        uid: snap.id,
        fullName: data.fullName || "",
        avatarUrl: data.avatarUrl || "",
        role: data.role || "",
        isActive: data.isActive !== false,
    };
}

async function ensureClassChatRoom(classDoc) {
    const cls = classDoc.data() || {};
    const classId = classDoc.id;

    const teacherId = (cls.teacherId || "").toString();
    const classCode = (cls.classCode || "").toString();
    const courseId = (cls.courseId || "").toString();
    const adminState = (cls.adminState || "draft").toString();

    let courseName = "";
    if (courseId) {
        const courseSnap = await db.collection("courses").doc(courseId).get();
        if (courseSnap.exists) {
            courseName = (courseSnap.data()?.courseName || "").toString();
        }
    }

    let teacherName = "";
    if (teacherId) {
        const teacher = await getUserProfile(teacherId);
        teacherName = teacher?.fullName || "";
    }

    const isLocked = adminState !== "active";
    const roomRef = db.collection("class_chats").doc(classId);
    const roomSnap = await roomRef.get();

    const payload = {
        classId,
        classCode,
        courseId,
        courseName,
        teacherId,
        teacherName,
        isLocked,
        deleted: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!roomSnap.exists) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await roomRef.set(payload, { merge: true });

    return { classId, isLocked };
}

async function syncClassChatMembers(classId) {
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};
    const teacherId = (cls.teacherId || "").toString();

    await ensureClassChatRoom(classSnap);

    const membersRootRef = db.collection("class_chat_members").doc(classId);
    const membersRootSnap = await membersRootRef.get();

    const membersRootPayload = {
        classId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!membersRootSnap.exists) {
        membersRootPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await membersRootRef.set(membersRootPayload, { merge: true });

    const membersRef = membersRootRef.collection("members");

    const validMemberIds = new Set();

    // Teacher
    if (teacherId) {
        const teacher = await getUserProfile(teacherId);
        if (teacher && teacher.isActive) {
            validMemberIds.add(teacherId);
            await membersRef.doc(teacherId).set(
                {
                    uid: teacherId,
                    role: "teacher",
                    fullName: teacher.fullName || "",
                    avatarUrl: teacher.avatarUrl || "",
                    isActive: true,
                    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );
        }
    }

    // Approved students
    const enrollmentSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("status", "==", "approved")
        .get();

    for (const doc of enrollmentSnap.docs) {
        const e = doc.data() || {};
        const studentId = (e.studentId || "").toString();
        if (!studentId) continue;

        const student = await getUserProfile(studentId);
        if (!student || !student.isActive) continue;

        validMemberIds.add(studentId);

        await membersRef.doc(studentId).set(
            {
                uid: studentId,
                role: "student",
                fullName: student.fullName || "",
                avatarUrl: student.avatarUrl || "",
                isActive: true,
                joinedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );
    }

    // Xóa member không còn hợp lệ
    const existingMembersSnap = await membersRef.get();
    const batch = db.batch();

    for (const doc of existingMembersSnap.docs) {
        if (!validMemberIds.has(doc.id)) {
            batch.delete(doc.ref);
        }
    }

    if (!existingMembersSnap.empty) {
        await batch.commit();
    }

    return {
        classId,
        teacherAdded: !!teacherId,
        memberCount: validMemberIds.size,
    };
}

async function syncChatLockStateByClass(classId) {
    const classSnap = await db.collection("classes").doc(classId).get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};
    const adminState = (cls.adminState || "draft").toString();
    const isLocked = adminState !== "active";

    await db.collection("class_chats").doc(classId).set(
        {
            classId,
            isLocked,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    return { classId, isLocked, adminState };
}

async function syncAllActiveClassChats() {
    const snap = await db.collection("classes").get();
    const results = [];

    for (const classDoc of snap.docs) {
        const cls = classDoc.data() || {};
        const adminState = (cls.adminState || "draft").toString();

        // luôn sync room + lock state + members
        const room = await ensureClassChatRoom(classDoc);
        const members = await syncClassChatMembers(classDoc.id);

        results.push({
            classId: classDoc.id,
            adminState,
            isLocked: room.isLocked,
            memberCount: members.memberCount,
        });
    }

    return {
        total: results.length,
        results,
    };
}

module.exports = {
    ensureClassChatRoom,
    syncClassChatMembers,
    syncChatLockStateByClass,
    syncAllActiveClassChats,
};