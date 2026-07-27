--- imperial_turfs/server/main.lua
--- Server-authoritative territory state. Presence is measured by scanning
--- online players' positions each tick (small player counts make this cheap;
--- see docs/30 performance notes) rather than trusting client presence claims.

local turfRows = {}
for _, zone in ipairs(ImperialTurfs.zones) do
    turfRows[zone.key] = nil -- populated on load
end

local function loadTurfs()
    for _, zone in ipairs(ImperialTurfs.zones) do
        local row = MySQL.single.await('SELECT * FROM imperial_turfs WHERE turf_key = ?', { zone.key })
        if not row then
            MySQL.insert.await('INSERT INTO imperial_turfs (turf_key, label) VALUES (?, ?)',
                { zone.key, zone.label })
            row = MySQL.single.await('SELECT * FROM imperial_turfs WHERE turf_key = ?', { zone.key })
        end
        turfRows[zone.key] = row
    end
end
CreateThread(loadTurfs)

local function zoneFor(turfKey)
    for _, zone in ipairs(ImperialTurfs.zones) do
        if zone.key == turfKey then return zone end
    end
    return nil
end

---Count members of `gangKey` physically inside `zone`, capped at maxCountedParticipants.
local function presenceCount(zone, gangKey)
    local count = 0
    local players = exports.qbx_core:GetQBPlayers()
    for src, player in pairs(players) do
        local citizenid = player.PlayerData.citizenid
        local playerGang = exports.imperial_gangs:GetPlayerGang(citizenid)
        if playerGang and playerGang.key == gangKey then
            local ped = GetPlayerPed(tonumber(src))
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                if #(coords - zone.coords) <= zone.radius then
                    count = count + 1
                    if count >= ImperialTurfs.maxCountedParticipants then break end
                end
            end
        end
    end
    return count
end

-- ── start contest ─────────────────────────────────────────────────────────
lib.callback.register('imperial_turfs:startContest', function(src, turfKey)
    if not exports.imperial_logging:RateLimit(src, 'turf:contest', 2, 30000) then return false end
    local zone = zoneFor(turfKey)
    if not zone then return false end
    local row = turfRows[turfKey]
    if not row then return false end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end
    local gang = exports.imperial_gangs:GetPlayerGang(snap.citizenid)
    if not gang then return false, 'nogang' end
    if row.owner_gang_key == gang.key then return false, 'ownturf' end
    if row.contested_by_gang_key then return false, 'alreadycontested' end

    local now = os.time()
    if row.last_capture_at and (now - row.last_capture_at) < ImperialTurfs.cooldownAfterCaptureSec then
        return false, 'cooldown'
    end

    if not exports.imperial_logging:ValidateDistance(src, zone.coords, zone.radius) then
        return false, 'notinzone'
    end
    if presenceCount(zone, gang.key) < ImperialTurfs.minPresence then
        return false, 'notenoughpresence'
    end

    row.contested_by_gang_key = gang.key
    row.contest_started_at = now
    row.progress = 0
    MySQL.query('UPDATE imperial_turfs SET contested_by_gang_key = ?, contest_started_at = ?, progress = 0 WHERE id = ?',
        { gang.key, now, row.id })
    MySQL.insert('INSERT INTO imperial_turf_log (turf_key, gang_key, action) VALUES (?, ?, ?)',
        { turfKey, gang.key, 'contest_start' })

    if ImperialTurfs.notifyPoliceOnContest then
        exports.imperial_dispatch:CreateDispatchCall({
            code = '10-90', title = 'Gang Activity Reported',
            description = ('Unusual gang activity near %s'):format(zone.label),
            coords = zone.coords, jobs = { 'police' }, priority = 2, duration = 120000,
        })
    end

    -- notify defenders
    if row.owner_gang_key then
        local players = exports.qbx_core:GetQBPlayers()
        for playerSrc, player in pairs(players) do
            local pg = exports.imperial_gangs:GetPlayerGang(player.PlayerData.citizenid)
            if pg and pg.key == row.owner_gang_key then
                exports.qbx_core:Notify(tonumber(playerSrc),
                    ('%s is being contested!'):format(zone.label), 'error')
            end
        end
    end

    exports.imperial_logging:Log({
        resource = 'imperial_turfs', category = 'gameplay', action = 'contest_started',
        source = src, data = { turf = turfKey, gang = gang.key },
    })
    return true, { declareDelaySec = ImperialTurfs.declareDelaySec }
end)

-- ── query ───────────────────────────────────────────────────────────────
lib.callback.register('imperial_turfs:getState', function(_)
    local out = {}
    for key, row in pairs(turfRows) do
        out[key] = {
            owner = row.owner_gang_key, progress = row.progress,
            contestedBy = row.contested_by_gang_key,
        }
    end
    return out
end)

exports('GetTurfOwner', function(turfKey)
    local row = turfRows[turfKey]
    return row and row.owner_gang_key or nil
end)

exports('GetGangTurfs', function(gangKey)
    local owned = {}
    for key, row in pairs(turfRows) do
        if row.owner_gang_key == gangKey then owned[#owned + 1] = key end
    end
    return owned
end)

-- ── tick: presence-driven progress ───────────────────────────────────────
CreateThread(function()
    while true do
        Wait(ImperialTurfs.tickIntervalSec * 1000)
        local now = os.time()
        for key, row in pairs(turfRows) do
            if row.contested_by_gang_key then
                local zone = zoneFor(key)

                -- contest timeout
                if row.contest_started_at and (now - row.contest_started_at) > ImperialTurfs.contestTimeoutSec then
                    MySQL.query('UPDATE imperial_turfs SET contested_by_gang_key = NULL, contest_started_at = NULL, progress = 0 WHERE id = ?', { row.id })
                    MySQL.insert('INSERT INTO imperial_turf_log (turf_key, gang_key, action) VALUES (?, ?, ?)',
                        { key, row.contested_by_gang_key, 'contest_cancel' })
                    row.contested_by_gang_key = nil
                    row.contest_started_at = nil
                    row.progress = 0
                elseif row.contest_started_at and (now - row.contest_started_at) >= ImperialTurfs.declareDelaySec then
                    -- capture window active
                    local attackerCount = presenceCount(zone, row.contested_by_gang_key)
                    local defenderCount = row.owner_gang_key and presenceCount(zone, row.owner_gang_key) or 0

                    if attackerCount >= ImperialTurfs.minPresence then
                        row.progress = math.min(ImperialTurfs.captureThreshold,
                            row.progress + ImperialTurfs.progressPerTickAttack)
                    elseif defenderCount >= ImperialTurfs.minPresence then
                        row.progress = math.max(0, row.progress - ImperialTurfs.progressPerTickDefense)
                    end
                    -- otherwise: no presence from either side this tick, progress holds

                    if row.progress >= ImperialTurfs.captureThreshold then
                        local newOwner = row.contested_by_gang_key
                        row.owner_gang_key = newOwner
                        row.contested_by_gang_key = nil
                        row.contest_started_at = nil
                        row.progress = 0
                        row.last_capture_at = now
                        MySQL.query([[
                            UPDATE imperial_turfs SET owner_gang_key = ?, contested_by_gang_key = NULL,
                                contest_started_at = NULL, progress = 0, last_capture_at = ? WHERE id = ?
                        ]], { newOwner, now, row.id })
                        MySQL.insert('INSERT INTO imperial_turf_log (turf_key, gang_key, action) VALUES (?, ?, ?)',
                            { key, newOwner, 'captured' })
                        exports.imperial_gangs:AddGangReputation(newOwner, ImperialTurfs.reputationOnCapture)
                        exports.imperial_logging:Log({
                            resource = 'imperial_turfs', category = 'gameplay', action = 'turf_captured',
                            data = { turf = key, gang = newOwner }, severity = 2,
                        })
                    elseif row.progress <= 0 and defenderCount >= ImperialTurfs.minPresence then
                        MySQL.query('UPDATE imperial_turfs SET contested_by_gang_key = NULL, contest_started_at = NULL, progress = 0 WHERE id = ?', { row.id })
                        MySQL.insert('INSERT INTO imperial_turf_log (turf_key, gang_key, action) VALUES (?, ?, ?)',
                            { key, row.contested_by_gang_key, 'contest_cancel' })
                        row.contested_by_gang_key = nil
                        row.contest_started_at = nil
                    else
                        MySQL.query('UPDATE imperial_turfs SET progress = ? WHERE id = ?', { row.progress, row.id })
                    end
                end
            end
        end
    end
end)

-- ── income cycle ────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(ImperialTurfs.incomeIntervalMin * 60000)
        local incomeAmount = GetConvarInt(ImperialTurfs.incomeConvar, ImperialTurfs.incomeDefault)
        for key, row in pairs(turfRows) do
            if row.owner_gang_key then
                exports.imperial_gangs:AddGangFunds(row.owner_gang_key, incomeAmount,
                    'turf-income:' .. key, nil)
            end
        end
    end
end)

-- ── admin override ─────────────────────────────────────────────────────
lib.addCommand('turfset', {
    help = 'Force-set turf owner (admin)',
    restricted = 'group.admin',
    params = {
        { name = 'turfKey', type = 'string' },
        { name = 'gangKey', type = 'string' },
    },
}, function(src, args)
    local row = turfRows[args.turfKey]
    if not row then return end
    local owner = args.gangKey ~= 'none' and args.gangKey or nil
    MySQL.query('UPDATE imperial_turfs SET owner_gang_key = ?, contested_by_gang_key = NULL, progress = 0 WHERE id = ?',
        { owner, row.id })
    row.owner_gang_key = owner
    row.contested_by_gang_key = nil
    row.progress = 0
    exports.imperial_logging:Log({
        resource = 'imperial_turfs', category = 'admin', action = 'turf_admin_set',
        source = src > 0 and src or nil, severity = 2, data = { turf = args.turfKey, owner = owner },
    })
end)
