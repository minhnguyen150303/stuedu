const { db } = require("../config/firebase");
const { cloudinary } = require("../config/cloudinary");
const { deleteCloudinaryFile } = require("./uploads.service");

function toDateSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate();
    if (value instanceof Date) return value;

    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
}

function toISOStringSafe(value) {
    const d = toDateSafe(value);
    return d ? d.toISOString() : null;
}

function buildAttachmentDownloadUrl(file = {}) {
    const publicId = (file.publicId || "").toString();
    if (!publicId) {
        return (file.url || "").toString();
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

function normalizeAttachment(file = {}) {
    return {
        url: file.url || "",
        publicId: file.publicId || null,
        resourceType: file.resourceType || "raw",
        originalName: file.originalName || null,
        format: file.format || null,
        downloadUrl: buildAttachmentDownloadUrl(file),
    };
}

function mapSubmissionDoc(doc, student = null) {
    const data = doc.data() || {};

    const file = normalizeAttachment({
        url: data.fileUrl || "",
        publicId: data.publicId || null,
        resourceType: data.resourceType || "raw",
        originalName: data.originalName || null,
        format: data.format || null,
    });

    return {
        id: doc.id,
        assignmentId: data.assignmentId || "",
        classId: data.classId || "",
        studentId: data.studentId || "",
        fileUrl: data.fileUrl || "",
        publicId: data.publicId || null,
        resourceType: data.resourceType || "raw",
        originalName: data.originalName || null,
        format: data.format || null,
        submittedAt: toISOStringSafe(data.submittedAt),
        updatedAt: toISOStringSafe(data.updatedAt),

        file,

        student: student
            ? {
                uid: student.uid || "",
                fullName: student.fullName || "Sinh viên",
                email: student.email || "",
                avatarUrl: student.avatarUrl || "",
                studentCode:
                    student.studentInfo?.studentCode ||
                    student.studentCode ||
                    "",
            }
            : null,
    };
}

function mapAssignmentDoc(doc, mySubmission = null, meta = {}) {
    const data = doc.data() || {};

    return {
        id: doc.id,
        classId: data.classId || "",
        title: data.title || "",
        content: data.content || "",
        deadline: toISOStringSafe(data.deadline),
        attachments: Array.isArray(data.attachments)
            ? data.attachments.map((file) => normalizeAttachment(file))
            : [],
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
        mySubmission,

        submissionCount: meta.submissionCount || 0,
        latestSubmittedAt: meta.latestSubmittedAt || null,
        submissions: Array.isArray(meta.submissions) ? meta.submissions : [],
    };
}

async function getUserMapByIds(userIds = []) {
    const uniqueIds = [...new Set(userIds.filter(Boolean))];
    const result = {};

    for (const uid of uniqueIds) {
        const snap = await db.collection("users").doc(uid).get();

        if (!snap.exists) continue;

        result[uid] = {
            uid,
            ...(snap.data() || {}),
        };
    }

    return result;
}

async function getSubmissionDetailsByAssignmentIds(assignmentIds = []) {
    const result = new Map();

    for (const id of assignmentIds) {
        result.set(id, {
            submissionCount: 0,
            latestSubmittedAt: null,
            submissions: [],
        });
    }

    if (!assignmentIds.length) return result;

    const submissionDocs = [];

    for (let i = 0; i < assignmentIds.length; i += 10) {
        const chunk = assignmentIds.slice(i, i + 10);

        const snap = await db
            .collection("assignment_submissions")
            .where("assignmentId", "in", chunk)
            .get();

        for (const doc of snap.docs) {
            submissionDocs.push(doc);
        }
    }

    const studentIds = submissionDocs
        .map((doc) => (doc.data()?.studentId || "").toString())
        .filter(Boolean);

    const userMap = await getUserMapByIds(studentIds);

    for (const doc of submissionDocs) {
        const data = doc.data() || {};
        const assignmentId = (data.assignmentId || "").toString();
        const studentId = (data.studentId || "").toString();

        if (!assignmentId) continue;

        const current = result.get(assignmentId) || {
            submissionCount: 0,
            latestSubmittedAt: null,
            submissions: [],
        };

        const student = userMap[studentId] || null;
        const submission = mapSubmissionDoc(doc, student);

        current.submissionCount += 1;
        current.submissions.push(submission);

        const submittedAt = toDateSafe(data.submittedAt || data.updatedAt);
        const latest = toDateSafe(current.latestSubmittedAt);

        if (submittedAt && (!latest || submittedAt > latest)) {
            current.latestSubmittedAt = submittedAt.toISOString();
        }

        result.set(assignmentId, current);
    }

    for (const value of result.values()) {
        value.submissions.sort((a, b) => {
            const ta = new Date(a.submittedAt || 0).getTime();
            const tb = new Date(b.submittedAt || 0).getTime();
            return tb - ta;
        });
    }

    return result;
}

async function getSubmissionStatsByAssignmentIds(assignmentIds = []) {
    const result = new Map();

    for (const id of assignmentIds) {
        result.set(id, {
            submissionCount: 0,
            latestSubmittedAt: null,
        });
    }

    if (!assignmentIds.length) return result;

    // Firestore "in" giới hạn 10 phần tử, nên chia batch
    const chunks = [];
    for (let i = 0; i < assignmentIds.length; i += 10) {
        chunks.push(assignmentIds.slice(i, i + 10));
    }

    for (const chunk of chunks) {
        const snap = await db
            .collection("assignment_submissions")
            .where("assignmentId", "in", chunk)
            .get();

        for (const doc of snap.docs) {
            const data = doc.data() || {};
            const assignmentId = (data.assignmentId || "").toString();
            if (!assignmentId) continue;

            const current = result.get(assignmentId) || {
                submissionCount: 0,
                latestSubmittedAt: null,
            };

            current.submissionCount += 1;

            const submittedAt = toDateSafe(data.submittedAt || data.updatedAt);
            const currentLatest = toDateSafe(current.latestSubmittedAt);

            if (
                submittedAt &&
                (!currentLatest || submittedAt.getTime() > currentLatest.getTime())
            ) {
                current.latestSubmittedAt = submittedAt.toISOString();
            }

            result.set(assignmentId, current);
        }
    }

    return result;
}

async function createAssignment(data) {
    const docRef = await db.collection("assignments").add({
        classId: data.classId,
        title: data.title,
        content: data.content,
        deadline: new Date(data.deadline),
        attachments: Array.isArray(data.attachments) ? data.attachments : [],
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    return { id: docRef.id };
}

async function listAssignments(query = {}, currentUser = null) {
    let ref = db.collection("assignments");
    if (query.classId) ref = ref.where("classId", "==", query.classId);

    const snap = await ref.get();

    let mySubmissionMap = new Map();
    let submissionDetailsMap = new Map();
    let submissionStatsMap = new Map();

    const assignmentIds = snap.docs.map((doc) => doc.id);

    if (currentUser?.role === "student" && currentUser?.uid) {
        const submissionSnap = await db
            .collection("assignment_submissions")
            .where("studentId", "==", currentUser.uid)
            .get();

        for (const doc of submissionSnap.docs) {
            const submission = mapSubmissionDoc(doc);
            mySubmissionMap.set(submission.assignmentId, submission);
        }
    }

    if (
        currentUser?.role === "teacher" ||
        currentUser?.role === "admin"
    ) {
        submissionStatsMap = await getSubmissionStatsByAssignmentIds(
            assignmentIds
        );
    }

    if (
        currentUser?.role === "teacher" ||
        currentUser?.role === "admin"
    ) {
        submissionDetailsMap = await getSubmissionDetailsByAssignmentIds(
            assignmentIds
        );
    }

    const items = snap.docs.map((doc) => {
        const mySubmission = mySubmissionMap.get(doc.id) || null;
        const meta = submissionDetailsMap.get(doc.id) || {};
        return mapAssignmentDoc(doc, mySubmission, meta);
    });

    items.sort((a, b) => {
        const ta = new Date(a.deadline || 0).getTime();
        const tb = new Date(b.deadline || 0).getTime();
        return ta - tb;
    });

    return items;
}

async function updateAssignment(id, data) {
    const ref = db.collection("assignments").doc(id);
    const snap = await ref.get();
    const assignmentIds = snap.docs.map((doc) => doc.id);

    if (!snap.exists) {
        const err = new Error("Assignment not found");
        err.statusCode = 404;
        throw err;
    }

    const oldData = snap.data() || {};
    const oldAttachments = Array.isArray(oldData.attachments)
        ? oldData.attachments
        : [];

    const newAttachments = Array.isArray(data.attachments)
        ? data.attachments
        : [];

    const newPublicIds = new Set(
        newAttachments.map((file) => file?.publicId).filter(Boolean)
    );

    for (const file of oldAttachments) {
        const oldPublicId = file?.publicId;
        if (oldPublicId && !newPublicIds.has(oldPublicId)) {
            await deleteCloudinaryFile(
                oldPublicId,
                file.resourceType || "raw"
            );
        }
    }

    const payload = {
        classId: data.classId,
        title: data.title,
        content: data.content,
        deadline: new Date(data.deadline),
        updatedAt: new Date(),
        attachments: newAttachments,
    };

    await ref.update(payload);
    return { id };
}

async function deleteAssignment(id) {
    const ref = db.collection("assignments").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Assignment not found");
        err.statusCode = 404;
        throw err;
    }

    const data = snap.data() || {};
    const attachments = Array.isArray(data.attachments) ? data.attachments : [];

    for (const file of attachments) {
        if (file?.publicId) {
            await deleteCloudinaryFile(
                file.publicId,
                file.resourceType || "raw"
            );
        }
    }

    const submissionSnap = await db
        .collection("assignment_submissions")
        .where("assignmentId", "==", id)
        .get();

    const batch = db.batch();

    for (const doc of submissionSnap.docs) {
        const submission = doc.data() || {};

        if (submission.publicId) {
            await deleteCloudinaryFile(
                submission.publicId,
                submission.resourceType || "raw"
            );
        }

        batch.delete(doc.ref);
    }

    batch.delete(ref);
    await batch.commit();

    return { id, deleted: true };
}

async function assertStudentCanSubmit({ assignmentId, studentId }) {
    const assignmentRef = db.collection("assignments").doc(assignmentId);
    const assignmentSnap = await assignmentRef.get();

    if (!assignmentSnap.exists) {
        const err = new Error("Assignment not found");
        err.statusCode = 404;
        throw err;
    }

    const assignment = assignmentSnap.data() || {};
    const classId = (assignment.classId || "").toString();

    if (!classId) {
        const err = new Error("Assignment is missing classId");
        err.statusCode = 409;
        throw err;
    }

    const deadline = toDateSafe(assignment.deadline);
    if (!deadline) {
        const err = new Error("Assignment deadline is invalid");
        err.statusCode = 409;
        throw err;
    }

    if (new Date() > deadline) {
        const err = new Error("Assignment deadline has passed");
        err.statusCode = 409;
        throw err;
    }

    const enrollmentSnap = await db
        .collection("enrollments")
        .where("classId", "==", classId)
        .where("studentId", "==", studentId)
        .where("status", "==", "approved")
        .limit(1)
        .get();

    if (enrollmentSnap.empty) {
        const err = new Error("Student is not enrolled in this class");
        err.statusCode = 403;
        throw err;
    }

    return {
        assignmentId,
        classId,
        deadline,
    };
}

async function submitAssignment({ assignmentId, studentId, file }) {
    const { classId } = await assertStudentCanSubmit({
        assignmentId,
        studentId,
    });

    if (!file || !file.fileUrl) {
        const err = new Error("Submission file is required");
        err.statusCode = 400;
        throw err;
    }

    const existingSnap = await db
        .collection("assignment_submissions")
        .where("assignmentId", "==", assignmentId)
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

    const payload = {
        assignmentId,
        classId,
        studentId,
        fileUrl: file.fileUrl,
        publicId: file.publicId || null,
        resourceType: file.resourceType || "raw",
        originalName: file.originalName || null,
        format: file.format || null,
        updatedAt: new Date(),
    };

    if (existingSnap.empty) {
        const docRef = await db.collection("assignment_submissions").add({
            ...payload,
            submittedAt: new Date(),
        });

        const after = await docRef.get();
        return {
            replaced: false,
            submission: mapSubmissionDoc(after),
        };
    }

    const existingDoc = existingSnap.docs[0];
    const oldData = existingDoc.data() || {};

    if (
        oldData.publicId &&
        payload.publicId &&
        oldData.publicId !== payload.publicId
    ) {
        await deleteCloudinaryFile(
            oldData.publicId,
            oldData.resourceType || "raw"
        );
    }

    await existingDoc.ref.set(payload, { merge: true });

    const after = await existingDoc.ref.get();
    return {
        replaced: true,
        submission: mapSubmissionDoc(after),
    };
}

module.exports = {
    createAssignment,
    listAssignments,
    updateAssignment,
    deleteAssignment,
    submitAssignment,
};
