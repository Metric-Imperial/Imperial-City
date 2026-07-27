# 05 — Resource Selection Report

Research date: 2026-07-26. All repositories inspected via GitHub (org listing, repo pages, official txAdmin recipe `Qbox-project/txAdminRecipe@main`, and the official `qbox-lean.yaml` / `qbox.yaml`). The official Qbox recipe is treated as first-party vetting for the third-party resources it ships (Renewed-Banking, illenium-appearance, NPWD, xt-prison, Renewed-Weathersync, vehiclehandler, pma-voice, bob74_ipl, mana_audio, loadscreen, MugShotBase64, scully_emotemenu, ultra-voltlab, safecracker, mhacking, screencapture).

Key ecosystem facts confirmed during discovery:

* Multicharacter is **built into `qbx_core`** — the standalone `qbx-multicharacter` repo is archived. The stack requirement "qbx_multicharacter" is satisfied by qbx_core's integrated multicharacter.
* `qbx_weathersync`, `qbx_prison`, `qbx_evidence`, `qbx_apartments`, `qbx_houses`, `qbx_phone`, `qbx_lockpick`, `PolyZone` (fork), `qbx_radio` are **archived** upstream. Their replacements are, respectively: Renewed-Weathersync, xt-prison, evidence integrated in `qbx_police`, `qbx_properties`, NPWD, ox_lib skill checks / safecracker / mhacking, ox_lib zones, `mm_radio`.
* `qbx_police` (551 commits, active) is a full police job: duty, armory, evidence lockers, forensics (casings, GSR, blood), fingerprint/DNA, impound, integrated jail, cuffs, radar, cameras, anklets. It supersedes the old qbx_policejob.
* `qbx_properties` is the only active free Qbox-native housing system (GPLv3, active July 2026, documented WIP areas: realtor job polish, decoration, MLO support). Selected with documented gaps; supplemented by config and, where needed, contained patches.
* The Qbox org ships first-party civilian jobs (taxi, trucker, tow, garbage, bus, news, recycle, mechanic, diving) and criminal activities (store/bank/truck/house/jewellery robbery, pawnshop, scrapyard, drugs, weed, vineyard, street/lap races) — all Lua, GPLv3, active as of July 2026.

## Selected Resources

| Category | Resource | Repository | Framework | Dependencies | Licence | Last Meaningful Update | Selection Reason | Required Modifications |
| -------- | -------- | ---------- | --------- | ------------ | ------- | ---------------------- | ---------------- | ---------------------- |
| Core | qbx_core | Qbox-project/qbx_core | Qbox | oxmysql, ox_lib | GPLv3 | 2026-07 (active) | Framework core; integrated multicharacter; player/job/gang state | Config only |
| Core | ox_lib | overextended/ox_lib | Standalone | — | LGPL-3.0 | active | Standard UI/callback/zone provider | None |
| Core | ox_target | overextended/ox_target | Standalone | ox_lib | LGPL-3.0 | active | Sole third-eye system | None |
| Core | ox_inventory | overextended/ox_inventory | Standalone | ox_lib, oxmysql | LGPL-3.0 | active | Sole inventory | items.lua catalogue; shop/stash config |
| Core | oxmysql | overextended/oxmysql | Standalone | — | LGPL-3.0 | active | Sole DB layer (MariaDB ≥10.9, rec. 12.3 LTS) | None |
| Core | ox_doorlock | overextended/ox_doorlock | Standalone | ox_lib | LGPL-3.0 | active | Door access for stations/labs | Door config |
| Core | ox_fuel | overextended/ox_fuel | Standalone | ox_lib, ox_inventory | LGPL-3.0 | active | Fuel | Config |
| Core | qbx_vehicles | Qbox-project/qbx_vehicles | Qbox | qbx_core | GPLv3 | active | Player-vehicle DB API — single authority for vehicle ownership | None |
| Character | qbx_spawn | Qbox-project/qbx_spawn | Qbox | qbx_core, ox_lib | GPLv3 | active | Spawn selection | Spawn list config |
| Character | illenium-appearance | iLLeniumStudios/illenium-appearance | qb/qbx bridge | ox_lib | GPLv3 | active (in official recipe) | Best free appearance; qbx supported via core bridge | Config (qbx mode) |
| Character | qbx_idcard | Qbox-project/qbx_idcard | Qbox | qbx_core, ox_inventory | GPLv3 | active | ID/licence card items | Item defs |
| UI/HUD | qbx_hud | Qbox-project/qbx_hud | Qbox | qbx_core | GPLv3 | active | HUD | Config |
| UI | qbx_radialmenu | Qbox-project/qbx_radialmenu | Qbox | ox_lib | GPLv3 | active | Radial menu (ox_lib based) | Entries for custom resources |
| UI | qbx_scoreboard | Qbox-project/qbx_scoreboard | Qbox | qbx_core | GPLv3 | active | Player count / scoreboard | None |
| UI | qbx_seatbelt | Qbox-project/qbx_seatbelt | Qbox | qbx_core | GPLv3 | active | Seatbelt | None |
| Admin | qbx_adminmenu | Qbox-project/qbx_adminmenu | Qbox | qbx_core, ox_lib | GPLv3 | active | In-game admin | Permission config |
| World | qbx_smallresources | Qbox-project/qbx_smallresources | Qbox | qbx_core | GPLv3 | active | QoL bundle (consumables, etc.) | Config |
| World | qbx_density | Qbox-project/qbx_density | Qbox | — | GPLv3 | active | Population control | Config |
| World | Renewed-Weathersync | Renewed-Scripts/Renewed-Weathersync | Standalone | ox_lib | GPLv3 | active | Weather/time sync (replaces archived qbx_weathersync) | Config |
| World | bob74_ipl | Bob74/bob74_ipl | Standalone | — | MIT | maintained | Interior IPL loader | None |
| World | qbx_binoculars | Qbox-project/qbx_binoculars | Qbox | — | GPLv3 | active | Binoculars | None |
| Vehicles | qbx_garages | Qbox-project/qbx_garages | Qbox | qbx_core, qbx_vehicles | GPLv3 | active | Garages (public/job/gang/property) | Garage config |
| Vehicles | qbx_vehiclekeys | Qbox-project/qbx_vehiclekeys | Qbox | qbx_core | GPLv3 | active | Keys, locking, hotwire | Config |
| Vehicles | qbx_vehicleshop | Qbox-project/qbx_vehicleshop | Qbox | qbx_core, ox_lib | GPLv3 | active | Dealerships (incl. player-run) | Config, economy prices |
| Vehicles | qbx_vehiclesales | Qbox-project/qbx_vehiclesales | Qbox | qbx_core | GPLv3 | active | Player-to-player vehicle sales | Config |
| Vehicles | qbx_customs | Qbox-project/qbx_customs | Qbox | ox_lib | GPLv3 | active | Vehicle customisation/mechanic POS | Config |
| Vehicles | vehiclehandler | QuantumMalice/vehiclehandler | Standalone | ox_lib | GPLv3 | active | Damage/handling behaviour | Config |
| Vehicles | qbx_carwash | Qbox-project/qbx_carwash | Qbox | qbx_core | GPLv3 | active | Car wash money sink | Config |
| Voice | pma-voice | AvarianKnight/pma-voice | Standalone | — | MIT | active | Voice standard | voice.cfg |
| Voice | mm_radio | Qbox-project/mm_radio | Qbox | pma-voice, ox_lib | GPLv3 | active | Radio (replaces archived qbx_radio) | Item def |
| Phone | npwd | project-error/npwd | Standalone | oxmysql | MIT | maintained releases | Only viable free full phone | qbx config via qbx_npwd |
| Phone | qbx_npwd | Qbox-project/qbx_npwd | Qbox | npwd, qbx_core | GPLv3 | active | Qbox glue for NPWD | None |
| Phone | npwd_qbx_garages / npwd_qbx_mail | Qbox-project | Qbox | npwd | GPLv3 | active | Phone apps | None |
| Banking | Renewed-Banking | Renewed-Scripts/Renewed-Banking | qb/esx (bridge) | ox_lib, ox_target, oxmysql | GPLv3 | 2025-02 release, maintained | Personal/job/gang/shared accounts, transfers, history; in official Qbox recipe | Framework file uses qbx bridge; society hooks for imperial_businesses/gangs |
| Medical | qbx_medical | Qbox-project/qbx_medical | Qbox | qbx_core | GPLv3 | active | Injury/death state authority | Config |
| EMS | qbx_ambulancejob | Qbox-project/qbx_ambulancejob | Qbox | qbx_medical | GPLv3 | active | EMS job, beds, check-in, treatment | Config; dispatch hooks |
| Police | qbx_police | Qbox-project/qbx_police | Qbox | qbx_core, ox_lib, ox_inventory | GPLv3 | active (551 commits) | Full police: duty, armory, evidence, forensics, jail, impound, cuffs | Config; imperial_dispatch + imperial_mdt integration |
| Prison | xt-prison | xT-Development/xt-prison | qbx/ox | ox_lib, ox_inventory | GPLv3 | active | Prison (replaces archived qbx_prison); in official recipe | Config |
| Jobs | qbx_taxijob, qbx_truckerjob, qbx_towjob, qbx_garbagejob, qbx_busjob, qbx_newsjob, qbx_recyclejob, qbx_mechanicjob, qbx_diving (+qbx_divegear) | Qbox-project/* | Qbox | qbx_core, ox_lib | GPLv3 | active (2026-07) | First-party civilian job set | Payout/economy config; side-job layer via qbx_cityhall |
| Civic | qbx_cityhall | Qbox-project/qbx_cityhall | Qbox | qbx_core | GPLv3 | active | City services + civilian job applications (employment layer) | Job list config |
| Business (mgmt) | qbx_management | Qbox-project/qbx_management | Qbox | qbx_core, ox_lib | GPLv3 | active | Boss-menu baseline for framework jobs/gangs | Complemented by imperial_businesses |
| Criminal | qbx_storerobbery, qbx_bankrobbery, qbx_truckrobbery, qbx_houserobbery, qbx_jewelery, qbx_pawnshop, qbx_scrapyard | Qbox-project/* | Qbox | qbx_core, ox_lib, ox_inventory (+safecracker, mhacking, ultra-voltlab minigames) | GPLv3 | active | First-party robbery/chop suite | Dispatch rewired to imperial_dispatch; economy config |
| Criminal | qbx_drugs, qbx_weed | Qbox-project/* | Qbox | qbx_core, ox_inventory | GPLv3 | active | Street drug selling + weed growing baseline | Integrated with imperial_drugs labs + imperial_farming |
| Criminal | qbx_streetraces, qbx_lapraces | Qbox-project/* | Qbox | qbx_core | GPLv3 | active | Illegal racing | Config |
| Housing | qbx_properties | Qbox-project/qbx_properties | Qbox | qbx_core, ox_lib, ox_inventory | GPLv3 | active (WIP areas) | Only active free Qbox-native housing; apartments+houses+stash+wardrobe | Config; documented WIP gaps; property-garage config |
| Minigames | safecracker, mhacking, ultra-voltlab | qbox-project / ultrahacx | Standalone | — | see repos | active | Robbery minigames used by qbx criminal suite | None |
| Media | screencapture, MugShotBase64, mana_audio, loadscreen, scully_emotemenu | various (official recipe set) | Standalone | — | MIT/GPL | active | Screenshots, mugshots, audio, loading screen, emotes | Branding |
| Assets | pillbox | Lorenc95/pillbox | Map | — | free | active | Pillbox hospital interior used by qbx_ambulancejob | None |

## Custom `imperial_*` Resources (to be built — no acceptable free equivalent found)

| Resource | Domain | Why custom |
| -------- | ------ | ---------- |
| imperial_businesses | Player-owned businesses (ownership, employees, ledger, POS, stock, storage, invoices, API) | qbx_management is framework-job boss menu only; free full business frameworks are qb-only/abandoned/paid |
| imperial_dispatch | Unified police/EMS/fire dispatch with documented `CreateDispatchCall` export | ps-dispatch is qb-core-only; cd/core dispatch paid; need fire support + clean API |
| imperial_mdt | Multi-department MDT (police/EMS/fire) | ps-mdt qb-only & stale; all maintained MDTs paid/escrow |
| imperial_fire | Fire & rescue job + synced incidents (vehicle/structure fires, hazmat, RTCs) | No maintained free fire system exists |
| imperial_gangs | Dynamic DB-backed gang creation/management | qbx_core gangs are static config; no free dynamic gang system for qbox |
| imperial_turfs | Territory control with configurable conflict rules | No maintained free qbox turf system |
| imperial_crafting | Single crafting framework (general + criminal benches, XP, unlocks, logs) | ox_inventory bench crafting lacks XP/unlocks/logging/skill checks; qb crafting scripts incompatible |
| imperial_drugs | Lab-based abstract drug production (quality metadata, batches, raids) | qbx_drugs covers selling; no free qbox lab framework |
| imperial_farming | Full farming loop (plant entities, growth persistence, quality, processing) | qbx_vineyard is a single activity; free farming scripts qb-only/abandoned |
| imperial_blackmarket | Black market, money laundering, criminal currency, fencing | No acceptable free equivalent |
| imperial_boosting | Vehicle boosting contracts (tie-in to qbx_scrapyard chop) | Free boosting scripts are qb-only or abandoned |
| imperial_logging | Structured audit/security logging bus used by all imperial resources | Purpose-built cross-cutting concern |

## Rejected Resources

| Resource | Repository | Rejection Reason |
| -------- | ---------- | ---------------- |
| qb-core (full) | qbcore-framework/qb-core | Must not run beside qbx_core; superseded by Qbox |
| ps-dispatch | Project-Sloth/ps-dispatch | QBCore-only dependency; would force bridge reliance for a core system; replaced by imperial_dispatch |
| ps-mdt | Project-Sloth/ps-mdt | QBCore-only, depends on ps-dispatch; stale vs qbx_police data model |
| ps-housing | Project-Sloth/ps-housing | QBCore-oriented, heavy dependency chain (ps-realtor); qbx_properties is native |
| qbx_apartments / qbx_houses | Qbox-project | Archived upstream; replaced by qbx_properties |
| qbx_weathersync | Qbox-project | Archived; replaced by Renewed-Weathersync |
| qbx_prison | Qbox-project | Archived; replaced by xt-prison |
| qbx_evidence | Qbox-project | Archived; evidence now in qbx_police |
| qbx_phone | Qbox-project | Archived; replaced by NPWD |
| qbx-multicharacter | Qbox-project | Archived; merged into qbx_core |
| qbx_radio | Qbox-project | Archived; replaced by mm_radio |
| qbx_vehiclefailure | Qbox-project | Archived; replaced by vehiclehandler |
| PolyZone | (any) | Unmaintained; ox_lib zones are the standard |
| wasabi_police / wasabi_ambulance | wasabi scripts | Paid (Tebex), escrow |
| okokBanking, okok* | okok | Paid, escrow |
| lb-phone, lb-tablet | LB | Paid, escrow |
| qs-inventory / qs-housing / qs-smartphone | Quasar | Paid, escrow, competes with ox_inventory |
| cd_dispatch, core_dispatch | Codesign/Core | Paid or qb-only |
| renzu_jobs / renzu_gangs | renzu | Low maintenance, mixed framework assumptions, quality concerns |
| esx_* suite | any | ESX-only |
| qb-* job/criminal suite | qbcore-framework | QBCore-only; superseded by first-party qbx_* ports |
| jsfour-mdt / shot-mdt | various | Abandoned (ESX-era), poor security |
| Badger/other free dispatches | various | Standalone-only (no job/char integration) or abandoned |

## Notes

* `qbx:enableBridge` remains **true**: illenium-appearance and Renewed-Banking consume the bridge. This is the officially supported configuration (both ship in the first-party recipe). No full qb-core is installed. Documented as the only two bridge consumers; everything else is qbx/ox-native.
* All Qbox-project resources are GPLv3 → recipe downloads from original sources; imperial_* resources are GPLv3 for licence compatibility where they adapt GPL patterns.
