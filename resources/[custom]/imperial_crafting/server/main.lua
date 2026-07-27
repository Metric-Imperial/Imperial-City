--- imperial_crafting/server/main.lua
--- All crafting decisions are server-side. Clients only request (benchId,
--- recipeId, count) and animate; the server owns validation, timing floors,
--- ingredient removal, outputs, XP, unlocks and logging.

local RECIPES = {}
local BENCHES = {}
for _, r in ipairs(ImperialCraftingRecipes) do RECIPES[r.id] = r end
for _, b in ipairs(ImperialCraftingBenches) do BENCHES[b.id] = b end

---Register additional benches/recipes at runtime (e.g. from imperial_businesses
---so hospitality/mechanic stations use the same authoritative crafting flow
---without duplicating validation logic). Safe to call after this resource starts.
---@param bench table bench definition (see config/benches.lua schema)
exports('RegisterBench', function(bench)
    if type(bench) ~= 'table' or not bench.id or BENCHES[bench.id] then return false end
    BENCHES[bench.id] = bench
    return true
end)

---@param recipe table recipe definition (see config/recipes.lua schema)
exports('RegisterRecipe', function(recipe)
    if type(recipe) ~= 'table' or not recipe.id or RECIPES[recipe.id] then return false end
    RECIPES[recipe.id] = recipe
    return true
end)

local xpCache = {}       -- [citizenid] = { [category] = xp }
local unlockCache = {}   -- [citizenid] = { [recipeId] = true }
local crafting = {}      -- [src] = { finishesAt } server-side state machine

-- ── persistence ─────────────────────────────────────────────────────────
local function loadPlayer(citizenid)
    if xpCache[citizenid] then return end
    xpCache[citizenid] = {}
    unlockCache[citizenid] = {}
    local rows = MySQL.query.await(
        'SELECT category, xp FROM imperial_crafting_xp WHERE citizenid = ?', { citizenid })
    for _, row in ipairs(rows or {}) do
        xpCache[citizenid][row.category] = row.xp
    end
    local unlocks = MySQL.query.await(
        'SELECT recipe_id FROM imperial_crafting_unlocks WHERE citizenid = ?', { citizenid })
    for _, row in ipairs(unlocks or {}) do
        unlockCache[citizenid][row.recipe_id] = true
    end
end

local function addXp(citizenid, category, amount)
    loadPlayer(citizenid)
    xpCache[citizenid][category] = (xpCache[citizenid][category] or 0) + amount
    MySQL.query([[
        INSERT INTO imperial_crafting_xp (citizenid, category, xp) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp)
    ]], { citizenid, category, amount })
end

local function levelFor(citizenid, category)
    loadPlayer(citizenid)
    local xp = xpCache[citizenid][category] or 0
    return math.floor((xp / ImperialCrafting.xpBase) ^ 0.7)
end

-- ── validation ──────────────────────────────────────────────────────────
---@return table|nil bench, table|nil recipe, string|nil err
local function validateRequest(src, benchId, recipeId, count)
    local bench = BENCHES[benchId]
    local recipe = RECIPES[recipeId]
    if not bench or not recipe then return nil, nil, 'invalid' end

    local okCat = false
    for _, cat in ipairs(bench.categories) do
        if cat == recipe.category then okCat = true break end
    end
    if not okCat then return nil, nil, 'invalid' end

    if type(count) ~= 'number' or count < 1 or count > ImperialCrafting.maxBatch
        or math.floor(count) ~= count then
        return nil, nil, 'invalid'
    end

    if not exports.imperial_logging:ValidateDistance(src, bench.coords, ImperialCrafting.benchDistance + 2.0) then
        return nil, nil, 'too_far'
    end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil, nil, 'invalid' end

    local r = bench.restrict
    if r then
        if r.job then
            local grade = r.job[snap.job]
            if not grade or snap.jobGrade < grade then return nil, nil, 'restricted' end
        end
        if r.gang then
            -- Dynamic gangs (imperial_gangs) are the source of truth for gang
            -- membership/rank — qbx_core's static PlayerData.gang is never set
            -- by imperial_gangs, so snap.gang/snap.gangGrade only matter for
            -- servers still using static framework gangs (r.gang[gangName]).
            local staticNeed = r.gang[snap.gang]
            local staticOk = staticNeed and snap.gang and snap.gang ~= 'none'
                and snap.gangGrade >= staticNeed

            local dynamicOk = false
            if r.gang['*'] and GetResourceState('imperial_gangs') == 'started' then
                local rank = exports.imperial_gangs:GetMemberRank(snap.citizenid)
                dynamicOk = rank ~= nil and rank >= r.gang['*']
            end

            if not staticOk and not dynamicOk then return nil, nil, 'restricted' end
        end
        if r.item and exports.ox_inventory:GetItemCount(src, r.item) < 1 then
            return nil, nil, 'restricted'
        end
        if r.minLevel and levelFor(snap.citizenid, r.minLevel.category) < r.minLevel.level then
            return nil, nil, 'restricted'
        end
        if r.business then
            -- delegates to imperial_businesses so employment/grade is the single
            -- source of truth; fails closed if that resource is not running.
            if GetResourceState('imperial_businesses') ~= 'started' then
                return nil, nil, 'restricted'
            end
            local ok = exports.imperial_businesses:HasBusinessPermission(src, r.business, r.businessPerm or 'stock')
            if not ok then return nil, nil, 'restricted' end
        end
    end

    if recipe.minLevel and levelFor(snap.citizenid, recipe.category) < recipe.minLevel then
        return nil, nil, 'level'
    end

    if recipe.unlock == 'blueprint' and not unlockCache[snap.citizenid][recipe.id] then
        return nil, nil, 'locked'
    end

    return bench, recipe, nil
end

local PRODUCE_ITEMS = {
    fish = true, wheat = true, corn = true, tomato = true, potato = true,
    lettuce = true, orange = true, apple = true, coffee_beans = true,
    sugarcane = true, herbs = true, cotton = true, grape = true,
}

local function hasIngredients(src, recipe, count)
    for item, need in pairs(recipe.ingredients) do
        if exports.ox_inventory:GetItemCount(src, item) < need * count then
            return false
        end
    end
    if recipe.anyProduce then
        local total = 0
        for item in pairs(PRODUCE_ITEMS) do
            total = total + exports.ox_inventory:GetItemCount(src, item)
        end
        if total < recipe.anyProduce * count then return false end
    end
    return true
end

local function removeIngredients(src, recipe, count)
    for item, need in pairs(recipe.ingredients) do
        if not exports.ox_inventory:RemoveItem(src, item, need * count) then
            return false
        end
    end
    if recipe.anyProduce then
        local remaining = recipe.anyProduce * count
        for item in pairs(PRODUCE_ITEMS) do
            if remaining <= 0 then break end
            local have = exports.ox_inventory:GetItemCount(src, item)
            local take = math.min(have, remaining)
            if take > 0 and exports.ox_inventory:RemoveItem(src, item, take) then
                remaining = remaining - take
            end
        end
        if remaining > 0 then return false end
    end
    return true
end

-- ── craft flow ──────────────────────────────────────────────────────────
---Client asks to begin a craft. Returns duration (ms) for the progress UI, or false.
lib.callback.register('imperial_crafting:startCraft', function(src, benchId, recipeId, count)
    if not exports.imperial_logging:RateLimit(src, 'craft:start',
        ImperialCrafting.rateLimit.max, ImperialCrafting.rateLimit.windowMs) then
        return false, 'ratelimited'
    end
    if not exports.imperial_logging:AcquireLock(src, 'craft', 120000) then
        return false, 'busy'
    end

    local bench, recipe, err = validateRequest(src, benchId, recipeId, count)
    if not bench then
        exports.imperial_logging:ReleaseLock(src, 'craft')
        return false, err
    end
    if not hasIngredients(src, recipe, count) then
        exports.imperial_logging:ReleaseLock(src, 'craft')
        return false, 'ingredients'
    end

    local duration = recipe.duration * count
    crafting[src] = {
        benchId = benchId,
        recipeId = recipeId,
        count = count,
        finishesAt = GetGameTimer() + duration - 500, -- small grace, never early
    }
    return duration
end)

---Client reports completion (after progress bar + optional skill check).
---Server enforces the time floor and re-validates everything.
lib.callback.register('imperial_crafting:finishCraft', function(src, skillCheckPassed)
    local session = crafting[src]
    crafting[src] = nil
    if not session then
        exports.imperial_logging:ReleaseLock(src, 'craft')
        return false, 'nosession'
    end

    local function fail(reason)
        exports.imperial_logging:ReleaseLock(src, 'craft')
        return false, reason
    end

    if GetGameTimer() < session.finishesAt then
        exports.imperial_logging:LogSuspicious(src, 'craft_time_floor', session)
        return fail('early')
    end

    local bench, recipe, err = validateRequest(src, session.benchId, session.recipeId, session.count)
    if not bench then return fail(err) end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return fail('invalid') end

    if recipe.skillCheck and skillCheckPassed ~= true then
        exports.imperial_logging:Log({
            resource = 'imperial_crafting', category = 'gameplay',
            action = 'craft_skillcheck_failed', source = src,
            data = { recipe = recipe.id },
        })
        -- failed skill check consumes half the ingredients (rounded up)
        for item, need in pairs(recipe.ingredients) do
            exports.ox_inventory:RemoveItem(src, item, math.ceil(need * session.count / 2))
        end
        return fail('skillcheck')
    end

    -- Re-check sufficiency immediately before removal (not just at start):
    -- the player may have traded, dropped, or spent an ingredient during the
    -- cook. removeIngredients does not roll back a partial removal, so this
    -- guard is what keeps a failed craft from ever consuming only *some* of
    -- the recipe's materials.
    if not hasIngredients(src, recipe, session.count) then
        return fail('ingredients')
    end
    if not removeIngredients(src, recipe, session.count) then
        -- Should be unreachable given the check above, but if ox_inventory
        -- state changed between the check and the removal (e.g. a concurrent
        -- trade), fail loudly rather than silently eating the discrepancy.
        exports.imperial_logging:LogSuspicious(src, 'craft_partial_removal', {
            recipe = recipe.id, count = session.count,
        })
        return fail('ingredients')
    end

    -- fail chance (server RNG, reduced by level)
    local level = levelFor(snap.citizenid, recipe.category)
    local failChance = math.max(0, (recipe.failChance or 0) - level * ImperialCrafting.failLevelBonus)
    if failChance > 0 and math.random() < failChance then
        addXp(snap.citizenid, recipe.category, math.ceil((recipe.xp or 1) / 4))
        exports.imperial_logging:Log({
            resource = 'imperial_crafting', category = 'gameplay',
            action = 'craft_failed', source = src, data = { recipe = recipe.id, count = session.count },
        })
        exports.imperial_logging:ReleaseLock(src, 'craft')
        return false, 'failed'
    end

    -- capacity check then grant
    for item, n in pairs(recipe.output) do
        if not exports.ox_inventory:CanCarryItem(src, item, n * session.count) then
            return fail('capacity')
        end
    end
    for item, n in pairs(recipe.output) do
        exports.ox_inventory:AddItem(src, item, n * session.count)
    end

    addXp(snap.citizenid, recipe.category, (recipe.xp or 1) * session.count)

    if bench.dispatchChance and math.random() < bench.dispatchChance
        and GetResourceState('imperial_dispatch') == 'started' then
        exports.imperial_dispatch:CreateDispatchCall({
            code = '10-66', title = 'Suspicious Activity',
            description = 'Reports of suspicious workshop noise',
            coords = bench.coords, jobs = { 'police' }, priority = 3,
        })
    end

    exports.imperial_logging:Log({
        resource = 'imperial_crafting', category = 'gameplay',
        action = 'craft_completed', source = src,
        data = { recipe = recipe.id, count = session.count, bench = session.benchId },
    })
    exports.imperial_logging:ReleaseLock(src, 'craft')
    return true
end)

---Menu data for a bench: recipes with availability flags (no secrets leak —
---hidden recipes the player cannot see are filtered out entirely).
lib.callback.register('imperial_crafting:getBenchMenu', function(src, benchId)
    local bench = BENCHES[benchId]
    if not bench then return nil end
    if not exports.imperial_logging:ValidateDistance(src, bench.coords, ImperialCrafting.benchDistance + 3.0) then
        return nil
    end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil end
    loadPlayer(snap.citizenid)

    local out = {}
    for _, recipe in pairs(RECIPES) do
        for _, cat in ipairs(bench.categories) do
            if recipe.category == cat then
                local locked = recipe.unlock == 'blueprint' and not unlockCache[snap.citizenid][recipe.id]
                local level = levelFor(snap.citizenid, recipe.category)
                if not (locked and recipe.hiddenUntilUnlocked) then
                    out[#out + 1] = {
                        id = recipe.id,
                        label = recipe.label,
                        category = recipe.category,
                        duration = recipe.duration,
                        ingredients = recipe.ingredients,
                        anyProduce = recipe.anyProduce,
                        output = recipe.output,
                        locked = locked or (recipe.minLevel or 0) > level,
                        minLevel = recipe.minLevel or 0,
                        level = level,
                        skillCheck = recipe.skillCheck ~= nil,
                    }
                end
            end
        end
    end
    return out
end)

-- Blueprint consumption: usable item handler registered via ox_inventory
-- (items.lua 'blueprint' metadata.recipe). Exported for the item's server use.
exports('UseBlueprint', function(event, item, inventory, slot)
    local src = inventory.id
    local slotData = exports.ox_inventory:GetSlot(src, slot)
    local recipeId = slotData and slotData.metadata and slotData.metadata.recipe
    local recipe = recipeId and RECIPES[recipeId]
    if not recipe then return false end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    loadPlayer(snap.citizenid)
    if unlockCache[snap.citizenid][recipeId] then return false end

    if exports.ox_inventory:RemoveItem(src, 'blueprint', 1, nil, slot) then
        unlockCache[snap.citizenid][recipeId] = true
        MySQL.query('INSERT IGNORE INTO imperial_crafting_unlocks (citizenid, recipe_id) VALUES (?, ?)',
            { snap.citizenid, recipeId })
        exports.imperial_logging:Log({
            resource = 'imperial_crafting', category = 'gameplay',
            action = 'blueprint_learned', source = src, data = { recipe = recipeId },
        })
        return true
    end
    return false
end)

-- cleanup on drop / unload
AddEventHandler('playerDropped', function()
    local src = source
    crafting[src] = nil
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    crafting[src] = nil
end)

exports('GetLevel', function(citizenid, category) return levelFor(citizenid, category) end)
exports('HasUnlock', function(citizenid, recipeId)
    loadPlayer(citizenid)
    return unlockCache[citizenid][recipeId] == true
end)
