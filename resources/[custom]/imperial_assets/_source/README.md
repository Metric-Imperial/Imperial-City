# imperial_assets / _source

Source files that are **converted** into streamed assets. Nothing here is
streamed itself — the game ignores this folder. Keep the originals here so an
asset can be rebuilt or corrected later.

## Why a .ytyp is needed at all

A `.ydr` is only the model. For a **new** custom prop the game also needs an
*archetype* — a record saying the name exists, what asset backs it, and what its
bounds are. That record lives in a `.ytyp`, registered through
`data_file 'DLC_ITYP_REQUEST'`.

Without it the model never enters the game's index: `IsModelInCdimage` returns
false, nothing spawns, and `/prop <name>` reports **"Invalid model"**.

This only applies to *new* models. A `.ydr` that **replaces** an existing game
model needs no archetype, because the archetype already exists — which is why
every other stream folder in this server ships only `.ytd` texture replacements
and declares no ytyp. `[maps]/pillbox` is the one that does, and it ships
`.ydr` files.

## Converting imperial_props.ytyp.xml

In CodeWalker, same round trip you used for the `.ydr`:

1. **RPF Explorer** → **Tools** → **XML → Resource** (or drag the `.xml` in)
2. Save the output as `imperial_props.ytyp`
3. Put it in `imperial_assets/stream/`
4. Restart `imperial_assets`, then `/prop coal_rock` to confirm

## About the bounds in that file

`bbMin` / `bbMax` / `bsRadius` are deliberately **generous** (±3m box, 5.2m
sphere). Getting these wrong fails in one direction only:

- **Too large** — harmless. Slightly less efficient culling, no visual defect.
- **Too small** — the prop pops out of view at certain camera angles, because
  the game culls it once the (wrong, small) bounds leave the frustum.

So oversized values are the safe default when the real dimensions aren't known.
If you would rather have exact ones, CodeWalker computes them for you: open the
`.ydr` in **Project Window → New → YTYP → Add Archetype**, pick the drawable,
and it fills the bounds from the actual geometry. Use that output instead of
this file if you want it tight.

## Adding more props later

Add another `<Item type="CBaseArchetypeDef">` block per model inside
`<archetypes>`, with `name` and `assetName` both set to the model's filename
(without extension). One `.ytyp` can hold every prop in the suite — there is no
need for one per model, and only one `data_file` line is needed either way.
