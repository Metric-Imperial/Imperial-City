# imperial_sidejobs

Session-based civilian side jobs that complement the first-party qbx job set
(taxi/trucker/tow/garbage/bus/news/recycle/mechanic/diving). None of these set
the player's framework job — no job-state pollution; anyone can work them with
the right tools, and qbx_cityhall remains the formal employment office.

## Jobs
- **Fishing** — rod (degradable) + bait at fishing spots; skill check; weighted
  server-side catch table; per-cast cooldown.
- **Mining** — pickaxe at ore-specific nodes: stone, coal, copper, iron and gem,
  each with its own boulder, its own four sites and a guaranteed yield. The
  swing is a skill check, not a fixed timer. A worked node *despawns* and
  returns after 60s (server-tracked, synced to all clients). No map blips —
  sites are meant to be found.
- **Smelting** — fixed smelters at the copper and iron sites turn
  `iron_ore`/`copper_ore` into `iron`/`copper`, 2:1, 1 coal per ingot. Batched
  and timed (90s/ingot): ore and coal are committed up front, then collected
  later, so it persists across logout and restart. One batch per player per
  furnace. Custom `imperial_smelter` prop with an emissive firebox and looped
  chimney smoke; prop and particle effect both stream with player distance.
- **Mine access** — teleport through the rock face at the iron site. Entrance
  and exit markers are under a metre apart, so each is gated on whether the
  player is inside and only the applicable one is ever shown.
- **Jeweller** — ped on Portola Drive cuts `uncut_gem` into `emerald_gem` over
  real time (5 min/stone, $75/stone, 10 max). Orders live in
  `imperial_jeweller_orders` so they survive logout and server restarts.
- **Lumber** — felling axe at logging camp; logs → planks at the sawmill bench
  (imperial_crafting `saw_planks`).
- **Materials buyer** — sells fish/ore/timber for convar-priced cash
  (`imperial:econ:pay:*`).

## Security
- Every reward path is a server callback with distance validation, tool checks,
  rate limits and audit logs. Catch/ore tables and prices are server-only.
- Node depletion is authoritative server state — clients only render it.

## Test checklist
- [ ] Fishing outside spots rejected + logged; bait consumed per cast.
- [ ] Fishing plays the cast swing then the wait idle, rod in hand throughout.
- [ ] Fishing skill check prompts are 1-4, not letters.
- [ ] Two miners on one node: second gets 'depleted'.
- [ ] Failed mining skill check leaves the node workable; tool still wears.
- [ ] Mining with full bags does not burn the node.
- [ ] Smelt batch clamps to the lowest of ore, coal and the furnace cap.
- [ ] Second batch in the same furnace rejected while one is pending.
- [ ] Smelt order survives a server restart and is still collectable.
- [ ] Mine entrance and exit never offer both options at once.
- [ ] Jeweller: second batch while one is pending rejected ('busy').
- [ ] Jeweller: collect before ready reports remaining time, pays nothing.
- [ ] Jeweller order survives a server restart and is still collectable.
- [ ] Selling clamps to owned count; convar prices honoured.
