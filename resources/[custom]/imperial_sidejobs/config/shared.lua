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
        nodes = {
            vec3(2954.1, 2794.5, 41.0),
            vec3(2962.7, 2802.1, 40.6),
            vec3(2970.3, 2787.9, 40.2),
            vec3(2946.9, 2810.4, 41.3),
            vec3(-595.3, 2090.5, 131.4),
            vec3(-588.1, 2096.2, 130.9),
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
