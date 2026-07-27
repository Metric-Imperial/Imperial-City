# imperial_blackmarket

Two systems: a **fence** that converts contraband items into `crim_token`
(criminal scrip, not framework money — keeps the black market from being a
direct cash faucet), and **laundering fronts** that convert `black_money`
(dirty cash, already in the catalogue as "Dirty Money") into clean bank
funds over time, at a configurable fee, with a per-player one-job-at-a-time
limit and a per-job cap.

## Why crim_token instead of cash
Fencing stolen goods directly for spendable cash would let criminal activity
bypass the entire economy-balancing surface. `crim_token` is a separate item
currency that `imperial_crafting`'s criminal benches and `imperial_gangs`
territory bonuses can price things in, keeping the criminal economy legible
and tunable independently of the legitimate one.

## Laundering
`startLaunder(frontIndex, amount)` removes `black_money` immediately and
opens a timed job (`launder_jobs`); `collectLaunder` pays out clean bank
funds only after `ready_at` has passed (server clock) and only once
(guarded UPDATE). Amount is capped per front and requires a minimum to
discourage penny-laundering spam.

## Test checklist
- [ ] Fence only buys configured items; unknown items rejected.
- [ ] Selling clamps to owned count; token grant capacity-checked (refunds goods on overflow).
- [ ] Only one active launder job per citizen; second attempt rejected.
- [ ] Collecting before `ready_at` fails; collecting twice fails (guarded UPDATE).
