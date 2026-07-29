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

## physicsDictionary is required, or the prop has no collision

Every archetype **must** declare:

```xml
<physicsDictionary>imperial_props</physicsDictionary>
```

Left empty (`<physicsDictionary/>`), the engine is told the archetype has no
physics and never associates the drawable's embedded bound with it. The prop
then renders perfectly, sits correctly, reports the right dimensions — and
players walk straight through it. `RequestCollisionForModel` cannot help,
because there is nothing registered to load.

Diagnosing it: `/prop <model>` reports collision state.

```
prop_rock_1_d       2.94 x 2.67 x 1.48 m   collision=1      <- stock, works
prop_boulder_iron   1.60 x 1.40 x 1.20 m   collision=false  <- empty physicsDictionary
prop_boulder_coal   1.68 x 1.48 x 1.28 m   collision=1      <- fixed
```

Note the dimensions change once physics loads: `GetModelDimensions` starts
reporting the **collision** bounds (including the 0.04 margin) rather than the
drawable bounding box. A prop reporting slightly larger numbers than its mesh is
therefore a good sign, not a fault.

Comparing against a stock prop through the same code path is the fastest way to
tell a broken asset from broken script: if `prop_rock_1_d` is solid and yours is
not, the problem is the asset or its archetype, not the spawning code.

## Converting imperial_props.ytyp.xml

In CodeWalker, same round trip you used for the `.ydr`:

1. **RPF Explorer** → **Tools** → **XML → Resource** (or drag the `.xml` in)
2. Save the output as `imperial_props.ytyp`
3. Put it in `imperial_assets/stream/`
4. Restart `imperial_assets`, then `/prop coal_rock` to confirm

## Bounds must match the model exactly

`bbMin` / `bbMax` / `bsCentre` / `bsRadius` **must be copied from the top of the
model's own `.ydr.xml`**. They are not a culling hint and guessing them does not
work.

`CreateObject` positions an object using its **archetype** bounds. A first
version of this file used a deliberately generous ±3m box on the assumption that
oversized was harmless. It is not: with `bbMin.z = -3`, every `coal_rock` spawned
exactly 3 metres above where it was asked for, `GetModelDimensions` reported a
6×6×6m object, and the rock appeared to float. That cost several rounds of
chasing coordinates and collision, neither of which was ever the problem.

For each model, copy these four lines out of its `.ydr.xml`:

```xml
<BoundingSphereCenter x="..." y="..." z="..." />   ->  bsCentre
<BoundingSphereRadius value="..." />               ->  bsRadius
<BoundingBoxMin x="..." y="..." z="..." />         ->  bbMin
<BoundingBoxMax x="..." y="..." z="..." />         ->  bbMax
```

CodeWalker can also generate the archetype for you with the correct values:
**Project Window → New → YTYP → Add Archetype**, pick the drawable, and it fills
the bounds from the actual geometry.

## Adding more props later

Add another `<Item type="CBaseArchetypeDef">` block per model inside
`<archetypes>`, with `name` and `assetName` both set to the model's filename
(without extension). One `.ytyp` can hold every prop in the suite — there is no
need for one per model, and only one `data_file` line is needed either way.

## Never put XML comments in the .ytyp

CodeWalker's ytyp reader walks the children of `<archetypes>` and casts each
node to an element. An XML comment is a node but not an element, so the cast
yields null and the import dies with:

```
Unable to import file
Object reference not set to an instance of an object.
```

The file is valid XML and every editor will accept it — only CodeWalker
objects, and its error names neither the file nor the line. Document archetypes
here in the README instead, never inline.

## imperial_smelter

Built procedurally from `_work/smelter/build_smelter.py` (headless Blender +
Sollumz) rather than modelled by hand, so dimensions, bevels and the origin are
all reproducible. Bounds are copied verbatim out of the exported
`imperial_smelter.ydr.xml`:

```
bbMin  -0.75, -0.64, 0.00      <- z=0: the mesh is built upward from its origin
bbMax   0.75,  0.60, 1.43
```

`textureDictionary` is empty because the six textures are embedded in the
drawable. Shaders are `normal_spec.sps` (masonry, brass, red, iron) and
`emissive.sps` (the fire), never `default.sps`.
