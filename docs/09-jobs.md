# 09 — Job Catalogue

## Framework jobs (qbx_core `shared/jobs.lua`)
qbx_core ships its own default job set (unemployed, police, ambulance, etc).
This recipe requires one **addition** the operator must make to qbx_core's
job config before first start: a `fire` job entry (grades 0–3), since
`imperial_fire` and `imperial_mdt` both key off `job.name == 'fire'`. This is
config, not framework-core editing — it is the same file server owners edit
to add any custom job, and Qbox's own docs treat `shared/jobs.lua` as an
operator-owned config surface.

```lua
-- add to qbx_core/shared/jobs.lua
fire = {
    label = 'Fire & Rescue',
    type = 'leo', -- or 'none', per your onesync/queue priority needs
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Probationary', payment = 60 },
        [1] = { name = 'Firefighter', payment = 75 },
        [2] = { name = 'Lieutenant', payment = 90, isboss = false },
        [3] = { name = 'Chief', payment = 110, isboss = true },
    },
},
```

## First-party civilian jobs (qbx_*)
taxi, trucker, tow, garbage, bus, news, recycle, mechanic, diving — installed
from Qbox-project. Each is configured independently per its own upstream
config; economy alignment is via the `imperial:econ:pay:*` convars in
`economy.cfg` where the job supports convar overrides, otherwise its own
config file.

## Imperial side jobs (session-based, no job-state change)
See `imperial_sidejobs` README: fishing, mining, lumber, construction,
secure transport, plus a materials buyer. These deliberately do **not** call
`SetJob` — a player keeps their primary employment while working them, per
the master requirement that starter/side activities must not pollute job
state. `qbx_cityhall` remains the place a player formally changes jobs.

## Emergency service jobs
`police`, `ambulance` — qbx_core defaults, extended by `qbx_police` /
`qbx_ambulancejob`. `fire` — added per above, extended by `imperial_fire`.
