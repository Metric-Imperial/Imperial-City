ImperialBoosting = {
    tabletItem = 'boost_tablet',
    contractCooldownMs = 15 * 60000,
    timeLimitSec = 480,

    -- Delivery point (hands off to qbx_scrapyard's chop flow conceptually;
    -- payout band reflects that this is the "contract" tier, not scrapyard's
    -- own market prices).
    dropoff = vec4(731.0, -3196.4, 5.9, 90.0),
    dropoffRadius = 15.0,

    -- Vehicle pools by reputation band (class -> models). Kept small/curated;
    -- extend freely with class-appropriate models.
    bands = {
        { minRep = 0, label = 'Class C', models = { `sultan`, `blista`, `futo` }, payConvar = 'imperial:econ:crime:boostBandC' },
        { minRep = 20, label = 'Class B', models = { `felon`, `oracle`, `sentinel` }, payConvar = 'imperial:econ:crime:boostBandB' },
        { minRep = 50, label = 'Class A', models = { `elegy2`, `feltzer2`, `banshee` }, payConvar = 'imperial:econ:crime:boostBandA' },
    },

    repPerContract = 4,
    dispatchChanceOnTheft = 0.4,
}
