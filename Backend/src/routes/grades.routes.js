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
    requireRole(["teacher", "admin", "qlsv"]),
    asyncHandler(controller.list)
);

router.post(
    "/",
    requireAuth,
    requireRole(["teacher", "admin"]),
    validate(validateGrade),
    asyncHandler(controller.upsert)
);

router.post(
    "/final",
    requireAuth,
    requireRole(["qlsv", "admin"]),
    validate(validateGrade),
    asyncHandler(controller.upsertFinal)
);

router.post(
    "/import/check",
    requireAuth,
    requireRole(["teacher"]),
    asyncHandler(controller.checkImportTeacherGrades)
);

router.post(
    "/import",
    requireAuth,
    requireRole(["teacher"]),
    asyncHandler(controller.importTeacherGrades)
);

router.post(
    "/final/import/check",
    requireAuth,
    requireRole(["qlsv", "admin"]),
    asyncHandler(controller.checkImportFinalGrades)
);

router.post(
    "/final/import",
    requireAuth,
    requireRole(["qlsv", "admin"]),
    asyncHandler(controller.importFinalGrades)
);

module.exports = router;