const service = require("../services/majors.service");

async function list(req, res) {
    const data = await service.listMajors();
    res.json(data);
}

async function create(req, res) {
    const result = await service.createMajor(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await service.updateMajor(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function hide(req, res) {
    const result = await service.hideMajor(req.params.id);
    res.json({ message: "Hidden", ...result });
}

async function show(req, res) {
    const result = await service.showMajor(req.params.id);
    res.json({ message: "Shown", ...result });
}

// Giữ route delete cũ nhưng đổi hành vi thành ẩn.
async function remove(req, res) {
    const result = await service.hideMajor(req.params.id);
    res.json({ message: "Hidden", ...result });
}

module.exports = {
    list,
    create,
    update,
    hide,
    show,
    remove,
};