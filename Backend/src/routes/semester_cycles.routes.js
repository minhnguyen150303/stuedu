const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateSemesterCycle,
    validateSemesterCyclePatch,
} = require("../models/validators");
const controller = require("../controllers/semester_cycles.controller");

router.get(
    "/",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.list)
);

router.get(
    "/history",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    asyncHandler(controller.history)
);

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateSemesterCycle),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateSemesterCyclePatch),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;