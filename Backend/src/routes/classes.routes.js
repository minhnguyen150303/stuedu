const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateClass,
    validateClassPatch,
    validateClassClone,
    validateJoin,
    validateAdminAddStudent,
} = require("../models/validators");
const controller = require("../controllers/classes.controller");

router.get("/", asyncHandler(controller.list));

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClass),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClassPatch),
    asyncHandler(controller.update)
);

router.patch(
    "/:id/archive",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.archive)
);

router.patch(
    "/:id/visibility",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.toggleVisibility)
);

router.post(
    "/:id/replace",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClassClone),
    asyncHandler(controller.replace)
);

router.post(
    "/:id/reopen",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClassClone),
    asyncHandler(controller.reopen)
);

router.post(
    "/join",
    validate(validateJoin),
    asyncHandler(controller.joinByCode)
);

router.post(
    "/:id/students",
    requireAuth,
    requireRole(["admin"]),
    validate(validateAdminAddStudent),
    asyncHandler(controller.addStudent)
);

router.get(
    "/:id/available-students",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.availableStudents)
);

router.delete(
    "/:id/students/:studentId",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.removeStudent)
);

module.exports = router;