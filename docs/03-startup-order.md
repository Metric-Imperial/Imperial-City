# 03 — Startup Order and Dependency Graph

The startup order in `server.cfg.template` is deterministic and tiered. FXServer
also honours `dependencies` declared in each fxmanifest, but the recipe never
relies on implicit resolution for cross-folder ordering.

## Tiers

```text
Tier 0  cfx defaults        mapmanager, chat, spawnmanager, sessionmanager, hardcap, baseevents
Tier 1  data + core         oxmysql → ox_lib → qbx_core
Tier 2  interaction         ox_target → ox_inventory
Tier 3  satellites          [ox] (doorlock, fuel) → [qbx] → [standalone] → [appearance] → [voice] → [maps]
Tier 4  phone               qbx_npwd → npwd → [phone] apps
Tier 5  content             [housing] → [civilian-jobs] → [criminal]
Tier 6  imperial suite      imperial_logging → imperial_dispatch → businesses → crafting →
                            farming → gangs → turfs → drugs → blackmarket → boosting →
                            sidejobs → fire → mdt
```

## Dependency graph (authoritative systems)

```text
oxmysql ──┬─▶ qbx_core ──┬─▶ qbx_vehicles ─▶ qbx_garages / qbx_vehicleshop / qbx_vehiclesales
          │              ├─▶ qbx_medical ─▶ qbx_ambulancejob
          │              ├─▶ qbx_police ─▶ xt-prison
          │              ├─▶ qbx job resources (taxi/tow/garbage/... )
          │              └─▶ qbx_properties
ox_lib ───┼─▶ ox_target ─▶ ox_inventory ─▶ (stashes/shops/crafting consumers)
          │
          └─▶ imperial_logging ──┬─▶ imperial_dispatch ──┬─▶ imperial_fire
                                 │                       ├─▶ imperial_mdt
                                 │                       └─▶ (qbx robbery alerts via bridge shim)
                                 ├─▶ imperial_businesses ─▶ (farming wholesale, POS, crafting stations)
                                 ├─▶ imperial_crafting
                                 ├─▶ imperial_farming ───▶ imperial_businesses (supply chain)
                                 ├─▶ imperial_gangs ─────▶ imperial_turfs, imperial_drugs, imperial_blackmarket
                                 ├─▶ imperial_drugs ─────▶ imperial_blackmarket (distribution)
                                 ├─▶ imperial_boosting ──▶ qbx_scrapyard (chop), imperial_blackmarket
                                 └─▶ imperial_sidejobs
```

Rules encoded by this order:

1. `oxmysql` starts before anything that queries (qbx_core runs migrations on start).
2. `ox_target`/`ox_inventory` start before every resource that registers targets or stashes.
3. `imperial_logging` starts before all other imperial resources (they hard-depend on its exports).
4. `imperial_dispatch` starts before `imperial_fire` and `imperial_mdt` (alert consumers).
5. `imperial_gangs` starts before `imperial_turfs` (ownership checks) and before drug/black-market gang gating.
6. NPWD starts after qbx_core (framework binding via qbx_npwd config).

## Verifying

`tools/verify_startup.py` parses `server.cfg.template` plus every custom
fxmanifest and fails if a resource is ensured before any of its declared
dependencies. Run it as part of CI / before shipping recipe changes.
