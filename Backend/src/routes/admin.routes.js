const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateRolePatch,
    validateAdminUserUpdate,
    validateUserLockPatch,
    validateAdminCreateUser,
    validateAdminImportUsers,
} = require("../models/validators");
const controller = require("../controllers/admin.controller");
const usersController = require("../controllers/users.controller");

router.get(
    "/user-stats",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.userStats)
);

router.get(
    "/users",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.listUsers)
);

router.get(
    "/teachers/by-major",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.listTeachersByMajor)
);

router.post(
    "/users",
    requireAuth,
    requireRole(["admin"]),
    validate(validateAdminCreateUser),
    asyncHandler(controller.createUser)
);

router.post(
    "/users/import/check",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.checkImportUsers)
);

router.post(
    "/users/import",
    requireAuth,
    requireRole(["admin"]),
    validate(validateAdminImportUsers),
    asyncHandler(controller.importUsers)
);

router.get(
    "/students/:uid/learning-overview",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.getStudentLearningOverview)
);

router.get(
    "/users/:uid",
    requireAuth,
    requireRole(["admin", "qlsv"]),
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

router.get(
    "/me/profile",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(usersController.getMyProfile)
);

router.patch(
    "/me/profile",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(usersController.updateMyProfile)
);


module.exports = router;