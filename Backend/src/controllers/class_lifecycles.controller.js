const service = require("../services/class_lifecycles.service");

async function list(req, res) {
    const items = await service.listClassLifecycles(req.query);
    res.json(items);
}

async function create(req, res) {
    const item = await service.createClassLifecycle(req.body);
    res.status(201).json(item);
}

async function update(req, res) {
    const item = await service.updateClassLifecycle(req.params.id, req.body);
    res.json(item);
}

async function hide(req, res) {
    const item = await service.hideClassLifecycle(req.params.id);
    res.json(item);
}

async function replace(req, res) {
    const item = await service.replaceClassLifecycle(req.params.id, req.body);
    res.json(item);
}

module.exports = {
    list,
    create,
    update,
    hide,
    replace,
};