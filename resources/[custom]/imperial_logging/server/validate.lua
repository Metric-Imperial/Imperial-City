--- imperial_logging/server/validate.lua
--- Server-side validation helpers shared by all imperial resources.

---Validate that a player is within maxDist of coords (anti spoof/teleport-exploit).
---@param src number
---@param coords vector3|table
---@param maxDist number
---@return boolean
local function validateDistance(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pcoords = GetEntityCoords(ped)
    local target = type(coords) == 'vector3' and coords
        or vec3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3])
    local ok = #(pcoords - target) <= maxDist
    if not ok then
        exports.imperial_logging:LogSuspicious(src, 'distance_check_failed', {
            expected = { x = target.x, y = target.y, z = target.z },
            actual = { x = pcoords.x, y = pcoords.y, z = pcoords.z },
            maxDist = maxDist,
        })
    end
    return ok
end

---Validate a positive integer money/count amount within an inclusive band.
---@param amount any
---@param min number|nil default 1
---@param max number|nil default 2^43 (safe far below BIGINT / double precision)
---@return boolean, integer
local function validateAmount(amount, min, max)
    if type(amount) ~= 'number' or amount ~= amount --[[NaN]] or amount == math.huge then
        return false, 0
    end
    local n = math.floor(amount)
    if n ~= amount then return false, 0 end -- reject fractional client input
    min = min or 1
    max = max or 8796093022208
    if n < min or n > max then return false, 0 end
    return true, n
end

---Validate that a networked entity exists, matches an expected model, and is
---within maxDist of the player.
---@param src number
---@param netId number
---@param expectedModels table<number|string, boolean>|nil set of allowed model hashes/names
---@param maxDist number|nil
---@return boolean, number entity handle (0 when invalid)
local function validateNetEntity(src, netId, expectedModels, maxDist)
    if type(netId) ~= 'number' then return false, 0 end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 0
    end
    if expectedModels then
        local model = GetEntityModel(entity)
        local allowed = false
        for m in pairs(expectedModels) do
            local hash = type(m) == 'string' and joaat(m) or m
            if hash == model then allowed = true break end
        end
        if not allowed then
            exports.imperial_logging:LogSuspicious(src, 'entity_model_mismatch', { netId = netId, model = model })
            return false, 0
        end
    end
    if maxDist then
        local pcoords = GetEntityCoords(GetPlayerPed(src))
        if #(pcoords - GetEntityCoords(entity)) > maxDist then
            return false, 0
        end
    end
    return true, entity
end

---Fetch a player's job/gang snapshot for permission checks.
---@param src number
---@return table|nil { citizenid, job, jobGrade, onDuty, gang, gangGrade }
local function playerSnapshot(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    local pd = player.PlayerData
    local job, gang = pd.job, pd.gang
    return {
        citizenid = pd.citizenid,
        job = job and job.name or nil,
        jobGrade = (job and job.grade and job.grade.level) or 0,
        onDuty = (job and job.onduty) or false,
        gang = gang and gang.name or nil,
        gangGrade = (gang and gang.grade and gang.grade.level) or 0,
    }
end

exports('ValidateDistance', validateDistance)
exports('ValidateAmount', validateAmount)
exports('ValidateNetEntity', validateNetEntity)
exports('PlayerSnapshot', playerSnapshot)
