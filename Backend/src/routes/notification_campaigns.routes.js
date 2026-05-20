const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");

const controller = require("../controllers/notification_campaigns.controller");

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
    asyncHandler(controller.create)
);

router.patch(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.update)
);

router.delete(
    "/:id",
    requireAuth,
    requireRole(["admin"]),
    asyncHandler(controller.remove)
);

module.exports = router;