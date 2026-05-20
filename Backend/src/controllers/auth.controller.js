const userService = require("../services/users.service");

async function me(req, res) {
    // req.user được gán từ requireAuth middleware
    const profile = await userService.ensureUserProfile(req.user);
    res.json(profile);
}

module.exports = { me };