const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateCurriculum, validateCurriculumPatch } = require("../models/validators");
const controller = require("../controllers/curriculum.controller");

router.get(
    "/",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateCurriculum),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateCurriculumPatch),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;