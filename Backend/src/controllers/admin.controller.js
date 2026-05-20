const userService = require("../services/users.service");

async function setRole(req, res) {
    const { uid } = req.params;
    const { role } = req.body;
    const result = await userService.setUserRole(uid, role);
    res.json({ message: "Role updated", ...result });
}

async function userStats(req, res) {
    const data = await userService.getUserStats();
    res.json(data);
}

async function listUsers(req, res) {
    const data = await userService.listUsersForAdmin(req.query);
    res.json(data);
}

async function getUserDetail(req, res) {
    const data = await userService.getUserDetailForAdmin(req.params.uid);
    res.json(data);
}

async function updateUser(req, res) {
    const data = await userService.updateUserProfileByAdmin(req.params.uid, req.body);
    res.json({ message: "User updated", ...data });
}

async function lockUser(req, res) {
    const disabled = req.body?.disabled ?? true;
    const data = await userService.setUserLockByAdmin(req.params.uid, !!disabled);
    res.json({
        message: disabled ? "User locked" : "User unlocked",
        ...data,
    });
}

async function deleteUser(req, res) {
    const data = await userService.deleteUserByAdmin(req.params.uid);
    res.json({ message: "User deleted", ...data });
}

async function listTeachersByMajor(req, res) {
    const majorId = (req.query.majorId || "").toString();
    const data = await userService.listTeachersByMajor(majorId);
    res.json(data);
}

module.exports = {
    setRole,
    userStats,
    listUsers,
    getUserDetail,
    updateUser,
    lockUser,
    deleteUser,
    listTeachersByMajor,
};