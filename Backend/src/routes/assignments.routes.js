const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateAssignment } = require("../models/validators");
const controller = require("../controllers/assignments.controller");

router.get(
    "/",
    requireAuth,
    requireRole(["teacher", "admin", "student"]),
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["teacher", "admin"]),
    validate(validateAssignment),
    asyncHandler(controller.create)
);

router.post(
    "/:id/submit",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.submit)
);

router.patch(
    "/:id/submissions/:studentId/grade",
    requireAuth,
    requireRole(["teacher"]),
    asyncHandler(controller.gradeSubmission)
);

router.put(
    "/:id",
    requireAuth,
    requireRole(["teacher", "admin"]),
    validate(validateAssignment),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["teacher", "admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;