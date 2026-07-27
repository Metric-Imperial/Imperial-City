# Contributing

## Before you start

Read `docs/00-overview.md` and `docs/01-architecture.md` first — most
"new feature" work in this project should extend an existing authoritative
system (crafting, dispatch, gangs, businesses) rather than adding a parallel
one. If you're not sure whether something belongs in an existing resource
or a new one, check the "one authoritative system per domain" rule in
`CLAUDE.md` before writing code.

## Ground rules

This project follows a small set of non-negotiable rules, documented in
full in `CLAUDE.md`:

- No `+=`/`-=`/`*=`/`/=` or `?.` — neither is valid CfxLua syntax.
- Every custom event/export/resource name is prefixed `imperial_`.
- Every server-side handler treats client input as untrusted and
  re-derives identity/job/gang/duty/distance from server state.
- Money movement uses the guarded atomic-`UPDATE` + ledger + audit-log
  pattern (`BizAdjust`/`gangAdjust`) — don't invent a new money-handling
  shape.
- Tunables go in `config/*.lua` or `imperial:econ:*` convars, not inline.
- `imperial_drugs` content stays fictional/abstract — no real chemistry.

## Workflow

1. **Discuss scope first** for anything touching more than one resource, or
   introducing a new `imperial_*` resource — check
   `docs/05-resource-selection.md`'s rejection table to make sure you're not
   duplicating something already deliberately excluded, and
   `docs/01-architecture.md` to make sure a new resource is actually
   warranted rather than an extension of an existing one.
2. **Write the code.** Follow the folder structure and conventions of an
   existing `imperial_*` resource (fxmanifest, `config/{shared,client,server}`,
   `client/`, `server/`, `README.md` with an export table and test
   checklist).
3. **Validate.**
   ```bash
   python3 tools/luacheck.py "resources/[custom]/<your-resource>"
   python3 tools/verify_startup.py
   ```
4. **Update docs.** If you touched schema, add a new numbered migration
   (never edit a shipped one — see `docs/21-update-procedure.md`). If you
   touched a validated flow, update `docs/18-security.md`. If you added a
   thread/tick loop, update `docs/23-performance-review.md`. Update
   `RESOURCE_REGISTRY.md` if resource metadata changed.
5. **Test manually against the relevant section of `docs/19-testing.md`**
   before considering the change done — this project does not claim
   completion without testing.
6. **Commit** with a message explaining *why* the change was made, not just
   what changed — check `git log` for the established tone.

## Reporting a security issue

If you find a validation gap, a money-atomicity issue, or any other
exploitable flaw, document it the way Phase 9's review documented the
`imperial_crafting` ingredient-consumption bug: describe the failure
scenario concretely (what a client could do, what state it would corrupt),
fix it, and record the finding in `docs/18-security.md` and
`PROJECT_STATUS.md`'s Security Concerns section rather than silently
folding the fix into an unrelated commit.

## Adding a new third-party resource to the recipe

1. Research it the way `docs/05-resource-selection.md` describes: check
   activity, licence, SQL requirements, exports, and security posture —
   don't assume a "Qbox compatible" label is accurate without inspecting
   the code.
2. Add the corresponding `download_github`/`download_file` + `unzip`/
   `move_path` tasks to `recipes/imperial-city-qbox.yaml`, in the correct
   tier (see `docs/03-startup-order.md`).
3. Add it to `server.cfg.template`'s ensure list in the same tier.
4. Add a row to `docs/05-resource-selection.md` and `RESOURCE_REGISTRY.md`.
5. Re-run `python3 tools/verify_startup.py`.

## Code style

- Lua 5.4/CfxLua compatible syntax only (see `CLAUDE.md`).
- Event-driven over per-frame polling — no `Wait(0)`/`Wait(1)` loops; check
  `docs/23-performance-review.md` for the interval conventions used
  elsewhere before picking one for new code.
- Prefer `lib.callback.register` (request/response, validated) over
  `RegisterNetEvent` (fire-and-forget) for anything that changes state —
  see `docs/18-security.md` for why the few `RegisterNetEvent` handlers
  that do exist are safe despite that.
