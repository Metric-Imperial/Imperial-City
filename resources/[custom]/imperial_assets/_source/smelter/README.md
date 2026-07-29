# imperial_smelter — build source

The smelter is **generated**, not modelled by hand. Run headless:

```
"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" ^
  --background --python build_smelter.py
```

`make_dds.py` writes the flat albedo textures first; run it whenever a colour
changes. Output lands in `export/` as `imperial_smelter.ydr.xml` plus a texture
folder, ready for CodeWalker's XML → Resource.

Generating it means dimensions, bevels, the origin and the collision are all
reproducible: fixing a fault is an edit and a re-run, not remodelling.

## Sollumz gotchas this script exists to encode

Each of these produced a silent or misleading failure:

| Symptom | Cause |
|---|---|
| `has no Sollumz materials` | `shader_materials.create_shader` (v1) does not tag `sollum_type`. Use **v2**. |
| ...still, after setting `sollum_type` by hand | `get_sollumz_materials` only collects meshes registered against a **LOD level**. Use `bpy.ops.sollumz.converttodrawable()`. |
| Prop renders untextured | `texture_properties.embedded` defaults to `False`, so the texture dictionary exports empty. |
| `/prop` says `collision=1` but you walk through | Every `composite_flags1/2` defaults to `False`. The bound loads and collides with *nothing*. `PED` is the flag that matters. |
| Prop sinks 5cm | Assigning `mesh.location` **moves** a joined mesh, because it inherits the first part's origin. Use `origin_set` alone. |
| Metal looks like stone | Accent materials were given the rock's normal map. Use the flat normal. |

Blender 5.1 + Sollumz as a `bl_ext.repo_sollumz_org.sollumz` extension. Do not
pass `--factory-startup`: it drops the extension repositories and Sollumz will
not load.
