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

---Character id for persistence keys. Defined up here with the other helpers
---because both smelting and the jeweller call it -- a `local` declared further
---down the file is nil at the point the earlier callback runs.
local function citizenOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
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

---Node identity. Mining nodes are grouped by ore, so the ore id is part of the
---key -- a coal seam and an iron deposit can both be index 1. Must stay in step
---with nodeKey() on the client.
local function nodeKey(kind, group, index)
    return group and ('%s:%s:%d'):format(kind, group, index)
        or ('%s:%d'):format(kind, index)
end

---@param group? string ore id for mining, nil for lumber
---@param skillPassed boolean did the player land the swing
local function gatherNode(src, kind, index, group, skillPassed)
    local cfg = ImperialSideJobs[kind]

    -- Mining nodes live under their ore and yield that ore specifically; lumber
    -- keeps a single flat list. There is no shared random ore table any more --
    -- a coal seam gives coal.
    local ore, node
    if kind == 'mining' then
        ore = cfg.ores[group]
        if not ore then return false, 'invalid' end
        node = ore.nodes[index]
    else
        node = cfg.trees[index]
    end
    if not node then return false, 'invalid' end
    if not exports.imperial_logging:ValidateDistance(src, node, 5.0) then return false, 'toofar' end

    local key = nodeKey(kind, group, index)
    local now = os.time()
    if depletedNodes[key] and depletedNodes[key] > now then return false, 'depleted' end

    local tool = kind == 'mining' and 'pickaxe' or 'lumber_axe'
    if (exports.ox_inventory:Search(src, 'count', tool) or 0) < 1 then return false, 'notool' end

    -- Wear applies whether or not the strike lands: a fluffed swing still blunts
    -- the pick.
    wearTool(src, tool, kind == 'mining' and cfg.pickWearPercent or cfg.axeWearPercent)

    -- A missed skill check costs the swing but not the node, which stays
    -- workable for the next attempt.
    if skillPassed ~= true then return false, 'missed' end

    local item, n
    if kind == 'mining' then
        item, n = ore.item, math.random(ore.count[1], ore.count[2])
    else
        item, n = 'log', math.random(cfg.logsPerTree[1], cfg.logsPerTree[2])
    end

    -- Checked before depleting, so a full inventory does not burn the node.
    if not exports.ox_inventory:CanCarryItem(src, item, n) then return false, 'capacity' end

    local respawn = kind == 'mining' and cfg.nodeRespawnSec or cfg.treeRespawnSec
    depletedNodes[key] = now + respawn
    TriggerClientEvent('imperial_sidejobs:client:nodeDepleted', -1, kind, index, group, respawn)

    exports.ox_inventory:AddItem(src, item, n)
    return true, { item = item, count = n }
end

lib.callback.register('imperial_sidejobs:gather', function(src, kind, index, group, skillPassed)
    if not exports.imperial_logging:RateLimit(src, 'sidejob:gather', 8, 30000) then return false, 'cooldown' end
    if kind ~= 'mining' and kind ~= 'lumber' then return false, 'invalid' end
    if type(index) ~= 'number' then return false, 'invalid' end
    if kind == 'mining' and type(group) ~= 'string' then return false, 'invalid' end
    return gatherNode(src, kind, index, group, skillPassed)
end)

-- ── Smelting ────────────────────────────────────────────────────────────
--
-- A batch, not a single ingot. Ore and coal go in now, metal comes out later,
-- so the order outlives the interaction and has to be persisted -- same reason
-- as the jeweller. Schema in sql/014_smelting.sql; also created here so a
-- running server needs no hand-applied migration.
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `imperial_smelt_orders` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(50) NOT NULL,
          `site` INT UNSIGNED NOT NULL,
          `output` VARCHAR(64) NOT NULL,
          `count` INT UNSIGNED NOT NULL,
          `ready_at` INT UNSIGNED NOT NULL,
          `collected` TINYINT(1) NOT NULL DEFAULT 0,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_smelt_citizen` (`citizenid`, `site`, `collected`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end)

lib.callback.register('imperial_sidejobs:smelt:start', function(src, index, input, units)
    if not exports.imperial_logging:RateLimit(src, 'sidejob:smelt', 6, 30000) then
        return false, 'cooldown'
    end
    if type(index) ~= 'number' or type(input) ~= 'string' then return false, 'invalid' end

    local cfg = ImperialSideJobs.smelting
    local site = cfg.sites[index]
    if not site then return false, 'invalid' end
    if not exports.imperial_logging:ValidateDistance(src, site.coords, 5.0) then
        return false, 'toofar'
    end

    -- Recipe looked up by input item; the client only says which ore it fed in.
    local recipe
    for _, r in ipairs(cfg.recipes) do
        if r.input == input then recipe = r break end
    end
    if not recipe then return false, 'invalid' end

    -- Batch size is clamped server-side. The client's number is a request.
    local cap = site.maxPerBatch or cfg.defaultMaxPerBatch
    units = math.floor(tonumber(units) or 0)
    if units < 1 then return false, 'noore' end
    units = math.min(units, cap)

    local citizenid = citizenOf(src)
    if not citizenid then return false, 'invalid' end

    -- One batch per player per furnace: two people can run the same furnace at
    -- once, which matters for a public one, but nobody can queue up five.
    local pending = MySQL.scalar.await(
        'SELECT id FROM imperial_smelt_orders WHERE citizenid = ? AND site = ? AND collected = 0 LIMIT 1',
        { citizenid, index })
    if pending then return false, 'busy' end

    local needOre = recipe.count * units
    local needFuel = cfg.fuel.perUnit * units
    if (exports.ox_inventory:Search(src, 'count', recipe.input) or 0) < needOre then
        return false, 'noore'
    end
    if (exports.ox_inventory:Search(src, 'count', cfg.fuel.item) or 0) < needFuel then
        return false, 'nofuel'
    end

    -- Ore first: if it cannot be taken there is nothing to smelt, and taking the
    -- fuel first would burn coal for a batch that never starts.
    if not exports.ox_inventory:RemoveItem(src, recipe.input, needOre) then
        return false, 'noore'
    end
    exports.ox_inventory:RemoveItem(src, cfg.fuel.item, needFuel)

    local seconds = cfg.smeltTimeSecPerUnit * units
    MySQL.insert.await(
        'INSERT INTO imperial_smelt_orders (citizenid, site, output, count, ready_at) VALUES (?, ?, ?, ?, ?)',
        { citizenid, index, recipe.output, recipe.yield * units, os.time() + seconds })

    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'craft',
        action = 'smelt-start-' .. recipe.output, source = src, amount = units,
    })
    return true, { units = units, output = recipe.output, seconds = seconds }
end)

lib.callback.register('imperial_sidejobs:smelt:collect', function(src, index)
    if type(index) ~= 'number' then return false, 'invalid' end

    local cfg = ImperialSideJobs.smelting
    local site = cfg.sites[index]
    if not site then return false, 'invalid' end
    if not exports.imperial_logging:ValidateDistance(src, site.coords, 5.0) then
        return false, 'toofar'
    end

    local citizenid = citizenOf(src)
    if not citizenid then return false, 'invalid' end

    local order = MySQL.single.await(
        'SELECT id, output, count, ready_at FROM imperial_smelt_orders WHERE citizenid = ? AND site = ? AND collected = 0 LIMIT 1',
        { citizenid, index })
    if not order then return false, 'noorder' end

    local now = os.time()
    if order.ready_at > now then
        return false, 'notready', order.ready_at - now
    end

    if not exports.ox_inventory:CanCarryItem(src, order.output, order.count) then
        return false, 'capacity'
    end

    -- Claimed before handing over, guarded on collected = 0, so a double-click
    -- cannot pay out twice.
    local claimed = MySQL.update.await(
        'UPDATE imperial_smelt_orders SET collected = 1 WHERE id = ? AND collected = 0',
        { order.id })
    if not claimed or claimed < 1 then return false, 'noorder' end

    exports.ox_inventory:AddItem(src, order.output, order.count)
    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'craft',
        action = 'smelt-collect-' .. order.output, source = src, amount = order.count,
    })
    return true, { item = order.output, count = order.count }
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

-- ── Jeweller ────────────────────────────────────────────────────────────
--
-- Cutting takes real time, so an order has to outlive the interaction, the
-- player's session and a server restart. That rules out an in-memory table:
-- a restart would silently eat everyone's stones.

-- The schema also ships as sql/013_jeweller.sql for fresh deploys. Creating it
-- here as well means an already-running server picks it up on restart without
-- anyone hand-applying migrations. CREATE TABLE IF NOT EXISTS is idempotent, so
-- running both ways is harmless.
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `imperial_jeweller_orders` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(50) NOT NULL,
          `count` INT UNSIGNED NOT NULL,
          `ready_at` INT UNSIGNED NOT NULL,
          `collected` TINYINT(1) NOT NULL DEFAULT 0,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_jeweller_citizen` (`citizenid`, `collected`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end)

lib.callback.register('imperial_sidejobs:jeweller:submit', function(src, count)
    if not exports.imperial_logging:RateLimit(src, 'sidejob:jeweller', 4, 30000) then
        return false, 'cooldown'
    end

    local cfg = ImperialSideJobs.jeweller
    if not exports.imperial_logging:ValidateDistance(src, cfg.coords.xyz, 5.0) then
        return false, 'toofar'
    end

    -- Clamped server-side: the client's number is a request, not an instruction.
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false, 'nogems' end
    count = math.min(count, cfg.maxPerOrder)

    local citizenid = citizenOf(src)
    if not citizenid then return false, 'noorder' end

    -- One batch at a time, which keeps the fiction simple and stops the table
    -- filling with parallel orders from one player.
    local pending = MySQL.scalar.await(
        'SELECT id FROM imperial_jeweller_orders WHERE citizenid = ? AND collected = 0 LIMIT 1',
        { citizenid })
    if pending then return false, 'busy' end

    if (exports.ox_inventory:Search(src, 'count', cfg.input) or 0) < count then
        return false, 'nogems'
    end

    local player = exports.qbx_core:GetPlayer(src)
    local fee = cfg.feePerGem * count
    if not player.Functions.RemoveMoney('cash', fee, 'imperial-jeweller-cutting') then
        return false, 'nomoney'
    end

    -- Stones leave the player's hands now; only the receipt goes in the table.
    if not exports.ox_inventory:RemoveItem(src, cfg.input, count) then
        player.Functions.AddMoney('cash', fee, 'imperial-jeweller-refund')
        return false, 'nogems'
    end

    local seconds = cfg.cutTimeSecPerGem * count
    MySQL.insert.await(
        'INSERT INTO imperial_jeweller_orders (citizenid, count, ready_at) VALUES (?, ?, ?)',
        { citizenid, count, os.time() + seconds })

    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'money',
        action = 'jeweller-cutting-fee', source = src, amount = fee,
    })
    return true, { count = count, fee = fee, seconds = seconds }
end)

lib.callback.register('imperial_sidejobs:jeweller:collect', function(src)
    local cfg = ImperialSideJobs.jeweller
    if not exports.imperial_logging:ValidateDistance(src, cfg.coords.xyz, 5.0) then
        return false, 'toofar'
    end

    local citizenid = citizenOf(src)
    if not citizenid then return false, 'noorder' end

    local order = MySQL.single.await(
        'SELECT id, count, ready_at FROM imperial_jeweller_orders WHERE citizenid = ? AND collected = 0 LIMIT 1',
        { citizenid })
    if not order then return false, 'noorder' end

    local now = os.time()
    if order.ready_at > now then
        return false, 'notready', order.ready_at - now
    end

    local out = weightedPick(cfg.outputs)
    if not exports.ox_inventory:CanCarryItem(src, out.item, order.count) then
        return false, 'capacity'
    end

    -- Marked collected before handing over, and guarded on collected = 0, so a
    -- double-click cannot pay out twice.
    local claimed = MySQL.update.await(
        'UPDATE imperial_jeweller_orders SET collected = 1 WHERE id = ? AND collected = 0',
        { order.id })
    if not claimed or claimed < 1 then return false, 'noorder' end

    exports.ox_inventory:AddItem(src, out.item, order.count)
    exports.imperial_logging:Log({
        resource = 'imperial_sidejobs', category = 'craft',
        action = 'jeweller-collect-' .. out.item, source = src, amount = order.count,
    })
    return true, { item = out.item, count = order.count }
end)
