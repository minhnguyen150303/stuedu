const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const {
    validateClassLifecycle,
    validateClassLifecyclePatch,
} = require("../models/validators");
const controller = require("../controllers/class_lifecycles.controller");

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
    validate(validateClassLifecycle),
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClassLifecyclePatch),
    asyncHandler(controller.update)
);

router.patch(
    "/:id/hide",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.hide)
);

router.patch(
    "/:id/show",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.show)
);

router.post(
    "/:id/replace",
    requireAuth,
    requireRole(["admin"]),
    validate(validateClassLifecyclePatch),
    asyncHandler(controller.replace)
);

module.exports = router;