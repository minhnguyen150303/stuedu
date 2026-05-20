const service = require("../services/semesters.service");

async function list(req, res) {
    const data = await service.listSemesters(req.query);
    res.json(data);
}

async function current(req, res) {
    const data = await service.getCurrentSemester(req.query);
    if (!data) {
        return res.status(404).json({ error: "No current semester" });
    }
    res.json(data);
}

async function create(req, res) {
    const result = await service.createSemester(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateSemester(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteSemester(req.params.id);
    res.json({ message: "Deleted", ...result });
}

async function setCurrent(req, res) {
    const result = await service.setCurrentSemester(req.params.id);
    res.json({ message: "Updated", ...result });
}

module.exports = { list, current, create, update, remove, setCurrent };