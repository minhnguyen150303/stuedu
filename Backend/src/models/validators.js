function requiredString(v) {
    return typeof v === "string" && v.trim().length > 0;
}
function requiredNumber(v) {
    return typeof v === "number" && !Number.isNaN(v);
}

function validateCourse(body) {
    const errors = [];
    if (!requiredString(body.courseName)) errors.push("courseName is required (string)");
    if (!requiredString(body.courseCode)) errors.push("courseCode is required (string)");
    if (body.credits === undefined || body.credits === null) errors.push("credits is required (number)");
    if (!requiredString(body.majorId)) errors.push("majorId is required (string)");
    return { ok: errors.length === 0, errors };
}

function validateCoursePatch(body) {
    const errors = [];

    if (body.courseName != null && !requiredString(body.courseName)) {
        errors.push("courseName must be non-empty string");
    }
    if (body.courseCode != null && !requiredString(body.courseCode)) {
        errors.push("courseCode must be non-empty string");
    }
    if (body.credits != null && typeof body.credits !== "number") {
        errors.push("credits must be number");
    }
    if (body.description != null && !requiredString(body.description)) {
        errors.push("description must be non-empty string");
    }
    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }

    return { ok: errors.length === 0, errors };
}

function isValidTimeHHmm(v) {
    if (!requiredString(v)) return false;
    return /^([01]\d|2[0-3]):([0-5]\d)$/.test(v);
}

function validateScheduleArray(schedule, errors, prefix = "schedule") {
    if (!Array.isArray(schedule) || schedule.length === 0) {
        errors.push(`${prefix} is required and must be non-empty array`);
        return;
    }

    for (const item of schedule) {
        if (typeof item !== "object" || item == null || Array.isArray(item)) {
            errors.push(`${prefix} item must be object`);
            continue;
        }

        if (
            typeof item.dayOfWeek !== "number" ||
            ![2, 3, 4, 5, 6, 7, 8].includes(item.dayOfWeek)
        ) {
            errors.push(`${prefix}.dayOfWeek must be one of 2..8`);
        }

        if (!isValidTimeHHmm(item.startTime)) {
            errors.push(`${prefix}.startTime must be HH:mm`);
        }

        if (!isValidTimeHHmm(item.endTime)) {
            errors.push(`${prefix}.endTime must be HH:mm`);
        }

        if (
            isValidTimeHHmm(item.startTime) &&
            isValidTimeHHmm(item.endTime) &&
            item.startTime >= item.endTime
        ) {
            errors.push(`${prefix}.startTime must be before endTime`);
        }
    }
}

function validateClass(body) {
    const errors = [];

    if (!requiredString(body.courseId)) errors.push("courseId is required");
    if (!requiredString(body.teacherId)) errors.push("teacherId is required");
    if (!requiredString(body.semesterId)) errors.push("semesterId is required");

    if (!requiredString(body.classCode)) {
        errors.push("classCode is required");
    }

    if (!requiredString(body.room)) {
        errors.push("room is required");
    }

    if (body.maxStudents == null || typeof body.maxStudents !== "number") {
        errors.push("maxStudents is required and must be number");
    } else if (body.maxStudents <= 0) {
        errors.push("maxStudents must be > 0");
    }

    validateScheduleArray(body.schedule, errors);

    if (body.adminState != null) {
        const allowed = ["draft", "archived"];
        if (!allowed.includes(body.adminState)) {
            errors.push("adminState must be draft/archived");
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateClassPatch(body) {
    const errors = [];

    if (body.courseId != null && !requiredString(body.courseId)) {
        errors.push("courseId must be non-empty string");
    }

    if (body.teacherId != null && !requiredString(body.teacherId)) {
        errors.push("teacherId must be non-empty string");
    }

    if (body.semesterId != null && !requiredString(body.semesterId)) {
        errors.push("semesterId must be non-empty string");
    }

    if (body.classCode != null && !requiredString(body.classCode)) {
        errors.push("classCode must be non-empty string");
    }

    if (body.room != null && !requiredString(body.room)) {
        errors.push("room must be non-empty string");
    }

    if (body.maxStudents != null) {
        if (typeof body.maxStudents !== "number") {
            errors.push("maxStudents must be number");
        } else if (body.maxStudents <= 0) {
            errors.push("maxStudents must be > 0");
        }
    }

    if (body.schedule != null) {
        validateScheduleArray(body.schedule, errors);
    }

    if (body.adminState != null) {
        const allowed = ["draft", "archived"];
        if (!allowed.includes(body.adminState)) {
            errors.push("adminState must be draft/archived");
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateClassClone(body) {
    const errors = [];

    if (!requiredString(body.classCode)) {
        errors.push("classCode is required");
    }

    if (body.courseId != null && !requiredString(body.courseId)) {
        errors.push("courseId must be non-empty string");
    }

    if (body.teacherId != null && !requiredString(body.teacherId)) {
        errors.push("teacherId must be non-empty string");
    }

    if (body.semesterId != null && !requiredString(body.semesterId)) {
        errors.push("semesterId must be non-empty string");
    }

    if (body.room != null && !requiredString(body.room)) {
        errors.push("room must be non-empty string");
    }

    if (body.maxStudents != null) {
        if (typeof body.maxStudents !== "number") {
            errors.push("maxStudents must be number");
        } else if (body.maxStudents <= 0) {
            errors.push("maxStudents must be > 0");
        }
    }

    if (body.schedule != null) {
        validateScheduleArray(body.schedule, errors);
    }

    return { ok: errors.length === 0, errors };
}

function validateJoin(body) {
    const errors = [];
    if (!requiredString(body.classCode)) errors.push("classCode is required");
    if (!requiredString(body.studentId)) errors.push("studentId is required");
    return { ok: errors.length === 0, errors };
}

function validateClassLifecycle(body) {
    const errors = [];

    if (!requiredString(body.courseId)) errors.push("courseId is required");
    if (!requiredString(body.teacherId)) errors.push("teacherId is required");
    if (!requiredString(body.classCode)) errors.push("classCode is required");
    if (!requiredString(body.room)) errors.push("room is required");
    if (!requiredString(body.majorId)) errors.push("majorId is required");

    if (body.maxStudents == null || typeof body.maxStudents !== "number") {
        errors.push("maxStudents is required and must be number");
    } else if (body.maxStudents <= 0) {
        errors.push("maxStudents must be > 0");
    }

    if (typeof body.yearNumber !== "number") {
        errors.push("yearNumber is required and must be number");
    }

    if (typeof body.termNumber !== "number" || ![1, 2].includes(body.termNumber)) {
        errors.push("termNumber must be 1 or 2");
    }

    validateScheduleArray(body.schedule, errors, "schedule");

    return { ok: errors.length === 0, errors };
}

function validateClassLifecyclePatch(body) {
    const errors = [];

    if (body.courseId != null && !requiredString(body.courseId)) {
        errors.push("courseId must be non-empty string");
    }
    if (body.teacherId != null && !requiredString(body.teacherId)) {
        errors.push("teacherId must be non-empty string");
    }
    if (body.classCode != null && !requiredString(body.classCode)) {
        errors.push("classCode must be non-empty string");
    }
    if (body.room != null && !requiredString(body.room)) {
        errors.push("room must be non-empty string");
    }
    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }
    if (body.maxStudents != null) {
        if (typeof body.maxStudents !== "number") {
            errors.push("maxStudents must be number");
        } else if (body.maxStudents <= 0) {
            errors.push("maxStudents must be > 0");
        }
    }
    if (body.yearNumber != null && typeof body.yearNumber !== "number") {
        errors.push("yearNumber must be number");
    }
    if (body.termNumber != null) {
        if (typeof body.termNumber !== "number" || ![1, 2].includes(body.termNumber)) {
            errors.push("termNumber must be 1 or 2");
        }
    }
    if (body.schedule != null) {
        validateScheduleArray(body.schedule, errors, "schedule");
    }
    if (body.isHidden != null && typeof body.isHidden !== "boolean") {
        errors.push("isHidden must be boolean");
    }

    return { ok: errors.length === 0, errors };
}

function validateAssignment(body) {
    const errors = [];
    if (!requiredString(body.classId)) errors.push("classId is required");
    if (!requiredString(body.title)) errors.push("title is required");
    if (!requiredString(body.content)) errors.push("content is required");
    // deadline: nhận ISO string hoặc number millis (tạm cho đồ án)
    if (!body.deadline) errors.push("deadline is required");
    return { ok: errors.length === 0, errors };
}

function validateGrade(body) {
    const errors = [];

    if (!requiredString(body.classId)) errors.push("classId is required");
    if (!requiredString(body.studentId)) errors.push("studentId is required");

    const scoreFields = ["scoreProcess", "scoreMid", "scoreFinal"];

    for (const key of scoreFields) {
        if (body[key] != null) {
            if (typeof body[key] !== "number") {
                errors.push(`${key} must be number`);
            } else if (body[key] < 0 || body[key] > 10) {
                errors.push(`${key} must be between 0 and 10`);
            }
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateNotification(body) {
    const errors = [];
    if (!requiredString(body.receiverId)) errors.push("receiverId is required");
    if (!requiredString(body.receiverType)) errors.push("receiverType is required (individual/all)");
    if (!requiredString(body.title)) errors.push("title is required");
    if (!requiredString(body.body)) errors.push("body is required");
    return { ok: errors.length === 0, errors };
}

function validateMajor(body) {
    const errors = [];
    if (!requiredString(body.name)) errors.push("name is required");
    return { ok: errors.length === 0, errors };
}

function validateSemester(body) {
    const errors = [];

    if (!requiredString(body.majorId)) {
        errors.push("majorId is required");
    }

    if (typeof body.yearNumber !== "number") {
        errors.push("yearNumber is required and must be number");
    }

    if (typeof body.termNumber !== "number") {
        errors.push("termNumber is required and must be number");
    }

    if (![1, 2].includes(body.termNumber)) {
        errors.push("termNumber must be 1 or 2");
    }

    if (!requiredString(body.academicYear)) {
        errors.push("academicYear is required");
    }

    if (!body.registrationOpenAt) {
        errors.push("registrationOpenAt is required");
    }

    if (!body.registrationCloseAt) {
        errors.push("registrationCloseAt is required");
    }

    if (!body.studyStartAt) {
        errors.push("studyStartAt is required");
    }

    if (!body.studyEndAt) {
        errors.push("studyEndAt is required");
    }

    return { ok: errors.length === 0, errors };
}

function validateSemesterPatch(body) {
    const errors = [];

    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }

    if (body.yearNumber != null && typeof body.yearNumber !== "number") {
        errors.push("yearNumber must be number");
    }

    if (body.termNumber != null) {
        if (typeof body.termNumber !== "number") {
            errors.push("termNumber must be number");
        } else if (![1, 2].includes(body.termNumber)) {
            errors.push("termNumber must be 1 or 2");
        }
    }

    if (body.academicYear != null && !requiredString(body.academicYear)) {
        errors.push("academicYear must be non-empty string");
    }

    if (body.registrationOpenAt != null && !body.registrationOpenAt) {
        errors.push("registrationOpenAt is invalid");
    }

    if (body.registrationCloseAt != null && !body.registrationCloseAt) {
        errors.push("registrationCloseAt is invalid");
    }

    if (body.studyStartAt != null && !body.studyStartAt) {
        errors.push("studyStartAt is invalid");
    }

    if (body.studyEndAt != null && !body.studyEndAt) {
        errors.push("studyEndAt is invalid");
    }

    if (body.isManualLocked != null && typeof body.isManualLocked !== "boolean") {
        errors.push("isManualLocked must be boolean");
    }

    return { ok: errors.length === 0, errors };
}

function validateSemesterCycle(body) {
    const errors = [];

    if (!requiredString(body.majorId)) {
        errors.push("majorId is required");
    }

    if (typeof body.yearNumber !== "number") {
        errors.push("yearNumber is required and must be number");
    }

    if (typeof body.termNumber !== "number") {
        errors.push("termNumber is required and must be number");
    } else if (![1, 2].includes(body.termNumber)) {
        errors.push("termNumber must be 1 or 2");
    }

    const rules = [
        ["registrationOpenMonth", 1, 12],
        ["registrationOpenDay", 1, 31],
        ["registrationCloseMonth", 1, 12],
        ["registrationCloseDay", 1, 31],
        ["studyStartMonth", 1, 12],
        ["studyStartDay", 1, 31],
        ["studyEndMonth", 1, 12],
        ["studyEndDay", 1, 31],
    ];

    for (const [key, min, max] of rules) {
        if (typeof body[key] !== "number") {
            errors.push(`${key} is required and must be number`);
        } else if (body[key] < min || body[key] > max) {
            errors.push(`${key} is invalid`);
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateSemesterCyclePatch(body) {
    const errors = [];

    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }

    if (body.yearNumber != null && typeof body.yearNumber !== "number") {
        errors.push("yearNumber must be number");
    }

    if (body.termNumber != null) {
        if (typeof body.termNumber !== "number") {
            errors.push("termNumber must be number");
        } else if (![1, 2].includes(body.termNumber)) {
            errors.push("termNumber must be 1 or 2");
        }
    }

    const rules = [
        ["registrationOpenMonth", 1, 12],
        ["registrationOpenDay", 1, 31],
        ["registrationCloseMonth", 1, 12],
        ["registrationCloseDay", 1, 31],
        ["studyStartMonth", 1, 12],
        ["studyStartDay", 1, 31],
        ["studyEndMonth", 1, 12],
        ["studyEndDay", 1, 31],
    ];

    for (const [key, min, max] of rules) {
        if (body[key] != null) {
            if (typeof body[key] !== "number") {
                errors.push(`${key} must be number`);
            } else if (body[key] < min || body[key] > max) {
                errors.push(`${key} is invalid`);
            }
        }
    }

    if (body.isActive != null && typeof body.isActive !== "boolean") {
        errors.push("isActive must be boolean");
    }

    if (body.isManualLocked != null && typeof body.isManualLocked !== "boolean") {
        errors.push("isManualLocked must be boolean");
    }

    return { ok: errors.length === 0, errors };
}

function validateMaterial(body) {
    const errors = [];
    if (!requiredString(body.classId)) errors.push("classId is required");
    if (!requiredString(body.title)) errors.push("title is required");
    if (!requiredString(body.type)) {
        errors.push("type is required");
    } else {
        const allowed = ["link", "pdf", "image", "file"];
        if (!allowed.includes(body.type)) {
            errors.push("type must be link/pdf/image/file");
        }
    }
    if (!requiredString(body.url)) errors.push("url is required");
    return { ok: errors.length === 0, errors };
}

function validateRolePatch(body) {
    const errors = [];
    if (!requiredString(body.role)) errors.push("role is required");
    const allowed = ["admin", "teacher", "student", "qlsv"];
    if (body.role && !allowed.includes(body.role)) errors.push("role must be admin/teacher/student/qlsv");
    return { ok: errors.length === 0, errors };
}

function validateSettingsPatch(body) {
    const errors = [];
    if (body.theme && !["light", "dark", "system"].includes(body.theme)) errors.push("theme must be light/dark/system");
    if (body.remindMinutes != null && typeof body.remindMinutes !== "number") errors.push("remindMinutes must be number");
    return { ok: errors.length === 0, errors };
}

function validateFcmToken(body) {
    const errors = [];
    if (!requiredString(body.token)) errors.push("token is required");
    return { ok: errors.length === 0, errors };
}

function validateAdminUserUpdate(body) {
    const errors = [];

    if (body.fullName != null && !requiredString(body.fullName)) {
        errors.push("fullName must be non-empty string");
    }

    if (body.email != null && !requiredString(body.email)) {
        errors.push("email must be non-empty string");
    }

    if (body.phoneNumber != null && !requiredString(body.phoneNumber)) {
        errors.push("phoneNumber must be non-empty string");
    }

    if (body.address != null && !requiredString(body.address)) {
        errors.push("address must be non-empty string");
    }

    if (body.department != null && !requiredString(body.department)) {
        errors.push("department must be non-empty string");
    }

    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }

    if (body.avatarUrl != null && !requiredString(body.avatarUrl)) {
        errors.push("avatarUrl must be non-empty string");
    }

    if (body.role != null) {
        const allowed = ["admin", "teacher", "student", "qlsv"];
        if (!allowed.includes(body.role)) {
            errors.push("role must be admin/teacher/student/qlsv");
        }
    }

    if (body.studentInfo != null) {
        if (typeof body.studentInfo !== "object" || Array.isArray(body.studentInfo)) {
            errors.push("studentInfo must be object");
        } else {
            if (
                body.studentInfo.studentCode != null &&
                !requiredString(body.studentInfo.studentCode)
            ) {
                errors.push("studentInfo.studentCode must be non-empty string");
            }

            if (
                body.studentInfo.className != null &&
                !requiredString(body.studentInfo.className)
            ) {
                errors.push("studentInfo.className must be non-empty string");
            }

            if (
                body.studentInfo.year != null &&
                typeof body.studentInfo.year !== "number"
            ) {
                errors.push("studentInfo.year must be number");
            }
        }
    }

    if (body.teacherInfo != null) {
        if (typeof body.teacherInfo !== "object" || Array.isArray(body.teacherInfo)) {
            errors.push("teacherInfo must be object");
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateUserLockPatch(body) {
    const errors = [];
    if (typeof body.disabled !== "boolean") {
        errors.push("disabled must be boolean");
    }
    return { ok: errors.length === 0, errors };
}

function validateMajorPatch(body) {
    const errors = [];
    if (body.name != null && !requiredString(body.name)) {
        errors.push("name must be non-empty string");
    }
    if (body.description != null && !requiredString(body.description)) {
        errors.push("description must be non-empty string");
    }
    return { ok: errors.length === 0, errors };
}

function validateCurriculum(body) {
    const errors = [];
    if (!requiredString(body.majorId)) errors.push("majorId is required");
    if (!requiredString(body.semesterId)) errors.push("semesterId is required");
    if (!requiredString(body.courseId)) errors.push("courseId is required");
    return { ok: errors.length === 0, errors };
}

function validateCurriculumPatch(body) {
    const errors = [];

    if (body.majorId != null && !requiredString(body.majorId)) {
        errors.push("majorId must be non-empty string");
    }

    if (body.semesterId != null && !requiredString(body.semesterId)) {
        errors.push("semesterId must be non-empty string");
    }

    if (body.courseId != null && !requiredString(body.courseId)) {
        errors.push("courseId must be non-empty string");
    }

    if (body.isVisible != null && typeof body.isVisible !== "boolean") {
        errors.push("isVisible must be boolean");
    }

    return { ok: errors.length === 0, errors };
}

function validateAdminAddStudent(body) {
    const errors = [];
    if (!requiredString(body.studentId)) {
        errors.push("studentId is required");
    }
    return { ok: errors.length === 0, errors };
}

function validateAdminCreateUser(body) {
    const errors = [];

    if (!requiredString(body.fullName)) errors.push("fullName is required");
    if (!requiredString(body.email)) errors.push("email is required");
    if (!requiredString(body.role)) errors.push("role is required");

    const allowedRoles = ["admin", "teacher", "student", "qlsv"];
    if (body.role && !allowedRoles.includes(body.role)) {
        errors.push("role must be admin/teacher/student/qlsv");
    }

    if (!requiredString(body.loginProvider)) {
        errors.push("loginProvider is required");
    }

    const allowedProviders = ["google", "password"];
    if (body.loginProvider && !allowedProviders.includes(body.loginProvider)) {
        errors.push("loginProvider must be google/password");
    }

    if (body.loginProvider === "password" && !requiredString(body.password)) {
        errors.push("password is required for password login");
    }

    if (body.role === "student") {
        if (!body.studentInfo || typeof body.studentInfo !== "object") {
            errors.push("studentInfo is required for student");
        } else {
            if (!requiredString(body.studentInfo.studentCode)) {
                errors.push("studentInfo.studentCode is required");
            }
            if (typeof body.studentInfo.year !== "number") {
                errors.push("studentInfo.year is required and must be number");
            }
            if (!requiredString(body.studentInfo.className)) {
                errors.push("studentInfo.className is required");
            }
        }
    }

    return { ok: errors.length === 0, errors };
}

function validateAdminImportUsers(body) {
    const errors = [];

    if (!Array.isArray(body.users) || body.users.length === 0) {
        errors.push("users must be non-empty array");
        return { ok: false, errors };
    }

    if (body.users.length > 500) {
        errors.push("Maximum 500 users per import");
    }

    body.users.forEach((user, index) => {
        const prefix = `users[${index}]`;

        if (!requiredString(user.fullName)) {
            errors.push(`${prefix}.fullName is required`);
        }

        if (!requiredString(user.email)) {
            errors.push(`${prefix}.email is required`);
        }

        if (!requiredString(user.role)) {
            errors.push(`${prefix}.role is required`);
        } else if (!["admin", "teacher", "student", "qlsv"].includes(user.role)) {
            errors.push(`${prefix}.role must be admin/teacher/student/qlsv`);
        }

        if (!requiredString(user.loginProvider)) {
            errors.push(`${prefix}.loginProvider is required`);
        } else if (!["google", "password"].includes(user.loginProvider)) {
            errors.push(`${prefix}.loginProvider must be google/password`);
        }

        if (user.loginProvider === "password" && !requiredString(user.password)) {
            errors.push(`${prefix}.password is required for password login`);
        }

        if (user.role === "student") {
            if (!user.studentInfo || typeof user.studentInfo !== "object") {
                errors.push(`${prefix}.studentInfo is required for student`);
            } else {
                if (!requiredString(user.studentInfo.studentCode)) {
                    errors.push(`${prefix}.studentInfo.studentCode is required`);
                }
                if (typeof user.studentInfo.year !== "number") {
                    errors.push(`${prefix}.studentInfo.year must be number`);
                }
                if (!requiredString(user.studentInfo.className)) {
                    errors.push(`${prefix}.studentInfo.className is required`);
                }
            }
        }
    });

    return { ok: errors.length === 0, errors };
}

module.exports = {
    validateCourse,
    validateCoursePatch,
    validateClass,
    validateClassPatch,
    validateClassClone,
    validateJoin,
    validateClassLifecycle,
    validateClassLifecyclePatch,
    validateAssignment,
    validateGrade,
    validateNotification,
    validateMajor,
    validateSemester,
    validateSemesterPatch,
    validateSemesterCycle,
    validateSemesterCyclePatch,
    validateMaterial,
    validateRolePatch,
    validateSettingsPatch,
    validateFcmToken,
    validateAdminUserUpdate,
    validateUserLockPatch,
    validateMajorPatch,
    validateCurriculum,
    validateCurriculumPatch,
    validateAdminAddStudent,
    validateAdminCreateUser,
    validateAdminImportUsers,
};
