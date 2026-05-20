const { db } = require("../config/firebase");

function requireRole(roles = []) {
    return async (req, res, next) => {
        try {
            const uid = req.user?.uid;
            if (!uid) return res.status(401).json({ error: "Unauthenticated" });

            const doc = await db.collection("users").doc(uid).get();
            if (!doc.exists) return res.status(403).json({ error: "User profile not found" });

            const role = doc.data().role;
            req.user.role = role;

            if (!roles.includes(role)) {
                return res.status(403).json({ error: "Forbidden", role, need: roles });
            }

            next();
        } catch (e) {
            res.status(500).json({ error: e.message });
        }
    };
}

module.exports = { requireRole };