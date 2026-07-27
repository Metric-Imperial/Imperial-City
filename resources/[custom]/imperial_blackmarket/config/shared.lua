ImperialBlackmarket = {
    fence = {
        coords = vec4(1247.9, -3175.4, 5.9, 30.0),
        model = `g_m_y_mexgoon_01`,
        radius = 3.0,
    },

    -- Items the fence will buy, and at what criminal-currency (crim_token) rate.
    -- Contraband only — never framework money directly, to keep laundering
    -- as the sole cash-in path (see below).
    buyRates = {
        diamond_ring = 8, rolex = 10, goldbar = 12, goldchain = 6,
        security_card_01 = 4, security_card_02 = 4,
        trojan_usb = 5, cryptostick = 6, meth = 3, coke_brick = 15,
        weed_brick = 8, scratched_vin = 10,
    },
    maxSellPerTxn = 20,
    rateLimit = { max = 10, windowMs = 10000 },

    -- Laundering fronts: dirty cash -> clean cash over time, at a fee
    -- (imperial:econ:crime:launderFeePct convar, default in economy.cfg).
    launderFronts = {
        { coords = vec4(-42.7, -1751.2, 29.4, 200.0), label = 'LTD Grove Front', maxPerJob = 15000, durationSec = 1800 },
        { coords = vec4(1198.9, -3161.9, 5.9, 90.0), label = 'Docks Front', maxPerJob = 40000, durationSec = 3600 },
    },
    launderMinAmount = 500,
}
