--- imperial_gangs/server/main.lua
--- Dynamic gangs live entirely in imperial_gangs' own tables. qbx_core's
--- static gang config and PlayerData.gang are intentionally left untouched —
--- gang-aware resources should call the exports below (GetMemberRank,
--- IsGangMember, HasGangPermission) rather than checking PlayerData.gang.
--- This keeps dynamic gang creation possible without editing framework
--- config files, per the master decision rules (adapters over core edits).

Gangs = {
    byKey = {},      -- [gang_key] = row
    byId = {},       -- [id] = row
    memberOf = {},   -- [citizenid] = gang_id (single-gang-per-player cache)
    members = {},    -- [gang_id] = { [citizenid] = { rank, name } }
}

local foundingSessions = {} -- [founderSrc] = { label, key, joined = { [citizenid] = { src, name } }, expiresAt }

local function loadGangs()
    local rows = MySQL.query.await('SELECT * FROM imperial_gangs WHERE active = 1', {})
    for _, row in ipairs(rows or {}) do
        Gangs.byKey[row.gang_key] = row
        Gangs.byId[row.id] = row
        Gangs.members[row.id] = {}
    end
    local memberRows = MySQL.query.await('SELECT * FROM imperial_gang_members', {})
    for _, m in ipairs(memberRows or {}) do
        if Gangs.members[m.gang_id] then
            Gangs.members[m.gang_id][m.citizenid] = { rank = m.rank, name = m.name }
            Gangs.memberOf[m.citizenid] = m.gang_id
        end
    end
end
CreateThread(loadGangs)

local function slugify(label)
    local slug = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    return slug:sub(1, 40)
end

local function validLabel(label)
    if type(label) ~= 'string' then return false end
    local trimmed = label:match('^%s*(.-)%s*$')
    if #trimmed < ImperialGangs.minLabelLen or #trimmed > ImperialGangs.maxLabelLen then return false end
    local lower = trimmed:lower()
    for _, word in ipairs(ImperialGangs.reservedWords) do
        if lower == word then return false end
    end
    return true, trimmed
end

-- ── founding session (multi-player creation) ─────────────────────────────
lib.callback.register('imperial_gangs:startFounding', function(src, label)
    if not exports.imperial_logging:RateLimit(src, 'gang:found', 2, 60000) then return false end
    local ok, clean = validLabel(label)
    if not ok then return false, 'badname' end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    if Gangs.memberOf[snap.citizenid] then return false, 'alreadyingang' end

    local key = slugify(clean)
    if Gangs.byKey[key] then return false, 'taken' end

    local player = exports.qbx_core:GetPlayer(src)
    local name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)

    foundingSessions[src] = {
        label = clean, key = key,
        joined = { [snap.citizenid] = { src = src, name = name } },
        expiresAt = os.time() + ImperialGangs.foundingWindowSec,
    }
    return true, { key = key, expiresAt = foundingSessions[src].expiresAt }
end)

lib.callback.register('imperial_gangs:joinFounding', function(src, founderSrc)
    local session = foundingSessions[founderSrc]
    if not session or os.time() > session.expiresAt then return false, 'expired' end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    if Gangs.memberOf[snap.citizenid] then return false, 'alreadyingang' end

    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(founderSrc))
    if #(a - b) > ImperialGangs.foundingRadius then return false, 'toofar' end

    local player = exports.qbx_core:GetPlayer(src)
    local name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
    session.joined[snap.citizenid] = { src = src, name = name }
    return true, { count = (function() local n = 0 for _ in pairs(session.joined) do n = n + 1 end return n end)() }
end)

lib.callback.register('imperial_gangs:finaliseFounding', function(src)
    local session = foundingSessions[src]
    if not session then return false end
    if os.time() > session.expiresAt then foundingSessions[src] = nil return false, 'expired' end

    local count = 0
    for _ in pairs(session.joined) do count = count + 1 end
    if count < ImperialGangs.minFoundingMembers then return false, 'notenough' end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end

    local fee = GetConvarInt(ImperialGangs.creationFeeConvar, 50000)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.Functions.RemoveMoney('bank', fee, 'imperial-gang-creation') then
        return false, 'insufficient'
    end

    local gangId = MySQL.insert.await(
        'INSERT INTO imperial_gangs (gang_key, label, leader_citizenid) VALUES (?, ?, ?)',
        { session.key, session.label, snap.citizenid })

    Gangs.byKey[session.key] = { id = gangId, gang_key = session.key, label = session.label,
        leader_citizenid = snap.citizenid, balance = 0, reputation = 0, active = 1 }
    Gangs.byId[gangId] = Gangs.byKey[session.key]
    Gangs.members[gangId] = {}

    for citizenid, info in pairs(session.joined) do
        local rank = citizenid == snap.citizenid and 3 or 0
        MySQL.insert('INSERT INTO imperial_gang_members (gang_id, citizenid, name, rank) VALUES (?, ?, ?, ?)',
            { gangId, citizenid, info.name, rank })
        Gangs.members[gangId][citizenid] = { rank = rank, name = info.name }
        Gangs.memberOf[citizenid] = gangId
        if info.src then
            exports.qbx_core:Notify(info.src, ('%s has been founded!'):format(session.label), 'success')
        end
    end

    exports.ox_inventory:RegisterStash('gang_' .. session.key,
        ('%s — Storage'):format(session.label), ImperialGangs.storage.slots, ImperialGangs.storage.weight, false)

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_founded',
        source = src, data = { key = session.key, founders = count },
    })
    foundingSessions[src] = nil
    return true, { key = session.key }
end)

-- ── membership queries (compatibility exports) ───────────────────────────
exports('GetMemberRank', function(citizenid)
    local gangId = Gangs.memberOf[citizenid]
    if not gangId then return nil end
    local member = Gangs.members[gangId] and Gangs.members[gangId][citizenid]
    return member and member.rank or nil
end)

exports('IsGangMember', function(citizenid, gangKey)
    local gangId = Gangs.memberOf[citizenid]
    if not gangId then return false end
    if gangKey then
        local gang = Gangs.byId[gangId]
        return gang and gang.gang_key == gangKey
    end
    return true
end)

exports('HasGangPermission', function(citizenid, permission)
    local gangId = Gangs.memberOf[citizenid]
    if not gangId then return false end
    local member = Gangs.members[gangId][citizenid]
    local min = ImperialGangs.permissions[permission]
    if not member or min == nil then return false end
    return member.rank >= min
end)

exports('GetGang', function(gangKey)
    local gang = Gangs.byKey[gangKey]
    if not gang then return nil end
    return { id = gang.id, key = gang.gang_key, label = gang.label,
        leader = gang.leader_citizenid, balance = gang.balance, reputation = gang.reputation }
end)

exports('AddGangReputation', function(gangKey, amount)
    local gang = Gangs.byKey[gangKey]
    if not gang then return false end
    local ok, n = exports.imperial_logging:ValidateAmount(amount, 0, 100000)
    if not ok then return false end
    MySQL.query('UPDATE imperial_gangs SET reputation = reputation + ? WHERE id = ?', { n, gang.id })
    gang.reputation = gang.reputation + n
    return true
end)

exports('GetPlayerGang', function(citizenid)
    local gangId = Gangs.memberOf[citizenid]
    if not gangId then return nil end
    local gang = Gangs.byId[gangId]
    return gang and { id = gang.id, key = gang.gang_key, label = gang.label } or nil
end)

-- ── management ─────────────────────────────────────────────────────────
local function myGangAndRank(citizenid)
    local gangId = Gangs.memberOf[citizenid]
    if not gangId then return nil end
    return Gangs.byId[gangId], Gangs.members[gangId][citizenid]
end

lib.callback.register('imperial_gangs:getManagement', function(src)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang then return nil end

    local roster = {}
    for citizenid, m in pairs(Gangs.members[gang.id]) do
        roster[#roster + 1] = { citizenid = citizenid, name = m.name, rank = m.rank }
    end
    return {
        label = gang.label, key = gang.gang_key, myRank = member.rank,
        balance = member.rank >= ImperialGangs.permissions.withdraw and gang.balance or nil,
        reputation = gang.reputation, roster = roster, ranks = ImperialGangs.ranks,
    }
end)

lib.callback.register('imperial_gangs:invite', function(src, targetSource)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or member.rank < ImperialGangs.permissions.invite then return false end
    if type(targetSource) ~= 'number' then return false end

    local target = exports.qbx_core:GetPlayer(targetSource)
    if not target then return false, 'offline' end
    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(targetSource))
    if #(a - b) > 5.0 then return false, 'toofar' end

    local tcid = target.PlayerData.citizenid
    if Gangs.memberOf[tcid] then return false, 'alreadyingang' end

    local name = ('%s %s'):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname)
    MySQL.insert('INSERT INTO imperial_gang_members (gang_id, citizenid, name, rank) VALUES (?, ?, ?, 0)',
        { gang.id, tcid, name })
    Gangs.members[gang.id][tcid] = { rank = 0, name = name }
    Gangs.memberOf[tcid] = gang.id

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_invite',
        citizenid = snap.citizenid, targetCitizenid = tcid, data = { gang = gang.gang_key },
    })
    exports.qbx_core:Notify(targetSource, ('You joined %s'):format(gang.label), 'success')
    return true
end)

lib.callback.register('imperial_gangs:kick', function(src, citizenid)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or type(citizenid) ~= 'string' then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or member.rank < ImperialGangs.permissions.kick then return false end
    local target = Gangs.members[gang.id][citizenid]
    if not target then return false end
    if member.rank < 3 and target.rank >= member.rank then return false, 'rank' end
    if citizenid == gang.leader_citizenid then return false, 'leader' end

    MySQL.query('DELETE FROM imperial_gang_members WHERE gang_id = ? AND citizenid = ?', { gang.id, citizenid })
    Gangs.members[gang.id][citizenid] = nil
    Gangs.memberOf[citizenid] = nil

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_kick',
        citizenid = snap.citizenid, targetCitizenid = citizenid, data = { gang = gang.gang_key },
    })
    return true
end)

lib.callback.register('imperial_gangs:setRank', function(src, citizenid, rank)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or type(citizenid) ~= 'string' then return false end
    if type(rank) ~= 'number' or rank < 0 or rank > 2 then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or member.rank < ImperialGangs.permissions.setrank then return false end
    local target = Gangs.members[gang.id][citizenid]
    if not target or citizenid == gang.leader_citizenid then return false end
    if member.rank < 3 and (target.rank >= member.rank or rank >= member.rank) then return false, 'rank' end

    MySQL.query('UPDATE imperial_gang_members SET rank = ? WHERE gang_id = ? AND citizenid = ?',
        { rank, gang.id, citizenid })
    target.rank = rank
    return true
end)

lib.callback.register('imperial_gangs:transferLeadership', function(src, citizenid)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or type(citizenid) ~= 'string' then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or gang.leader_citizenid ~= snap.citizenid then return false end
    local target = Gangs.members[gang.id][citizenid]
    if not target then return false end

    MySQL.query('UPDATE imperial_gangs SET leader_citizenid = ? WHERE id = ?', { citizenid, gang.id })
    MySQL.query('UPDATE imperial_gang_members SET rank = 3 WHERE gang_id = ? AND citizenid = ?', { gang.id, citizenid })
    MySQL.query('UPDATE imperial_gang_members SET rank = 2 WHERE gang_id = ? AND citizenid = ?', { gang.id, snap.citizenid })
    gang.leader_citizenid = citizenid
    Gangs.members[gang.id][citizenid].rank = 3
    Gangs.members[gang.id][snap.citizenid].rank = 2

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_leadership_transfer',
        citizenid = snap.citizenid, targetCitizenid = citizenid, severity = 2, data = { gang = gang.gang_key },
    })
    return true
end)

lib.callback.register('imperial_gangs:disband', function(src)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or member.rank < ImperialGangs.permissions.disband then return false end

    for citizenid in pairs(Gangs.members[gang.id]) do
        Gangs.memberOf[citizenid] = nil
    end
    MySQL.query('UPDATE imperial_gangs SET active = 0 WHERE id = ?', { gang.id })
    Gangs.byKey[gang.gang_key] = nil
    Gangs.byId[gang.id] = nil
    Gangs.members[gang.id] = nil

    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_disbanded',
        citizenid = snap.citizenid, severity = 2, data = { gang = gang.gang_key },
    })
    return true
end)

-- ── stash access ────────────────────────────────────────────────────────
lib.callback.register('imperial_gangs:openStash', function(src)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gang, member = myGangAndRank(snap.citizenid)
    if not gang or member.rank < ImperialGangs.permissions.storage then return false end
    return 'gang_' .. gang.gang_key
end)

-- ── admin controls ──────────────────────────────────────────────────────
lib.addCommand('gangdisband', {
    help = 'Force-disband a gang (admin)',
    restricted = 'group.admin',
    params = { { name = 'gangKey', type = 'string' } },
}, function(src, args)
    local gang = Gangs.byKey[args.gangKey]
    if not gang then return end
    for citizenid in pairs(Gangs.members[gang.id]) do
        Gangs.memberOf[citizenid] = nil
    end
    MySQL.query('UPDATE imperial_gangs SET active = 0 WHERE id = ?', { gang.id })
    Gangs.byKey[gang.gang_key] = nil
    Gangs.byId[gang.id] = nil
    Gangs.members[gang.id] = nil
    exports.imperial_logging:Log({
        resource = 'imperial_gangs', category = 'admin', action = 'gang_admin_disbanded',
        source = src > 0 and src or nil, severity = 3, data = { gang = args.gangKey },
    })
end)

-- founding session cleanup
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for founderSrc, session in pairs(foundingSessions) do
            if now > session.expiresAt + 60 then foundingSessions[founderSrc] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    foundingSessions[source] = nil
end)
