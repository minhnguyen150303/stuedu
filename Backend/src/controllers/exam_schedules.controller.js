const service = require("../services/exam_schedules.service");

async function list(req, res) {
    const data = await service.listExamSchedules(req.query);
    res.json(data);
}

async function create(req, res) {
    const result = await service.createExamSchedule(req.body, req.user);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateExamSchedule(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteExamSchedule(req.params.id);
    res.json({ message: "Deleted", ...result });
}

async function checkImportExamSchedules(req, res) {
    const result = await service.checkImportExamSchedules({
        rows: req.body.rows || [],
    });

    res.json(result);
}

async function importExamSchedules(req, res) {
    const result = await service.importExamSchedules({
        rows: req.body.rows || [],
    });

    res.json(result);
}

module.exports = {
    list,
    create,
    update,
    remove,
    checkImportExamSchedules,
    importExamSchedules,
};