# imperial_logging

Shared foundation for the imperial suite: structured audit logging (batched to
`imperial_logs`), sliding-window rate limiting, per-player action locks,
restart-safe KV persistence (`imperial_kv`), and server-side validation helpers.

Every other `imperial_*` resource declares a dependency on this resource and
**must** route money/security-relevant actions through `Log`.

## Requirements
- oxmysql, ox_lib, qbx_core (for citizenid resolution)
- SQL: `sql/001_core.sql` (tables `imperial_logs`, `imperial_kv`)

## Server exports

| Export | Signature | Purpose |
| ------ | --------- | ------- |
| `Log` | `(data: table) -> boolean` | Queue audit entry `{category, severity, source|citizenid, targetCitizenid, action, amount, data}` |
| `LogSuspicious` | `(src, action, extra?)` | Security log incl. player identifiers |
| `RateLimit` | `(src, key, max?, windowMs?) -> allowed` | Sliding-window limiter keyed by licence |
| `AcquireLock` / `ReleaseLock` | `(src, key, ttlMs?)` | Exclusive per-player action locks with TTL safety |
| `KVSet` / `KVGet` | `(key, value?) / (key) -> value` | Persistent JSON KV (write-through cache) |
| `ValidateDistance` | `(src, coords, maxDist) -> boolean` | Anti-spoof distance check (logs failures) |
| `ValidateAmount` | `(amount, min?, max?) -> ok, int` | Rejects NaN/inf/fractional/out-of-band amounts |
| `ValidateNetEntity` | `(src, netId, models?, maxDist?) -> ok, entity` | Networked entity existence/model/distance |
| `PlayerSnapshot` | `(src) -> table?` | `{citizenid, job, jobGrade, onDuty, gang, gangGrade}` |

## Configuration
`config/shared.lua` — flush intervals, queue caps, severity map, defaults.
Convars: `imperial:webhook_audit` (optional Discord mirror), `imperial:debug`.

## Security notes
- The webhook mirror is best-effort only; the database is authoritative.
- Rate-limit keys are bound to the licence identifier, not the source id.
- No client scripts: this resource exposes nothing to clients.

## Test checklist
- [ ] Server starts with resource before all other imperial resources.
- [ ] `Log` entries appear in `imperial_logs` within 2 s (batch flush).
- [ ] Queue survives burst of 500 entries without loss below `maxQueue`.
- [ ] `RateLimit` returns false beyond the window budget and logs severity 3.
- [ ] `AcquireLock` blocks re-entry until release or TTL expiry.
- [ ] `KVGet` returns persisted value after full server restart.
