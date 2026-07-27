# 07 — Database

## Engine and connection

MariaDB ≥ 10.9 (12.3 LTS recommended), accessed exclusively through
**oxmysql** — no custom resource opens its own connection or uses a
different MySQL client library. Every query in the custom suite is
parameterized (`?` placeholders + a parameter table); the Phase 9 security
review swept the whole tree for string-concatenated SQL and found none (see
`docs/18-security.md`).

## Migration ledger, not a monolithic install.sql

Rather than one big `install.sql` a server owner runs once, this recipe
ships **ordered, numbered, idempotent** migration files
(`sql/000_ledger.sql` through `sql/011_boosting.sql`), each of which:

- Uses `CREATE TABLE IF NOT EXISTS` for schema and `INSERT IGNORE` (or
  `ON DUPLICATE KEY UPDATE` where an upsert is the correct semantic) for any
  seed data, so re-running a migration file is always safe.
- Records itself in `imperial_migrations` (`sql/000_ledger.sql` creates this
  table first, before anything else runs) — `SELECT * FROM
  imperial_migrations ORDER BY id;` after install should show all 12 rows,
  one per migration file, and is the fastest way to confirm every migration
  actually applied.

txAdmin's recipe (`recipes/imperial-city-qbox.yaml`) runs all 12 files in
order via `query_database` tasks. If you're applying migrations manually
(e.g. onto an existing database rather than through the deployer), run them
in numeric filename order — later files assume earlier ones' tables exist.

## Schema overview

| Migration | Tables |
|---|---|
| 000_ledger | `imperial_migrations` |
| 001_core | `imperial_logs`, `imperial_kv` |
| 002_businesses | `imperial_businesses`, `imperial_business_employees`, `imperial_business_txns` |
| 003_gangs | `imperial_gangs`, `imperial_gang_members`, `imperial_gang_txns` |
| 004_turfs | `imperial_turfs`, `imperial_turf_log` |
| 005_crafting | `imperial_crafting_xp`, `imperial_crafting_unlocks` |
| 006_drugs | `imperial_drug_labs`, `imperial_drug_batches` |
| 007_farming | `imperial_farm_plants` |
| 008_mdt | `imperial_dispatch_calls`, `imperial_mdt_reports`, `imperial_mdt_charges`, `imperial_mdt_warrants`, `imperial_mdt_bolos`, `imperial_mdt_audit` |
| 009_fire | `imperial_fire_roster` |
| 010_blackmarket | `imperial_blackmarket_listings`, `imperial_launder_jobs` |
| 011_boosting | `imperial_boosting_reputation` |

Dispatch calls (`imperial_dispatch_calls`) live in the `008_mdt` migration
rather than a dedicated dispatch migration because MDT is the primary
consumer that needs to join against call history (linking reports to the
call that generated them); `imperial_dispatch` itself is mostly in-memory
runtime state (duty tracking, active-call routing) and only persists the
call record for MDT's benefit.

## Conventions used throughout

- **Every table uses `InnoDB` / `utf8mb4` / `utf8mb4_unicode_ci`**, matching
  the official Qbox recipe's own schema conventions.
- **Foreign keys use `ON DELETE CASCADE` or `ON DELETE SET NULL`** as
  appropriate to the relationship — e.g. deleting a business cascades to its
  employees and transaction ledger; deleting a gang cascades to its members
  and turf ownership reverts to unowned (`SET NULL`) rather than deleting
  the turf row.
- **JSON columns use a `CHECK (JSON_VALID(...))` constraint** (MariaDB-
  compatible syntax) rather than trusting application code alone to keep
  them well-formed.
- **Ledger tables** (`imperial_business_txns`, `imperial_gang_txns`) are
  append-only — nothing in the custom suite ever `UPDATE`s or `DELETE`s a
  ledger row; they exist purely as an audit trail alongside the live
  `balance` column on their parent table.
- **`imperial_logs`** is the audit log every `imperial_logging:Log`/
  `LogSuspicious` call writes to, batched (see `docs/23-performance-review.md`)
  rather than one `INSERT` per call.
- **`imperial_kv`** is a generic persistent key-value store
  (`imperial_logging:KVSet`/`KVGet`) used by resources that need a small
  amount of durable state without a dedicated table — e.g.
  `imperial_character`'s duplicate-proof starter-grant claims and
  `imperial_businesses`' lease-billing last-run timestamp.

## Adding a new migration

1. Create the next-numbered file, e.g. `sql/012_yourfeature.sql`.
2. Use `CREATE TABLE IF NOT EXISTS` and `INSERT IGNORE`/`ON DUPLICATE KEY
   UPDATE` exclusively — never a bare `INSERT` for seed data, never `DROP`
   or destructive `ALTER` in a numbered migration (see
   `docs/21-update-procedure.md` for how schema changes to *existing*
   tables should be handled instead).
3. End the file with an `INSERT IGNORE INTO imperial_migrations (migration)
   VALUES ('012_yourfeature');` so the ledger reflects it.
4. Add the corresponding `query_database` task to
   `recipes/imperial-city-qbox.yaml` in the same numeric order.
