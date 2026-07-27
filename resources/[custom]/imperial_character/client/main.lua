--- imperial_character/client/main.lua
--- Broken-spawn detection and first-login welcome.

local function checkSpawn()
    SetTimeout(ImperialCharacter.spawnCheckDelay * 1000, function()
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        local broken = coords.z < ImperialCharacter.minSafeZ
            or (math.abs(coords.x) < ImperialCharacter.originRadius
                and math.abs(coords.y) < ImperialCharacter.originRadius)
        if broken then
            TriggerServerEvent('imperial_character:server:requestSpawnRescue')
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', checkSpawn)

RegisterNetEvent('imperial_character:client:firstLogin', function()
    lib.notify({
        title = 'Welcome to Imperial City',
        description = 'Check your pockets — we packed you the essentials. Visit City Hall for work.',
        type = 'success',
        duration = 9000,
    })
end)
