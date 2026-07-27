--- imperial_logging/server/ratelimit.lua
--- Sliding-window rate limiting + per-player action locks.
--- Keyed by player licence identifier so reconnects cannot reset windows cheaply.

local windows = {} -- [identifier..key] = { count, windowStart }
local locks = {}   -- [identifier..key] = expiryMs

local function identifierFor(src)
    if not src or src <= 0 then return 'server' end
    return GetPlayerIdentifierByType(src, 'license') or ('src:%d'):format(src)
end

---Check and consume one unit of a rate limit.
---@param src number player source (or 0 for global/server keys)
---@param key string action key, e.g. 'business:deposit'
---@param maxPerWindow number|nil
---@param windowMs number|nil
---@return boolean allowed
local function rateLimit(src, key, maxPerWindow, windowMs)
    maxPerWindow = maxPerWindow or ImperialLogConfig.defaultMaxPerWindow
    windowMs = windowMs or ImperialLogConfig.defaultWindowMs

    local now = GetGameTimer()
    local id = identifierFor(src) .. '|' .. key
    local w = windows[id]

    if not w or (now - w.windowStart) > windowMs then
        windows[id] = { count = 1, windowStart = now }
        return true
    end

    w.count = w.count + 1
    if w.count > maxPerWindow then
        exports.imperial_logging:LogSuspicious(src, 'ratelimit:' .. key, {
            count = w.count, windowMs = windowMs,
        })
        return false
    end
    return true
end

---Acquire an exclusive per-player action lock (e.g. one robbery at a time).
---@param src number
---@param key string
---@param ttlMs number|nil safety expiry
---@return boolean acquired
local function acquireLock(src, key, ttlMs)
    local now = GetGameTimer()
    local id = identifierFor(src) .. '|' .. key
    local expiry = locks[id]
    if expiry and expiry > now then
        return false
    end
    locks[id] = now + (ttlMs or ImperialLogConfig.defaultLockTtlMs)
    return true
end

---@param src number
---@param key string
local function releaseLock(src, key)
    locks[identifierFor(src) .. '|' .. key] = nil
end

-- Garbage-collect stale windows/locks every 5 minutes.
CreateThread(function()
    while true do
        Wait(300000)
        local now = GetGameTimer()
        for id, w in pairs(windows) do
            if (now - w.windowStart) > 600000 then windows[id] = nil end
        end
        for id, expiry in pairs(locks) do
            if expiry <= now then locks[id] = nil end
        end
    end
end)

exports('RateLimit', rateLimit)
exports('AcquireLock', acquireLock)
exports('ReleaseLock', releaseLock)
