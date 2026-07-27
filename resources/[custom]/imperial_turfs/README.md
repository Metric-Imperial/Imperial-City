# imperial_turfs

Configurable gang territory control built on `imperial_gangs`' dynamic gang
data — not uncontrolled deathmatching. Every contest follows the same
server-authoritative shape:

1. **Declaration** — `startContest` requires the attacking gang to already
   have `minPresence` members physically inside the zone, and the turf must
   not be on cooldown or already contested. A declaration period
   (`declareDelaySec`, default 60 s) follows before any capture progress can
   accrue, giving defenders and police (a low-priority dispatch alert, if
   `notifyPoliceOnContest`) time to respond.
2. **Capture window** — every tick (`tickIntervalSec`), the server counts
   attacker and defender presence server-side (real player positions, not
   client claims). Attacker presence advances progress; defender presence
   (if the turf has an owner) pushes it back — defense is intentionally
   stronger per tick than offense. No presence from either side simply holds
   progress in place.
3. **Resolution** — reaching `captureThreshold` flips ownership, resets
   progress, starts the capture cooldown, and awards the new owner gang
   reputation. Progress falling to 0 while defenders hold the zone cancels
   the contest outright. An untouched contest auto-cancels after
   `contestTimeoutSec`.

**Participation limits**: attacker/defender counts are capped at
`maxCountedParticipants` so an oversized mob doesn't trivially win — bringing
more than the cap contributes nothing extra.

## Ownership benefits
`GetTurfOwner(turfKey)` and `GetGangTurfs(gangKey)` exports let other
resources price bonuses off ownership (drug-sale bonuses, black-market
access, crafting discounts) without imperial_turfs needing to know about
them — this keeps turfs a pure ownership ledger. A flat income payment
(`imperial:econ:turf:incomePerCycle`) is paid to each owning gang's account
every `incomeIntervalMin` as the one benefit shipped by default.

## Commands
`/turfcontest` (declare a contest for the zone you're standing in),
`/turfinfo` (status of all zones). Admin: `/turfset <turfKey> <gangKey|none>`.

## Test checklist
- [ ] Starting a contest without minimum presence is rejected.
- [ ] Capture progress only accrues after the declaration delay.
- [ ] Defender presence reverses progress; attacker+defender both present holds.
- [ ] Cooldown blocks re-contesting immediately after a capture.
- [ ] Contest auto-cancels after timeout with no capture.
- [ ] Server restart mid-contest resumes from persisted progress correctly.
