ImperialSideJobs = {
    -- ── Fishing ─────────────────────────────────────────────────────────
    fishing = {
        spots = {
            { coords = vec3(-1850.5, -1248.5, 8.6), radius = 40.0, label = 'Del Perro Pier' },
            { coords = vec3(1301.0, 4216.5, 33.9), radius = 50.0, label = 'Alamo Sea' },
            { coords = vec3(3857.5, 4459.5, 0.8), radius = 80.0, label = 'Open Water' },
        },
        castCooldownMs = 8000,
        baitPerCast = 1,
        rodWearPercent = 2,
        catchTable = {           -- server-side weighted results
            { item = 'fish', count = { 1, 2 }, weight = 70 },
            { item = 'fish', count = { 2, 3 }, weight = 20 },
            { item = nil, weight = 10 },  -- got away
        },
        skillCheck = { 'easy', 'medium' },
        blip = { sprite = 68, colour = 3 },
    },

    -- ── Mining ──────────────────────────────────────────────────────────
    mining = {
        -- Marker prop placed at every node so they are actually findable --
        -- without one the target sphere sits on bare terrain and is invisible
        -- unless you already know the coordinates. Set to nil for no prop.
        --
        -- Custom asset from imperial_assets/stream/. One prop for every node
        -- until the ore-specific restructure, which will give each ore its own
        -- boulder and its own sites. The full set is already streamed:
        -- prop_boulder_stone / _coal / _copper / _iron / _gem.
        nodeProp = `prop_boulder_coal`,
        nodes = {
            vec3(2962.74, 2802.94, 40.60),           
            vec3(2946.45, 2810.49, 40.79),
            vec3(2953.64, 2795.85, 39.93),
            vec3(2971.36, 2788.50, 38.77),
        },
        nodeRespawnSec = 120,
        pickWearPercent = 3,
        oreTable = {
            { item = 'stone', count = { 2, 4 }, weight = 40 },
            { item = 'coal', count = { 1, 3 }, weight = 25 },
            { item = 'iron', count = { 1, 2 }, weight = 18 },
            { item = 'copper', count = { 1, 2 }, weight = 12 },
            { item = 'uncut_gem', count = { 1, 1 }, weight = 5 },
        },
        blip = { coords = vec3(2958.0, 2798.0, 41.0), sprite = 618, colour = 21, label = 'Quarry' },
    },

    -- ── Lumber ──────────────────────────────────────────────────────────
    lumber = {
        -- nil because the logging camp has real trees at these coords; setting
        -- a prop here would stack one on top of the existing geometry. Set a
        -- model (e.g. `prop_tree_pine_02`) if the trees don't line up.
        nodeProp = nil,
        trees = {
            vec3(-560.4, 5252.1, 70.5),
            vec3(-548.9, 5262.7, 72.1),
            vec3(-570.8, 5271.3, 73.9),
            vec3(-582.2, 5244.6, 68.8),
        },
        treeRespawnSec = 90,
        axeWearPercent = 3,
        logsPerTree = { 2, 4 },
        blip = { coords = vec3(-565.0, 5258.0, 71.0), sprite = 285, colour = 25, label = 'Logging Camp' },
    },

    -- ── Construction ────────────────────────────────────────────────────
    construction = {
        site = { coords = vec3(-141.5, -947.5, 29.4), radius = 60.0, label = 'City Construction Site' },
        pickup = vec3(-127.9, -964.7, 29.4),
        dropoffs = {
            vec3(-158.6, -939.6, 29.4),
            vec3(-146.2, -925.0, 29.4),
            vec3(-170.9, -955.3, 29.4),
        },
        carryProp = `prop_cementbags01`,
        tasksPerShift = 10,
        blip = { sprite = 566, colour = 47 },
    },

    -- ── Secure transport (Gruppe 6-style) ───────────────────────────────
    securetransport = {
        depot = vec4(11.9, -1060.4, 29.8, 340.0),
        vehicleModel = `stockade`,
        stops = {
            vec3(-56.5, -1752.3, 29.4),   -- convenience store
            vec3(147.4, -1035.8, 29.3),   -- fleeca legion
            vec3(-1211.7, -336.5, 37.8),  -- fleeca vinewood
            vec3(-2957.5, 481.9, 15.7),   -- banham
            vec3(1175.0, 2711.5, 38.1),   -- route 68
        },
        stopsPerRun = 3,
        casePickupMs = 6000,
        minPoliceForRobbery = 2, -- robbing the case handled by criminal suite hooks
        blip = { sprite = 477, colour = 5 },
    },

    -- ── Materials buyer (fish/ore/logs → cash, convar-priced) ───────────
    buyer = {
        coords = vec4(169.2, -1633.3, 29.3, 230.0),
        model = `s_m_m_dockwork_01`,
        prices = {           -- convar override: imperial:econ:pay:<key>
            fish = { convar = 'imperial:econ:pay:fishing_fish', default = 24 },
            stone = { convar = 'imperial:econ:pay:mining_stone', default = 8 },
            coal = { convar = 'imperial:econ:pay:mining_coal', default = 12 },
            iron = { convar = 'imperial:econ:pay:mining_ore', default = 18 },
            copper = { convar = 'imperial:econ:pay:mining_ore', default = 18 },
            log = { convar = 'imperial:econ:pay:lumber_log', default = 16 },
            plank = { convar = 'imperial:econ:pay:lumber_plank', default = 28 },
        },
        maxPerSale = 100,
    },
}
