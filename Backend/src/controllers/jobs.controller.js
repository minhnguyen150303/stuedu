const { runClassGenerationJob } = require("../services/class_generation.service");
const { runClassStateSyncJob } = require("../services/class_state_sync.service");
const classChatSyncService = require("../services/class_chat_sync.service");

async function generateClasses(req, res) {
    const cronSecret = process.env.CRON_SECRET || "";
    const requestSecret = req.headers["x-cron-secret"];

    if (!cronSecret || requestSecret !== cronSecret) {
        return res.status(403).json({ error: "Forbidden" });
    }

    const result = await runClassGenerationJob();

    await classChatSyncService.syncAllActiveClassChats();

    res.json({
        ...result,
        chatSynced: true,
    });
}

async function syncClassStates(req, res) {
    const secret = req.headers["x-cron-secret"];
    if (secret !== process.env.CRON_SECRET) {
        return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await runClassStateSyncJob();

    await classChatSyncService.syncAllActiveClassChats();

    res.json({
        ...result,
        chatStateSynced: true,
    });
}

async function syncClassChats(req, res) {
    const secret = req.headers["x-cron-secret"];
    if (secret !== process.env.CRON_SECRET) {
        return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await classChatSyncService.syncAllActiveClassChats();

    res.json({
        message: "Synced class chats",
        ...result,
    });
}

module.exports = {
    generateClasses,
    syncClassStates,
    syncClassChats,
};