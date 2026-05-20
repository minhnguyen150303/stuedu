const service = require("../services/notifications.service");

async function create(req, res) {
    const result = await service.createNotification(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function list(req, res) {
    const role = (req.user?.role || "").toString();
    const requestedReceiverId = (req.query.receiverId || "").toString();

    let receiverId = req.user.uid;

    if (role === "admin" && requestedReceiverId) {
        receiverId = requestedReceiverId;
    }

    const data = await service.listNotifications({ receiverId });
    res.json(data);
}

async function read(req, res) {
    const result = await service.markRead(req.params.id, req.user);
    res.json({ message: "Read", ...result });
}
module.exports = { create, list, read };