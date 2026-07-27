# imperial_drugs

Abstract, fictional drug-lab production framework (gather → process → refine
→ package → distribute) that feeds the same sellable items `qbx_drugs`
already uses for street dealing — this is the production front end, not a
competing item set. No real-world chemistry, procedures, or instructional
content is included anywhere in config or code; stages are generic
placeholders (`raw_material_a/b`, `chem_supplies`, `packaging_materials`).

## Design
- **Restart-safe timing.** Like `imperial_farming`, stage readiness is derived
  from a stored `stage_ready_at` timestamp, not a running thread — a restart
  mid-cook loses nothing and gains nothing.
- **Access control.** Hidden benches require a `lab_keycard` item; gang-owned
  labs are a documented extension point (`owner_type = 'gang'` in the schema)
  for `imperial_gangs` to claim ownership without schema changes.
- **Contamination & raids.** Active labs accumulate contamination over time;
  higher contamination raises the chance of a periodic dispatch tip-off to
  police. Police get a permanent "Raid & seize" target option at every lab
  (visible only while on duty) that deletes all in-progress batches and
  resets contamination — a real consequence for running a hot lab.
- **Capacity limits.** Two concurrent batches per lab, enforced server-side.

## Callbacks
`startBatch`, `getLabState`, `advanceBatch`, `raidSeize` — all under the
`imperial_drugs:` prefix, all distance-validated and rate-limited.

## Database
`sql/006_drugs.sql`: `imperial_drug_labs`, `imperial_drug_batches`.

## Test checklist
- [ ] Starting a batch without the keycard/ingredients is rejected.
- [ ] Advancing before `stage_ready_at` is rejected (server clock, not client).
- [ ] Restarting mid-cook preserves batch stage/timing exactly.
- [ ] Contamination rises only while batches are active; raids reset it.
- [ ] Only on-duty police see/can use the raid option.
