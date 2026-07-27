# 10 — Business Catalogue

All businesses run on `imperial_businesses` (see its README for the API).
Seed businesses ship in `resources/[custom]/imperial_businesses/config/businesses.lua`;
add a new business by appending an entry there and inserting no code.

| Key | Label | Type | Weekly Lease | Crafting Bench | Notes |
| --- | ----- | ---- | ------------ | -------------- | ----- |
| `beanmachine` | Bean Machine Coffee | cafe | $1,750 | Barista Station (hospitality) | POS x1 |
| `burgershot` | Burger Shot | restaurant | $2,500 | Kitchen Station (hospitality) | POS x2 |
| `vanillaunicorn` | Vanilla Unicorn | nightclub | $3,000 | — | door POS |
| `bennys` | Benny's Original Motorworks | mechanic | $2,800 | Fabrication Bench (mechanical, repair) | shares imperial_crafting mechanical recipes |
| `ltdgrove` | LTD Grove Street | store | $1,200 | — | general goods POS |
| `pacificfreight` | Pacific Freight & Logistics | logistics | $2,200 | — | warehouse storage, no POS (B2B) |
| `grapeseedfarm` | Grapeseed Growers Co-op | farm | $1,400 | — | ingredient storage feeds imperial_farming produce |
| `dynasty8` | Dynasty 8 Real Estate | realestate | $2,000 | — | management-only; pairs with qbx_properties realtor role |

## Adding a business
1. Append a site entry to `config/businesses.lua` (key, label, type, lease,
   management/duty/storage/pos coords, optional `craftingBench`, optional blip).
2. Restart `imperial_businesses` — the config→DB sync inserts the row and
   registers stashes automatically.
3. Assign an owner: in-game `/bizowner <key> <playerId>` (admin ACE) or via
   `imperial_businesses:transferOwnership` once an owner exists.

## Gun stores
Per server policy, gun-store type businesses are not seeded by default
(criminal-liability and platform-policy sensitive). Operators who want one can
add a `type = 'gunstore'` site and gate POS/stock behind a licence check
(`weaponlicense` item) in a thin wrapper around the POS callback — documented
here rather than shipped active.
