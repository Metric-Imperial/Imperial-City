"""Build imperial_smelter as a Sollumz drawable and export a .ydr.

Run headless:
  blender.exe --background --python build_smelter.py

Everything is parametric and in METRES, with the origin pinned to the centre of
the base at (0,0,0). That origin is not cosmetic: CreateObject positions a prop
by its archetype bounds, so a mesh whose origin is not at its base is the exact
cause of props appearing to float. Building upward from z=0 makes the archetype
bounds start at z~0 and the prop sit on the ground with no runtime correction.

Materials use real GTA shaders (normal_spec / emissive), never `default.sps`,
and the albedo textures carry no baked lighting -- both were faults in the
earlier hand-made boulders that made them read as plastic and glow at night.
"""
import bpy
import bmesh
import math
import os
import sys
import addon_utils

addon_utils.enable("bl_ext.repo_sollumz_org.sollumz", default_set=True, persistent=True)
# shader_materials_v2, NOT shader_materials: only the v2 implementation tags the
# material with sollum_type = MaterialType.SHADER, and get_sollumz_materials()
# filters on exactly that. Materials from v1 are invisible to the exporter, which
# aborts with "has no Sollumz materials".
from bl_ext.repo_sollumz_org.sollumz.ydr.shader_materials_v2 import (  # noqa: E402
    create_shader,
)
from bl_ext.repo_sollumz_org.sollumz.sollumz_properties import MaterialType  # noqa: E402
from bl_ext.repo_sollumz_org.sollumz.ybn.collision_materials import (  # noqa: E402
    create_collision_material_from_index,
)
from bl_ext.repo_sollumz_org.sollumz.tools.meshhelper import (  # noqa: E402
    get_uv_map_name,
    get_color_attr_name,
)

# Sollumz reports export failures through the logging module and only says
# "check the Info Log" on stdout, which is invisible in background mode. Pipe
# every logger to stdout so failures are readable.
import logging  # noqa: E402
for _n in ("", "szio", "sollumz"):
    _lg = logging.getLogger(_n)
    _lg.setLevel(logging.DEBUG)
    _h = logging.StreamHandler(sys.stdout)
    _h.setFormatter(logging.Formatter("[SZ %(levelname)s] %(message)s"))
    _lg.addHandler(_h)

NAME = "imperial_smelter"
WORK = r"E:\FiveM - Custom Recipe\_work\smelter"
TEX = os.path.join(WORK, "textures")
ROCK = r"E:\FiveM - Custom Recipe\_work\rock3d\prop_rock_3_d+hidr"
OUT = os.path.join(WORK, "export")

# ── Dimensions (metres) ────────────────────────────────────────────────────
BODY_X, BODY_Y = 0.90, 1.00     # main furnace mass
BODY_CX = -0.28                 # furnace sits left of centre
PLINTH_X, PLINTH_Y, PLINTH_Z = 1.50, 1.20, 0.10
BODY_TOP = 0.65                 # where the barrel vault springs from
ARCH_R = BODY_X / 2.0           # vault radius -> total body height 1.10
MOUTH_R = 0.28                  # firebox opening radius
MOUTH_BASE = 0.30               # flat floor of the firebox opening
CHIM_X, CHIM_Y = -0.10, 0.24


def clear_scene():
    bpy.ops.wm.read_homefile(use_empty=True)


def activate(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)


def apply_mod(obj, mod):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(obj, width=0.02, segments=3, angle=50.0):
    """Chamfer every hard edge. Untouched 90-degree corners are the single
    biggest reason a hand-made prop reads as a video-game box: real objects
    catch a highlight along every edge."""
    m = obj.modifiers.new("bev", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.harden_normals = False
    apply_mod(obj, m)


def box(name, sx, sy, sz, x=0.0, y=0.0, z=0.0):
    """Axis-aligned box, z given as the BOTTOM of the box."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z + sz / 2.0))
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx, sy, sz)
    activate(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def cyl(name, r, h, x=0.0, y=0.0, z=0.0, axis="Z", verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h,
                                        location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    if axis == "Y":
        o.rotation_euler = (math.radians(90), 0, 0)
        activate(o)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        o.location = (x, y, z)
    else:
        o.location = (x, y, z + h / 2.0)
    activate(o)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return o


def boolean(target, cutter, op="DIFFERENCE"):
    m = target.modifiers.new("bool", "BOOLEAN")
    m.object = cutter
    m.operation = op
    m.solver = "EXACT"
    apply_mod(target, m)
    bpy.data.objects.remove(cutter, do_unlink=True)


def shade_smooth(obj, angle=40.0):
    activate(obj)
    bpy.ops.object.shade_smooth()
    # Blender 4.1+ dropped mesh.auto_smooth_angle for a modifier-based approach;
    # the angle-limited bevel above already keeps flat faces flat, so a plain
    # smooth shade is safe here for the curved parts only.
    if hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(angle)


# ── Materials ──────────────────────────────────────────────────────────────
def set_tex(mat, param, path):
    """Bind an image to a Sollumz shader parameter node."""
    if not os.path.isfile(path):
        print("  !! missing texture", path)
        return False
    img = bpy.data.images.get(os.path.basename(path)) or bpy.data.images.load(path)
    img.name = os.path.splitext(os.path.basename(path))[0]

    def bind(n):
        n.image = img
        # Without this the texture dictionary exports EMPTY -- the shader still
        # names the texture, but nothing carries the pixels, so the prop renders
        # untextured. texture_properties.embedded defaults to False.
        n.texture_properties.embedded = True
        # sollumz_texture_name is read-only -- it is derived from the image
        # datablock name, which is set above.
        return True

    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.name == param:
            return bind(n)
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is None:
            print("  (fallback slot %r for %s)" % (n.name, param))
            return bind(n)
    print("  !! no free image node for", param, "in", mat.name)
    return False


def make_materials():
    mats = {}

    # Stone masonry: Rockstar's own rock diffuse + normal, the same pair proven
    # on the ore boulders. Guarantees the smelter sits in the world's lighting.
    m = create_shader("normal_spec.sps")
    m.name = "smelter_stone"
    set_tex(m, "DiffuseSampler", os.path.join(ROCK, "prop_rock_3.dds"))
    set_tex(m, "BumpSampler", os.path.join(ROCK, "cs_rsn_sl_boulderrock_03_n.dds"))
    mats["stone"] = m

    for key, tex in (("brass", "imperial_smelter_brass"),
                     ("red", "imperial_smelter_red"),
                     ("iron", "imperial_smelter_iron")):
        m = create_shader("normal_spec.sps")
        m.name = "smelter_" + key
        set_tex(m, "DiffuseSampler", os.path.join(TEX, tex + ".dds"))
        # NOT the rock normal: it gave the metal parts stone-like relief, which
        # is why the chimney read as masonry and the anvil plate looked lumpy.
        set_tex(m, "BumpSampler", os.path.join(TEX, "imperial_smelter_flat_n.dds"))
        mats[key] = m

    # The fire self-illuminates. An emissive shader means it reads hot at night
    # without spawning a light entity, which would cost far more.
    try:
        m = create_shader("emissive.sps")
    except Exception as e:
        print("  emissive.sps unavailable (%s); falling back" % e)
        m = create_shader("normal_spec.sps")
    m.name = "smelter_fire"
    set_tex(m, "DiffuseSampler", os.path.join(TEX, "imperial_smelter_fire.dds"))
    mats["fire"] = m
    return mats


def assign(obj, mat):
    mat.sollum_type = MaterialType.SHADER
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ── Geometry ───────────────────────────────────────────────────────────────
def build(mats):
    parts = []

    # 1. Stepped plinth
    p = box("plinth", PLINTH_X, PLINTH_Y, PLINTH_Z, 0, 0, 0)
    bevel(p, 0.025)
    assign(p, mats["stone"])
    parts.append(p)

    # 2. Furnace mass: a squat box with a barrel vault on top. The vault is what
    #    stops this being a cube -- the reference is arched, not boxy.
    body = box("body", BODY_X, BODY_Y, BODY_TOP - PLINTH_Z, BODY_CX, 0, PLINTH_Z)
    vault = cyl("vault", ARCH_R, BODY_Y, BODY_CX, 0, BODY_TOP, axis="Y", verts=32)
    boolean(body, vault, "UNION")

    # 3. Firebox: a flat-floored arch cut into the front face, not a round hole.
    mouth_arch = cyl("ma", MOUTH_R, 0.95, BODY_CX, -0.12, MOUTH_BASE + 0.20,
                     axis="Y", verts=28)
    mouth_box = box("mb", MOUTH_R * 2, 0.95, 0.20, BODY_CX, -0.12 - 0.475, MOUTH_BASE)
    boolean(mouth_arch, mouth_box, "UNION")
    boolean(body, mouth_arch, "DIFFERENCE")

    bevel(body, 0.015, 2, 40)
    shade_smooth(body)
    assign(body, mats["stone"])
    parts.append(body)

    # 4. Brass surround proud of the arch mouth
    ring_o = cyl("ro", MOUTH_R + 0.07, 0.08, BODY_CX, -0.50, MOUTH_BASE + 0.20,
                 axis="Y", verts=28)
    ring_ob = box("rob", (MOUTH_R + 0.07) * 2, 0.08, 0.20, BODY_CX, -0.50, MOUTH_BASE)
    boolean(ring_o, ring_ob, "UNION")
    ring_i = cyl("ri", MOUTH_R, 0.30, BODY_CX, -0.50, MOUTH_BASE + 0.20,
                 axis="Y", verts=28)
    ring_ib = box("rib", MOUTH_R * 2, 0.30, 0.22, BODY_CX, -0.50, MOUTH_BASE - 0.01)
    boolean(ring_i, ring_ib, "UNION")
    boolean(ring_o, ring_i, "DIFFERENCE")
    ring_o.name = "arch_surround"
    bevel(ring_o, 0.008, 2, 40)
    shade_smooth(ring_o)
    assign(ring_o, mats["brass"])
    parts.append(ring_o)

    # 5. The fire itself, recessed inside the mouth
    fire = box("fire", MOUTH_R * 1.75, 0.06, 0.36, BODY_CX, -0.30, MOUTH_BASE + 0.02)
    bevel(fire, 0.02)
    assign(fire, mats["fire"])
    parts.append(fire)

    # 6. Right-hand block with its red anvil plate
    rb = box("rblock", 0.45, 0.75, 0.42, 0.48, 0.05, PLINTH_Z)
    bevel(rb, 0.03)
    assign(rb, mats["stone"])
    parts.append(rb)

    rp = box("redplate", 0.40, 0.44, 0.07, 0.48, -0.02, PLINTH_Z + 0.42)
    bevel(rp, 0.015)
    assign(rp, mats["red"])
    parts.append(rp)

    # 7. Chimney: collar then stack, offset to the back so it clears the vault
    collar = cyl("collar", 0.20, 0.13, CHIM_X, CHIM_Y, 1.00, verts=24)
    bevel(collar, 0.015, 2, 40)
    shade_smooth(collar)
    assign(collar, mats["stone"])
    parts.append(collar)

    stack = cyl("stack", 0.125, 0.30, CHIM_X, CHIM_Y, 1.13, verts=24)
    bevel(stack, 0.01, 2, 40)
    shade_smooth(stack)
    assign(stack, mats["iron"])
    parts.append(stack)

    # 8. Brass pipe curling up the right side
    # Kept inside the plinth footprint: at x=0.74 with major radius 0.17 the
    # pipe overhung the base and pushed the model's X extent to 1.70m.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.038,
                                     major_segments=20, minor_segments=10,
                                     location=(0.55, 0.18, 0.62),
                                     rotation=(math.radians(90), 0, 0))
    pipe = bpy.context.active_object
    pipe.name = "pipe"
    shade_smooth(pipe)
    assign(pipe, mats["brass"])
    parts.append(pipe)

    # 9. Ingot mould at the front, with a glowing bar in it
    trough = box("trough", 0.62, 0.20, 0.10, -0.42, -0.54, 0.10)
    bevel(trough, 0.015)
    assign(trough, mats["iron"])
    parts.append(trough)

    ingot = box("ingot", 0.50, 0.11, 0.05, -0.42, -0.54, 0.17)
    bevel(ingot, 0.012)
    assign(ingot, mats["fire"])
    parts.append(ingot)

    # Join into a single drawable model
    activate(parts[0])
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = NAME + "_mesh"
    return mesh


def box_project_uvs(obj, scale=1.0):
    """World-space box projection, written by hand.

    bpy.ops.uv.smart_project needs a real 3D viewport context and is unreliable
    headless. Box projection is also the better fit here: it gives constant
    texel density in metres, so the masonry does not stretch across the larger
    faces the way an auto-unwrap would.
    """
    me = obj.data
    uv = me.uv_layers.get(get_uv_map_name(0)) or me.uv_layers.new(name=get_uv_map_name(0))
    me.uv_layers.active = uv
    bm = bmesh.new()
    bm.from_mesh(me)
    layer = bm.loops.layers.uv.get(uv.name)
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x, co.y
            elif ax >= ay:
                u, v = co.y, co.z
            else:
                u, v = co.x, co.z
            loop[layer].uv = (u * scale, v * scale)
    bm.to_mesh(me)
    bm.free()

    # GTA shaders read a vertex colour channel; without it Sollumz warns and the
    # geometry can render darker than intended. White = no tint.
    cname = get_color_attr_name(0)
    if cname not in me.color_attributes:
        attr = me.color_attributes.new(name=cname, type="BYTE_COLOR", domain="CORNER")
        for d in attr.data:
            d.color = (1.0, 1.0, 1.0, 1.0)


def main():
    clear_scene()
    os.makedirs(OUT, exist_ok=True)

    mats = make_materials()
    mesh = build(mats)

    box_project_uvs(mesh, 1.0)

    # Origin at the base centre -- see module docstring. Note there is NO
    # mesh.location assignment here: the joined mesh inherits the plinth's
    # origin at z=0.05, so setting location to (0,0,0) MOVED the geometry down
    # by 5cm and put the base below ground. origin_set moves the origin while
    # leaving world geometry alone, which is what is actually wanted.
    bpy.context.scene.cursor.location = (0, 0, 0)
    activate(mesh)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    # Which material actually ended up on how many faces. Joining objects
    # remaps material indices, so this is the only reliable way to confirm the
    # stack really is iron and not stone.
    counts = {}
    for poly in mesh.data.polygons:
        mname = mesh.data.materials[poly.material_index].name
        counts[mname] = counts.get(mname, 0) + 1
    print("== material face counts: " + ", ".join(
        "%s=%d" % kv for kv in sorted(counts.items())))

    dims = mesh.dimensions
    bb = [mesh.matrix_world @ __import__("mathutils").Vector(c) for c in mesh.bound_box]
    zmin = min(v.z for v in bb)
    print("== MESH  %.3f x %.3f x %.3f m   zmin=%.4f   verts=%d  tris~%d"
          % (dims.x, dims.y, dims.z, zmin, len(mesh.data.vertices),
             len(mesh.data.polygons)))

    # ── Sollumz hierarchy ──────────────────────────────────────────────────
    # Built by Sollumz's own operator rather than by hand. Setting
    # sollum_type = "sollumz_drawable_model" directly LOOKS right but leaves the
    # model's LOD slots empty, and get_sollumz_materials() only collects meshes
    # registered against a LOD level -- so the exporter found zero materials and
    # aborted with "has no Sollumz materials", even though every face had one.
    activate(mesh)
    mesh.select_set(True)
    bpy.ops.sollumz.converttodrawable()

    drawable = next((o for o in bpy.data.objects
                     if o.sollum_type == "sollumz_drawable"), None)
    if drawable is None:
        print("!! converttodrawable produced no drawable")
        return
    drawable.name = NAME
    for c in drawable.children_recursive:
        if c.sollum_type == "sollumz_drawable_model":
            c.name = NAME + "_mesh"

    from bl_ext.repo_sollumz_org.sollumz.sollumz_helper import get_sollumz_materials
    found = get_sollumz_materials(drawable)
    print("== exporter sees %d material(s): %s"
          % (len(found), ", ".join(m.name for m in found)))

    # Collision: simple primitives, not the render mesh. Cheap for physics and
    # entirely adequate for something players walk into rather than shoot.
    comp = bpy.data.objects.new(NAME + "_col", None)
    bpy.context.scene.collection.objects.link(comp)
    comp.sollum_type = "sollumz_bound_composite"
    comp.parent = drawable

    for cname, sx, sy, sz, cx, cy, cz in (
        ("col_body", 1.50, 1.20, 1.10, 0.00, 0.00, 0.00),
        ("col_stack", 0.28, 0.28, 0.33, CHIM_X, CHIM_Y, 1.10),
    ):
        b = box(cname, sx, sy, sz, cx, cy, cz)
        b.sollum_type = "sollumz_bound_box"

        # Collision flags say what the bound may collide WITH. Every flag
        # defaults to False, which produces a bound that loads fine
        # (HasCollisionForModelLoaded returns true, /prop reports collision=1)
        # but that nothing can touch -- players walk straight through it.
        # These are the exact sets Rockstar uses on prop_rock_3_d.
        for fl in ("map_weapon", "map_dynamic", "map_animal", "map_cover",
                   "map_vehicle"):
            setattr(b.composite_flags1, fl, True)
        for fl in ("vehicle_not_bvh", "vehicle_bvh", "ped", "ragdoll", "animal",
                   "animal_ragdoll", "object", "plant", "projectile",
                   "explosion", "forklift_forks", "test_weapon", "test_camera",
                   "test_ai", "test_script", "test_vehicle_wheel", "glass"):
            setattr(b.composite_flags2, fl, True)
        # Export fails outright on a bound with no collision material --
        # validate_collision_materials() rejects it before writing anything.
        b.data.materials.clear()
        b.data.materials.append(create_collision_material_from_index(0))
        b.parent = comp

    activate(drawable)
    drawable.select_set(True)
    for c in drawable.children_recursive:
        c.select_set(True)

    # Draw distances: 9998 is Sollumz.s default and means "always draw at full
    # detail". A 1.5m workshop prop does not need that.
    drawable.drawable_properties.lod_dist_high = 60.0
    drawable.drawable_properties.lod_dist_med = 120.0
    drawable.drawable_properties.lod_dist_low = 250.0
    drawable.drawable_properties.lod_dist_vlow = 500.0

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, NAME + ".blend"))
    print("== saved blend")

    try:
        bpy.ops.sollumz.export_assets(directory=OUT, direct_export=True)
        print("== export op returned")
    except Exception as e:
        print("!! EXPORT FAILED:", type(e).__name__, e)

    for f in sorted(os.listdir(OUT)):
        print("   OUT:", f, os.path.getsize(os.path.join(OUT, f)))


main()
