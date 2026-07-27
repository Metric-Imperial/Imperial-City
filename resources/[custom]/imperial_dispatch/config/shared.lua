ImperialDispatch = {
    -- Recognised job keys and their display metadata (extend as needed).
    jobs = {
        police = { label = 'Police', blipSprite = 60, blipColour = 29, sound = 'Lose_1st' },
        ambulance = { label = 'EMS', blipSprite = 61, blipColour = 2, sound = 'Lose_1st' },
        fire = { label = 'Fire', blipSprite = 436, blipColour = 17, sound = 'Lose_1st' },
    },

    -- Default alert lifetime if the caller doesn't specify one
    defaultDurationMs = 90000,

    -- Rate limit for resources spamming CreateDispatchCall (per source resource)
    rateLimit = { max = 20, windowMs = 10000 },

    -- How far a unit needs to be to auto-clear "en route" pulsing (cosmetic only)
    blipPulseRadius = 30.0,
}
