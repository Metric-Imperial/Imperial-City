-- Imperial City consolidated ox_inventory item catalogue.
-- Base: official Qbox-project/txAdminRecipe items.lua (GPLv3), with one fix:
--   * weed_white-widow label corrected ('OGKush 2g' -> 'White Widow 2g').
-- Imperial additions are grouped at the end under IMPERIAL ITEMS.
-- Image files: ox_inventory/web/images/<name>.png (see docs item-audit notes).

return {
    ['testburger'] = {
        label = 'Test Burger',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Lick it',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Squeeze it',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'What do you call a vegan burger?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'What do frogs like to eat with their hamburgers?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Why were the burger and fries running?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['bandage'] = {
        label = 'Bandage',
        weight = 115,
    },

    ['burger'] = {
        label = 'Burger',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 160,
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['money'] = {
        label = 'Money',
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    ['id_card'] = {
        label = 'Identification Card',
    },

    ['driver_license'] = {
        label = 'Drivers License',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
    },

    ['radio'] = {
        label = 'Radio',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Repair Kit',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'Advanced Repair Kit',
        weight = 4000,
    },

    ['diamond_ring'] = {
        label = 'Diamond',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        weight = 100,
    },

    ['meth'] = {
        label = 'Methamphetamine',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'White Widow 2g',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'First Aid',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Painkillers',
        weight = 400,
    },

    ['firework1'] = {
        label = '2Brothers',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Rubber',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Aluminium',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Toaster',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'Antipatharia',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Dendrogyra',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Lighter',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        weight = 200,
    },

    ['harness'] = {
        label = 'Harness',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        weight = 200,
    },

    -- ════════════════════════════════════════════════════════════════════
    -- IMPERIAL ITEMS
    -- ════════════════════════════════════════════════════════════════════

    -- ── Side jobs: fishing / mining / lumber / construction / secure transport ──
    ['fishing_rod'] = {
        label = 'Fishing Rod',
        weight = 2000,
        stack = false,
        degrade = 180,
        description = 'A sturdy rod for coastal and deep-water fishing',
        client = { export = 'imperial_sidejobs.useRod' },
    },
    ['fishing_bait'] = {
        label = 'Fishing Bait',
        weight = 30,
    },
    ['fish'] = {
        label = 'Fish',
        weight = 500,
        description = 'Fresh catch. Sell to the wholesaler or a restaurant',
        metadata = { type = 'produce' },
    },
    ['pickaxe'] = {
        label = 'Pickaxe',
        weight = 4000,
        stack = false,
        degrade = 240,
    },
    ['stone'] = {
        label = 'Stone',
        weight = 300,
    },
    ['coal'] = {
        label = 'Coal',
        weight = 250,
    },
    ['uncut_gem'] = {
        label = 'Uncut Gem',
        weight = 120,
        description = 'A rough gemstone. A jeweller might be interested',
    },
    ['lumber_axe'] = {
        label = 'Felling Axe',
        weight = 4500,
        stack = false,
        degrade = 240,
    },
    ['log'] = {
        label = 'Timber Log',
        weight = 2500,
    },
    ['plank'] = {
        label = 'Timber Plank',
        weight = 800,
    },
    ['hammer'] = {
        label = 'Hammer',
        weight = 1200,
        stack = false,
    },
    ['security_case'] = {
        label = 'Secure Transport Case',
        weight = 6000,
        stack = false,
        description = 'Sealed courier case. Tampering is logged',
        metadata = { sealed = true },
    },

    -- ── Farming ──
    ['watering_can'] = {
        label = 'Watering Can',
        weight = 2000,
        stack = false,
        degrade = 300,
    },
    ['farming_hoe'] = {
        label = 'Hoe',
        weight = 3000,
        stack = false,
        degrade = 300,
    },
    ['fertiliser'] = {
        label = 'Fertiliser',
        weight = 1500,
        description = 'Improves crop quality and growth speed',
    },
    ['seed_wheat'] = { label = 'Wheat Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['seed_corn'] = { label = 'Corn Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['seed_tomato'] = { label = 'Tomato Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['seed_potato'] = { label = 'Seed Potatoes', weight = 40, client = { export = 'imperial_farming.useSeed' } },
    ['seed_lettuce'] = { label = 'Lettuce Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['seed_orange'] = { label = 'Orange Sapling', weight = 400, stack = false, client = { export = 'imperial_farming.useSeed' } },
    ['seed_apple'] = { label = 'Apple Sapling', weight = 400, stack = false, client = { export = 'imperial_farming.useSeed' } },
    ['seed_coffee'] = { label = 'Coffee Seedling', weight = 200, client = { export = 'imperial_farming.useSeed' } },
    ['seed_sugarcane'] = { label = 'Sugar Cane Cutting', weight = 60, client = { export = 'imperial_farming.useSeed' } },
    ['seed_herbs'] = { label = 'Herb Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['seed_cotton'] = { label = 'Cotton Seeds', weight = 10, client = { export = 'imperial_farming.useSeed' } },
    ['wheat'] = { label = 'Wheat', weight = 120, metadata = { type = 'produce' } },
    ['corn'] = { label = 'Corn', weight = 150, metadata = { type = 'produce' } },
    ['tomato'] = { label = 'Tomato', weight = 90, metadata = { type = 'produce' } },
    ['potato'] = { label = 'Potato', weight = 130, metadata = { type = 'produce' } },
    ['lettuce'] = { label = 'Lettuce', weight = 80, metadata = { type = 'produce' } },
    ['orange'] = { label = 'Orange', weight = 90, metadata = { type = 'produce' } },
    ['apple'] = { label = 'Apple', weight = 95, metadata = { type = 'produce' } },
    ['coffee_beans'] = { label = 'Coffee Beans', weight = 60, metadata = { type = 'produce' } },
    ['sugarcane'] = { label = 'Sugar Cane', weight = 200, metadata = { type = 'produce' } },
    ['herbs'] = { label = 'Fresh Herbs', weight = 40, metadata = { type = 'produce' } },
    ['cotton'] = { label = 'Cotton', weight = 60, metadata = { type = 'produce' } },
    ['flour'] = { label = 'Flour', weight = 400 },
    ['sugar'] = { label = 'Sugar', weight = 350 },
    ['produce_box'] = {
        label = 'Produce Box',
        weight = 2500,
        description = 'Wholesale crate of packed produce',
        metadata = { type = 'wholesale' },
    },

    -- ── General crafting ──
    ['toolkit'] = {
        label = 'Toolkit',
        weight = 3500,
        stack = false,
        degrade = 400,
    },
    ['component_electronics'] = {
        label = 'Electronic Components',
        weight = 150,
    },
    ['component_mechanical'] = {
        label = 'Mechanical Components',
        weight = 250,
    },
    ['blueprint'] = {
        label = 'Blueprint',
        weight = 50,
        stack = false,
        description = 'Unlocks a crafting recipe. Use at a matching bench',
        metadata = { recipe = '' },
        server = { export = 'imperial_crafting.UseBlueprint' },
    },

    -- ── Criminal crafting / tools ──
    ['fake_plate'] = {
        label = 'Fake Number Plate',
        weight = 1200,
        stack = false,
        metadata = { plate = '' },
    },
    ['signal_jammer'] = {
        label = 'Signal Jammer',
        weight = 900,
        stack = false,
        degrade = 120,
        description = 'Suppresses dispatch pings for a short window',
    },
    ['tracker_device'] = {
        label = 'Tracking Device',
        weight = 300,
        stack = false,
    },
    ['hacking_device'] = {
        label = 'Hacking Device',
        weight = 800,
        stack = false,
        degrade = 90,
    },
    ['weapon_parts'] = {
        label = 'Weapon Parts',
        weight = 600,
    },
    ['ammo_components'] = {
        label = 'Ammunition Components',
        weight = 350,
    },
    ['armour_plate'] = {
        label = 'Armour Plate',
        weight = 1800,
    },
    ['rope_restraints'] = {
        label = 'Rope Restraints',
        weight = 400,
        description = 'Improvised restraints. Less secure than handcuffs',
    },
    ['crim_token'] = {
        label = 'Marked Marker',
        weight = 5,
        description = 'Underworld scrip accepted by certain fences',
    },

    -- ── Drug production (abstract gameplay stages) ──
    ['chem_supplies'] = {
        label = 'Chemical Supplies',
        weight = 1000,
        description = 'Unlabelled containers. Best not to ask',
    },
    ['raw_material_a'] = { label = 'Raw Material A', weight = 500 },
    ['raw_material_b'] = { label = 'Raw Material B', weight = 500 },
    ['refined_product'] = {
        label = 'Refined Product',
        weight = 400,
        metadata = { quality = 0, batch = '' },
    },
    ['packaging_materials'] = {
        label = 'Packaging Materials',
        weight = 300,
    },
    ['product_package'] = {
        label = 'Packaged Product',
        weight = 250,
        metadata = { quality = 0, batch = '' },
    },
    ['lab_keycard'] = {
        label = 'Lab Keycard',
        weight = 20,
        stack = false,
        metadata = { lab = '' },
    },

    -- ── Fire & rescue ──
    ['fire_extinguisher_item'] = {
        label = 'Fire Extinguisher',
        weight = 6000,
        stack = false,
        degrade = 60,
        description = 'Handheld extinguisher for small fires',
    },
    ['breathing_apparatus'] = {
        label = 'Breathing Apparatus',
        weight = 8000,
        stack = false,
        degrade = 45,
    },
    ['rescue_tools'] = {
        label = 'Rescue Tools',
        weight = 9000,
        stack = false,
        description = 'Hydraulic cutter/spreader combi tool',
    },
    ['fire_hose_nozzle'] = {
        label = 'Hose Nozzle',
        weight = 2500,
        stack = false,
    },

    -- ── Boosting / black market ──
    ['boost_tablet'] = {
        label = 'Boosting Tablet',
        weight = 900,
        stack = false,
        client = { export = 'imperial_boosting.useTablet' },
        description = 'Encrypted tablet. Contracts appear when you have a reputation',
    },
    ['scratched_vin'] = {
        label = 'Scratched VIN Plate',
        weight = 300,
        metadata = { class = '' },
    },

    -- ── Business / hospitality ──
    ['ingredient_box'] = {
        label = 'Ingredient Box',
        weight = 2000,
        description = 'Bulk ingredients for hospitality businesses',
    },
    ['coffee_cup'] = {
        label = 'Fresh Coffee',
        weight = 250,
        client = {
            status = { thirst = 150000, stress = -10000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            usetime = 2500,
            notification = 'A proper flat white',
        },
    },
    ['meal_box'] = {
        label = 'Prepared Meal',
        weight = 450,
        client = {
            status = { hunger = 250000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 3000,
        },
        metadata = { business = '', quality = 0 },
    },
}
