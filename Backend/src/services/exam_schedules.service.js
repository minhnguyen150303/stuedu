const { db } = require("../config/firebase");

function toISOStringSafe(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();
    return value;
}

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    return month >= 7 ? academicStartYear : academicStartYear + 1;
}

function parseAcademicStartYear(value) {
    const text = (value || "").toString();
    const match = text.match(/\d{4}/);
    return match ? Number(match[0]) : getAcademicStartYear();
}

function buildStudyEndAtFromCycle(semester, cls) {
    const studyEndMonth = Number(semester.studyEndMonth || 0);
    const studyEndDay = Number(semester.studyEndDay || 0);

    if (!studyEndMonth || !studyEndDay) return null;

    const academicStartYear = parseAcademicStartYear(
        cls.academicYearSnapshot || semester.academicYear
    );

    const year = getDateYearForAcademicCycle(studyEndMonth, academicStartYear);

    return new Date(Date.UTC(year, studyEndMonth - 1, studyEndDay, 23, 59, 59));
}

function getStudyEndAt(semester = {}, cls = {}) {
    return (
        parseDateSafe(
            semester.studyEndAt ||
            semester.studyEndDate ||
            semester.endDate ||
            semester.endAt ||
            semester.timeline?.studyEndAt ||
            semester.semesterTimeline?.studyEndAt
        ) || buildStudyEndAtFromCycle(semester, cls)
    );
}

function parseDateSafe(value) {
    if (!value) return null;

    if (value instanceof Date) return value;

    if (typeof value.toDate === "function") {
        return value.toDate();
    }

    if (typeof value === "string") {
        const dt = new Date(value);
        return Number.isNaN(dt.getTime()) ? null : dt;
    }

    if (typeof value === "object") {
        if (value._seconds) return new Date(value._seconds * 1000);
        if (value.seconds) return new Date(value.seconds * 1000);
    }

    return null;
}

function mapDoc(doc) {
    const data = doc.data() || {};

    return {
        id: doc.id,
        courseId: data.courseId || "",
        semesterId: data.semesterId || "",
        examDate: toISOStringSafe(data.examDate),
        examRoom: data.examRoom || "",
        examType: data.examType || "final",
        note: data.note || "",
        createdBy: data.createdBy || "",
        createdAt: toISOStringSafe(data.createdAt),
        updatedAt: toISOStringSafe(data.updatedAt),
    };
}

async function listExamSchedules(query = {}) {
    let ref = db.collection("exam_schedules");

    if (query.courseId) {
        ref = ref.where("courseId", "==", query.courseId);
    }

    if (query.semesterId) {
        ref = ref.where("semesterId", "==", query.semesterId);
    }

    const snap = await ref.get();

    const items = snap.docs.map(mapDoc);

    items.sort((a, b) => {
        return new Date(a.examDate || 0) - new Date(b.examDate || 0);
    });

    return items;
}

async function createExamSchedule(data, actor) {
    const courseId = (data.courseId || "").toString();
    const semesterId = (data.semesterId || "").toString();

    if (!courseId || !semesterId) {
        const err = new Error("courseId and semesterId are required");
        err.statusCode = 400;
        throw err;
    }

    const duplicate = await db.collection("exam_schedules")
        .where("courseId", "==", courseId)
        .where("semesterId", "==", semesterId)
        .where("examType", "==", data.examType || "final")
        .limit(1)
        .get();

    if (!duplicate.empty) {
        const err = new Error("Exam schedule already exists for this course and semester");
        err.statusCode = 409;
        throw err;
    }

    const docRef = await db.collection("exam_schedules").add({
        courseId,
        semesterId,
        examDate: data.examDate ? new Date(data.examDate) : null,
        examRoom: data.examRoom || "",
        examType: data.examType || "final",
        note: data.note || "",
        createdBy: actor?.uid || "",
        createdAt: new Date(),
        updatedAt: new Date(),
    });

    const after = await docRef.get();
    return mapDoc(after);
}

async function updateExamSchedule(id, patch) {
    const ref = db.collection("exam_schedules").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Exam schedule not found");
        err.statusCode = 404;
        throw err;
    }

    const payload = {
        updatedAt: new Date(),
    };

    if (patch.courseId !== undefined) payload.courseId = patch.courseId;
    if (patch.semesterId !== undefined) payload.semesterId = patch.semesterId;
    if (patch.examDate !== undefined) {
        payload.examDate = patch.examDate ? new Date(patch.examDate) : null;
    }
    if (patch.examRoom !== undefined) payload.examRoom = patch.examRoom;
    if (patch.examType !== undefined) payload.examType = patch.examType;
    if (patch.note !== undefined) payload.note = patch.note;

    await ref.set(payload, { merge: true });

    const after = await ref.get();
    return mapDoc(after);
}

async function deleteExamSchedule(id) {
    const ref = db.collection("exam_schedules").doc(id);
    const snap = await ref.get();

    if (!snap.exists) {
        const err = new Error("Exam schedule not found");
        err.statusCode = 404;
        throw err;
    }

    await ref.delete();

    return {
        id,
        deleted: true,
    };
}

async function checkImportExamSchedules({ rows = [] }) {
    const results = [];
    const seenCourseCodes = new Set();

    for (let i = 0; i < rows.length; i++) {
        const row = rows[i] || {};

        const rowNumber = row.rowNumber || i + 2;
        const courseCode = (row.courseCode || "").toString().trim();
        const examDateRaw = (row.examDate || "").toString().trim();
        const examTime = (row.examTime || "").toString().trim();
        const examRoom = (row.examRoom || "").toString().trim();
        const note = (row.note || "").toString().trim();

        const errors = [];

        if (!courseCode) errors.push("Thiếu mã môn học");
        if (!examDateRaw) errors.push("Thiếu ngày thi");
        if (!examTime) errors.push("Thiếu giờ thi");
        if (!examRoom) errors.push("Thiếu phòng thi");

        if (courseCode && seenCourseCodes.has(courseCode)) {
            errors.push("Mã môn học bị trùng trong file Excel");
        }

        if (courseCode) {
            seenCourseCodes.add(courseCode);
        }

        let courseId = "";
        let courseName = "";
        let semesterId = "";
        let examDate = null;

        if (examDateRaw && examTime) {
            examDate = buildExamDate(examDateRaw, examTime);

            if (!examDate || Number.isNaN(examDate.getTime())) {
                errors.push("Ngày giờ thi không hợp lệ");
            }
        }

        if (courseCode) {
            const courseSnap = await db.collection("courses")
                .where("courseCode", "==", courseCode)
                .limit(1)
                .get();

            if (courseSnap.empty) {
                errors.push("Không tìm thấy môn học");
            } else {
                const courseDoc = courseSnap.docs[0];
                const course = courseDoc.data() || {};

                courseId = courseDoc.id;
                courseName = course.courseName || "";

                const classSnap = await db.collection("classes")
                    .where("courseId", "==", courseId)
                    .where("adminState", "==", "active")
                    .limit(1)
                    .get();

                if (classSnap.empty) {
                    errors.push("Môn học chưa có lớp active");
                } else {
                    const cls = classSnap.docs[0].data() || {};
                    semesterId = (cls.semesterId || "").toString();

                    if (!semesterId) {
                        errors.push("Không xác định được học kỳ của môn học");
                    } else {
                        const semesterSnap = await db
                            .collection("semester_cycles")
                            .doc(semesterId)
                            .get();

                        if (!semesterSnap.exists) {
                            errors.push("Không tìm thấy học kỳ");
                        } else {
                            const semester = semesterSnap.data() || {};
                            const studyEndAt = getStudyEndAt(semester, cls);

                            if (!studyEndAt || Number.isNaN(studyEndAt.getTime())) {
                                errors.push("Học kỳ chưa có ngày kết thúc hợp lệ");
                            } else if (examDate) {
                                const minDate = new Date(
                                    studyEndAt.getFullYear(),
                                    studyEndAt.getMonth(),
                                    studyEndAt.getDate()
                                );

                                const maxDate = new Date(minDate);
                                maxDate.setDate(maxDate.getDate() + 15);

                                if (examDate < minDate || examDate > maxDate) {
                                    errors.push("Ngày thi phải nằm trong khoảng kết thúc học kỳ đến 15 ngày sau");
                                }
                            }

                            const existedSnap = await db.collection("exam_schedules")
                                .where("courseId", "==", courseId)
                                .where("semesterId", "==", semesterId)
                                .limit(1)
                                .get();

                            if (!existedSnap.empty) {
                                errors.push("Môn học này đã có lịch thi trong học kỳ hiện tại");
                            }
                        }
                    }
                }
            }
        }

        results.push({
            rowNumber,
            courseCode,
            courseId,
            courseName,
            semesterId,
            examDate: examDate ? examDate.toISOString() : "",
            examTime,
            examRoom,
            note,
            valid: errors.length === 0,
            errors,
        });
    }

    return { results };
}

async function importExamSchedules({ rows = [] }) {
    const checked = await checkImportExamSchedules({ rows });
    const validRows = checked.results.filter((row) => row.valid);

    let success = 0;
    let failed = checked.results.length - validRows.length;
    const results = [];

    for (const row of validRows) {
        try {
            const payload = {
                courseId: row.courseId,
                semesterId: row.semesterId,
                examDate: row.examDate ? new Date(row.examDate) : null,
                examRoom: row.examRoom,
                examType: "final",
                note: row.note || "",
                createdAt: new Date(),
                updatedAt: new Date(),
            };

            const ref = await db.collection("exam_schedules").add(payload);

            success += 1;

            results.push({
                ...row,
                id: ref.id,
                success: true,
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

function buildExamDate(examDateRaw, examTime) {
    const dateText = (examDateRaw || "").toString().trim();
    const timeText = (examTime || "").toString().trim();

    if (!dateText) return null;

    // Nếu lần import gửi lại ISO từ bước check
    if (dateText.includes("T")) {
        const dt = new Date(dateText);
        return Number.isNaN(dt.getTime()) ? null : dt;
    }

    let year, month, day;

    if (dateText.includes("/")) {
        const parts = dateText.split("/");
        day = Number(parts[0]);
        month = Number(parts[1]);
        year = Number(parts[2]);
    } else if (dateText.includes("-")) {
        const parts = dateText.split("-");
        year = Number(parts[0]);
        month = Number(parts[1]);
        day = Number(parts[2]);
    } else if (!Number.isNaN(Number(dateText))) {
        // Excel serial date
        const serial = Number(dateText);
        const excelEpoch = new Date(Date.UTC(1899, 11, 30));
        const dt = new Date(excelEpoch.getTime() + serial * 86400000);
        year = dt.getUTCFullYear();
        month = dt.getUTCMonth() + 1;
        day = dt.getUTCDate();
    }

    let hour = 0;
    let minute = 0;

    if (timeText.includes(":")) {
        const timeParts = timeText.split(":");
        hour = Number(timeParts[0]);
        minute = Number(timeParts[1] || 0);
    } else if (!Number.isNaN(Number(timeText)) && Number(timeText) > 0 && Number(timeText) < 1) {
        // Excel time fraction: 0.5 = 12:00
        const totalMinutes = Math.round(Number(timeText) * 24 * 60);
        hour = Math.floor(totalMinutes / 60);
        minute = totalMinutes % 60;
    } else if (timeText) {
        return null;
    }

    if (!year || !month || !day || Number.isNaN(hour) || Number.isNaN(minute)) {
        return null;
    }

    return new Date(year, month - 1, day, hour, minute, 0);
}

module.exports = {
    listExamSchedules,
    createExamSchedule,
    updateExamSchedule,
    deleteExamSchedule,
    checkImportExamSchedules,
    importExamSchedules,
};