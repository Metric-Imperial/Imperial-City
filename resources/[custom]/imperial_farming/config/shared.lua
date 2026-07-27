ImperialFarming = {
    -- Where planting is allowed (circle zones; server re-validates every action)
    zones = {
        { id = 'grapeseed_fields', label = 'Grapeseed Fields', coords = vec3(2032.0, 4988.0, 41.0), radius = 120.0, blip = { sprite = 569, colour = 2 } },
        { id = 'paleto_farm', label = 'Paleto Farmland', coords = vec3(-183.0, 6272.0, 31.0), radius = 90.0, blip = { sprite = 569, colour = 2 } },
        { id = 'elysian_allotments', label = 'Elysian Allotments', coords = vec3(230.0, -2570.0, 5.0), radius = 45.0 },
    },

    -- Per-player live plant cap and minimum spacing between plants
    maxPlantsPerPlayer = 10,
    minSpacing = 1.5,

    -- Watering
    waterIntervalMinutes = 45,   -- needs water this often while growing
    missedWaterHealthLoss = 25,  -- health lost per missed interval (0-100)

    -- Theft
    allowTheft = true,
    theftYieldMultiplier = 0.5,
    theftDispatchChance = 0.35,

    -- Client prop sync
    syncRadius = 80.0,
    syncIntervalMs = 20000,

    -- Growth stage props (index 1 = seedling … 4 = mature)
    stageProps = {
        `prop_plant_fern_02a`,
        `prop_plant_cane_01a`,
        `prop_plant_cane_02a`,
        `prop_plant_cane_02b`,
    },

    crops = {
        wheat      = { seed = 'seed_wheat',     produce = 'wheat',        growthMinutes = 40,  yield = { 3, 6 }, seedReturnChance = 0.35 },
        corn       = { seed = 'seed_corn',      produce = 'corn',         growthMinutes = 45,  yield = { 3, 6 }, seedReturnChance = 0.35 },
        tomato     = { seed = 'seed_tomato',    produce = 'tomato',       growthMinutes = 35,  yield = { 4, 7 }, seedReturnChance = 0.3 },
        potato     = { seed = 'seed_potato',    produce = 'potato',       growthMinutes = 50,  yield = { 4, 8 }, seedReturnChance = 0.4 },
        lettuce    = { seed = 'seed_lettuce',   produce = 'lettuce',      growthMinutes = 30,  yield = { 3, 5 }, seedReturnChance = 0.3 },
        orange     = { seed = 'seed_orange',    produce = 'orange',       growthMinutes = 90,  yield = { 8, 14 }, seedReturnChance = 0.1 },
        apple      = { seed = 'seed_apple',     produce = 'apple',        growthMinutes = 90,  yield = { 8, 14 }, seedReturnChance = 0.1 },
        coffee     = { seed = 'seed_coffee',    produce = 'coffee_beans', growthMinutes = 75,  yield = { 4, 8 }, seedReturnChance = 0.2 },
        sugarcane  = { seed = 'seed_sugarcane', produce = 'sugarcane',    growthMinutes = 60,  yield = { 4, 8 }, seedReturnChance = 0.25 },
        herbs      = { seed = 'seed_herbs',     produce = 'herbs',        growthMinutes = 25,  yield = { 2, 5 }, seedReturnChance = 0.3 },
        cotton     = { seed = 'seed_cotton',    produce = 'cotton',       growthMinutes = 55,  yield = { 4, 7 }, seedReturnChance = 0.3 },
        grape      = { seed = 'grape',          produce = 'grape',        growthMinutes = 60,  yield = { 5, 9 }, seedReturnChance = 0.35 },
    },

    -- Wholesale buyer (sells produce_box for cash; price from economy convar
    -- imperial:econ:pay:produce_box, default below)
    wholesaler = {
        coords = vec4(2001.9, 4994.2, 41.1, 130.0),
        model = `s_m_m_farmer_01`,
        defaultBoxPrice = 180,
    },
}
