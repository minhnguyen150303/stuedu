const service = require("../services/curriculum.service");

async function list(req, res) {
    const data = await service.listCurriculum(req.query);
    res.json(data);
}

async function create(req, res) {
    const result = await service.createCurriculumItem(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateCurriculumItem(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteCurriculumItem(req.params.id);
    res.json({ message: "Deleted", ...result });
}

module.exports = { list, create, update, remove };