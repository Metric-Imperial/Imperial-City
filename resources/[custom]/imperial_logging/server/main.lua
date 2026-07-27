--- imperial_logging/server/main.lua
--- Structured audit log bus. All imperial resources log through here.
--- DB is authoritative; Discord webhook (if configured) is a best-effort mirror.

local queue = {}
local queueSize = 0
local webhook = GetConvar('imperial:webhook_audit', '')
local debugMode = GetConvar('imperial:debug', 'false') == 'true'

local INSERT_SQL = [[
    INSERT INTO imperial_logs
        (resource, category, severity, citizenid, target_citizenid, action, amount, data)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
]]

---Resolve a player's citizenid from a server source, if online.
---@param src number|nil
---@return string|nil
local function citizenidFromSource(src)
    if not src or src <= 0 then return nil end
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

local function flush()
    if queueSize == 0 then return end
    local batch = queue
    queue, queueSize = {}, 0

    local params = {}
    for i = 1, #batch do
        local e = batch[i]
        params[#params + 1] = {
            e.resource, e.category, e.severity, e.citizenid, e.targetCitizenid,
            e.action, e.amount, e.data and json.encode(e.data) or nil,
        }
    end

    MySQL.prepare(INSERT_SQL, params, function(_)
        if debugMode then
            print(('[imperial_logging] flushed %d log entries'):format(#params))
        end
    end)
end

local function mirrorToWebhook(entry)
    if webhook == '' then return end
    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        embeds = {{
            title = ('[%s] %s'):format(entry.resource, entry.action),
            description = ('severity %d | citizen %s | amount %s'):format(
                entry.severity, entry.citizenid or '-', entry.amount or '-'),
            color = entry.severity >= 4 and 15158332 or 15105570,
        }},
    }), { ['Content-Type'] = 'application/json' })
end

---Queue a structured log entry.
---@param data { resource: string?, category: string?, severity: number?, source: number?, citizenid: string?, targetCitizenid: string?, action: string, amount: number?, data: table? }
local function log(data)
    if type(data) ~= 'table' or type(data.action) ~= 'string' then
        return false
    end

    local entry = {
        resource = data.resource or (GetInvokingResource() or 'unknown'),
        category = data.category or 'gameplay',
        severity = data.severity or ImperialLogConfig.severity.info,
        citizenid = data.citizenid or citizenidFromSource(data.source),
        targetCitizenid = data.targetCitizenid,
        action = data.action,
        amount = data.amount,
        data = data.data,
    }

    if queueSize >= ImperialLogConfig.maxQueue then
        print('[imperial_logging] WARNING: log queue full, dropping oldest entry')
        table.remove(queue, 1)
        queueSize = queueSize - 1
    end

    queue[#queue + 1] = entry
    queueSize = queueSize + 1

    if entry.severity >= ImperialLogConfig.webhookMinSeverity then
        mirrorToWebhook(entry)
    end
    if queueSize >= ImperialLogConfig.flushBatchSize then
        flush()
    end
    return true
end

---Convenience wrapper for suspicious client behaviour.
---@param src number
---@param action string
---@param extra table|nil
local function logSuspicious(src, action, extra)
    local identifiers = {}
    if src and src > 0 then
        for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            identifiers[#identifiers + 1] = id
        end
    end
    return log({
        resource = GetInvokingResource() or 'imperial_logging',
        category = 'security',
        severity = ImperialLogConfig.severity.suspicious,
        source = src,
        action = action,
        data = { identifiers = identifiers, extra = extra },
    })
end

CreateThread(function()
    while true do
        Wait(ImperialLogConfig.flushIntervalMs)
        flush()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then flush() end
end)

exports('Log', log)
exports('LogSuspicious', logSuspicious)
