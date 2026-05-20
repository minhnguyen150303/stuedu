const service = require("../services/grades.service");

async function upsert(req, res) {
    const result = await service.upsertGrade(req.body);
    res.status(201).json({ message: "Upserted", ...result });
}

async function list(req, res) {
    const data = await service.listGrades(req.query);
    res.json(data);
}

module.exports = { upsert, list };