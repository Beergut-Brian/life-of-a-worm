"""Lantern Deep characters with Arcade Chomp faces (Docket D92: B + A's faces).

    python3 art/tools/lantern_faces.py

Sprite sets other lanes swap in (names documented in docs/art-direction.md "This game"):
  assets/sprites/worm/lantern/   head.png, segment.png, band.png (white, tinted by the slot colour in
                                 code, as the proto set), face_p1_0..2.png (one big lidded eye),
                                 face_p2_0..2.png (two small cross-eyed eyes); 0 shut mouth, 1 open,
                                 2 wide chomp. Same sizes and pivots as assets/proto/worm/. *_n.png normals.
  assets/sprites/foods/<id>_calm.png, <id>_wide.png   (wide-eyed when a bigger worm nears)
  assets/sprites/creatures/<id>_calm.png, _wide.png, _smug.png
Faces are A's: big white eyes, 1 px ink, a loud mouth. Machines and vehicles get no face (the boot,
the lawnmower). Every colour is snapped to art/palette/lantern_deep.gpl plus the slot colours.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from worm_looks import LOOKS, mix, rgb  # noqa: E402
from pix import Spr, eye, mouth_o, smirk, char_ramp  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
B = LOOKS["b"]
ST = B["style"]
INK = B["char_outline"]
MOUTH = (90, 16, 34)
WHITE_RAMP = ["#8c8c8c", "#bdbdbd", "#ffffff", "#ffffff"]


def out(*p):
    d = os.path.join(ROOT, "assets", "sprites", *p[:-1])
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, p[-1])


# ---- worm set --------------------------------------------------------------------------------

def worm_set():
    head = Spr(20, 20, ST)
    head.ell(10, 10, 8, 8, WHITE_RAMP)
    head.outline(INK)
    head.save(out("worm", "lantern", "head.png"), normals=True)
    seg = Spr(16, 16, ST)
    seg.ell(8, 8, 6.5, 6.5, WHITE_RAMP)
    seg.outline(INK)
    seg.save(out("worm", "lantern", "segment.png"), normals=True)
    band = Spr(16, 16, ST)
    for y in range(4, 12):
        for x in range(6, 10):
            if (x - 7.5) ** 2 / 4 + (y - 7.5) ** 2 / 20 <= 1.0:
                band.put(x, y, "#ffffff")
    band.save(out("worm", "lantern", "band.png"))
    for p in (1, 2):
        for m in range(3):
            f = Spr(20, 20, ST)
            f.lid = (60, 60, 60)
            _mouth(f, m)
            if p == 1:   # one big eye with a lid (A size: radius 4.5 on a 16 px head)
                f.lid = mix("#3cc24a", INK, 0.35)
                eye(f, 9.5, 6.5, 4.6, 0.6, 0.1, lid=0.2 if m < 2 else 0.05, ink=rgb(INK))
            else:        # two small eyes, a little cross-eyed
                eye(f, 7.5, 6.2, 2.7, 1, 0.35, ink=rgb(INK))
                eye(f, 12.6, 5.6, 2.7, -1, 0.35, ink=rgb(INK))
            f.save(out("worm", "lantern", "face_p%d_%d.png" % (p, m)))


def _mouth(f, m):
    """Facing +x like the proto faces: 0 a grin, 1 open, 2 a wide chomp with teeth."""
    if m == 0:
        for x in range(11, 17):
            f.put(x, 13 + (1 if 12 < x < 16 else 0), INK)
        return
    h = 2 if m == 1 else 5
    for y in range(12 - h, 13 + h):
        for x in range(12, 19):
            if abs(y - 12) <= h * (x - 11) / 7.0 + 0.5:
                f.put(x, y, MOUTH)
    for x in range(12, 19):
        for y in range(12 - h - 1, 14 + h):
            if f.get(x, y)[3] and f.get(x, y)[:3] == MOUTH and (
                    not f.get(x, y - 1)[3] or not f.get(x, y + 1)[3]):
                pass
    if m == 2:
        f.put(17, 8, "#ffffff"); f.put(17, 16, "#ffffff"); f.put(15, 9, "#ffffff")
    f.put(13, 12, (220, 90, 110))


# ---- faces on things ---------------------------------------------------------------------------

def face(s, cx, cy, r, mood, gap=None):
    gap = gap if gap is not None else r * 2.1
    s.lid = getattr(s, "lid", (60, 60, 90))
    ink = rgb(INK)
    if mood == "calm":
        eye(s, cx - gap / 2, cy, r, 0.4, 0.2, ink=ink)
        eye(s, cx + gap / 2, cy, r, 0.4, 0.2, ink=ink)
        smirk(s, int(cx - 1), int(cy + r + 2), 3, ink=ink)
    elif mood == "wide":
        eye(s, cx - gap / 2, cy - 0.5, r + 0.8, 0, -0.4, ink=ink)
        eye(s, cx + gap / 2, cy - 0.5, r + 0.8, 0, -0.4, ink=ink)
        mouth_o(s, cx, cy + r + 2.5, max(1, r * 0.45), ink=MOUTH)
        s.put(int(cx + gap / 2 + r + 2), int(cy - r - 1), "#7fd0ff")   # sweat drop
        s.put(int(cx + gap / 2 + r + 2), int(cy - r), "#7fd0ff")
    else:  # smug: half lids and a smirk
        eye(s, cx - gap / 2, cy, r, 0.6, 0.2, lid=0.5, ink=ink)
        eye(s, cx + gap / 2, cy, r, 0.6, 0.2, lid=0.5, ink=ink)
        smirk(s, int(cx - 2), int(cy + r + 2), 4, ink=ink)


def body(w, h, parts, colour, lid=None):
    s = Spr(w, h, ST)
    ramp = char_ramp(colour, INK, True)
    for (x, y, rx, ry) in parts:
        s.ell(x, y, rx, ry, ramp)
    s.outline(INK)
    s.lid = lid or ramp[1]
    return s


FOODS = {
    # id: (w, h, parts, colour, face centre x, y, eye r)
    "seed": (14, 12, [(7, 6.5, 5.5, 4.2)], "#c8a060", 7, 6, 1.8),
    "pebble": (14, 12, [(7, 6.5, 5.5, 4.5)], "#988a76", 7, 6, 1.8),
    "boulder": (26, 22, [(13, 11.5, 11, 9.5)], "#7a8296", 13, 10, 3.2),
    "root": (16, 12, [(5, 6, 3.5, 3), (9, 6.5, 4, 3.2), (13, 7, 2.5, 2)], "#a07848", 8, 5.5, 1.8),
    "mushroom": (14, 16, [(7, 6, 6, 4.5), (7, 11, 2.5, 4)], "#c48ae0", 7, 6, 1.7),
    "crumb": (12, 10, [(6, 5.5, 4.5, 3.5)], "#e0b070", 6, 5, 1.5),
    "honeydew": (14, 14, [(7, 7.5, 5.5, 5.5)], "#ffd24a", 7, 7, 1.8),
    "bug_egg": (12, 14, [(6, 7.5, 4.5, 5.5)], "#fff6dc", 6, 7, 1.6),
    "crystal": (14, 16, [(7, 9, 5, 6)], "#59e6ff", 7, 8.5, 1.8),
    "nugget": (16, 13, [(8, 7, 6.5, 5)], "#f2c84a", 8, 6.5, 2.0),
}

CREATURES = {
    # grub (stage 1): three round blobs
    "grub": (22, 14, [(4.5, 8, 3.5, 3.5), (9, 8.5, 4, 4), (14.5, 7.5, 5, 5)], "#f3e2b0", 14.5, 7, 2.0),
    # ant (stage 1): small, head forward
    "ant": (16, 11, [(3.5, 6.5, 3, 2.6), (7.5, 6.5, 2, 2), (12, 5.5, 3.5, 3.5)], "#8a3a24", 12, 5, 1.5),
    # ladybird (pet, stage 1)
    "ladybird": (16, 13, [(7, 7, 6, 5.2), (12.5, 7.5, 3, 3)], "#e05a2a", 12.5, 7, 1.4),
    # beetle (stage 2): round, shiny; >= 1.25x a stage-1 head
    "beetle": (30, 22, [(17, 11, 11, 8.5), (7, 13, 5.5, 5)], "#4a3fa8", 7, 12, 2.4),
    # apex beetle (dirt ring): bigger still
    "apex_beetle": (44, 32, [(25, 16, 16, 12.5), (10, 19, 8, 7.5)], "#5a2f8a", 10, 18, 3.4),
    # bird (stage 3): round body, beak
    "bird": (36, 30, [(18, 18, 13, 10.5), (26, 10, 7, 6.5)], "#d07a3a", 26, 9, 2.6),
}


def food_set():
    for fid, (w, h, parts, col, fx, fy, r) in FOODS.items():
        for mood in ("calm", "wide"):
            s = body(w, h, parts, col)
            if fid == "mushroom":   # stem cream, cap colour
                pass
            face(s, fx, fy, r, mood)
            s.save(out("foods", "%s_%s.png" % (fid, mood)), normals=True)


def creature_set():
    for cid, (w, h, parts, col, fx, fy, r) in CREATURES.items():
        for mood in ("calm", "wide", "smug"):
            s = body(w, h, parts, col)
            if cid in ("beetle", "apex_beetle"):   # shell sheen + head darker
                for (x, y) in ((14, 5), (15, 5), (14, 6)):
                    s.put(x if cid == "beetle" else x * 1.4, y if cid == "beetle" else y * 1.3, "#ffffff")
            if cid == "bird":
                for y in range(8, 12):
                    for x in range(32, 36 - (y - 8)):
                        s.put(x, y, "#f2c84a")
            if cid == "ladybird":
                for (x, y) in ((4, 5), (7, 9), (8, 4)):
                    s.put(x, y, INK); s.put(x + 1, y, INK)
            face(s, fx, fy, r, mood, gap=r * 2.0)
            s.save(out("creatures", "%s_%s.png" % (cid, mood)), normals=True)


def sheet(path):
    """Contact sheet of every sprite at 4x on the B dirt mid (for REPORT and the reviewer)."""
    from PIL import Image
    import glob
    files = sorted(glob.glob(out("worm", "lantern", "*.png"))) + sorted(glob.glob(out("foods", "*.png"))) \
        + sorted(glob.glob(out("creatures", "*.png")))
    files = [f for f in files if not f.endswith("_n.png")]
    cols, cell = 12, 50 * 4
    rows = (len(files) + cols - 1) // cols
    im = Image.new("RGBA", (cols * cell, rows * cell), rgb(B["rings"]["dirt"][4]) + (255,))
    for i, f in enumerate(files):
        sp = Image.open(f).convert("RGBA")
        if "/worm/" in f and ("head" in f or "segment" in f or "band" in f):
            tint = rgb("#3cc24a") if i % 2 == 0 else rgb("#e4393c")
            px = sp.load()
            for y in range(sp.height):
                for x in range(sp.width):
                    c = px[x, y]
                    px[x, y] = (c[0] * tint[0] // 255, c[1] * tint[1] // 255, c[2] * tint[2] // 255, c[3])
        sp = sp.resize((sp.width * 4, sp.height * 4), Image.NEAREST)
        im.alpha_composite(sp, ((i % cols) * cell + 10, (i // cols) * cell + 10))
    im.save(path)


if __name__ == "__main__":
    worm_set()
    food_set()
    creature_set()
    if len(sys.argv) > 1:
        sheet(sys.argv[1])
    print("ok")
