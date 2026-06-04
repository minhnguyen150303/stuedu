const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateNotification } = require("../models/validators");
const controller = require("../controllers/notifications.controller");

router.get(
    "/",
    requireAuth,
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["admin", "qlsv"]),
    validate(validateNotification),
    asyncHandler(controller.create)
);

router.patch(
    "/:id/read",
    requireAuth,
    asyncHandler(controller.read)
);

module.exports = router;