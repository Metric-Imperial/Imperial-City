ImperialFire = {
    -- Registered automatically at runtime by server/main.lua via
    -- qbx_core:CreateJob if it doesn't already exist -- no manual edit to
    -- qbx_core/shared/jobs.lua needed. Define it there yourself if you want
    -- different grades/pay; imperial_fire will then leave it alone.
    job = 'fire',

    stations = {
        {
            id = 'station_davis',
            label = 'Davis Fire Station',
            duty = vec3(-1600.3, -406.2, 40.1),
            lockerRoom = vec3(-1602.9, -403.8, 40.1),
            equipment = vec3(-1598.5, -409.9, 40.1),
            garage = vec3(-1594.6, -415.3, 40.1),
            blip = { sprite = 436, colour = 17 },
        },
    },

    -- Equipment given from the locker (returned on undress, not consumed)
    equipmentLoadout = {
        'fire_extinguisher_item', 'breathing_apparatus', 'rescue_tools', 'fire_hose_nozzle',
    },

    -- Incident types
    incidentTypes = {
        vehicle_fire = { label = 'Vehicle Fire', extinguishWork = 30, priority = 3, code = '10-70' },
        structure_fire = { label = 'Structure Fire', extinguishWork = 80, priority = 4, code = '10-71' },
        hazmat = { label = 'Hazardous Material Incident', extinguishWork = 60, priority = 4, code = '10-72' },
        rescue = { label = 'Rescue — Person Trapped', extinguishWork = 40, priority = 4, code = '10-73' },
        rtc = { label = 'Road Traffic Collision', extinguishWork = 35, priority = 3, code = '10-74' },
    },

    -- Extinguisher tick: each use reduces remaining work by this much (server clamps)
    extinguishPerTick = 8,
    tickCooldownMs = 1500,

    -- Escalation: if untouched this long, priority increases once (re-dispatch)
    escalateAfterMs = 120000,

    -- Auto-clear an incident that has had zero progress for this long (abandoned)
    abandonAfterMs = 600000,

    salaryConvar = 'imperial:econ:salary:fire_base',
    incidentRewardConvar = 'imperial:econ:pay:fire_incident',
}
