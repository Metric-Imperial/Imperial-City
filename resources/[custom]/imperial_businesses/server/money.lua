--- imperial_businesses/server/money.lua
--- All business money movement flows through bizAdjust: atomic DB update,
--- ledger row, cache refresh, audit log. Nothing accepts client amounts
--- without ValidateAmount.

---Atomic balance adjustment with ledger entry.
---@param businessId number
---@param delta integer +credit / -debit
---@param txnType string
---@param actor string|nil citizenid
---@param reason string|nil
---@return boolean ok, integer newBalance
function BizAdjust(businessId, delta, txnType, actor, reason)
    local business = Biz.byId[businessId]
    if not business then return false, 0 end

    local result
    if delta < 0 then
        -- guarded debit: only succeeds when balance is sufficient
        result = MySQL.update.await(
            'UPDATE imperial_businesses SET balance = balance + ? WHERE id = ? AND balance >= ?',
            { delta, businessId, -delta })
        if not result or result == 0 then return false, business.balance end
    else
        MySQL.update.await(
            'UPDATE imperial_businesses SET balance = balance + ? WHERE id = ?',
            { delta, businessId })
    end

    local newBalance = MySQL.scalar.await(
        'SELECT balance FROM imperial_businesses WHERE id = ?', { businessId }) or 0
    business.balance = newBalance

    MySQL.insert([[
        INSERT INTO imperial_business_txns (business_id, actor_citizenid, type, amount, balance_after, reason)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { businessId, actor, txnType, delta, newBalance, reason })

    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'money',
        action = 'biz_' .. txnType, citizenid = actor, amount = delta,
        data = { business = business.business_key, balanceAfter = newBalance, reason = reason },
    })
    return true, newBalance
end

-- ── exported API (server-only consumers) ────────────────────────────────
exports('AddBusinessFunds', function(businessKey, amount, reason, actor)
    local business = Biz.byKey[businessKey]
    if not business then return false end
    local ok, n = exports.imperial_logging:ValidateAmount(amount)
    if not ok then return false end
    return BizAdjust(business.id, n, 'adjust', actor, reason)
end)

exports('RemoveBusinessFunds', function(businessKey, amount, reason, actor)
    local business = Biz.byKey[businessKey]
    if not business then return false end
    local ok, n = exports.imperial_logging:ValidateAmount(amount)
    if not ok then return false end
    return BizAdjust(business.id, -n, 'adjust', actor, reason)
end)

-- ── player deposit / withdraw ───────────────────────────────────────────
lib.callback.register('imperial_businesses:deposit', function(src, businessKey, amount)
    if not exports.imperial_logging:RateLimit(src, 'biz:money', 8, 10000) then return false end
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'deposit')
    if not okPerm then return false end
    local okAmt, n = exports.imperial_logging:ValidateAmount(amount, 1, 1000000)
    if not okAmt then return false end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    if not player.Functions.RemoveMoney('cash', n, 'imperial-business-deposit') then
        return false, 'insufficient'
    end
    local ok, newBalance = BizAdjust(business.id, n, 'deposit', snap.citizenid)
    if not ok then -- refund on the (unlikely) failed credit
        player.Functions.AddMoney('cash', n, 'imperial-business-deposit-refund')
        return false
    end
    return true, newBalance
end)

lib.callback.register('imperial_businesses:withdraw', function(src, businessKey, amount)
    if not exports.imperial_logging:RateLimit(src, 'biz:money', 8, 10000) then return false end
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'withdraw')
    if not okPerm then
        exports.imperial_logging:LogSuspicious(src, 'biz_withdraw_denied', { business = businessKey })
        return false
    end
    local okAmt, n = exports.imperial_logging:ValidateAmount(amount, 1, ImperialBusinesses.maxWithdraw)
    if not okAmt then return false end

    local ok, newBalance = BizAdjust(business.id, -n, 'withdraw', snap.citizenid)
    if not ok then return false, 'insufficient' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then -- pay back into business if player vanished mid-flow
        BizAdjust(business.id, n, 'adjust', snap.citizenid, 'withdraw-rollback')
        return false
    end
    player.Functions.AddMoney('cash', n, 'imperial-business-withdraw')
    return true, newBalance
end)

-- ── ledger ──────────────────────────────────────────────────────────────
lib.callback.register('imperial_businesses:getLedger', function(src, businessKey, page)
    local okPerm, business = BizHasPermission(src, businessKey, 'ledger')
    if not okPerm then return nil end
    page = (type(page) == 'number' and page >= 1 and page <= 100) and math.floor(page) or 1
    local offset = (page - 1) * 25
    return MySQL.query.await([[
        SELECT actor_citizenid, type, amount, balance_after, reason,
               UNIX_TIMESTAMP(created_at) AS at
        FROM imperial_business_txns WHERE business_id = ?
        ORDER BY id DESC LIMIT 25 OFFSET ?
    ]], { business.id, offset })
end)
