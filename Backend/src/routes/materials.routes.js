const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateMaterial } = require("../models/validators");
const controller = require("../controllers/materials.controller");

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
    validate(validateMaterial),
    asyncHandler(controller.create)
);

router.put(
    "/:id",
    requireAuth,
    requireRole(["teacher", "admin"]),
    validate(validateMaterial),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["teacher", "admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;