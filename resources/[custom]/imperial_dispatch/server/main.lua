--- imperial_dispatch/server/main.lua
--- Documented dispatch API: exports.imperial_dispatch:CreateDispatchCall(data).
--- Any resource (qbx robbery scripts, imperial_farming theft, imperial_fire,
--- panic buttons) can raise an alert without needing to know who is on duty.

local nextCallId = 0
local onDutyByJob = {} -- [job] = { [src] = true }
for job in pairs(ImperialDispatch.jobs) do onDutyByJob[job] = {} end

local function refreshDuty()
    onDutyByJob = {}
    for job in pairs(ImperialDispatch.jobs) do onDutyByJob[job] = {} end
    local players = exports.qbx_core:GetQBPlayers()
    for src, player in pairs(players) do
        local job = player.PlayerData.job
        if job and job.onduty and onDutyByJob[job.name] then
            onDutyByJob[job.name][tonumber(src)] = true
        end
    end
end

-- keep duty map fresh on the events qbx_core fires; also poll as a safety net
RegisterNetEvent('QBCore:Server:SetDuty', function() SetTimeout(200, refreshDuty) end)
AddEventHandler('QBCore:Server:OnPlayerLoaded', function() SetTimeout(500, refreshDuty) end)
AddEventHandler('playerDropped', function() SetTimeout(200, refreshDuty) end)
CreateThread(function()
    while true do Wait(30000) refreshDuty() end
end)

---Create a dispatch call. See README for the full field reference.
---@param data table { code?, title, description?, coords, jobs, priority?, blip?, duration?, metadata? }
---@return integer|nil callId
local function createDispatchCall(data)
    local callerResource = GetInvokingResource() or 'unknown'
    if not exports.imperial_logging:RateLimit(0, 'dispatch:create:' .. callerResource,
        ImperialDispatch.rateLimit.max, ImperialDispatch.rateLimit.windowMs) then
        return nil
    end

    if type(data) ~= 'table' or type(data.title) ~= 'string' or type(data.jobs) ~= 'table' then
        return nil
    end
    local coords = data.coords
    if not coords or not coords.x then return nil end

    local jobs = {}
    for _, j in ipairs(data.jobs) do
        if ImperialDispatch.jobs[j] then jobs[#jobs + 1] = j end
    end
    if #jobs == 0 then return nil end

    local priority = (type(data.priority) == 'number' and data.priority >= 1 and data.priority <= 5)
        and math.floor(data.priority) or 3

    nextCallId = nextCallId + 1
    local callId = nextCallId

    MySQL.insert('INSERT INTO imperial_dispatch_calls (code, title, description, x, y, z, jobs, priority, source_resource, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            data.code, data.title, data.description, coords.x, coords.y, coords.z,
            table.concat(jobs, ','), priority, callerResource,
            data.metadata and json.encode(data.metadata) or nil,
        })

    local payload = {
        id = callId,
        code = data.code,
        title = data.title,
        description = data.description,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        jobs = jobs,
        priority = priority,
        blip = data.blip,
        duration = data.duration or ImperialDispatch.defaultDurationMs,
    }

    for _, job in ipairs(jobs) do
        for src in pairs(onDutyByJob[job] or {}) do
            TriggerClientEvent('imperial_dispatch:client:alert', src, payload)
        end
    end

    exports.imperial_logging:Log({
        resource = 'imperial_dispatch', category = 'gameplay', action = 'call_created',
        data = { id = callId, title = data.title, jobs = jobs, priority = priority, from = callerResource },
    })
    return callId
end

exports('CreateDispatchCall', createDispatchCall)

---Fetch recent calls for MDT linking (department-scoped).
exports('GetRecentCalls', function(job, limit)
    limit = (type(limit) == 'number' and limit > 0 and limit <= 200) and math.floor(limit) or 50
    return MySQL.query.await([[
        SELECT id, code, title, description, x, y, z, jobs, priority,
               UNIX_TIMESTAMP(created_at) AS created_at
        FROM imperial_dispatch_calls
        WHERE FIND_IN_SET(?, jobs) ORDER BY id DESC LIMIT ?
    ]], { job, limit })
end)

-- ── player-triggered panic button (validated: uses the player's own coords) ──
RegisterNetEvent('imperial_dispatch:server:panic', function(job)
    local src = source
    if not ImperialDispatch.jobs[job] then return end
    if not exports.imperial_logging:RateLimit(src, 'dispatch:panic', 3, 60000) then return end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or snap.job ~= job or not snap.onDuty then
        exports.imperial_logging:LogSuspicious(src, 'panic_denied', { claimedJob = job })
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local charinfo = exports.qbx_core:GetPlayer(src).PlayerData.charinfo

    createDispatchCall({
        code = '10-99',
        title = 'OFFICER DOWN / PANIC',
        description = ('%s %s needs immediate assistance'):format(charinfo.firstname, charinfo.lastname),
        coords = coords, jobs = { job }, priority = 5, duration = 180000,
        metadata = { panicSource = src },
    })
end)
