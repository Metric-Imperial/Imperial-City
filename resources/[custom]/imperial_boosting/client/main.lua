--- imperial_boosting/client/main.lua
--- Tablet item spawns a contract; client spawns/locates the target vehicle
--- client-side for gameplay feel, but the server independently verifies the
--- entity's model and position before ever paying out.

local active = nil -- { model, timeLimit, expiresAt }

exports('useTablet', function()
    if active then
        lib.notify({ type = 'inform', description = 'You already have an active contract.' })
        return
    end
    local ok, result = lib.callback.await('imperial_boosting:requestContract', false)
    if not ok then
        local messages = { active = 'Finish your current contract first.', notablet = 'You need a boosting tablet.' }
        lib.notify({ type = 'error', description = messages[result] or 'No contracts available.' })
        return
    end
    active = { model = result.model, timeLimit = result.timeLimit, expiresAt = GetGameTimer() + result.timeLimit * 1000 }
    lib.notify({ type = 'success', description = ('Target acquired: %s. Deliver within %d minutes.'):format(
        GetLabelText(GetDisplayNameFromVehicleModel(result.model)), math.floor(result.timeLimit / 60)) })
end)

CreateThread(function()
    while true do
        Wait(1000)
        if active and GetGameTimer() > active.expiresAt then
            lib.notify({ type = 'error', description = 'Contract expired.' })
            active = nil
        end
    end
end)

-- Track entering the target vehicle model to register its net id + fire the
-- (chance-based) theft dispatch hook.
local lastVehicle = nil
CreateThread(function()
    while true do
        Wait(1000)
        if active then
            local ped = cache.ped
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and veh ~= lastVehicle then
                lastVehicle = veh
                if GetEntityModel(veh) == joaat(active.model) then
                    local netId = NetworkGetNetworkIdFromEntity(veh)
                    local ok = lib.callback.await('imperial_boosting:registerVehicle', false, netId)
                    if ok then
                        TriggerServerEvent('imperial_boosting:server:vehicleEntered')
                        lib.notify({ type = 'success', description = 'This is the one. Get it to the drop-off.' })
                    end
                end
            elseif veh == 0 then
                lastVehicle = nil
            end
        end
    end
end)

CreateThread(function()
    local drop = ImperialBoosting.dropoff
    local blip = AddBlipForCoord(drop.x, drop.y, drop.z)
    SetBlipSprite(blip, 67)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Chop Contact')
    EndTextCommandSetBlipName(blip)

    exports.ox_target:addSphereZone({
        coords = vec3(drop.x, drop.y, drop.z),
        radius = ImperialBoosting.dropoffRadius,
        options = {{
            name = 'imperial_boosting_deliver',
            label = 'Deliver vehicle',
            icon = 'fa-solid fa-warehouse',
            onSelect = function()
                if not active then
                    lib.notify({ type = 'error', description = 'You have no active contract.' })
                    return
                end
                local ok, result = lib.callback.await('imperial_boosting:deliver', false)
                if ok then
                    lib.notify({ type = 'success', description = ('Paid: %d dirty cash.'):format(result.pay) })
                    active = nil
                else
                    local messages = {
                        expired = 'Contract expired.', novehicle = 'Bring the correct vehicle.',
                        wrongvehicle = 'This is not the target vehicle.', notatdropoff = 'Get closer to the drop-off.',
                    }
                    lib.notify({ type = 'error', description = messages[result] or 'Delivery failed.' })
                end
            end,
        }},
    })
end)
