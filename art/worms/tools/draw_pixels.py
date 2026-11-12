"""Draw the Gulp (P1) and Burp (P2) 16 px pixel sets, stages 1 to 3, at target size.

    python3 art/worms/tools/draw_pixels.py            # writes assets/characters/{gulp,burp}/s{1,2,3}/

Every pixel is placed at its final size (no downscaling): shapes, ink outline, light from the
upper left, belly stripe and faces are drawn per stage on the stage's own canvas, using the
proportions and colours of the 3D master (art/worms/build_masters.py, renders in art/worms/renders/).
The read-check sheet (read_check.py) shows each sprite next to a low-res render of the master.

Head and faces face +X (the worm's heading); the game flips the whole head when it turns left.
"""
import math
import os
import sys

from PIL import Image

sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "characters")

SEG = {1: 16, 2: 19, 3: 22}        # body / tail canvas (WormLook.SEGMENT_PX)
HEADN = {1: 20, 2: 24, 3: 32}      # head / face canvas (WormLook.HEAD_PX)
HEAD_D = {1: 18, 2: 21, 3: 24}     # head diameter incl. ink
BAND_W = {1: 3, 2: 3, 3: 4}
P = 2.4                            # superellipse exponent: chunky, like the master's beads

INK = "140c12"
SCLERA = "ffffff"
PUPIL = "1a1220"
MOUTH = "5a1424"
TONGUE = "ff7a8a"
TOOTH = "fff6e8"
SWEAT = "8fd8ff"
PAL = {
    "gulp": dict(main="3cc24a", hi="8ee86e", spec="e8ffd0", shade="23893a", belly="9be86a", belly_dk="6cbf4a"),
    "burp": dict(main="e4393c", hi="ff8a78", spec="ffe0d8", shade="a3202e", belly="8e1c2a", belly_dk="66121f"),
}
BAND = dict(top="ffffff", mid="e6e6e6", low="b4b4b4", rim="9a9a9a")
BOW = dict(P="ff5fa2", L="ffa8cc", D="c23a7a", K=INK)
CAP = dict(main="3a6dff", hi="8fb0ff", dark="2446b8", button="ffffff")

MOODS = ["idle", "ajar", "open", "chomp_1", "chomp_2", "chomp_3", "squash", "happy", "worried", "sleep"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Canvas:
    def __init__(self, n):
        self.n = n
        self.px = {}

    def set(self, x, y, h):
        if 0 <= x < self.n and 0 <= y < self.n:
            self.px[(x, y)] = h

    def get(self, x, y):
        return self.px.get((x, y))

    def save(self, path):
        im = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        for (x, y), h in self.px.items():
            im.putpixel((x, y), rgb(h))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        return im


# ------------------------------------------------------------------ shapes
def blob(n, cx, cy, rx, ry, taper=None):
    """Pixels inside a superellipse; `taper` narrows the left end (tail)."""
    inside = set()
    for y in range(n):
        for x in range(n):
            u = (x + 0.5 - cx) / rx
            k = 1.0
            if taper is not None:
                k = taper + (1.0 - taper) * min(1.0, max(0.0, (u + 1.0) / 2.0)) ** 0.8
            v = (y + 0.5 - cy) / (ry * k)
            if abs(u) ** P + abs(v) ** P <= 1.0:
                inside.add((x, y))
    return inside


def edge(shape):
    return {(x, y) for (x, y) in shape
            if any((x + dx, y + dy) not in shape for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def zone(x, y, cx, cy, rx, ry):
    """Shading zone of an inner pixel: spec, hi, main, shade, belly, belly_dk."""
    u = (x + 0.5 - cx) / rx
    v = (y + 0.5 - cy) / ry
    n = abs(u) ** P + abs(v) ** P
    if v > 0.36:
        return "belly_dk" if n > 0.62 or v > 0.78 else "belly"
    if n > 0.62 and (u + 1.4 * v) > 0.35:
        return "shade"
    d = (u + 0.36) ** 2 + (v + 0.5) ** 2
    if d < 0.025:
        return "spec"
    if d < 0.09:
        return "hi"
    return "main"


def paint_bead(c, shape, pal, cx, cy, rx, ry):
    rim = edge(shape)
    for (x, y) in shape:
        c.set(x, y, INK if (x, y) in rim else pal[zone(x, y, cx, cy, rx, ry)])


def paint_band(c, shape, bx0, w, cx, cy, rx, ry):
    rim = edge(shape)
    for (x, y) in shape:
        if (x, y) in rim or not bx0 <= x < bx0 + w:
            continue
        z = zone(x, y, cx, cy, rx, ry)
        tone = {"spec": "top", "hi": "top", "main": "mid", "shade": "rim", "belly": "low", "belly_dk": "rim"}[z]
        v = (y + 0.5 - cy) / ry
        if z == "main" and v < -0.55:
            tone = "top"
        c.set(x, y, BAND[tone])


# ------------------------------------------------------------------ geometry per stage
def bead_geo(s):
    n = SEG[s]
    return n, n / 2.0, n / 2.0, n / 2.0 - 0.2, n / 2.0 - 0.2


def head_geo(s):
    n = HEADN[s]
    r = HEAD_D[s] / 2.0
    cy = n / 2.0 + (3.0 if s == 3 else 0.0)   # stage 3: room above for the bow / cap
    cx = n / 2.0 - (1.0 if s == 3 else 0.0)
    return n, cx, cy, r


def body(name, s):
    n, cx, cy, rx, ry = bead_geo(s)
    c = Canvas(n)
    paint_bead(c, blob(n, cx, cy, rx, ry), PAL[name], cx, cy, rx, ry)
    return c


def band(s, tail=False):
    n, cx, cy, rx, ry = bead_geo(s)
    shape = blob(n, cx, cy, rx, ry, taper=0.45 if tail else None)
    c = Canvas(n)
    w = BAND_W[s]
    bx0 = int(round(cx + (0.3 * rx if tail else 0.0) - w / 2.0))
    paint_band(c, shape, bx0, w, cx, cy, rx, ry)
    return c


def tail(name, s):
    n, cx, cy, rx, ry = bead_geo(s)
    c = Canvas(n)
    paint_bead(c, blob(n, cx, cy, rx, ry, taper=0.45), PAL[name], cx, cy, rx, ry)
    return c


def head(name, s):
    n, cx, cy, r = head_geo(s)
    c = Canvas(n)
    paint_bead(c, blob(n, cx, cy, r, r), PAL[name], cx, cy, r, r)
    if s == 3:
        stamp(c, feature(name).px, *feature_anchor(name, s))
    return c


# ------------------------------------------------------------------ stage-3 features
BOW_MAP = [
    "KK.....KK",
    "KLKK.KKLK",
    "KPPPKPPPK",
    "KPPKDKPPK",
    "KPKK.KKPK",
    "KK.....KK",
]


def feature(name):
    """Gulp's tiny bow, Burp's backwards cap (visor to the back: nothing near the mouth or eyes)."""
    if name == "gulp":
        c = Canvas(9)
        for y, row in enumerate(BOW_MAP):
            for x, ch in enumerate(row):
                if ch != ".":
                    c.set(x, y, BOW[ch])
        return trim(c)
    # cap: a dome 10 wide, 5 tall, a visor 4 long off its back (left) edge, a white button on top
    c = Canvas(15)
    dome = blob(15, 9.5, 6.0, 5.2, 5.0)
    dome = {(x, y) for (x, y) in dome if y <= 6}
    rim = edge(dome) | {(x, 6) for (x, y) in dome}
    for (x, y) in dome:
        if (x, y) in rim:
            c.set(x, y, INK)
        else:
            c.set(x, y, CAP["hi"] if (x <= 7 and y <= 3) else CAP["dark"] if y >= 5 else CAP["main"])
    for x in range(0, 6):
        c.set(x, 6, INK)
        c.set(x, 5, CAP["dark"] if x > 0 else INK)
    c.set(0, 5, INK)
    for x in range(1, 5):
        c.set(x, 4, INK)
    c.set(9, 0, INK)
    c.set(10, 0, INK)
    c.set(9, 1, CAP["button"])
    c.set(10, 1, CAP["button"])
    return trim(c)


def trim(c):
    xs = [x for x, _ in c.px]
    ys = [y for _, y in c.px]
    x0, y0 = min(xs), min(ys)
    n = max(max(xs) - x0, max(ys) - y0) + 1
    out = Canvas(n)
    for (x, y), h in c.px.items():
        out.set(x - x0, y - y0, h)
    out.w, out.h = max(xs) - x0 + 1, max(ys) - y0 + 1
    return out


def feature_anchor(name, s):
    n, cx, cy, r = head_geo(s)
    if name == "gulp":
        return int(cx - 0.45 * r) - 4, int(cy - r) - 3
    return int(cx - 0.55 * r) - 6, int(cy - r) - 2


def stamp(c, px, ox, oy):
    for (x, y), h in px.items():
        c.set(x + ox, y + oy, h)


# ------------------------------------------------------------------ faces
def line(x0, y0, x1, y1):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# per mood: lid (0 open .. 1 shut), eye style, mouth (top angle, bottom angle in degrees, 0 = closed line)
FACE = {
    "idle":    dict(lid=0.22, eye="open", mouth=None),
    "ajar":    dict(lid=0.15, eye="open", mouth=(-10, 16), tongue=False),
    "open":    dict(lid=0.0, eye="wide", mouth=(-22, 42), tongue=True),
    "chomp_1": dict(lid=0.45, eye="open", mouth=(-8, 12)),
    "chomp_2": dict(lid=1.0, eye="squeeze", mouth=None, cheek=True),
    "chomp_3": dict(lid=0.5, eye="open", mouth=(-4, 14), tongue=True, cheek=True),
    "squash":  dict(lid=1.0, eye="squeeze", mouth="tight"),
    "happy":   dict(lid=1.0, eye="happy", mouth=(0, 24), tongue=True),
    "worried": dict(lid=0.0, eye="worried", mouth="wavy", sweat=True),
    "sleep":   dict(lid=1.0, eye="shut", mouth="tight"),
}


def eye_specs(name, s):
    n, cx, cy, r = head_geo(s)
    if name == "gulp":
        re = {1: 3, 2: 4, 3: 4}[s]
        return [(int(cx + 0.3 * r), int(cy - r + re - 0.5), re, +1)]
    re = {1: 2, 2: 2, 3: 3}[s]
    ex = int(cx + 0.5 * r)
    ey = int(cy - 0.52 * r)
    # two small eyes side by side, pupils toward each other (a little cross-eyed)
    return [(ex - 2 * re - 1, ey, re, +1), (ex, ey, re, -1)]


def draw_eye(c, pal, ex, ey, re, look, f, s, name, head_shape):
    disk = {(x, y) for x in range(ex - re, ex + re + 1) for y in range(ey - re, ey + re + 1)
            if (x - ex) ** 2 + (y - ey) ** 2 <= re * re + re * 0.8}
    rim = edge(disk)
    style = f["eye"]
    lid = f["lid"] if name == "gulp" or f["lid"] >= 0.45 else 0.0   # Burp's lids only drop for chomps
    if style in ("open", "wide", "worried"):
        for (x, y) in disk:
            c.set(x, y, INK if (x, y) in rim else SCLERA)
        if re >= 3:
            pw, ph = 2, (3 if re == 3 or style == "wide" else 3)
            px = ex + re - pw - 1 if look > 0 else ex - re + 2
            if name == "burp":
                px = ex + 1 if look > 0 else ex - 2   # pupils toward each other
                ph = 2
        else:
            pw, ph = 1, 2
            px = ex + look
        py = ey - ph // 2 + (1 if style == "wide" else 0) - (1 if style == "worried" else 0)
        if style == "worried" and re >= 3:
            pw, ph = 1, 2
        for x in range(px, px + pw):
            for y in range(py, py + ph):
                c.set(x, y, PUPIL)
        if pw >= 2 and ph >= 3:
            c.set(px, py, SCLERA)               # catch-light
        lid_rows = int(round(lid * (2 * re - 1)))
        top = ey - re
        if lid_rows > 0:
            for y in range(top, top + lid_rows + 1):
                for x in range(ex - re, ex + re + 1):
                    if (x, y) in disk:
                        c.set(x, y, INK if ((x, y) in rim or y == top + lid_rows) else pal["main"])
        if style == "worried":                  # brow up in the middle: a little ink tick over the eye
            ticks = [(ex - 1, ey - re - 1), (ex, ey - re - 2)] if name == "gulp" else [(ex - look, ey - re - 1)]
            for (x, y) in ticks:
                c.set(x, y, INK)
        return
    # closed eyes: lid in the body colour (ink only where it bulges past the head), then the line
    union = head_shape | disk
    out = edge(union)
    for (x, y) in disk:
        c.set(x, y, INK if (x, y) in out else pal["main"])
    k = max(1, re - 1)
    if style == "shut":                         # asleep: a soft smile-shaped line
        for dx in range(-k, k + 1):
            c.set(ex + dx, ey + (0 if abs(dx) == k else 1), INK)
    elif style == "happy":                      # ^
        for dx in range(-k, k + 1):
            c.set(ex + dx, ey + abs(dx) - 1, INK)
    else:                                       # squeezed shut: > (or < on Burp's front eye)
        for dy in range(-k, k + 1):
            c.set(ex + look * (1 - abs(dy)), ey + dy, INK)


def draw_mouth(c, pal, name, s, f, head_shape):
    n, cx, cy, r = head_geo(s)
    hx, hy = cx - 0.1 * r, cy + 0.22 * r
    m = f["mouth"]
    front_y = int(cy + 0.12 * r)
    if m is None or m in ("tight", "wavy"):
        x0, x1 = int(cx + 0.15 * r), int(cx + r) - 1
        if m == "tight":
            x0 = int(cx + 0.5 * r)
        pts = line(x1, front_y, x0, int(hy))
        if m == "wavy":
            pts = [(x, front_y + 1 + ((x // 2) % 2)) for x in range(x0, x1 + 1)]
        for (x, y) in pts:
            if (x, y) in head_shape:
                c.set(x, y, INK)
        if m is None:                            # smile corner
            c.set(x0 - 1, int(hy) - 1, INK)
        if f.get("cheek"):
            ccx, ccy = int(cx + 0.15 * r), int(cy + 0.5 * r)
            for x in range(ccx - 1, ccx + 2):
                c.set(x, ccy - 2, INK)
            c.set(ccx - 2, ccy - 1, INK)
            c.set(ccx + 2, ccy - 1, INK)
            c.set(ccx, ccy - 1, pal["hi"])
        return
    a0, a1 = (math.radians(a) for a in m)
    wedge = set()
    for (x, y) in head_shape:
        dx, dy = x + 0.5 - hx, y + 0.5 - hy
        if dx <= 0.5:
            continue
        a = math.atan2(dy, dx)
        if a0 <= a <= a1 or (a0 == a1 and abs(a - a0) < 0.08):
            wedge.add((x, y))
    if not wedge:
        return
    rim = {(x, y) for (x, y) in wedge
           if any((x + dx, y + dy) in head_shape and (x + dx, y + dy) not in wedge
                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    for (x, y) in wedge:
        c.set(x, y, INK if (x, y) in rim else MOUTH)
    inner = wedge - rim
    if f.get("tongue") and inner:
        ys = [y for _, y in inner]
        if max(ys) - min(ys) >= 3:
            ymax = max(ys)
            xfront = max(x for x, _ in inner)
            for (x, y) in inner:
                if y >= ymax - (0 if s < 3 else 1) and (x - 1, y) in inner and x < xfront - 2:
                    c.set(x, y, TONGUE)
    if f.get("cheek"):
        ccx, ccy = int(cx + 0.05 * r), int(cy + 0.55 * r)
        c.set(ccx, ccy, pal["hi"])
        c.set(ccx + 1, ccy, pal["hi"])


def face(name, s, mood):
    n, cx, cy, r = head_geo(s)
    shape = blob(n, cx, cy, r, r)
    c = Canvas(n)
    f = FACE[mood]
    pal = PAL[name]
    draw_mouth(c, pal, name, s, f, shape)
    for (ex, ey, re, look) in eye_specs(name, s):
        draw_eye(c, pal, ex, ey, re, look, f, s, name, shape)
    if f.get("sweat"):
        sx, sy = int(cx - 0.55 * r), int(cy - 0.75 * r)
        for (x, y, h) in [(sx, sy, SWEAT), (sx, sy + 1, SWEAT), (sx - 1, sy + 1, SWEAT), (sx, sy + 2, "ffffff")]:
            c.set(x, y, h)
    return c


def main():
    count = 0
    for name in ("gulp", "burp"):
        for s in (1, 2, 3):
            d = os.path.join(OUT, name, "s%d" % s)
            body(name, s).save(os.path.join(d, "body.png"))
            tail(name, s).save(os.path.join(d, "tail.png"))
            head(name, s).save(os.path.join(d, "head.png"))
            band(s).save(os.path.join(d, "band.png"))
            band(s, tail=True).save(os.path.join(d, "tail_band.png"))
            count += 5
            for mood in MOODS:
                face(name, s, mood).save(os.path.join(d, "face_%s.png" % mood))
                count += 1
            if s == 3:
                ft = feature(name)
                im = Image.new("RGBA", (ft.w, ft.h), (0, 0, 0, 0))
                for (x, y), h in ft.px.items():
                    im.putpixel((x, y), rgb(h))
                im.save(os.path.join(d, "feature.png"))
                count += 1
    print("draw_pixels: %d sprites under %s" % (count, OUT))


if __name__ == "__main__":
    main()
