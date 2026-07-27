ImperialGangs = {
    creationFeeConvar = 'imperial:econ:gang:creationFee',
    minFoundingMembers = 3,        -- including the founder
    foundingWindowSec = 90,        -- time nearby players have to join the founding session
    foundingRadius = 15.0,

    ranks = {
        [0] = { label = 'Member' },
        [1] = { label = 'Senior' },
        [2] = { label = 'Officer' },
        [3] = { label = 'Leader' },
    },

    permissions = {
        deposit = 0,
        storage = 0,
        withdraw = 1,
        invite = 1,
        kick = 2,
        setrank = 2,
        rename = 3,
        transfer = 3,
        disband = 3,
    },

    -- Gang key/label validation
    minLabelLen = 3,
    maxLabelLen = 32,
    reservedWords = { 'police', 'ambulance', 'fire', 'admin', 'none', 'unemployed' },

    storage = { slots = 40, weight = 150000 },
    maxWithdraw = 50000,
}
