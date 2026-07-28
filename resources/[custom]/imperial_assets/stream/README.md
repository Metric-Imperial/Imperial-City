# imperial_assets / stream

**One place for every imported asset used anywhere in the Imperial suite.**

Streamed assets in FiveM are global — they are *not* scoped to the resource
that holds them. Once `imperial_assets` has started, every model in here can be
spawned by any script on the server. So `imperial_sidejobs`, `imperial_farming`,
`imperial_fire` and anything else all draw from this single folder; none of them
need a `stream/` folder of their own.

## Dropping assets in

No fxmanifest entry is needed for plain props. Subfolders are fine and are
purely for your own organisation — the game flattens them, so feel free to use
`stream/mining/`, `stream/farming/` and so on.

| File | Purpose | Required |
|---|---|---|
| `<model>.ydr` | the model itself | yes |
| `<model>.ytd` | its texture dictionary | usually |
| `<model>.ybn` | separate collision | only if not embedded in the `.ydr` |
| `<model>.ytyp` | archetype definition | only some packs — **see below** |

The **model name is the filename without the extension**. That is the string
config takes, e.g. `nodeProp = \`my_rock_01\`` for `my_rock_01.ydr`.

## If a pack includes a .ytyp

A `.ytyp` defines archetypes and must be registered explicitly, or the props
will not spawn — usually appearing invisible or as a missing model. Add to
`imperial_assets/fxmanifest.lua`:

```lua
files {
    'stream/your_pack.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/your_pack.ytyp'
```

Multiple packs each need their own `files` entry and their own `data_file`
line. `[maps]/pillbox` is a working example of the pattern.

## Verifying a model

`imperial_propcheck` validates against the game's model index, so it says
immediately whether an asset actually resolved:

```
/prop my_rock_01     spawn it in front of you
/propinfo            real-world size in metres
```

**"Invalid model"** means it did not stream. Usual causes: a missing `.ytd`, an
unregistered `.ytyp`, or the resource not restarted since the files were added.
Restarting `imperial_assets` alone is enough — a full server restart is not
needed, though scripts already holding a model reference may need their own
restart to pick up a changed asset.

## Sizing props for interaction zones

Mining node target zones are spheres of radius **2.2m** (`setupNodes` in
`imperial_sidejobs/client/main.lua`). A prop much larger than that is visible
from a distance but forces players to stand almost on top of it before the
target option appears. Either keep props near that size, or say so and the
radius can be raised to match the model.

## Repository size

These are binary assets committed to git. A handful of props is nothing, but
GitHub rejects individual files over 100MB and warns past roughly 1GB per
repository. If the collection ever approaches that, these should move out of
the repo and be pulled in by a `download_file` task in the recipe instead.
