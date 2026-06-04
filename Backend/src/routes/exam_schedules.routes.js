const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const controller = require("../controllers/exam_schedules.controller");

router.get(
    "/",
    requireAuth,
    requireRole(["admin", "qlsv", "teacher", "student"]),
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.remove)
);

router.post(
    "/import/check",
    requireAuth,
    requireRole(["qlsv", "admin"]),
    asyncHandler(controller.checkImportExamSchedules)
);

router.post(
    "/import",
    requireAuth,
    requireRole(["qlsv", "admin"]),
    asyncHandler(controller.importExamSchedules)
);

module.exports = router;