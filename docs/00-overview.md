# 00 — Overview

**Imperial City** is a complete, installable txAdmin recipe for a serious
roleplay FiveM server, built on the latest stable **Qbox Lean** framework.
It combines the official Qbox Lean base pack, a curated set of first-party
Qbox and Overextended ("ox") resources, a small number of vetted third-party
standalone resources, and a suite of 14 custom `imperial_*` resources that
fill every gap the free ecosystem doesn't already cover well.

## What's in the box

- **Framework**: qbx_core (with integrated multicharacter), qbx_spawn.
- **UI / interaction layer**: ox_lib, ox_target, ox_inventory, ox_doorlock, ox_fuel.
- **Database**: oxmysql, with all custom schema delivered as ordered,
  idempotent migrations (`sql/000`–`011`).
- **Voice, appearance, banking, phone, weather**: pma-voice + mm_radio,
  illenium-appearance, Renewed-Banking, NPWD (+ qbx_npwd bridge and apps),
  Renewed-Weathersync.
- **Civilian economy**: the full set of first-party qbx job resources (taxi,
  trucker, tow, garbage, bus, news, recycling, mechanic, diving) plus
  `imperial_sidejobs` (fishing, mining, smelting, lumber, jeweller,
  materials buyer) and `imperial_crafting` (a single config-driven bench/recipe
  framework covering both general and criminal crafting).
- **Player-owned businesses**: `imperial_businesses` — ownership, employees
  and ranks, point-of-sale, wages, lease billing, and a documented,
  reusable API (`GetBusiness`, `IsBusinessEmployee`, `HasBusinessPermission`,
  `AddBusinessFunds`, `RemoveBusinessFunds`) that other resources (including
  imperial_crafting) build on.
- **Real estate**: qbx_properties for general housing.
- **Emergency services**: qbx_police, qbx_medical/qbx_ambulancejob, and
  `imperial_fire` (a full incident state machine — vehicle fires, structure
  fires, hazmat, rescue, and RTC calls — not an afterthought), unified by
  `imperial_dispatch` (`CreateDispatchCall` export) and `imperial_mdt` (one
  MDT, department-scoped, across all three services).
- **Gangs and territory**: `imperial_gangs` (fully dynamic, database-backed,
  never touches qbx_core's static gang system) and `imperial_turfs`
  (configurable, non-deathmatch territory conflict with declaration
  periods, capture windows, defender advantage, and cooldowns).
- **Criminal ecosystem**: the first-party qbx robbery suite (store, bank,
  truck, house, jewelry, pawnshop, scrapyard), plus `imperial_drugs`
  (fictional, abstract-stage drug labs — no real-world chemistry),
  `imperial_blackmarket` (fencing and laundering), and `imperial_boosting`
  (contract vehicle theft).
- **Farming**: `imperial_farming` — a full seed → water → fertilise → grow →
  harvest → process → sell loop feeding businesses and the wholesale market.
- **Security and audit**: `imperial_logging` — the cross-cutting resource
  every other custom resource depends on, providing a structured/batched
  audit log with optional Discord mirroring, a sliding-window rate limiter,
  per-player action locks, a persistent key-value store, and shared
  server-side validation helpers.

## Design principles

The whole recipe follows the same handful of rules everywhere:

- **Server authority over client convenience.** No client ever declares an
  outcome (money changed, item granted, job assigned) — it requests, and the
  server decides after re-deriving the truth from its own state.
- **One authoritative system per domain.** There is exactly one inventory,
  one targeting system, one crafting authority, one gang authority, one
  dispatch authority — never two competing systems for the same concern.
- **Adapters over core edits.** Where a system needs to interact with
  qbx_core (gangs, in particular), it exposes compatibility exports instead
  of patching framework files.
- **Config over hard-coded edits.** Every tunable — prices, cooldowns,
  thresholds, durations — lives in a `config/` file or an `imperial:econ:*`
  convar, not inline in logic.
- **Free and open-source throughout.** Nothing in this recipe requires a
  paid or escrowed resource; see `docs/05-resource-selection.md` for the
  full selection/rejection rationale.

## Where to go next

- New to this recipe? Start with `docs/01-architecture.md`, then
  `docs/02-installation.md`.
- Installing on a fresh box? `docs/02-installation.md` and
  `docs/04-dependencies.md`.
- Looking for a specific system? See the table of contents below.
- Auditing security or performance before going live?
  `docs/18-security.md` and `docs/23-performance-review.md`.

## Documentation index

| Doc | Covers |
|---|---|
| 00-overview.md | This file. |
| 01-architecture.md | Resource layout, module boundaries, how systems talk to each other. |
| 02-installation.md | Fresh-install walkthrough via txAdmin. |
| 03-startup-order.md | Deterministic tier order and dependency graph. |
| 04-dependencies.md | Every resource's declared dependencies, in one place. |
| 05-resource-selection.md | Repository selection report + rejected-resources report. |
| 06-configuration.md | Where every tunable lives (config files vs. convars). |
| 07-database.md | Schema overview, migration ledger, how to add new migrations. |
| 08-economy.md | Money flows, `imperial:econ:*` convars, anti-exploit rules. |
| 09-jobs.md | Civilian starter jobs and side-jobs. |
| 10-businesses.md | Player-owned business framework and API. |
| 11-emergency-services.md | Police / EMS / fire. |
| 12-dispatch-and-mdt.md | Dispatch API and unified MDT. |
| 13-gangs-and-turfs.md | Dynamic gangs and territory control. |
| 14-criminal-activities.md | Robberies, crafting (criminal side), general criminal design rules. |
| 15-drugs.md | Fictional/abstract drug lab system. |
| 16-farming.md | Farming loop and produce economy. |
| 17-properties.md | Real estate / housing. |
| 18-security.md | Phase 9 security review. |
| 19-testing.md | Structured test plan. |
| 20-troubleshooting.md | Common install/runtime issues. |
| 21-update-procedure.md | How to update the recipe / apply new migrations safely. |
| 22-licences-and-attribution.md | Licence and attribution tracking per resource. |
| 23-performance-review.md | Phase 9 performance review. |
| 24-item-audit.md | Item catalogue audit (duplicate keys/labels, unreferenced items, image-asset check). |

Also see `RESOURCE_REGISTRY.md` (per-resource metadata for every third-party
and custom resource) and `PROJECT_STATUS.md` (build history and current status).
