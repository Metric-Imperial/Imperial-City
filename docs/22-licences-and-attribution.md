# 22 — Licences and Attribution

## This project

Every custom `imperial_*` resource in this repository is licensed
**GPLv3**, matching the licence of the Qbox-project resources whose
patterns and conventions they build on (see `LICENSE` at the repository
root). Choosing the same licence family as the framework this recipe
extends keeps the whole stack licence-compatible without needing a
case-by-case compatibility review.

## Third-party resources

This recipe does not vendor third-party code — every non-`[custom]`
resource is downloaded from its own upstream source at deploy time (see
`recipes/imperial-city-qbox.yaml`), so **the authoritative licence for each
one is whatever its own repository states at download time**, not a copy
frozen into this project. The table below is a snapshot recorded during
resource selection (see `docs/05-resource-selection.md` for the full
selection methodology and rationale per resource); always check the
resource's own repository if licence terms matter for your deployment.

| Category | Resources | Licence (as recorded at selection) |
|---|---|---|
| Qbox-project (framework, jobs, criminal, housing) | qbx_core, qbx_vehicles, qbx_spawn, qbx_garages, qbx_vehicleshop, qbx_vehiclesales, qbx_customs, qbx_vehiclekeys, qbx_carwash, qbx_idcard, qbx_radialmenu, qbx_scoreboard, qbx_seatbelt, qbx_binoculars, qbx_cityhall, qbx_medical, qbx_ambulancejob, qbx_police, all `qbx_*` civilian job and criminal-activity resources, qbx_properties, qbx_hud, qbx_adminmenu, qbx_management, qbx_smallresources, qbx_density, qbx_npwd, npwd_qbx_garages, npwd_qbx_mail, mm_radio | GPLv3 |
| Overextended ("ox") | ox_lib, oxmysql, ox_target, ox_inventory, ox_doorlock, ox_fuel | GPLv3 |
| Other third-party (standalone/appearance/voice/phone/world) | Renewed-Banking, Renewed-Weathersync, illenium-appearance, pma-voice, npwd, bob74_ipl, xt-prison, safecracker, mhacking, ultra-voltlab, screencapture, scully_emotemenu, loadscreen, mana_audio, vehiclehandler, MugShotBase64, pillbox | Varies by project — MIT for several (recorded per-resource in `docs/05-resource-selection.md`), GPLv3 or project-specific terms for others. **Verify against the resource's own repository before redistribution**, since these snapshots can go stale as upstream projects change licence terms. |

## Attribution

This recipe's own written material (documentation, config, SQL migrations,
and all `imperial_*` Lua code) was authored for this project. Attribution
for every third-party resource lives with its original author/organisation
per that resource's own repository — this project does not claim authorship
of anything outside `resources/[custom]` and the `docs/`/`recipes/`/`sql/`/
`tools/` content in this repository.

## Rejected resources

`docs/05-resource-selection.md`'s rejection table records why specific
alternatives were **not** selected — several rejections were licence-driven
(paid/escrowed resources such as the `okok*`, `wasabi*`, `lb-*`, and `qs-*`
families were excluded specifically because they are incompatible with this
recipe's free/open-source-only requirement, not because of any quality
judgement about the resources themselves).

## If you redistribute this recipe

- Keep this project's own `LICENSE` file (GPLv3) attached to any
  redistribution of the `[custom]` resources, SQL, docs, and recipe files
  in this repository.
- Do not assume a third-party resource's licence terms are unchanged from
  the snapshot in `docs/05-resource-selection.md` — re-verify before
  redistributing a bundled copy of any third-party resource rather than
  linking to its upstream source the way this recipe does.
