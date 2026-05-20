const userService = require("../services/users.service");

async function updateSettings(req, res) {
    const uid = req.user.uid;
    const profile = await userService.updateMySettings(uid, req.body);
    res.json(profile);
}

async function addToken(req, res) {
    const uid = req.user.uid;
    const profile = await userService.addFcmToken(uid, req.body.token);
    res.json(profile);
}

async function removeToken(req, res) {
    const uid = req.user.uid;
    const profile = await userService.removeFcmToken(uid, req.body.token);
    res.json(profile);
}

module.exports = { updateSettings, addToken, removeToken };