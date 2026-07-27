# CLAUDE.md

Guidance for any AI assistant (or human) working in this repository.

## What this repository is

A complete, installable txAdmin recipe for a FiveM roleplay server on the
**Qbox Lean** framework, combining first-party Qbox/ox resources, a curated
set of vetted third-party resources, and 14 custom `imperial_*` resources
authored in `resources/[custom]`. Start with `docs/00-overview.md` for the
full picture; `PROJECT_STATUS.md` tracks build history and current status;
`RESOURCE_REGISTRY.md` has per-resource metadata.

## Hard rules — do not violate these

1. **CfxLua syntax discipline.** No `+=`/`-=`/`*=`/`/=` compound assignment
   operators and no `?.` optional chaining — **neither is valid Lua 5.4 or
   CfxLua syntax**, despite both being easy mistakes when writing Lua after
   working in other languages. Use `x = x + y` and
   `job and job.name or nil` instead. This bit the project once (see
   `PROJECT_STATUS.md` Phase 2/3 decisions) — check for both before
   considering any new Lua file finished.
2. **Server authority, always.** No client-triggered event or callback may
   change money, items, job/gang state, or permissions based on a
   client-supplied value without the server independently re-deriving the
   truth (identity, job, gang, duty, distance, inventory contents) from its
   own state. See `docs/18-security.md` for the standard this is held to.
3. **Namespace everything `imperial_*`.** Every custom resource folder,
   export, and event name. Never collide with third-party naming.
4. **One authoritative system per domain.** Don't build a second crafting
   system, a second dispatch router, a second inventory, etc. — extend the
   existing authoritative resource (see `docs/01-architecture.md`'s "module
   boundaries" section for the established extension patterns, e.g.
   `imperial_crafting:RegisterBench`/`RegisterRecipe`).
5. **Adapters over core edits.** Never modify a third-party resource's own
   files to add functionality — expose compatibility exports instead (the
   `imperial_gangs` ↔ `qbx_core` relationship is the canonical example).
6. **Config over hard-coded values.** Tunable numbers belong in a
   `config/*.lua` file or an `imperial:econ:*` convar (`recipes/economy.cfg`),
   not inline in logic — except anti-exploit *ceilings* (max amounts per
   request), which are deliberately kept in version-controlled Lua config
   rather than an admin-editable convar (see `docs/08-economy.md`).
7. **No real-world drug-production content.** `imperial_drugs` is
   fictional/abstract by explicit design requirement — gather/process/
   refine/package stage labels only, no real chemistry, formulas, or
   hazardous procedures, ever.
8. **Money atomicity.** Any new balance-changing code must use a guarded
   conditional `UPDATE ... WHERE balance >= ?` (not read-then-write), write
   an append-only ledger row, and log via `imperial_logging:Log`. Follow the
   `BizAdjust`/`gangAdjust` pattern rather than inventing a new one.
9. **Migrations are append-only.** Never edit a shipped `sql/NNN_*.sql`
   file — add a new numbered migration instead (see
   `docs/21-update-procedure.md`).

## Validation tools — run after every Lua change

```bash
python3 tools/luacheck.py "resources/[custom]/<resource>"   # structural check (brackets/blocks)
python3 tools/verify_startup.py                              # dependency-order check
```

Neither tool is a full Lua parser — `luacheck.py` only catches gross
structural imbalance (unbalanced brackets/blocks/strings), not semantic
issues like the compound-assignment/optional-chaining mistakes in rule #1
above. Those require a manual read, not just a green check from the tool.
No FXServer is available in most environments this project is developed
in, so these static tools plus manual API-verification against fetched
upstream docs are the primary safety net until a real test pass (see
`docs/19-testing.md`) is run.

## Where things live

- `resources/[custom]/imperial_*` — all custom Lua code. See
  `docs/01-architecture.md` for the module map.
- `sql/000_ledger.sql` … `011_boosting.sql` — ordered, idempotent schema
  migrations. See `docs/07-database.md`.
- `recipes/` — the txAdmin recipe YAML plus every `.cfg` file it assembles
  into `server.cfg`, and the base item catalogue (`items.lua`).
- `docs/00`–`23` — the numbered documentation set; `docs/00-overview.md` is
  the index.
- `tools/` — the two validators described above.
- `PROJECT_STATUS.md` — phase-by-phase build log, kept current.
- `RESOURCE_REGISTRY.md` — per-resource metadata for every third-party and
  custom resource.

## Working style established in this project

- Every git commit explains *why*, not just *what* — check `git log` for
  the established tone before writing a new commit message.
- Security/performance findings get written up in `docs/18-security.md`/
  `docs/23-performance-review.md` as they're found, not batched at the end.
- When a bug is found via review rather than a test failure, say so
  explicitly in the commit message and in `PROJECT_STATUS.md`'s Security
  Concerns section — don't bury a real finding as a routine refactor.
