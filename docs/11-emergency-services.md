# 11 — Emergency Services

## Police
`qbx_police` (Qbox-project, active, 551 commits): duty, clothing, vehicles,
armory (citizen-ID whitelisted), stash management, fingerprint/DNA testing,
evidence lockers, speed radar, stormram, vehicle impound (fee or permanent),
integrated jail, forensics (casings/GSR/blood), handcuffs, security cameras,
tracking anklets, vehicle flag/unflag. Wired to `imperial_dispatch` for
alerts and `imperial_mdt` for records (police department).

## EMS
`qbx_medical` (injury/death-state authority) + `qbx_ambulancejob` (job,
hospital beds, check-in, treatment, medical items). `pillbox` MLO provides
the hospital interior. Wired to `imperial_dispatch`/`imperial_mdt`.

## Fire & Rescue
`imperial_fire` (custom — no maintained free equivalent exists). See its
README for the incident model, and `docs/09-jobs.md` for the required
qbx_core job addition.

## Dispatch & MDT
`imperial_dispatch` and `imperial_mdt` (custom — see docs/12).

## Jail
`xt-prison` (active, qbx/ox-compatible; replaces the archived `qbx_prison`).
Police's arrest flow (qbx_police) integrates with it per its own docs.

## Shared department patterns
All three departments follow the same shape: duty toggle at a station point,
job/grade-gated garages (`qbx_garages` config), equipment lockers
(ox_inventory stashes), dispatch alerts, and MDT records. This consistency
means an operator adding a fourth department (e.g. Search & Rescue) has a
clear template to follow rather than a bespoke pattern per service.
