# imperial_dispatch

Unified dispatch for police, EMS and fire with one documented export any
resource can call to raise an alert — no per-department dispatch scripts.

## API

```lua
exports.imperial_dispatch:CreateDispatchCall({
    code = '10-31',            -- optional
    title = 'Store Robbery',
    description = 'Silent alarm triggered',
    coords = vector3(x, y, z),
    jobs = { 'police' },       -- one or more of: police, ambulance, fire
    priority = 3,              -- 1-5, default 3
    blip = true,                -- default true
    duration = 90000,           -- ms, default config.defaultDurationMs
    metadata = { ... },         -- optional, persisted with the call row
})
-- returns callId (number) or nil if rejected/rate-limited
```

Calls are routed only to on-duty players of the listed jobs (duty state is
tracked from `QBCore:Server:SetDuty` plus a 30 s safety poll), persisted to
`imperial_dispatch_calls` for MDT linking, and rate-limited per calling
resource (20 calls / 10 s) so a bug elsewhere cannot flood dispatch.

`exports.imperial_dispatch:GetRecentCalls(job, limit)` — used by imperial_mdt
to link reports to the call that generated them.

## Panic button
`/panic` (client) reads the player's own job from `qbx_core:GetPlayerData()`
and asks the server to raise a priority-5 alert. The server re-validates the
player is actually that job and on duty before creating the call — a client
cannot claim an arbitrary department.

## Consumers
qbx robbery resources, imperial_farming (crop theft), imperial_crafting
(criminal bench noise), imperial_boosting, imperial_blackmarket, and
imperial_fire all call `CreateDispatchCall` directly; none re-implement alert
routing.

## Test checklist
- [ ] Alert reaches only on-duty players of the listed job(s).
- [ ] Off-duty toggle removes a player from routing within one duty event.
- [ ] `/panic` from a non-matching job is rejected and logged.
- [ ] Flooding `CreateDispatchCall` from one resource is rate-limited.
- [ ] Call history is queryable by `GetRecentCalls` for MDT linking.
