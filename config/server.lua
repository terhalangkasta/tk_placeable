return {
    --- Per-player rate limits in ms between accepted events
    rateLimits = {
        save   = 1500,
        delete = 1500,
    },
    perfModeRateMultiplier  = 1.5,
    perfModePlayerThreshold = 100,
    perfModeCheckIntervalMs = 60000,
    streamBatchSize         = 50, -- 0 = unlimited
    streamBatchDelay        = 50,
    adminGroups             = { 'admin', 'god' },
}
