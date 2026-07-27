# imperial_sidejobs

Session-based civilian side jobs that complement the first-party qbx job set
(taxi/trucker/tow/garbage/bus/news/recycle/mechanic/diving). None of these set
the player's framework job — no job-state pollution; anyone can work them with
the right tools, and qbx_cityhall remains the formal employment office.

## Jobs
- **Fishing** — rod (degradable) + bait at fishing spots; skill check; weighted
  server-side catch table; per-cast cooldown.
- **Mining** — pickaxe at quarry nodes; shared node depletion with respawn
  timers (server-tracked, synced to all clients).
- **Lumber** — felling axe at logging camp; logs → planks at the sawmill bench
  (imperial_crafting `saw_planks`).
- **Construction** — carry-materials task loop with per-task wage + shift bonus.
- **Secure transport** — server-spawned armoured van, randomised multi-stop
  case collection in enforced order, payout on depot return. Vehicle deleted
  and lock released on completion, abandon, or disconnect.
- **Materials buyer** — sells fish/ore/timber for convar-priced cash
  (`imperial:econ:pay:*`).

## Security
- Every reward path is a server callback with distance validation, tool checks,
  rate limits and audit logs. Catch/ore tables and prices are server-only.
- Node depletion is authoritative server state — clients only render it.
- Transport stops must be collected in the server-chosen order; payout counts
  only server-confirmed collections.
- Disconnect/unload clears shifts and runs, deletes the run vehicle.

## Test checklist
- [ ] Fishing outside spots rejected + logged; bait consumed per cast.
- [ ] Two miners on one node: second gets 'depleted'.
- [ ] Construction deliver without pickup rejected.
- [ ] Transport payout equals collected stops only; abandoning pays nothing.
- [ ] Selling clamps to owned count; convar prices honoured.
