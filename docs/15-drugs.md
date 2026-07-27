# 15 — Drugs

All content here is fictional gameplay abstraction. No real-world chemistry,
synthesis procedures, or operational manufacturing detail appears in this
recipe's config, code, or documentation — production is modelled as four
generic stages (gather → process → refine → package) using placeholder
materials (`raw_material_a/b`, `chem_supplies`, `packaging_materials`).

## Two systems, one item set
- **`qbx_drugs` / `qbx_weed`** (first-party) — street dealing and small-scale
  growing, using the base catalogue's drug items (`meth`, `coke_brick`,
  `weed_*`, `oxy`, etc).
- **`imperial_drugs`** (custom) — the lab-production front end for the same
  items. It does not introduce a parallel drug economy; `meth` produced by a
  lab is the same `meth` item `qbx_drugs` lets a player sell on the street.

## Risk model
Labs accumulate contamination while batches are active, raising the chance of
a periodic anonymous tip-off dispatched to police (`imperial_dispatch`).
On-duty police have a permanent "Raid & seize" option at every lab location
that clears in-progress batches and resets contamination — production is a
standing risk, not a one-time gate.

## Configurable effects
Drug *effects* (status changes on consumption) are defined per-item in
`ox_inventory`'s item catalogue (`client.status` fields) exactly like food and
drink items — see `recipes/items.lua`. None are configured with permanent
stat bonuses; this recipe ships the base catalogue's items without added
consumption effects, leaving status-effect design to server policy.
