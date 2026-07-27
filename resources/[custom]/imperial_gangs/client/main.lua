--- imperial_gangs/client/main.lua

local function fmt(n) return lib.math.groupdigits(n or 0) end

local function openCreation()
    local input = lib.inputDialog('Found a Gang', {
        { type = 'input', label = 'Gang name' },
    })
    if not input or not input[1] then return end

    local ok, result = lib.callback.await('imperial_gangs:startFounding', false, input[1])
    if not ok then
        local messages = { badname = 'Invalid or reserved name.', alreadyingang = 'You are already in a gang.', taken = 'That name is taken.' }
        lib.notify({ type = 'error', description = messages[result] or 'Could not start.' })
        return
    end

    lib.notify({ type = 'inform', description = ('Gather %d founding members nearby within %ds, then finalise.')
        :format(ImperialGangs.minFoundingMembers, ImperialGangs.foundingWindowSec) })

    -- one-shot expiry notice for the founder
    CreateThread(function()
        local remaining = result.expiresAt - os.time()
        if remaining > 0 then Wait(remaining * 1000) end
        lib.notify({ type = 'inform', description = 'Founding window closed.' })
    end)

    lib.registerContext({
        id = 'imperial_gangs_founding',
        title = 'Founding Session',
        options = {
            {
                title = 'Finalise gang',
                description = 'Requires enough nearby members to have joined.',
                onSelect = function()
                    local fok, ferr = lib.callback.await('imperial_gangs:finaliseFounding', false)
                    if fok then
                        lib.notify({ type = 'success', description = 'Gang founded!' })
                    else
                        local messages = { notenough = 'Not enough founding members yet.', expired = 'Founding window expired.', insufficient = 'Not enough gang funds.' }
                        lib.notify({ type = 'error', description = messages[ferr] or 'Could not finalise.' })
                    end
                end,
            },
        },
    })
    lib.showContext('imperial_gangs_founding')
end

RegisterCommand('creategang', openCreation, false)

RegisterCommand('joingang', function()
    local player, dist = lib.getClosestPlayer()
    if not player or dist > ImperialGangs.foundingRadius then
        lib.notify({ type = 'error', description = 'No founding session nearby.' })
        return
    end
    local ok, result = lib.callback.await('imperial_gangs:joinFounding', false, GetPlayerServerId(player))
    if ok then
        lib.notify({ type = 'success', description = ('Joined founding session (%d so far).'):format(result.count) })
    else
        local messages = { expired = 'That founding session has expired.', alreadyingang = 'You are already in a gang.', toofar = 'Move closer to the founder.' }
        lib.notify({ type = 'error', description = messages[result] or 'Could not join.' })
    end
end, false)

-- ── management menu ────────────────────────────────────────────────────
local function openManagement()
    local data = lib.callback.await('imperial_gangs:getManagement', false)
    if not data then
        lib.notify({ type = 'error', description = 'You are not in a gang.' })
        return
    end

    local options = {
        { title = data.label, description = ('Reputation: %d'):format(data.reputation), disabled = true },
        {
            title = 'Deposit cash',
            onSelect = function()
                local input = lib.inputDialog('Deposit', { { type = 'number', label = 'Amount', min = 1 } })
                if not input or not input[1] then return end
                local ok, bal = lib.callback.await('imperial_gangs:deposit', false, input[1])
                if ok then lib.notify({ type = 'success', description = ('Balance: $%s'):format(fmt(bal)) }) end
            end,
        },
    }

    if data.balance ~= nil then
        options[#options + 1] = { title = ('Balance: $%s'):format(fmt(data.balance)), disabled = true }
        options[#options + 1] = {
            title = 'Withdraw cash',
            onSelect = function()
                local input = lib.inputDialog('Withdraw', { { type = 'number', label = 'Amount', min = 1 } })
                if not input or not input[1] then return end
                local ok, bal = lib.callback.await('imperial_gangs:withdraw', false, input[1])
                if ok then lib.notify({ type = 'success', description = ('Balance: $%s'):format(fmt(bal)) })
                else lib.notify({ type = 'error', description = 'Withdraw failed.' }) end
            end,
        }
        options[#options + 1] = {
            title = 'Members',
            onSelect = function() openRoster(data) end,
        }
        options[#options + 1] = {
            title = 'Invite nearby player',
            onSelect = function()
                local player, dist = lib.getClosestPlayer()
                if not player or dist > 5.0 then
                    lib.notify({ type = 'error', description = 'No one nearby.' })
                    return
                end
                local ok = lib.callback.await('imperial_gangs:invite', false, GetPlayerServerId(player))
                if ok then lib.notify({ type = 'success', description = 'Invited.' }) end
            end,
        }
        if data.myRank >= 3 then
            options[#options + 1] = {
                title = 'Disband gang',
                onSelect = function()
                    local confirm = lib.alertDialog({ header = 'Disband?', content = 'This cannot be undone.', cancel = true })
                    if confirm == 'confirm' then
                        lib.callback.await('imperial_gangs:disband', false)
                    end
                end,
            }
        end
    end

    lib.registerContext({ id = 'imperial_gangs_mgmt', title = data.label, options = options })
    lib.showContext('imperial_gangs_mgmt')
end

function openRoster(data)
    local options = {}
    for _, m in ipairs(data.roster) do
        options[#options + 1] = {
            title = ('%s — %s'):format(m.name, ImperialGangs.ranks[m.rank].label),
            onSelect = function()
                if data.myRank < 2 then return end
                lib.registerContext({
                    id = 'imperial_gangs_member', title = m.name, menu = 'imperial_gangs_mgmt',
                    options = {
                        {
                            title = 'Set rank',
                            onSelect = function()
                                local input = lib.inputDialog('Rank', { { type = 'number', label = 'Rank (0-2)', default = m.rank, min = 0, max = 2 } })
                                if input and input[1] then
                                    lib.callback.await('imperial_gangs:setRank', false, m.citizenid, input[1])
                                end
                            end,
                        },
                        {
                            title = 'Transfer leadership',
                            onSelect = function()
                                if data.myRank < 3 then return end
                                lib.callback.await('imperial_gangs:transferLeadership', false, m.citizenid)
                            end,
                        },
                        {
                            title = 'Kick',
                            onSelect = function()
                                lib.callback.await('imperial_gangs:kick', false, m.citizenid)
                            end,
                        },
                    },
                })
                lib.showContext('imperial_gangs_member')
            end,
        }
    end
    lib.registerContext({ id = 'imperial_gangs_roster', title = 'Members', menu = 'imperial_gangs_mgmt', options = options })
    lib.showContext('imperial_gangs_roster')
end

RegisterCommand('gang', openManagement, false)

RegisterCommand('gangstash', function()
    local stashId = lib.callback.await('imperial_gangs:openStash', false)
    if not stashId then
        lib.notify({ type = 'error', description = 'You cannot access gang storage.' })
        return
    end
    exports.ox_inventory:openInventory('stash', stashId)
end, false)
