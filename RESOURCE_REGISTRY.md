# Resource Registry

Per-resource metadata for every resource in this recipe. Custom `imperial_*`
resources are documented in full (they're this project's own code); every
third-party resource is documented at reference depth, since the
authoritative source for third-party metadata is that resource's own
repository, not a copy frozen here — see `docs/05-resource-selection.md` for
the full selection methodology and `docs/22-licences-and-attribution.md`
for licence details.

## Custom resources (`resources/[custom]/`)

### imperial_logging
- **Role**: Foundational cross-cutting resource — every other `imperial_*` resource depends on it.
- **Dependencies**: oxmysql, ox_lib
- **Key exports**: `Log`, `LogSuspicious`, `RateLimit`, `AcquireLock`, `ReleaseLock`, `KVSet`, `KVGet`, `PlayerSnapshot`, `ValidateDistance`, `ValidateAmount`, `ValidateNetEntity`
- **DB tables**: `imperial_logs`, `imperial_kv`
- **Config**: `config/shared.lua` (flush interval, severity map, rate-limit defaults, lock TTL)
- **Notes**: Batches audit-log inserts rather than one per call; mirrors severity ≥ 3 to an optional Discord webhook.

### imperial_character
- **Role**: First-login starter package, spawn-rescue safety net.
- **Dependencies**: qbx_core, imperial_logging
- **Key events**: `imperial_character:server:firstLogin` / `:client:firstLogin`, `imperial_character:server:requestSpawnRescue`
- **DB**: uses `imperial_kv` (via imperial_logging) for duplicate-proof grant claims.
- **Notes**: Grant claimed in KV before granting, so a starter package can never be issued twice to the same character.

### imperial_sidejobs
- **Role**: Session-based civilian side jobs — fishing, mining, lumber, construction, secure transport, materials buyer.
- **Dependencies**: qbx_core, ox_lib, ox_target, ox_inventory, imperial_logging
- **Design note**: Never calls `SetJob` — purely session/in-memory state, so side jobs never pollute a player's framework job.

### imperial_crafting
- **Role**: Single crafting authority for both general and criminal categories.
- **Dependencies**: qbx_core, ox_lib, ox_target, ox_inventory, imperial_logging
- **Key exports**: `RegisterBench`, `RegisterRecipe`, `GetLevel`, `HasUnlock`, `UseBlueprint`
- **DB tables**: `imperial_crafting_xp`, `imperial_crafting_unlocks`
- **Config**: `config/benches.lua`, `config/recipes.lua`
- **Notes**: Runtime-extensible — `imperial_businesses` registers its own benches/recipes into this resource rather than building a second crafting system.

### imperial_businesses
- **Role**: Player-owned business framework.
- **Dependencies**: qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging, imperial_crafting
- **Key exports**: `GetBusiness`, `IsBusinessEmployee`, `IsBusinessEmployeeCitizen`, `HasBusinessPermission`, `AddBusinessFunds`, `RemoveBusinessFunds`
- **DB tables**: `imperial_businesses`, `imperial_business_employees`, `imperial_business_txns`
- **Config**: `config/businesses.lua` (8 seed businesses + hospitality recipes)
- **Notes**: Wage cycles, lease billing (restart-safe via KV timestamp guard), POS with customer confirmation, ledger.

### imperial_dispatch
- **Role**: Single dispatch authority for all emergency services.
- **Dependencies**: qbx_core, ox_lib, imperial_logging
- **Key exports**: `CreateDispatchCall(data)`, `GetRecentCalls`
- **DB tables**: `imperial_dispatch_calls` (in `sql/008_mdt.sql`)
- **Notes**: Duty tracked via `QBCore:Server:SetDuty` event plus a 30s safety poll that re-derives truth from live PlayerData — never trusts the event payload alone.

### imperial_fire
- **Role**: Fire & rescue incident state machine.
- **Dependencies**: qbx_core, ox_lib, ox_target, imperial_logging, imperial_dispatch
- **Incident types**: vehicle_fire, structure_fire, hazmat, rescue, rtc
- **DB tables**: `imperial_fire_roster`
- **Notes**: Escalation-if-ignored, abandonment cleanup sweep, automatic spawner capped at 2 concurrent incidents.

### imperial_mdt
- **Role**: Unified, department-scoped MDT across police/EMS/fire.
- **Dependencies**: qbx_core, ox_lib, oxmysql, imperial_logging, imperial_dispatch
- **DB tables**: `imperial_mdt_reports`, `imperial_mdt_charges`, `imperial_mdt_warrants`, `imperial_mdt_bolos`, `imperial_mdt_audit`
- **UI**: self-contained NUI (`web/index.html`, vanilla JS, no framework), department scope derived server-side from real job/grade/duty.

### imperial_drugs
- **Role**: Fictional, abstract-stage drug lab production.
- **Dependencies**: qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging, imperial_dispatch
- **DB tables**: `imperial_drug_labs`, `imperial_drug_batches`
- **Notes**: 4 config-driven gather/process/refine/package stages, no real-world chemistry content anywhere; restart-safe timestamp-derived batch state, matching imperial_farming's pattern.

### imperial_blackmarket
- **Role**: Fencing and money laundering.
- **Dependencies**: qbx_core, ox_lib, ox_inventory, oxmysql, imperial_logging
- **DB tables**: `imperial_blackmarket_listings`, `imperial_launder_jobs`
- **Notes**: `crim_token` (fencing payout) and `black_money` (Dirty Money) are both ox_inventory items, kept separate from framework cash by design.

### imperial_boosting
- **Role**: Contract-based vehicle theft.
- **Dependencies**: qbx_core, ox_lib, ox_inventory, imperial_logging, imperial_dispatch
- **DB tables**: `imperial_boosting_reputation`
- **Notes**: Delivery verification is bound to the exact network id captured at `registerVehicle` time — prevents swapping in a different vehicle of the same model.

### imperial_gangs
- **Role**: Fully dynamic, database-backed gang system.
- **Dependencies**: qbx_core, ox_lib, oxmysql, imperial_logging
- **Key exports**: `GetMemberRank`, `IsGangMember`, `HasGangPermission`, `GetGang`, `GetPlayerGang`, `AddGangReputation`, `AddGangFunds`, `RemoveGangFunds`
- **DB tables**: `imperial_gangs`, `imperial_gang_members`, `imperial_gang_txns`
- **Notes**: Never calls `qbx_core:SetGang` — integration surface for other resources is exclusively the exports above.

### imperial_turfs
- **Role**: Configurable, non-deathmatch gang territory control.
- **Dependencies**: qbx_core, ox_lib, oxmysql, imperial_logging, imperial_gangs, imperial_dispatch
- **Key exports**: `GetTurfOwner`, `GetGangTurfs`
- **DB tables**: `imperial_turfs`, `imperial_turf_log`
- **Notes**: Declaration delay → presence-gated capture window → resolution, defender advantage, participation caps, cooldowns.

### imperial_farming
- **Role**: Restart-safe seed→harvest→sell production loop.
- **Dependencies**: qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging
- **DB tables**: `imperial_farm_plants`
- **Config**: `config/shared.lua` (12 crops, zones, watering/health rules)
- **Notes**: Growth/health computed lazily from stored timestamps — no per-plant threads; atomic delete-first harvest claim prevents double-collection.

## Third-party resources

Full selection rationale, licence, dependency, and "last meaningful update"
detail for every resource below is in `docs/05-resource-selection.md`'s
Selected Resources table — this section is a category index, not a
duplicate of that table.

| Category | Resources |
|---|---|
| Core / framework | qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, ox_doorlock, ox_fuel, qbx_vehicles |
| Character | qbx_spawn, illenium-appearance, qbx_idcard |
| UI / HUD / Admin | qbx_hud, qbx_radialmenu, qbx_scoreboard, qbx_seatbelt, qbx_adminmenu |
| World | qbx_smallresources, qbx_density, Renewed-Weathersync, bob74_ipl, qbx_binoculars |
| Vehicles | qbx_garages, qbx_vehiclekeys, qbx_vehicleshop, qbx_vehiclesales, qbx_customs, vehiclehandler, qbx_carwash |
| Voice | pma-voice, mm_radio |
| Phone | npwd, qbx_npwd, npwd_qbx_garages, npwd_qbx_mail |
| Banking | Renewed-Banking |
| Medical / EMS / Police | qbx_medical, qbx_ambulancejob, qbx_police, xt-prison |
| Civilian jobs | qbx_taxijob, qbx_truckerjob, qbx_towjob, qbx_garbagejob, qbx_busjob, qbx_newsjob, qbx_recyclejob, qbx_mechanicjob, qbx_diving, qbx_divegear |
| Civic / management | qbx_cityhall, qbx_management |
| Criminal | qbx_storerobbery, qbx_bankrobbery, qbx_truckrobbery, qbx_houserobbery, qbx_jewelery, qbx_pawnshop, qbx_scrapyard, qbx_drugs, qbx_weed, qbx_streetraces, qbx_lapraces |
| Housing | qbx_properties |
| Minigames | safecracker, mhacking, ultra-voltlab |
| Media / branding | screencapture, MugShotBase64, mana_audio, loadscreen, scully_emotemenu |
| Assets | pillbox |

## Keeping this file current

Add a new entry to the Custom resources section whenever a new `imperial_*`
resource is created (see `CONTRIBUTING.md`'s workflow), and add a row to the
relevant category in the Third-party table (plus a full row in
`docs/05-resource-selection.md`) whenever a new third-party resource is
adopted into the recipe.
