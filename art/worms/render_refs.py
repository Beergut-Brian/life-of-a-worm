"""Render the reference sheets and low-res drawing bases from worms_master.blend.

    blender -b art/worms/worms_master.blend --python art/worms/render_refs.py [-- only=<group,...>]

groups: turnaround, expressions, lowres, side (default: all). Cycles CPU (Eevee and
Workbench crash headless on the build box: no GPU).
"""
import math
import os
import sys

sys.dont_write_bytecode = True
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import worm_rig as rig  # noqa: E402

OUT = os.path.join(HERE, "renders")
LOW = os.path.join(OUT, "lowres")
SCRATCH = os.path.join(os.path.dirname(os.path.dirname(HERE)), ".scratch", "worm_cells")
HI_OUTLINE = 0.035
PPU = {1: 16, 2: 19, 3: 22}
CANVAS = {"head": {1: 20, 2: 24, 3: 32}, "body": {1: 16, 2: 19, 3: 22}, "tail": {1: 16, 2: 19, 3: 22}}
HEAD_S3_LIFT_PX = 2   # stage-3 head canvas: head sits 2 px low to leave headroom for bow / cap

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = None
for a in args:
    if a.startswith("only="):
        ONLY = set(a[5:].split(","))


def want(g):
    return ONLY is None or g in ONLY


# ---------------------------------------------------------------- scene
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.render.threads_mode = "FIXED"
sc.render.threads = 4
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.resolution_percentage = 100
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"
sc.cycles.transparent_max_bounces = 32
sc.cycles.max_bounces = 4
sc.cycles.use_adaptive_sampling = True

world = bpy.data.worlds.new("RefWorld")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
sc.world = world

lights = {}


def sun(name, rot_deg, energy, angle_deg):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy = energy
    ld.angle = math.radians(angle_deg)
    o = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(o)
    o.rotation_euler = [math.radians(a) for a in rot_deg]
    lights[name] = o
    return o


# Sun rotations: default sun points -Z; X rot tilts toward +Y (away from the camera at -Y).
sun("key", (50, 0, -35), 2.6, 30)     # upper left, camera side
sun("fill", (70, 0, 50), 0.7, 40)     # right, low
sun("rim", (-55, 0, 20), 1.6, 20)    # behind
sun("top", (5, 0, 0), 0.8, 40)        # slight top light
sun("flat", (48, 0, -40), 1.9, 1)     # hard key for the pixel bases

cam_data = bpy.data.cameras.new("RefCam")
cam_data.type = "ORTHO"
cam_data.clip_start = 0.1
cam_data.clip_end = 200
cam = bpy.data.objects.new("RefCam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)


def light_mode(flat):
    for n, o in lights.items():
        o.hide_render = (n != "flat") if flat else (n == "flat")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.0 if flat else 0.28
    rig.set_flat(flat)
    if flat:
        sc.cycles.samples = 24
        sc.cycles.use_denoising = False
        sc.cycles.pixel_filter_type = "BOX"
        sc.cycles.filter_width = 1.0
    else:
        sc.cycles.samples = 40
        sc.cycles.use_denoising = True
        sc.cycles.pixel_filter_type = "BLACKMAN_HARRIS"
        sc.cycles.filter_width = 1.5


# ---------------------------------------------------------------- worm state
def worm_objs(w):
    return list(bpy.data.collections[w].all_objects)


def part_set(w, part):
    def tree(name):
        o = bpy.data.objects[name]
        return {o.name} | {c.name for c in o.children_recursive}
    if part == "head":
        return tree(f"{w}_head")
    if part == "body":
        return tree(f"{w}_body_3")
    if part == "tail":
        return tree(f"{w}_tail")
    if part == "expr":
        return tree(f"{w}_head") | tree(f"{w}_body_1")
    return {o.name for o in worm_objs(w)}


def pose(w, mood="idle", stage=1, part="all", yaw_deg=0.0):
    for other in rig.WORMS:
        bpy.data.collections[other].hide_render = other != w
    for o in worm_objs(w):
        o.hide_render = False
    root = bpy.data.objects[f"{w}_root"]
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, math.radians(yaw_deg))
    rig.apply_mood(w, mood)
    rig.set_stage(w, stage)
    keep = part_set(w, part)
    for o in worm_objs(w):
        if o.name not in keep:
            o.hide_render = True
    bpy.context.view_layer.update()


def visible_bbox(w):
    """World-space x/z extent of the visible meshes (camera looks along +Y)."""
    dg = bpy.context.evaluated_depsgraph_get()
    xs, zs = [], []
    for o in worm_objs(w):
        if o.type not in ("MESH", "CURVE") or o.hide_render:
            continue
        oe = o.evaluated_get(dg)
        for c in oe.bound_box:
            v = oe.matrix_world @ Vector(c)
            xs.append(v.x)
            zs.append(v.z)
    return min(xs), max(xs), min(zs), max(zs)


def render(path, rx, ry, cx, cz, ortho):
    sc.render.resolution_x = rx
    sc.render.resolution_y = ry
    cam_data.sensor_fit = "HORIZONTAL" if rx >= ry else "VERTICAL"
    cam_data.ortho_scale = ortho
    cam.location = (cx, -50, cz)
    sc.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- sheets
def load_px(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)  # bottom-up rows


def compose(path, cells, cols, cw, ch):
    rows = (len(cells) + cols - 1) // cols
    W, H = cols * cw, rows * ch
    sheet = np.zeros((H, W, 4), dtype=np.float32)
    for i, cp in enumerate(cells):
        px = load_px(cp)
        r, c = divmod(i, cols)
        y0 = H - (r + 1) * ch   # bottom-up
        sheet[y0:y0 + ch, c * cw:(c + 1) * cw] = px
    img = bpy.data.images.new("sheet", W, H, alpha=True)
    img.colorspace_settings.name = "sRGB"
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("sheet", path)


# ---------------------------------------------------------------- jobs
def turnaround(w):
    light_mode(False)
    rig.set_outline(HI_OUTLINE)
    views = [("front", -90), ("three_quarter", -40), ("side", 0), ("back", 90)]
    cw, ch, ortho = 768, 384, 7.0
    cells = []
    for name, yaw in views:
        pose(w, "idle", 1, "all", yaw)
        x0, x1, z0, z1 = visible_bbox(w)
        p = os.path.join(SCRATCH, f"turn_{w}_{name}.png")
        render(p, cw, ch, (x0 + x1) / 2, (z0 + z1) / 2, ortho)
        cells.append(p)
    compose(os.path.join(OUT, f"turnaround_{w.lower()}.png"), cells, 2, cw, ch)


def expressions(w):
    light_mode(False)
    rig.set_outline(HI_OUTLINE)
    cells = []
    for mood in rig.MOOD_ORDER:
        pose(w, mood, 1, "expr")
        p = os.path.join(OUT, f"expr_{w.lower()}_{mood}.png")
        render(p, 384, 384, -0.42, 0.02, 2.45)
        cells.append(p)
    compose(os.path.join(OUT, f"expressions_{w.lower()}.png"), cells, 3, 384, 384)


def part_center(w, part, stage):
    if part == "head":
        lift = HEAD_S3_LIFT_PX / PPU[stage] if stage == 3 else 0.0
        return 0.0, lift
    o = bpy.data.objects[f"{w}_body_3" if part == "body" else f"{w}_tail"]
    return o.matrix_world.translation.x, 0.0


def lowres(w):
    light_mode(True)
    jobs = []
    for s in (1, 2, 3):
        for part in ("head", "body", "tail"):
            jobs.append((s, part, "idle", f"{w.lower()}_s{s}_{part}"))
    for mood in rig.MOOD_ORDER:
        jobs.append((1, "head", mood, f"{w.lower()}_s1_head_{mood}"))
    for s, part, mood, base in jobs:
        rig.set_outline(0.6 / PPU[s])
        pose(w, mood, s, part)
        cx, cz = part_center(w, part, s)
        n = CANVAS[part][s]
        ortho = n / PPU[s]
        render(os.path.join(LOW, base + ".png"), n, n, cx, cz, ortho)
        render(os.path.join(LOW, base + "_x8.png"), n * 8, n * 8, cx, cz, ortho)


def side(w):
    light_mode(False)
    rig.set_outline(HI_OUTLINE)
    pose(w, "idle", 3, "all")
    x0, x1, z0, z1 = visible_bbox(w)
    render(os.path.join(OUT, f"side_{w.lower()}.png"), 1024, 320, (x0 + x1) / 2, (z0 + z1) / 2, 6.75)


for w in rig.WORMS:
    if want("turnaround"):
        turnaround(w)
    if want("expressions"):
        expressions(w)
    if want("lowres"):
        lowres(w)
    if want("side"):
        side(w)
print("done")
