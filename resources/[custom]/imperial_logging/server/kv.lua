--- imperial_logging/server/kv.lua
--- Restart-safe persistent key/value store (JSON values) with write-through cache.

local cache = {}

---@param key string
---@param value any JSON-serialisable; nil deletes the key
local function kvSet(key, value)
    if type(key) ~= 'string' or #key == 0 or #key > 96 then return false end
    if value == nil then
        cache[key] = nil
        MySQL.query('DELETE FROM imperial_kv WHERE k = ?', { key })
        return true
    end
    cache[key] = value
    MySQL.query(
        'INSERT INTO imperial_kv (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
        { key, json.encode(value) }
    )
    return true
end

---Synchronous (awaited) read; cached after first hit.
---@param key string
---@return any|nil
local function kvGet(key)
    if cache[key] ~= nil then return cache[key] end
    local row = MySQL.scalar.await('SELECT v FROM imperial_kv WHERE k = ?', { key })
    if row == nil then return nil end
    local ok, decoded = pcall(json.decode, row)
    if not ok then return nil end
    cache[key] = decoded
    return decoded
end

exports('KVSet', kvSet)
exports('KVGet', kvGet)
