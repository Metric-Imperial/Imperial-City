-- Bench definitions. `restrict` is optional:
--   job = { ['police'] = 0 }         minimum grade per job
--   gang = { ['*'] = 1 }             any gang, min rank (dynamic gangs via imperial_gangs)
--   item = 'lab_keycard'             required item in inventory
--   hidden = true                    no blip, no default target text
-- `categories` limits which recipe categories this bench offers.
ImperialCraftingBenches = {
    -- Public benches
    {
        id = 'public_workbench_paleto',
        label = 'Community Workbench',
        coords = vec3(-378.35, 6120.25, 31.48),
        heading = 45.0,
        prop = `prop_toolchest_05`,
        categories = { 'tools', 'repair', 'camping' },
        blip = { sprite = 566, colour = 5, scale = 0.7 },
    },
    {
        id = 'public_workbench_city',
        label = 'Community Workbench',
        coords = vec3(717.81, -962.31, 30.4),
        heading = 90.0,
        prop = `prop_toolchest_05`,
        categories = { 'tools', 'repair', 'camping' },
        blip = { sprite = 566, colour = 5, scale = 0.7 },
    },

    -- Job benches
    {
        id = 'mechanic_bench',
        label = 'Mechanic Fabrication Bench',
        coords = vec3(-347.31, -133.5, 39.01),
        heading = 250.0,
        prop = `prop_tool_bench02`,
        categories = { 'mechanical', 'repair' },
        restrict = { job = { mechanic = 0 } },
    },
    {
        id = 'ems_supply_bench',
        label = 'Medical Supply Station',
        coords = vec3(306.15, -601.13, 43.28),
        heading = 70.0,
        categories = { 'medical' },
        restrict = { job = { ambulance = 0 } },
    },

    -- Farming processing stations (owned by the farming loop)
    {
        id = 'grain_mill',
        label = 'Grain Mill',
        coords = vec3(2029.11, 4979.35, 41.35),
        heading = 130.0,
        categories = { 'processing' },
        blip = { sprite = 569, colour = 25, scale = 0.7 },
    },
    {
        id = 'sawmill',
        label = 'Sawmill Bench',
        coords = vec3(-553.0, 5250.5, 70.2),
        heading = 0.0,
        prop = `prop_tool_bench02`,
        categories = { 'processing' },
        blip = { sprite = 566, colour = 25, scale = 0.7 },
    },
    {
        id = 'produce_packing',
        label = 'Produce Packing Table',
        coords = vec3(2027.6, 4973.4, 41.2),
        heading = 130.0,
        categories = { 'packing' },
    },

    -- Criminal benches (hidden; gated)
    {
        id = 'crim_bench_docks',
        label = 'Improvised Bench',
        coords = vec3(1088.9, -3101.5, -39.0),
        heading = 0.0,
        categories = { 'criminal_tools' },
        restrict = { hidden = true, minLevel = { category = 'criminal_tools', level = 0 } },
        dispatchChance = 0.15, -- chance a craft pings imperial_dispatch
    },
    {
        id = 'crim_bench_weapons',
        label = 'Armourer Bench',
        coords = vec3(997.2, -3200.6, -36.4),
        heading = 180.0,
        categories = { 'criminal_weapons' },
        restrict = { hidden = true, gang = { ['*'] = 1 }, item = 'lab_keycard' },
        dispatchChance = 0.25,
    },
}
