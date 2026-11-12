"""Build the Gulp (P1) and Burp (P2) 3D masters procedurally and save worms_master.blend.

    blender -b --factory-startup --python art/worms/build_masters.py

This script is the source of truth: the .blend is regenerated from it. Units: 1 = one
stage-1 body segment height. The worm lies along X with the head at the origin facing +X;
the gameplay (side) view looks along +Y, so the visible side of the head is -Y.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import worm_rig  # noqa: E402

OUT = os.path.join(HERE, "worms_master.blend")

# ---------------------------------------------------------------- dimensions
HEAD = (0.57, 0.56, 0.58)      # head half-extents x, y, z (1.16 tall + eye/outline ~ 1.25)
HEAD_P = 2.3                   # superellipse exponent (2 = ellipsoid, higher = chunkier)
BEAD_RX, BEAD_R, BEAD_P = 0.475, 0.455, 2.4   # body bead: 0.95 long, ~1.0 tall with band + ink
BEAD_STEP = 0.85               # bead spacing (beads overlap ~0.1)
FIRST_BEAD_X = -0.9
N_BEADS = 5
TAIL_RX, TAIL_R0, TAIL_R1 = 0.45, 0.42, 0.29  # tail: 0.9 long, ~0.84 tall at the join -> ~0.6 at the tip
BAND_RAISE, BAND_HALF_W = 0.012, 0.12
MOUTH_ZF, MOUTH_K, MOUTH_GAP = -0.06, 0.28, 0.014   # mouth plane z = ZF + K*(x - HEAD.x), half gap
OUTLINE = 0.035

COLORS = {
    "Gulp": dict(body="3cc24a", belly="9be86a", feature="ff5fa2"),
    "Burp": dict(body="e4393c", belly="8e1c2a", feature="3a6dff"),
}
BAND = "d8d8d8"
INK = "140c12"
PUPIL = "1a1220"
SCLERA = "ffffff"
MOUTH = "5a1424"
TONGUE = "ff7a8a"


# ---------------------------------------------------------------- helpers
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def make_mat(name, hx, rough=0.32, coat=0.25, emit=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    col = hexcol(hx)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    pr = nt.nodes.new("ShaderNodeBsdfPrincipled")
    pr.inputs["Base Color"].default_value = col
    pr.inputs["Roughness"].default_value = rough
    if "Coat Weight" in pr.inputs:
        pr.inputs["Coat Weight"].default_value = coat
        pr.inputs["Coat Roughness"].default_value = 0.15
    if emit:
        pr.inputs["Emission Color"].default_value = col
        pr.inputs["Emission Strength"].default_value = emit
    toon = nt.nodes.new("ShaderNodeBsdfToon")
    toon.inputs["Color"].default_value = col
    toon.inputs["Size"].default_value = 0.5
    toon.inputs["Smooth"].default_value = 0.03
    amb = nt.nodes.new("ShaderNodeEmission")
    amb.inputs["Color"].default_value = col
    amb.inputs["Strength"].default_value = 0.45 if not emit else 1.0
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(toon.outputs[0], add.inputs[0])
    nt.links.new(amb.outputs[0], add.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.name = "FlatMix"
    mix.inputs[0].default_value = 0.0
    nt.links.new(pr.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    mat.diffuse_color = col
    return mat


def make_ink():
    """Inverted-hull ink: only the hull's back faces, only for camera rays."""
    mat = bpy.data.materials.new("Ink")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = hexcol(INK)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    lp = nt.nodes.new("ShaderNodeLightPath")
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(lp.outputs["Is Camera Ray"], inv.inputs[1])
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    mx.use_clamp = True
    nt.links.new(geo.outputs["Backfacing"], mx.inputs[0])
    nt.links.new(inv.outputs[0], mx.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mx.outputs[0], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    mat.diffuse_color = hexcol(INK)
    return mat


def link(obj, coll):
    coll.objects.link(obj)
    return obj


def parent(child, par, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    child.parent = par
    child.matrix_parent_inverse = Matrix.Identity(4)
    child.location = loc
    child.rotation_euler = rot
    child.scale = scale
    return child


def empty(name, coll, size=0.2):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = size
    return link(e, coll)


def mesh_obj(name, bm, coll, mats, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    return link(bpy.data.objects.new(name, me), coll)


def add_outline(obj, ink, thick=OUTLINE):
    if ink.name not in [m.name for m in obj.data.materials if m]:
        obj.data.materials.append(ink)
    md = obj.modifiers.new("Outline", "SOLIDIFY")
    md.thickness = thick
    md.offset = 1.0
    md.use_flip_normals = True
    md.use_rim = False
    md.use_even_offset = True
    md.material_offset = 32  # clamps to the last slot (Ink)
    return md


def add_subsurf(obj, levels=2):
    md = obj.modifiers.new("Subsurf", "SUBSURF")
    md.levels = levels
    md.render_levels = levels
    return md


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


def rev_bm(rx, radius_fn, p=2.4, nx=20, nseg=24, ry=1.0):
    """Surface of revolution about X (superellipse profile). Ring vertex 0 sits at the
    bottom so face boundaries land on exact angles (60 deg from the bottom = lower 25%)."""
    bm = bmesh.new()
    rings = []
    ts = [math.pi * (i + 1) / (nx + 1) for i in range(nx)]
    for t in ts:
        x = -rx * spow(math.cos(t), 2.0 / p)
        r = radius_fn(x) * abs(math.sin(t)) ** (2.0 / p)
        ring = []
        for j in range(nseg):
            a = 2 * math.pi * j / nseg
            ring.append(bm.verts.new((x, r * math.sin(a) * ry, -r * math.cos(a))))
        rings.append(ring)
    p0 = bm.verts.new((-rx, 0, 0))
    p1 = bm.verts.new((rx, 0, 0))
    for j in range(nseg):
        k = (j + 1) % nseg
        bm.faces.new((p0, rings[0][k], rings[0][j]))
        bm.faces.new((p1, rings[-1][j], rings[-1][k]))
        for i in range(nx - 1):
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    bm.normal_update()
    return bm


def assign_belly(bm, idx=1, max_angle_deg=60.0):
    for f in bm.faces:
        c = f.calc_center_median()
        r = math.hypot(c.y, c.z)
        if r < 1e-6:
            continue
        ang = math.degrees(math.atan2(abs(c.y), -c.z))
        if ang < max_angle_deg:
            f.material_index = idx


def ellipsoid_bm(rx, ry, rz, segs=32, rings=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    bmesh.ops.scale(bm, vec=(rx, ry, rz), verts=bm.verts)
    return bm


def torus_bm(R, r, nu=32, nv=12):
    """Torus lying in the XZ plane (hole faces +-Y)."""
    bm = bmesh.new()
    grid = []
    for i in range(nu):
        u = 2 * math.pi * i / nu
        row = []
        for j in range(nv):
            v = 2 * math.pi * j / nv
            rr = R + r * math.cos(v)
            row.append(bm.verts.new((rr * math.cos(u), r * math.sin(v), rr * math.sin(u))))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            a, b = grid[i][j], grid[(i + 1) % nu][j]
            c, d = grid[(i + 1) % nu][(j + 1) % nv], grid[i][(j + 1) % nv]
            bm.faces.new((a, b, c, d))
    bm.normal_update()
    return bm


def band_bm(radius_at, half_w, raise_, nu=48, nv=10):
    """Raised ring around X: a flattened tube hugging the bead surface."""
    bm = bmesh.new()
    grid = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        row = []
        for j in range(nv):
            v = 2 * math.pi * j / nv
            x = half_w * math.cos(v)
            r = radius_at(x) - 0.06 + (raise_ + 0.06) * max(0.0, math.sin(v)) ** 0.6 \
                - 0.06 * max(0.0, -math.sin(v))
            row.append(bm.verts.new((x, r * math.sin(a), -r * math.cos(a))))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            a, b = grid[i][j], grid[(i + 1) % nu][j]
            c, d = grid[(i + 1) % nu][(j + 1) % nv], grid[i][(j + 1) % nv]
            bm.faces.new((a, d, c, b))
    bm.normal_update()
    return bm


def hemishell_bm(radius, segs=32, rings=16):
    bm = ellipsoid_bm(radius, radius, radius, segs, rings)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    return bm


def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)


def cutter(coll, offset):
    """Big cube whose top face is the mouth plane shifted by offset along its normal."""
    n = Vector((-MOUTH_K, 0, 1)).normalized()
    p = Vector((HEAD[0], 0, MOUTH_ZF)) + n * offset
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=4.0)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new("cutter", me), coll)
    o.rotation_euler = (0, -math.atan(MOUTH_K), 0)
    o.location = p - n * 2.0
    return o


def mouth_z(x):
    return MOUTH_ZF + MOUTH_K * (x - HEAD[0])


def head_radius_fn(x):
    return 1.0  # profile shape handled in rev_bm; per-axis scale applied after


# ---------------------------------------------------------------- worm parts
def build_head(w, coll, M, root):
    head = parent(empty(f"{w}_head", coll, 0.3), root)

    # base head: superellipsoid of revolution, scaled to HEAD
    def mk_base():
        bm = rev_bm(1.0, lambda x: 1.0, p=HEAD_P, nx=32, nseg=48)
        bmesh.ops.scale(bm, vec=HEAD, verts=bm.verts)
        assign_belly(bm)
        return bm

    n = Vector((-MOUTH_K, 0, 1)).normalized()
    pieces = {}
    for part, op, off in (("skull", "DIFFERENCE", MOUTH_GAP), ("jaw", "INTERSECT", -MOUTH_GAP)):
        o = mesh_obj(f"{w}_{part}", mk_base(), coll, [M["body"], M["belly"], M["mouth"]])
        c = cutter(coll, off)
        md = o.modifiers.new("cut", "BOOLEAN")
        md.operation = op
        md.solver = "EXACT"
        md.object = c
        apply_modifiers(o)
        bpy.data.objects.remove(c)
        # cap faces -> mouth material, flat shaded
        for poly in o.data.polygons:
            pn = Vector(poly.normal)
            if abs(abs(pn.dot(n)) - 1.0) < 1e-3:
                poly.material_index = 2
                poly.use_smooth = False
            else:
                poly.use_smooth = True
        pieces[part] = o

    skull, jaw = pieces["skull"], pieces["jaw"]
    parent(skull, head)
    # jaw origin on the hinge (rear end of the cut, mid-plane)
    xs = [v.co.x for v in jaw.data.vertices]
    hx = min(xs) + 0.01
    hinge = Vector((hx, 0, mouth_z(hx) - MOUTH_GAP))
    jaw.data.transform(Matrix.Translation(-hinge))
    parent(jaw, head, loc=hinge)

    # mouth interior (dark), on a pivot that follows the jaw at half angle
    mpiv = parent(empty(f"{w}_mouth_in", coll, 0.1), head, loc=hinge)
    bx = 0.02
    blob = mesh_obj(f"{w}_mouth_blob", ellipsoid_bm(0.38, 0.40, 0.19), coll, [M["mouth"]])
    parent(blob, mpiv, loc=Vector((bx, 0, mouth_z(bx))) - hinge, rot=(0, -math.atan(MOUTH_K), 0))

    # tongue on the jaw floor
    tx = 0.28
    tongue = mesh_obj(f"{w}_tongue", ellipsoid_bm(0.25, 0.2, 0.08), coll, [M["tongue"]])
    tloc = Vector((tx, 0, mouth_z(tx))) - hinge
    parent(tongue, jaw, loc=tloc, rot=(0, -math.atan(MOUTH_K), 0))
    tongue["base_z"] = tloc.z

    # cheeks (chomp bulge), ride on the jaw
    for side, sy in (("L", -1), ("R", 1)):
        ch = mesh_obj(f"{w}_cheek_{side}", ellipsoid_bm(0.2, 0.2, 0.18), coll, [M["body"]])
        parent(ch, jaw, loc=Vector((0.08, sy * 0.40, -0.30)) - hinge)
        add_subsurf(ch, 1)
        add_outline(ch, M["ink"])

    for o in (skull, jaw):
        add_outline(o, M["ink"])
    return head


def head_surface(az_deg, el_deg):
    """Point and outward normal on the head (ellipsoid approximation) for az/el."""
    a, e = math.radians(az_deg), math.radians(el_deg)
    d = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
    # scale to superellipsoid surface along d
    s = (sum(abs(d[i] / HEAD[i]) ** HEAD_P for i in range(3))) ** (-1.0 / HEAD_P)
    p = d * s
    nrm = Vector((spow(p.x / HEAD[0], HEAD_P - 1) / HEAD[0],
                  spow(p.y / HEAD[1], HEAD_P - 1) / HEAD[1],
                  spow(p.z / HEAD[2], HEAD_P - 1) / HEAD[2])).normalized()
    return p, nrm


def gaze_vec(az_deg, el_deg):
    a, e = math.radians(az_deg), math.radians(el_deg)
    return Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))


def lash_curve(name, coll, mat, R, kind, bevel):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    n = 15
    sp.points.add(n - 1)
    for i in range(n):
        s = -1 + 2 * i / (n - 1)
        th = math.radians(62 * s)
        if kind == "happy":   # upward arc  ^
            ph = math.radians(-4 + 26 * (1 - s * s))
        else:                 # sleepy arc, sagging  U
            ph = math.radians(6 - 22 * (1 - s * s))
        v = Vector((math.cos(ph) * math.cos(th), math.cos(ph) * math.sin(th), math.sin(ph))) * R
        sp.points[i].co = (v.x, v.y, v.z, 1.0)
    cu.materials.append(mat)
    return link(bpy.data.objects.new(name, cu), coll)


def build_eye(w, i, coll, M, head, az, el, r, gaze, inset, pupil_scale=1.0, tilt_sign=1.0):
    p, nrm = head_surface(az, el)
    c = p - nrm * (inset * r)
    piv = parent(empty(f"{w}_eye_{i}", coll, r), head, loc=c,
                 rot=gaze.to_track_quat("X", "Z").to_euler())
    piv["tilt_sign"] = tilt_sign
    scl = mesh_obj(f"{w}_sclera_{i}", ellipsoid_bm(r, r, r, 32, 16), coll, [M["sclera"]])
    parent(scl, piv)
    add_outline(scl, M["ink"])
    pr = 0.62 * r * pupil_scale
    pup = mesh_obj(f"{w}_pupil_{i}", ellipsoid_bm(0.3 * r, pr, pr, 32, 16), coll, [M["pupil"]])
    parent(pup, piv, loc=(0.76 * r, 0, 0))
    cl = mesh_obj(f"{w}_catch_{i}", ellipsoid_bm(0.16 * r, 0.16 * r, 0.16 * r, 16, 8), coll, [M["catch"]])
    parent(cl, piv, loc=Vector((0.82, -0.25, 0.42)).normalized() * (1.03 * r))
    lp = parent(empty(f"{w}_lidpiv_{i}", coll, r), piv)
    lid = mesh_obj(f"{w}_lid_{i}", hemishell_bm(1.1 * r), coll, [M["body"]])
    parent(lid, lp)
    sm = lid.modifiers.new("Shell", "SOLIDIFY")
    sm.thickness = 0.08 * r
    sm.offset = -1.0
    add_outline(lid, M["ink"])
    bev = max(0.018, 0.09 * r)
    for kind in ("happy", "sleep"):
        lc = lash_curve(f"{w}_lash_{kind}_{i}", coll, M["pupil"], 1.1 * r + 0.01, kind, bev)
        parent(lc, piv)
    return piv


def build_bow(w, coll, M, head):
    bow = parent(empty(f"{w}_bow", coll, 0.15), head, loc=(-0.14, 0, 0.6), rot=(0, 0, 0))
    for side, sx in (("L", -1), ("R", 1)):
        lp = mesh_obj(f"{w}_bow_loop_{side}", torus_bm(0.085, 0.045), coll, [M["feature"]])
        parent(lp, bow, loc=(sx * 0.12, 0, 0.035), rot=(0, sx * math.radians(-22), 0), scale=(1.35, 0.75, 1.0))
        add_subsurf(lp, 1)
        add_outline(lp, M["ink"], 0.025)
    kn = mesh_obj(f"{w}_bow_knot", ellipsoid_bm(0.06, 0.055, 0.06, 24, 12), coll, [M["feature"]])
    parent(kn, bow, loc=(0, 0, 0.02))
    add_outline(kn, M["ink"], 0.025)
    return bow


def build_cap(w, coll, M, head):
    cap = parent(empty(f"{w}_cap", coll, 0.15), head, loc=(-0.04, 0, 0.42))
    crown = mesh_obj(f"{w}_cap_crown", ellipsoid_bm(0.47, 0.47, 0.30, 48, 24), coll, [M["feature"]])
    parent(crown, cap)
    add_outline(crown, M["ink"])
    brim = mesh_obj(f"{w}_cap_brim", ellipsoid_bm(0.25, 0.34, 0.035, 48, 12), coll, [M["feature"]])
    parent(brim, cap, loc=(0.37, 0, 0.02), rot=(0, math.radians(10), 0))
    add_outline(brim, M["ink"], 0.025)
    btn = mesh_obj(f"{w}_cap_button", ellipsoid_bm(0.05, 0.05, 0.035, 16, 8), coll, [M["feature"]])
    parent(btn, cap, loc=(0, 0, 0.30))
    add_outline(btn, M["ink"], 0.02)
    return cap


def bead_radius(x):
    return BEAD_R


def tail_radius(x):
    t = (x + TAIL_RX) / (2 * TAIL_RX)  # 0 at the tip (-X), 1 at the join (+X)
    return TAIL_R1 + (TAIL_R0 - TAIL_R1) * t


def build_worm(w, ink, band, shared):
    coll = bpy.data.collections.new(w)
    bpy.context.scene.collection.children.link(coll)
    cols = COLORS[w]
    M = dict(shared)
    M["body"] = make_mat(f"{w}_body", cols["body"])
    M["belly"] = make_mat(f"{w}_belly", cols["belly"])
    M["feature"] = make_mat(f"{w}_feature", cols["feature"])
    M["ink"] = ink
    M["band"] = band

    root = empty(f"{w}_root", coll, 0.5)
    head = build_head(w, coll, M, root)

    if w == "Gulp":
        # one big eye, centred on the head, gazing forward and toward the viewer
        build_eye(w, 0, coll, M, head, az=0, el=36, r=0.27, gaze=gaze_vec(-38, 6), inset=0.5)
        build_bow(w, coll, M, head)
    else:
        # two small eyes; the pair is turned toward the viewer (-Y) so both read side-on,
        # pupils turned toward each other (a little cross-eyed)
        build_eye(w, 0, coll, M, head, az=-56, el=30, r=0.15, gaze=gaze_vec(-22, 4), inset=0.35,
                  pupil_scale=1.05, tilt_sign=1.0)
        build_eye(w, 1, coll, M, head, az=-10, el=30, r=0.15, gaze=gaze_vec(-78, 4), inset=0.35,
                  pupil_scale=1.05, tilt_sign=-1.0)
        build_cap(w, coll, M, head)

    for i in range(N_BEADS):
        x = FIRST_BEAD_X - BEAD_STEP * i
        bm = rev_bm(BEAD_RX, bead_radius, p=BEAD_P, nx=20, nseg=24)
        assign_belly(bm)
        b = mesh_obj(f"{w}_body_{i + 1}", bm, coll, [M["body"], M["belly"]])
        parent(b, root, loc=(x, 0, 0))
        add_subsurf(b)
        add_outline(b, ink)
        bd = mesh_obj(f"{w}_band_{i + 1}", band_bm(lambda xx: BEAD_R * (1 - abs(xx / BEAD_RX) ** BEAD_P) ** (1 / BEAD_P),
                                                     BAND_HALF_W, BAND_RAISE), coll, [band])
        parent(bd, b)
        add_subsurf(bd, 1)
        add_outline(bd, ink)

    tx = FIRST_BEAD_X - BEAD_STEP * (N_BEADS - 1) - 0.78
    bm = rev_bm(TAIL_RX, tail_radius, p=2.2, nx=20, nseg=24)
    assign_belly(bm)
    t = mesh_obj(f"{w}_tail", bm, coll, [M["body"], M["belly"]])
    parent(t, root, loc=(tx, 0, 0))
    add_subsurf(t)
    add_outline(t, ink)
    return root


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ink = make_ink()
    band = make_mat("Band", BAND, rough=0.4, coat=0.1)
    shared = dict(
        sclera=make_mat("Sclera", SCLERA, rough=0.15, coat=0.4),
        pupil=make_mat("Pupil", PUPIL, rough=0.12, coat=0.5),
        catch=make_mat("Catchlight", SCLERA, rough=0.5, coat=0.0, emit=1.0),
        mouth=make_mat("MouthInside", MOUTH, rough=0.45, coat=0.0),
        tongue=make_mat("Tongue", TONGUE, rough=0.35, coat=0.2),
    )
    roots = {w: build_worm(w, ink, band, shared) for w in worm_rig.WORMS}
    roots["Burp"].location = (0, 0, -2.5)   # parked below Gulp in the .blend; renders move it
    for w in worm_rig.WORMS:
        worm_rig.apply_mood(w, "idle")
        worm_rig.set_stage(w, 3)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
    print("saved", OUT)


if __name__ == "__main__":
    main()
