const { db } = require("../config/firebase");

function calcTotalTen({ scoreProcess = 0, scoreMid = 0, scoreFinal = 0 }) {
    const total = scoreProcess * 0.1 + scoreMid * 0.3 + scoreFinal * 0.6;
    return Math.round(total * 10) / 10;
}
function passFail(totalTen) {
    return totalTen >= 5 ? "Pass" : "Fail";
}

async function upsertGrade(data) {
    const snap = await db.collection("grades")
        .where("classId", "==", data.classId)
        .where("studentId", "==", data.studentId)
        .limit(1)
        .get();

    const scoreProcess = Number(data.scoreProcess ?? 0);
    const scoreMid = Number(data.scoreMid ?? 0);

    const payload = {
        classId: data.classId,
        studentId: data.studentId,
        scoreProcess,
        scoreMid,
        updatedAt: new Date(),
    };

    if (snap.empty) {
        payload.scoreFinal = null;
        payload.totalTen = null;
        payload.status = "Chưa đủ điểm";
        payload.createdAt = new Date();

        const docRef = await db.collection("grades").add(payload);
        return { id: docRef.id, ...payload };
    }

    const doc = snap.docs[0];
    const old = doc.data() || {};

    // Nếu QLSV đã nhập điểm cuối kỳ rồi thì mới tính lại
    if (old.scoreFinal !== null && old.scoreFinal !== undefined) {
        const scoreFinal = Number(old.scoreFinal);
        payload.totalTen = calcTotalTen({ scoreProcess, scoreMid, scoreFinal });
        payload.status = passFail(payload.totalTen);
    } else {
        payload.totalTen = null;
        payload.status = "Chưa đủ điểm";
    }

    await db.collection("grades").doc(doc.id).set(payload, { merge: true });
    return { id: doc.id, ...payload };
}

async function upsertFinalGrade(data) {
    const snap = await db.collection("grades")
        .where("classId", "==", data.classId)
        .where("studentId", "==", data.studentId)
        .limit(1)
        .get();

    const scoreFinal = Number(data.scoreFinal ?? 0);

    if (snap.empty) {
        const payload = {
            classId: data.classId,
            studentId: data.studentId,
            scoreProcess: null,
            scoreMid: null,
            scoreFinal,
            totalTen: null,
            status: "Chưa đủ điểm",
            finalUpdatedAt: new Date(),
            createdAt: new Date(),
            updatedAt: new Date(),
        };

        const docRef = await db.collection("grades").add(payload);
        return { id: docRef.id, ...payload };
    }

    const doc = snap.docs[0];
    const old = doc.data() || {};

    const scoreProcess = old.scoreProcess;
    const scoreMid = old.scoreMid;

    const payload = {
        scoreFinal,
        finalUpdatedAt: new Date(),
        updatedAt: new Date(),
    };

    if (
        scoreProcess !== null &&
        scoreProcess !== undefined &&
        scoreMid !== null &&
        scoreMid !== undefined
    ) {
        payload.totalTen = calcTotalTen({
            scoreProcess: Number(scoreProcess),
            scoreMid: Number(scoreMid),
            scoreFinal,
        });
        payload.status = passFail(payload.totalTen);
    } else {
        payload.totalTen = null;
        payload.status = "Chưa đủ điểm";
    }

    await db.collection("grades").doc(doc.id).set(payload, { merge: true });
    return { id: doc.id, ...payload };
}

async function listGrades(query) {
    let ref = db.collection("grades");
    if (query.classId) ref = ref.where("classId", "==", query.classId);
    if (query.studentId) ref = ref.where("studentId", "==", query.studentId);
    const snap = await ref.get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function checkImportTeacherGrades({ classId, rows = [] }) {
    if (!classId) {
        const err = new Error("classId is required");
        err.statusCode = 400;
        throw err;
    }

    const enrollmentSnap = await db.collection("enrollments")
        .where("classId", "==", classId)
        .where("status", "==", "approved")
        .get();

    const studentIds = enrollmentSnap.docs.map(doc => {
        const data = doc.data() || {};
        return (data.studentId || "").toString();
    });

    const studentMapByCode = {};

    for (const studentId of studentIds) {
        const userSnap = await db.collection("users").doc(studentId).get();
        if (!userSnap.exists) continue;

        const user = userSnap.data() || {};
        const studentCode = (
            user.studentInfo?.studentCode ||
            user.studentCode ||
            ""
        ).toString().trim();

        if (studentCode) {
            studentMapByCode[studentCode] = {
                uid: userSnap.id,
                fullName: user.fullName || "",
                studentCode,
            };
        }
    }

    const seenCodes = new Set();
    const results = [];

    for (let index = 0; index < rows.length; index++) {
        const row = rows[index] || {};
        const studentCode = (row.studentCode || "").toString().trim();
        const scoreProcess = Number(row.scoreProcess);
        const scoreMid = Number(row.scoreMid);
        const errors = [];

        if (!studentCode) errors.push("Thiếu mã sinh viên");

        if (studentCode && seenCodes.has(studentCode)) {
            errors.push("Mã sinh viên bị trùng trong file Excel");
        }

        if (studentCode) seenCodes.add(studentCode);

        const student = studentMapByCode[studentCode] || null;

        if (studentCode && !student) {
            errors.push("Sinh viên không thuộc lớp này");
        }

        if (Number.isNaN(scoreProcess) || scoreProcess < 0 || scoreProcess > 10) {
            errors.push("Điểm chuyên cần phải từ 0 đến 10");
        }

        if (Number.isNaN(scoreMid) || scoreMid < 0 || scoreMid > 10) {
            errors.push("Điểm giữa kỳ phải từ 0 đến 10");
        }

        if (student) {
            const gradeSnap = await db.collection("grades")
                .where("classId", "==", classId)
                .where("studentId", "==", student.uid)
                .limit(1)
                .get();

            if (!gradeSnap.empty) {
                const grade = gradeSnap.docs[0].data() || {};

                const hasProcess = grade.scoreProcess !== null &&
                    grade.scoreProcess !== undefined &&
                    grade.scoreProcess !== "";

                const hasMid = grade.scoreMid !== null &&
                    grade.scoreMid !== undefined &&
                    grade.scoreMid !== "";

                if (hasProcess || hasMid) {
                    errors.push("Sinh viên này đã có điểm chuyên cần / giữa kỳ");
                }
            }
        }

        results.push({
            rowNumber: row.rowNumber || index + 2,
            studentCode,
            studentId: student?.uid || "",
            fullName: student?.fullName || "",
            scoreProcess,
            scoreMid,
            valid: errors.length === 0,
            errors,
        });
    }

    return { results };
}

async function importTeacherGrades({ classId, rows = [] }) {
    const checked = await checkImportTeacherGrades({ classId, rows });
    const checkedRows = checked.results;
    const validRows = checkedRows.filter((row) => row.valid);

    let success = 0;
    let failed = checkedRows.length - validRows.length;
    const results = [];

    for (const row of validRows) {
        try {
            await upsertGrade({
                classId,
                studentId: row.studentId,
                scoreProcess: row.scoreProcess,
                scoreMid: row.scoreMid,
            });

            success += 1;
            results.push({ ...row, success: true });
        } catch (error) {
            failed += 1;
            results.push({
                ...row,
                success: false,
                errors: [error.message || "Import failed"],
            });
        }
    }

    return {
        total: checkedRows.length,
        success,
        failed,
        invalid: checkedRows.length - validRows.length,
        results: [...checkedRows.filter((row) => !row.valid), ...results],
    };
}

async function checkImportFinalGrades({ classId, rows = [] }) {
    if (!classId) {
        const err = new Error("classId is required");
        err.statusCode = 400;
        throw err;
    }

    const classSnap = await db.collection("classes").doc(classId).get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const results = [];
    const seenCodes = new Set();

    for (let i = 0; i < rows.length; i++) {
        const row = rows[i] || {};

        const rowNumber = row.rowNumber || i + 2;
        const studentCode = (row.studentCode || "").toString().trim();
        const scoreFinal = Number(row.scoreFinal);

        const errors = [];

        if (!studentCode) errors.push("Thiếu mã sinh viên");

        if (studentCode && seenCodes.has(studentCode)) {
            errors.push("Mã sinh viên bị trùng trong file Excel");
        }

        if (studentCode) seenCodes.add(studentCode);

        if (Number.isNaN(scoreFinal) || scoreFinal < 0 || scoreFinal > 10) {
            errors.push("Điểm cuối kỳ phải từ 0 đến 10");
        }

        let studentId = "";
        let fullName = "";
        let gradeId = "";

        if (studentCode) {
            const usersSnap = await db.collection("users")
                .where("role", "==", "student")
                .get();

            let matchedStudent = null;

            for (const doc of usersSnap.docs) {
                const user = doc.data() || {};
                const code = (
                    user.studentInfo?.studentCode ||
                    user.studentCode ||
                    ""
                ).toString().trim();

                if (code === studentCode) {
                    matchedStudent = {
                        uid: doc.id,
                        ...user,
                    };
                    break;
                }
            }

            if (!matchedStudent) {
                errors.push("Không tìm thấy sinh viên");
            } else {
                studentId = matchedStudent.uid;
                fullName = matchedStudent.fullName || "";

                const enrollmentSnap = await db.collection("enrollments")
                    .where("classId", "==", classId)
                    .where("studentId", "==", studentId)
                    .where("status", "==", "approved")
                    .limit(1)
                    .get();

                if (enrollmentSnap.empty) {
                    errors.push("Sinh viên không thuộc lớp này");
                }

                const gradeSnap = await db.collection("grades")
                    .where("classId", "==", classId)
                    .where("studentId", "==", studentId)
                    .limit(1)
                    .get();

                if (gradeSnap.empty) {
                    errors.push("Sinh viên chưa có điểm chuyên cần và giữa kỳ");
                } else {
                    const gradeDoc = gradeSnap.docs[0];
                    const grade = gradeDoc.data() || {};
                    gradeId = gradeDoc.id;

                    const hasProcess =
                        grade.scoreProcess !== undefined &&
                        grade.scoreProcess !== null &&
                        grade.scoreProcess !== "";

                    const hasMid =
                        grade.scoreMid !== undefined &&
                        grade.scoreMid !== null &&
                        grade.scoreMid !== "";

                    if (!hasProcess || !hasMid) {
                        errors.push("Sinh viên chưa đủ điểm chuyên cần và giữa kỳ");
                    }

                    if (
                        grade.scoreFinal !== undefined &&
                        grade.scoreFinal !== null &&
                        grade.scoreFinal !== ""
                    ) {
                        errors.push("Sinh viên này đã có điểm cuối kỳ");
                    }
                }
            }
        }

        results.push({
            rowNumber,
            classId,
            studentCode,
            studentId,
            fullName,
            gradeId,
            scoreFinal,
            valid: errors.length === 0,
            errors,
        });
    }

    return { results };
}

async function importFinalGrades({ classId, rows = [] }) {
    const checked = await checkImportFinalGrades({ classId, rows });
    const validRows = checked.results.filter((row) => row.valid);

    let success = 0;
    let failed = checked.results.length - validRows.length;
    const results = [];

    for (const row of validRows) {
        try {
            const gradeRef = db.collection("grades").doc(row.gradeId);
            const snap = await gradeRef.get();
            const old = snap.data() || {};

            const scoreProcess = Number(old.scoreProcess);
            const scoreMid = Number(old.scoreMid);
            const scoreFinal = Number(row.scoreFinal);

            const totalTen = calcTotalTen({
                scoreProcess,
                scoreMid,
                scoreFinal,
            });

            const status = passFail(totalTen);

            await gradeRef.set(
                {
                    scoreFinal,
                    totalTen,
                    status,
                    finalUpdatedAt: new Date(),
                    updatedAt: new Date(),
                },
                { merge: true }
            );

            success += 1;

            results.push({
                ...row,
                success: true,
                totalTen,
                status,
            });
        } catch (error) {
            failed += 1;

            results.push({
                ...row,
                success: false,
                errors: [error.message || "Import failed"],
            });
        }
    }

    return {
        total: checked.results.length,
        success,
        failed,
        invalid: checked.results.length - validRows.length,
        results: [...checked.results.filter((row) => !row.valid), ...results],
    };
}

module.exports = {
    upsertGrade, upsertFinalGrade, listGrades, checkImportTeacherGrades,
    importTeacherGrades, checkImportFinalGrades,
    importFinalGrades,
};