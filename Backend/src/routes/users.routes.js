const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { validateSettingsPatch, validateFcmToken } = require("../models/validators");
const controller = require("../controllers/users.controller");

router.get(
    "/me",
    requireAuth,
    asyncHandler(controller.getMyProfile)
);

router.patch(
    "/me",
    requireAuth,
    asyncHandler(controller.updateMyProfile)
);

router.patch("/me/settings", requireAuth, validate(validateSettingsPatch), asyncHandler(controller.updateSettings));
router.post("/me/fcm-token", requireAuth, validate(validateFcmToken), asyncHandler(controller.addToken));
router.delete(
    "/me/fcm-token",
    requireAuth,
    validate(validateFcmToken),
    asyncHandler(controller.removeToken)
);

module.exports = router;