# 23 — Performance Review

Companion to `docs/18-security.md` for Phase 9. Since no FXServer instance
was available to profile live (see the environment note in
`docs/19-testing.md`), this is a static review of every long-running thread,
every tick interval, and every query pattern in the `imperial_*` suite,
checked against the master requirement: **no zero-millisecond loops, no
idle polling that scales with player count faster than necessary, no
unbounded per-frame client work.**

## Server-side threads

Every `CreateThread`/`while true do ... Wait(n) ... end` loop in the custom
suite, with its interval and cost per tick:

| Resource | Purpose | Interval | Cost per tick |
|---|---|---|---|
| imperial_logging | Batched audit-log flush | `flushIntervalMs` (config, default a few seconds) | One batched multi-row insert, size-bounded by queue; not one insert per log line. |
| imperial_logging | Rate-limit/lock table sweep | 300000ms (5 min) | O(active keys) table prune, in-memory only. |
| imperial_dispatch | Duty safety poll | 30000ms | One `GetQBPlayers()` pass; O(online players), no DB query. |
| imperial_fire | Duty safety poll | 30000ms | Same shape as dispatch. |
| imperial_fire | Automatic incident spawner | random 240000–480000ms (4–8 min) | Single spawn decision, capped at 2 concurrent incidents — the randomised interval also avoids every fire-enabled server on a shared box ticking in lockstep. |
| imperial_fire | Incident escalation/abandonment sweep | 30000ms | O(active incidents), small (incidents are capped). |
| imperial_drugs | Contamination/raid-risk sweep | `raidCheckIntervalSec` (config) | O(labs) with one `COUNT(*)` per lab; lab count is a small, fixed, config-defined set, not player-scaled. |
| imperial_turfs | Capture-progress tick | `tickIntervalSec` (config, default tens of seconds) | O(turfs × online players) — see "Turf presence scanning" below. |
| imperial_turfs | Income cycle | `incomeIntervalMin` (config, minutes) | O(turfs), one `AddGangFunds` call per owned turf. |
| imperial_businesses | Wage cycle | `wageCycleMinutes` (config) | O(businesses × on-duty employees). |
| imperial_businesses | Lease billing cron | dynamic (sleeps until the next scheduled run, capped at 1h re-checks) | O(businesses), guarded by an `imperial_kv` timestamp so a restart never double-bills or skips a cycle. |
| imperial_businesses | POS invoice expiry sweep | 30000ms | O(pending invoices), typically near-zero. |
| imperial_gangs | Founding-session expiry sweep | 30000ms | O(in-progress founding sessions), typically near-zero. |
| imperial_sidejobs | Depleted-node table prune | 3600000ms (1h) | O(depleted nodes), in-memory only. |
| imperial_farming | Dead-plant prune | 6h | One bounded `DELETE ... WHERE planted_at < ...` query. |

No thread anywhere uses `Wait(0)`. No thread re-derives full world state every
tick when a cheaper cached/timestamp-derived approach was available (see
"Restart-safe timestamp state" below).

## Turf presence scanning (the one O(turfs × players) loop)

`imperial_turfs`' capture tick is the only loop whose cost genuinely scales
with concurrent player count, because presence must be measured from real
server-side positions (see `docs/18-security.md` — trusting client presence
claims would defeat the whole point of a contested-zone system). This is
deliberately bounded on both axes:

- **Turfs**: a fixed, config-defined zone list — not something that grows
  with players or gangs. Typical deployments will have single-digit-to-low-
  double-digit turf counts.
- **Players per turf check**: `presenceCount()` breaks out of its scan early
  once it hits `maxCountedParticipants`, so a crowded zone doesn't cost more
  than the cap regardless of how many players are actually standing there.
- **Only contested turfs are scanned per tick** — the loop skips any `row`
  without `contested_by_gang_key` set, so an idle server with no active
  turf war does zero presence-scanning work.
- **Tick interval is config-controlled** (`tickIntervalSec`) specifically so
  operators can trade capture-progress granularity for server load on
  lower-spec hardware.

At realistic FiveM player counts (tens to low hundreds) and realistic
concurrently-contested-turf counts (rarely more than one or two at once),
this loop is one `GetQBPlayers()` iteration with a coordinate distance check
per online player, per contested turf, per tick — negligible relative to
FXServer's normal per-frame budget.

## Restart-safe timestamp-derived state

`imperial_farming` (plant growth/health) and `imperial_drugs` (batch stage
readiness) both deliberately avoid a "growth thread" pattern (a loop per
plant/batch ticking state forward) in favour of storing a timestamp
(`planted_at`, `watered_at`, `stage_ready_at`) and computing the current
derived state lazily, only when something actually reads it (a sync
callback, an advance/harvest attempt). This means:

- Thread count does **not** scale with the number of planted crops or active
  drug batches — there is no per-entity thread at all.
- A server restart loses no state and requires no catch-up pass — the next
  read simply recomputes from `os.time()` against the stored timestamp as if
  the server had never stopped.

## Client-side cost

- Bench/plant/node zones use `lib.points` (ox_lib's distance-bucketed point
  system) rather than a raw per-frame distance-check loop against every
  possible interaction point in the world — points only become "active"
  (spawning props, registering ox_target zones) once the player is within
  the configured trigger radius.
- `imperial_farming`'s client sync (`getNearbyPlants`) runs on a config
  interval (`syncIntervalMs`), not per-frame, and is server-rate-limited
  independently as a second line of defence against a modified client
  calling it more often.
- `imperial_turfs` and `imperial_boosting` client-side polling loops
  (turf-state refresh, contract countdown) run on 1–60s intervals, never
  per-frame.
- No custom resource in this suite uses a `CreateThread` with `Wait(0)` or
  `Wait(1)` on either client or server.

## Database

- Every hot-path query is indexed on its lookup key: `imperial_farm_plants`
  by spatial bounding box (used by the nearby-plants sync — see
  `sql/007_farming.sql`), `imperial_drug_batches`/`imperial_business_txns`/
  `imperial_gang_txns` by their foreign-key id, `imperial_launder_jobs` and
  `imperial_boosting_reputation` by `citizenid`.
- The audit log (`imperial_logs`) is the only high-volume write path;
  `imperial_logging` batches inserts into periodic multi-row flushes rather
  than one `INSERT` per log call, specifically to keep this from becoming a
  query-count problem under load.
- No query in the custom suite performs an unbounded `SELECT *` without
  either a `WHERE` on an indexed column or a small fixed `LIMIT` (ledger
  reads are paginated at 25 rows).

## Recommendations for operators

- On a shared/low-spec box, raise `imperial_turfs`' `tickIntervalSec` and
  lower `maxCountedParticipants` first if turf wars are the busiest custom
  system on a given server — those are the two knobs that most directly
  trade fidelity for load.
- Keep `imperial:debug` off in production (see `recipes/misc.cfg`) — several
  resources gate verbose console output behind it.
- The Discord webhook mirror (`imperial:webhook_audit`) only fires for
  severity ≥ 3 log entries by default; this is intentional so routine
  gameplay logging doesn't generate Discord API traffic.
