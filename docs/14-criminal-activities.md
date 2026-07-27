# 14 — Criminal Activity Catalogue

## First-party (Qbox-project, active)
Store robbery, bank robbery, armoured-truck robbery (`qbx_truckrobbery`),
house robbery, jewellery robbery (`qbx_jewelery`), pawnshop, chop shop
(`qbx_scrapyard`), street dealing/growing (`qbx_drugs`, `qbx_weed`), illegal
racing (`qbx_streetraces`, `qbx_lapraces`). Each ships its own police-count
requirements, cooldowns, and tool checks; operators should point each
resource's dispatch hook at `exports.imperial_dispatch:CreateDispatchCall`
(see docs/12) rather than installing a competing dispatch system.

## Custom (imperial_*)
| Resource | Covers |
| -------- | ------ |
| `imperial_drugs` | Lab-based production feeding qbx_drugs' sellable items (docs/15) |
| `imperial_blackmarket` | Fencing (contraband → crim_token) + money laundering (dirty → clean cash) |
| `imperial_boosting` | Contract-based vehicle theft feeding qbx_scrapyard |
| `imperial_crafting` (criminal benches) | Advanced lockpicks, hacking devices, fake plates, jammers, thermite, armour, ammo components — see docs/13 |

## Cargo theft / warehouse burglary
Covered by `qbx_truckrobbery` (cargo-in-transit) and `qbx_houserobbery`
(residential). A dedicated warehouse-burglary variant targeting
`imperial_businesses` logistics-type sites (e.g. `pacificfreight`) is a
documented extension point: gate an `ox_target` option on the warehouse
storage stash behind a police-count/cooldown check identical to
`qbx_houserobbery`'s pattern, and reward from the business's *own* stock
(via `RemoveBusinessFunds`/stash removal) rather than minting new items —
left undeployed by default since it requires an operator decision on which
businesses should be robbable.

## Prison
Arrests from `qbx_police` integrate with `xt-prison`. Optional in-prison
activities are xt-prison's own scope; not duplicated here.
