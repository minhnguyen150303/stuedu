const router = require("express").Router();

router.use("/courses", require("./courses.routes"));
router.use("/classes", require("./classes.routes"));
router.use("/class-lifecycles", require("./class_lifecycles.routes"));
router.use("/enrollments", require("./enrollments.routes"));
router.use("/assignments", require("./assignments.routes"));
router.use("/grades", require("./grades.routes"));
router.use("/notifications", require("./notifications.routes"));
router.use("/notification-campaigns", require("./notification_campaigns.routes"));
router.use("/auth", require("./auth.routes"));
router.use("/users", require("./users.routes"));
router.use("/admin", require("./admin.routes"));
router.use("/majors", require("./majors.routes"));
router.use("/semesters", require("./semesters.routes"));
router.use("/semester-cycles", require("./semester_cycles.routes"));
router.use("/materials", require("./materials.routes"));
router.use("/curriculum", require("./curriculum.routes"));
router.use("/jobs", require("./jobs.routes"));
router.use("/uploads", require("./uploads.routes"));
router.use("/students", require("./students.routes"));
router.use("/teachers", require("./teachers.routes"));
router.use("/exam-schedules", require("./exam_schedules.routes"));

module.exports = router;