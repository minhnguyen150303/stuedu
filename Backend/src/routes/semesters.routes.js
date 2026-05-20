const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateSemester,
    validateSemesterPatch,
} = require("../models/validators");
const controller = require("../controllers/semesters.controller");

router.get("/", asyncHandler(controller.list));
router.get("/current", asyncHandler(controller.current));

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateSemester),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateSemesterPatch),
    asyncHandler(controller.update)
);

router.patch(
    "/:id/set-current",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.setCurrent)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;