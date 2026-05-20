const service = require("../services/notification_campaigns.service");

async function create(req, res) {
    const result = await service.createCampaign(req.body, req.user);
    res.status(201).json({ message: "Created", ...result });
}

async function list(req, res) {
    const data = await service.listCampaigns();
    res.json(data);
}

async function update(req, res) {
    const result = await service.updateCampaign(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await service.deleteCampaign(req.params.id);
    res.json({ message: "Deleted", ...result });
}

module.exports = {
    create,
    list,
    update,
    remove,
};