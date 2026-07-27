--- imperial_fire/client/main.lua
--- Station points, equipment, and incident visuals. Fire effects are
--- client-rendered presentation (StartScriptFire is not networked); the
--- server is authoritative for whether the incident exists and its progress.

local activeIncidents = {} -- [id] = { blip, extinguishing, data }

local function fmt(n) return lib.math.groupdigits(n or 0) end

-- ── stations ────────────────────────────────────────────────────────────
CreateThread(function()
    for _, station in ipairs(ImperialFire.stations) do
        if station.blip then
            local blip = AddBlipForCoord(station.duty.x, station.duty.y, station.duty.z)
            SetBlipSprite(blip, station.blip.sprite)
            SetBlipColour(blip, station.blip.colour)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(station.label)
            EndTextCommandSetBlipName(blip)
        end

        exports.ox_target:addSphereZone({
            coords = station.duty, radius = 1.5,
            options = {{
                name = 'imperial_fire_duty_' .. station.id,
                label = 'Toggle Duty',
                icon = 'fa-solid fa-fire-flame-curved',
                onSelect = function()
                    local onDuty = lib.callback.await('imperial_fire:toggleDuty', false)
                    if onDuty == nil then
                        lib.notify({ type = 'error', description = 'Fire department only.' })
                        return
                    end
                    lib.notify({ type = onDuty and 'success' or 'inform',
                        description = onDuty and 'On duty.' or 'Off duty.' })
                end,
            }},
        })

        exports.ox_target:addSphereZone({
            coords = station.equipment, radius = 1.5,
            options = {{
                name = 'imperial_fire_equip_' .. station.id,
                label = 'Equipment Locker',
                icon = 'fa-solid fa-fire-extinguisher',
                onSelect = function()
                    -- shared equipment stash; admins stock consumables, gear is returnable
                    exports.ox_inventory:openInventory('stash', 'fire_equip_' .. station.id)
                end,
            }},
        })
    end
end)

-- ── incidents ───────────────────────────────────────────────────────────
local function drawIncident(incident)
    local blip = AddBlipForCoord(incident.coords.x, incident.coords.y, incident.coords.z)
    SetBlipSprite(blip, 436)
    SetBlipColour(blip, incident.priority >= 4 and 1 or 17)
    SetBlipFlashes(blip, true)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(incident.label)
    EndTextCommandSetBlipName(blip)

    exports.ox_target:addSphereZone({
        coords = incident.coords, radius = 4.0,
        options = {{
            name = 'imperial_fire_extinguish_' .. incident.id,
            label = 'Extinguish',
            icon = 'fa-solid fa-droplet',
            onSelect = function()
                local finished = lib.progressCircle({
                    duration = 1500,
                    label = 'Extinguishing…',
                    position = 'bottom',
                    disable = { move = true, combat = true },
                })
                if not finished then return end
                local ok, result = lib.callback.await('imperial_fire:extinguish', false, incident.id)
                if not ok then
                    local messages = {
                        notonduty = 'You must be on duty.',
                        toofar = 'Move closer.',
                        notool = 'You need an extinguisher or hose.',
                    }
                    lib.notify({ type = 'error', description = messages[result] or 'No effect.' })
                    return
                end
                if result.done then
                    lib.notify({ type = 'success', description = ('Incident resolved. +$%s'):format(fmt(result.reward)) })
                else
                    lib.notify({ type = 'inform', description = ('Progress: %d remaining'):format(result.remaining) })
                end
            end,
        }},
    })

    return { blip = blip, zoneName = 'imperial_fire_extinguish_' .. incident.id }
end

RegisterNetEvent('imperial_fire:client:incidentStart', function(data)
    if activeIncidents[data.id] then return end
    local handle = drawIncident(data)
    activeIncidents[data.id] = handle
end)

RegisterNetEvent('imperial_fire:client:incidentEnd', function(id)
    local handle = activeIncidents[id]
    if not handle then return end
    RemoveBlip(handle.blip)
    exports.ox_target:removeZone(handle.zoneName)
    activeIncidents[id] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, handle in pairs(activeIncidents) do
        RemoveBlip(handle.blip)
        exports.ox_target:removeZone(handle.zoneName)
    end
end)
