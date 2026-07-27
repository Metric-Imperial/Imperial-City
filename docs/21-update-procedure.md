# 21 — Update Procedure

## Updating third-party resources

Because every non-`[custom]` resource is pulled from its own upstream
source at deploy time rather than vendored into this repository, updating
them is a matter of re-running the relevant recipe task(s) against a live
server — this recipe does not pin third-party resources to a specific
commit by default (each `download_github` task uses `ref: main`, and
`download_file` tasks generally point at each project's "latest release"
asset URL). This is a deliberate trade-off: it means security fixes reach a
server automatically on redeploy, at the cost of not being able to fully
pin every third-party version. If you need reproducible pinned versions for
a production server, fork this recipe and replace `ref: main` with a
specific commit/tag per resource you want pinned, and replace "latest
release" download URLs with versioned ones.

**Recommended cadence**: review `docs/05-resource-selection.md`'s selected
resources periodically (their activity/maintenance status can change) and
re-run the deploy in a staging environment before applying to production,
since an upstream `main` branch update is by definition untested against
this specific recipe's configuration.

## Updating custom `imperial_*` resources

1. Make the change in the relevant `resources/[custom]/imperial_*` resource
   in your fork.
2. Run `python3 tools/luacheck.py "resources/[custom]/<resource>"` and
   `python3 tools/verify_startup.py` before committing — every prior change
   in this project's history has been validated this way.
3. If the change touches schema, add a new numbered migration file (see
   `docs/07-database.md`) — **never edit an already-shipped migration file**
   once it may have run against a live server; a numbered migration is a
   permanent historical record, not a place to iterate.
4. Commit with a message describing the change and its rationale (see this
   repo's own git history for the established style — every commit
   documents *why*, not just *what*).
5. Update `docs/18-security.md`/`docs/23-performance-review.md` if the
   change affects a validated flow or a threaded/tick-based system.
6. Update `PROJECT_STATUS.md`'s relevant phase notes and
   `RESOURCE_REGISTRY.md`'s entry for the resource if its metadata changed.

## Applying an update to a live server

1. **Back up the database** before applying any migration, even an
   idempotent one — this is standard practice regardless of how safe the
   migration is believed to be.
2. Stop the affected resource(s) via txAdmin/console (`stop imperial_x`),
   or restart the whole server during a low-population window for changes
   spanning multiple interdependent resources.
3. Pull the updated `[custom]` folder and any new `sql/*.sql` files onto the
   server.
4. Run any new migration file(s), in numeric order, against the live
   database.
5. `ensure`/`restart` the affected resource(s) (respecting startup order —
   see `docs/03-startup-order.md` — if the update introduces a new
   cross-resource dependency).
6. Spot-check the affected system against the relevant section of
   `docs/19-testing.md`.

## Schema changes to existing tables

A numbered migration file is append-only by convention (see
`docs/07-database.md`) — it should never be edited after it may have run
against a live server. To change an existing table's shape (add a column,
change a type, etc.), write a **new** numbered migration that performs the
`ALTER TABLE`, guarded so it's safe to re-run:

```sql
-- Example: sql/012_add_column.sql
ALTER TABLE imperial_businesses
  ADD COLUMN IF NOT EXISTS new_field VARCHAR(64) NULL;

INSERT IGNORE INTO imperial_migrations (migration) VALUES ('012_add_column');
```

(MariaDB supports `ADD COLUMN IF NOT EXISTS` directly, keeping the same
idempotency guarantee as every other migration in this repo.)

## Rolling back

There is no automated rollback tooling — the migration ledger is a forward-
only record of what has been applied, matching the "not a destructive
install.sql" design goal. To roll back a schema change, write a new
migration that reverses it (rather than deleting the migration that
introduced it), so the ledger continues to accurately reflect what has
actually run against the database over time.
