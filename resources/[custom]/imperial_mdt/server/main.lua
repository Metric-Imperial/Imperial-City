--- imperial_mdt/server/main.lua
--- Department-scoped records. Every write is server-validated against the
--- caller's real job/grade (never trusts a client-declared department) and
--- audited to imperial_mdt_audit.

local function departmentFor(snap)
    for dept, cfg in pairs(ImperialMDT.departments) do
        if snap.job == cfg.job then return dept end
    end
    return nil
end

local function hasPerm(snap, permission)
    local min = ImperialMDT.permissions[permission]
    if min == nil then return false end
    return snap.jobGrade >= min
end

local function audit(citizenid, department, action, target)
    MySQL.insert('INSERT INTO imperial_mdt_audit (citizenid, department, action, target) VALUES (?, ?, ?, ?)',
        { citizenid, department, action, target })
end

-- ── access gate used by every callback ───────────────────────────────────
local function authorise(src, permission)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or not snap.onDuty then return nil end
    local dept = departmentFor(snap)
    if not dept then return nil end
    if not hasPerm(snap, permission) then return nil end
    return snap, dept
end

-- ── reports ─────────────────────────────────────────────────────────────
lib.callback.register('imperial_mdt:createReport', function(src, payload)
    local snap, dept = authorise(src, 'createReport')
    if not snap then return false end
    if type(payload) ~= 'table' or type(payload.title) ~= 'string' or type(payload.body) ~= 'string' then
        return false
    end
    if #payload.title > 120 or #payload.body > 8000 then return false end

    local reportId = MySQL.insert.await([[
        INSERT INTO imperial_mdt_reports (department, type, title, body, author_citizenid, subject_citizenid, dispatch_call_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        dept, payload.type or 'incident', payload.title, payload.body,
        snap.citizenid, payload.subjectCitizenid, payload.dispatchCallId,
    })

    if type(payload.charges) == 'table' then
        for _, charge in ipairs(payload.charges) do
            local def = nil
            for _, c in ipairs(ImperialMDT.chargeCodes) do
                if c.code == charge.code then def = c break end
            end
            if def then
                MySQL.insert('INSERT INTO imperial_mdt_charges (report_id, charge_code, label, fine, jail_months) VALUES (?, ?, ?, ?, ?)',
                    { reportId, def.code, def.label, def.fine, def.jail })
            end
        end
    end

    audit(snap.citizenid, dept, 'create_report', tostring(reportId))
    exports.imperial_logging:Log({
        resource = 'imperial_mdt', category = 'admin', action = 'mdt_report_created',
        source = src, data = { reportId = reportId, dept = dept, type = payload.type },
    })
    return true, reportId
end)

lib.callback.register('imperial_mdt:getReports', function(src, filter)
    local snap, dept = authorise(src, 'view')
    if not snap then return nil end

    filter = type(filter) == 'table' and filter or {}
    local where, params = { 'department = ?' }, { dept }
    if type(filter.subjectCitizenid) == 'string' then
        where[#where + 1] = 'subject_citizenid = ?'
        params[#params + 1] = filter.subjectCitizenid
    end
    if type(filter.search) == 'string' and #filter.search > 0 then
        where[#where + 1] = 'title LIKE ?'
        params[#params + 1] = '%' .. filter.search:sub(1, 60) .. '%'
    end

    return MySQL.query.await(([[
        SELECT id, type, title, author_citizenid, subject_citizenid,
               UNIX_TIMESTAMP(created_at) AS created_at
        FROM imperial_mdt_reports WHERE %s
        ORDER BY id DESC LIMIT 100
    ]]):format(table.concat(where, ' AND ')), params)
end)

lib.callback.register('imperial_mdt:getReport', function(src, reportId)
    local snap = authorise(src, 'view')
    if not snap or type(reportId) ~= 'number' then return nil end
    local report = MySQL.single.await('SELECT * FROM imperial_mdt_reports WHERE id = ?', { reportId })
    if not report then return nil end
    report.charges = MySQL.query.await('SELECT * FROM imperial_mdt_charges WHERE report_id = ?', { reportId })
    return report
end)

-- ── warrants ────────────────────────────────────────────────────────────
lib.callback.register('imperial_mdt:createWarrant', function(src, subjectCitizenid, reason)
    local snap, dept = authorise(src, 'createWarrant')
    if not snap or dept ~= 'police' then return false end
    if type(subjectCitizenid) ~= 'string' or type(reason) ~= 'string' or #reason > 255 then return false end

    MySQL.insert('INSERT INTO imperial_mdt_warrants (subject_citizenid, reason, issued_by) VALUES (?, ?, ?)',
        { subjectCitizenid, reason, snap.citizenid })
    audit(snap.citizenid, dept, 'create_warrant', subjectCitizenid)
    return true
end)

lib.callback.register('imperial_mdt:getWarrants', function(src)
    local snap, dept = authorise(src, 'view')
    if not snap or dept ~= 'police' then return nil end
    return MySQL.query.await(
        'SELECT * FROM imperial_mdt_warrants WHERE active = 1 ORDER BY id DESC LIMIT 100', {})
end)

lib.callback.register('imperial_mdt:clearWarrant', function(src, warrantId)
    local snap, dept = authorise(src, 'createWarrant')
    if not snap or dept ~= 'police' or type(warrantId) ~= 'number' then return false end
    MySQL.update('UPDATE imperial_mdt_warrants SET active = 0 WHERE id = ?', { warrantId })
    audit(snap.citizenid, dept, 'clear_warrant', tostring(warrantId))
    return true
end)

-- ── BOLOs ───────────────────────────────────────────────────────────────
lib.callback.register('imperial_mdt:createBolo', function(src, title, description, plate)
    local snap, dept = authorise(src, 'createBolo')
    if not snap or dept ~= 'police' then return false end
    if type(title) ~= 'string' or type(description) ~= 'string' then return false end
    if #title > 120 or #description > 255 then return false end

    MySQL.insert('INSERT INTO imperial_mdt_bolos (title, description, plate, author_citizenid) VALUES (?, ?, ?, ?)',
        { title, description, type(plate) == 'string' and plate:sub(1, 12) or nil, snap.citizenid })
    audit(snap.citizenid, dept, 'create_bolo', title)
    return true
end)

lib.callback.register('imperial_mdt:getBolos', function(src)
    local snap, dept = authorise(src, 'view')
    if not snap or dept ~= 'police' then return nil end
    return MySQL.query.await(
        'SELECT * FROM imperial_mdt_bolos WHERE active = 1 ORDER BY id DESC LIMIT 100', {})
end)

-- ── person lookup (name/plate search bridges to qbx_core / qbx_vehicles) ──
lib.callback.register('imperial_mdt:lookupPerson', function(src, citizenid)
    local snap = authorise(src, 'view')
    if not snap or type(citizenid) ~= 'string' then return nil end

    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    local charinfo, name
    if player then
        charinfo = player.PlayerData.charinfo
    else
        local row = MySQL.single.await(
            'SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if row and row.charinfo then
            local ok, decoded = pcall(json.decode, row.charinfo)
            if ok then charinfo = decoded end
        end
    end
    if not charinfo then return nil end
    name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?')

    local reports = MySQL.query.await([[
        SELECT id, type, title, UNIX_TIMESTAMP(created_at) AS created_at
        FROM imperial_mdt_reports WHERE subject_citizenid = ? ORDER BY id DESC LIMIT 50
    ]], { citizenid })
    local warrants = MySQL.query.await(
        'SELECT * FROM imperial_mdt_warrants WHERE subject_citizenid = ? AND active = 1', { citizenid })

    return { name = name, citizenid = citizenid, reports = reports, warrants = warrants }
end)

-- ── dispatch call linking ────────────────────────────────────────────────
lib.callback.register('imperial_mdt:getRecentCalls', function(src)
    local snap, dept = authorise(src, 'view')
    if not snap then return nil end
    local job = ImperialMDT.departments[dept].job
    return exports.imperial_dispatch:GetRecentCalls(job, 25)
end)
