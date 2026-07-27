--- imperial_boosting/server/main.lua
--- Server issues the target vehicle (model + spawn), tracks the contract by
--- network id (never trusts the client's claim of "I stole the right car"),
--- and pays out only on verified delivery within the time limit.

local contracts = {} -- [src] = { model, netId, plate, expiresAt, band }
local reputation = {}

local function loadRep(citizenid)
    if reputation[citizenid] then return reputation[citizenid] end
    local row = MySQL.single.await(
        'SELECT reputation FROM imperial_boosting_reputation WHERE citizenid = ?', { citizenid })
    reputation[citizenid] = row and row.reputation or 0
    return reputation[citizenid]
end

local function bandFor(rep)
    local best = ImperialBoosting.bands[1]
    for _, band in ipairs(ImperialBoosting.bands) do
        if rep >= band.minRep then best = band end
    end
    return best
end

lib.callback.register('imperial_boosting:requestContract', function(src)
    if not exports.imperial_logging:RateLimit(src, 'boost:request', 2, 30000) then return false end
    if contracts[src] then return false, 'active' end
    if not exports.imperial_logging:AcquireLock(src, 'boosting', ImperialBoosting.timeLimitSec * 1000 + 30000) then
        return false, 'active'
    end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then
        exports.imperial_logging:ReleaseLock(src, 'boosting')
        return false
    end
    if exports.ox_inventory:GetItemCount(src, ImperialBoosting.tabletItem) < 1 then
        exports.imperial_logging:ReleaseLock(src, 'boosting')
        return false, 'notablet'
    end

    local rep = loadRep(snap.citizenid)
    local band = bandFor(rep)
    local model = band.models[math.random(#band.models)]

    contracts[src] = {
        model = model, band = band, citizenid = snap.citizenid,
        expiresAt = os.time() + ImperialBoosting.timeLimitSec,
        netId = nil, plate = nil,
    }

    exports.imperial_logging:Log({
        resource = 'imperial_boosting', category = 'gameplay', action = 'contract_issued',
        source = src, data = { model = model, band = band.label },
    })
    return true, { model = model, timeLimit = ImperialBoosting.timeLimitSec }
end)

---Client reports it has spawned/found the target vehicle; server records its
---network id so delivery can be verified against the *same* entity.
lib.callback.register('imperial_boosting:registerVehicle', function(src, netId)
    local contract = contracts[src]
    if not contract then return false end
    local ok, entity = exports.imperial_logging:ValidateNetEntity(src, netId, { [contract.model] = true }, 50.0)
    if not ok then return false end
    contract.netId = netId
    return true
end)

lib.callback.register('imperial_boosting:deliver', function(src)
    local contract = contracts[src]
    if not contract then return false end

    local function finish(ok, err)
        contracts[src] = nil
        exports.imperial_logging:ReleaseLock(src, 'boosting')
        return ok, err
    end

    if os.time() > contract.expiresAt then return finish(false, 'expired') end
    if not contract.netId then return finish(false, 'novehicle') end

    local ok, entity = exports.imperial_logging:ValidateNetEntity(
        src, contract.netId, { [contract.model] = true }, ImperialBoosting.dropoffRadius)
    if not ok then return finish(false, 'wrongvehicle') end

    local coords = GetEntityCoords(entity)
    local drop = ImperialBoosting.dropoff
    if #(coords - vec3(drop.x, drop.y, drop.z)) > ImperialBoosting.dropoffRadius then
        return finish(false, 'notatdropoff')
    end

    local pay = GetConvarInt(contract.band.payConvar, 2000)
    -- 'black_money' (Dirty Money) is an ox_inventory item in this catalogue,
    -- not a qbx_core money-account type — matches imperial_blackmarket's
    -- laundering flow which removes it the same way.
    if exports.ox_inventory:CanCarryItem(src, 'black_money', pay) then
        exports.ox_inventory:AddItem(src, 'black_money', pay)
    else
        -- fall back to bank if the player can't carry that much dirty cash
        -- as a stack (still logged as the boosting payout, not a clean sale)
        local player = exports.qbx_core:GetPlayer(src)
        if player then player.Functions.AddMoney('bank', math.floor(pay / 2), 'imperial-boosting-contract-fallback') end
    end

    reputation[contract.citizenid] = (reputation[contract.citizenid] or 0) + ImperialBoosting.repPerContract
    MySQL.query([[
        INSERT INTO imperial_boosting_reputation (citizenid, reputation) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE reputation = VALUES(reputation)
    ]], { contract.citizenid, reputation[contract.citizenid] })

    DeleteEntity(entity)

    exports.imperial_logging:Log({
        resource = 'imperial_boosting', category = 'money', action = 'contract_delivered',
        source = src, amount = pay, data = { model = contract.model, band = contract.band.label },
    })
    return finish(true, { pay = pay })
end)

RegisterNetEvent('imperial_boosting:server:vehicleEntered', function()
    local src = source
    local contract = contracts[src]
    if not contract or contract.dispatchSent then return end
    if math.random() < ImperialBoosting.dispatchChanceOnTheft then
        contract.dispatchSent = true
        local ped = GetPlayerPed(src)
        exports.imperial_dispatch:CreateDispatchCall({
            code = '10-51', title = 'Vehicle Theft in Progress',
            description = 'A vehicle alarm was triggered',
            coords = GetEntityCoords(ped), jobs = { 'police' }, priority = 3,
        })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    contracts[src] = nil
    exports.imperial_logging:ReleaseLock(src, 'boosting')
end)
