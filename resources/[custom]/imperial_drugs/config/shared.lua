-- Fictional gameplay abstraction only. No real-world production detail:
-- stages are gather -> process -> refine -> package -> distribute, using
-- generic placeholder materials. Output items are the existing catalogue
-- items already used by qbx_drugs' selling loop (this is a production front
-- end for that loop, not a competing item set).
ImperialDrugs = {
    labs = {
        {
            key = 'lab_sandy_shed',
            label = 'Sandy Shore Shed',
            coords = vec3(1985.4, 3771.9, 32.2),
            heading = 210.0,
            tier = 1,
            product = 'meth',
            accessItem = 'lab_keycard',
            hidden = true,
        },
        {
            key = 'lab_paleto_barn',
            label = 'Paleto Barn',
            coords = vec3(-138.9, 6357.2, 31.6),
            heading = 45.0,
            tier = 2,
            product = 'coke',
            accessItem = 'lab_keycard',
            hidden = true,
        },
    },

    products = {
        meth = { label = 'Methamphetamine', output = 'meth', outputPerBatch = 5 },
        coke = { label = 'Cocaine', output = 'coke_brick', outputPerBatch = 2 },
    },

    -- Per-stage requirements and durations (seconds). Stage 1 consumes
    -- ingredients immediately (server removes on start); later stages are
    -- time-only (the batch "cooks") to keep the loop server-driven and
    -- restart-safe (durations are wall-clock, derived like imperial_farming).
    stages = {
        { id = 1, label = 'Gather Materials', durationSec = 5,
          ingredients = { raw_material_a = 4, raw_material_b = 2 } },
        { id = 2, label = 'Process Materials', durationSec = 180,
          ingredients = { chem_supplies = 2 } },
        { id = 3, label = 'Refine Product', durationSec = 240, ingredients = {} },
        { id = 4, label = 'Package Product', durationSec = 90,
          ingredients = { packaging_materials = 2 } },
    },

    -- Access
    maxActiveBatchesPerLab = 2,
    accessDistance = 3.0,

    -- Contamination / raid risk: each active-lab hour increases contamination;
    -- higher contamination increases the chance a dispatch call fires.
    contaminationPerHour = 4,
    raidCheckIntervalSec = 300,
    raidChanceBase = 0.05,          -- at 0 contamination
    raidChancePerContam = 0.006,    -- additional chance per contamination point

    -- Quality: derived from lab tier and whether contamination was high when
    -- the batch finished. Quality affects street sale price (qbx_drugs side).
    qualityBaseByTier = { [1] = 40, [2] = 60, [3] = 80 },
    qualityContaminationPenalty = 0.5, -- per contamination point at completion
}
