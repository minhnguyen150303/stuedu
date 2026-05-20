const enrollmentService = require("../services/enrollments.service");

async function list(req, res) {
    const data = await enrollmentService.listEnrollments(req.query);
    res.json(data);
}

async function approve(req, res) {
    const { id } = req.params;
    const result = await enrollmentService.approveEnrollment(id);
    res.json({ message: "Approved", ...result });
}

async function listUsersByClass(req, res) {
    const data = await enrollmentService.listEnrollmentUsersByClass({
        classId: req.params.classId,
        status: req.query.status,
    });
    res.json(data);
}

module.exports = { list, approve, listUsersByClass };