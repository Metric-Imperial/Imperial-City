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

---Props are placed at exactly the configured coordinate. No runtime grounding.
---
---Earlier versions tried PlaceObjectOnGroundProperly and then a
---GetGroundZFor_3dCoord probe to auto-correct placement. Both were attempts to
---rescue coordinates that were simply wrong -- the quarry nodes were configured
---at z=41.00 where the terrain is actually 42.82, i.e. underground. Auto-
---correction only moved the problem around and made the result unpredictable.
---
---Node coordinates are now captured in-game by standing on the spot and running
---/nodehere (imperial_propcheck), which prints and copies the exact position.
---A prop whose origin is at its base then sits correctly with no adjustment,
---and the interaction sphere is guaranteed to be in the same place.
---Load a model AND its collision.
---
---lib.requestModel only calls RequestModel/HasModelLoaded -- it never requests
---collision. Stock props get away with that because the game already has their
---collision resident from streaming the world; a custom streamed model does
---not, so it renders perfectly and players walk straight through it. This was
---the cause of the boulders being non-solid: not the export, not the archetype,
---and not CreateObject.
---@return boolean collisionReady
local function requestModelWithCollision(model, timeout)
    lib.requestModel(model, timeout or 10000)
    RequestCollisionForModel(model)

    local deadline = GetGameTimer() + (timeout or 10000)
    while not HasCollisionForModelLoaded(model) and GetGameTimer() < deadline do
        RequestCollisionForModel(model)
        Wait(0)
    end

    return HasCollisionForModelLoaded(model)
end

local function spawnNodeProp(id, model, coords)
    lib.points.new({
        coords = coords,
        distance = 100.0,
        onEnter = function()
            if nodeProps[id] then return end
            if not requestModelWithCollision(model, 10000) then
                print(('[sidejobs] collision never loaded for node prop %s'):format(id))
            end
            -- The last argument is `dynamic`. Passing false creates the object
            -- without a physics instance, so it renders but nothing can touch
            -- it -- players walked straight through the boulders even though
            -- the models carry full collision. Create it dynamic so the physics
            -- archetype is instanced, then freeze it in place so it behaves as
            -- a static prop.
            local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, true)
            SetEntityCollision(obj, true, true)
            SetEntityLoadCollisionFlag(obj, true)
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            nodeProps[id] = obj

            -- Diagnostic: what we asked for vs where the object actually is, and
            -- the model's runtime bounds. If placed z differs from requested z,
            -- CreateObject is repositioning it. If min.z is non-zero, the mesh is
            -- offset from its origin and the prop needs that offset applied.
            local actual = GetEntityCoords(obj)
            local mn, mx = GetModelDimensions(model)
            print(('[sidejobs] %s requested z=%.2f actual z=%.2f | model min.z=%.3f max.z=%.3f (h=%.2f)')
                :format(id, coords.z, actual.z, mn.z, mx.z, mx.z - mn.z))

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

        -- Prop and zone both sit on the configured coordinate, so they are in
        -- the same place by construction. Capture coordinates with /nodehere
        -- while standing on the spot rather than estimating them.
        exports.ox_target:addSphereZone({
            coords = pos,
            radius = 2.2,
            options = { option },
        })
        if propModel then
            spawnNodeProp(key, propModel, pos)
        end
    end
end

CreateThread(function()
    -- bone 28422 = IK_R_Hand. pos/rot are the offsets that sit a long-handled
    -- tool in the grip for the ground_attack_on_spot swing.
    -- Tool prop and animation both come from config now, so the axe angle and
    -- the swing can be tuned by editing shared.lua and restarting -- no code
    -- change, no round trip. bone 28422 = IK_R_Hand.
    local function toolProp(cfg)
        if not cfg then return nil end
        return { model = cfg.model, bone = 28422, pos = cfg.pos, rot = cfg.rot }
    end

    local mining, lumber = ImperialSideJobs.mining, ImperialSideJobs.lumber

    setupNodes('mining', mining.nodes, 'fa-solid fa-hill-rockslide', 'Mine rock',
        mining.anim, mining.nodeProp, toolProp(mining.toolProp), 'pickaxe')
    -- No marker prop for lumber: the nodes sit on real trees, so a placed prop
    -- would stack on top of existing geometry.
    setupNodes('lumber', lumber.trees, 'fa-solid fa-tree', 'Chop tree',
        lumber.anim, lumber.nodeProp, toolProp(lumber.toolProp), 'lumber_axe')

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
