# 16 — Farming (`imperial_farming`)

## The loop

```text
seed → plant → water → fertilise (optional) → grow → harvest → produce_box → wholesale sale
                                                              └▶ or feed business recipes directly
```

Twelve crops are configured by default (wheat, corn, tomato, potato,
lettuce, orange, apple, coffee, sugarcane, herbs, cotton, grape), each with
its own seed item, growth time, yield range, and seed-return chance on
harvest. Produce feeds both the wholesale NPC buyer (`sellBoxes`,
`imperial:econ:pay:produce_box`) and — via ox_inventory items shared with
`imperial_businesses`' hospitality recipes (`herbs`, `coffee_beans`, etc.) —
player-owned businesses directly, so farming is a real upstream supplier to
the business economy, not an isolated minigame.

## Restart-safe, timestamp-derived state

Unlike a naive implementation that would run a growth thread per plant (or
one global thread ticking every plant every N seconds — still a cost that
scales with plant count), `imperial_farming` stores only two timestamps per
plant row (`planted_at`, `watered_at`) plus a `fertilised` flag and a
`health` value, and computes growth stage, current health, and maturity
**lazily, only when something reads it** (see `derive()` in
`resources/[custom]/imperial_farming/server/main.lua`). This means:

- Zero threads scale with plant count — thread count in this resource is
  fixed regardless of how many plants exist server-wide (see
  `docs/23-performance-review.md`).
- A server restart loses no state and needs no catch-up pass: the next read
  simply recomputes from `os.time()` against the stored timestamps as if the
  server had never gone down. A plant that would have gone unwatered for two
  hours during a restart window is exactly as unhealthy on the next read as
  it would have been had the server never stopped.

## Zones, spacing, and caps

Planting is restricted to configured circular zones (`ImperialFarming.zones`
— Grapeseed Fields, Paleto Farmland, Elysian Allotments by default),
re-validated server-side on every planting attempt (never trusting a
client-reported "I'm in the zone" claim). A minimum spacing check
(`minSpacing`) prevents crowding plants into an unrealistic dense grid, and
a per-player live-plant cap (`maxPlantsPerPlayer`) bounds both griefing
potential and the eventual per-player row count in `imperial_farm_plants`.

## Watering, fertilising, and health decay

Plants need re-watering every `waterIntervalMinutes`; each missed interval
costs `missedWaterHealthLoss` health (derived lazily, same as growth stage).
A dead plant (health reaches 0) yields nothing on harvest and is removed.
Fertilising (once per plant, requires `fertiliser` or `weed_nutrition`) boosts
final yield quality by a flat multiplier.

## Harvest: an atomic delete-first claim

`harvest` deletes the plant row **before** computing and granting yield
(`MySQL.update.await('DELETE FROM imperial_farm_plants WHERE id = ?', ...)`,
checking `affected > 0`), rather than checking maturity/ownership and then
deleting afterward. This is the same atomicity pattern documented in
`docs/18-security.md`: two players attempting to harvest the same mature
plant in the same instant can't both succeed, because only one `DELETE` can
ever affect a row that only exists once.

## Theft

If `allowTheft` is enabled, a non-owner can harvest someone else's mature
plant, at a reduced yield (`theftYieldMultiplier`) and a chance
(`theftDispatchChance`) of triggering an `imperial_dispatch:CreateDispatchCall`
crop-theft alert to police — giving farming a light criminal-interaction
surface without requiring a dedicated theft system.

## Capacity handling

If a harvesting player can't carry the yielded produce
(`ox_inventory:CanCarryItem` fails), the plant row is **re-inserted** with
its original state rather than the crop being silently voided — the harvest
attempt fails cleanly and the plant remains harvestable later, rather than
punishing a player for a full inventory.

## Maintenance

A daily sweep prunes any plant older than 7 days that's still un-harvested
(`sql`-level `DELETE ... WHERE planted_at < NOW() - 7 days`), preventing
long-abandoned plants from accumulating indefinitely in the table.
