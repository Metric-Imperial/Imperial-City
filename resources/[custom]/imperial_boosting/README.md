# imperial_boosting

Vehicle boosting contracts: use a boosting tablet to receive a target vehicle
model, steal one matching that model, and deliver it to the chop contact
within a time limit for a dirty-cash payout. Feeds the criminal economy
alongside `qbx_scrapyard` (chop shop) without duplicating its mechanics —
this resource is the "contract" layer that puts a specific target in front of
the player; scrapyard remains the open-ended chop loop.

## Security model
The client requests a contract and reports which vehicle it entered, but the
server is the one that decides whether that report is credible:
`registerVehicle` re-validates the network entity's model against the
contract via `imperial_logging:ValidateNetEntity`, and `deliver` re-validates
both the model *and* current position against the drop-off, using the same
network id captured at registration — a player cannot switch to a different
(cheaper-to-acquire) matching-model vehicle at the last second and still bind
it to an earlier registration, since the netId is fixed once set.

Rewards are paid as the `black_money` **item** (matching this catalogue's
convention — see `imperial_blackmarket`), not as a qbx_core money-account
type, so the earnings must be laundered like any other dirty cash rather than
spent directly.

## Reputation
`imperial_boosting_reputation` tracks a simple counter per citizen; higher
reputation unlocks higher vehicle-class bands (and payouts) via
`config/shared.lua`'s `bands` table.

## Test checklist
- [ ] Delivering an unrelated vehicle of the same model but never registered fails (no netId).
- [ ] Delivering outside the drop-off radius fails even with the right vehicle.
- [ ] Expired contracts cannot be delivered.
- [ ] Payout lands as an inventory item, not a bank/cash balance.
- [ ] Second contract request while one is active is rejected.
