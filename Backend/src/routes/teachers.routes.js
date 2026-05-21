const router = require("express").Router();

const usersController = require("../controllers/users.controller");

const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");

router.get(
    "/me/profile",
    requireAuth,
    requireRole(["teacher"]),
    asyncHandler(usersController.getMyProfile)
);

router.patch(
    "/me/profile",
    requireAuth,
    requireRole(["teacher"]),
    asyncHandler(usersController.updateMyProfile)
);

module.exports = router;