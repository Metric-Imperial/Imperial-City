# imperial_fire

Fire & rescue as a first-class department, not an afterthought: duty stations
with equipment lockers, synced incidents (vehicle fire, structure fire,
hazmat, rescue, RTC), escalation when ignored, abandonment cleanup, and
dispatch integration via `imperial_dispatch`.

## Design notes
- **Server-authoritative incidents.** `CreateIncident(type, coords)` (export)
  creates the canonical incident; `imperial_fire:extinguish` is the only way
  to reduce its remaining work, validated for duty status, tool possession,
  and distance, and rate-limited to one tick per 1.5 s.
- **Visual fire is presentation-only.** FiveM has no networked "fire entity"
  API (`StartScriptFire` is local); every on-duty client renders its own
  extinguisher animation/particle at the server-given coordinates. The
  server's incident record — not the visual — is what "exists".
- **Escalation/abandonment.** An incident untouched for 2 minutes triggers a
  second, higher-priority dispatch call; untouched for 10 minutes it is
  cleared as abandoned (no infinite clutter from missed incidents).
- **Automatic spawner** keeps 0–2 incidents live, spaced 4–8 minutes apart,
  only while at least one unit is on duty (no cost when the department is
  empty).

## Config
`config/shared.lua`: stations, equipment loadout, incident type table
(`extinguishWork`, `priority`, dispatch `code`), tick size/cooldown,
escalate/abandon timers, economy convars.

## Garages
Fire apparatus garages use `qbx_garages` with a job-restricted entry for the
`fire` job (config, not code) — see docs/09-jobs.md for the qbx_core job
definition this resource assumes exists.

## Exports
- `CreateIncident(type, coords) -> id|nil` — for other resources to trigger
  incidents (e.g. a criminal script that sets a vehicle alight).

## Test checklist
- [ ] Non-fire/off-duty players cannot progress or resolve an incident.
- [ ] Extinguishing requires a real extinguisher/hose item in inventory.
- [ ] Escalation fires exactly once per incident; abandonment clears it.
- [ ] A unit coming on duty mid-incident receives the current incident list.
- [ ] Automatic spawner never exceeds 2 concurrent incidents.
