--- imperial_drugs/client/main.lua
--- Hidden lab targets + progress UI. All stage logic and timing floors are
--- server-side; this renders whatever getLabState returns.

local function fmt(n) return lib.math.groupdigits(n or 0) end

local function openLab(lab)
    local state = lib.callback.await('imperial_drugs:getLabState', false, lab.key)
    if not state then
        lib.notify({ type = 'error', description = 'You cannot access this.' })
        return
    end

    local options = {
        {
            title = 'Start new batch',
            icon = 'fa-solid fa-flask',
            disabled = #state.batches >= 2,
            onSelect = function()
                local ok, err = lib.callback.await('imperial_drugs:startBatch', false, lab.key)
                if ok then
                    lib.notify({ type = 'success', description = 'Batch started.' })
                else
                    local messages = {
                        toofar = 'Move closer.', noaccess = 'You lack access.',
                        full = 'This lab is at capacity.', ingredients = 'Missing materials.',
                    }
                    lib.notify({ type = 'error', description = messages[err] or 'Cannot start.' })
                end
            end,
        },
    }

    for _, batch in ipairs(state.batches) do
        options[#options + 1] = {
            title = ('%s — %s'):format(batch.stageLabel, batch.ready and 'Ready' or ('%ds remaining'):format(batch.secondsRemaining)),
            description = ('Quality %d%%'):format(batch.quality),
            icon = batch.ready and 'fa-solid fa-check' or 'fa-solid fa-hourglass-half',
            disabled = not batch.ready,
            onSelect = function()
                local ok, result = lib.callback.await('imperial_drugs:advanceBatch', false, batch.id)
                if ok and result.done then
                    lib.notify({ type = 'success', description = 'Product collected.' })
                elseif ok then
                    lib.notify({ type = 'success', description = 'Batch advanced.' })
                else
                    local messages = {
                        toofar = 'Move closer.', noaccess = 'You lack access.',
                        notready = 'Not ready yet.', ingredients = 'Missing materials.',
                        capacity = 'You cannot carry the product.',
                    }
                    lib.notify({ type = 'error', description = messages[result] or 'Nothing happened.' })
                end
            end,
        }
    end

    lib.registerContext({
        id = 'imperial_drugs_lab',
        title = ('%s (contamination %d%%)'):format(lab.label, state.contamination),
        options = options,
    })
    lib.showContext('imperial_drugs_lab')
end

CreateThread(function()
    for _, lab in ipairs(ImperialDrugs.labs) do
        exports.ox_target:addSphereZone({
            coords = lab.coords,
            radius = ImperialDrugs.accessDistance,
            options = {{
                name = 'imperial_drugs_' .. lab.key,
                label = 'Access lab',
                icon = 'fa-solid fa-flask',
                onSelect = function() openLab(lab) end,
            }},
        })

        -- police-only raid option, always visible to police so raids don't
        -- require prior knowledge of a hidden bench id
        exports.ox_target:addSphereZone({
            coords = lab.coords,
            radius = ImperialDrugs.accessDistance,
            options = {{
                name = 'imperial_drugs_raid_' .. lab.key,
                label = 'Raid & seize',
                icon = 'fa-solid fa-handcuffs',
                canInteract = function()
                    local playerData = exports.qbx_core:GetPlayerData()
                    return playerData and playerData.job and playerData.job.name == 'police'
                        and playerData.job.onduty
                end,
                onSelect = function()
                    local ok, seized = lib.callback.await('imperial_drugs:raidSeize', false, lab.key)
                    if ok then
                        lib.notify({ type = 'success', description = ('Seized %d batch(es).'):format(seized) })
                    end
                end,
            }},
        })
    end
end)
