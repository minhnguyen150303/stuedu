const cron = require("node-cron");
const { runClassGenerationJob } = require("../services/class_generation.service");
const { runClassStateSyncJob } = require("../services/class_state_sync.service");
const classChatSyncService = require("../services/class_chat_sync.service");

let started = false;

function logJob(name, data) {
    console.log(`[SCHEDULER] ${name} OK`, {
        at: new Date().toISOString(),
        data,
    });
}

function logJobError(name, error) {
    console.error(`[SCHEDULER] ${name} ERROR`, {
        at: new Date().toISOString(),
        message: error?.message || error,
        stack: error?.stack || null,
    });
}

async function runGenerateClassesSafe() {
    try {
        const result = await runClassGenerationJob();
        logJob("generate-classes", result);
    } catch (error) {
        logJobError("generate-classes", error);
    }
}

async function runSyncClassStatesSafe() {
    try {
        const result = await runClassStateSyncJob();
        logJob("sync-class-states", result);
    } catch (error) {
        logJobError("sync-class-states", error);
    }
}

async function runSyncClassChatsSafe() {
    try {
        const result = await classChatSyncService.syncAllActiveClassChats();
        logJob("sync-class-chats", result);
    } catch (error) {
        logJobError("sync-class-chats", error);
    }
}

async function runSchedulerRound() {
    await runGenerateClassesSafe();
    await runSyncClassStatesSafe();
    await runSyncClassChatsSafe();
}

function startScheduler() {
    if (started) return;
    started = true;

    const enabled = (process.env.ENABLE_INTERNAL_SCHEDULER || "true") === "true";
    if (!enabled) {
        console.log("[SCHEDULER] Internal scheduler disabled by env");
        return;
    }

    console.log("[SCHEDULER] Internal scheduler started");

    // Chạy 1 lần lúc server vừa boot: sinh lớp trước, rồi sync trạng thái
    void runSchedulerRound();

    // Mỗi 10 phút chạy tuần tự 1 vòng
    cron.schedule("*/10 * * * *", async () => {
        await runSchedulerRound();
    });
}

module.exports = { startScheduler };