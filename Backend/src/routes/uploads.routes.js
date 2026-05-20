const router = require("express").Router();
const multer = require("multer");
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const controller = require("../controllers/uploads.controller");

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 15 * 1024 * 1024,
    },
});

router.post(
    "/single",
    requireAuth,
    requireRole(["teacher", "admin", "student"]),
    upload.single("file"),
    asyncHandler(controller.uploadSingle)
);

module.exports = router;