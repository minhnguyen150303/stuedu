const userService = require("../services/users.service");
const { auth } = require("../config/firebase");
const { sendPasswordResetEmail } = require("../services/mail.service");

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

async function forgotPassword(req, res) {
    const email = (req.body.email || "").toString().trim();

    if (!email) {
        return res.status(400).json({ error: "email is required" });
    }

    try {
        const resetLink = await auth.generatePasswordResetLink(email);

        await sendPasswordResetEmail({
            to: email,
            resetLink,
        });

        return res.json({
            message: "Password reset email sent",
        });
    } catch (err) {
        console.error("forgotPassword error:", err);

        return res.status(500).json({
            error: "Cannot send password reset email",
        });
    }
}

module.exports = {
    updateSettings, addToken, removeToken, getMyProfile,
    updateMyProfile, forgotPassword,
};