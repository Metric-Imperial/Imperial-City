# 24 — Item Catalogue Audit

Audit of `recipes/items.lua`, the consolidated ox_inventory item catalogue
that overrides `ox_inventory/data/items.lua` at deploy time (see
`recipes/imperial-city-qbox.yaml`). Base is the official Qbox-project
`items.lua` (103 items), extended with 69 Imperial-specific items grouped
under the `-- IMPERIAL ITEMS` marker, for 172 total.

## Method

A Python pass over the file checked: duplicate item keys (would silently
overwrite an earlier definition — a real bug, since ox_inventory keys the
whole catalogue by this field), duplicate display labels (a UX smell, not
necessarily a bug, but worth flagging since two items with the same on-
screen name confuses players), and cross-referenced every Imperial-added
item key against every `imperial_*` resource's config and code to find
items defined in the catalogue but never granted, consumed, or referenced
by any custom resource.

## Findings

### Duplicate keys: none

All 172 item keys are unique. A duplicate key would silently overwrite an
earlier definition in Lua table syntax — this was checked first since it's
the class of bug that would be easy to introduce while hand-editing a
900-line file and easy to miss without tooling.

### Duplicate labels: one found and fixed

`coffee` (the base drink item, weight 200) and `coffee_cup` (the item
`imperial_businesses`' `make_coffee` recipe produces from `coffee_beans` +
`water`) were both labelled **"Coffee"**. A player would see two visually
identical-looking inventory entries with no way to tell which is which.
Fixed: `coffee_cup`'s label changed to **"Fresh Coffee"** to distinguish
the business-made version from the base catalogue drink.

### Items defined but not referenced by any imperial_* resource: 8

These 69 Imperial-added items were cross-checked against every config and
server file under `resources/[custom]`. Eight showed no reference anywhere
in this repository's own code. Each is assessed individually below rather
than assumed to be dead weight, since several are plausible integration
points for third-party resources this recipe installs but doesn't author:

| Item | Assessment |
|---|---|
| `security_case` | Plausibly a loot container for the first-party `qbx_jewelery`/`qbx_pawnshop` robbery resources (third-party, outside this repo — cannot verify their item usage from here). Recommend leaving in the catalogue; low cost to keep. |
| `tracker_device` | Plausibly for `qbx_customs`/`qbx_vehicles` GPS-tracker features. Same reasoning as above — kept. |
| `rope_restraints` | Plausibly a police restraint tool consumed by `qbx_police`. Kept. |
| `weapon_parts` | Plausibly armory/robbery loot from `qbx_police` or the robbery suite (note: `imperial_crafting` does define an `ammo_components` output recipe, but nothing produces or consumes `weapon_parts` itself). Kept, flagged for a follow-up check once `qbx_police`'s actual item usage can be inspected against a running server. |
| `farming_hoe` | **Genuinely unwired.** `imperial_farming`'s planting/watering/fertilising flow does not check for this tool (only `watering_can` is checked, in `water()`). Likely an early-design intent (a farming tool item, mirroring the mining/lumber `pickaxe`/`lumber_axe` tool-check pattern) that was never connected to `plant()`. **Recommendation for a future change**: either wire a tool check into `imperial_farming:plant` the same way `imperial_sidejobs`' mining/lumber nodes check for a tool, or remove the item. Left in the catalogue for now since removing it is a design decision beyond the scope of a documentation-phase audit — flagged here rather than silently dropped or silently left unexplained. |
| `ingredient_box` | **Genuinely unwired.** Catalogue description reads "Bulk ingredients for hospitality businesses," but `imperial_businesses` has no restock/wholesale-purchase flow that grants or consumes it — employees are expected to place raw ingredients (`coffee_beans`, `water`, `herbs`, etc.) directly into business storage. Same recommendation as `farming_hoe`: either wire a bulk-restock purchase flow, or remove the item in a future pass. |
| `refined_product` | **Genuinely unwired, and inconsistent with the shipped design.** `imperial_drugs`' actual stage config (`config/shared.lua`) has an empty-ingredients "Refine Product" stage (stage 3) and the final collected output is the real sellable item (`meth`/`coke_brick`, matching `qbx_drugs`' own item set) — never `refined_product`. This item appears to be left over from an earlier design iteration where refining produced an intermediate physical item. |
| `product_package` | Same situation as `refined_product` — the final "Packaging" stage produces the real product item directly, not this placeholder. |

`refined_product` and `product_package` are the only two items in this
audit assessed as unambiguous dead catalogue entries with no plausible
third-party use (they're drug-production-stage placeholders, and
`imperial_drugs` is a wholly custom resource with no third-party consumer
of its intermediate items) — flagged here for removal in a future
migration/catalogue update rather than removed silently in this pass, so
the change is visible and reviewable rather than an unannounced deletion.

### Image assets: not verified

`ox_inventory` resolves each item's icon from `web/images/<key>.png` by
convention (see the note at the top of `recipes/items.lua`). Since
`ox_inventory` itself is downloaded from its own upstream source at deploy
time rather than vendored in this repository (see
`docs/02-installation.md`), there is no local `web/images/` directory in
this repo to check image files against, and no running server available in
this environment to render the inventory UI and spot missing icons visually.
**This must be verified after a live deploy** — check every Imperial-added
item (69 keys, listed in `RESOURCE_REGISTRY.md`'s custom-resource sections
and the `-- IMPERIAL ITEMS` block of `recipes/items.lua`) renders a real
icon rather than ox_inventory's fallback placeholder, and add any missing
`.png` files to the deployed `ox_inventory/web/images/` directory. This is
listed explicitly in `docs/19-testing.md`'s installation-tests scope as a
follow-up rather than omitted.

## Summary

- 172 total items, 0 duplicate keys.
- 1 duplicate label found and fixed (`coffee_cup` → "Fresh Coffee").
- 6 of 8 apparently-unreferenced items are plausible third-party
  integration points, kept as-is.
- 2 of 8 (`refined_product`, `product_package`) are confirmed dead
  catalogue entries from an earlier design iteration — flagged for removal.
- 2 of 8 (`farming_hoe`, `ingredient_box`) represent unfinished gameplay
  wiring rather than dead items — flagged as follow-up feature work, not a
  catalogue bug.
- Image-asset presence could not be verified in this environment — flagged
  as a required live-deploy check.
