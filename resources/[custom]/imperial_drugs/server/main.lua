--- imperial_drugs/server/main.lua
--- Server-authoritative lab production. Stage timing is wall-clock (derived
--- from stored timestamps), matching imperial_farming's restart-safe pattern.
--- No client ever declares a stage outcome; the server computes it from time.

local LABS = {}
for _, lab in ipairs(ImperialDrugs.labs) do LABS[lab.key] = lab end

local function loadLabRow(labKey)
    local row = MySQL.single.await('SELECT * FROM imperial_drug_labs WHERE lab_key = ?', { labKey })
    if row then return row end
    local id = MySQL.insert.await(
        'INSERT INTO imperial_drug_labs (lab_key) VALUES (?)', { labKey })
    return { id = id, lab_key = labKey, contamination = 0 }
end

local labRows = {}
CreateThread(function()
    for key in pairs(LABS) do
        labRows[key] = loadLabRow(key)
    end
end)

local function hasAccess(src, lab, snap)
    if lab.accessItem and exports.ox_inventory:GetItemCount(src, lab.accessItem) < 1 then
        return false
    end
    return true
end

-- ── start a batch (stage 1: gather, consumes ingredients immediately) ────
lib.callback.register('imperial_drugs:startBatch', function(src, labKey)
    if not exports.imperial_logging:RateLimit(src, 'drugs:start', 3, 30000) then return false end
    local lab = LABS[labKey]
    if not lab then return false end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end

    if not exports.imperial_logging:ValidateDistance(src, lab.coords, ImperialDrugs.accessDistance + 2.0) then
        return false, 'toofar'
    end
    if not hasAccess(src, lab, snap) then return false, 'noaccess' end

    local labRow = labRows[labKey]
    if not labRow then return false end

    local activeCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM imperial_drug_batches WHERE lab_id = ?', { labRow.id }) or 0
    if activeCount >= ImperialDrugs.maxActiveBatchesPerLab then return false, 'full' end

    local stage1 = ImperialDrugs.stages[1]
    for item, need in pairs(stage1.ingredients) do
        if exports.ox_inventory:GetItemCount(src, item) < need then
            return false, 'ingredients'
        end
    end
    for item, need in pairs(stage1.ingredients) do
        exports.ox_inventory:RemoveItem(src, item, need)
    end

    local now = os.time()
    local batchId = MySQL.insert.await([[
        INSERT INTO imperial_drug_batches (lab_id, citizenid, product, stage, quality, started_at, stage_ready_at)
        VALUES (?, ?, ?, 2, ?, ?, ?)
    ]], {
        labRow.id, snap.citizenid, lab.product,
        ImperialDrugs.qualityBaseByTier[lab.tier] or 50,
        now, now + ImperialDrugs.stages[2].durationSec,
    })

    exports.imperial_logging:Log({
        resource = 'imperial_drugs', category = 'gameplay', action = 'batch_started',
        source = src, data = { lab = labKey, batchId = batchId },
    })
    return true, batchId
end)

-- ── query lab state (batches + readiness) ────────────────────────────────
lib.callback.register('imperial_drugs:getLabState', function(src, labKey)
    local lab = LABS[labKey]
    if not lab then return nil end
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return nil end
    if not exports.imperial_logging:ValidateDistance(src, lab.coords, ImperialDrugs.accessDistance + 3.0) then
        return nil
    end
    if not hasAccess(src, lab, snap) then return nil end

    local labRow = labRows[labKey]
    local batches = MySQL.query.await(
        'SELECT * FROM imperial_drug_batches WHERE lab_id = ?', { labRow.id })
    local now = os.time()
    local out = {}
    for _, b in ipairs(batches or {}) do
        out[#out + 1] = {
            id = b.id, stage = b.stage, product = b.product, quality = b.quality,
            ready = now >= b.stage_ready_at,
            secondsRemaining = math.max(0, b.stage_ready_at - now),
            stageLabel = ImperialDrugs.stages[b.stage] and ImperialDrugs.stages[b.stage].label or 'Packaging',
        }
    end
    return { contamination = labRow.contamination, batches = out, tier = labRow.tier }
end)

-- ── advance a batch to the next stage (or collect if final) ─────────────
lib.callback.register('imperial_drugs:advanceBatch', function(src, batchId)
    if not exports.imperial_logging:RateLimit(src, 'drugs:advance', 6, 10000) then return false end
    local batch = MySQL.single.await('SELECT * FROM imperial_drug_batches WHERE id = ?', { batchId })
    if not batch then return false end

    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap then return false end

    local labRow = nil
    for _, row in pairs(labRows) do
        if row.id == batch.lab_id then labRow = row break end
    end
    if not labRow then return false end
    local lab = LABS[labRow.lab_key]
    if not exports.imperial_logging:ValidateDistance(src, lab.coords, ImperialDrugs.accessDistance + 2.0) then
        return false, 'toofar'
    end
    if not hasAccess(src, lab, snap) then return false, 'noaccess' end

    local now = os.time()
    if now < batch.stage_ready_at then return false, 'notready' end

    -- stage 5 = product ready to collect
    if batch.stage >= 5 then
        local productCfg = ImperialDrugs.products[batch.product]
        if not productCfg then return false end
        if not exports.ox_inventory:CanCarryItem(src, productCfg.output, productCfg.outputPerBatch) then
            return false, 'capacity'
        end
        exports.ox_inventory:AddItem(src, productCfg.output, productCfg.outputPerBatch, { quality = batch.quality })
        MySQL.query('DELETE FROM imperial_drug_batches WHERE id = ?', { batchId })
        exports.imperial_logging:Log({
            resource = 'imperial_drugs', category = 'gameplay', action = 'batch_collected',
            source = src, data = { batchId = batchId, product = batch.product, quality = batch.quality },
        })
        return true, { done = true }
    end

    local nextStage = batch.stage + 1
    local stageCfg = ImperialDrugs.stages[nextStage]
    if not stageCfg then
        -- no more timed stages: mark ready-to-collect
        MySQL.query('UPDATE imperial_drug_batches SET stage = 5 WHERE id = ?', { batchId })
        return true, { done = false, nextStage = 5 }
    end

    for item, need in pairs(stageCfg.ingredients) do
        if exports.ox_inventory:GetItemCount(src, item) < need then
            return false, 'ingredients'
        end
    end
    for item, need in pairs(stageCfg.ingredients) do
        exports.ox_inventory:RemoveItem(src, item, need)
    end

    MySQL.query('UPDATE imperial_drug_batches SET stage = ?, stage_ready_at = ? WHERE id = ?',
        { nextStage, now + stageCfg.durationSec, batchId })

    return true, { done = false, nextStage = nextStage }
end)

-- ── contamination + raid risk (per lab, periodic) ────────────────────────
CreateThread(function()
    while true do
        Wait(ImperialDrugs.raidCheckIntervalSec * 1000)
        for key, row in pairs(labRows) do
            local activeCount = MySQL.scalar.await(
                'SELECT COUNT(*) FROM imperial_drug_batches WHERE lab_id = ?', { row.id }) or 0
            if activeCount > 0 then
                local gain = math.floor(ImperialDrugs.contaminationPerHour
                    * (ImperialDrugs.raidCheckIntervalSec / 3600))
                row.contamination = math.min(100, row.contamination + math.max(1, gain))
                MySQL.query('UPDATE imperial_drug_labs SET contamination = ? WHERE id = ?',
                    { row.contamination, row.id })

                local chance = ImperialDrugs.raidChanceBase
                    + row.contamination * ImperialDrugs.raidChancePerContam
                if math.random() < chance then
                    local lab = LABS[key]
                    exports.imperial_dispatch:CreateDispatchCall({
                        code = '10-72', title = 'Suspicious Chemical Odour',
                        description = 'Anonymous tip about unusual activity',
                        coords = lab.coords, jobs = { 'police' }, priority = 3,
                    })
                    exports.imperial_logging:Log({
                        resource = 'imperial_drugs', category = 'gameplay', action = 'lab_tipoff',
                        data = { lab = key, contamination = row.contamination }, severity = 2,
                    })
                end
            end
        end
    end
end)

-- ── police raid: seize all batches at a lab (evidence-based, not free) ───
lib.callback.register('imperial_drugs:raidSeize', function(src, labKey)
    local snap = exports.imperial_logging:PlayerSnapshot(src)
    if not snap or snap.job ~= 'police' or not snap.onDuty then return false end
    local lab = LABS[labKey]
    if not lab then return false end
    if not exports.imperial_logging:ValidateDistance(src, lab.coords, ImperialDrugs.accessDistance + 2.0) then
        return false
    end

    local labRow = labRows[labKey]
    local seized = MySQL.scalar.await(
        'SELECT COUNT(*) FROM imperial_drug_batches WHERE lab_id = ?', { labRow.id }) or 0
    MySQL.query('DELETE FROM imperial_drug_batches WHERE lab_id = ?', { labRow.id })
    MySQL.query('UPDATE imperial_drug_labs SET contamination = 0 WHERE id = ?', { labRow.id })
    labRow.contamination = 0

    exports.imperial_logging:Log({
        resource = 'imperial_drugs', category = 'admin', action = 'lab_raided',
        source = src, data = { lab = labKey, batchesSeized = seized }, severity = 2,
    })
    return true, seized
end)
