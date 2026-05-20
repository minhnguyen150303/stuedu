const router = require("express").Router();
const asyncHandler = require("../middlewares/async.middleware");
const { requireAuth } = require("../middlewares/auth.middleware");
const { requireRole } = require("../middlewares/role.middleware");
const controller = require("../controllers/students.controller");

router.get(
    "/me/home",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.home)
);

router.get(
    "/me/classes",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.myClasses)
);

router.get(
    "/me/schedule-today",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.scheduleToday)
);

router.get(
    "/me/assignments/upcoming",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.upcomingAssignments)
);

router.get(
    "/me/grades",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.myGrades)
);

router.get(
    "/me/credit-progress",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.creditProgress)
);

router.get(
    "/me/gpa-progress",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.gpaProgress)
);

router.get(
    "/me/notifications",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.myNotifications)
);

router.get(
    "/me/schedule-week",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.scheduleWeek)
);

router.get(
    "/me/schedule-month",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.scheduleMonth)
);

////register
router.get(
    "/me/course-registration",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.getCourseRegistrationData)
);

router.post(
    "/me/course-registration",
    requireAuth,
    requireRole(["student"]),
    asyncHandler(controller.registerCourseClass)
);

module.exports = router;