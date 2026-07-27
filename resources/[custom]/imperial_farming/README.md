# imperial_farming

Full farming loop: acquire seeds → plant in farmland zones → water → fertilise
→ lazy growth → harvest → process at crafting stations (grain mill, packing
table via imperial_crafting) → wholesale or supply businesses.

## Design
- **Restart-safe by construction** — plants live in `imperial_farm_plants`;
  growth/health are *derived from timestamps* on read. No growth threads, no
  state loss on restart.
- **Server authority** — planting (zone, spacing, per-player cap, seed
  removal), watering, fertilising and harvest (atomic delete-first claim, so
  two players can never double-harvest) are all validated server-side with
  distance checks and rate limits.
- **Theft** — configurable; thieves get a reduced yield and risk a police
  dispatch. Harvests and thefts are audit-logged.
- **Client cost** — props stream only inside farming zones via `lib.points`;
  a 20 s sync poll runs only while plants are rendered. Zero idle cost elsewhere.
- **Supply chain** — produce feeds `pack_produce_box` / `mill_flour` /
  `press_sugar` recipes (imperial_crafting) and business ingredient storage
  (imperial_businesses).

## Callbacks
`plant`, `getNearbyPlants`, `water`, `fertilise`, `harvest`, `sellBoxes` —
all under the `imperial_farming:` prefix, all rate-limited.

## Config
`config/shared.lua`: zones (circle), crop table (seed/produce/growth/yield/
seed-return), watering cadence, theft rules, wholesaler, stage props.
Wholesale price: convar `imperial:econ:pay:produce_box`.

## Test checklist
- [ ] Planting outside zones/limit/spacing rejected.
- [ ] Growth persists across restart; stage advances by wall-clock.
- [ ] Missed watering reduces yield; dead plants yield nothing.
- [ ] Two players harvesting same plant → exactly one succeeds.
- [ ] Theft yields reduced amount and can ping dispatch.
- [ ] Capacity-full harvest refunds the plant (no crop void).
