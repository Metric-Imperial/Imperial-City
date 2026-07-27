ImperialCharacter = {
    -- Items granted exactly once per character on first login.
    --
    -- Money is handled by qbx_core (config/server.lua `moneyTypes`) and the
    -- phone / id_card / driver_license by qbx_core (config/shared.lua
    -- `starterItems`) — do NOT duplicate either here.
    --
    -- qbx_core grants id_card and driver_license with metadata built by
    -- qbx_idcard:GetMetaLicense, so they carry the holder's details. Granting a
    -- bare 'id_card' from here produced a second, metadata-less card on top of
    -- the good one. Keep this list to consumables qbx_core does not cover.
    starterItems = {
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
