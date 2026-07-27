--- imperial_blackmarket/client/main.lua

local function fmt(n) return lib.math.groupdigits(n or 0) end
local fencePed = nil

local function openFence()
    local options = {}
    for item, rate in pairs(ImperialBlackmarket.buyRates) do
        local have = exports.ox_inventory:Search('count', item)
        if have and have > 0 then
            options[#options + 1] = {
                title = ('%s (x%d)'):format(item, have),
                description = ('%d tokens each'):format(rate),
                onSelect = function()
                    local input = lib.inputDialog('Sell ' .. item, {
                        { type = 'number', label = 'Quantity', default = 1, min = 1, max = have },
                    })
                    if not input or not input[1] then return end
                    local ok, total = lib.callback.await('imperial_blackmarket:sell', false, item, input[1])
                    if ok then
                        lib.notify({ type = 'success', description = ('+%d crim tokens'):format(total) })
                    else
                        lib.notify({ type = 'error', description = 'No deal.' })
                    end
                end,
            }
        end
    end
    if #options == 0 then
        lib.notify({ type = 'error', description = "I'm not interested in what you're carrying." })
        return
    end
    lib.registerContext({ id = 'imperial_bm_fence', title = 'Fence', options = options })
    lib.showContext('imperial_bm_fence')
end

CreateThread(function()
    local fence = ImperialBlackmarket.fence
    lib.points.new({
        coords = vec3(fence.coords.x, fence.coords.y, fence.coords.z),
        distance = 40.0,
        onEnter = function()
            lib.requestModel(fence.model, 10000)
            fencePed = CreatePed(4, fence.model, fence.coords.x, fence.coords.y, fence.coords.z - 1.0, fence.coords.w, false, false)
            FreezeEntityPosition(fencePed, true)
            SetEntityInvincible(fencePed, true)
            SetBlockingOfNonTemporaryEvents(fencePed, true)
            exports.ox_target:addLocalEntity(fencePed, {{
                name = 'imperial_bm_fence',
                label = 'Talk to the fence',
                icon = 'fa-solid fa-user-secret',
                onSelect = openFence,
            }})
        end,
        onExit = function()
            if fencePed and DoesEntityExist(fencePed) then DeletePed(fencePed) end
            fencePed = nil
        end,
    })

    for i, front in ipairs(ImperialBlackmarket.launderFronts) do
        exports.ox_target:addSphereZone({
            coords = vec3(front.coords.x, front.coords.y, front.coords.z),
            radius = 2.0,
            options = {{
                name = ('imperial_bm_launder_%d'):format(i),
                label = front.label,
                icon = 'fa-solid fa-money-bill-transfer',
                onSelect = function()
                    local status = lib.callback.await('imperial_blackmarket:getLaunderStatus', false)
                    if status then
                        if status.ready then
                            local ok, amount = lib.callback.await('imperial_blackmarket:collectLaunder', false)
                            if ok then
                                lib.notify({ type = 'success', description = ('Collected $%s clean.'):format(fmt(amount)) })
                            end
                        else
                            local remaining = status.readyAt - os.time()
                            lib.notify({ type = 'inform', description = ('Still working — check back later.') })
                        end
                        return
                    end

                    local input = lib.inputDialog(front.label, {
                        { type = 'number', label = 'Dirty cash amount', min = 1, max = front.maxPerJob },
                    })
                    if not input or not input[1] then return end
                    local ok, err = lib.callback.await('imperial_blackmarket:startLaunder', false, i, input[1])
                    if ok then
                        lib.notify({ type = 'success', description = 'Cash is moving through the front.' })
                    else
                        local messages = {
                            invalid = 'Amount out of range.', toofar = 'Move closer.',
                            active = 'You already have a job running.', nodirty = 'You have no dirty cash.',
                        }
                        lib.notify({ type = 'error', description = messages[err] or 'Could not start.' })
                    end
                end,
            }},
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if fencePed and DoesEntityExist(fencePed) then DeletePed(fencePed) end
end)
