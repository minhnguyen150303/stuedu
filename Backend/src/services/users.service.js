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
    const normalizedEmail = (email || "").trim().toLowerCase();

    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (snap.exists) {
        await ref.set(
            {
                email: normalizedEmail || snap.data().email || "",
                avatarUrl: picture || snap.data().avatarUrl || "",
                updatedAt: new Date(),
            },
            { merge: true }
        );

        const after = await ref.get();
        return { uid, ...after.data() };
    }

    const pendingSnap = await db
        .collection("pending_users")
        .where("email", "==", normalizedEmail)
        .limit(1)
        .get();

    if (pendingSnap.empty) {
        const err = new Error("Tài khoản chưa được cấp quyền trong hệ thống");
        err.statusCode = 404;
        throw err;
    }

    const pendingDoc = pendingSnap.docs[0];
    const pending = pendingDoc.data() || {};

    await ref.set({
        fullName: pending.fullName || name || "",
        email: normalizedEmail,
        role: pending.role || "student",
        avatarUrl: picture || pending.avatarUrl || "",
        phoneNumber: pending.phoneNumber || "",
        address: pending.address || "",
        department: pending.department || "",
        majorId: pending.majorId || "",
        isActive: pending.isActive !== false,
        studentInfo: pending.studentInfo || null,
        teacherInfo: pending.teacherInfo || null,
        settings: pending.settings || {
            theme: "system",
            remindMinutes: 15,
        },
        fcmTokens: [],
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    await pendingDoc.ref.delete();

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

    const user = snap.data() || {};
    const email = (user.email || "").trim().toLowerCase();

    // Xóa Firebase Auth theo UID
    try {
        await admin.auth().deleteUser(uid);
    } catch (error) {
        // Nếu Auth không còn user thì vẫn cho xóa Firestore
        if (error.code !== "auth/user-not-found") {
            throw error;
        }
    }

    // Xóa user trong users
    await ref.delete();

    // Xóa luôn pending_users nếu còn email này
    if (email) {
        const pendingSnap = await db
            .collection("pending_users")
            .where("email", "==", email)
            .get();

        const batch = db.batch();

        pendingSnap.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });

        if (!pendingSnap.empty) {
            await batch.commit();
        }
    }

    return { uid, email, deleted: true };
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

async function createUserByAdmin(data) {
    const email = await assertEmailNotExists(data.email);

    const baseProfile = {
        fullName: data.fullName,
        email,
        role: data.role,
        avatarUrl: data.avatarUrl || "",
        phoneNumber: data.phoneNumber || "",
        address: data.address || "",
        department: data.department || "",
        majorId: data.role === "admin" || data.role === "qlsv"
            ? ""
            : data.majorId || "",
        isActive: true,

        studentInfo: data.role === "student" ? data.studentInfo || null : null,
        teacherInfo: data.role === "teacher" ? data.teacherInfo || null : null,
        qlsvInfo: data.role === "qlsv" ? data.qlsvInfo || null : null,

        settings: {
            theme: "system",
            remindMinutes: 15,
        },
        fcmTokens: [],
        createdAt: new Date(),
        updatedAt: new Date(),
    };

    // Trường hợp đăng nhập email/password: tạo luôn Firebase Auth
    if (data.loginProvider === "password") {
        const userRecord = await admin.auth().createUser({
            email,
            password: data.password,
            displayName: data.fullName,
            disabled: false,
        });

        await db.collection("users").doc(userRecord.uid).set(baseProfile);

        return {
            uid: userRecord.uid,
            pending: false,
            ...baseProfile,
        };
    }

    // Trường hợp Google: chỉ cấp quyền trước, chờ user login lần đầu
    const pendingRef = await db.collection("pending_users").add({
        ...baseProfile,
        loginProvider: "google",
        status: "pending",
    });

    return {
        id: pendingRef.id,
        pending: true,
        ...baseProfile,
    };
}

async function assertEmailNotExists(email) {
    const normalizedEmail = (email || "").trim().toLowerCase();

    if (!normalizedEmail) {
        const err = new Error("Email is required");
        err.statusCode = 400;
        throw err;
    }

    const userSnap = await db
        .collection("users")
        .where("email", "==", normalizedEmail)
        .limit(1)
        .get();

    if (!userSnap.empty) {
        const err = new Error("Email already exists in users");
        err.statusCode = 409;
        throw err;
    }

    const pendingSnap = await db
        .collection("pending_users")
        .where("email", "==", normalizedEmail)
        .limit(1)
        .get();

    if (!pendingSnap.empty) {
        const err = new Error("Email already exists in pending users");
        err.statusCode = 409;
        throw err;
    }

    try {
        await admin.auth().getUserByEmail(normalizedEmail);

        const err = new Error("Email already exists in Firebase Auth");
        err.statusCode = 409;
        throw err;
    } catch (error) {
        if (error.code === "auth/user-not-found") {
            return normalizedEmail;
        }

        if (error.statusCode === 409) {
            throw error;
        }

        throw error;
    }

    return normalizedEmail;
}

async function importUsersByAdmin(users = []) {
    const results = [];

    let created = 0;
    let pending = 0;
    let failed = 0;
    let duplicate = 0;

    const seenEmails = new Set();

    for (const item of users) {
        const email = (item.email || "").trim().toLowerCase();

        try {
            if (seenEmails.has(email)) {
                duplicate += 1;
                failed += 1;

                results.push({
                    email,
                    fullName: item.fullName || "",
                    role: item.role || "",
                    success: false,
                    duplicate: true,
                    error: "Duplicate email inside Excel file",
                });

                continue;
            }

            seenEmails.add(email);

            const result = await createUserByAdmin({
                ...item,
                email,
            });

            results.push({
                email,
                fullName: item.fullName || "",
                role: item.role || "",
                success: true,
                pending: result.pending === true,
                uid: result.uid || null,
                id: result.id || null,
            });

            if (result.pending === true) {
                pending += 1;
            } else {
                created += 1;
            }
        } catch (error) {
            failed += 1;

            const isDuplicate =
                (error.statusCode === 409) ||
                String(error.message || "").toLowerCase().includes("already exists");

            if (isDuplicate) {
                duplicate += 1;
            }

            results.push({
                email,
                fullName: item.fullName || "",
                role: item.role || "",
                success: false,
                duplicate: isDuplicate,
                error: error.message || "Import failed",
            });
        }
    }

    return {
        total: users.length,
        created,
        pending,
        failed,
        duplicate,
        results,
    };
}

async function checkImportUsersByAdmin(users = []) {
    const results = [];
    const seenEmails = new Set();

    for (const item of users) {
        const email = (item.email || "").trim().toLowerCase();
        const errors = [];

        if (!email) {
            errors.push("Email is required");
        }

        if (seenEmails.has(email)) {
            errors.push("Email bị trùng trong file Excel");
        }

        seenEmails.add(email);

        const userSnap = await db
            .collection("users")
            .where("email", "==", email)
            .limit(1)
            .get();

        if (!userSnap.empty) {
            errors.push("Email đã tồn tại trong users");
        }

        const pendingSnap = await db
            .collection("pending_users")
            .where("email", "==", email)
            .limit(1)
            .get();

        if (!pendingSnap.empty) {
            errors.push("Email đang nằm trong danh sách chờ pending");
        }

        results.push({
            email,
            exists: errors.length > 0,
            errors,
        });
    }

    return results;
}

async function getMyProfile(uid) {
    const snap = await db.collection("users").doc(uid).get();

    if (!snap.exists) {
        const err = new Error("User profile not found");
        err.statusCode = 404;
        throw err;
    }

    return {
        uid: snap.id,
        ...snap.data(),
    };
}

async function updateMyProfile(uid, patch) {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("User profile not found");
        err.statusCode = 404;
        throw err;
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.fullName !== undefined) payload.fullName = patch.fullName;
    if (patch.phoneNumber !== undefined) payload.phoneNumber = patch.phoneNumber;
    if (patch.address !== undefined) payload.address = patch.address;
    if (patch.avatarUrl !== undefined) payload.avatarUrl = patch.avatarUrl;

    await ref.set(payload, { merge: true });

    const after = await ref.get();

    return {
        uid,
        ...after.data(),
    };
}

function tenToFourForAdmin(totalTen) {
    const score = Number(totalTen || 0);

    if (score >= 8.5) return 4.0;
    if (score >= 8.0) return 3.5;
    if (score >= 7.0) return 3.0;
    if (score >= 6.5) return 2.5;
    if (score >= 5.5) return 2.0;
    if (score >= 5.0) return 1.5;
    if (score >= 4.0) return 1.0;
    return 0.0;
}

function roundForAdmin(value, digits = 2) {
    const factor = Math.pow(10, digits);
    return Math.round(Number(value || 0) * factor) / factor;
}

async function getClassMapByIdsForAdmin(classIds = []) {
    const map = {};

    for (const classId of classIds) {
        if (!classId || map[classId]) continue;

        const snap = await db.collection("classes").doc(classId).get();

        if (snap.exists) {
            map[classId] = {
                id: snap.id,
                ...snap.data(),
            };
        }
    }

    return map;
}

async function getCourseMapByIdsForAdmin(courseIds = []) {
    const map = {};

    for (const courseId of courseIds) {
        if (!courseId || map[courseId]) continue;

        const snap = await db.collection("courses").doc(courseId).get();

        if (snap.exists) {
            map[courseId] = {
                id: snap.id,
                ...snap.data(),
            };
        }
    }

    return map;
}

async function getStudentLearningOverviewForAdmin(uid) {
    const userSnap = await db.collection("users").doc(uid).get();

    if (!userSnap.exists) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    const user = userSnap.data() || {};

    if ((user.role || "").toString() !== "student") {
        const err = new Error("User is not a student");
        err.statusCode = 400;
        throw err;
    }

    const gradeSnap = await db
        .collection("grades")
        .where("studentId", "==", uid)
        .get();

    const rawGrades = gradeSnap.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() || {}),
    }));

    const classIds = [
        ...new Set(
            rawGrades
                .map((g) => (g.classId || "").toString())
                .filter(Boolean)
        ),
    ];

    const classMap = await getClassMapByIdsForAdmin(classIds);

    const courseIds = [
        ...new Set(
            Object.values(classMap)
                .map((cls) => (cls.courseId || "").toString())
                .filter(Boolean)
        ),
    ];

    const courseMap = await getCourseMapByIdsForAdmin(courseIds);

    const items = rawGrades.map((grade) => {
        const classId = (grade.classId || "").toString();
        const cls = classMap[classId] || {};
        const course = courseMap[cls.courseId] || {};

        const scoreProcess = Number(grade.scoreProcess || 0);
        const scoreMid = Number(grade.scoreMid || 0);
        const scoreFinal = Number(grade.scoreFinal || 0);
        const totalTen = Number(grade.totalTen || 0);
        const gpa4 = Number(grade.gpa4 ?? tenToFourForAdmin(totalTen));

        const status = (grade.status || "").toString() ||
            (totalTen >= 5 ? "Pass" : "Fail");

        return {
            gradeId: grade.id,
            classId,
            classCode: cls.classCode || "",
            courseId: cls.courseId || "",
            courseName: course.courseName || cls.courseName || "Chưa rõ môn",
            courseCode: course.courseCode || "",
            credits: Number(course.credits || 0),
            scoreProcess,
            scoreMid,
            scoreFinal,
            totalTen,
            gpa4,
            status,
            updatedAt: toISOStringSafe(grade.updatedAt),
        };
    });

    const completedItems = items.filter((x) => Number(x.totalTen || 0) > 0);

    const passedItems = completedItems.filter((x) => {
        const status = (x.status || "").toString();
        return status === "Pass" || Number(x.totalTen || 0) >= 5;
    });

    const failedItems = completedItems.filter((x) => {
        const status = (x.status || "").toString();
        return status === "Fail" || Number(x.totalTen || 0) < 5;
    });

    let totalWeightedGpa = 0;
    let totalCredits = 0;

    for (const item of completedItems) {
        const credits = Number(item.credits || 0) > 0 ? Number(item.credits) : 1;
        totalWeightedGpa += Number(item.gpa4 || 0) * credits;
        totalCredits += credits;
    }

    const avgGpa4 = totalCredits > 0
        ? roundForAdmin(totalWeightedGpa / totalCredits, 2)
        : 0;

    const avgTotalTen = completedItems.length > 0
        ? roundForAdmin(
            completedItems.reduce((sum, x) => sum + Number(x.totalTen || 0), 0) /
            completedItems.length,
            2
        )
        : 0;

    items.sort((a, b) => {
        const codeA = (a.courseCode || "").toString();
        const codeB = (b.courseCode || "").toString();

        if (codeA && codeB) return codeA.localeCompare(codeB);

        return (a.courseName || "").localeCompare(b.courseName || "");
    });

    return {
        studentId: uid,
        studentName: user.fullName || "",
        studentCode: user.studentInfo?.studentCode || "",
        summary: {
            totalSubjects: items.length,
            completedSubjects: completedItems.length,
            passedSubjects: passedItems.length,
            failedSubjects: failedItems.length,
            avgTotalTen,
            avgGpa4,
        },
        items,
    };
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
    createUserByAdmin,
    importUsersByAdmin,
    checkImportUsersByAdmin,
    getMyProfile,
    updateMyProfile,
    getStudentLearningOverviewForAdmin,
};