# imperial_character

Character-lifecycle hardening on top of qbx_core's integrated multicharacter:

- **Duplicate-proof starter package** — items granted exactly once per character,
  claimed atomically through `imperial_kv` *before* granting so a race or replayed
  event can never double-grant. Starter *funds* remain qbx_core `StartingFunds`
  (single money authority); an optional logged bank bonus is available here.
- **First-login flag + onboarding hooks** — `imperial_character:server:firstLogin`
  (server) and `imperial_character:client:firstLogin` (client) fire once per
  character for tutorials/starter-accommodation offers.
- **Spawn fallback** — client detects under-map/origin spawns; the server
  re-validates the position before rescuing (rate-limited, logged).
- **Lifecycle audit** — load/unload entries in `imperial_logs`.

Character creation, selection, deletion, appearance and spawn choice remain the
responsibility of qbx_core (multicharacter), illenium-appearance and qbx_spawn.
Identifier validation and name/DOB validation are performed by qbx_core's
character creation; slots are configured in qbx_core config (see docs/06).

## Events
| Event | Direction | Payload | Notes |
| ----- | --------- | ------- | ----- |
| `imperial_character:server:firstLogin` | server→server | `(source, citizenid)` | onboarding hook |
| `imperial_character:client:firstLogin` | server→client | — | welcome notify |
| `imperial_character:server:requestSpawnRescue` | client→server | — | validated + rate-limited |

## Test checklist
- [ ] New character receives starter items exactly once (relog, restart, /logout).
- [ ] Second character on same licence receives its own package.
- [ ] Spawn rescue only triggers when genuinely below map / at origin.
- [ ] `imperial_logs` contains lifecycle entries.
