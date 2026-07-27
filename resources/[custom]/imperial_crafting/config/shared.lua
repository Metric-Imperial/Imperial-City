ImperialCrafting = {
    -- XP required per level; level = floor((xp / base) ^ 0.7)
    xpBase = 100,

    -- Max simultaneous batch size (server-enforced)
    maxBatch = 10,

    -- Client → server craft requests per 10 s
    rateLimit = { max = 8, windowMs = 10000 },

    -- Default interaction distance from a bench (server re-validates)
    benchDistance = 3.0,

    -- Failure: recipes may define failChance (0–1) reduced by level
    failLevelBonus = 0.01, -- each level reduces fail chance by 1 percentage point, floor 0
}
