return {
    --- Per-player rate limits in ms between accepted events
    rateLimits = {
        save   = 1500,
        delete = 1500,
    },
    streamBatchSize  = 50, -- 0 = unlimited
    streamBatchDelay = 50,
    adminGroups      = { 'admin', 'god' },
}
