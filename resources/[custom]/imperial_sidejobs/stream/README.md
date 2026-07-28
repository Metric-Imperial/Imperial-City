# imperial_sidejobs / stream

Custom streamed assets for side-job activity sites (mining rocks, etc).

## Dropping props in

FiveM streams anything in a folder named `stream/` automatically — **no
fxmanifest entry is needed** for plain props. Subfolders are fine and are
purely for your own organisation; the game flattens them.

Typical prop import needs:

| File | Purpose | Required |
|---|---|---|
| `<model>.ydr` | the model itself | yes |
| `<model>.ytd` | its texture dictionary | usually |
| `<model>.ybn` | separate collision | only if not embedded in the `.ydr` |
| `<model>.ytyp` | archetype definition | only for some packs — **see below** |

The **model name is the filename without the extension**. That is the string
you put in the config, e.g. `nodeProp = \`my_rock_01\`` for `my_rock_01.ydr`.

## If your pack includes a .ytyp

A `.ytyp` defines archetypes and must be explicitly registered, or the props
will not spawn (usually as an invisible or missing model). Add to
`imperial_sidejobs/fxmanifest.lua`:

```lua
files {
    'stream/your_pack.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/your_pack.ytyp'
```

`[maps]/pillbox` in this server is a working example of that pattern.

Tell Claude when you've added files and the manifest will be wired up if
needed — whether it is depends entirely on what the pack contains.

## Verifying a model before wiring it into config

`imperial_propcheck` validates against the game's model index, so it will tell
you immediately whether a streamed model actually resolved:

```
/prop my_rock_01     spawn it in front of you
/propinfo            real-world size in metres
```

If `/prop` reports **"Invalid model"** the asset did not stream — usual causes
are a missing `.ytd`, an unregistered `.ytyp`, or the resource not having been
restarted after the files were added. A restart of `imperial_sidejobs` alone is
enough; a full server restart is not required.

Size matters here: mining node target zones are spheres of radius **2.2m**
(`setupNodes` in `client/main.lua`). A prop much larger than that means players
can see the rock from far off but have to stand almost on top of it to get the
target option. Either keep props near that size or the radius needs raising to
match.

## A note on repository size

These are binary assets committed to git. A handful of rock props is nothing,
but if this grows into a large pack be aware GitHub rejects individual files
over 100MB and warns past roughly 1GB per repository. If it ever gets that far,
the props want to live outside the repo and be pulled in by a `download_file`
task in the recipe instead.
