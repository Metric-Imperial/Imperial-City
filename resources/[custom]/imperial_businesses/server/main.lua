--- imperial_businesses/server/main.lua
--- Core state, config→DB sync, stashes, exported API.

Biz = {
    byKey = {},     -- [business_key] = row (live cache)
    byId = {},      -- [id] = row
    employees = {}, -- [business_id] = { [citizenid] = { grade, wage, name } }
    onDuty = {},    -- [business_id] = { [citizenid] = true }
    siteByKey = {},
}

for _, site in ipairs(ImperialBusinessSites) do
    Biz.siteByKey[site.key] = site
end

local function loadEmployees(businessId)
    local rows = MySQL.query.await(
        'SELECT citizenid, name, grade, wage FROM imperial_business_employees WHERE business_id = ?',
        { businessId })
    local map = {}
    for _, e in ipairs(rows or {}) do
        map[e.citizenid] = { grade = e.grade, wage = e.wage, name = e.name }
    end
    Biz.employees[businessId] = map
end

CreateThread(function()
    -- config → DB sync (insert missing seed businesses)
    for _, site in ipairs(ImperialBusinessSites) do
        MySQL.query.await([[
            INSERT INTO imperial_businesses (business_key, label, type, lease_weekly)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE label = VALUES(label), type = VALUES(type)
        ]], { site.key, site.label, site.type, site.leaseWeekly or 0 })
    end

    local rows = MySQL.query.await('SELECT * FROM imperial_businesses WHERE active = 1', {})
    for _, row in ipairs(rows or {}) do
        Biz.byKey[row.business_key] = row
        Biz.byId[row.id] = row
        Biz.onDuty[row.id] = {}
        loadEmployees(row.id)

        local site = Biz.siteByKey[row.business_key]
        if site then
            local cfg = ImperialBusinesses.storage
            if site.storageShared then
                exports.ox_inventory:RegisterStash(('biz_shared_%s'):format(row.business_key),
                    ('%s — Storage'):format(row.label), cfg.shared.slots, cfg.shared.weight, false)
            end
            if site.storageManagement then
                exports.ox_inventory:RegisterStash(('biz_mgmt_%s'):format(row.business_key),
                    ('%s — Office Safe'):format(row.label), cfg.management.slots, cfg.management.weight, false)
            end
            if site.storageIngredients then
                exports.ox_inventory:RegisterStash(('biz_ingr_%s'):format(row.business_key),
                    ('%s — Ingredients'):format(row.label), cfg.ingredients.slots, cfg.ingredients.weight, false)
            end
        end
    end
    print(('[imperial_businesses] loaded %d businesses'):format(#(rows or {})))
end)

-- ── permission helpers ──────────────────────────────────────────────────
---@param citizenid string
---@param businessKey string
---@return table|nil employee { grade, wage, name }, table|nil business row
function BizEmployee(citizenid, businessKey)
    local business = Biz.byKey[businessKey]
    if not business then return nil, nil end
    if business.owner_citizenid == citizenid then
        return { grade = 3, wage = 0, name = 'Owner' }, business
    end
    local employees = Biz.employees[business.id] or {}
    return employees[citizenid], business
end

---@param src number
---@param businessKey string
---@param permission string
---@return boolean, table|nil business, table|nil snap
function BizHasPermission(src, businessKey, permission)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local employee, business = BizEmployee(snap.citizenid, businessKey)
    if not employee then return false end
    local minGrade = ImperialBusinesses.permissions[permission]
    if minGrade == nil then return false end
    return employee.grade >= minGrade, business, snap
end

-- ── duty ────────────────────────────────────────────────────────────────
lib.callback.register('imperial_businesses:toggleDuty', function(src, businessKey)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil end
    local employee, business = BizEmployee(snap.citizenid, businessKey)
    if not employee then return nil end

    local duty = Biz.onDuty[business.id]
    duty[snap.citizenid] = not duty[snap.citizenid] or nil
    return duty[snap.citizenid] == true
end)

-- ── stash access (server-validated) ─────────────────────────────────────
lib.callback.register('imperial_businesses:openStash', function(src, businessKey, stashType)
    local permMap = { shared = 'storage_shared', mgmt = 'storage_management', ingr = 'stock', personal = 'storage_shared' }
    local perm = permMap[stashType]
    if not perm then return false end
    local ok, business, snap = BizHasPermission(src, businessKey, perm)
    if not ok then return false end

    local site = Biz.siteByKey[businessKey]
    if not site then return false end
    local anchor = stashType == 'mgmt' and site.storageManagement
        or stashType == 'ingr' and site.storageIngredients
        or site.storageShared
    if not anchor or not exports.imperial_logging:ValidateDistance(src, anchor, 4.0) then
        return false
    end

    local stashId
    if stashType == 'personal' then
        stashId = ('biz_pers_%s_%s'):format(businessKey, snap.citizenid)
        local cfg = ImperialBusinesses.storage.personal
        exports.ox_inventory:RegisterStash(stashId,
            ('%s — Locker'):format(business.label), cfg.slots, cfg.weight, true)
    else
        stashId = ('biz_%s_%s'):format(stashType == 'mgmt' and 'mgmt' or stashType == 'ingr' and 'ingr' or 'shared', businessKey)
    end
    return stashId
end)

-- ── exported API ────────────────────────────────────────────────────────
exports('GetBusiness', function(businessKey)
    local b = Biz.byKey[businessKey]
    if not b then return nil end
    return {
        id = b.id, key = b.business_key, label = b.label, type = b.type,
        owner = b.owner_citizenid, balance = b.balance, active = b.active == 1,
    }
end)

exports('IsBusinessEmployee', function(source, businessKey)
    local snap = exports.imperial_logging:PlayerSnapshot(source)
    if not snap then return false end
    local employee = BizEmployee(snap.citizenid, businessKey)
    return employee ~= nil, employee and employee.grade or nil
end)

exports('IsBusinessEmployeeCitizen', function(citizenid, businessKey)
    local employee = BizEmployee(citizenid, businessKey)
    return employee ~= nil, employee and employee.grade or nil
end)

exports('HasBusinessPermission', function(source, businessKey, permission)
    local ok = BizHasPermission(source, businessKey, permission)
    return ok
end)

-- money exports defined in server/money.lua (AddBusinessFunds / RemoveBusinessFunds)

AddEventHandler('playerDropped', function()
    local src = source
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return end
    for _, duty in pairs(Biz.onDuty) do
        duty[snap.citizenid] = nil
    end
end)
