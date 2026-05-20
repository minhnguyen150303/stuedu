const { db } = require("../config/firebase");

function getAcademicStartYear(now = new Date()) {
    const month = now.getMonth() + 1;
    return month >= 7 ? now.getFullYear() : now.getFullYear() - 1;
}

function getAcademicYearLabel(startYear) {
    return `${startYear}-${startYear + 1}`;
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
    const registrationOpenYear = getDateYearForAcademicCycle(
        cycle.registrationOpenMonth,
        academicStartYear
    );

    const registrationCloseYear = getDateYearForAcademicCycle(
        cycle.registrationCloseMonth,
        academicStartYear
    );

    const studyStartYear = getDateYearForAcademicCycle(
        cycle.studyStartMonth,
        academicStartYear
    );

    const studyEndYear = getDateYearForAcademicCycle(
        cycle.studyEndMonth,
        academicStartYear
    );

    const registrationOpenAt = buildUtcDate(
        registrationOpenYear,
        cycle.registrationOpenMonth,
        cycle.registrationOpenDay
    );

    const registrationCloseAt = buildUtcDate(
        registrationCloseYear,
        cycle.registrationCloseMonth,
        cycle.registrationCloseDay,
        true
    );

    const studyStartAt = buildUtcDate(
        studyStartYear,
        cycle.studyStartMonth,
        cycle.studyStartDay
    );

    const studyEndAt = buildUtcDate(
        studyEndYear,
        cycle.studyEndMonth,
        cycle.studyEndDay,
        true
    );

    return {
        registrationOpenAt,
        registrationCloseAt,
        studyStartAt,
        studyEndAt,
        academicYear: getAcademicYearLabel(academicStartYear),
    };
}

function getGenerateAt(registrationOpenAt) {
    const d = new Date(registrationOpenAt);
    d.setUTCDate(d.getUTCDate() - 5);
    return d;
}

async function generateClassesForCycle(cycleId, academicStartYear) {
    const cycleRef = db.collection("semester_cycles").doc(cycleId);
    const cycleSnap = await cycleRef.get();

    if (!cycleSnap.exists) {
        throw new Error("Semester cycle not found");
    }

    const cycle = cycleSnap.data() || {};
    if (cycle.isActive === false || cycle.isManualLocked === true) {
        return { cycleId, skipped: true, reason: "inactive_or_locked" };
    }

    const currentAcademicYear = getAcademicYearLabel(academicStartYear);

    const existing = await db.collection("classes")
        .where("semesterId", "==", cycleId)
        .where("academicYearSnapshot", "==", currentAcademicYear)
        .limit(1)
        .get();

    if (!existing.empty) {
        await cycleRef.set(
            {
                classesGenerated: true,
                classesGeneratedAt: new Date(),
                updatedAt: new Date(),
            },
            { merge: true }
        );

        return {
            cycleId,
            skipped: true,
            reason: "already_generated",
        };
    }

    const lifecycleSnap = await db.collection("class_lifecycles")
        .where("majorId", "==", (cycle.majorId || "").toString())
        .where("yearNumber", "==", Number(cycle.yearNumber))
        .where("termNumber", "==", Number(cycle.termNumber))
        .where("isHidden", "==", false)
        .get();

    if (lifecycleSnap.empty) {
        return {
            cycleId,
            skipped: true,
            reason: "no_lifecycles",
        };
    }

    const batch = db.batch();
    let count = 0;

    for (const doc of lifecycleSnap.docs) {
        const life = doc.data() || {};
        const newRef = db.collection("classes").doc();

        batch.set(newRef, {
            lifecycleId: doc.id,

            courseId: life.courseId || "",
            semesterId: cycleId,
            teacherId: life.teacherId || "",
            classCode: life.classCode || "",
            room: life.room || "",
            schedule: Array.isArray(life.schedule) ? life.schedule : [],
            maxStudents: Number(life.maxStudents || 0),

            adminState: "draft",
            isVisibleForRegistration: true,

            termNumberSnapshot: Number(cycle.termNumber),
            yearNumberSnapshot: Number(cycle.yearNumber),
            academicYearSnapshot: currentAcademicYear,

            createdAt: new Date(),
            updatedAt: new Date(),
            archivedAt: null,
        });

        count += 1;
    }

    batch.set(
        cycleRef,
        {
            classesGenerated: true,
            classesGeneratedAt: new Date(),
            updatedAt: new Date(),
        },
        { merge: true }
    );

    await batch.commit();

    return {
        cycleId,
        generated: count,
        academicYear: currentAcademicYear,
    };
}

async function runClassGenerationJob() {
    const now = new Date();
    const baseAcademicStartYear = getAcademicStartYear(now);

    const snap = await db.collection("semester_cycles").get();
    const results = [];

    for (const doc of snap.docs) {
        const cycle = doc.data() || {};

        if (cycle.isActive === false || cycle.isManualLocked === true) {
            continue;
        }

        // Xét 2 lần xuất hiện:
        // 1) năm học hiện tại
        // 2) năm học kế tiếp
        const candidateYears = [
            baseAcademicStartYear,
            baseAcademicStartYear + 1,
        ];

        for (const targetAcademicStartYear of candidateYears) {
            const timeline = resolveCycleTimeline(cycle, targetAcademicStartYear);
            const generateAt = getGenerateAt(timeline.registrationOpenAt);

            // Chỉ sinh trong cửa sổ của đúng lần xuất hiện đó
            if (now >= generateAt && now <= timeline.studyEndAt) {
                const result = await generateClassesForCycle(
                    doc.id,
                    targetAcademicStartYear
                );

                results.push({
                    ...result,
                    targetAcademicYear: getAcademicYearLabel(targetAcademicStartYear),
                });
            }
        }
    }

    return {
        ranAt: now.toISOString(),
        totalCyclesChecked: snap.docs.length,
        results,
    };
}

module.exports = {
    generateClassesForCycle,
    runClassGenerationJob,
};