# imperial_businesses

A reusable, modular framework for player-owned businesses: ownership, hiring,
grade-based permissions, duty status, a real ledger, deposits/withdrawals,
POS charges with customer confirmation and tax, shared/management/ingredient
storage, personal lockers, wage cycles, and daily lease billing with
repossession on prolonged arrears. Eight seed businesses ship configured
(cafe, restaurant, nightclub, mechanic, store, logistics, farm co-op, real
estate agency) — adding a new one is a config entry, not new code.

Business crafting stations (barista, kitchen, fabrication bench) are **not** a
second crafting system — they register into `imperial_crafting` via
`RegisterBench`/`RegisterRecipe` and are access-gated through
`imperial_crafting`'s `restrict.business` delegation, which calls back into
`HasBusinessPermission`. One crafting authority, no duplication.

## Reusable API (server exports)

| Export | Signature | Notes |
| ------ | --------- | ----- |
| `GetBusiness` | `(businessKey) -> table?` | id, key, label, type, owner, balance, active |
| `IsBusinessEmployee` | `(source, businessKey) -> boolean, grade?` | by server source |
| `IsBusinessEmployeeCitizen` | `(citizenid, businessKey) -> boolean, grade?` | by citizenid (offline-safe) |
| `HasBusinessPermission` | `(source, businessKey, permission) -> boolean` | see permission table below |
| `AddBusinessFunds` / `RemoveBusinessFunds` | `(businessKey, amount, reason, actor?) -> ok, balance` | server-authoritative, validated, logged |

Permissions (`config/shared.lua`): `pos`, `stock`, `storage_shared`,
`deposit` (grade 0+); `storage_management`, `ledger`, `hire`, `fire`,
`setgrade` (grade 2+); `withdraw`, `setwage`, `transfer`, `rename` (grade 3 /
owner only).

## Money flow
Every mutation goes through `BizAdjust` (atomic guarded UPDATE, ledger insert,
audit log). Deposits/withdrawals move between Renewed-Banking player accounts
and the business balance; POS charges debit the customer (bank, falling back
to cash) and credit the business net of `imperial:econ:business:transactionTaxPct`
(the tax is sunk, not paid to anyone). Wages are paid from the business
balance to on-duty employees every `wageCycleMinutes`; if the balance can't
cover a wage the employee is simply skipped that cycle (no negative balances).

## Leases
Daily debit of `lease_weekly / 7`, restart-safe via `imperial_kv` timestamp
(`biz:lastLeaseRun`) so a server restart never double-charges or skips a day.
Missed days increment `lease_arrears`; `leaseArrearsLimit` (default 3)
triggers repossession (owner cleared, employees retained for history).

## Database
`sql/002_businesses.sql`: `imperial_businesses`, `imperial_business_employees`,
`imperial_business_txns`.

## Test checklist
- [ ] Deposit/withdraw update balance and ledger; withdraw denied below grade 2.
- [ ] POS charge requires customer confirmation; declines refund nothing.
- [ ] Tax is deducted from POS sales and never credited to the business.
- [ ] Hiring requires physical proximity to an online target.
- [ ] Firing/grade changes respect rank (cannot act on equal/higher grade).
- [ ] Wage cycle pays only on-duty, online employees from business balance.
- [ ] Missed lease payments accumulate arrears; 3rd miss repossesses.
- [ ] Business crafting bench refuses non-employees even with a matching job.
- [ ] Restart mid-lease-cycle does not double-charge (KV timestamp guard).
