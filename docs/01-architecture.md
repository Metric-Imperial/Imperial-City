# 01 — Architecture

## Folder layout

```text
resources/
  [cfx-default]/        cfx-server-data base resources (chat removed — see below)
  [ox]/                  ox_lib, oxmysql, ox_target, ox_inventory, ox_doorlock, ox_fuel
  [qbx]/                 qbx_core, qbx_vehicles, qbx_spawn, qbx_garages, qbx_vehicleshop, ...
  [standalone]/           xt-prison, Renewed-Banking, Renewed-Weathersync, loadscreen, ...
  [appearance]/           illenium-appearance
  [voice]/                pma-voice, mm_radio
  [phone]/                npwd, qbx_npwd, [npwd-apps]
  [housing]/              qbx_properties
  [civilian-jobs]/        qbx_taxijob, qbx_truckerjob, qbx_towjob, ...
  [criminal]/              qbx_storerobbery, qbx_bankrobbery, qbx_drugs, qbx_weed, ...
  [maps]/                  pillbox and other map assets
  [custom]/                the 14 imperial_* resources (this project's own code)
```

`[custom]` is the only folder whose contents are authored in this repository;
every other bracketed folder is populated by the txAdmin recipe pulling from
each project's own upstream source at install time (see
`docs/02-installation.md`). This keeps the recipe's own footprint small and
means upstream security fixes reach a server on the next recipe re-run
without this project needing to vendor or re-publish anyone else's code.

## The imperial_* suite

| Resource | Role |
|---|---|
| `imperial_logging` | Foundational. Audit log, rate limiter, per-player locks, KV store, shared validation helpers. Every other imperial_* resource depends on it. |
| `imperial_character` | First-login starter package (duplicate-proof), spawn-rescue safety net. |
| `imperial_sidejobs` | Session-based civilian side jobs — never touches framework job state. |
| `imperial_crafting` | Single crafting authority for both general and criminal recipes; runtime-extensible via `RegisterBench`/`RegisterRecipe`. |
| `imperial_businesses` | Player-owned business framework: ownership, employees, POS, wages, leases, ledger, reusable API. |
| `imperial_dispatch` | Single dispatch authority (`CreateDispatchCall`); duty-aware routing. |
| `imperial_fire` | Fire/rescue incident state machine. |
| `imperial_mdt` | Unified, department-scoped MDT (NUI) across police/EMS/fire. |
| `imperial_drugs` | Fictional, abstract-stage drug lab production. |
| `imperial_blackmarket` | Fencing (contraband → crim_token) and laundering (dirty cash → clean). |
| `imperial_boosting` | Contract-based vehicle theft with network-id-bound delivery verification. |
| `imperial_gangs` | Fully dynamic, database-backed gang system with compatibility exports. |
| `imperial_turfs` | Configurable, non-deathmatch gang territory control. |
| `imperial_farming` | Restart-safe seed→harvest→sell production loop. |

## Module boundaries — how systems talk to each other

The rule throughout is **exports and documented events, not direct file
edits or event-name coupling to internals**. Concretely:

- **imperial_gangs never modifies qbx_core.** Gang-aware resources
  (`imperial_crafting`'s criminal benches, `imperial_turfs`,
  `imperial_drugs`/`imperial_blackmarket` gating) call
  `GetMemberRank`/`IsGangMember`/`HasGangPermission`/`GetPlayerGang` instead
  of reading `PlayerData.gang`. This is the concrete instance of the
  "adapters over core edits" rule — see `docs/13-gangs-and-turfs.md`.
- **imperial_businesses registers into imperial_crafting rather than
  building a second crafting system.** Business hospitality/mechanic
  stations call `imperial_crafting:RegisterBench`/`RegisterRecipe` at
  startup and use a `restrict.business` delegation that calls back into
  `imperial_businesses:HasBusinessPermission`. There is exactly one crafting
  authority in the recipe.
- **imperial_dispatch is the only resource that fires dispatch alerts.**
  Every other resource that needs to notify emergency services
  (`imperial_fire`, `imperial_drugs`' raid tip-offs, `imperial_farming`'s
  theft alerts, `imperial_boosting`'s theft-in-progress alert,
  `imperial_turfs`' contest notification) calls
  `exports.imperial_dispatch:CreateDispatchCall(...)` rather than
  maintaining its own alert routing.
- **imperial_logging is the only resource that writes the audit log,
  enforces rate limits, or holds locks.** Every other custom resource is a
  consumer of its exports, never a re-implementation.
- **Money always flows through one atomic-adjust function per ledger
  domain**: `BizAdjust` in imperial_businesses, `gangAdjust` in
  imperial_gangs — both the same guarded-`UPDATE` + ledger-row + audit-log
  shape, exposed as `Add-`/`RemoveBusinessFunds` and (informally, since gangs
  don't need a public add/remove pair beyond `AddGangFunds`/`RemoveGangFunds`)
  the equivalent gang exports.
- **Resources check `GetResourceState(...)` before calling an optional
  integration's export**, and fail closed (deny, not silently allow) when
  the dependency isn't running — e.g. `imperial_crafting`'s `restrict.business`
  branch, `imperial_farming`'s dispatch call on theft, `imperial_turfs`'
  police-notification-on-contest.

## Data flow for a typical action

Every player-triggered action in the custom suite follows the same shape,
illustrated here with a crafting request:

```text
client: "I want to craft recipe R at bench B, x1"
   │  lib.callback.await('imperial_crafting:startCraft', ..., benchId, recipeId, count)
   ▼
server: validateRequest() — bench/recipe exist, category matches, count in
        range, distance to bench, job/gang/item/level/business restrictions,
        ingredient sufficiency
   │  acquire per-player lock, return duration
   ▼
client: shows progress bar for `duration`, optional skill check
   │  lib.callback.await('imperial_crafting:finishCraft', skillCheckPassed)
   ▼
server: enforce time floor (GetGameTimer() can't have completed early),
        re-run validateRequest() (state may have changed during the wait),
        re-check ingredient sufficiency (Phase 9 fix), remove ingredients,
        roll fail chance, grant output, log, release lock
```

This "validate on request, re-validate on completion" shape — always
re-deriving truth server-side rather than trusting anything the client
reported earlier in the flow — is the same pattern used by
`imperial_boosting` (register vehicle → deliver), `imperial_blackmarket`
(start launder → collect launder), and `imperial_turfs` (declare contest →
tick-based resolution).

## Why 14 resources instead of the originally-scoped 12

Farming and side-jobs were split out from businesses/crafting once each grew
large enough (config, DB schema, and gameplay surface) to justify being an
independently versioned, independently restartable resource rather than a
sub-module of a larger one — consistent with the "modular over monolithic"
decision rule.

## Removed from cfx-server-data

`[cfx-default]/[gameplay]/chat` is removed by the recipe (see
`recipes/imperial-city-qbox.yaml`) because qbx_core ships its own chat
integration; keeping both running would be a duplicate-system violation of
the "one authoritative system per domain" rule.
