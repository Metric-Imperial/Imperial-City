ImperialCharacter = {
    -- Items granted exactly once per character on first login.
    -- Money is handled by qbx_core StartingFunds — do not duplicate it here.
    starterItems = {
        { name = 'phone', count = 1 },
        { name = 'id_card', count = 1 },
        { name = 'water', count = 2 },
        { name = 'sandwich', count = 2 },
    },

    -- Optional one-off bank top-up on first login (0 disables). Kept separate
    -- from qbx_core StartingFunds so it is logged and duplicate-proof.
    starterBankBonus = 0,

    -- Fallback spawn if the player ends up under the map or at origin.
    fallbackSpawn = vec4(-1035.71, -2731.87, 12.86, 330.0), -- LSIA arrivals

    -- Consider a spawn broken when below this Z or within this range of origin.
    minSafeZ = -60.0,
    originRadius = 5.0,

    -- Seconds after spawn before the client checks for a broken spawn.
    spawnCheckDelay = 8,
}
