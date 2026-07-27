--- imperial_businesses/server/employees.lua
--- Hiring, firing, grades, wages, ownership transfer, management data.

local function employeeRow(business, citizenid)
    return (Biz.employees[business.id] or {})[citizenid]
end

lib.callback.register('imperial_businesses:getManagement', function(src, businessKey)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'ledger')
    local employee = snap and BizEmployee(snap.citizenid, businessKey)
    local businessLite = Biz.byKey[businessKey]
    if not businessLite or not employee then return nil end

    local roster = nil
    if okPerm then
        roster = {}
        for citizenid, e in pairs(Biz.employees[business.id] or {}) do
            roster[#roster + 1] = {
                citizenid = citizenid, name = e.name, grade = e.grade, wage = e.wage,
                online = exports.qbx_core:GetPlayerByCitizenId(citizenid) ~= nil,
                onDuty = Biz.onDuty[business.id][citizenid] == true,
            }
        end
    end

    return {
        label = businessLite.label,
        type = businessLite.type,
        myGrade = employee.grade,
        isOwner = businessLite.owner_citizenid == (snap and snap.citizenid),
        balance = okPerm and businessLite.balance or nil,
        leaseWeekly = businessLite.lease_weekly,
        leaseArrears = businessLite.lease_arrears,
        roster = roster,
        grades = ImperialBusinesses.grades,
    }
end)

lib.callback.register('imperial_businesses:hire', function(src, businessKey, targetSource)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'hire')
    if not okPerm then return false end
    if type(targetSource) ~= 'number' then return false end

    local target = exports.qbx_core:GetPlayer(targetSource)
    if not target then return false, 'offline' end

    -- must be physically nearby (consensual hire flow)
    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(targetSource))
    if #(a - b) > 5.0 then return false, 'toofar' end

    local citizenid = target.PlayerData.citizenid
    if employeeRow(business, citizenid) or business.owner_citizenid == citizenid then
        return false, 'already'
    end

    local charinfo = target.PlayerData.charinfo
    local name = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    local wage = GetConvarInt('imperial:econ:business:defaultWage', 150)

    MySQL.insert.await([[
        INSERT INTO imperial_business_employees (business_id, citizenid, name, grade, wage)
        VALUES (?, ?, ?, 0, ?)
    ]], { business.id, citizenid, name, wage })
    Biz.employees[business.id][citizenid] = { grade = 0, wage = wage, name = name }

    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_hire',
        citizenid = snap.citizenid, targetCitizenid = citizenid,
        data = { business = businessKey },
    })
    exports.qbx_core:Notify(targetSource,
        ('You were hired at %s'):format(business.label), 'success')
    return true
end)

lib.callback.register('imperial_businesses:fire', function(src, businessKey, citizenid)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'fire')
    if not okPerm or type(citizenid) ~= 'string' then return false end
    local target = employeeRow(business, citizenid)
    if not target then return false end

    -- managers cannot fire equal/higher grades; owner can fire anyone
    local actor = BizEmployee(snap.citizenid, businessKey)
    if actor.grade < 3 and target.grade >= actor.grade then return false, 'rank' end

    MySQL.query.await('DELETE FROM imperial_business_employees WHERE business_id = ? AND citizenid = ?',
        { business.id, citizenid })
    Biz.employees[business.id][citizenid] = nil
    Biz.onDuty[business.id][citizenid] = nil

    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_fire',
        citizenid = snap.citizenid, targetCitizenid = citizenid, data = { business = businessKey },
    })
    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if online then
        exports.qbx_core:Notify(online.PlayerData.source,
            ('You were let go from %s'):format(business.label), 'error')
    end
    return true
end)

lib.callback.register('imperial_businesses:setGrade', function(src, businessKey, citizenid, grade)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'setgrade')
    if not okPerm or type(citizenid) ~= 'string' then return false end
    if type(grade) ~= 'number' or grade < 0 or grade > 2 then return false end -- 3 = owner only via transfer
    local target = employeeRow(business, citizenid)
    if not target then return false end

    local actor = BizEmployee(snap.citizenid, businessKey)
    if actor.grade < 3 and (target.grade >= actor.grade or grade >= actor.grade) then
        return false, 'rank'
    end

    MySQL.query.await('UPDATE imperial_business_employees SET grade = ? WHERE business_id = ? AND citizenid = ?',
        { grade, business.id, citizenid })
    target.grade = grade
    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_setgrade',
        citizenid = snap.citizenid, targetCitizenid = citizenid,
        data = { business = businessKey, grade = grade },
    })
    return true
end)

lib.callback.register('imperial_businesses:setWage', function(src, businessKey, citizenid, wage)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'setwage')
    if not okPerm or type(citizenid) ~= 'string' then return false end
    local okAmt, n = exports.imperial_logging:ValidateAmount(wage, 0, ImperialBusinesses.maxWage)
    if not okAmt then return false end
    local target = employeeRow(business, citizenid)
    if not target then return false end

    MySQL.query.await('UPDATE imperial_business_employees SET wage = ? WHERE business_id = ? AND citizenid = ?',
        { n, business.id, citizenid })
    target.wage = n
    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_setwage',
        citizenid = snap.citizenid, targetCitizenid = citizenid,
        data = { business = businessKey, wage = n },
    })
    return true
end)

lib.callback.register('imperial_businesses:transferOwnership', function(src, businessKey, citizenid)
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'transfer')
    if not okPerm or type(citizenid) ~= 'string' then return false end
    if business.owner_citizenid ~= snap.citizenid then return false end

    local newOwner = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if not newOwner then return false, 'offline' end

    MySQL.query.await('UPDATE imperial_businesses SET owner_citizenid = ? WHERE id = ?',
        { citizenid, business.id })
    business.owner_citizenid = citizenid
    -- previous owner becomes manager; new owner removed from employee table if present
    MySQL.query.await('DELETE FROM imperial_business_employees WHERE business_id = ? AND citizenid = ?',
        { business.id, citizenid })
    Biz.employees[business.id][citizenid] = nil
    MySQL.insert.await([[
        INSERT INTO imperial_business_employees (business_id, citizenid, name, grade, wage)
        VALUES (?, ?, ?, 2, 0)
        ON DUPLICATE KEY UPDATE grade = 2
    ]], { business.id, snap.citizenid, 'Former Owner', })
    Biz.employees[business.id][snap.citizenid] = { grade = 2, wage = 0, name = 'Former Owner' }

    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_transfer',
        citizenid = snap.citizenid, targetCitizenid = citizenid,
        data = { business = businessKey }, severity = 2,
    })
    return true
end)

-- ── admin: assign ownership (ace-gated command, server console friendly) ─
lib.addCommand('bizowner', {
    help = 'Set business owner (admin)',
    restricted = 'group.admin',
    params = {
        { name = 'businessKey', type = 'string' },
        { name = 'playerId', type = 'playerId' },
    },
}, function(src, args)
    local business = Biz.byKey[args.businessKey]
    local target = exports.qbx_core:GetPlayer(args.playerId)
    if not business or not target then return end
    local citizenid = target.PlayerData.citizenid
    MySQL.query.await('UPDATE imperial_businesses SET owner_citizenid = ? WHERE id = ?',
        { citizenid, business.id })
    business.owner_citizenid = citizenid
    exports.imperial_logging:Log({
        resource = 'imperial_businesses', category = 'admin', action = 'biz_owner_set',
        source = src > 0 and src or nil, targetCitizenid = citizenid,
        data = { business = args.businessKey }, severity = 2,
    })
    exports.qbx_core:Notify(args.playerId, ('You now own %s'):format(business.label), 'success')
end)
