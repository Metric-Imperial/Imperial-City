# 09 — Job Catalogue

## Framework jobs (qbx_core `shared/jobs.lua`)
qbx_core ships its own default job set (unemployed, police, ambulance, etc).
This recipe adds one job on top: `fire`, since `imperial_fire` and
`imperial_mdt` both key off `job.name == 'fire'`.

**No manual edit is required.** `imperial_fire/server/main.lua` registers the
job at startup via `exports.qbx_core:CreateJob`, with `commitToFile = false` —
it re-registers each start rather than rewriting a file qbx_core owns. That
survives qbx_core updates and full redeploys, and `CreateJob` fires qbx_core's
job-update events so cityhall and connected clients pick it up immediately.

Registered grades:

```lua
fire = {
    label = 'Fire & Rescue',
    type = 'leo',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Probationary', payment = 60 },
        [1] = { name = 'Firefighter', payment = 75 },
        [2] = { name = 'Lieutenant', payment = 90 },
        [3] = { name = 'Chief', isboss = true, bankAuth = true, payment = 110 },
    },
},
```

To use different grades or pay, define `fire` in `qbx_core/shared/jobs.lua`
yourself — `imperial_fire` checks `GetJob` first and will not overwrite an
existing definition.

> Earlier revisions of this document asked the operator to hand-add this job.
> That was a silent trap: a fresh deploy that skipped the step had no fire
> department at all and no error to say why — the job simply could not be
> assigned, so nothing in `imperial_fire` was reachable.

## First-party civilian jobs (qbx_*)
trucker, tow, garbage, bus, recycle, diving — installed
from Qbox-project. Each is configured independently per its own upstream
config; economy alignment is via the `imperial:econ:pay:*` convars in
`economy.cfg` where the job supports convar overrides, otherwise its own
config file.

**Deliberately not installed:** `qbx_taxijob`, `qbx_newsjob`,
`qbx_mechanicjob` — dropped after live testing, too many upstream issues to be
worth carrying. Their download tasks are gone from the recipe, and `taxi` /
`reporter` are stripped from qbx_cityhall's employment menu by `replace_string`
so nobody can take a job with no resource behind it. The rows remain in
`qbx_core/shared/jobs.lua`, which is harmless — nothing routes to them.

Note that removing `qbx_mechanicjob` does **not** remove mechanic gameplay:
`imperial_businesses` ships Benny's Original Motorworks as a player-owned
business (`type = 'mechanic'`) with its own employment, duty, storage and
fabrication bench. That `type` is an imperial_businesses category label and has
no dependency on the qbx_core `mechanic` job.

## Imperial side jobs (session-based, no job-state change)
See `imperial_sidejobs` README: fishing, mining, lumber, construction,
secure transport, plus a materials buyer. These deliberately do **not** call
`SetJob` — a player keeps their primary employment while working them, per
the master requirement that starter/side activities must not pollute job
state. `qbx_cityhall` remains the place a player formally changes jobs.

## Emergency service jobs
`police`, `ambulance` — qbx_core defaults, extended by `qbx_police` /
`qbx_ambulancejob`. `fire` — added per above, extended by `imperial_fire`.
