--- imperial_dispatch/client/main.lua
--- Renders alerts for on-duty units. Alert routing/authorisation is entirely
--- server-side; this file only presents what the server already decided to send.

local activeBlips = {}

local function clearAlert(id)
    local blip = activeBlips[id]
    if blip then
        RemoveBlip(blip)
        activeBlips[id] = nil
    end
end

RegisterNetEvent('imperial_dispatch:client:alert', function(payload)
    local jobCfg = ImperialDispatch.jobs[payload.jobs[1]]

    if jobCfg and jobCfg.sound then
        PlaySoundFrontend(-1, jobCfg.sound, 'GTAO_FM_Events_Soundset', true)
    end

    lib.notify({
        id = 'dispatch_' .. payload.id,
        title = ('%s%s'):format(payload.code and (payload.code .. ' — ') or '', payload.title),
        description = payload.description,
        type = payload.priority >= 4 and 'error' or (payload.priority >= 3 and 'warning' or 'inform'),
        duration = payload.duration,
        position = 'top-right',
    })

    if payload.blip ~= false then
        local blip = AddBlipForCoord(payload.coords.x, payload.coords.y, payload.coords.z)
        SetBlipSprite(blip, (jobCfg and jobCfg.blipSprite) or 161)
        SetBlipColour(blip, (jobCfg and jobCfg.blipColour) or 1)
        SetBlipScale(blip, 0.9)
        SetBlipFlashes(blip, payload.priority >= 4)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(payload.title)
        EndTextCommandSetBlipName(blip)
        activeBlips[payload.id] = blip

        SetTimeout(payload.duration, function() clearAlert(payload.id) end)
    end
end)

RegisterCommand('panic', function()
    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData or not playerData.job then return end
    TriggerServerEvent('imperial_dispatch:server:panic', playerData.job.name)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(activeBlips) do clearAlert(id) end
end)
