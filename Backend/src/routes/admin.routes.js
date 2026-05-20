const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateRolePatch,
    validateAdminUserUpdate,
    validateUserLockPatch,
} = require("../models/validators");
const controller = require("../controllers/admin.controller");

router.get(
    "/user-stats",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.userStats)
);

router.get(
    "/users",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.listUsers)
);

router.get(
    "/teachers/by-major",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.listTeachersByMajor)
);

router.get(
    "/users/:uid",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.getUserDetail)
);

router.patch(
    "/users/:uid",
    requireAuth,
    requireRole(["admin"]),
    validate(validateAdminUserUpdate),
    asyncHandler(controller.updateUser)
);

router.patch(
    "/users/:uid/lock",
    requireAuth,
    requireRole(["admin"]),
    validate(validateUserLockPatch),
    asyncHandler(controller.lockUser)
);

router.delete(
    "/users/:uid",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.deleteUser)
);

router.patch(
    "/users/:uid/role",
    requireAuth,
    requireRole(["admin"]),
    validate(validateRolePatch),
    asyncHandler(controller.setRole)
);

module.exports = router;