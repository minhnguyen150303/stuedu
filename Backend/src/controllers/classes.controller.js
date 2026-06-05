const classService = require("../services/classes.service");
const enrollmentService = require("../services/enrollments.service");
const { db } = require("../config/firebase");

async function create(req, res) {
    const result = await classService.createClass(req.body);
    res.status(201).json({
        message: "Created",
        ...result,
    });
}

async function list(req, res) {
    const data = await classService.listClasses(req.query);
    res.json(data);
}

async function update(req, res) {
    const result = await classService.updateClass(req.params.id, req.body);
    res.json({
        message: "Updated",
        ...result,
    });
}

async function archive(req, res) {
    const result = await classService.archiveClass(req.params.id);
    res.json({
        message: "Class archived",
        ...result,
    });
}

async function replace(req, res) {
    const result = await classService.replaceClass(req.params.id, req.body || {});
    res.status(201).json({
        message: "Class replaced by new life",
        ...result,
    });
}

async function reopen(req, res) {
    const result = await classService.reopenClassFromOld(
        req.params.id,
        req.body || {}
    );

    res.status(201).json({
        message: "New class life created from old class",
        ...result,
    });
}

async function joinByCode(req, res) {
    const { classCode, studentId } = req.body;

    const cls = await classService.findClassByCode(classCode);
    if (!cls) {
        return res
            .status(404)
            .json({ error: "Không tìm thấy lớp với classCode này" });
    }

    const result = await enrollmentService.createEnrollmentPending({
        classId: cls.id,
        studentId,
    });

    res.status(result.already ? 200 : 201).json({
        message: result.already ? "Đã join trước đó" : "Join pending",
        enrollmentId: result.id,
        status: result.status,
        classId: cls.id,
    });
}

async function toggleVisibility(req, res) {
    const result = await classService.toggleClassVisibility(
        req.params.id,
        req.body.isVisibleForRegistration
    );

    res.json({
        message: "Visibility updated",
        ...result,
    });
}

async function addStudent(req, res) {
    await assertCanManageClassStudents(req, req.params.id);

    const result = await enrollmentService.addStudentToClassByAdmin({
        classId: req.params.id,
        studentId: req.body.studentId,
        adminUid: req.user.uid,
    });

    res.status(result.already ? 200 : 201).json({
        message: result.already
            ? "Sinh viên đã có trong lớp"
            : "Đã thêm sinh viên vào lớp",
        ...result,
    });
}

async function availableStudents(req, res) {
    await assertCanManageClassStudents(req, req.params.id);

    const data = await enrollmentService.listAvailableStudentsForClass({
        classId: req.params.id,
        q: req.query.q || "",
    });

    res.json(data);
}

async function assertCanManageClassStudents(req, classId) {
    const role = (req.user?.role || "").toString();
    const uid = (req.user?.uid || "").toString();

    if (role === "admin") {
        return;
    }

    if (role !== "teacher") {
        const err = new Error("Không có quyền quản lý sinh viên lớp này");
        err.statusCode = 403;
        throw err;
    }

    const classSnap = await db.collection("classes").doc(classId).get();

    if (!classSnap.exists) {
        const err = new Error("Class not found");
        err.statusCode = 404;
        throw err;
    }

    const cls = classSnap.data() || {};
    const teacherId = (cls.teacherId || "").toString();

    if (teacherId !== uid) {
        const err = new Error("Bạn chỉ được quản lý sinh viên trong lớp mình dạy");
        err.statusCode = 403;
        throw err;
    }
}

async function removeStudent(req, res) {
    await assertCanManageClassStudents(req, req.params.id);

    const result = await enrollmentService.removeStudentFromClassByAdmin({
        classId: req.params.id,
        studentId: req.params.studentId,
    });

    res.json({
        message: "Đã xóa sinh viên khỏi lớp",
        ...result,
    });
}

module.exports = {
    create,
    list,
    update,
    archive,
    replace,
    reopen,
    joinByCode,
    toggleVisibility,
    addStudent,
    availableStudents,
    removeStudent,
};