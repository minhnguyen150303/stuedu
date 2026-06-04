const service = require("../services/grades.service");

async function upsert(req, res) {
    const result = await service.upsertGrade(req.body);
    res.status(201).json({ message: "Upserted", ...result });
}

async function upsertFinal(req, res) {
    const result = await service.upsertFinalGrade(req.body);
    res.status(201).json({ message: "Final grade upserted", ...result });
}

async function list(req, res) {
    const data = await service.listGrades(req.query);
    res.json(data);
}

async function checkImportTeacherGrades(req, res) {
    const result = await service.checkImportTeacherGrades({
        classId: req.body.classId,
        rows: req.body.rows || [],
    });

    res.json(result);
}

async function importTeacherGrades(req, res) {
    const result = await service.importTeacherGrades({
        classId: req.body.classId,
        rows: req.body.rows || [],
    });

    res.json(result);
}

async function checkImportFinalGrades(req, res) {
    const result = await service.checkImportFinalGrades({
        classId: req.body.classId,
        rows: req.body.rows || [],
    });

    res.json(result);
}

async function importFinalGrades(req, res) {
    const result = await service.importFinalGrades({
        classId: req.body.classId,
        rows: req.body.rows || [],
    });

    res.json(result);
}

module.exports = {
    upsert,
    upsertFinal,
    list,
    checkImportTeacherGrades,
    importTeacherGrades,
    checkImportFinalGrades,
    importFinalGrades,
};