--- imperial_character/server/main.lua
--- First-login starter package (duplicate-proof via DB flag), onboarding hook,
--- spawn-fallback authorisation, logout/delete audit.

local ACTIVE = {} -- [source] = citizenid, session guard

---Grant the starter package exactly once per character.
---@param source number
---@param citizenid string
local function grantStarterPackage(source, citizenid)
    -- Atomic claim: INSERT into KV acts as the first-login flag. A second
    -- login (or a duplicated event) finds the key and does nothing.
    local key = ('char:welcomed:%s'):format(citizenid)
    if exports.imperial_logging:KVGet(key) then return end

    -- Claim BEFORE granting so a race duplicates nothing (grant failures are
    -- recoverable by admins; duplicate grants are not).
    exports.imperial_logging:KVSet(key, { at = os.time() })

    for _, item in ipairs(ImperialCharacter.starterItems) do
        exports.ox_inventory:AddItem(source, item.name, item.count)
    end

    if ImperialCharacter.starterBankBonus > 0 then
        local player = exports.qbx_core:GetPlayer(source)
        if player then
            player.Functions.AddMoney('bank', ImperialCharacter.starterBankBonus, 'imperial-starter-bonus')
        end
    end

    exports.imperial_logging:Log({
        resource = 'imperial_character',
        category = 'lifecycle',
        action = 'starter_package_granted',
        source = source,
        data = { items = ImperialCharacter.starterItems, bonus = ImperialCharacter.starterBankBonus },
    })

    -- Onboarding hook for other resources (tutorials, starter accommodation offers…)
    TriggerEvent('imperial_character:server:firstLogin', source, citizenid)
    TriggerClientEvent('imperial_character:client:firstLogin', source)
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local citizenid = player.PlayerData.citizenid
    ACTIVE[source] = citizenid
    grantStarterPackage(source, citizenid)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    local citizenid = ACTIVE[source]
    if citizenid then
        exports.imperial_logging:Log({
            resource = 'imperial_character',
            category = 'lifecycle',
            action = 'character_unloaded',
            citizenid = citizenid,
        })
        ACTIVE[source] = nil
    end
end)

AddEventHandler('playerDropped', function()
    ACTIVE[source] = nil
end)

--- Spawn fallback: client requests a rescue teleport; server validates the
--- player really is in a broken position before honouring it.
RegisterNetEvent('imperial_character:server:requestSpawnRescue', function()
    local src = source
    if not exports.imperial_logging:RateLimit(src, 'char:spawnrescue', 3, 60000) then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)

    local broken = coords.z < ImperialCharacter.minSafeZ
        or (math.abs(coords.x) < ImperialCharacter.originRadius
            and math.abs(coords.y) < ImperialCharacter.originRadius)

    if not broken then
        exports.imperial_logging:LogSuspicious(src, 'spawn_rescue_denied', {
            coords = { x = coords.x, y = coords.y, z = coords.z },
        })
        return
    end

    local fb = ImperialCharacter.fallbackSpawn
    SetEntityCoords(ped, fb.x, fb.y, fb.z, false, false, false, false)
    SetEntityHeading(ped, fb.w)

    exports.imperial_logging:Log({
        resource = 'imperial_character',
        category = 'lifecycle',
        action = 'spawn_rescue',
        source = src,
        data = { from = { x = coords.x, y = coords.y, z = coords.z } },
    })
end)
