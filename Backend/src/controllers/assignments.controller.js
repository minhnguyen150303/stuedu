const service = require("../services/assignments.service");

async function create(req, res) {
    const result = await service.createAssignment(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function list(req, res) {
    const data = await service.listAssignments(req.query, req.user || null);
    res.json(data);
}

async function update(req, res) {
    const result = await service.updateAssignment(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteAssignment(req.params.id);
    res.json({ message: "Deleted", ...result });
}

async function submit(req, res) {
    const result = await service.submitAssignment({
        assignmentId: req.params.id,
        studentId: req.user.uid,
        file: req.body,
    });

    res.status(result.replaced ? 200 : 201).json({
        message: result.replaced ? "Resubmitted" : "Submitted",
        ...result,
    });
}

async function gradeSubmission(req, res) {
    const result = await service.gradeAssignmentSubmission({
        assignmentId: req.params.id,
        studentId: req.params.studentId,
        teacherId: req.user.uid,
        assignmentScore: req.body.assignmentScore,
    });

    res.json({
        message: "Graded",
        submission: result,
    });
}

module.exports = {
    create,
    list,
    update,
    remove,
    submit,
    gradeSubmission,
};