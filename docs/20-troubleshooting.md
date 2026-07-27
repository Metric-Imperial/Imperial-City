# 20 — Troubleshooting

## Black screen with working UI

**Symptom:** the loading screen displays correctly, then the multicharacter
menu appears — but the world behind it is solid black. Audio works (traffic,
NPC chatter). No Lua errors, no JS errors, clean server console.

**Cause:** a NUI page whose *root canvas* is opaque. NUI composites over the
game, so every NUI page must keep a transparent canvas. Declaring
`color-scheme: dark` on `:root` (or setting any background on `html`) makes
CEF paint the canvas opaque black, producing a full-screen black layer over
the game for as long as that resource runs — whether or not its UI is ever
opened.

This bit `imperial_mdt` on the first live deploy. Two things make it
especially hard to spot:

- `body { background: transparent }` does **not** fix it. The canvas colour is
  taken from the root element, not `body`.
- `body { display: none }` does **not** fix it either. The canvas is painted
  regardless of whether anything inside it is displayed.

The engine reports nothing wrong, because nothing *is* wrong: the screen is
faded in, collision is loaded, the ped is visible and alive, and the camera is
rendering correctly. It is all just hidden behind a black web page. A giveaway
is that `DrawText` debug output is invisible while another resource's NUI (for
example ox_lib's menu) still shows — NUI layers draw above `DrawText`, so the
offending page sits between the game and the menu.

**Fix:**

```css
html, body { background: transparent; }
#app { color-scheme: dark; }   /* scope it -- never put this on :root */
```

**Finding the culprit fast:** stop resources until the screen clears, then
start them back one at a time until it goes black again. Only resources that
declare `ui_page` in their manifest can do this:
`grep -rl ui_page --include=fxmanifest.lua resources/`

## Deploy / installation

**Recipe fails at the first `download_github` task.**
You almost certainly haven't replaced `YOUR_ORG/imperial-city` in
`recipes/imperial-city-qbox.yaml` with your own fork's URL — see
`docs/02-installation.md`. The recipe cannot pull the custom `[custom]`
suite, SQL migrations, or base config files from a placeholder URL.

**A `query_database` task fails partway through the SQL migrations.**
Check the migration ledger (`SELECT * FROM imperial_migrations ORDER BY
id;`) to see which migrations already applied. Every migration is
idempotent (`CREATE TABLE IF NOT EXISTS` / `INSERT IGNORE`), so it's safe
to re-run the deploy from the same point — you do not need to drop the
database and start over. If the failure is a genuine SQL error (not a
transient connection issue), check your MariaDB version is ≥ 10.9; older
versions may not support the `CHECK (JSON_VALID(...))` constraint syntax
used throughout.

**Console shows `SCRIPT ERROR: ... unable to execute a query! Table 'X'
doesn't exist` at boot, for a third-party (non-`imperial_*`) resource.**
This means that resource ships its own SQL schema file that the recipe
never ran — confirmed to have happened on first live deploy for
`qbx_lapraces`, `qbx_weed`, `qbx_drugs`, `qbx_properties`, and
`Renewed-Banking` (fixed in commit `3ee957b`; if you deployed from a repo
snapshot predating that fix, pull the update and re-run those specific
`query_database` tasks, or run the listed `.sql` files by hand against
your database — they're idempotent `CREATE TABLE IF NOT EXISTS`, safe to
run standalone). If a *different* resource throws this same error, it
means that resource also ships a schema file the recipe doesn't yet cover:
look in that resource's own downloaded folder under
`resources/[category]/<resource>/` for a `.sql` file (root or a `sql/`
subfolder), add a matching `query_database` task to
`recipes/imperial-city-qbox.yaml` right after that resource's
download/unzip task, and run it once by hand against the live database
(no need to redeploy from scratch — the resource is already downloaded).

**Console shows non-fatal `qbx_core` warnings**: `Table 'playerskins' /
'player_mails' / 'player_outfits' does not exist ... please remove it
from qbx_core/config/server.lua or create the table`.
**Do not "fix" these by deleting the config lines — all three tables are
genuinely required by resources this recipe ships.** An earlier revision of
this document called them inert examples; the first live deploy disproved
that:

- `playerskins` and `player_outfits` are used by `illenium-appearance`,
  which ships them in its own `sql/` directory (four files:
  `playerskins.sql`, `player_outfits.sql`, `player_outfit_codes.sql`,
  `management_outfits.sql`). Missing `playerskins` makes every character
  load throw on `SELECT skin FROM playerskins`, and appearance is never
  persisted — this was the cause of the black screen on first live deploy.
- `player_mails` is used by `npwd_qbx_mail`, which ships **no** `.sql` file
  at all, so there is nothing for a `query_database` task to point at. Its
  schema now lives in this repo as `sql/012_third_party_gaps.sql`.

All three now have `query_database` tasks in the recipe. On a deploy
predating that, run the `.sql` files by hand — they are idempotent
`CREATE TABLE IF NOT EXISTS`.

**`mm_radio` starts with `Warning: UI has not been built`.**
Fixed: the recipe now pulls the release zip
(`releases/latest/download/mm_radio.zip` — verified to be the correct asset
name) via `download_file` + `unzip`, instead of `download_github` of `main`.
A `main` checkout has no pre-built NUI, so it also logs `could not find file
'build/**'` and the radio has no usable interface. If this warning appears
again, the resource was pulled from source rather than a release.

**Console shows `Started gametype Freeroam` / `Started map fivem-map-skater`
/ `Couldn't start resource redm-map-one`.**
`server.cfg` is starting the wrong maps. Resource-category names are matched
by folder name *anywhere* in the resources tree, and cfx-server-data ships
its own `[cfx-default]/[gamemodes]/[maps]/` — so `ensure [maps]` matches that
as well as ours, pulling in `fivem-map-hipster`/`fivem-map-skater`. Those
declare `resource_type 'map' { gameTypes = { ['basic-gamemode'] = true } }`,
which makes mapmanager start the Freeroam gametype, whose client script calls
`spawnmanager:setAutoSpawn(true)` + `forceRespawn()` on `onClientMapStart` —
directly against qbx_core's multicharacter spawn flow. Start our map by name
(`ensure pillbox`) instead. Note a `stop basic-gamemode` line earlier in the
cfg does *not* help: it runs before the resource has started, so it stops
nothing.

**A custom `imperial_*` server hook silently never runs, and the console
shows `event QBCore:Server:OnPlayerLoaded was not safe for net`.**
That event is emitted only from the *client* (`TriggerServerEvent` in
`qbx_core/client/character.lua`), so a handler must use `RegisterNetEvent`;
with `AddEventHandler` the trigger is rejected and the handler never fires.
The inverse applies to `QBCore:Server:SetDuty` and
`QBCore:Server:OnPlayerUnload`, which qbx_core emits locally via
`TriggerEvent` — those want `AddEventHandler`, and they receive the player
source as the **first argument**, not via the ambient `source` global.

**A third-party `download_file`/`download_github` task 404s or times out.**
This recipe pulls every third-party resource from its own upstream source
at deploy time rather than vendoring it, which means a renamed repo, a
removed release asset, or a temporary GitHub outage on the upstream side
will break that one task. Check the specific project's current repository
URL/release page and update the corresponding task in
`recipes/imperial-city-qbox.yaml` — this is expected maintenance for any
recipe built this way, not a bug in this project's own code.

## Boot / startup order

**A resource fails to start with "could not find export" or similar.**
Run `python3 tools/verify_startup.py` from the repository root — it parses
`server.cfg.template` and every custom `fxmanifest.lua`'s `dependencies{}`
block and will name the exact resource that's ensured before something it
depends on. If it passes but the server still shows the error, check
whether the *third-party* resource providing that export failed to start
for an unrelated reason (check its own console output above the error).

**`imperial_*` resources silently do nothing.**
Almost every custom resource hard-depends on `imperial_logging` — if it
failed to start (check for an oxmysql connection issue, since
`imperial_logging` needs the database for its log flush and KV store),
every resource that calls into it will find its exports missing and fail
whatever check depends on them. `imperial_logging` should always be the
first custom resource in your console's start order — confirm that first.

## Runtime

**A gang-gated feature (crafting bench, turf action, drug lab access)
rejects a player who should have access.**
Confirm `imperial_gangs` is actually running (`GetResourceState`) — several
integrations fail closed (deny access) rather than silently allow when
`imperial_gangs` isn't started, by design (see `docs/18-security.md`). Also
confirm the player's rank via `imperial_gangs:GetMemberRank` meets the
bench/action's configured minimum — dynamic gang rank is *not* the same as
qbx_core's static `PlayerData.gang.grade`, and a bench configured with
`restrict.gang['*']` is checking the former.

**Business wages/lease billing didn't run, or ran twice, after a restart.**
Check `imperial_kv` for the relevant timestamp key
(`biz:lastLeaseRun` for leases) — the cron logic in
`imperial_businesses/server/cron.lua` is guarded by this key specifically
so restarts can't double-charge or skip a cycle. If the key is missing or
stale, that's the first thing to inspect; it should not require manual
intervention under normal operation.

**Audit log growing faster than expected / Discord webhook spam.**
Check `imperial:webhook_audit` — only severity ≥ 3 (`suspicious`/`critical`)
entries mirror to Discord by default. If you're seeing high-volume webhook
traffic, something is generating a lot of `LogSuspicious` calls, which
usually means either a misconfigured rate limit somewhere or an actual
exploit attempt in progress — check `imperial_logs` for the specific
`action` values generating the volume.

**A player reports an action "did nothing" with no error.**
Check whether they hit a rate limit (`imperial_logging:RateLimit` fails
silently from the player's perspective by design, to avoid revealing exact
limit values to a would-be exploiter) or a held lock from an earlier
disconnected session that hasn't expired yet (`AcquireLock`'s TTL is the
safety net — check the specific resource's lock TTL if a player reports
being "stuck" after a disconnect; it should self-clear within that TTL).

## Performance

See `docs/23-performance-review.md` for expected thread/tick behaviour. If
a server-wide slowdown correlates with active turf contests, see that
document's guidance on `tickIntervalSec`/`maxCountedParticipants` — those
are the two knobs that most directly trade turf-system fidelity for load.

## Still stuck?

Check the specific resource's own `README.md` first (each one documents its
exports, config, and a resource-scoped test checklist), then
`docs/18-security.md` for anything that looks like it might be an
intentional server-authority rejection rather than a bug.
