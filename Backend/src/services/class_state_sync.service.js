const { db } = require("../config/firebase");

function parseAcademicStartYear(academicYearLabel) {
    if (!academicYearLabel) return null;

    const text = String(academicYearLabel).trim();
    const match = text.match(/^(\d{4})-(\d{4})$/);

    if (!match) return null;

    return Number(match[1]);
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    return month >= 7 ? academicStartYear : academicStartYear + 1;
}

function buildUtcDate(year, month, day, isEndOfDay = false) {
    if (isEndOfDay) {
        return new Date(Date.UTC(year, month - 1, day, 23, 59, 59));
    }
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0));
}

function resolveCycleTimeline(cycle, academicStartYear) {
    return {
        registrationOpenAt: buildUtcDate(
            getDateYearForAcademicCycle(cycle.registrationOpenMonth, academicStartYear),
            cycle.registrationOpenMonth,
            cycle.registrationOpenDay
        ),
        registrationCloseAt: buildUtcDate(
            getDateYearForAcademicCycle(cycle.registrationCloseMonth, academicStartYear),
            cycle.registrationCloseMonth,
            cycle.registrationCloseDay,
            true
        ),
        studyStartAt: buildUtcDate(
            getDateYearForAcademicCycle(cycle.studyStartMonth, academicStartYear),
            cycle.studyStartMonth,
            cycle.studyStartDay
        ),
        studyEndAt: buildUtcDate(
            getDateYearForAcademicCycle(cycle.studyEndMonth, academicStartYear),
            cycle.studyEndMonth,
            cycle.studyEndDay,
            true
        ),
    };
}

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function getDateYearForAcademicCycle(month, academicStartYear) {
    return month >= 7 ? academicStartYear : academicStartYear + 1;
}

function buildUtcDate(year, month, day, isEndOfDay = false) {
    if (isEndOfDay) {
        return new Date(Date.UTC(year, month - 1, day, 23, 59, 59));
    }
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0));
}

async function runClassStateSyncJob() {
    const now = new Date();

    const cycleSnap = await db.collection("semester_cycles").get();
    const results = [];

    for (const cycleDoc of cycleSnap.docs) {
        const cycle = cycleDoc.data() || {};
        const cycleId = cycleDoc.id;

        if (cycle.isActive === false || cycle.isManualLocked === true) {
            continue;
        }

        const classSnap = await db.collection("classes")
            .where("semesterId", "==", cycleId)
            .get();

        if (classSnap.empty) {
            results.push({
                cycleId,
                activated: 0,
                archived: 0,
                note: "no_classes",
            });
            continue;
        }

        const batch = db.batch();
        let activated = 0;
        let archived = 0;

        for (const classDoc of classSnap.docs) {
            const cls = classDoc.data() || {};
            const state = (cls.adminState || "draft").toString();

            const academicStartYear = parseAcademicStartYear(
                cls.academicYearSnapshot
            );

            if (!academicStartYear) {
                continue;
            }

            const timeline = resolveCycleTimeline(cycle, academicStartYear);
            const registrationOpenAt = timeline.registrationOpenAt;
            const studyEndAt = timeline.studyEndAt;

            // Đúng lần xuất hiện của class đó -> draft thành active
            if (
                now >= registrationOpenAt &&
                now <= studyEndAt &&
                state === "draft"
            ) {
                batch.set(
                    classDoc.ref,
                    {
                        adminState: "active",
                        updatedAt: new Date(),
                    },
                    { merge: true }
                );
                activated += 1;
            }

            // Chỉ active mới archive
            if (now > studyEndAt && state === "active") {
                batch.set(
                    classDoc.ref,
                    {
                        adminState: "archived",
                        archivedAt: new Date(),
                        updatedAt: new Date(),
                    },
                    { merge: true }
                );
                archived += 1;
            }
        }

        if (activated > 0 || archived > 0) {
            await batch.commit();
        }

        results.push({
            cycleId,
            activated,
            archived,
        });
    }

    return {
        ranAt: now.toISOString(),
        results,
    };
}

module.exports = {
    runClassStateSyncJob,
};