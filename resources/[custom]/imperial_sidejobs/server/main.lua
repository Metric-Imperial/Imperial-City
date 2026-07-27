--- imperial_sidejobs/server/main.lua
--- Server authority for all side-job rewards. Node depletion, construction
--- shift state and transport runs are tracked server-side; disconnects clean up.

local depletedNodes = {}   -- ['mining:3'] = respawnAtEpoch
local shifts = {}          -- construction: [src] = { tasksDone, currentDrop, carrying }
local runs = {}            -- transport:   [src] = { stops = {...}, collected, vehicleNetId, plate }

local function weightedPick(tbl)
    local total = 0
    for _, e in ipairs(tbl) do total = total + e.weight end
    local roll, acc = math.random() * total, 0
    for _, e in ipairs(tbl) do
        acc = acc + e.weight
        if roll <= acc then return e end
    end
    return tbl[#tbl]
end

local function wearTool(src, item, percent)
    local slots = exports.ox_inventory:Search(src, 'slots', item)
    if not slots or #slots == 0 then return false end
    local slot = slots[1]
    local durability = (slot.metadata and slot.metadata.durability) or 100
    durability = durability - percent
    if durability <= 0 then
        exports.ox_inventory:RemoveItem(src, item, 1, nil, slot.slot)
    else
        exports.ox_inventory:SetMetadata(src, slot.slot, { durability = durability })
    end
    return true
end

local function pay(src, amount, reason)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    player.Functions.AddMoney('cash', amount, reason)
    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'money',
        action = reason, source = src, amount = amount,
    })
    return true
end

-- ── Fishing ─────────────────────────────────────────────────────────────
lib.callback.register('imperial_sidejobs:fish', function(src, skillPassed)
    if not exports.imperial_logging:RateLimit(src, 'sidejob:fish', 1,
        ImperialSideJobs.fishing.castCooldownMs) then
        return false, 'cooldown'
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local inSpot = false
    for _, spot in ipairs(ImperialSideJobs.fishing.spots) do
        if #(coords - spot.coords) <= spot.radius then inSpot = true break end
    end
    if not inSpot then
        exports.imperial_logging:LogSuspicious(src, 'fish_outside_spot', {})
        return false, 'nospot'
    end

    local rods = exports.ox_inventory:Search(src, 'count', 'fishing_rod')
    if (rods or 0) < 1 then return false, 'norod' end
    if exports.ox_inventory:GetItemCount(src, 'fishing_bait') < ImperialSideJobs.fishing.baitPerCast then
        return false, 'nobait'
    end

    exports.ox_inventory:RemoveItem(src, 'fishing_bait', ImperialSideJobs.fishing.baitPerCast)
    wearTool(src, 'fishing_rod', ImperialSideJobs.fishing.rodWearPercent)

    if skillPassed ~= true then return false, 'escaped' end

    local catch = weightedPick(ImperialSideJobs.fishing.catchTable)
    if not catch.item then return false, 'escaped' end
    local n = math.random(catch.count[1], catch.count[2])
    if not exports.ox_inventory:CanCarryItem(src, catch.item, n) then return false, 'capacity' end
    exports.ox_inventory:AddItem(src, catch.item, n)
    return true, n
end)

-- ── Mining / Lumber (shared node logic) ─────────────────────────────────
local function gatherNode(src, kind, index)
    local cfg = ImperialSideJobs[kind]
    local nodes = kind == 'mining' and cfg.nodes or cfg.trees
    local node = nodes[index]
    if not node then return false, 'invalid' end
    if not exports.imperial_logging:ValidateDistance(src, node, 5.0) then return false, 'toofar' end

    local key = ('%s:%d'):format(kind, index)
    local now = os.time()
    if depletedNodes[key] and depletedNodes[key] > now then return false, 'depleted' end

    local tool = kind == 'mining' and 'pickaxe' or 'lumber_axe'
    if (exports.ox_inventory:Search(src, 'count', tool) or 0) < 1 then return false, 'notool' end
    wearTool(src, tool, kind == 'mining' and cfg.pickWearPercent or cfg.axeWearPercent)

    local respawn = kind == 'mining' and cfg.nodeRespawnSec or cfg.treeRespawnSec
    depletedNodes[key] = now + respawn
    TriggerClientEvent('imperial_sidejobs:client:nodeDepleted', -1, kind, index, respawn)

    local item, n
    if kind == 'mining' then
        local ore = weightedPick(cfg.oreTable)
        item, n = ore.item, math.random(ore.count[1], ore.count[2])
    else
        item, n = 'log', math.random(cfg.logsPerTree[1], cfg.logsPerTree[2])
    end
    if not exports.ox_inventory:CanCarryItem(src, item, n) then return false, 'capacity' end
    exports.ox_inventory:AddItem(src, item, n)
    return true, { item = item, count = n }
end

lib.callback.register('imperial_sidejobs:gather', function(src, kind, index)
    if not exports.imperial_logging:RateLimit(src, 'sidejob:gather', 8, 30000) then return false, 'cooldown' end
    if kind ~= 'mining' and kind ~= 'lumber' then return false, 'invalid' end
    if type(index) ~= 'number' then return false, 'invalid' end
    return gatherNode(src, kind, index)
end)

lib.callback.register('imperial_sidejobs:getDepleted', function(_)
    local now = os.time()
    local out = {}
    for key, at in pairs(depletedNodes) do
        if at > now then out[key] = at - now end
    end
    return out
end)

-- ── Construction ────────────────────────────────────────────────────────
lib.callback.register('imperial_sidejobs:construction:start', function(src)
    if shifts[src] then return false, 'active' end
    local cfg = ImperialSideJobs.construction
    if not exports.imperial_logging:ValidateDistance(src, cfg.pickup, 60.0) then return false, 'toofar' end
    shifts[src] = { tasksDone = 0, carrying = false, currentDrop = math.random(#cfg.dropoffs) }
    return true, shifts[src].currentDrop
end)

lib.callback.register('imperial_sidejobs:construction:pickup', function(src)
    local shift = shifts[src]
    if not shift or shift.carrying then return false end
    if not exports.imperial_logging:ValidateDistance(src, ImperialSideJobs.construction.pickup, 4.0) then
        return false
    end
    shift.carrying = true
    return true, shift.currentDrop
end)

lib.callback.register('imperial_sidejobs:construction:deliver', function(src)
    local shift = shifts[src]
    local cfg = ImperialSideJobs.construction
    if not shift or not shift.carrying then return false end
    local drop = cfg.dropoffs[shift.currentDrop]
    if not exports.imperial_logging:ValidateDistance(src, drop, 4.0) then return false end

    shift.carrying = false
    shift.tasksDone = shift.tasksDone + 1
    local wage = GetConvarInt('imperial:econ:pay:construction_task', 45)
    pay(src, wage, 'imperial-construction-task')

    if shift.tasksDone >= cfg.tasksPerShift then
        shifts[src] = nil
        local bonus = GetConvarInt('imperial:econ:pay:construction_bonus', 150)
        pay(src, bonus, 'imperial-construction-shift-bonus')
        return true, { done = true, wage = wage, bonus = bonus }
    end
    shift.currentDrop = math.random(#cfg.dropoffs)
    return true, { done = false, wage = wage, next = shift.currentDrop }
end)

-- ── Secure transport ────────────────────────────────────────────────────
lib.callback.register('imperial_sidejobs:transport:start', function(src)
    if runs[src] then return false, 'active' end
    if not exports.imperial_logging:AcquireLock(src, 'sidejob:transport', 30 * 60000) then
        return false, 'active'
    end
    local cfg = ImperialSideJobs.securetransport
    if not exports.imperial_logging:ValidateDistance(src,
        vec3(cfg.depot.x, cfg.depot.y, cfg.depot.z), 40.0) then
        exports.imperial_logging:ReleaseLock(src, 'sidejob:transport')
        return false, 'toofar'
    end

    -- pick unique stops
    local pool, chosen = {}, {}
    for i = 1, #cfg.stops do pool[i] = i end
    for _ = 1, math.min(cfg.stopsPerRun, #pool) do
        local pick = table.remove(pool, math.random(#pool))
        chosen[#chosen + 1] = pick
    end

    -- server-spawned vehicle with keys
    local veh = CreateVehicleServerSetter(cfg.vehicleModel, 'automobile',
        cfg.depot.x, cfg.depot.y, cfg.depot.z, cfg.depot.w)
    local timeout = 0
    while not DoesEntityExist(veh) and timeout < 50 do Wait(50) timeout = timeout + 1 end
    if not DoesEntityExist(veh) then
        exports.imperial_logging:ReleaseLock(src, 'sidejob:transport')
        return false, 'novehicle'
    end
    local plate = ('SEC%04d'):format(math.random(9999))
    SetVehicleNumberPlateText(veh, plate)
    local netId = NetworkGetNetworkIdFromEntity(veh)

    runs[src] = { stops = chosen, collected = 0, vehicleNetId = netId, plate = plate }
    TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)

    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'gameplay',
        action = 'transport_started', source = src, data = { stops = chosen, plate = plate },
    })
    return true, { stops = chosen, netId = netId }
end)

lib.callback.register('imperial_sidejobs:transport:collect', function(src, stopIndex)
    local run = runs[src]
    if not run then return false end
    local cfg = ImperialSideJobs.securetransport

    local expected = run.stops[run.collected + 1]
    if stopIndex ~= expected then return false, 'wrongstop' end
    if not exports.imperial_logging:ValidateDistance(src, cfg.stops[stopIndex], 6.0) then return false end

    run.collected = run.collected + 1
    return true, { collected = run.collected, total = #run.stops }
end)

local function endRun(src, completed)
    local run = runs[src]
    if not run then return end
    runs[src] = nil
    exports.imperial_logging:ReleaseLock(src, 'sidejob:transport')
    local veh = NetworkGetEntityFromNetworkId(run.vehicleNetId)
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    if completed then
        local cfg = ImperialSideJobs.securetransport
        local perStop = GetConvarInt('imperial:econ:pay:transport_stop', 120)
        local amount = perStop * run.collected
        pay(src, amount, 'imperial-secure-transport')
    end
end

lib.callback.register('imperial_sidejobs:transport:finish', function(src)
    local run = runs[src]
    if not run then return false end
    local cfg = ImperialSideJobs.securetransport
    if not exports.imperial_logging:ValidateDistance(src,
        vec3(cfg.depot.x, cfg.depot.y, cfg.depot.z), 30.0) then
        return false, 'notatdepot'
    end
    if run.collected < 1 then
        endRun(src, false)
        return false, 'nothing'
    end
    local collected = run.collected
    endRun(src, true)
    return true, collected
end)

-- ── Materials buyer ─────────────────────────────────────────────────────
lib.callback.register('imperial_sidejobs:sellMaterials', function(src, item, count)
    local cfg = ImperialSideJobs.buyer
    local price = cfg.prices[item]
    if not price then return false, 'invalid' end
    if not exports.imperial_logging:RateLimit(src, 'sidejob:sell', 10, 10000) then return false, 'cooldown' end
    local okAmount, n = exports.imperial_logging:ValidateAmount(count, 1, cfg.maxPerSale)
    if not okAmount then return false, 'invalid' end
    if not exports.imperial_logging:ValidateDistance(src,
        vec3(cfg.coords.x, cfg.coords.y, cfg.coords.z), 5.0) then
        return false, 'toofar'
    end

    local have = exports.ox_inventory:GetItemCount(src, item)
    n = math.min(n, have)
    if n < 1 then return false, 'none' end
    if not exports.ox_inventory:RemoveItem(src, item, n) then return false, 'none' end

    local unit = GetConvarInt(price.convar, price.default)
    local total = unit * n
    pay(src, total, 'imperial-materials-sale')
    return true, total
end)

-- ── cleanup ─────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    shifts[src] = nil
    endRun(src, false)
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    shifts[src] = nil
    endRun(src, false)
end)

-- prune depleted-node table hourly
CreateThread(function()
    while true do
        Wait(3600 * 1000)
        local now = os.time()
        for key, at in pairs(depletedNodes) do
            if at <= now then depletedNodes[key] = nil end
        end
    end
end)
