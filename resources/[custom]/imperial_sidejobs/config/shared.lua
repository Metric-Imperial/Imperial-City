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

        -- Rod held for both the cast and the wait. Same bone and same tuning
        -- story as the pickaxe: bone 28422 = IK_R_Hand, edit pos/rot here and
        -- restart the resource. rot is (pitch, roll, yaw) in degrees.
        -- Starting at zero deliberately: the pickaxe's numbers do not carry over
        -- to a different model's origin, so this wants one look in-game and a
        -- nudge, exactly as the axe did.
        rodProp = { model = `prop_fishing_rod_01`, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },

        -- The cast, played once before the wait. GTA V ships no dedicated
        -- fishing-cast clip, so this is a tennis forehand -- the same
        -- substitution every fishing script ends up making, because it reads as
        -- a rod being swung out over the water and nothing else in the game does.
        -- Swap dict/clip here if a better one turns up; /prop in
        -- imperial_propcheck is the quickest way to eyeball a candidate.
        castAnim = { dict = 'mini@tennis', clip = 'forehand_ts_md_far' },
        castDurationMs = 1400,

        -- The wait: rod out, line in the water, until the skill check resolves.
        anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' },
        catchTable = {           -- server-side weighted results
            { item = 'fish', count = { 1, 2 }, weight = 70 },
            { item = 'fish', count = { 2, 3 }, weight = 20 },
            { item = nil, weight = 10 },  -- got away
        },
        skillCheck = { 'easy', 'medium' },
        -- Number row, matching mining and lumber. The default WASD prompts fight
        -- the movement keys and read as letters mid-animation.
        skillCheckKeys = { '1', '2', '3', '4' },
        blip = { sprite = 68, colour = 3 },
    },

    -- ── Mine access (teleport through the rock face) ────────────────────
    -- The entrance and exit targets are only 0.93m apart, being two sides of
    -- the same wall. Rather than move them, each is gated on whether the player
    -- is currently inside: you only ever see the one that applies. State is
    -- client-side because it is presentation only -- nothing is rewarded for
    -- being inside, so there is nothing to cheat.
    mineAccess = {
        {
            label = 'Iron Mine',
            enter = {
                target = vec3(-596.06, 2089.02, 131.41),
                spawn  = vec4(-595.57, 2086.11, 131.41, 191.64),
            },
            exit = {
                target = vec3(-595.95, 2088.10, 131.35),
                spawn  = vec4(-596.26, 2089.42, 131.41, 5.67),
            },
            radius = 1.0,   -- small: the two targets are less than a metre apart
        },
    },

    -- ── Mining ──────────────────────────────────────────────────────────
    mining = {
        -- Tool held during the swing, and the animation played.
        -- bone 28422 = IK_R_Hand. Tweak pos/rot here and restart the resource;
        -- no code change needed. rot is (pitch, roll, yaw) in degrees.
        toolProp = { model = `prop_tool_pickaxe`, pos = vec3(0.0, -0.03, -0.02), rot = vec3(-80.0, 0.0, 0.0) },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },

        -- The swing is a skill check rather than a fixed 7s timer, so a strike
        -- can actually be fluffed. One difficulty is picked at random per swing.
        skillCheck = { 'easy', 'easy', 'medium' },
        -- Number row rather than WASD: the movement keys are held down during
        -- the swing, so reusing them made the check fight the character.
        skillCheckKeys = { '1', '2', '3', '4' },

        nodeRespawnSec = 60,
        pickWearPercent = 3,

        -- Shared blip style, used only by ores that opt in below. Sprite 618 /
        -- colour 21 are the pair already proven on the quarry.
        blip = { sprite = 618, colour = 21 },

        -- One entry per ore. Each has its own boulder, its own sites and its own
        -- guaranteed yield -- mining a coal seam gives coal, never a random roll
        -- off a table shared with every other rock.
        --
        -- Capture coordinates by standing on the spot and running /nodehere,
        -- which prints the exact vec3 and copies it to the clipboard. Guessing
        -- them does not work: nodes configured below the terrain cost several
        -- rounds of debugging that looked like collision faults.
        --
        -- `blips` is a list, so an ore spread over more than one location gets a
        -- marker at each. All five are deliberately empty: mining sites are
        -- meant to be found, not handed over on the map. The coordinate that
        -- would centre each blip is kept in a comment so they can be switched
        -- back on one line at a time.
        ores = {
            stone = {
                label = 'Stone Outcrop',
                -- Stock, and the very mesh the three custom boulders were built
                -- from -- so plain stone shares their silhouette and only the
                -- colour tells the ores apart.
                prop = `prop_rock_3_d`,
                item = 'stone', count = { 2, 4 },
                blips = {},  -- vec3(1650.6, -21.7, 133.4)
                nodes = {
                    vec3(1652.95, -25.72, 132.80),
                    vec3(1655.20, -16.93, 133.54),
                    vec3(1649.86, -24.90, 131.98),
                    vec3(1644.59, -19.47, 135.23),
                },
            },
            coal = {
                label = 'Coal Seam',
                prop = `prop_boulder_coal`,  -- imperial_assets
                item = 'coal', count = { 2, 3 },
                blips = {},  -- vec3(2996.6, 2779.2, 42.6)
                nodes = {
                    vec3(2987.58, 2811.27, 43.88),
                    vec3(2991.54, 2805.18, 43.23),
                    vec3(2996.04, 2800.11, 42.85),
                    vec3(3005.52, 2779.25, 42.47),
                    vec3(3005.04, 2772.39, 42.01),
                    vec3(3003.63, 2760.87, 42.12),
                    vec3(3001.94, 2758.09, 42.32),
                    vec3(2992.08, 2750.68, 42.69),
                    vec3(2991.30, 2773.17, 41.94),
                    vec3(2991.46, 2781.22, 42.60),
                },
            },
            copper = {
                label = 'Copper Deposit',
                prop = `prop_rock_2_f`,      -- stock: naturally reddish rock
                item = 'copper_ore', count = { 1, 2 },
                blips = {},  -- vec3(-1021.0, 2889.1, 5.1)
                nodes = {
                    vec3(-1022.99, 2885.20, 5.42),
                    vec3(-1017.79, 2884.75, 4.75),
                    vec3(-1022.99, 2890.59, 5.25),
                    vec3(-1020.05, 2895.95, 4.84),
                },
            },
            iron = {
                label = 'Iron Deposit',
                prop = `prop_boulder_iron`,  -- imperial_assets
                item = 'iron_ore', count = { 1, 2 },
                blips = {},  -- vec3(-597.9, 2093.5, 130.3)
                nodes = {
                    vec3(-607.78, 2091.41, 128.86),
                    vec3(-593.19, 2096.31, 130.54),
                    vec3(-599.52, 2091.06, 130.50),
                    vec3(-590.98, 2095.23, 131.10),
                    vec3(-594.51, 2078.39, 130.44),
                    vec3(-590.30, 2072.81, 130.29),
                    vec3(-591.28, 2065.47, 130.13),
                    vec3(-588.09, 2061.84, 129.83),
                    -- Duplicates spawn two boulders inside each other and two
                    -- overlapping target zones: mine one and an identical rock
                    -- is still standing there. This coordinate appeared twice.
                    vec3(-589.55, 2054.24, 129.35),
                },
            },
            gem = {
                label = 'Gem Vein',
                prop = `prop_boulder_gem`,   -- imperial_assets
                item = 'uncut_gem', count = { 1, 1 },
                blips = {},  -- vec3(-1541.0, 2177.3, 48.4)
                nodes = {
                    vec3(-1547.80, 2169.95, 49.30),
                    vec3(-1544.03, 2172.81, 48.76),
                    vec3(-1538.81, 2180.59, 48.02),
                    vec3(-1533.23, 2185.87, 47.59),
                },
            },
        },
    },

    -- ── Smelting ────────────────────────────────────────────────────────
    -- Turns raw ore into refined metal. This is the step that gives iron_ore
    -- and copper_ore a purpose -- mining nodes drop raw ore precisely so that
    -- refining is a real stage rather than a cosmetic one.
    smelting = {
        prop = `imperial_smelter`,   -- imperial_assets, built by _work/smelter

        -- Capture with /sitehere while standing where the smelter should sit,
        -- facing it the way you want it to end up. The prop origin is at its
        -- base, so foot position is right, and the heading is used verbatim --
        -- no 180-degree correction, which only turned props back to front.
        --
        -- Ground is rarely dead flat, so nudging z by a few centimetres after
        -- looking at it is normal and expected.
        -- `maxPerBatch` may be set per site; it falls back to defaultMaxPerBatch.
        sites = {
            -- Copper site (captured heading 319.0)
            { coords = vec3(-1019.25, 2901.78, 5.14), heading = 319.0 },
            -- Iron site (captured heading 246.7)
            { coords = vec3(-593.99, 2091.59, 130.54), heading = 246.7 },
        },

        -- Chimney smoke. NOT part of the model: baking smoke into geometry
        -- looks wrong from every angle but one, and a looped particle effect
        -- only runs while somebody is nearby.
        --
        -- Offset is from the prop origin (base centre) to the chimney mouth:
        -- the stack sits at x=-0.10, y=+0.24 and tops out at z=1.43.
        --
        -- Effect names are NOT guessable and a wrong one fails silently --
        -- /smoke in imperial_propcheck cycles candidates in-game. This pair is
        -- confirmed working.
        smoke = {
            dict = 'core',
            effect = 'ent_amb_smoke_general',
            offset = vec3(-0.10, 0.24, 1.45),
            scale = 0.6,
            renderDistance = 40.0,
        },

        -- Ore in, metal out. Fuel is consumed per unit, which is what gives coal
        -- a second use beyond selling it raw.
        --
        -- Smelting is a BATCH: you choose how many ingots to run, load the
        -- furnace, and come back. Time scales with the batch, so a big load is
        -- genuinely set-and-forget rather than a long progress bar you have to
        -- stand and watch.
        --
        -- Batch size is left generous and the risk sits with the player: ore and
        -- coal are committed the moment the furnace is loaded, and the wait
        -- scales with the load, so a 50-unit batch is a real decision rather
        -- than a free win. Per-site `maxPerBatch` overrides this.
        --
        -- Player-crafted smelters will differ from these by consuming durability
        -- per unit, not by being larger.
        defaultMaxPerBatch = 50,
        smeltTimeSecPerUnit = 90,
        fuel = { item = 'coal', perUnit = 1 },

        -- count/yield are PER UNIT. A batch of 3 iron runs this three times:
        -- 6 iron_ore and 3 coal in, 3 iron out, 270 seconds.
        recipes = {
            { input = 'iron_ore',   count = 2, output = 'iron',   yield = 1 },
            { input = 'copper_ore', count = 2, output = 'copper', yield = 1 },
        },
    },

    -- ── Lumber ──────────────────────────────────────────────────────────
    lumber = {
        -- nil because the logging camp has real trees at these coords; setting
        -- a prop here would stack one on top of the existing geometry. Set a
        -- model (e.g. `prop_tree_pine_02`) if the trees don't line up.
        nodeProp = nil,
        trees = {
            vec3(-632.44, 5466.54, 52.46),
            vec3(-629.14, 5470.35, 52.77),
            vec3(-626.03, 5472.18, 52.47),
            vec3(-620.09, 5488.43, 50.58),
            vec3(-591.03, 5494.60, 53.03),
            vec3(-585.51, 5491.02, 54.39),
            vec3(-573.01, 5507.90, 54.66),
            vec3(-575.95, 5526.30, 51.99),
            vec3(-586.00, 5541.64, 50.00),
            vec3(-585.36, 5544.18, 49.93),
        },
        -- The axe sits differently in the hand to the pickaxe: v_ind_cs_axe has
        -- its own origin and orientation, so the pickaxe's rotation does not
        -- carry over. Tune here and restart -- no code change needed.
        toolProp = { model = `v_ind_cs_axe`, pos = vec3(0.02, -0.02, -0.03), rot = vec3(-100.0, 180.0, 0.0) },

        -- Felling a trunk is a horizontal swing, not a downward one.
        -- ground_attack_on_spot is a strike at the FLOOR, which is why the
        -- character doubles over at the tree. Hammering is a repeated
        -- shoulder-height strike and reads far better for chopping.
        -- Swap back to the melee dict if you prefer a heavier single swing.
        anim = { dict = 'amb@world_human_hammering@male@base', clip = 'base' },

        -- Felling is a skill check like mining, but a touch easier: a tree is a
        -- bigger target than a seam of ore.
        skillCheck = { 'easy', 'easy' },
        skillCheckKeys = { '1', '2', '3', '4' },

        treeRespawnSec = 90,
        axeWearPercent = 3,
        logsPerTree = { 2, 4 },
        blip = { coords = vec3(-565.0, 5258.0, 71.0), sprite = 285, colour = 25, label = 'Logging Camp' },
    },

    -- Construction and secure transport used to live here. Both were dropped:
    -- neither produced anything the crafting chain could use -- unlike fish,
    -- ore and logs -- and city hall already covers wage work. Removed rather
    -- than commented out; the git history has them if they are ever wanted back.

    -- ── Jeweller (uncut_gem → cut stones, over real time) ───────────────
    -- Cutting is NOT instant. You hand rough stones over and come back later,
    -- which is why the order lives in the database rather than in memory: it has
    -- to survive the player logging out and the server restarting.
    --
    -- Coords are the Vangelico store on Portola Drive.
    jeweller = {
        model = `a_m_m_business_01`,
        coords = vec4(-622.05, -230.72, 38.06, 127.7),

        input = 'uncut_gem',
        -- A table, so more stones can be added when there is art for them --
        -- emerald_gem is simply the one that has an icon today.
        outputs = {
            { item = 'emerald_gem', weight = 100 },
        },

        maxPerOrder = 10,
        feePerGem = 75,          -- charged up front, per stone
        cutTimeSecPerGem = 300,  -- 5 min each; 10 stones is a ~50 min wait
    },

    -- ── Materials buyer (fish/ore/logs → cash, convar-priced) ───────────
    buyer = {
        coords = vec4(169.2, -1633.3, 29.3, 50.0),
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
