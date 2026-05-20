const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const controller = require("../controllers/enrollments.controller");

router.get(
    "/",
    requireAuth,
    asyncHandler(controller.list)
);

router.get(
    "/class/:classId/users",
    requireAuth,
    requireRole(["teacher", "admin", "student"]),
    asyncHandler(controller.listUsersByClass)
);

router.patch(
    "/:id/approve",
    requireAuth,
    requireRole(["teacher", "admin"]),
    asyncHandler(controller.approve)
);

module.exports = router;