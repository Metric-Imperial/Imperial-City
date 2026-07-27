ImperialTurfs = {
    zones = {
        { key = 'turf_grovest', label = 'Grove Street', coords = vec3(103.9, -1945.8, 21.1), radius = 60.0 },
        { key = 'turf_davis', label = 'Davis', coords = vec3(90.2, -1670.9, 29.5), radius = 70.0 },
        { key = 'turf_lasventuras', label = 'La Puerta', coords = vec3(-1600.0, -600.0, 33.0), radius = 65.0 },
        { key = 'turf_vespucci', label = 'Vespucci Canals', coords = vec3(-1180.0, -1520.0, 4.4), radius = 60.0 },
    },

    -- Conflict rules
    declareDelaySec = 60,      -- warning period before capture progress begins
    captureThreshold = 100,     -- progress needed to flip ownership
    progressPerTickAttack = 4,  -- gained per tick while attackers hold presence
    progressPerTickDefense = 6, -- lost per tick while defenders hold presence (defense is stronger)
    tickIntervalSec = 30,
    minPresence = 2,             -- minimum gang members physically in the zone to contribute
    maxCountedParticipants = 6,  -- extra attackers beyond this don't add more progress
    cooldownAfterCaptureSec = 3600,
    contestTimeoutSec = 1800,    -- contest auto-cancels if not captured within this long

    -- Benefits of ownership (read by imperial_drugs/imperial_crafting/etc via GetTurfOwner)
    incomeIntervalMin = 60,
    incomeConvar = 'imperial:econ:turf:incomePerCycle', -- paid to gang account per interval per owned turf
    incomeDefault = 2000,

    notifyPoliceOnContest = true,
    reputationOnCapture = 10,
}
