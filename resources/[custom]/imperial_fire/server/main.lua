--- imperial_fire/server/main.lua
--- Server-authoritative incident state machine. Visual fire effects are
--- client-rendered (StartScriptFire is a presentation-only native — there is
--- no server-side "fire entity" to sync), but progress, completion and
--- rewards are decided here and here only.

local incidents = {}     -- [id] = { type, coords, workRemaining, workTotal, priority, createdAt, lastProgressAt, dispatchCallId }
local nextIncidentId = 0
local onDutyFire = {}    -- [src] = true

-- Candidate spawn points for automatic incidents (kept small & curated).
local SPAWN_POOL = {
    { type = 'vehicle_fire', coords = vec3(-1120.9, -1520.2, 4.4) },
    { type = 'structure_fire', coords = vec3(124.9, -1290.9, 29.3) },
    { type = 'hazmat', coords = vec3(972.9, -2115.6, 30.5) },
    { type = 'rescue', coords = vec3(-75.6, -1444.2, 26.4) },
    { type = 'rtc', coords = vec3(-541.8, -191.2, 38.1) },
    { type = 'vehicle_fire', coords = vec3(841.1, -1290.5, 26.2) },
    { type = 'structure_fire', coords = vec3(-321.5, 6300.7, 31.5) },
}

local function refreshDuty()
    onDutyFire = {}
    local players = exports.qbx_core:GetQBPlayers()
    for src, player in pairs(players) do
        local job = player.PlayerData.job
        if job and job.name == ImperialFire.job and job.onduty then
            onDutyFire[tonumber(src)] = true
        end
    end
end
RegisterNetEvent('QBCore:Server:SetDuty', function() SetTimeout(200, refreshDuty) end)
AddEventHandler('playerDropped', function() SetTimeout(200, refreshDuty) end)
CreateThread(function() while true do Wait(30000) refreshDuty() end end)

CreateThread(function()
    for _, station in ipairs(ImperialFire.stations) do
        exports.ox_inventory:RegisterStash('fire_equip_' .. station.id,
            ('%s — Equipment'):format(station.label), 30, 200000, false)
    end
end)

local function broadcastIncident(incident, eventName)
    for src in pairs(onDutyFire) do
        TriggerClientEvent(eventName, src, {
            id = incident.id, type = incident.type, coords = incident.coords,
            workRemaining = incident.workRemaining, workTotal = incident.workTotal,
            priority = incident.priority, label = ImperialFire.incidentTypes[incident.type].label,
        })
    end
end

local function createIncident(incidentType, coords)
    local cfg = ImperialFire.incidentTypes[incidentType]
    if not cfg then return nil end

    nextIncidentId = nextIncidentId + 1
    local id = nextIncidentId
    local now = os.time()
    local incident = {
        id = id, type = incidentType, coords = coords,
        workRemaining = cfg.extinguishWork, workTotal = cfg.extinguishWork,
        priority = cfg.priority, createdAt = now, lastProgressAt = now,
        escalated = false,
    }
    incidents[id] = incident

    local callId = exports.imperial_dispatch:CreateDispatchCall({
        code = cfg.code, title = cfg.label,
        description = 'Fire & rescue response required',
        coords = coords, jobs = { ImperialFire.job }, priority = cfg.priority,
        duration = 300000,
    })
    incident.dispatchCallId = callId

    broadcastIncident(incident, 'imperial_fire:client:incidentStart')
    exports.imperial_logging:Log({
        resource = 'imperial_fire', category = 'gameplay', action = 'incident_created',
        data = { id = id, type = incidentType },
    })
    return id
end

exports('CreateIncident', createIncident)

-- ── automatic spawner: keeps 0-2 incidents live, spaced out ─────────────
CreateThread(function()
    while true do
        Wait(math.random(240000, 480000)) -- every 4-8 minutes
        local live = 0
        for _ in pairs(incidents) do live = live + 1 end
        if live < 2 and next(onDutyFire) ~= nil then
            local pick = SPAWN_POOL[math.random(#SPAWN_POOL)]
            createIncident(pick.type, pick.coords)
        end
    end
end)

-- ── extinguish progress ──────────────────────────────────────────────────
lib.callback.register('imperial_fire:extinguish', function(src, incidentId)
    if not exports.imperial_logging:RateLimit(src, 'fire:extinguish', 1,
        ImperialFire.tickCooldownMs) then
        return false
    end
    local incident = incidents[incidentId]
    if not incident then return false end
    if not onDutyFire[src] then return false, 'notonduty' end
    if not exports.imperial_logging:ValidateDistance(src, incident.coords, 6.0) then
        return false, 'toofar'
    end

    local hasTool = exports.ox_inventory:GetItemCount(src, 'fire_extinguisher_item') > 0
        or exports.ox_inventory:GetItemCount(src, 'fire_hose_nozzle') > 0
    if not hasTool then return false, 'notool' end

    incident.workRemaining = math.max(0, incident.workRemaining - ImperialFire.extinguishPerTick)
    incident.lastProgressAt = os.time()

    if incident.workRemaining <= 0 then
        incidents[incidentId] = nil
        for unitSrc in pairs(onDutyFire) do
            TriggerClientEvent('imperial_fire:client:incidentEnd', unitSrc, incidentId)
        end
        local reward = GetConvarInt(ImperialFire.incidentRewardConvar, 180)
        local player = exports.qbx_core:GetPlayer(src)
        if player then player.Functions.AddMoney('bank', reward, 'imperial-fire-incident') end
        exports.imperial_logging:Log({
            resource = 'imperial_fire', category = 'money', action = 'incident_resolved',
            source = src, amount = reward, data = { id = incidentId, type = incident.type },
        })
        return true, { done = true, reward = reward }
    end

    return true, { done = false, remaining = incident.workRemaining }
end)

-- ── escalation / abandonment sweep ───────────────────────────────────────
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, incident in pairs(incidents) do
            local idle = now - incident.lastProgressAt
            if idle * 1000 > ImperialFire.abandonAfterMs then
                incidents[id] = nil
                for unitSrc in pairs(onDutyFire) do
                    TriggerClientEvent('imperial_fire:client:incidentEnd', unitSrc, id)
                end
                exports.imperial_logging:Log({
                    resource = 'imperial_fire', category = 'gameplay', action = 'incident_abandoned',
                    data = { id = id, type = incident.type },
                })
            elseif not incident.escalated and idle * 1000 > ImperialFire.escalateAfterMs then
                incident.escalated = true
                incident.priority = math.min(5, incident.priority + 1)
                exports.imperial_dispatch:CreateDispatchCall({
                    code = ImperialFire.incidentTypes[incident.type].code,
                    title = ImperialFire.incidentTypes[incident.type].label .. ' (Escalated)',
                    description = 'Incident spreading — additional units required',
                    coords = incident.coords, jobs = { ImperialFire.job },
                    priority = incident.priority, duration = 300000,
                })
            end
        end
    end
end)

-- ── duty ────────────────────────────────────────────────────────────────
lib.callback.register('imperial_fire:toggleDuty', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or player.PlayerData.job.name ~= ImperialFire.job then return nil end
    exports.qbx_core:SetJobDuty(src, not player.PlayerData.job.onduty)
    SetTimeout(200, refreshDuty)
    return not player.PlayerData.job.onduty
end)

-- sync existing incidents to a unit that just came on duty
RegisterNetEvent('QBCore:Server:SetDuty', function()
    local src = source
    SetTimeout(400, function()
        if onDutyFire[src] then
            for _, incident in pairs(incidents) do
                TriggerClientEvent('imperial_fire:client:incidentStart', src, {
                    id = incident.id, type = incident.type, coords = incident.coords,
                    workRemaining = incident.workRemaining, workTotal = incident.workTotal,
                    priority = incident.priority, label = ImperialFire.incidentTypes[incident.type].label,
                })
            end
        end
    end)
end)
