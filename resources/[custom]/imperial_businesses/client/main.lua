--- imperial_businesses/client/main.lua
--- Targets/blips for every configured business site; management menu, POS
--- flow, stash access. All decisions are server-validated; this file only
--- renders UI and forwards requests.

local function fmt(n) return lib.math.groupdigits(n or 0) end

local function openManagement(site)
    local data = lib.callback.await('imperial_businesses:getManagement', false, site.key)
    if not data then
        lib.notify({ type = 'error', description = 'You do not work here.' })
        return
    end

    local options = {
        {
            title = 'Deposit cash',
            icon = 'fa-solid fa-hand-holding-dollar',
            onSelect = function()
                local input = lib.inputDialog('Deposit', {
                    { type = 'number', label = 'Amount', min = 1 },
                })
                if not input or not input[1] then return end
                local ok, bal = lib.callback.await('imperial_businesses:deposit', false, site.key, input[1])
                if ok then
                    lib.notify({ type = 'success', description = ('Deposited. Balance: $%s'):format(fmt(bal)) })
                else
                    lib.notify({ type = 'error', description = 'Deposit failed.' })
                end
            end,
        },
    }

    if data.balance ~= nil then
        options[#options + 1] = {
            title = ('Balance: $%s'):format(fmt(data.balance)),
            description = ('Weekly lease: $%s | Arrears: %d'):format(fmt(data.leaseWeekly), data.leaseArrears),
            icon = 'fa-solid fa-vault',
            disabled = true,
        }
        options[#options + 1] = {
            title = 'Withdraw cash',
            icon = 'fa-solid fa-hand-holding',
            onSelect = function()
                local input = lib.inputDialog('Withdraw', {
                    { type = 'number', label = 'Amount', min = 1 },
                })
                if not input or not input[1] then return end
                local ok, bal = lib.callback.await('imperial_businesses:withdraw', false, site.key, input[1])
                if ok then
                    lib.notify({ type = 'success', description = ('Withdrawn. Balance: $%s'):format(fmt(bal)) })
                else
                    lib.notify({ type = 'error', description = 'Withdraw failed or insufficient funds.' })
                end
            end,
        }
        options[#options + 1] = {
            title = 'View ledger',
            icon = 'fa-solid fa-book',
            onSelect = function() openLedger(site) end,
        }
        options[#options + 1] = {
            title = 'Manage employees',
            icon = 'fa-solid fa-users',
            onSelect = function() openRoster(site, data) end,
        }
    end

    lib.registerContext({
        id = 'imperial_biz_mgmt',
        title = data.label,
        options = options,
    })
    lib.showContext('imperial_biz_mgmt')
end

function openLedger(site)
    local rows = lib.callback.await('imperial_businesses:getLedger', false, site.key, 1)
    local options = {}
    for _, row in ipairs(rows or {}) do
        options[#options + 1] = {
            title = ('%s%s'):format(row.amount >= 0 and '+' or '', fmt(row.amount)),
            description = ('%s | %s | balance $%s'):format(row.type, row.reason or '', fmt(row.balance_after)),
        }
    end
    if #options == 0 then options[1] = { title = 'No transactions yet' } end
    lib.registerContext({ id = 'imperial_biz_ledger', title = 'Ledger', menu = 'imperial_biz_mgmt', options = options })
    lib.showContext('imperial_biz_ledger')
end

function openRoster(site, data)
    local options = {}
    for _, e in ipairs(data.roster or {}) do
        options[#options + 1] = {
            title = ('%s — %s'):format(e.name, ImperialBusinesses.grades[e.grade].label),
            description = e.online and (e.onDuty and 'Online, on duty' or 'Online') or 'Offline',
            icon = e.online and 'fa-solid fa-circle-user' or 'fa-regular fa-circle-user',
            onSelect = function()
                lib.registerContext({
                    id = 'imperial_biz_employee',
                    title = e.name,
                    menu = 'imperial_biz_mgmt',
                    options = {
                        {
                            title = 'Promote/demote',
                            onSelect = function()
                                local input = lib.inputDialog('Set grade', {
                                    { type = 'number', label = 'Grade (0-2)', default = e.grade, min = 0, max = 2 },
                                })
                                if input and input[1] then
                                    lib.callback.await('imperial_businesses:setGrade', false, site.key, e.citizenid, input[1])
                                end
                            end,
                        },
                        {
                            title = 'Set wage',
                            onSelect = function()
                                local input = lib.inputDialog('Set wage', {
                                    { type = 'number', label = 'Wage per cycle', default = e.wage, min = 0 },
                                })
                                if input and input[1] then
                                    lib.callback.await('imperial_businesses:setWage', false, site.key, e.citizenid, input[1])
                                end
                            end,
                        },
                        {
                            title = 'Fire',
                            icon = 'fa-solid fa-user-minus',
                            onSelect = function()
                                local confirm = lib.alertDialog({
                                    header = 'Fire employee?',
                                    content = ('Remove %s from %s?'):format(e.name, data.label),
                                    centered = true,
                                    cancel = true,
                                })
                                if confirm == 'confirm' then
                                    lib.callback.await('imperial_businesses:fire', false, site.key, e.citizenid)
                                end
                            end,
                        },
                    },
                })
                lib.showContext('imperial_biz_employee')
            end,
        }
    end
    options[#options + 1] = {
        title = 'Hire nearby player',
        icon = 'fa-solid fa-user-plus',
        onSelect = function()
            local player, dist = lib.getClosestPlayer()
            if not player or dist > 5.0 then
                lib.notify({ type = 'error', description = 'No one nearby.' })
                return
            end
            local targetId = GetPlayerServerId(player)
            local ok = lib.callback.await('imperial_businesses:hire', false, site.key, targetId)
            if ok then lib.notify({ type = 'success', description = 'Hired.' }) end
        end,
    }
    lib.registerContext({ id = 'imperial_biz_roster', title = 'Employees', menu = 'imperial_biz_mgmt', options = options })
    lib.showContext('imperial_biz_roster')
end

-- ── POS ─────────────────────────────────────────────────────────────────
local function openPos(site)
    local player, dist = lib.getClosestPlayer()
    if not player or dist > 8.0 then
        lib.notify({ type = 'error', description = 'No customer nearby.' })
        return
    end
    local input = lib.inputDialog('Charge Customer', {
        { type = 'number', label = 'Amount', min = 1 },
        { type = 'input', label = 'Note (optional)' },
    })
    if not input or not input[1] then return end
    local ok = lib.callback.await('imperial_businesses:pos:charge', false,
        site.key, GetPlayerServerId(player), input[1], input[2])
    if ok then
        lib.notify({ type = 'inform', description = 'Invoice sent to customer.' })
    else
        lib.notify({ type = 'error', description = 'Could not charge customer.' })
    end
end

RegisterNetEvent('imperial_businesses:client:posPrompt', function(label, amount, note)
    local alert = lib.alertDialog({
        header = ('%s — Payment Request'):format(label),
        content = note and ('$%s — %s'):format(lib.math.groupdigits(amount), note)
            or ('$%s'):format(lib.math.groupdigits(amount)),
        centered = true,
        cancel = true,
        labels = { confirm = 'Pay', cancel = 'Decline' },
    })
    lib.callback.await('imperial_businesses:pos:respond', false, alert == 'confirm')
end)

-- ── stashes ─────────────────────────────────────────────────────────────
local function openStash(site, stashType)
    local stashId = lib.callback.await('imperial_businesses:openStash', false, site.key, stashType)
    if not stashId then
        lib.notify({ type = 'error', description = 'You cannot access this.' })
        return
    end
    exports.ox_inventory:openInventory('stash', stashId)
end

-- ── duty ────────────────────────────────────────────────────────────────
local function toggleDuty(site)
    local onDuty = lib.callback.await('imperial_businesses:toggleDuty', false, site.key)
    if onDuty == nil then
        lib.notify({ type = 'error', description = 'You do not work here.' })
        return
    end
    lib.notify({ type = onDuty and 'success' or 'inform',
        description = onDuty and 'You are now on duty.' or 'You clocked off.' })
end

-- ── zone setup ──────────────────────────────────────────────────────────
CreateThread(function()
    for _, site in ipairs(ImperialBusinessSites) do
        if site.blip then
            local blip = AddBlipForCoord(site.management.x, site.management.y, site.management.z)
            SetBlipSprite(blip, site.blip.sprite)
            SetBlipColour(blip, site.blip.colour)
            SetBlipScale(blip, 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(site.label)
            EndTextCommandSetBlipName(blip)
        end

        if site.management then
            exports.ox_target:addSphereZone({
                coords = site.management, radius = 1.5,
                options = {{
                    name = 'imperial_biz_mgmt_' .. site.key,
                    label = 'Business Management',
                    icon = 'fa-solid fa-briefcase',
                    onSelect = function() openManagement(site) end,
                }},
            })
        end
        if site.duty then
            exports.ox_target:addSphereZone({
                coords = site.duty, radius = 1.5,
                options = {{
                    name = 'imperial_biz_duty_' .. site.key,
                    label = 'Clock in/out',
                    icon = 'fa-solid fa-clock',
                    onSelect = function() toggleDuty(site) end,
                }},
            })
        end
        if site.storageShared then
            exports.ox_target:addSphereZone({
                coords = site.storageShared, radius = 1.5,
                options = {{
                    name = 'imperial_biz_shared_' .. site.key,
                    label = 'Storage',
                    icon = 'fa-solid fa-box',
                    onSelect = function() openStash(site, 'shared') end,
                }},
            })
        end
        if site.storageManagement then
            exports.ox_target:addSphereZone({
                coords = site.storageManagement, radius = 1.5,
                options = {{
                    name = 'imperial_biz_office_' .. site.key,
                    label = 'Office Safe',
                    icon = 'fa-solid fa-lock',
                    onSelect = function() openStash(site, 'mgmt') end,
                }},
            })
        end
        if site.storageIngredients then
            exports.ox_target:addSphereZone({
                coords = site.storageIngredients, radius = 1.5,
                options = {{
                    name = 'imperial_biz_ingr_' .. site.key,
                    label = 'Ingredients',
                    icon = 'fa-solid fa-carrot',
                    onSelect = function() openStash(site, 'ingr') end,
                }},
            })
        end
        for i, pos in ipairs(site.pos or {}) do
            exports.ox_target:addSphereZone({
                coords = pos, radius = 1.5,
                options = {{
                    name = ('imperial_biz_pos_%s_%d'):format(site.key, i),
                    label = 'Charge Customer (POS)',
                    icon = 'fa-solid fa-cash-register',
                    onSelect = function() openPos(site) end,
                }},
            })
        end
    end
end)
