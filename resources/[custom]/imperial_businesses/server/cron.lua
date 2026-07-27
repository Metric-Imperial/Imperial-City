--- imperial_businesses/server/cron.lua
--- Wage cycles (on-duty employees, paid from business balance) and daily
--- lease collection with arrears → repossession.

-- ── wages ───────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(ImperialBusinesses.wageCycleMinutes * 60 * 1000)
        for businessId, duty in pairs(Biz.onDuty) do
            local business = Biz.byId[businessId]
            if business and business.active == 1 then
                for citizenid in pairs(duty) do
                    local employee = (Biz.employees[businessId] or {})[citizenid]
                    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
                    if employee and player and employee.wage > 0 then
                        local ok = BizAdjust(businessId, -employee.wage, 'wage', citizenid,
                            'wage:' .. citizenid)
                        if ok then
                            player.Functions.AddMoney('bank', employee.wage, 'imperial-business-wage')
                            exports.qbx_core:Notify(player.PlayerData.source,
                                ('Wage received: $%s'):format(employee.wage), 'success')
                        end
                    elseif not player then
                        duty[citizenid] = nil -- offline: clear stale duty
                    end
                end
            end
        end
    end
end)

-- ── lease (daily) ───────────────────────────────────────────────────────
local function collectLeases()
    for _, business in pairs(Biz.byId) do
        if business.active == 1 and business.owner_citizenid and business.lease_weekly > 0 then
            local daily = math.ceil(business.lease_weekly / 7)
            local ok = BizAdjust(business.id, -daily, 'lease', nil, 'daily-lease')
            if ok then
                if business.lease_arrears > 0 then
                    MySQL.query('UPDATE imperial_businesses SET lease_arrears = 0 WHERE id = ?', { business.id })
                    business.lease_arrears = 0
                end
            else
                local arrears = business.lease_arrears + 1
                MySQL.query('UPDATE imperial_businesses SET lease_arrears = ? WHERE id = ?',
                    { arrears, business.id })
                business.lease_arrears = arrears
                exports.imperial_logging:Log({
                    resource = 'imperial_businesses', category = 'money', action = 'biz_lease_missed',
                    severity = 2, data = { business = business.business_key, arrears = arrears },
                })
                if arrears >= ImperialBusinesses.leaseArrearsLimit then
                    -- repossession: strip owner, keep employees rows for history
                    MySQL.query('UPDATE imperial_businesses SET owner_citizenid = NULL, lease_arrears = 0 WHERE id = ?',
                        { business.id })
                    business.owner_citizenid = nil
                    business.lease_arrears = 0
                    exports.imperial_logging:Log({
                        resource = 'imperial_businesses', category = 'admin', action = 'biz_repossessed',
                        severity = 2, data = { business = business.business_key },
                    })
                end
            end
        end
    end
    exports.imperial_logging:KVSet('biz:lastLeaseRun', os.time())
end

CreateThread(function()
    Wait(5000)
    -- run at most once per 24h, persisted across restarts
    while true do
        local last = exports.imperial_logging:KVGet('biz:lastLeaseRun') or 0
        local nextRun = last + 86400
        local now = os.time()
        if now >= nextRun then
            collectLeases()
        else
            Wait(math.min((nextRun - now) * 1000, 3600 * 1000))
        end
        Wait(60000)
    end
end)
