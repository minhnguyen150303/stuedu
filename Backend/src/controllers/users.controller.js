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

async function getMyProfile(req, res) {
    const data = await userService.getMyProfile(req.user.uid);

    res.json(data);
}

async function updateMyProfile(req, res) {
    const data = await userService.updateMyProfile(
        req.user.uid,
        req.body
    );

    res.json(data);
}

module.exports = {
    updateSettings, addToken, removeToken, getMyProfile,
    updateMyProfile,
};