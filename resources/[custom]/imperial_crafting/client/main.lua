--- imperial_crafting/client/main.lua
--- Bench props/targets/blips + craft UI. All outcomes are server-decided.

local craftingBusy = false

local function doCraft(bench, recipe, count)
    if craftingBusy then return end
    craftingBusy = true

    local duration, err = lib.callback.await('imperial_crafting:startCraft', false,
        bench.id, recipe.id, count)

    if not duration then
        local messages = {
            ratelimited = 'Slow down.',
            busy = 'You are already working on something.',
            too_far = 'Move closer to the bench.',
            restricted = 'You cannot use this bench.',
            level = 'You lack the experience for this.',
            locked = 'You have not learned this recipe.',
            ingredients = 'You are missing materials.',
            invalid = 'You cannot craft that here.',
        }
        lib.notify({ type = 'error', description = messages[err] or 'Crafting failed.' })
        craftingBusy = false
        return
    end

    local finished = lib.progressCircle({
        duration = duration,
        label = ('Crafting %s…'):format(recipe.label),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })

    local skillPassed = true
    if finished and recipe.skillCheck then
        skillPassed = lib.skillCheck(table.unpack(recipe.skillCheckArgs or { 'easy', 'medium' }))
    end

    if not finished then
        -- cancelled: let the server session lapse; nothing was consumed
        lib.callback.await('imperial_crafting:finishCraft', false, false)
        craftingBusy = false
        return
    end

    local ok, err2 = lib.callback.await('imperial_crafting:finishCraft', false, skillPassed)
    if ok then
        lib.notify({ type = 'success', description = ('Crafted %s'):format(recipe.label) })
    else
        local messages = {
            failed = 'The attempt failed and materials were wasted.',
            skillcheck = 'You botched it — some materials were lost.',
            capacity = 'You cannot carry the result.',
            early = 'Crafting interrupted.',
            ingredients = 'You are missing materials.',
        }
        lib.notify({ type = 'error', description = messages[err2] or 'Crafting failed.' })
    end
    craftingBusy = false
end

local function openBench(bench)
    local menu = lib.callback.await('imperial_crafting:getBenchMenu', false, bench.id)
    if not menu or #menu == 0 then
        lib.notify({ type = 'error', description = 'Nothing to craft here.' })
        return
    end

    local options = {}
    for _, recipe in ipairs(menu) do
        local meta = {}
        for item, n in pairs(recipe.ingredients or {}) do
            meta[#meta + 1] = { label = item, value = ('x%d'):format(n) }
        end
        if recipe.anyProduce then
            meta[#meta + 1] = { label = 'any produce', value = ('x%d'):format(recipe.anyProduce) }
        end
        options[#options + 1] = {
            title = recipe.label,
            description = recipe.locked
                and ('Locked (level %d required%s)'):format(recipe.minLevel,
                    recipe.skillCheck and ', skill check' or '')
                or ('Level %d | %.1fs each'):format(recipe.level, recipe.duration / 1000),
            icon = recipe.locked and 'lock' or 'hammer',
            metadata = meta,
            disabled = recipe.locked,
            onSelect = function()
                local input = lib.inputDialog(recipe.label, {
                    { type = 'number', label = 'Quantity', default = 1, min = 1, max = ImperialCrafting.maxBatch },
                })
                if input and input[1] then
                    doCraft(bench, recipe, input[1])
                end
            end,
        }
    end

    lib.registerContext({
        id = 'imperial_crafting_bench',
        title = bench.label,
        options = options,
    })
    lib.showContext('imperial_crafting_bench')
end

-- ── bench props, targets, blips ─────────────────────────────────────────
local spawnedProps = {}

CreateThread(function()
    for _, bench in ipairs(ImperialCraftingBenches) do
        if bench.blip and not (bench.restrict and bench.restrict.hidden) then
            local blip = AddBlipForCoord(bench.coords.x, bench.coords.y, bench.coords.z)
            SetBlipSprite(blip, bench.blip.sprite)
            SetBlipColour(blip, bench.blip.colour)
            SetBlipScale(blip, bench.blip.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(bench.label)
            EndTextCommandSetBlipName(blip)
        end

        exports.ox_target:addSphereZone({
            coords = bench.coords,
            radius = ImperialCrafting.benchDistance,
            debug = false,
            options = {
                {
                    name = 'imperial_crafting_' .. bench.id,
                    label = bench.restrict and bench.restrict.hidden and 'Use bench' or ('Use %s'):format(bench.label),
                    icon = 'fa-solid fa-hammer',
                    onSelect = function() openBench(bench) end,
                },
            },
        })

        if bench.prop then
            lib.points.new({
                coords = bench.coords,
                distance = 60.0,
                onEnter = function()
                    if spawnedProps[bench.id] then return end
                    lib.requestModel(bench.prop, 10000)
                    local obj = CreateObject(bench.prop, bench.coords.x, bench.coords.y, bench.coords.z - 1.0, false, false, false)
                    SetEntityHeading(obj, bench.heading or 0.0)
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    spawnedProps[bench.id] = obj
                end,
                onExit = function()
                    local obj = spawnedProps[bench.id]
                    if obj and DoesEntityExist(obj) then DeleteObject(obj) end
                    spawnedProps[bench.id] = nil
                end,
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(spawnedProps) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
end)
