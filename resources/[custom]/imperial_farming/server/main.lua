--- imperial_farming/server/main.lua
--- Plants persist in imperial_farm_plants. Growth, health and quality are
--- computed lazily from timestamps — no growth threads, restart-safe.

local CROPS = ImperialFarming.crops

-- ── helpers ─────────────────────────────────────────────────────────────
local function inZone(coords)
    for _, zone in ipairs(ImperialFarming.zones) do
        if #(vec3(coords.x, coords.y, coords.z) - zone.coords) <= zone.radius then
            return zone
        end
    end
    return nil
end

---Compute derived state for a plant row.
---@return integer stage 1..4, number health 0..100, boolean mature
local function derive(row)
    local crop = CROPS[row.crop]
    local now = os.time()
    local elapsedMin = (now - row.planted_at) / 60
    local progress = math.min(1.0, elapsedMin / crop.growthMinutes)
    local stage = math.max(1, math.min(4, 1 + math.floor(progress * 3.999)))

    -- health decays for each missed watering interval while growing
    local sinceWaterMin = (now - row.watered_at) / 60
    local missed = math.max(0, math.floor(sinceWaterMin / ImperialFarming.waterIntervalMinutes) - 1)
    local health = math.max(0, row.health - missed * ImperialFarming.missedWaterHealthLoss)

    return stage, health, progress >= 1.0
end

local function plantCount(citizenid)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM imperial_farm_plants WHERE citizenid = ?', { citizenid }) or 0
end

-- ── planting ────────────────────────────────────────────────────────────
lib.callback.register('imperial_farming:plant', function(src, cropName, coords)
    if not exports.imperial_logging:RateLimit(src, 'farm:plant', 6, 10000) then return false, 'ratelimited' end
    local crop = CROPS[cropName]
    if not crop or type(coords) ~= 'vector3' then return false, 'invalid' end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false, 'invalid' end

    if not exports.imperial_logging:ValidateDistance(src, coords, 5.0) then return false, 'too_far' end
    local zone = inZone(coords)
    if not zone then return false, 'not_farmland' end

    if plantCount(snap.citizenid) >= ImperialFarming.maxPlantsPerPlayer then
        return false, 'limit'
    end

    -- spacing: any existing plant within minSpacing blocks planting
    local nearby = MySQL.scalar.await([[
        SELECT COUNT(*) FROM imperial_farm_plants
        WHERE ABS(x - ?) < ? AND ABS(y - ?) < ?
    ]], { coords.x, ImperialFarming.minSpacing, coords.y, ImperialFarming.minSpacing })
    if (nearby or 0) > 0 then return false, 'too_close' end

    if not exports.ox_inventory:RemoveItem(src, crop.seed, 1) then
        return false, 'no_seed'
    end

    local now = os.time()
    local id = MySQL.insert.await([[
        INSERT INTO imperial_farm_plants
            (citizenid, crop, x, y, z, planted_at, watered_at, fertilised, health)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, 100)
    ]], { snap.citizenid, cropName, coords.x, coords.y, coords.z, now, now })

    exports.imperial_logging:Log({
        resource = 'imperial_farming', category = 'gameplay', action = 'plant',
        source = src, data = { crop = cropName, id = id, zone = zone.id },
    })
    return true, id
end)

-- ── sync: plants near the player ────────────────────────────────────────
lib.callback.register('imperial_farming:getNearbyPlants', function(src, coords)
    if type(coords) ~= 'vector3' then return {} end
    if not exports.imperial_logging:RateLimit(src, 'farm:sync', 6, 30000) then return {} end
    local r = ImperialFarming.syncRadius
    local rows = MySQL.query.await([[
        SELECT id, citizenid, crop, x, y, z, planted_at, watered_at, fertilised, health
        FROM imperial_farm_plants
        WHERE x BETWEEN ? AND ? AND y BETWEEN ? AND ?
    ]], { coords.x - r, coords.x + r, coords.y - r, coords.y + r })

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local stage, health, mature = derive(row)
        out[#out + 1] = {
            id = row.id,
            crop = row.crop,
            coords = { x = row.x, y = row.y, z = row.z },
            stage = stage,
            mature = mature,
            health = health,
            owned = snap and snap.citizenid == row.citizenid,
            needsWater = ((os.time() - row.watered_at) / 60) > ImperialFarming.waterIntervalMinutes,
        }
    end
    return out
end)

-- ── shared action validation ────────────────────────────────────────────
local function fetchPlantFor(src, plantId)
    if type(plantId) ~= 'number' then return nil end
    local row = MySQL.single.await(
        'SELECT * FROM imperial_farm_plants WHERE id = ?', { plantId })
    if not row then return nil end
    if not exports.imperial_logging:ValidateDistance(src, vec3(row.x, row.y, row.z), 4.0) then
        return nil
    end
    return row
end

-- ── watering ────────────────────────────────────────────────────────────
lib.callback.register('imperial_farming:water', function(src, plantId)
    if not exports.imperial_logging:RateLimit(src, 'farm:action', 10, 10000) then return false end
    local row = fetchPlantFor(src, plantId)
    if not row then return false end

    local can = exports.ox_inventory:Search(src, 'slots', 'watering_can')
    if not can or #can == 0 then return false, 'no_can' end

    -- wear the can slightly (degradable item handles its own lifecycle)
    local _, health = derive(row)
    MySQL.query('UPDATE imperial_farm_plants SET watered_at = ?, health = LEAST(100, ? + 10) WHERE id = ?',
        { os.time(), health, plantId })
    return true
end)

-- ── fertilising ─────────────────────────────────────────────────────────
lib.callback.register('imperial_farming:fertilise', function(src, plantId)
    if not exports.imperial_logging:RateLimit(src, 'farm:action', 10, 10000) then return false end
    local row = fetchPlantFor(src, plantId)
    if not row then return false end
    if row.fertilised == 1 then return false, 'already' end

    if not exports.ox_inventory:RemoveItem(src, 'fertiliser', 1)
        and not exports.ox_inventory:RemoveItem(src, 'weed_nutrition', 1) then
        return false, 'no_fertiliser'
    end
    MySQL.query('UPDATE imperial_farm_plants SET fertilised = 1 WHERE id = ?', { plantId })
    return true
end)

-- ── harvesting ──────────────────────────────────────────────────────────
lib.callback.register('imperial_farming:harvest', function(src, plantId)
    if not exports.imperial_logging:RateLimit(src, 'farm:action', 10, 10000) then return false end
    if not exports.imperial_logging:AcquireLock(src, 'farm:harvest', 15000) then return false end

    local function done(ok, reason)
        exports.imperial_logging:ReleaseLock(src, 'farm:harvest')
        return ok, reason
    end

    local row = fetchPlantFor(src, plantId)
    if not row then return done(false) end

    local crop = CROPS[row.crop]
    local stage, health, mature = derive(row)
    if not mature then return done(false, 'not_ready') end
    if health <= 0 then
        -- dead plant: remove, nothing gained
        MySQL.query('DELETE FROM imperial_farm_plants WHERE id = ?', { plantId })
        TriggerClientEvent('imperial_farming:client:removePlant', -1, plantId)
        return done(false, 'dead')
    end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return done(false) end
    local isOwner = snap.citizenid == row.citizenid

    if not isOwner and not ImperialFarming.allowTheft then
        return done(false, 'not_yours')
    end

    -- Atomic claim: delete first so two harvesters can't double-collect.
    local affected = MySQL.update.await('DELETE FROM imperial_farm_plants WHERE id = ?', { plantId })
    if not affected or affected == 0 then return done(false) end
    TriggerClientEvent('imperial_farming:client:removePlant', -1, plantId)

    local yieldMin, yieldMax = crop.yield[1], crop.yield[2]
    local base = math.random(yieldMin, yieldMax)
    local qualityMult = (health / 100) * (row.fertilised == 1 and 1.25 or 1.0)
    local amount = math.max(1, math.floor(base * qualityMult))
    if not isOwner then
        amount = math.max(1, math.floor(amount * ImperialFarming.theftYieldMultiplier))
        if math.random() < ImperialFarming.theftDispatchChance
            and GetResourceState('imperial_dispatch') == 'started' then
            exports.imperial_dispatch:CreateDispatchCall({
                code = '10-31', title = 'Crop Theft',
                description = 'A farmer reports someone raiding crops',
                coords = vec3(row.x, row.y, row.z), jobs = { 'police' }, priority = 3,
            })
        end
    end

    if not exports.ox_inventory:CanCarryItem(src, crop.produce, amount) then
        -- refund the plant row rather than voiding the crop
        MySQL.insert(
            [[INSERT INTO imperial_farm_plants (citizenid, crop, x, y, z, planted_at, watered_at, fertilised, health)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            { row.citizenid, row.crop, row.x, row.y, row.z, row.planted_at, row.watered_at, row.fertilised, row.health })
        return done(false, 'capacity')
    end

    exports.ox_inventory:AddItem(src, crop.produce, amount)
    if math.random() < crop.seedReturnChance then
        exports.ox_inventory:AddItem(src, crop.seed, 1)
    end

    exports.imperial_logging:Log({
        resource = 'imperial_farming', category = 'gameplay',
        action = isOwner and 'harvest' or 'harvest_theft',
        source = src, targetCitizenid = not isOwner and row.citizenid or nil,
        data = { crop = row.crop, amount = amount, plantId = plantId },
    })
    return done(true, amount)
end)

-- ── wholesale ───────────────────────────────────────────────────────────
lib.callback.register('imperial_farming:sellBoxes', function(src, count)
    if not exports.imperial_logging:RateLimit(src, 'farm:sell', 5, 10000) then return false end
    local okAmount, n = exports.imperial_logging:ValidateAmount(count, 1, 50)
    if not okAmount then return false end

    local w = ImperialFarming.wholesaler
    if not exports.imperial_logging:ValidateDistance(src, vec3(w.coords.x, w.coords.y, w.coords.z), 5.0) then
        return false
    end

    local have = exports.ox_inventory:GetItemCount(src, 'produce_box')
    n = math.min(n, have)
    if n < 1 then return false, 'none' end
    if not exports.ox_inventory:RemoveItem(src, 'produce_box', n) then return false end

    local price = GetConvarInt('imperial:econ:pay:produce_box', w.defaultBoxPrice)
    local total = price * n
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    player.Functions.AddMoney('cash', total, 'imperial-farming-wholesale')

    exports.imperial_logging:Log({
        resource = 'imperial_farming', category = 'money', action = 'wholesale_sale',
        source = src, amount = total, data = { boxes = n },
    })
    return true, total
end)

-- Admin/maintenance: prune dead plants daily (lazy health already handles gameplay)
CreateThread(function()
    while true do
        Wait(6 * 3600 * 1000)
        MySQL.query([[
            DELETE FROM imperial_farm_plants
            WHERE planted_at < (UNIX_TIMESTAMP() - 7 * 86400)
        ]])
    end
end)
