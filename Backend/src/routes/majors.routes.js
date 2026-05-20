const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateMajor, validateMajorPatch } = require("../models/validators");
const controller = require("../controllers/majors.controller");

router.get("/", asyncHandler(controller.list));

router.post(
    "/",
    requireAuth,
    requireRole(["admin"]),
    validate(validateMajor),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateMajorPatch),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;