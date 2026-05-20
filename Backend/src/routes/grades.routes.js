const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const validate = require("../middlewares/validate.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const { validateGrade } = require("../models/validators");
const controller = require("../controllers/grades.controller");

router.get(
    "/",
    requireAuth,
    requireRole(["teacher", "admin"]),
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["teacher", "admin"]),
    validate(validateGrade),
    asyncHandler(controller.upsert)
);

module.exports = router;