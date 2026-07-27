--- imperial_blackmarket/server/main.lua
--- Fence (contraband → crim_token) and laundering (dirty cash → clean cash
--- over time, at a fee, capped per job). Both are server-authoritative.

-- ── fencing ─────────────────────────────────────────────────────────────
lib.callback.register('imperial_blackmarket:sell', function(src, item, count)
    if not exports.imperial_logging:RateLimit(src, 'bm:sell',
        ImperialBlackmarket.rateLimit.max, ImperialBlackmarket.rateLimit.windowMs) then
        return false
    end
    local rate = ImperialBlackmarket.buyRates[item]
    if not rate then return false, 'notbuying' end
    local okAmount, n = exports.imperial_logging:ValidateAmount(count, 1, ImperialBlackmarket.maxSellPerTxn)
    if not okAmount then return false end

    local fence = ImperialBlackmarket.fence
    if not exports.imperial_logging:ValidateDistance(src,
        vec3(fence.coords.x, fence.coords.y, fence.coords.z), fence.radius + 2.0) then
        return false, 'toofar'
    end

    local have = exports.ox_inventory:GetItemCount(src, item)
    n = math.min(n, have)
    if n < 1 then return false, 'none' end
    if not exports.ox_inventory:RemoveItem(src, item, n) then return false end

    local total = rate * n
    if not exports.ox_inventory:CanCarryItem(src, 'crim_token', total) then
        -- refund the goods rather than voiding them
        exports.ox_inventory:AddItem(src, item, n)
        return false, 'capacity'
    end
    exports.ox_inventory:AddItem(src, 'crim_token', total)

    exports.imperial_logging:Log({
        resource = 'imperial_blackmarket', category = 'gameplay', action = 'fence_sale',
        source = src, data = { item = item, count = n, tokens = total },
    })
    return true, total
end)

-- ── laundering ──────────────────────────────────────────────────────────
lib.callback.register('imperial_blackmarket:startLaunder', function(src, frontIndex, amount)
    if not exports.imperial_logging:RateLimit(src, 'bm:launder', 3, 30000) then return false end
    local front = ImperialBlackmarket.launderFronts[frontIndex]
    if not front then return false end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end

    local okAmount, n = exports.imperial_logging:ValidateAmount(
        amount, ImperialBlackmarket.launderMinAmount, front.maxPerJob)
    if not okAmount then return false, 'invalid' end

    if not exports.imperial_logging:ValidateDistance(src,
        vec3(front.coords.x, front.coords.y, front.coords.z), 5.0) then
        return false, 'toofar'
    end

    -- one active launder job per player at a time
    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM imperial_launder_jobs WHERE citizenid = ? AND collected = 0',
        { snap.citizenid })
    if (existing or 0) > 0 then return false, 'active' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    -- "dirty money" is represented by the black_money item (already in the
    -- catalogue); robberies/criminal payouts should grant black_money, not cash.
    if not exports.ox_inventory:RemoveItem(src, 'black_money', n) then
        return false, 'nodirty'
    end

    local feePct = GetConvarInt('imperial:econ:crime:launderFeePct', 22)
    local clean = math.floor(n * (100 - feePct) / 100)
    local readyAt = os.time() + front.durationSec

    local jobId = MySQL.insert.await([[
        INSERT INTO imperial_launder_jobs (citizenid, dirty_amount, clean_amount, ready_at)
        VALUES (?, ?, ?, ?)
    ]], { snap.citizenid, n, clean, readyAt })

    exports.imperial_logging:Log({
        resource = 'imperial_blackmarket', category = 'money', action = 'launder_started',
        source = src, amount = n, data = { jobId = jobId, clean = clean, fee = feePct },
    })
    return true, { jobId = jobId, readyAt = readyAt, clean = clean }
end)

lib.callback.register('imperial_blackmarket:collectLaunder', function(src)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end

    local job = MySQL.single.await(
        'SELECT * FROM imperial_launder_jobs WHERE citizenid = ? AND collected = 0 ORDER BY id DESC LIMIT 1',
        { snap.citizenid })
    if not job then return false, 'none' end
    if os.time() < job.ready_at then return false, 'notready' end

    local affected = MySQL.update.await(
        'UPDATE imperial_launder_jobs SET collected = 1 WHERE id = ? AND collected = 0', { job.id })
    if not affected or affected == 0 then return false end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    player.Functions.AddMoney('bank', job.clean_amount, 'imperial-launder-collect')

    exports.imperial_logging:Log({
        resource = 'imperial_blackmarket', category = 'money', action = 'launder_collected',
        source = src, amount = job.clean_amount, data = { jobId = job.id },
    })
    return true, job.clean_amount
end)

lib.callback.register('imperial_blackmarket:getLaunderStatus', function(src)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil end
    local job = MySQL.single.await(
        'SELECT * FROM imperial_launder_jobs WHERE citizenid = ? AND collected = 0 ORDER BY id DESC LIMIT 1',
        { snap.citizenid })
    if not job then return nil end
    return { readyAt = job.ready_at, clean = job.clean_amount, ready = os.time() >= job.ready_at }
end)
