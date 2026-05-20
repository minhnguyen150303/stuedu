function notFound(req, res, next) {
    res.status(404);
    next(new Error(`Not Found - ${req.originalUrl}`));
}

function errorHandler(err, req, res, next) {
    const statusCode =
        err.statusCode ||
        (res.statusCode && res.statusCode !== 200 ? res.statusCode : 500);

    res.status(statusCode).json({
        error: err.message || "Server Error",
    });
}

module.exports = { notFound, errorHandler };