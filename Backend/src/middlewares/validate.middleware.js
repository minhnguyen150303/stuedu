module.exports = (validator) => (req, res, next) => {
    const { ok, errors } = validator(req.body || {});
    if (!ok) return res.status(400).json({ error: "Validation failed", details: errors });
    next();
};