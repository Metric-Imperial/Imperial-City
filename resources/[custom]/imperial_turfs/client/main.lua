--- imperial_turfs/client/main.lua
--- Zone blips reflect server-authoritative ownership; contesting is a
--- command validated entirely server-side (presence, cooldowns, gang rank).

local blips = {}
local zoneState = {}

local function colourFor(gangKey)
    if not gangKey then return 3 end -- neutral
    -- simple deterministic colour from key hash so each gang reads consistently
    local hash = 0
    for i = 1, #gangKey do hash = (hash + string.byte(gangKey, i) * i) % 60 end
    return hash + 1
end

local function refreshBlips()
    local state = lib.callback.await('imperial_turfs:getState', false)
    if not state then return end
    zoneState = state

    for _, zone in ipairs(ImperialTurfs.zones) do
        local info = state[zone.key]
        if not blips[zone.key] then
            local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipColour(blip, colourFor(info and info.owner))
            SetBlipAlpha(blip, 128)
            blips[zone.key] = blip
        else
            SetBlipColour(blips[zone.key], colourFor(info and info.owner))
        end
    end
end

CreateThread(function()
    Wait(2000)
    refreshBlips()
    while true do
        Wait(60000)
        refreshBlips()
    end
end)

RegisterCommand('turfcontest', function()
    local coords = GetEntityCoords(cache.ped)
    local nearest, nearestDist = nil, math.huge
    for _, zone in ipairs(ImperialTurfs.zones) do
        local dist = #(coords - zone.coords)
        if dist <= zone.radius and dist < nearestDist then
            nearest, nearestDist = zone, dist
        end
    end
    if not nearest then
        lib.notify({ type = 'error', description = 'You are not inside a turf zone.' })
        return
    end

    local ok, result = lib.callback.await('imperial_turfs:startContest', false, nearest.key)
    if ok then
        lib.notify({ type = 'inform', description =
            ('Contest declared. Hold the zone — capture begins in %ds.'):format(result.declareDelaySec) })
    else
        local messages = {
            nogang = 'You are not in a gang.', ownturf = 'Your gang already owns this.',
            alreadycontested = 'This turf is already contested.', cooldown = 'This turf was captured too recently.',
            notinzone = 'Move into the turf zone.', notenoughpresence = 'Bring more gang members into the zone.',
        }
        lib.notify({ type = 'error', description = messages[result] or 'Could not start a contest.' })
    end
end, false)

RegisterCommand('turfinfo', function()
    local lines = {}
    for _, zone in ipairs(ImperialTurfs.zones) do
        local info = zoneState[zone.key]
        lines[#lines + 1] = ('%s: %s%s'):format(
            zone.label, (info and info.owner) or 'Neutral',
            (info and info.contestedBy) and (' (contested by ' .. info.contestedBy .. ')') or '')
    end
    lib.notify({ type = 'inform', description = table.concat(lines, '\n'), duration = 8000 })
end, false)
