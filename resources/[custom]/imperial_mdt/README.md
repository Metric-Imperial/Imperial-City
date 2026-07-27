# imperial_mdt

Department-scoped MDT for police, EMS and fire, built on a minimal self-contained
NUI (`web/index.html`) and server-validated callbacks. There is no client-side
department claim anywhere — every callback re-derives the caller's real job,
grade and duty status via `imperial_logging:PlayerSnapshot` before touching
the database.

## Access model
`authorise(src, permission)` (server/main.lua) requires the player be on duty
in a job matching one of `config/shared.lua`'s `departments`, and to meet the
permission's minimum grade (`config/shared.lua permissions`). Police-only
features (warrants, BOLOs, criminal-record view) additionally check
`dept == 'police'` explicitly rather than relying on the permission table
alone, so an EMS employee can never reach them even at max grade.

## Features
- **Reports** — incident/arrest/citation/etc, with attachable charges from
  the `chargeCodes` config (fine + jail months per charge).
- **Warrants** — issue/clear, police only.
- **BOLOs** — issue with optional plate, police only.
- **Person lookup** — resolves online players via `qbx_core:GetPlayerByCitizenId`
  and offline players via the `players` table's `charinfo` JSON column
  (verify this column name against your qbx_core.sql if you have modified
  the players table), returning their report and warrant history.
- **Dispatch call linking** — `getRecentCalls` bridges to
  `imperial_dispatch:GetRecentCalls` so a report can reference the call that
  generated it.
- **Audit trail** — every write logs to `imperial_mdt_audit`.

## Open the MDT
`F6` or `/mdt` (client). NUI focus is only granted while open.

## Database
`sql/008_mdt.sql`: `imperial_dispatch_calls` (shared with imperial_dispatch),
`imperial_mdt_reports`, `imperial_mdt_charges`, `imperial_mdt_warrants`,
`imperial_mdt_bolos`, `imperial_mdt_audit`.

## Test checklist
- [ ] Off-duty or wrong-department players get nothing back from every callback.
- [ ] EMS/fire cannot reach warrants/BOLOs even with high grade.
- [ ] Report charges attach only from the configured charge-code list.
- [ ] Person lookup works for both online and offline citizens.
- [ ] Audit log records every write with the real citizenid.
