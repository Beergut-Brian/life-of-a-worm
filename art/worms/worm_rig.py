"""Pose / mood / stage controls for the Gulp and Burp masters.

Imported by build_masters.py (to set the rest pose) and render_refs.py.
Every control is a plain transform or visibility toggle on named objects, so the
same poses can be reproduced by hand in the .blend:

  <W>_head        empty, head pivot. Scale = squash / stretch.
  <W>_jaw         lower jaw, origin on the hinge. rotation_euler.y (+) opens.
  <W>_mouth_in    empty on the hinge carrying the dark mouth interior. Follows the jaw at 0.5.
  <W>_tongue      child of the jaw. location.z lifts it out of the jaw.
  <W>_eye_<i>     empty per eye, +X = gaze. Children: sclera, pupil, catchlight, lid pivot, lash arcs.
  <W>_lidpiv_<i>  empty; rotation_euler.y closes the lid (-75 deg open .. 90 deg shut),
                  rotation_euler.x tilts it (worried).
  <W>_cheek_L/R   children of the jaw; scale 0 = hidden, 1 = bulged.
  <W>_bow/<W>_cap stage-3 feature, toggled by set_stage().
"""
import math
import bpy

WORMS = ("Gulp", "Burp")
FEATURE = {"Gulp": "bow", "Burp": "cap"}
MOOD_ORDER = ["idle", "open", "chomp_1", "chomp_2", "chomp_3",
              "squash", "happy", "worried", "sleep"]

# jaw: degrees open. lid: 0 open .. 1 shut. tilt: worried lid tilt (deg).
# lash: None / "happy" / "sleep". cheek: 0..1. head: xyz scale of the head pivot.
# eye: vertical eye scale (squeezed eyes). tongue: 0 tucked .. 1 out.
MOODS = {
    "idle":    dict(jaw=0,  lid=0.15, tilt=0,  lash=None,    cheek=0.0, head=(1, 1, 1),          eye=1.0,  tongue=0.0),
    "open":    dict(jaw=30, lid=0.0,  tilt=0,  lash=None,    cheek=0.0, head=(0.97, 1, 1.05),    eye=1.08, tongue=1.0),
    "chomp_1": dict(jaw=44, lid=0.0,  tilt=0,  lash=None,    cheek=0.0, head=(0.94, 0.98, 1.1),  eye=1.12, tongue=1.0),
    "chomp_2": dict(jaw=0,  lid=0.45, tilt=0,  lash=None,    cheek=1.0, head=(1.08, 1.12, 0.9),  eye=0.9,  tongue=0.0),
    "chomp_3": dict(jaw=8,  lid=0.35, tilt=0,  lash=None,    cheek=0.6, head=(1.03, 1.05, 0.97), eye=1.0,  tongue=0.4),
    "squash":  dict(jaw=0,  lid=0.62, tilt=0,  lash=None,    cheek=0.3, head=(1.2, 1.15, 0.72),  eye=0.75, tongue=0.0),
    "happy":   dict(jaw=16, lid=1.0,  tilt=0,  lash="happy", cheek=0.0, head=(1, 1, 1.03),       eye=1.0,  tongue=0.8),
    "worried": dict(jaw=6,  lid=0.42, tilt=24, lash=None,    cheek=0.0, head=(0.97, 1, 1.02),    eye=1.0,  tongue=0.0),
    "sleep":   dict(jaw=0,  lid=1.0,  tilt=0,  lash="sleep", cheek=0.0, head=(1.02, 1, 0.97),    eye=1.0,  tongue=0.0),
}

LID_OPEN_DEG = -75.0
LID_SHUT_DEG = 90.0
TONGUE_IN = -0.10   # tongue z offset in jaw space when tucked
TONGUE_OUT = 0.035


def ob(name):
    return bpy.data.objects.get(name)


def eyes(w):
    return sorted((o for o in bpy.data.objects if o.name.startswith(w + "_eye_")), key=lambda o: o.name)


def apply_mood(w, mood):
    m = MOODS[mood]
    ob(w + "_head").scale = m["head"]
    jaw = math.radians(m["jaw"])
    ob(w + "_jaw").rotation_euler.y = jaw
    ob(w + "_mouth_in").rotation_euler.y = jaw * 0.5
    t = ob(w + "_tongue")
    t.location.z = t["base_z"] + TONGUE_IN + (TONGUE_OUT - TONGUE_IN) * m["tongue"]
    for side in ("L", "R"):
        c = ob(f"{w}_cheek_{side}")
        s = m["cheek"]
        c.scale = (s, s, s) if s > 0 else (0.001, 0.001, 0.001)
        c.hide_render = s <= 0
        c.hide_viewport = s <= 0
    for e in eyes(w):
        i = e.name.rsplit("_", 1)[1]
        e.scale = (1, 1, m["eye"])
        piv = ob(f"{w}_lidpiv_{i}")
        piv.rotation_euler.y = math.radians(LID_OPEN_DEG + (LID_SHUT_DEG - LID_OPEN_DEG) * m["lid"])
        sign = e.get("tilt_sign", 1.0)
        piv.rotation_euler.x = math.radians(m["tilt"]) * sign
        for kind in ("happy", "sleep"):
            a = ob(f"{w}_lash_{kind}_{i}")
            a.hide_render = m["lash"] != kind
            a.hide_viewport = m["lash"] != kind


def set_stage(w, stage):
    f = ob(f"{w}_{FEATURE[w]}")
    on = stage >= 3
    for o in [f] + list(f.children_recursive):
        o.hide_render = not on
        o.hide_viewport = not on


def all_meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def set_outline(thickness):
    for o in all_meshes():
        md = o.modifiers.get("Outline")
        if md:
            md.thickness = thickness


def set_flat(flat):
    """flat=True: toon light/shadow split used for the pixel-art drawing bases."""
    for mat in bpy.data.materials:
        if mat.node_tree and "FlatMix" in mat.node_tree.nodes:
            mat.node_tree.nodes["FlatMix"].inputs[0].default_value = 1.0 if flat else 0.0
