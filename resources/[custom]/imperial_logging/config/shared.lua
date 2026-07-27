ImperialLogConfig = {
    -- Batched insert tuning
    flushIntervalMs = 2000,     -- flush queue at least this often
    flushBatchSize = 50,        -- or as soon as this many entries are queued
    maxQueue = 2000,            -- hard cap; oldest entries dropped with a console warning

    -- Severity levels
    severity = {
        info = 1,
        warn = 2,
        suspicious = 3,
        critical = 4,
    },

    -- Mirror severity >= this to the optional Discord webhook (convar imperial:webhook_audit)
    webhookMinSeverity = 3,

    -- Default rate-limit window when callers do not specify one
    defaultWindowMs = 10000,
    defaultMaxPerWindow = 10,

    -- Action locks: default TTL safety net so a crashed flow cannot deadlock a player
    defaultLockTtlMs = 30000,
}
