# 19 — Testing

## Status

No FXServer instance was available in the environment this recipe was
authored in, so **everything in this document is a checklist to execute
before go-live, not a report of tests already run.** Correctness work to
date consists of: static code review (`docs/18-security.md`), a custom
structural Lua validator (`tools/luacheck.py`), a startup-dependency-order
verifier (`tools/verify_startup.py`), and manual verification of every
third-party API call against fetched upstream documentation. This checklist
is the gap between that and a real go-live decision.

Each custom resource's own `README.md` also carries a short test checklist
scoped to that resource; this document is the server-wide plan that ties
them together, plus scenarios that only show up with two or more players.

## Installation tests

- [ ] Fresh deploy via `recipes/imperial-city-qbox.yaml` completes with no
      task failures.
- [ ] `SELECT * FROM imperial_migrations ORDER BY id;` shows all 12 rows.
- [ ] Server boots with zero "could not find resource" / dependency-order
      warnings (cross-check against `tools/verify_startup.py`'s output,
      which should already have caught this pre-deploy).
- [ ] Re-running the same recipe against an already-migrated database is a
      no-op on schema/seed data (idempotency check — see `docs/07-database.md`).

## Character lifecycle tests

- [ ] New character creation grants the starter package exactly once.
- [ ] Logging out and back in, or reconnecting mid-session, does **not**
      re-grant the starter package (KV-claim-before-grant — see
      `imperial_character`'s README).
- [ ] Multicharacter: creating a second character on the same account gets
      its own independent starter grant and does not share state with the
      first.
- [ ] Spawn-rescue only fires for genuinely broken positions, not for a
      player who is legitimately standing still (rate-limited 3/60s).

## Inventory / crafting tests

- [ ] Crafting a recipe with sufficient ingredients succeeds and grants
      exactly the configured output.
- [ ] Starting a craft, then trading/dropping a required ingredient before
      the craft timer completes, correctly fails the craft **without**
      consuming any ingredients (the Phase 9 fix — see `docs/18-security.md`).
- [ ] A recipe with a skill check: failing the check consumes half
      ingredients (rounded up) and does not grant output.
- [ ] Capacity check: attempting to craft output the player can't carry
      fails cleanly with ingredients intact.
- [ ] Business-registered recipes (hospitality/mechanic) are only visible/
      usable to employees with the correct business permission.

## Job / business tests

- [ ] Civilian side jobs (fishing/mining/lumber/construction/secure
      transport) pay out correctly and cannot be re-triggered faster than
      their configured rate limits.
- [ ] `GetBusiness`/`IsBusinessEmployee`/`HasBusinessPermission` return
      correct values for owner, manager, and regular-employee ranks.
- [ ] POS charge: customer confirmation is required; an expired invoice
      (>60s unconfirmed) cannot be paid.
- [ ] Business withdraw by a player who disconnects mid-flow rolls the
      debit back into the business account rather than losing the funds.
- [ ] Wage cycle only pays on-duty employees, not all employees.
- [ ] Lease billing survives a server restart without double-charging or
      skipping a cycle (KV-timestamp guard).

## Emergency services tests

- [ ] Duty toggling is reflected correctly in dispatch routing within one
      safety-poll cycle even if the duty event itself is missed/forged.
- [ ] `CreateDispatchCall` only notifies on-duty players of the listed jobs.
- [ ] Fire incidents: each configured type (vehicle/structure/hazmat/
      rescue/rtc) spawns, escalates if ignored, and is cleaned up on
      abandonment; concurrent-incident cap is respected.
- [ ] MDT: department scope is correctly derived from real job/grade/duty —
      a police-job player cannot see EMS-only report categories and vice
      versa, and a non-duty employee cannot access MDT at all.

## Criminal / gang / turf tests

- [ ] Drug lab stages advance only after their configured duration and
      cannot be advanced early by repeated client requests.
- [ ] Police raid seizes all batches at a lab and resets contamination.
- [ ] Fencing refunds goods (does not consume them) if the payout can't be
      carried.
- [ ] Laundering: only one active launder job per player; collection is
      claimed atomically (two rapid collect attempts can't both pay out).
- [ ] Boosting: delivering a different vehicle of the same model as the
      registered one is rejected (network-id binding).
- [ ] Gang founding requires the configured minimum nearby members within
      the founding window; a founding session started but not finalised in
      time expires cleanly.
- [ ] Turf contest: cannot be declared without minimum attacker presence in
      the zone; capture progress only accrues after the declaration delay;
      defender presence reverses progress; an untouched contest auto-cancels.

## Two-player / exploit tests

- [ ] Two players attempting to harvest the same mature farm plant
      simultaneously — only one succeeds.
- [ ] Two players attempting to collect the same laundering job
      simultaneously — only one succeeds.
- [ ] A player attempts to call a business/gang money callback for a
      business/gang they are not a member of — rejected.
- [ ] A player spams a rate-limited callback well past its configured
      max/window — rejected after the limit, with no partial side effects
      from the rejected calls.
- [ ] A player attempts to trigger `imperial_*` server events directly
      (bypassing the intended client flow) with forged/missing arguments —
      every handler either ignores the payload and re-derives truth, or
      rejects invalid input without side effects (see the `RegisterNetEvent`
      table in `docs/18-security.md`).
- [ ] A player disconnects mid-flow in each multi-step system (crafting,
      boosting, secure transport, business POS as the customer) — no
      dangling lock, no partial resource consumption, no orphaned server
      state left behind.

## Sign-off

This checklist should be run in full (single-player pass, then a
two-player pass for the exploit section) before treating this recipe as
production-ready for a public server, per the master requirement not to
claim completion without testing.
