--- imperial_sidejobs/client/main.lua

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
        -- The whole list goes in as one argument: lib.skillCheck(difficulty,
        -- inputs) treats a table as a sequence of stages. Unpacking it passed
        -- 'easy' as the difficulty and 'medium' as the key list, so the second
        -- stage was silently dropped and only one check ever ran.
        skillPassed = lib.skillCheck(ImperialSideJobs.fishing.skillCheck) == true
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

--- Per-node runtime state, keyed by nodeKey().
--- { coords, model, obj, inside, depleted }
---
--- Mining nodes are grouped by ore, so the key carries the ore id: a coal seam
--- and an iron deposit can both be index 1 without colliding.
local nodes = {}

local MESSAGES = {
    depleted = 'Nothing left here — try another spot.',
    capacity = 'Your bags are full.',
    cooldown = 'Take a breather.',
    missed   = 'The swing glanced off.',
    toofar   = 'You are too far away.',
}

local function nodeKey(kind, group, index)
    return group and ('%s:%s:%d'):format(kind, group, index)
        or ('%s:%d'):format(kind, index)
end

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

---Build the marker prop, if this node has one and conditions allow.
---
---Props are placed at exactly the configured coordinate. No runtime grounding.
---Earlier versions tried PlaceObjectOnGroundProperly and then a
---GetGroundZFor_3dCoord probe to auto-correct placement. Both were attempts to
---rescue coordinates that were simply wrong, and only moved the problem around.
---Coordinates are captured in-game with /nodehere instead.
local function createNodeObject(key)
    local n = nodes[key]
    if not n or n.obj or not n.model then return end
    if not n.inside or n.depleted then return end

    if not requestModelWithCollision(n.model, 10000) then
        print(('[sidejobs] collision never loaded for node prop %s'):format(key))
    end

    -- The last argument is `dynamic`. Passing false creates the object without
    -- a physics instance, so it renders but nothing can touch it -- players
    -- walked straight through the boulders even though the models carry full
    -- collision. Create it dynamic so the physics archetype is instanced, then
    -- freeze it so it behaves as a static prop.
    local obj = CreateObject(n.model, n.coords.x, n.coords.y, n.coords.z, false, false, true)
    SetEntityCollision(obj, true, true)
    SetEntityLoadCollisionFlag(obj, true)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    n.obj = obj

    SetModelAsNoLongerNeeded(n.model)
end

local function destroyNodeObject(key)
    local n = nodes[key]
    if not n or not n.obj then return end
    if DoesEntityExist(n.obj) then DeleteObject(n.obj) end
    n.obj = nil
end

---Mark a node worked out and take its boulder away until it respawns.
---
---A depleted node despawns rather than merely refusing interaction: a rock you
---can still walk up to but cannot mine reads as a broken node, not an empty one.
local function setDepleted(key, respawnSec)
    local n = nodes[key]
    if not n then return end

    n.depleted = true
    destroyNodeObject(key)

    SetTimeout((respawnSec or 60) * 1000, function()
        local cur = nodes[key]
        if not cur then return end
        cur.depleted = false
        -- No-op unless the player happens to still be standing in range.
        createNodeObject(key)
    end)
end

---Start the swing animation with the tool in hand, and keep it running.
---
---lib.progressBar handles anim and prop together, but only for a fixed
---duration. The swing now ends when the player finishes the skill check rather
---than when a timer expires, so the animation is driven by hand.
---@return number? propEntity to pass to endSwing
local function startSwing(anim, toolCfg)
    lib.requestAnimDict(anim.dict, 5000)
    local ped = cache.ped
    TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, -1, 1, 0.0, false, false, false)

    if not toolCfg then return nil end
    if not lib.requestModel(toolCfg.model, 5000) then return nil end

    local c = GetEntityCoords(ped)
    local obj = CreateObject(toolCfg.model, c.x, c.y, c.z, true, true, false)
    -- bone 28422 = IK_R_Hand. pos/rot come from config, so tool angle is tuned
    -- by editing shared.lua and restarting -- no code change, no round trip.
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 28422),
        toolCfg.pos.x, toolCfg.pos.y, toolCfg.pos.z,
        toolCfg.rot.x, toolCfg.rot.y, toolCfg.rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(toolCfg.model)
    return obj
end

local function endSwing(propEntity, anim)
    ClearPedTasks(cache.ped)
    if propEntity and DoesEntityExist(propEntity) then DeleteEntity(propEntity) end
    RemoveAnimDict(anim.dict)
end

---@param kind 'mining'|'lumber'
---@param group? string ore id for mining, nil for lumber
---@param spec table model, label, icon, anim, toolProp, tool, notool, skillCheck, keys
local function registerNode(kind, group, index, coords, spec)
    local key = nodeKey(kind, group, index)
    nodes[key] = { coords = coords, model = spec.model, inside = false, depleted = false }

    exports.ox_target:addSphereZone({
        coords = coords,
        radius = 2.2,
        options = { {
            name = ('imperial_%s_%s%d'):format(kind, group or '', index),
            label = spec.label,
            icon = spec.icon,
            canInteract = function()
                if nodes[key].depleted then return false end
                -- Hide the option entirely when the player has no tool.
                -- Previously the full swing played and only then did the server
                -- reject it, so you mimed a strike with an invisible pickaxe you
                -- did not own. The server check stays -- this is presentation.
                return (exports.ox_inventory:GetItemCount(spec.tool) or 0) > 0
            end,
            onSelect = function()
                local held = startSwing(spec.anim, spec.toolProp)
                local passed = lib.skillCheck(spec.skillCheck, spec.keys)
                endSwing(held, spec.anim)

                local ok, extra = lib.callback.await('imperial_sidejobs:gather', false,
                    kind, index, group, passed == true)
                if ok then
                    lib.notify({ type = 'success',
                        description = ('+%d %s'):format(extra.count, extra.item) })
                else
                    lib.notify({ type = 'error',
                        description = extra == 'notool' and spec.notool
                            or MESSAGES[extra] or 'Nothing gained.' })
                end
            end,
        } },
    })

    -- Marker prop, streamed in and out with lib.points so we are not holding
    -- objects across the whole map. Without one the target sphere sits on bare
    -- terrain and is effectively invisible unless you already know where it is.
    -- Nodes on real world geometry (trees) pass no model and get no prop.
    if spec.model then
        lib.points.new({
            coords = coords,
            distance = 100.0,
            onEnter = function()
                nodes[key].inside = true
                createNodeObject(key)
            end,
            onExit = function()
                nodes[key].inside = false
                destroyNodeObject(key)
            end,
        })
    end
end

local function addBlip(coords, sprite, colour, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    local mining, lumber = ImperialSideJobs.mining, ImperialSideJobs.lumber

    for ore, o in pairs(mining.ores) do
        for index, pos in ipairs(o.nodes) do
            registerNode('mining', ore, index, pos, {
                model = o.prop,
                label = ('Mine %s'):format(o.label),
                icon = 'fa-solid fa-hill-rockslide',
                anim = mining.anim,
                toolProp = mining.toolProp,
                tool = 'pickaxe',
                notool = 'You need a pickaxe.',
                skillCheck = mining.skillCheck,
                keys = mining.skillCheckKeys,
            })
        end
        for _, c in ipairs(o.blips or {}) do
            addBlip(c, mining.blip.sprite, mining.blip.colour, o.label)
        end
    end

    -- No marker prop for lumber: the nodes sit on real trees, so a placed prop
    -- would stack on top of existing geometry.
    for index, pos in ipairs(lumber.trees) do
        registerNode('lumber', nil, index, pos, {
            model = lumber.nodeProp,
            label = 'Chop tree',
            icon = 'fa-solid fa-tree',
            anim = lumber.anim,
            toolProp = lumber.toolProp,
            tool = 'lumber_axe',
            notool = 'You need a felling axe.',
            skillCheck = lumber.skillCheck,
            keys = lumber.skillCheckKeys,
        })
    end

    local lb = lumber.blip
    addBlip(lb.coords, lb.sprite, lb.colour, lb.label)

    for _, spot in ipairs(ImperialSideJobs.fishing.spots) do
        local b = ImperialSideJobs.fishing.blip
        addBlip(spot.coords, b.sprite, b.colour, spot.label)
    end

    -- initial depletion sync
    local current = lib.callback.await('imperial_sidejobs:getDepleted', false)
    for key, remaining in pairs(current or {}) do
        setDepleted(key, remaining)
    end
end)

RegisterNetEvent('imperial_sidejobs:client:nodeDepleted', function(kind, index, group, respawnSec)
    setDepleted(nodeKey(kind, group, index), respawnSec)
end)

-- ── Smelting ────────────────────────────────────────────────────────────
--
-- Chimney smoke is a looped particle effect, not geometry. Modelled smoke only
-- looks right from the one angle it was built for, and it would burn draw calls
-- even with nobody watching. Tied to the same lib.points that streams the prop,
-- it exists only while a player is close enough to see it.

local smelters = {}   -- [index] = { obj, ptfx }

local function stopSmoke(index)
    local s = smelters[index]
    if not s or not s.ptfx then return end
    StopParticleFxLooped(s.ptfx, false)
    s.ptfx = nil
end

local function startSmoke(index)
    local cfg = ImperialSideJobs.smelting.smoke
    if not cfg or not cfg.effect then return end
    local s = smelters[index]
    if not s or s.ptfx or not s.obj then return end

    if not lib.requestNamedPtfxAsset(cfg.dict) then
        print(('[sidejobs] ptfx dict %s would not load'):format(cfg.dict))
        return
    end
    UseParticleFxAsset(cfg.dict)

    -- Attached to the entity, not to a world coordinate. The offset is in model
    -- space, so the game rotates it with the prop -- a smelter turned to face
    -- the player keeps its smoke over the chimney instead of leaving it hanging
    -- wherever the chimney would have been at heading 0.
    s.ptfx = StartParticleFxLoopedOnEntity(cfg.effect, s.obj,
        cfg.offset.x, cfg.offset.y, cfg.offset.z,
        0.0, 0.0, 0.0, cfg.scale or 1.0, false, false, false)
end

local function smeltAt(index, recipe)
    local cfg = ImperialSideJobs.smelting

    if (exports.ox_inventory:GetItemCount(recipe.input) or 0) < recipe.count then
        return lib.notify({ type = 'error',
            description = ('You need %d %s.'):format(recipe.count, recipe.input) })
    end
    if (exports.ox_inventory:GetItemCount(cfg.fuel.item) or 0) < cfg.fuel.count then
        return lib.notify({ type = 'error',
            description = ('The furnace needs %s to burn.'):format(cfg.fuel.item) })
    end

    local finished = lib.progressBar({
        duration = cfg.smeltTimeMs,
        label = ('Smelting %s…'):format(recipe.input),
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@prop_human_bbq@male@base', clip = 'base' },
    })
    if not finished then return end

    -- Bellows work: a missed check wastes the fuel but not the ore.
    local passed = lib.skillCheck(cfg.skillCheck, cfg.skillCheckKeys)

    local ok, extra = lib.callback.await('imperial_sidejobs:smelt', false,
        index, recipe.input, passed == true)
    if ok then
        lib.notify({ type = 'success',
            description = ('+%d %s'):format(extra.count, extra.item) })
    else
        local messages = {
            nofuel = 'The furnace has gone cold.',
            noore = 'Not enough ore.',
            ruined = 'The pour was botched — the fuel is spent.',
            capacity = 'Your bags are full.',
            cooldown = 'Let it cool a moment.',
            toofar = 'You are too far from the furnace.',
        }
        lib.notify({ type = 'error', description = messages[extra] or 'Nothing gained.' })
    end
end

CreateThread(function()
    local cfg = ImperialSideJobs.smelting
    if not cfg or not cfg.sites then return end

    for index, site in ipairs(cfg.sites) do
        local coords, heading = site.coords, site.heading or 0.0
        smelters[index] = { obj = nil, ptfx = nil }

        local options = {}
        for _, recipe in ipairs(cfg.recipes) do
            options[#options + 1] = {
                name = ('imperial_smelt_%d_%s'):format(index, recipe.input),
                label = ('Smelt %s → %s'):format(recipe.input, recipe.output),
                icon = 'fa-solid fa-fire',
                onSelect = function() smeltAt(index, recipe) end,
            }
        end

        exports.ox_target:addSphereZone({
            coords = coords,
            radius = 2.0,
            options = options,
        })

        lib.points.new({
            coords = coords,
            distance = cfg.smoke and cfg.smoke.renderDistance or 40.0,
            onEnter = function()
                local s = smelters[index]
                if not s.obj then
                    if not requestModelWithCollision(cfg.prop, 10000) then
                        print('[sidejobs] smelter collision never loaded')
                    end
                    local o = CreateObject(cfg.prop, coords.x, coords.y, coords.z,
                        false, false, true)
                    SetEntityCollision(o, true, true)
                    SetEntityLoadCollisionFlag(o, true)
                    -- Heading before freezing: a frozen entity ignores rotation.
                    SetEntityHeading(o, heading)
                    FreezeEntityPosition(o, true)
                    SetEntityInvincible(o, true)
                    s.obj = o
                    SetModelAsNoLongerNeeded(cfg.prop)
                end
                startSmoke(index)
            end,
            onExit = function()
                stopSmoke(index)
                local s = smelters[index]
                if s.obj and DoesEntityExist(s.obj) then DeleteObject(s.obj) end
                s.obj = nil
            end,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    for index, s in pairs(smelters) do
        stopSmoke(index)
        if s.obj and DoesEntityExist(s.obj) then DeleteObject(s.obj) end
    end
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

-- ── Jeweller ────────────────────────────────────────────────────────────
--
-- Gem cutting takes real time. The player hands stones over, walks away, and
-- comes back later -- so nothing about the order is held client-side. The ped
-- is purely a way to talk to the server.

local JEWELLER_MESSAGES = {
    nogems   = 'You have no rough stones.',
    busy     = 'Your last batch is still on the wheel.',
    noorder  = 'Nothing here under your name.',
    notready = 'Not finished yet — come back later.',
    nomoney  = 'You cannot cover the cutting fee.',
    capacity = 'Your bags are full.',
    cooldown = 'One thing at a time.',
    toofar   = 'You are not at the counter.',
}

CreateThread(function()
    local cfg = ImperialSideJobs.jeweller
    if not cfg then return end

    local mins = math.floor(cfg.cutTimeSecPerGem / 60)

    spawnStaticPed('jeweller', cfg.model, cfg.coords, {
        {
            name = 'imperial_jeweller_submit',
            label = 'Hand in uncut gems',
            icon = 'fa-solid fa-gem',
            canInteract = function()
                return (exports.ox_inventory:GetItemCount(cfg.input) or 0) > 0
            end,
            onSelect = function()
                local have = exports.ox_inventory:GetItemCount(cfg.input) or 0
                local most = math.min(have, cfg.maxPerOrder)

                local input = lib.inputDialog('Gem cutting', {
                    {
                        type = 'number',
                        label = 'How many stones?',
                        default = most, min = 1, max = most,
                        description = ('$%d each, about %d min per stone')
                            :format(cfg.feePerGem, mins),
                    },
                })
                if not input or not input[1] then return end

                local ok, extra = lib.callback.await(
                    'imperial_sidejobs:jeweller:submit', false, input[1])
                if ok then
                    lib.notify({
                        type = 'success',
                        title = 'Left with the jeweller',
                        description = ('%d stones, $%s paid. Ready in about %d minutes.')
                            :format(extra.count, lib.math.groupdigits(extra.fee),
                                    math.ceil(extra.seconds / 60)),
                        duration = 10000,
                    })
                else
                    lib.notify({ type = 'error',
                        description = JEWELLER_MESSAGES[extra] or 'He turns you away.' })
                end
            end,
        },
        {
            name = 'imperial_jeweller_collect',
            label = 'Collect finished stones',
            icon = 'fa-solid fa-hand-holding-heart',
            onSelect = function()
                local ok, extra, remaining = lib.callback.await(
                    'imperial_sidejobs:jeweller:collect', false)
                if ok then
                    lib.notify({ type = 'success', title = 'Collected',
                        description = ('+%d %s'):format(extra.count, extra.item),
                        duration = 8000 })
                elseif extra == 'notready' then
                    -- Remaining seconds arrive as a THIRD return value, not on
                    -- `extra` -- `extra` is the reason string in every failure
                    -- case, so the player is told when to come back rather than
                    -- being left to guess.
                    lib.notify({ type = 'error', title = 'Still cutting',
                        description = ('About %d minutes to go.')
                            :format(math.ceil((remaining or 0) / 60)),
                        duration = 8000 })
                else
                    lib.notify({ type = 'error',
                        description = JEWELLER_MESSAGES[extra] or 'Nothing to collect.' })
                end
            end,
        },
    })
end)
