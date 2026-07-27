# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/);
versioning is by build phase until the first tagged release (`v1.0.0`,
cut at the end of Phase 10 — see `PROJECT_STATUS.md`).

## [Unreleased] — Phase 10: Recipe and Documentation

### Added
- Remaining documentation set: `docs/00-overview.md`, `01-architecture.md`,
  `02-installation.md`, `04-dependencies.md`, `07-database.md`,
  `08-economy.md`, `16-farming.md`, `19-testing.md`, `20-troubleshooting.md`,
  `21-update-procedure.md`, `22-licences-and-attribution.md`.
- Root `CLAUDE.md`, `CONTRIBUTING.md`, `CHANGELOG.md` (this file),
  `.env.example`, `.gitignore`, `LICENSE`.
- `RESOURCE_REGISTRY.md` — per-resource metadata for every third-party and
  custom resource.
- `docs/24-item-audit.md` — item catalogue audit (172 items, 0 duplicate
  keys, 1 duplicate label fixed, 8 unreferenced items individually assessed).

### Fixed
- `recipes/items.lua`: `coffee_cup` shared the display label "Coffee" with
  the base `coffee` item — relabelled to "Fresh Coffee" to distinguish the
  business-made version.

## Phase 9 — Security and Optimisation

### Fixed
- `imperial_crafting`: `finishCraft` could partially consume a recipe's
  ingredients on a reported "failed: ingredients" outcome if inventory
  state changed during the crafting-duration window between `startCraft`'s
  check and `finishCraft`'s removal. Added a re-check immediately before
  removal, plus a `LogSuspicious` audit entry for the residual race window.

### Added
- `docs/18-security.md` — full security review across every custom
  resource: `RegisterNetEvent` handler audit, money-atomicity audit,
  distance/rate-limit/lock coverage audit.
- `docs/23-performance-review.md` — thread/tick inventory, turf-presence-
  scan cost analysis, restart-safe timestamp-state rationale, DB index
  review.

## Phase 8 — Gangs and Turfs

### Added
- `imperial_gangs` — fully dynamic, database-backed gang system. Founding-
  session flow, rank hierarchy, money (`AddGangFunds`/`RemoveGangFunds`),
  compatibility exports (`GetMemberRank`, `IsGangMember`,
  `HasGangPermission`, `GetGang`, `GetPlayerGang`, `AddGangReputation`).
  Never calls `qbx_core:SetGang`.
- `imperial_turfs` — configurable, non-deathmatch territory control:
  declaration period → presence-gated capture window → resolution, defender
  advantage, participation caps, cooldowns, `GetTurfOwner`/`GetGangTurfs`
  extension points, flat per-cycle income.

### Fixed
- `imperial_crafting`'s dynamic-gang restriction fallback checked only
  membership, not rank, allowing a rank-0 member to use a bench meant to
  require rank 1+. Split into explicit static/dynamic checks, both now
  enforcing the required rank.
- Removed two instances of dead/no-op placeholder code
  (`imperial_gangs:HasGangPermission`, `imperial_turfs` capture resolution).
- `imperial_turfs`' `reputationOnCapture` config value was declared but
  never used — wired to the new `AddGangReputation` export.
- `imperial_turfs`' income convar name/shape was inconsistent with the
  actual flat-amount logic reading it — reconciled to
  `imperial:econ:turf:incomePerCycle`.

## Phase 7 — Criminal Ecosystem

### Added
- `imperial_drugs` — fictional, abstract-stage drug lab production (no
  real-world chemistry), restart-safe timestamp-derived batch state,
  contamination/raid-risk sweep with dispatch tip-offs, police raid/seizure.
- `imperial_blackmarket` — fencing (contraband → `crim_token`) and
  laundering (`black_money` → clean bank cash, fee-based, one active job
  per player).
- `imperial_boosting` — contract vehicle theft, network-id-bound delivery
  verification, reputation-gated vehicle-class bands.

### Fixed
- Duplicate `goldbar` key in `imperial_blackmarket`'s buy-rate table.
- `imperial_boosting` payout used `player.Functions.AddMoney('black_money', ...)`,
  treating `black_money` as a money-account type when it's actually an
  ox_inventory item — corrected to `ox_inventory:AddItem` with a bank
  fallback.

## Phase 5–6 — Businesses, Real Estate, Emergency Services

### Added
- `imperial_businesses` — ownership, employees/ranks, point-of-sale, wage
  cycles, lease billing, ledger, and the reusable API (`GetBusiness`,
  `IsBusinessEmployee`, `HasBusinessPermission`, `AddBusinessFunds`,
  `RemoveBusinessFunds`). Registers hospitality/mechanic stations into
  `imperial_crafting` rather than duplicating a crafting system.
- `imperial_dispatch` — `CreateDispatchCall` export, duty-tracked routing
  with a periodic safety poll re-deriving truth from live PlayerData.
- `imperial_fire` — incident state machine (vehicle/structure/hazmat/
  rescue/rtc), escalation, automatic spawner, station duty/equipment.
- `imperial_mdt` — unified, department-scoped MDT NUI across police/EMS/fire.
- qbx_properties adopted for general real estate.

### Fixed — critical
- `imperial_logging/server/validate.lua`'s `playerSnapshot` used `?.`
  optional-chaining syntax, which is not valid Lua/CfxLua at all. Fixed to
  standard `and`/`or` nil-safe patterns.
- Swept the whole codebase for `+=`/`-=`/`*=`/`/=` compound assignment
  operators (also not valid Lua) — found and fixed ~12 occurrences across
  `imperial_crafting`, `imperial_dispatch`, `imperial_logging`,
  `imperial_sidejobs`.
- `imperial_dispatch/client/main.lua`'s `/panic` command assumed a
  `LocalPlayer.state.job` statebag that qbx_core doesn't set — corrected to
  the real `exports.qbx_core:GetPlayerData()` client export.

## Phases 1–4 — Discovery, Foundation, Core Player Systems, Civilian Economy

### Added
- Repository selection report and rejected-resources report
  (`docs/05-resource-selection.md`).
- Recipe skeleton, tiered `server.cfg.template`, base config files, first
  SQL migrations.
- `imperial_logging` — the foundational cross-cutting resource (audit log,
  rate limiter, locks, KV store, validation helpers).
- `imperial_character` — duplicate-proof starter package, spawn-rescue.
- `imperial_sidejobs` — session-based civilian side jobs (no framework
  job-state pollution).
- `imperial_crafting` — single crafting authority for general and criminal
  categories, runtime-extensible via `RegisterBench`/`RegisterRecipe`.
- `imperial_farming` — restart-safe seed→harvest→sell loop.
- Consolidated `ox_inventory` item catalogue (`recipes/items.lua`), ~85
  Imperial-specific items added on top of the official Qbox base catalogue;
  one duplicate-label fix applied (`weed_white-widow`).
