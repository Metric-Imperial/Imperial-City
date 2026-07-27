--- imperial_gangs/server/money.lua
--- Gang account: same atomic-adjust + ledger pattern as imperial_businesses.

local function gangAdjust(gangId, delta, txnType, actor, reason)
    local gang = Gangs.byId[gangId]
    if not gang then return false, 0 end

    local result
    if delta < 0 then
        result = MySQL.update.await(
            'UPDATE imperial_gangs SET balance = balance + ? WHERE id = ? AND balance >= ?',
            { delta, gangId, -delta })
        if not result or result == 0 then return false, gang.balance end
    else
        MySQL.update.await('UPDATE imperial_gangs SET balance = balance + ? WHERE id = ?', { delta, gangId })
    end

    local newBalance = MySQL.scalar.await('SELECT balance FROM imperial_gangs WHERE id = ?', { gangId }) or 0
    gang.balance = newBalance

    MySQL.insert([[
        INSERT INTO imperial_gang_txns (gang_id, actor_citizenid, type, amount, balance_after, reason)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { gangId, actor, txnType, delta, newBalance, reason })

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'money', action = 'gang_' .. txnType,
        citizenid = actor, amount = delta, data = { gang = gang.gang_key, reason = reason },
    })
    return true, newBalance
end

exports('AddGangFunds', function(gangKey, amount, reason, actor)
    local gang = Gangs.byKey[gangKey]
    if not gang then return false end
    local ok, n = exports.imperial_logging:ValidateAmount(amount)
    if not ok then return false end
    return gangAdjust(gang.id, n, 'adjust', actor, reason)
end)

exports('RemoveGangFunds', function(gangKey, amount, reason, actor)
    local gang = Gangs.byKey[gangKey]
    if not gang then return false end
    local ok, n = exports.imperial_logging:ValidateAmount(amount)
    if not ok then return false end
    return gangAdjust(gang.id, -n, 'adjust', actor, reason)
end)

lib.callback.register('imperial_gangs:deposit', function(src, amount)
    if not exports.imperial_logging:RateLimit(src, 'gang:money', 8, 10000) then return false end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gangId = Gangs.memberOf[snap.citizenid]
    if not gangId then return false end
    local member = Gangs.members[gangId][snap.citizenid]
    if member.rank < ImperialGangs.permissions.deposit then return false end

    local okAmt, n = exports.imperial_logging:ValidateAmount(amount, 1, 1000000)
    if not okAmt then return false end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.Functions.RemoveMoney('cash', n, 'imperial-gang-deposit') then
        return false, 'insufficient'
    end
    local ok, newBalance = gangAdjust(gangId, n, 'deposit', snap.citizenid)
    if not ok then
        player.Functions.AddMoney('cash', n, 'imperial-gang-deposit-refund')
        return false
    end
    return true, newBalance
end)

lib.callback.register('imperial_gangs:withdraw', function(src, amount)
    if not exports.imperial_logging:RateLimit(src, 'gang:money', 8, 10000) then return false end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gangId = Gangs.memberOf[snap.citizenid]
    if not gangId then return false end
    local member = Gangs.members[gangId][snap.citizenid]
    if member.rank < ImperialGangs.permissions.withdraw then return false end

    local okAmt, n = exports.imperial_logging:ValidateAmount(amount, 1, ImperialGangs.maxWithdraw)
    if not okAmt then return false end

    local ok, newBalance = gangAdjust(gangId, -n, 'withdraw', snap.citizenid)
    if not ok then return false, 'insufficient' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        gangAdjust(gangId, n, 'adjust', snap.citizenid, 'withdraw-rollback')
        return false
    end
    player.Functions.AddMoney('cash', n, 'imperial-gang-withdraw')
    return true, newBalance
end)
