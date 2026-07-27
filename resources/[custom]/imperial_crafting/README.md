# imperial_crafting

The single crafting authority for the server: config-driven benches and
recipes, per-category XP with levels, blueprint unlocks, batch crafting, skill
checks, failure states, criminal benches with dispatch risk, and full audit
logging. Farming processing stations and criminal workbenches are ordinary
benches with category and restriction config — one system, no duplicates.

## Security model
- Client requests `(benchId, recipeId, count)` only. Recipes, ingredients,
  outputs, timing floors, XP, unlocks, fail chances: all server-side.
- Time floor: the server refuses completions before `duration - 500ms`.
- Ingredient removal and capacity checks happen at completion, re-validated.
- Per-player craft lock prevents parallel sessions; rate-limited requests.
- Hidden/criminal benches can require gang membership (static or via
  imperial_gangs), a keycard item, or category level; each craft may ping
  imperial_dispatch with a configurable chance.

## Config
- `config/shared.lua` — XP curve, batch cap, rate limits.
- `config/benches.lua` — bench id/label/coords/prop/categories/restrict/blip.
- `config/recipes.lua` — recipes (see header for schema).

## Exports (server)
- `GetLevel(citizenid, category) -> number`
- `HasUnlock(citizenid, recipeId) -> boolean`
- `UseBlueprint(...)` — ox_inventory item handler for `blueprint`.

## Callbacks
- `imperial_crafting:getBenchMenu (benchId)` — recipes visible to the player.
- `imperial_crafting:startCraft (benchId, recipeId, count)` — begins session.
- `imperial_crafting:finishCraft (skillCheckPassed)` — resolves session.

## Database
`sql/005_crafting.sql`: `imperial_crafting_xp`, `imperial_crafting_unlocks`.

## Test checklist
- [ ] Craft succeeds with ingredients; ingredients removed exactly once.
- [ ] Finishing early (modified client) is rejected and logged (severity 3).
- [ ] Restricted benches refuse wrong job/gang/level/keycard.
- [ ] Blueprint use unlocks recipe once; second blueprint refused.
- [ ] Failure chance consumes materials, grants reduced XP.
- [ ] Batch crafting respects capacity; overflow rejected before grant.
- [ ] Dispatch pings fire from criminal benches at configured chance.
