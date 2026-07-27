--- imperial_farming/client/main.lua
--- Seed placement, plant prop streaming, plant interactions, wholesaler, blips.

local plantProps = {}   -- [plantId] = { obj, stage }
local seedByItem = {}
for cropName, crop in pairs(ImperialFarming.crops) do
    seedByItem[crop.seed] = cropName
end

-- ── seed item use (ox_inventory client export) ──────────────────────────
exports('useSeed', function(data)
    local cropName = seedByItem[data.name]
    if not cropName then return end

    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        lib.notify({ type = 'error', description = 'Step out of the vehicle first.' })
        return
    end

    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local target = coords + fwd * 1.2
    local found, groundZ = GetGroundZFor_3dCoord(target.x, target.y, target.z + 1.0, false)
    if found then target = vec3(target.x, target.y, groundZ) end

    local finished = lib.progressCircle({
        duration = 4000,
        label = 'Planting…',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    })
    if not finished then return end

    local ok, err = lib.callback.await('imperial_farming:plant', false, cropName, target)
    if ok then
        lib.notify({ type = 'success', description = 'Seed planted. Keep it watered.' })
        refreshPlants()
    else
        local messages = {
            not_farmland = 'This is not farmland.',
            limit = 'You are tending too many plants already.',
            too_close = 'Too close to another plant.',
            no_seed = 'You have no seeds.',
            too_far = 'You cannot reach there.',
        }
        lib.notify({ type = 'error', description = messages[err] or 'You cannot plant here.' })
    end
end)

-- ── plant interactions ──────────────────────────────────────────────────
local function interact(plantId, action)
    local labels = { water = 'Watering…', fertilise = 'Fertilising…', harvest = 'Harvesting…' }
    local finished = lib.progressCircle({
        duration = action == 'harvest' and 5000 or 3500,
        label = labels[action],
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    })
    if not finished then return end

    local ok, extra = lib.callback.await('imperial_farming:' .. action, false, plantId)
    if ok then
        local messages = {
            water = 'Plant watered.',
            fertilise = 'Fertiliser applied.',
            harvest = ('Harvested %s items.'):format(extra or ''),
        }
        lib.notify({ type = 'success', description = messages[action] })
        if action == 'harvest' then refreshPlants() end
    else
        local messages = {
            no_can = 'You need a watering can.',
            no_fertiliser = 'You need fertiliser.',
            already = 'Already fertilised.',
            not_ready = 'Not ready for harvest.',
            not_yours = 'This is not your crop.',
            dead = 'The plant has died.',
            capacity = 'You cannot carry the harvest.',
        }
        lib.notify({ type = 'error', description = messages[extra] or 'Nothing happened.' })
    end
end

-- ── prop streaming ──────────────────────────────────────────────────────
local function clearPlant(plantId)
    local p = plantProps[plantId]
    if p then
        if DoesEntityExist(p.obj) then DeleteObject(p.obj) end
        plantProps[plantId] = nil
    end
end

function refreshPlants()
    local coords = GetEntityCoords(cache.ped)
    local plants = lib.callback.await('imperial_farming:getNearbyPlants', false, coords)
    local seen = {}

    for _, plant in ipairs(plants or {}) do
        seen[plant.id] = true
        local existing = plantProps[plant.id]
        if existing and existing.stage ~= plant.stage then
            clearPlant(plant.id)
            existing = nil
        end
        if not existing then
            local model = ImperialFarming.stageProps[plant.stage]
            lib.requestModel(model, 10000)
            local obj = CreateObject(model, plant.coords.x, plant.coords.y, plant.coords.z, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            plantProps[plant.id] = { obj = obj, stage = plant.stage }

            exports.ox_target:addLocalEntity(obj, {
                {
                    name = ('imperial_farm_water_%d'):format(plant.id),
                    label = 'Water plant',
                    icon = 'fa-solid fa-droplet',
                    onSelect = function() interact(plant.id, 'water') end,
                },
                {
                    name = ('imperial_farm_fert_%d'):format(plant.id),
                    label = 'Fertilise',
                    icon = 'fa-solid fa-seedling',
                    onSelect = function() interact(plant.id, 'fertilise') end,
                },
                {
                    name = ('imperial_farm_harvest_%d'):format(plant.id),
                    label = 'Harvest',
                    icon = 'fa-solid fa-wheat-awn',
                    onSelect = function() interact(plant.id, 'harvest') end,
                },
            })
        end
    end

    for plantId in pairs(plantProps) do
        if not seen[plantId] then clearPlant(plantId) end
    end
end

RegisterNetEvent('imperial_farming:client:removePlant', function(plantId)
    clearPlant(plantId)
end)

-- Sync only while inside a farming zone (no idle work elsewhere)
CreateThread(function()
    for _, zone in ipairs(ImperialFarming.zones) do
        if zone.blip then
            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, zone.blip.sprite)
            SetBlipColour(blip, zone.blip.colour)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(zone.label)
            EndTextCommandSetBlipName(blip)
        end

        lib.points.new({
            coords = zone.coords,
            distance = zone.radius + ImperialFarming.syncRadius,
            onEnter = function()
                refreshPlants()
            end,
            onExit = function()
                for plantId in pairs(plantProps) do clearPlant(plantId) end
            end,
            nearby = function()
                -- lib.points nearby runs each frame; throttle with a timer flag
            end,
        })
    end

    while true do
        Wait(ImperialFarming.syncIntervalMs)
        if next(plantProps) ~= nil then
            refreshPlants()
        end
    end
end)

-- ── wholesaler ──────────────────────────────────────────────────────────
CreateThread(function()
    local w = ImperialFarming.wholesaler
    lib.points.new({
        coords = vec3(w.coords.x, w.coords.y, w.coords.z),
        distance = 60.0,
        onEnter = function()
            lib.requestModel(w.model, 10000)
            local ped = CreatePed(4, w.model, w.coords.x, w.coords.y, w.coords.z - 1.0, w.coords.w, false, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'imperial_farming_wholesale',
                    label = 'Sell produce boxes',
                    icon = 'fa-solid fa-boxes-stacked',
                    onSelect = function()
                        local input = lib.inputDialog('Wholesale', {
                            { type = 'number', label = 'Boxes to sell', default = 1, min = 1, max = 50 },
                        })
                        if not input or not input[1] then return end
                        local ok, total = lib.callback.await('imperial_farming:sellBoxes', false, input[1])
                        if ok then
                            lib.notify({ type = 'success', description = ('Sold for $%s'):format(lib.math.groupdigits(total)) })
                        else
                            lib.notify({ type = 'error', description = 'No boxes to sell.' })
                        end
                    end,
                },
            })
            LocalPlayer.state.imperialWholesalerPed = ped
        end,
        onExit = function()
            local ped = LocalPlayer.state.imperialWholesalerPed
            if ped and DoesEntityExist(ped) then DeletePed(ped) end
            LocalPlayer.state.imperialWholesalerPed = nil
        end,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for plantId in pairs(plantProps) do clearPlant(plantId) end
    local ped = LocalPlayer.state.imperialWholesalerPed
    if ped and DoesEntityExist(ped) then DeletePed(ped) end
end)
