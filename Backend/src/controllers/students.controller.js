const service = require("../services/students.service");
const studentCourseRegistrationService = require("../services/student_course_registration.service");

async function home(req, res) {
    const data = await service.getStudentHome(req.user.uid);
    res.json(data);
}

async function myClasses(req, res) {
    const data = await service.getMyClasses(req.user.uid);
    res.json(data);
}

async function scheduleToday(req, res) {
    const data = await service.getTodaySchedule(req.user.uid);
    res.json(data);
}

async function upcomingAssignments(req, res) {
    const limit = Number(req.query.limit || 10);
    const data = await service.getUpcomingAssignments(req.user.uid, limit);
    res.json(data);
}

async function myGrades(req, res) {
    const data = await service.getMyGrades(req.user.uid);
    res.json(data);
}

async function creditProgress(req, res) {
    const data = await service.getCreditProgress(req.user.uid);
    res.json(data);
}

async function gpaProgress(req, res) {
    const data = await service.getGpaProgress(req.user.uid);
    res.json(data);
}

async function myNotifications(req, res) {
    const data = await service.getMyNotifications(req.user.uid);
    res.json(data);
}

async function scheduleWeek(req, res) {
    const date = req.query.date || null;
    const data = await service.getWeeklySchedule(req.user.uid, date);
    res.json(data);
}

async function scheduleMonth(req, res) {
    const month = req.query.month || null; // ví dụ 2026-03
    const data = await service.getMonthlySchedule(req.user.uid, month);
    res.json(data);
}

///register
async function getCourseRegistrationData(req, res) {
    const studentId = req.user?.uid;

    if (!studentId) {
        return res.status(401).json({ error: "Unauthenticated" });
    }

    const data = await studentCourseRegistrationService.listStudentCourseRegistration(studentId);
    res.json(data);
}

async function registerCourseClass(req, res) {
    const studentId = req.user?.uid;
    const { classId } = req.body || {};

    if (!studentId) {
        return res.status(401).json({ error: "Unauthenticated" });
    }

    if (!classId) {
        return res.status(400).json({ error: "classId is required" });
    }

    const data = await studentCourseRegistrationService.registerStudentToClass(studentId, classId);
    res.json(data);
}

module.exports = {
    home,
    myClasses,
    scheduleToday,
    upcomingAssignments,
    myGrades,
    gpaProgress,
    creditProgress,
    myNotifications,
    scheduleWeek,
    scheduleMonth,
    getCourseRegistrationData,
    registerCourseClass,
};