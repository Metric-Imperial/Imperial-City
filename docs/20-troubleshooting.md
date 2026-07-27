# 20 — Troubleshooting

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
