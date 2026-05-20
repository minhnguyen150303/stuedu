const { db } = require("../config/firebase");

function calcTotalTen({ scoreProcess = 0, scoreMid = 0, scoreFinal = 0 }) {
    const total = scoreProcess * 0.1 + scoreMid * 0.3 + scoreFinal * 0.6;
    return Math.round(total * 10) / 10;
}
function passFail(totalTen) {
    return totalTen >= 5 ? "Pass" : "Fail";
}

async function upsertGrade(data) {
    // mỗi (classId, studentId) chỉ 1 grade => tìm trước
    const snap = await db.collection("grades")
        .where("classId", "==", data.classId)
        .where("studentId", "==", data.studentId)
        .limit(1).get();

    const scoreProcess = Number(data.scoreProcess ?? 0);
    const scoreMid = Number(data.scoreMid ?? 0);
    const scoreFinal = Number(data.scoreFinal ?? 0);
    const totalTen = calcTotalTen({ scoreProcess, scoreMid, scoreFinal });
    const status = passFail(totalTen);

    const payload = { classId: data.classId, studentId: data.studentId, scoreProcess, scoreMid, scoreFinal, totalTen, status, updatedAt: new Date() };

    if (snap.empty) {
        const docRef = await db.collection("grades").add({ ...payload, createdAt: new Date() });
        return { id: docRef.id, ...payload };
    } else {
        const doc = snap.docs[0];
        await db.collection("grades").doc(doc.id).update(payload);
        return { id: doc.id, ...payload };
    }
}

async function listGrades(query) {
    let ref = db.collection("grades");
    if (query.classId) ref = ref.where("classId", "==", query.classId);
    if (query.studentId) ref = ref.where("studentId", "==", query.studentId);
    const snap = await ref.get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

module.exports = { upsertGrade, listGrades };