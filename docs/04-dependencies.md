# 04 — Dependencies

Every custom resource's declared `fxmanifest.lua` dependencies, in one place
(cross-reference against `docs/03-startup-order.md` for *why* this order is
enforced, and `tools/verify_startup.py` for the tool that checks it stays
correct).

| Resource | `dependencies { ... }` |
|---|---|
| imperial_logging | oxmysql, ox_lib |
| imperial_character | qbx_core, imperial_logging |
| imperial_sidejobs | qbx_core, ox_lib, ox_target, ox_inventory, imperial_logging |
| imperial_crafting | qbx_core, ox_lib, ox_target, ox_inventory, imperial_logging |
| imperial_businesses | qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging, imperial_crafting |
| imperial_dispatch | qbx_core, ox_lib, imperial_logging |
| imperial_fire | qbx_core, ox_lib, ox_target, imperial_logging, imperial_dispatch |
| imperial_mdt | qbx_core, ox_lib, oxmysql, imperial_logging, imperial_dispatch |
| imperial_drugs | qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging, imperial_dispatch |
| imperial_blackmarket | qbx_core, ox_lib, ox_inventory, oxmysql, imperial_logging |
| imperial_boosting | qbx_core, ox_lib, ox_inventory, imperial_logging, imperial_dispatch |
| imperial_gangs | qbx_core, ox_lib, oxmysql, imperial_logging |
| imperial_turfs | qbx_core, ox_lib, oxmysql, imperial_logging, imperial_gangs, imperial_dispatch |
| imperial_farming | qbx_core, ox_lib, ox_target, ox_inventory, oxmysql, imperial_logging |

Two dependency relationships exist as **runtime, optional** integrations
rather than hard `fxmanifest` dependencies, because both resources must
still function correctly if the other isn't installed (checked via
`GetResourceState(...)` at the call site, failing closed):

- `imperial_crafting` ↔ `imperial_businesses` — the `restrict.business`
  delegation in `imperial_crafting` and the bench/recipe registration call
  from `imperial_businesses` are both guarded by a resource-state check.
- `imperial_gangs` ↔ (`imperial_turfs`, `imperial_drugs`,
  `imperial_blackmarket`, `imperial_crafting`) — every gang-gated feature in
  those resources checks `GetResourceState('imperial_gangs') == 'started'`
  before calling its exports, so a server that ships gangs disabled doesn't
  break gang-adjacent features — it just leaves the dynamic-gang branch of
  their restriction logic unreachable.

## Third-party framework dependencies (non-imperial)

The full third-party dependency chain (qbx_core ← oxmysql, ox_target ←
ox_lib, etc.) is covered by `docs/03-startup-order.md`'s dependency graph
and by each upstream project's own fxmanifest — this repo does not restate
third-party manifests here since they're not under this project's control
and can change independently of this recipe. `docs/05-resource-selection.md`
documents which version/branch of each was inspected at selection time.

## Adding a new custom resource

If you extend this recipe with an additional `imperial_*` resource:

1. Declare every imperial_* export it consumes as an explicit
   `dependencies` entry in its `fxmanifest.lua` (even where FXServer
   wouldn't strictly enforce it) — this is what keeps
   `tools/verify_startup.py` meaningful.
2. Add it to the `[custom]` tier list in `server.cfg.template` in an
   order consistent with its dependency table row.
3. Re-run `python3 tools/verify_startup.py` before committing — it will
   fail loudly if the new resource is ensured before something it depends on.
