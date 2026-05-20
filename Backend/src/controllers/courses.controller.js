const courseService = require("../services/courses.service");

async function getAll(req, res) {
    const data = await courseService.listCourses(req.query);
    res.json(data);
}

async function create(req, res) {
    const result = await courseService.createCourse(req.body);
    res.status(201).json({ message: "Created", ...result });
}

async function update(req, res) {
    const result = await courseService.updateCourse(req.params.id, req.body);
    res.json({ message: "Updated", ...result });
}

async function remove(req, res) {
    const result = await courseService.deleteCourse(req.params.id);
    res.json({ message: "Deleted", ...result });
}

module.exports = { getAll, create, update, remove };