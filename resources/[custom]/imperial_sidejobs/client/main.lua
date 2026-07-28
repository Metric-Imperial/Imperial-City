--- imperial_sidejobs/client/main.lua

local depleted = {}   -- ['mining:3'] = true
local peds = {}

local function spawnStaticPed(id, model, coords, options)
    lib.points.new({
        coords = vec3(coords.x, coords.y, coords.z),
        distance = 60.0,
        onEnter = function()
            if peds[id] then return end
            lib.requestModel(model, 10000)
            local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            exports.ox_target:addLocalEntity(ped, options)
            peds[id] = ped
        end,
        onExit = function()
            if peds[id] and DoesEntityExist(peds[id]) then DeletePed(peds[id]) end
            peds[id] = nil
        end,
    })
end

-- ── Fishing (rod item use → exports.useRod) ─────────────────────────────
local fishing = false
exports('useRod', function()
    if fishing then return end
    fishing = true

    local finished = lib.progressBar({
        duration = 6000,
        label = 'Casting a line…',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' },
    })
    local skillPassed = false
    if finished then
        skillPassed = lib.skillCheck(table.unpack(ImperialSideJobs.fishing.skillCheck))
    end

    local ok, extra = lib.callback.await('imperial_sidejobs:fish', false, skillPassed)
    if ok then
        lib.notify({ type = 'success', description = ('You caught %d fish!'):format(extra) })
    else
        local messages = {
            cooldown = 'The fish are wary — wait a moment.',
            nospot = 'Find a proper fishing spot.',
            norod = 'You need a fishing rod.',
            nobait = 'You need bait.',
            escaped = 'It got away…',
            capacity = 'Your bags are full.',
        }
        lib.notify({ type = 'error', description = messages[extra] or 'No luck.' })
    end
    fishing = false
end)

-- ── Mining / Lumber nodes ───────────────────────────────────────────────

-- Node marker props. Without one the target sphere sits on bare terrain and is
-- effectively invisible -- you can only find a node by already knowing where it
-- is. Streamed in/out with lib.points so we are not holding objects across the
-- whole map. Pass nil to leave a node unmarked (e.g. where real world geometry
-- like a tree already reads as interactable).
local nodeProps = {}

---Settle a prop onto the terrain once the ground beneath it actually exists.
---
---PlaceObjectOnGroundProperly only works when collision is loaded around the
---point. Props are spawned from 100m away, where it usually is not, so calling
---it immediately is a silent no-op and the prop hangs in mid-air at the
---configured Z. Retry until collision streams in, and only freeze afterwards --
---freezing first would pin it in the air permanently.
---Drop a prop onto the terrain.
---
---PlaceObjectOnGroundProperly is unreliable here: it works off the object's own
---physics bounds, so a model with no embedded collision never moves. Probe the
---world for its surface height instead, which does not care what the prop is
---made of, and offset by the model's own base so it rests on the surface rather
---than sinking to its origin. PlaceObjectOnGroundProperly is kept only as a
---fallback for when the probe finds nothing.
---@param onSettled fun(coords: vector3) called once the prop has its final position
local function settleOnGround(obj, model, coords, onSettled)
    CreateThread(function()
        local placed = false

        for _ = 1, 150 do -- ~15s
            if not DoesEntityExist(obj) then return end
            if HasCollisionLoadedAroundEntity(obj) then
                -- Probe from just above the configured point, not from high up.
                -- GetGroundZFor_3dCoord returns the first surface *below* the
                -- start height, so starting 25m up caught ledges and boulders
                -- above the quarry floor -- every node landed higher than its
                -- config Z (41.00 -> 42.82) and appeared to float. Start close,
                -- and only sweep from high up if nothing is found nearby.
                local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.5, false)
                if not found then
                    found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 25.0, false)
                end
                if found then
                    -- min.z is the model's lowest point relative to its origin.
                    -- Subtracting it seats the base on the surface whether the
                    -- origin sits at the centre or the bottom of the mesh.
                    local min = GetModelDimensions(model)
                    SetEntityCoords(obj, coords.x, coords.y, groundZ - min.z, false, false, false, false)
                    placed = true
                    break
                end
                PlaceObjectOnGroundProperly(obj)
                placed = true
                break
            end
            Wait(100)
        end

        if not DoesEntityExist(obj) then return end
        FreezeEntityPosition(obj, true)

        local final = GetEntityCoords(obj)
        if not placed then
            print(('[sidejobs] node prop never settled (collision never loaded) at %.1f %.1f %.1f')
                :format(coords.x, coords.y, coords.z))
        end
        print(('[sidejobs] node prop: config z=%.2f -> placed z=%.2f'):format(coords.z, final.z))

        if onSettled then onSettled(final) end
    end)
end

local function spawnNodeProp(id, model, coords, onSettled)
    lib.points.new({
        coords = coords,
        distance = 100.0,
        onEnter = function()
            if nodeProps[id] then return end
            if not lib.requestModel(model, 10000) then return end
            local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
            SetEntityInvincible(obj, true)
            nodeProps[id] = obj
            -- Model stays requested until after settling: GetModelDimensions
            -- needs it loaded to work out where the prop's base is.
            settleOnGround(obj, model, coords, onSettled)
            SetModelAsNoLongerNeeded(model)
        end,
        onExit = function()
            if nodeProps[id] and DoesEntityExist(nodeProps[id]) then
                DeleteObject(nodeProps[id])
            end
            nodeProps[id] = nil
        end,
    })
end

---@param propModel? number marker prop placed at each node
---@param toolProp? table prop held during the animation (ox_lib progressBar prop)
---@param tool string item required to work this node
local function setupNodes(kind, positions, icon, label, anim, propModel, toolProp, tool)
    for index, pos in ipairs(positions) do
        local key = ('%s:%d'):format(kind, index)
        local zoneId

        local option = {
            name = ('imperial_%s_%d'):format(kind, index),
            label = label,
            icon = icon,
            canInteract = function()
                if depleted[key] then return false end
                -- Hide the option entirely when the player has no tool.
                -- Previously the full 7s animation played and only then did the
                -- server reject it, so you mimed a swing with an invisible
                -- pickaxe you did not own. The server check stays -- this is
                -- presentation, not security.
                return (exports.ox_inventory:GetItemCount(tool) or 0) > 0
            end,
            onSelect = function()
                local finished = lib.progressBar({
                    duration = 7000,
                    label = label .. '…',
                    canCancel = true,
                    disable = { move = true, combat = true },
                    anim = anim,
                    prop = toolProp,
                })
                if not finished then return end
                local ok, extra = lib.callback.await('imperial_sidejobs:gather', false, kind, index)
                if ok then
                    lib.notify({ type = 'success',
                        description = ('+%d %s'):format(extra.count, extra.item) })
                else
                    local messages = {
                        depleted = 'Nothing left here — try another spot.',
                        notool = kind == 'mining' and 'You need a pickaxe.' or 'You need a felling axe.',
                        capacity = 'Your bags are full.',
                        cooldown = 'Take a breather.',
                    }
                    lib.notify({ type = 'error', description = messages[extra] or 'Nothing gained.' })
                end
            end,
        }

        local function placeZone(coords)
            if zoneId then exports.ox_target:removeZone(zoneId) end
            zoneId = exports.ox_target:addSphereZone({
                coords = coords,
                radius = 2.2,
                options = { option },
            })
        end

        -- Zone starts at the configured coordinate so no-prop nodes (lumber)
        -- work as before. Where there IS a prop, the zone re-anchors to wherever
        -- it actually settled.
        --
        -- The configured Z values were never ground-verified: the coal rock
        -- visibly floated several metres up, which means these interaction
        -- spheres have been hanging in mid-air the whole time. That is why nodes
        -- could not be found without teleporting onto them. Re-anchoring makes
        -- prop and zone self-correcting however wrong the config Z is.
        placeZone(pos)
        if propModel then
            spawnNodeProp(key, propModel, pos, function(settled)
                if #(settled - pos) > 0.5 then placeZone(settled) end
            end)
        end
    end
end

CreateThread(function()
    -- bone 28422 = IK_R_Hand. pos/rot are the offsets that sit a long-handled
    -- tool in the grip for the ground_attack_on_spot swing.
    local pickaxeProp = {
        model = `prop_tool_pickaxe`,
        bone = 28422,
        pos = vec3(0.0, -0.03, -0.02),
        rot = vec3(-80.0, 0.0, 0.0),
    }
    local axeProp = {
        model = `v_ind_cs_axe`,
        bone = 28422,
        pos = vec3(0.0, -0.03, -0.02),
        rot = vec3(-80.0, 0.0, 0.0),
    }

    setupNodes('mining', ImperialSideJobs.mining.nodes, 'fa-solid fa-hill-rockslide', 'Mine rock',
        { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
        ImperialSideJobs.mining.nodeProp, pickaxeProp, 'pickaxe')
    -- No marker prop for lumber: the logging camp already has real trees, so a
    -- placed prop would double up. Set ImperialSideJobs.lumber.nodeProp if the
    -- trees turn out not to line up with the node coords.
    setupNodes('lumber', ImperialSideJobs.lumber.trees, 'fa-solid fa-tree', 'Chop tree',
        { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
        ImperialSideJobs.lumber.nodeProp, axeProp, 'lumber_axe')

    -- blips
    for _, b in ipairs({ ImperialSideJobs.mining.blip, ImperialSideJobs.lumber.blip }) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.colour)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label)
        EndTextCommandSetBlipName(blip)
    end
    for _, spot in ipairs(ImperialSideJobs.fishing.spots) do
        local b = ImperialSideJobs.fishing.blip
        local blip = AddBlipForCoord(spot.coords.x, spot.coords.y, spot.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.colour)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(spot.label)
        EndTextCommandSetBlipName(blip)
    end

    -- initial depletion sync
    local current = lib.callback.await('imperial_sidejobs:getDepleted', false)
    for key, remaining in pairs(current or {}) do
        depleted[key] = true
        SetTimeout(remaining * 1000, function() depleted[key] = nil end)
    end
end)

RegisterNetEvent('imperial_sidejobs:client:nodeDepleted', function(kind, index, respawnSec)
    local key = ('%s:%d'):format(kind, index)
    depleted[key] = true
    SetTimeout(respawnSec * 1000, function() depleted[key] = nil end)
end)

-- ── Construction ────────────────────────────────────────────────────────
local carryObj = nil
local dropTarget = nil

local function clearCarry()
    if carryObj and DoesEntityExist(carryObj) then DeleteObject(carryObj) end
    carryObj = nil
    ClearPedTasks(cache.ped)
end

CreateThread(function()
    local cfg = ImperialSideJobs.construction
    local b = cfg.blip
    local blip = AddBlipForCoord(cfg.site.coords.x, cfg.site.coords.y, cfg.site.coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.colour)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.site.label)
    EndTextCommandSetBlipName(blip)

    exports.ox_target:addSphereZone({
        coords = cfg.pickup,
        radius = 2.5,
        options = {
            {
                name = 'imperial_construction_start',
                label = 'Start labouring shift',
                icon = 'fa-solid fa-helmet-safety',
                canInteract = function() return dropTarget == nil and carryObj == nil end,
                onSelect = function()
                    local ok, drop = lib.callback.await('imperial_sidejobs:construction:start', false)
                    if ok then
                        dropTarget = drop
                        lib.notify({ type = 'inform', description = 'Grab materials and carry them where the foreman marks.' })
                    end
                end,
            },
            {
                name = 'imperial_construction_pickup',
                label = 'Pick up materials',
                icon = 'fa-solid fa-boxes-stacked',
                canInteract = function() return dropTarget ~= nil and carryObj == nil end,
                onSelect = function()
                    local ok, drop = lib.callback.await('imperial_sidejobs:construction:pickup', false)
                    if not ok then return end
                    dropTarget = drop
                    lib.requestModel(cfg.carryProp, 10000)
                    carryObj = CreateObject(cfg.carryProp, 0, 0, 0, true, true, false)
                    AttachEntityToEntity(carryObj, cache.ped,
                        GetPedBoneIndex(cache.ped, 28422), 0.0, 0.1, 0.2, 0.0, 0.0, 0.0,
                        true, true, false, true, 1, true)
                    local marker = cfg.dropoffs[dropTarget]
                    SetNewWaypoint(marker.x, marker.y)
                    lib.notify({ type = 'inform', description = 'Carry the load to the waypoint.' })
                end,
            },
        },
    })

    for i, drop in ipairs(cfg.dropoffs) do
        exports.ox_target:addSphereZone({
            coords = drop,
            radius = 2.5,
            options = {
                {
                    name = ('imperial_construction_drop_%d'):format(i),
                    label = 'Set down materials',
                    icon = 'fa-solid fa-arrow-down',
                    canInteract = function() return carryObj ~= nil and dropTarget == i end,
                    onSelect = function()
                        local ok, result = lib.callback.await('imperial_sidejobs:construction:deliver', false)
                        clearCarry()
                        if not ok then return end
                        if result.done then
                            dropTarget = nil
                            lib.notify({ type = 'success',
                                description = ('Shift complete! Bonus $%s paid.'):format(lib.math.groupdigits(result.bonus)) })
                        else
                            dropTarget = result.next
                            local marker = cfg.dropoffs[result.next]
                            SetNewWaypoint(marker.x, marker.y)
                            lib.notify({ type = 'success',
                                description = ('$%s earned — next load.'):format(lib.math.groupdigits(result.wage)) })
                        end
                    end,
                },
            },
        })
    end
end)

-- ── Secure transport ────────────────────────────────────────────────────
local runStops = nil
local runCollected = 0

CreateThread(function()
    local cfg = ImperialSideJobs.securetransport
    local b = cfg.blip
    local blip = AddBlipForCoord(cfg.depot.x, cfg.depot.y, cfg.depot.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.colour)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Secure Transport Depot')
    EndTextCommandSetBlipName(blip)

    spawnStaticPed('transport_depot', `s_m_m_security_01`, cfg.depot, {
        {
            name = 'imperial_transport_start',
            label = 'Start transport run',
            icon = 'fa-solid fa-truck-ramp-box',
            canInteract = function() return runStops == nil end,
            onSelect = function()
                local ok, data = lib.callback.await('imperial_sidejobs:transport:start', false)
                if not ok then
                    lib.notify({ type = 'error', description = 'No runs available right now.' })
                    return
                end
                runStops, runCollected = data.stops, 0
                local first = cfg.stops[runStops[1]]
                SetNewWaypoint(first.x, first.y)
                lib.notify({ type = 'inform', description = 'Van assigned. Collect every case, then return.' })
            end,
        },
        {
            name = 'imperial_transport_finish',
            label = 'Hand in run',
            icon = 'fa-solid fa-flag-checkered',
            canInteract = function() return runStops ~= nil end,
            onSelect = function()
                local ok, collected = lib.callback.await('imperial_sidejobs:transport:finish', false)
                runStops = nil
                if ok then
                    lib.notify({ type = 'success', description = ('Run complete — %d cases delivered.'):format(collected) })
                else
                    lib.notify({ type = 'error', description = 'Run abandoned.' })
                end
            end,
        },
    })

    for i, stop in ipairs(cfg.stops) do
        exports.ox_target:addSphereZone({
            coords = stop,
            radius = 3.0,
            options = {
                {
                    name = ('imperial_transport_stop_%d'):format(i),
                    label = 'Collect secure case',
                    icon = 'fa-solid fa-briefcase',
                    canInteract = function()
                        return runStops ~= nil and runStops[runCollected + 1] == i
                    end,
                    onSelect = function()
                        local finished = lib.progressBar({
                            duration = cfg.casePickupMs,
                            label = 'Collecting case…',
                            canCancel = true,
                            disable = { move = true, combat = true },
                        })
                        if not finished then return end
                        local ok, prog = lib.callback.await('imperial_sidejobs:transport:collect', false, i)
                        if not ok then return end
                        runCollected = prog.collected
                        if prog.collected < prog.total then
                            local nxt = cfg.stops[runStops[prog.collected + 1]]
                            SetNewWaypoint(nxt.x, nxt.y)
                            lib.notify({ type = 'success',
                                description = ('Case %d/%d secured.'):format(prog.collected, prog.total) })
                        else
                            SetNewWaypoint(cfg.depot.x, cfg.depot.y)
                            lib.notify({ type = 'success', description = 'All cases secured — return to the depot.' })
                        end
                    end,
                },
            },
        })
    end
end)

-- ── Materials buyer ─────────────────────────────────────────────────────
CreateThread(function()
    local cfg = ImperialSideJobs.buyer
    spawnStaticPed('materials_buyer', cfg.model, cfg.coords, {
        {
            name = 'imperial_sidejobs_buyer',
            label = 'Sell materials',
            icon = 'fa-solid fa-scale-balanced',
            onSelect = function()
                local options = {}
                for item in pairs(cfg.prices) do
                    local count = exports.ox_inventory:Search('count', item)
                    if count and count > 0 then
                        options[#options + 1] = {
                            title = ('%s (x%d)'):format(item, count),
                            onSelect = function()
                                local input = lib.inputDialog('Sell ' .. item, {
                                    { type = 'number', label = 'Quantity', default = count, min = 1, max = count },
                                })
                                if not input or not input[1] then return end
                                local ok, total = lib.callback.await('imperial_sidejobs:sellMaterials', false, item, input[1])
                                if ok then
                                    lib.notify({ type = 'success',
                                        description = ('Sold for $%s'):format(lib.math.groupdigits(total)) })
                                end
                            end,
                        }
                    end
                end
                if #options == 0 then
                    lib.notify({ type = 'error', description = 'You have nothing I buy — fish, ore, timber.' })
                    return
                end
                lib.registerContext({ id = 'imperial_buyer', title = 'Materials Buyer', options = options })
                lib.showContext('imperial_buyer')
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearCarry()
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end)
