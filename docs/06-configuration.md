# 06 — Configuration Guide

Post-install configuration lives in three places: recipe-shipped cfg files
(`server.cfg`, `ox.cfg`, `economy.cfg`, `voice.cfg`, `permissions.cfg`,
`misc.cfg`), per-resource `config/` files, and convars read by the imperial
suite. Never edit framework source; every documented knob is config.

## Character flow (Phase 3 decisions)

* **Multicharacter** — integrated in qbx_core. Slots: qbx_core
  `config/client.lua → characters.slots` (default 4). Name/DOB/nationality
  validation is qbx_core's character-creation UI.
* **Appearance** — illenium-appearance in qbx mode (bridge). First spawn opens
  full creation; clothing shops and outfit saves enabled. Locale via
  `illenium-appearance:locale`.
* **Spawn selection** — qbx_spawn: configure spawn points in its config; the
  "Last Location" entry stays enabled. Broken spawns are rescued by
  imperial_character (validated server-side).
* **Starter package** — money: qbx_core `StartingFunds` (align with
  `imperial:econ:starterCash/Bank` in economy.cfg — see docs/08). Items:
  `imperial_character/config/shared.lua` (duplicate-proof).
* **Starter accommodation** — qbx_properties rentable low-tier apartments;
  weekly rent from `imperial:econ:starterApartmentRentPerWeek`. The
  first-login hook (`imperial_character:server:firstLogin`) can be pointed at a
  realtor intro or automatic starter-lease flow (disabled by default).

## Core player systems

* **Inventory** — ox_inventory is the only inventory. Weights/slots in ox.cfg.
  The item catalogue is `recipes/items.lua`, installed over
  `ox_inventory/data/items.lua` (single source of truth; do not edit the copy
  inside ox_inventory).
* **Banking** — Renewed-Banking: personal/job/gang/shared accounts, transfers,
  history. imperial_businesses and imperial_gangs mirror their ledgers into
  their own tables and treat Renewed-Banking as the player-facing UI. All money
  mutations go through server-side exports with `ValidateAmount`.
* **Phone** — NPWD with `npwd:framework "qbx"` (qbx_npwd config.json is copied
  over NPWD's by the recipe). Garages + mail apps included.
* **Garages** — qbx_garages backed by qbx_vehicles. Public garages, job/gang
  garages (grade-gated) and impound configured in qbx_garages config;
  property garages via qbx_properties.
* **Keys/fuel/damage** — qbx_vehiclekeys, ox_fuel, vehiclehandler.
* **Weather** — Renewed-Weathersync (server-authoritative cycle; snow toggle in
  misc.cfg).
* **Shops** — ox_inventory `data/shops.lua` (default set retained; business POS
  shops come from imperial_businesses, not ox static shops).

## Convar reference (imperial)

| Convar | Default | Purpose |
| ------ | ------- | ------- |
| `imperial:debug` | false | verbose logging in imperial resources |
| `imperial:webhook_audit` | "" | optional Discord mirror for severity ≥ 3 |
| `imperial:currencyLocale` | en-AU | display formatting only |
| `imperial:econ:*` | see economy.cfg | all economy values (server-read only) |
