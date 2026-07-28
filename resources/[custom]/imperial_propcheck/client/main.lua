--- imperial_propcheck — dev tool for choosing props for activity sites.
---
--- Everything here is client-side and NON-NETWORKED: objects are local to you,
--- nobody else sees them, and nothing touches server state. Safe to leave
--- installed, but it is a dev tool — not player-facing content.
---
--- /prop <model>   spawn a prop in front of you (replaces the current one)
--- /propdel        delete the current prop
--- /propinfo       print the current prop's model and real-world size
--- /proplist       list the built-in candidate models (validated)
--- /propnext       cycle forward through the candidate list
--- /propprev       cycle back through the candidate list

-- Candidate rock/mineral props for mining nodes. Each is validated against the
-- game's model index before use, so anything not present in this build is
-- skipped rather than silently failing.
local CANDIDATES = {
    'prop_rock_1_a', 'prop_rock_1_b', 'prop_rock_1_c', 'prop_rock_1_d',
    'prop_rock_1_e', 'prop_rock_1_f', 'prop_rock_1_g', 'prop_rock_1_h',
    'prop_rock_2_a', 'prop_rock_2_b', 'prop_rock_2_c', 'prop_rock_2_d',
    'prop_rock_2_e', 'prop_rock_2_f',
    'prop_rock_3_a', 'prop_rock_3_b', 'prop_rock_3_c', 'prop_rock_3_d',
    'prop_rock_4_a', 'prop_rock_4_b', 'prop_rock_4_c', 'prop_rock_4_d',
    'prop_rock_5_a', 'prop_rock_5_b', 'prop_rock_5_c', 'prop_rock_5_d',
    'prop_rock_6_a', 'prop_rock_7_a',
    'prop_asteroid_01a',
    'xs_terrain_rock_arena_1_01',
}

local current, currentModel, index = nil, nil, 0

---Real-world bounding size of a model, in metres.
local function modelSize(model)
    local min, max = GetModelDimensions(model)
    return (max - min)
end

local function deleteCurrent()
    if current and DoesEntityExist(current) then DeleteObject(current) end
    current, currentModel = nil, nil
end

---Spawn `model` roughly 2.5m in front of the player, dropped onto the terrain.
local function spawnProp(model)
    local hash = type(model) == 'string' and joaat(model) or model

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        lib.notify({ type = 'error', description = ('Invalid model: %s'):format(model) })
        return false
    end

    if not lib.requestModel(hash, 10000) then
        lib.notify({ type = 'error', description = ('Model would not load: %s'):format(model) })
        return false
    end

    deleteCurrent()

    local ped = cache.ped
    local fwd = GetEntityForwardVector(ped)
    local c = GetEntityCoords(ped) + (fwd * 2.5)

    -- isNetwork = false, netMissionEntity = false -> local only.
    current = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    PlaceObjectOnGroundProperly(current)
    FreezeEntityPosition(current, true)
    currentModel = type(model) == 'string' and model or tostring(model)
    SetModelAsNoLongerNeeded(hash)

    local s = modelSize(hash)
    lib.notify({
        type = 'success',
        title = currentModel,
        description = ('%.2f x %.2f x %.2f m (w/d/h)'):format(s.x, s.y, s.z),
        duration = 7000,
    })
    print(('[propcheck] %s  size %.2f x %.2f x %.2f m'):format(currentModel, s.x, s.y, s.z))
    return true
end

---Move through the candidate list, skipping models this build doesn't have.
local function cycle(step)
    local tried = 0
    repeat
        index = index + step
        if index > #CANDIDATES then index = 1 end
        if index < 1 then index = #CANDIDATES end
        tried = tried + 1
        if spawnProp(CANDIDATES[index]) then
            lib.notify({ type = 'info', description = ('%d / %d'):format(index, #CANDIDATES) })
            return
        end
    until tried >= #CANDIDATES
    lib.notify({ type = 'error', description = 'No valid models in the candidate list.' })
end

RegisterCommand('prop', function(_, args)
    if not args[1] then
        lib.notify({ type = 'error', description = 'Usage: /prop <model>' })
        return
    end
    spawnProp(args[1])
end, false)

RegisterCommand('propdel', function()
    if not current then
        lib.notify({ type = 'info', description = 'Nothing spawned.' })
        return
    end
    deleteCurrent()
    lib.notify({ type = 'info', description = 'Prop deleted.' })
end, false)

RegisterCommand('propinfo', function()
    if not current or not DoesEntityExist(current) then
        lib.notify({ type = 'info', description = 'Nothing spawned.' })
        return
    end
    local s = modelSize(joaat(currentModel))
    local c = GetEntityCoords(current)
    print(('[propcheck] %s'):format(currentModel))
    print(('[propcheck]   size   %.2f x %.2f x %.2f m'):format(s.x, s.y, s.z))
    print(('[propcheck]   coords vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z))
    lib.notify({ type = 'info', title = currentModel,
        description = ('%.2f x %.2f x %.2f m — full detail in F8'):format(s.x, s.y, s.z),
        duration = 8000 })
end, false)

RegisterCommand('proplist', function()
    print('[propcheck] candidate models (* = present in this build):')
    for i, m in ipairs(CANDIDATES) do
        local ok = IsModelInCdimage(joaat(m))
        print(('[propcheck]   %2d %s %s'):format(i, ok and '*' or ' ', m))
    end
    lib.notify({ type = 'info', description = 'Candidate list printed to F8.' })
end, false)

RegisterCommand('propnext', function() cycle(1) end, false)
RegisterCommand('propprev', function() cycle(-1) end, false)

-- Capture a node coordinate by standing where you want it.
--
-- This exists because guessing coordinates does not work. The mining nodes were
-- configured at z values that turned out to be below the terrain, and no amount
-- of runtime ground-probing fixed that reliably -- it only hid the real problem.
-- Standing on the spot and reading the position off the game is exact.
--
-- Prints the player's foot position, which is exactly where a prop whose origin
-- sits at its base should be placed.
RegisterCommand('nodehere', function()
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    -- GetEntityCoords returns the ped's root; subtract to get ground contact.
    local _, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    local line = ('vec3(%.2f, %.2f, %.2f),'):format(c.x, c.y, groundZ ~= 0 and groundZ or c.z)

    print('[propcheck] ' .. line)
    print(('[propcheck]   ped z=%.2f  ground z=%.2f  heading=%.1f')
        :format(c.z, groundZ or 0.0, GetEntityHeading(ped)))

    lib.setClipboard(line)
    lib.notify({
        type = 'success',
        title = 'Node coordinate copied',
        description = line,
        duration = 8000,
    })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == cache.resource then deleteCurrent() end
end)

print('[propcheck] loaded — /prop /propdel /propinfo /proplist /propnext /propprev')
