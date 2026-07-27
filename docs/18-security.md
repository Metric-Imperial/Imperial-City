# 18 — Security Review

This document records the Phase 9 security review of every `imperial_*` custom
resource. It is not a substitute for testing against a live server (no
FXServer was available in the authoring environment — see `docs/19-testing.md`
for the manual/two-player test plan that must be run before go-live), but it
is a systematic, resource-by-resource audit of every place client input
reaches server code.

## Method

1. Swept the whole custom-resource tree for raw SQL string concatenation
   (`grep` for `MySQL.*..*` patterns feeding query strings from client-derived
   variables). **Result: none found.** Every query in `sql/` and every runtime
   query in `server/*.lua` uses `?` placeholders with a parameter table.
2. Reviewed every `RegisterNetEvent` handler (fire-and-forget events, as
   opposed to `lib.callback.register` request/response handlers) individually,
   since these have no return value forcing the client to wait for
   validation — a careless one can be fired repeatedly with no feedback loop
   telling the attacker they've been rejected.
3. Reviewed every `lib.callback.register` handler for: server-side
   re-derivation of identity/job/gang/duty (never trusting a client-declared
   value for anything that gates money, items, or permissions), distance/zone
   validation, rate limiting on anything that can be spammed, and — the class
   of bug this review specifically went looking for after finding one —
   **whether a later stage of a multi-step flow re-validates state that could
   have changed since an earlier stage checked it** (trading, dropping items,
   or disconnecting during a timed window between two callbacks).
4. Reviewed every money-movement code path for atomicity (guarded
   `UPDATE ... WHERE balance >= ?` rather than read-then-write) and for
   ledger/audit coverage.

## Findings

### Fixed during this review

**`imperial_crafting` — partial ingredient consumption on failed craft.**
`finishCraft` runs after the crafting duration has elapsed (client reports
completion; server enforces a time floor via `GetGameTimer()`). It only
validated ingredient sufficiency once, at `startCraft` time — several seconds
to a couple of minutes before `finishCraft` actually removes them. Because
`removeIngredients` loops per-ingredient and returns `false` on the first
`RemoveItem` failure **without rolling back ingredients already removed** in
the same loop, a player who traded away, dropped, or otherwise spent one
ingredient mid-craft could have some — but not all — of a recipe's materials
silently consumed on a run that was reported to them as "failed: ingredients".
Fixed by adding a `hasIngredients()` re-check immediately before
`removeIngredients()` in `finishCraft`, with a `LogSuspicious` audit entry for
the (should-be-unreachable) case where inventory state changes in the small
window between the re-check and the removal itself (e.g. a concurrent trade
racing the same tick). See commit `94d424a`.

The same class of bug was checked for and **not found** elsewhere:
`imperial_drugs`' `advanceBatch` checks and removes stage ingredients back to
back with no `Wait`/timer between the check and the removal (no window for
state to change), and `imperial_farming`'s harvest uses an atomic
delete-first claim rather than a check-then-consume pattern.

### Reviewed, no issues found

**`RegisterNetEvent` handlers** (5 across the codebase — everything else uses
`lib.callback.register`, which is preferred throughout for anything that
needs a validated response):

| Handler | Resource | Why it's safe |
|---|---|---|
| `server:vehicleEntered` | imperial_boosting | Ignores all client payload; only reads `source`, looks up server-held contract state, re-reads the player's real ped position server-side for the dispatch call coords. |
| `server:requestSpawnRescue` | imperial_character | Rate-limited (3/60s); re-derives the player's actual position server-side and only honours the request if that position is genuinely outside any known safe volume — a client can't teleport itself anywhere by calling this repeatedly. |
| `server:panic` | imperial_dispatch | Client sends no data; server re-reads the real job via `exports.qbx_core:GetPlayerData()`-equivalent server lookup, not a client-declared job string. |
| `QBCore:Server:SetDuty` relay (×2: imperial_dispatch, imperial_fire) | imperial_dispatch, imperial_fire | Never trusted as the sole source of truth — each resource also runs a periodic (30s) safety poll that re-derives duty state from live `GetQBPlayers()`/`PlayerData`, so a forged or missed event self-corrects within one poll cycle. |

**Money movement** — every business/gang financial exports/callback
(`BizAdjust`/`gangAdjust`, `deposit`, `withdraw`, `pos:charge`/`pos:respond`,
`imperial_blackmarket:collectLaunder`) uses either a guarded conditional
`UPDATE ... WHERE balance >= ?` (rejecting the write atomically instead of
read-check-write) or a guarded claim `UPDATE ... WHERE collected = 0` before
paying out, and every debit/credit writes a ledger row plus an audit log
entry. `imperial_businesses:withdraw` and `imperial_gangs:withdraw` both
roll the ledger back if the paying-out player has disconnected between the
debit and the `AddMoney` call, so funds are never lost into a vanished
session.

**Distance/zone validation** — every proximity-gated callback
(crafting benches, farming plots, drug labs, business POS/stashes, side-job
nodes/depots, turf contests, dispatch panic) re-checks the player's real
server-side ped position against the relevant coordinate/zone every time,
never trusting a client-supplied "I'm at X" claim.

**Rate limiting** — every action that could be spammed for gain (crafting
starts, farming actions, side-job gathers/sales, drug batch starts/advances,
fencing, laundering starts, business POS charges/deposits/withdrawals, gang
deposits/withdrawals, turf contest declarations) is rate-limited via
`imperial_logging:RateLimit`, keyed by license identifier so it survives a
client reconnect with a new server id.

**Locks** — multi-step flows that must not be re-entered concurrently by the
same player (crafting, boosting contracts, secure transport, farm harvest)
use `imperial_logging:AcquireLock`/`ReleaseLock` with a TTL safety net, so a
crashed client or a dropped connection mid-flow can't permanently wedge a
player out of the action (the lock expires) and can't be double-fired by
rapid repeat requests before the first completes.

**Vehicle-identity binding** (`imperial_boosting`) — the contract is bound to
a specific network id captured at `registerVehicle` time via
`ValidateNetEntity` (checks the entity exists, matches the expected model,
and is within range of the player), and `deliver` re-validates against that
*same* network id rather than "any vehicle of the right model near the
dropoff" — this specifically prevents swapping in a different vehicle of the
same model to fake a delivery.

**Dead code removed** during earlier passes (not a vulnerability, but noted
here since it was found during this same audit sweep): a stray
`local rank = exports.imperial_gangs and nil` no-op in
`imperial_gangs:HasGangPermission`, and a similar dead placeholder line in
`imperial_turfs`' capture-resolution branch — both removed.

### Known limitations / accepted risk (not blocking)

- **`imperial_fire`'s dual `QBCore:Server:SetDuty` handler ordering.** Two
  separate handlers are registered for the same event (one per department
  concern) using different short timeouts (200ms / 400ms) to sequence
  side-effects. This is timing-fragile in principle; in practice the 30s
  safety poll self-corrects any misordering within one cycle, so the impact
  of a misfire is bounded and temporary. Recommended follow-up (not
  implemented): merge into a single handler with explicit ordering rather
  than relying on relative timeout values.
- **Fail-chance/skill-check ingredient penalty** (`imperial_crafting`) does
  not re-check `CanCarryItem`/sufficiency before removing the "half
  ingredients" skill-check-fail penalty — if `RemoveItem` can't remove the
  full penalty amount it silently removes less. This under-penalizes rather
  than over-penalizes or errors, so it was accepted as low-severity.
- **No FXServer smoke test was run.** Every finding above comes from static
  code review against the documented ox_inventory/qbx_core/oxmysql APIs, not
  from exercising the code on a running server. `docs/19-testing.md`'s
  checklist must be executed (single-player and two-player/exploit passes)
  before this recipe is treated as production-ready — this review reduces
  but does not eliminate the need for that pass.

## Standing security rules enforced throughout

- Every custom event/export is namespaced `imperial_*` — no ambiguity with
  third-party resource events.
- Every server-side handler treats its `src`/client payload as untrusted:
  identity (`citizenid`), job, job grade, gang, gang rank, and duty are
  always re-derived from `exports.qbx_core`/`imperial_gangs` server state,
  never taken from a client-supplied argument.
- Admin-only commands (`/turfset`, `/bizowner`, MDT admin actions) are gated
  by ACE permission (`group.admin`), not by job/grade alone.
- `imperial_logging:LogSuspicious` is used specifically for events that
  indicate a client is sending values that shouldn't be reachable through
  normal play (e.g. `craft_time_floor`, `craft_partial_removal`,
  `biz_withdraw_denied`, `fish_outside_spot`), and mirrors to Discord for
  severity ≥ 3 so operators get a live feed of exploit attempts rather than
  having to poll the DB.
