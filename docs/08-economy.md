# 08 — Economy

## Server authority, no exceptions

Every money-affecting flow in the custom suite is server-authoritative: the
client never declares an amount that is trusted outright, every payout is
computed server-side from config/convar values, and every balance change to
a business or gang account goes through a single atomic-adjust function per
domain (`BizAdjust` / `gangAdjust` — see `docs/01-architecture.md`) that
uses a guarded conditional `UPDATE ... WHERE balance >= ?` rather than a
read-then-write, so two simultaneous debits can never overdraw an account.
Every debit/credit also writes an append-only ledger row and an audit log
entry — see `docs/07-database.md`.

## Where the numbers live

All tunable economy figures live in **`recipes/economy.cfg`**, set as
`imperial:econ:*` convars, read server-side only via `GetConvarInt`/
`GetConvar` — clients never read or supply these values. This is the single
place to rebalance the whole server's economy without touching any Lua.

| Category | Convars (see `economy.cfg` for current defaults) |
|---|---|
| Starter package | `starterCash`, `starterBank`, `starterApartmentRentPerWeek` |
| Civilian job payouts | `pay:garbage`, `pay:taxi_per_km`, `pay:tow`, `pay:trucking`, `pay:bus_route`, `pay:postal`, `pay:recycle`, `pay:mining_ore/stone/coal`, `pay:lumber_log/plank`, `pay:fishing_fish`, `pay:produce_box`, `pay:fire_incident` |
| Emergency salaries | `salary:police_base`, `salary:ems_base`, `salary:fire_base` |
| Business | `business:registrationFee`, `business:transactionTaxPct`, `business:defaultWage` |
| Gangs & turfs | `gang:creationFee`, `turf:incomePerCycle` |
| Criminal | `crime:storeRegisterMin/Max`, `crime:launderFeePct`, `crime:boostBandC/B/A` |
| Sinks | `sink:carwash`, `sink:fuelMultiplier` |

A handful of amount *bounds* (not the amounts themselves) are hard-coded in
Lua config rather than convars — e.g. `ImperialBusinesses.posMaxCharge`,
`ImperialGangs.maxWithdraw` — deliberately, because these are anti-exploit
ceilings (the largest amount a single request is ever allowed to move), not
balancing levers; changing them has security implications (see
`docs/18-security.md`) rather than purely economic ones, so they live in
version-controlled config rather than a convar an admin panel could change
without review.

## Money flows, end to end

```text
Civilian jobs / side-jobs  ─▶ player cash          (imperial:econ:pay:*)
Farming wholesale          ─▶ player cash          (imperial:econ:pay:produce_box)
Business POS sales         ─▶ business balance     (minus transactionTaxPct, sunk)
Business wages             ─▶ on-duty employee cash (business balance → player, cron)
Business withdraw/deposit  ─▶ player cash ⇄ business balance
Gang deposit/withdraw      ─▶ player cash ⇄ gang balance
Turf income cycle          ─▶ owning gang balance  (imperial:econ:turf:incomePerCycle, flat)
Fencing (blackmarket)      ─▶ player crim_token     (separate criminal currency — see below)
Laundering (blackmarket)   ─▶ player bank            (black_money item → clean cash, minus launderFeePct fee)
Boosting contracts         ─▶ player black_money item (or bank fallback if inventory can't carry it)
Emergency salaries         ─▶ on-duty player cash   (cron, salary:*_base)
Business lease billing     ─▶ business balance debited; repossession after configured arrears limit
```

## Two separate currencies by design

`crim_token` (fencing payout) is deliberately **not** framework cash or
`black_money` — it's its own ox_inventory item, giving operators an
independent lever to tune the criminal economy's pace without touching the
legitimate cash economy. `black_money` (Dirty Money) is likewise an
ox_inventory item, not a qbx_core money-account type — every resource that
produces or consumes it (`imperial_boosting`, `imperial_blackmarket`) treats
it the same way, and laundering through `imperial_blackmarket` is the
**only** path from `black_money` into clean bank cash.

## Anti-exploit rules

- **Amount validation everywhere.** `imperial_logging:ValidateAmount`
  rejects NaN, infinity, fractional, negative, and out-of-configured-band
  amounts before any money-affecting callback proceeds.
- **Rate limiting on every spammable money action** — crafting starts,
  business POS/deposit/withdraw, gang deposit/withdraw, farming sales,
  fencing, laundering starts (see `docs/18-security.md` for the full list).
- **Every payout re-derives its inputs server-side** — a business POS charge
  re-checks distance and permission at charge time *and* at confirm time; a
  boosting delivery re-validates the vehicle's network id, model, and
  position against the dropoff, never trusting a client "I delivered it"
  claim alone.
- **Rollback on vanished recipient.** If a player disconnects between a
  business/gang debit and the corresponding `AddMoney` call (withdraw
  flows), the debit is reversed back into the business/gang account rather
  than the money being lost.
- **Tax is a sink, not a transfer.** Business POS tax
  (`transactionTaxPct`) and the laundering fee (`launderFeePct`) are
  removed from circulation entirely (logged, not credited anywhere) —
  this is a deliberate economy-health choice, not an oversight.

## Rebalancing guidance

Treat every value in `economy.cfg` as a **starting baseline**, not a tuned
final number — actual balance depends on your player count, session length,
and how aggressively your playerbase engages with the criminal vs.
legitimate economy. Recommended first-week monitoring: total cash/bank in
circulation (via a simple `SUM` query across player data), business/gang
ledger growth rate, and the ratio of legitimate-job income to criminal
income — all derivable from the tables in `docs/07-database.md` plus
qbx_core's own player table.

## Gathering and refining chain

Mining nodes are ore-specific: a coal seam yields coal, an iron deposit
yields `iron_ore`. Two of the five outputs are deliberately **not** sellable
as mined — they are raw ore, and refining them is a real step rather than a
cosmetic one.

```text
Stone Outcrop   ─▶ stone                                    ─▶ buyer ($8)
Coal Seam       ─▶ coal        ─┬─────────────────────────▶ buyer ($12)
                                └─▶ fuel for smelting
Iron Deposit    ─▶ iron_ore    ─▶ smelter (2:1, 1 coal)  ─▶ iron   ─▶ buyer ($18)
Copper Deposit  ─▶ copper_ore  ─▶ smelter (2:1, 1 coal)  ─▶ copper ─▶ buyer ($18)
Gem Vein        ─▶ uncut_gem   ─▶ jeweller (timed, $75/ea) ─▶ emerald_gem
```

Coal has two competing uses — sell it, or burn it — which is the only real
decision in the chain and the reason it is priced lower than the metals.

### Smelting

Two fixed smelters sit at the copper and iron sites (`imperial_sidejobs`
config `smelting.sites`). Each smelt consumes **1 coal** as fuel and takes a
skill check; a botched pour costs the fuel but keeps the ore.

Smelters placed in the world are permanent fixtures with no durability.
Player-crafted smelters and benches (planned, via `imperial_crafting`) will
deplete per item processed — the distinction is deliberate: a free public
furnace at the ore face, a consumable one you carry to your own workshop.

### Gem cutting

Cutting is not instant. Stones are handed to the jeweller on Portola Drive,
the fee is charged up front, and the order is written to
`imperial_jeweller_orders` — it survives logout and server restart, which is
why it is a table and not an in-memory list. One batch per player at a time.

`emerald_gem` currently has no buyer price: it is the top of the chain and
intended for player-to-player sale or a future fence. `outputs` in config is
a weighted table, so further stones are one line each once art exists.
