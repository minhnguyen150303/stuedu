const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateCourse, validateCoursePatch } = require("../models/validators");
const controller = require("../controllers/courses.controller");

router.get("/", asyncHandler(controller.getAll));

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateCourse),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateCoursePatch),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;