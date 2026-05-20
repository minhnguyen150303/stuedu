const service = require("../services/semester_cycles.service");

async function list(req, res) {
    const data = await service.listSemesterCycles(req.query);
    res.json(data);
}

async function create(req, res) {
    const result = await service.createSemesterCycle(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateSemesterCycle(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteSemesterCycle(req.params.id);
    res.json({ message: "Deleted", ...result });
}

async function history(req, res) {
    const data = await service.listSemesterHistory(req.query);
    res.json(data);
}

module.exports = {
    list,
    create,
    update,
    remove,
    history,
};