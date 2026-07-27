# Current Phase

Phase 10 — Recipe and Documentation (complete). **All 10 phases complete — recipe is v1.0.**

## Completed
- **Phase 1 — Discovery**: official Qbox Lean recipe captured, repo landscape
  surveyed, repository-selection report written (`docs/05-resource-selection.md`).
- **Phase 2 — Foundation**: recipe skeleton (`recipes/imperial-city-qbox.yaml`),
  tiered `server.cfg.template`, base config files (`voice.cfg`, `ox.cfg`,
  `permissions.cfg`, `misc.cfg`, `economy.cfg`), `sql/000_ledger.sql` +
  `sql/001_core.sql`, `imperial_logging` (audit log, rate limiter, locks, KV
  store, validation helpers — the cross-cutting dependency every other custom
  resource builds on).
- **Phase 3 — Core Player Systems**: multicharacter/spawn confirmed via
  first-party qbx_core + qbx_spawn (no custom code needed), `imperial_character`
  (duplicate-proof starter package via KV-claim-before-grant, server-validated
  spawn rescue).
- **Phase 4 — Civilian Economy**: `imperial_sidejobs` (fishing/mining/lumber/
  construction/secure-transport/materials-buyer, session-based, no framework
  job-state pollution), `imperial_crafting` (bench/recipe framework covering
  general + criminal categories from one config-driven authority).
- **Phase 5 — Businesses & Properties**: `imperial_businesses` (ownership,
  employees/ranks, POS, wages, lease billing, ledger, `GetBusiness`/
  `IsBusinessEmployee`/`HasBusinessPermission`/`Add-`/`RemoveBusinessFunds`
  exports exactly matching the spec), crafting-bridge registering business
  stations into `imperial_crafting` via `RegisterBench`/`RegisterRecipe`,
  qbx_properties adopted for general real estate (see `docs/17-properties.md`).
- **Phase 6 — Emergency Services**: qbx_police/qbx_medical/`imperial_fire`
  (incident state machine covering vehicle/structure/hazmat/rescue/rtc — not
  an afterthought), `imperial_dispatch` (`CreateDispatchCall` export matching
  the spec signature, duty tracked via event + periodic re-derivation from
  real PlayerData), `imperial_mdt` (unified cross-department NUI, reports/
  charges/warrants/BOLOs/lookups/dispatch-call linking, department scope
  derived server-side from real job/grade/duty).
- **Phase 7 — Criminal Ecosystem**: `imperial_drugs` (fictional abstract lab
  stages only — no real-world chemistry, feeds the same sellable items qbx_drugs
  defines), `imperial_blackmarket` (fencing → `crim_token`, laundering →
  clean bank cash, `black_money` kept as an ox_inventory item distinct from
  framework cash), `imperial_boosting` (contract theft, network-id-bound
  delivery verification).
- **Phase 8 — Gangs & Turfs**: `imperial_gangs` (fully dynamic DB-backed
  gangs, no `qbx_core:SetGang` calls, founding-session flow, compatibility
  exports for gang-aware resources), `imperial_turfs` (declaration →
  presence-gated capture window → resolution, defender advantage,
  participation caps, cooldowns, `GetTurfOwner`/`GetGangTurfs` extension
  points, reputation award on capture).
- **Phase 9 — Security and Optimisation**: full security review across all
  custom resources (`docs/18-security.md`) and full performance review
  (`docs/23-performance-review.md`). Found and fixed one real bug (crafting
  partial-ingredient-consumption); reviewed and cleared every
  `RegisterNetEvent` handler, every money-movement path, and every
  multi-step timed flow for the same class of re-validation gap.
- **Phase 10 — Recipe and Documentation**: full documentation set completed
  (`docs/00` through `docs/24`, 25 files total — see `docs/00-overview.md`'s
  index), `RESOURCE_REGISTRY.md`, root `CLAUDE.md`/`CONTRIBUTING.md`/
  `CHANGELOG.md`/`LICENSE`/`.env.example`/`.gitignore`, item-catalogue audit
  (`docs/24-item-audit.md` — found and fixed a duplicate item label, flagged
  two dead catalogue entries and two unwired items for future follow-up),
  structural clean-install validation (fxmanifest presence, README presence,
  SQL-migration-list-vs-disk consistency, server.cfg ensure-list coverage,
  lua54 manifest sanity — all custom resources pass).

## In Progress
- None — all 10 phases complete.

## Blocked
- Direct `git clone` of arbitrary GitHub repos remains unavailable in this
  environment (proxy restriction) — mitigated throughout: source inspection
  via GitHub web/raw fetches; the txAdmin recipe downloads all third-party
  resources from their original sources at install time, so this was never
  a blocker for the deliverable itself.
- No FXServer instance is available in this environment, so no live/runtime
  test pass has been executed. `docs/19-testing.md` is the structured plan
  that must be run (single-player, then two-player/exploit) before this
  recipe is treated as production-ready — this is the one meaningful gap
  between "recipe complete" and "verified production-ready," and it is
  documented as such rather than glossed over.

## Decisions Made
1. Base = official **qbox-lean** pack, extended with first-party qbx job/
   criminal/housing resources from the full qbox pack sources.
2. Multicharacter: qbx_core integrated (qbx-multicharacter archived).
3. Housing: qbx_properties (only active free Qbox-native option; gaps
   documented in `docs/17-properties.md`).
4. Dispatch/MDT/Fire/Gangs/Turfs/Crafting/Drug labs/Farming/Businesses/Black
   market/Boosting/Logging/Character/Side-jobs: **custom imperial_*** (no
   acceptable free equivalents — see rejection table).
5. Bridge stays enabled solely for illenium-appearance + Renewed-Banking
   (official-recipe configuration); no full qb-core.
6. One authority per domain: ox_inventory (items), ox_target (targeting),
   ox_lib (UI), oxmysql (DB), qbx_vehicles (vehicle ownership), qbx_medical
   (death state), imperial_logging (audit bus), imperial_crafting (all
   crafting including business-registered recipes), imperial_gangs (all
   dynamic gang state, compatibility-export surface only for other systems).
7. Dynamic gangs never call `qbx_core:SetGang` — adapters/compatibility
   exports over core edits, per the standing decision rule.
8. Money is always server-authoritative: every business/gang balance change
   goes through a guarded atomic UPDATE + ledger row + audit log, never a
   read-then-write.
9. Drug production is entirely fictional/abstract — no real-world chemistry,
   formulas, or hazardous procedure content anywhere in config or item flavour text.
10. CfxLua syntax discipline: no `+=`/`-=`/`*=`/`/=` compound assignment, no
    `?.` optional chaining — neither is valid Lua 5.4/CfxLua syntax, despite
    both being common mistakes when porting from other languages. Swept and
    fixed early (Phase 2/3); no subsequent occurrences found in later phases.
11. Job/business/property/criminal-activity catalogue requirement satisfied
    by the existing per-domain docs (`09-jobs.md`, `10-businesses.md`,
    `17-properties.md`, `14-criminal-activities.md`) plus
    `RESOURCE_REGISTRY.md`, rather than duplicating that content into
    separate standalone catalogue files — those docs are already
    catalogue-structured (tables of jobs/businesses/activities with their
    key parameters) and a separate file would have been a near-duplicate.

## Repositories Added
See `docs/05-resource-selection.md` (selected table — ~55 resources).

## Repositories Rejected
See `docs/05-resource-selection.md` (rejection table — 20+ entries).

## Custom Resources Created
All 14 `imperial_*` resources, complete: `imperial_logging`,
`imperial_character`, `imperial_sidejobs`, `imperial_crafting`,
`imperial_businesses`, `imperial_dispatch`, `imperial_fire`, `imperial_mdt`,
`imperial_drugs`, `imperial_blackmarket`, `imperial_boosting`,
`imperial_gangs`, `imperial_turfs`, `imperial_farming` (two more than the
original headcount estimate — farming and side-jobs grew large enough to
warrant separate resources rather than being folded into
businesses/crafting).

## Files Modified
- `recipes/items.lua` — Phase 10 fix: `coffee_cup`'s duplicate "Coffee"
  label changed to "Fresh Coffee" (found during item-catalogue audit).
- New this phase: `docs/00-overview.md`, `01-architecture.md`,
  `02-installation.md`, `04-dependencies.md`, `07-database.md`,
  `08-economy.md`, `16-farming.md`, `19-testing.md`, `20-troubleshooting.md`,
  `21-update-procedure.md`, `22-licences-and-attribution.md`,
  `24-item-audit.md`, `RESOURCE_REGISTRY.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`, `.env.example`, `.gitignore`.

## SQL Changes
- None this phase. All 12 migrations (`sql/000`–`011`) remain as shipped
  through Phase 8; Phase 9/10 made no schema changes. Cross-checked this
  phase: every migration file referenced in `recipes/imperial-city-qbox.yaml`
  exists on disk and vice versa (no drift).

## Tests Passed
- `tools/luacheck.py` — structural validator, run against the full
  `resources/[custom]` tree (67 files) and `recipes/items.lua`: 0 failures.
- `tools/verify_startup.py` — dependency-order verifier: 37 ensures, 0
  failures.
- Structural clean-install cross-check (this phase): every custom
  resource has a matching `fxmanifest.lua`, `README.md`, `lua54 'yes'`
  declaration, and `ensure` line in `server.cfg.template`; every SQL
  migration file referenced in the recipe YAML exists on disk and vice
  versa. All checks passed with zero discrepancies.
- Item-catalogue audit (this phase): 172 items, 0 duplicate keys.
- Manual API-verification against fetched qbx_core/ox_inventory/ox_target
  documentation for every third-party export/event used, throughout the project.

## Tests Failed
- N/A — no live-server test pass has been run (see Blocked). This is a
  known, documented gap: `docs/19-testing.md`'s full checklist (single-
  player and two-player/exploit passes) must be executed against a real
  FXServer deployment before this recipe is treated as production-verified,
  not just structurally/statically complete.

## Security Concerns
- **Fixed Phase 9**: `imperial_crafting`'s `finishCraft` could partially
  consume a recipe's ingredients on a reported "failed: ingredients" outcome
  if the player's inventory changed during the crafting-duration window
  between `startCraft`'s check and `finishCraft`'s removal. Fixed by
  re-checking sufficiency immediately before removal, with a
  `LogSuspicious` audit entry for the residual race window. See
  `docs/18-security.md` and commit `94d424a`.
- **Accepted, low-severity, not blocking**: `imperial_fire`'s two
  `QBCore:Server:SetDuty` handlers rely on relative timeout ordering
  rather than explicit sequencing; bounded by a 30s safety poll. Documented
  follow-up, not fixed.
- **Fixed Phase 10**: item-catalogue audit found `coffee_cup` sharing a
  display label with the base `coffee` item — relabelled.
- **Flagged Phase 10, not fixed (feature gaps, not security bugs)**:
  `farming_hoe` and `ingredient_box` are catalogue items with no wired
  gameplay consumer — documented in `docs/24-item-audit.md` as follow-up
  feature work rather than silently left unexplained. `refined_product`
  and `product_package` are confirmed dead catalogue entries from an
  earlier drug-production design iteration, flagged for removal in a
  future catalogue update.
- Renewed-Banking exports remain wrapped so imperial resources never accept
  a client-supplied amount directly.
- qbx_properties WIP areas: access-validation review deferred to installer
  discretion, documented in `docs/17-properties.md`.

## Next Actions
- Run `docs/19-testing.md`'s full checklist against a real FXServer
  deployment (the one remaining gap between "recipe complete" and
  "production-verified") — single-player pass, then two-player/exploit pass.
- Verify item icon assets for all 69 Imperial-added items render correctly
  post-deploy (flagged in `docs/24-item-audit.md` as unverifiable in this
  environment).
- Consider wiring `farming_hoe` into `imperial_farming:plant`'s tool check
  and `ingredient_box` into a business restock flow, or removing them from
  the catalogue — operator's call, documented as an open item rather than
  decided unilaterally.
- Once the live test pass is complete and clean, tag `v1.0.0`.
