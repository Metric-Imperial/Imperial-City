--- Stop outdoor weather rendering inside a prop-based housing shell.
---
--- Why it happens: a shell is not an MLO. qbx_properties spawns it with
--- CreateObjectNoOffset 50m below the world, so as far as the engine is
--- concerned the player is still outdoors -- there is no interior ID and no
--- roof test. Rain and snow particles fall through the ceiling and the wet
--- surface pass puts puddle reflections on the floor of a sealed room.
---
--- Why this does NOT fight the weather resource: Renewed-Weathersync already
--- has a per-player override built in. Setting
--- LocalPlayer.state.syncWeather = false makes it stop applying the server
--- weather to this client and instead reapply state.playerWeather every 2.5s
--- with SetRainLevel(0.0) (see its client/weather.lua). Any naive
--- SetWeatherTypeNow here would simply be overwritten on its next tick.
---
--- Redeploy safety: this only SETS two statebags that Renewed-Weathersync
--- already reads, and only LISTENS to two events qbx_properties already emits.
--- Neither third-party resource is modified, so nothing here reverts on a
--- redeploy. Depending on a third-party resource's stock behaviour is fine;
--- depending on a hand-edit to one is not.

local INDOOR_WEATHER = 'EXTRASUNNY'
local suppressed = false

local function suppress(enable)
    local st = LocalPlayer.state

    if enable then
        if suppressed then return end
        -- Order matters. The override loop reads playerWeather when it starts,
        -- so that value has to be in place before syncWeather flips it on.
        st:set('playerWeather', INDOOR_WEATHER, true)
        st:set('syncWeather', false, true)
        suppressed = true
    else
        if not suppressed then return end
        st:set('syncWeather', true, true)
        suppressed = false
    end
end

-- createInterior fires only for shell-type properties, i.e. a property row whose
-- `interior` is numeric (server/property.lua: isInteriorShell). Real MLO
-- properties never reach it and do not need this, because the interior system
-- already stops rain.
RegisterNetEvent('qbx_properties:client:createInterior', function()
    suppress(true)
end)

RegisterNetEvent('qbx_properties:client:unloadProperty', function()
    suppress(false)
end)

-- Failsafes. Leaving syncWeather false would mean this client never sees weather
-- again, which is a far worse bug than rain indoors.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        suppress(false)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    suppress(false)
end)

--- Manual override, for testing the effect without owning a property and for
--- recovering if a script error ever leaves the suppression stuck on.
RegisterCommand('shellweather', function(_, args)
    local arg = (args[1] or ''):lower()
    if arg ~= 'on' and arg ~= 'off' then
        lib.notify({ type = 'error', description = 'Usage: /shellweather on|off' })
        return
    end
    -- Force, rather than going through suppress(), so it works even when the
    -- cached flag disagrees with reality.
    suppressed = (arg == 'off')
    suppress(arg == 'on')
    lib.notify({
        type = 'info',
        description = ('Indoor weather suppression %s'):format(arg),
    })
    print(('[shells] suppression %s (playerWeather=%s)'):format(arg, INDOOR_WEATHER))
end, false)
