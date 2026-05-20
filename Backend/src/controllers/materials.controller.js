const service = require("../services/materials.service");

async function list(req, res) {
    res.json(await service.listMaterials(req.query));
}

async function create(req, res) {
    const result = await service.createMaterial(req.user.uid, req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateMaterial(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteMaterial(req.params.id);
    res.json({ message: "Deleted", ...result });
}

module.exports = { list, create, update, remove };