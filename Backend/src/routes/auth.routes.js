const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const controller = require("../controllers/auth.controller");

router.post("/me", requireAuth, asyncHandler(controller.me));

module.exports = router;