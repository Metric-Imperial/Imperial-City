# 12 — Dispatch & MDT Integration Guide

## Raising an alert from any resource
```lua
local callId = exports.imperial_dispatch:CreateDispatchCall({
    title = 'Store Robbery',
    description = 'Silent alarm triggered',
    coords = coords,           -- vector3
    jobs = { 'police' },       -- police | ambulance | fire (one or more)
    priority = 3,               -- 1 (low) .. 5 (critical)
    code = '10-31',              -- optional, shown in the alert title
    duration = 90000,            -- optional, ms
    metadata = { ... },          -- optional, stored with the call row
})
```
Returns a `callId` (or `nil` if invalid/rate-limited) usable to link an
`imperial_mdt` report to the call that generated it.

## Who receives it
Only players currently on duty in one of the listed jobs. Duty state is
tracked from `QBCore:Server:SetDuty` with a 30 s safety poll, so there is
never more than a brief window where a just-went-off-duty player still
receives an alert.

## MDT linkage
`imperial_mdt:getRecentCalls` (client → server callback) returns the last 25
calls for the caller's department via `imperial_dispatch:GetRecentCalls`,
letting an officer/medic/firefighter attach a report to the call that
generated it (`dispatch_call_id` foreign key in `imperial_mdt_reports`).

## Existing qbx criminal-suite alerts
The first-party `qbx_storerobbery`/`qbx_bankrobbery`/etc. resources ship
their own dispatch hooks aimed at `qb-core`-era dispatch conventions. Operators
should point their `Config.Dispatch` (or equivalent) callback at
`exports.imperial_dispatch:CreateDispatchCall` rather than installing a
second dispatch system — this is a one-line config change per resource,
documented per-resource in their own READMEs on first boot.
