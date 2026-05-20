const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const controller = require("../controllers/jobs.controller");

router.post("/generate-classes", asyncHandler(controller.generateClasses));
router.post("/sync-class-states", asyncHandler(controller.syncClassStates));
router.post("/sync-class-chats", asyncHandler(controller.syncClassChats));

module.exports = router;