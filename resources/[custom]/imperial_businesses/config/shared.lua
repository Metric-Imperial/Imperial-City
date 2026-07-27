ImperialBusinesses = {
    -- Grade model (applies to every business; wage is per-employee)
    grades = {
        [0] = { label = 'Employee' },
        [1] = { label = 'Senior' },
        [2] = { label = 'Manager' },
        [3] = { label = 'Owner' },
    },

    -- Permission → minimum grade
    permissions = {
        pos = 0,
        stock = 0,
        storage_shared = 0,
        deposit = 0,
        storage_management = 2,
        ledger = 2,
        hire = 2,
        fire = 2,
        setgrade = 2,
        withdraw = 2,
        setwage = 3,
        transfer = 3,
        rename = 3,
    },

    -- Wages: paid to ON-DUTY employees every cycle, from business balance
    wageCycleMinutes = 30,
    maxWage = 1000,

    -- Lease: charged daily (lease_weekly / 7); this many missed days → repossession
    leaseArrearsLimit = 3,

    -- POS
    posMaxCharge = 25000,
    posTaxConvar = 'imperial:econ:business:transactionTaxPct',

    -- Storage sizes
    storage = {
        shared = { slots = 50, weight = 200000 },
        management = { slots = 30, weight = 100000 },
        personal = { slots = 15, weight = 50000 },
        ingredients = { slots = 40, weight = 300000 },
    },

    maxWithdraw = 100000, -- absolute per-transaction cap, on top of balance checks
}
