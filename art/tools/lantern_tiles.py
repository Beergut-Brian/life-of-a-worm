"""Lantern Deep (look B, Docket D92) game tiles: 16 px atlases + normal maps, palette-snapped.

    python3 art/tools/lantern_tiles.py

Writes (all nearest-filter pixel art, every colour from art/palette/lantern_deep.gpl):
  assets/sprites/tiles/lantern_solid.png (+ _n.png)  one row per tile kind, 64 columns:
        column = open_mask * 4 + variant (open_mask: 1 up, 2 right, 4 down, 8 left are air)
  assets/sprites/tiles/lantern_wall.png (+ _n.png)   one row per ring back wall, 8 columns:
        column = ceiling * 4 + variant (ceiling: solid ground right above the dug cell)
  assets/sprites/tiles/lantern_tiles.json            row tables the game reads (scripts/lighting/)
  art/palette/lantern_deep.gpl, lantern_deep.hex     the palette (GIMP / Aseprite)

The ramps are look B's from art/tools/worm_looks.py (the frames Kaden saw), plus the accents the
real tile set needs (clay, ore, crystal, mushroom, flower, gardens, the Strangestone).
"""
import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from worm_looks import LOOKS, rgb, mix, hexs  # noqa: E402
from pix import h2, vnoise, enc_n  # noqa: E402

TS = 16
VARIANTS = 4
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "tiles")
PAL_DIR = os.path.join(ROOT, "art", "palette")

B = LOOKS["b"]
INK = B["outline"]

# deep, low, mid, high (+ wall light, wall dark for rings)
RAMPS = {
    "topsoil": B["rings"]["topsoil"],
    "dirt": B["rings"]["dirt"],
    "rock": B["rings"]["rock"],
    "core": B["rings"]["core"],
    "grass": ["#1b2a1c", "#3d5e36", "#5b7e45", "#d0d48a", "#2a3626", "#1e281b"],  # high was #9fbf63 (P1 12.2)
    "clay": ["#3a1e16", "#5e3424", "#7e5638", "#b07a52"],  # mid was #8a5236 (P2 19.8)
    "crystal": ["#1e5a70", "#2f98b8", "#59e6ff", "#d2fbff"],
    "ore": ["#7a5418", "#c8962a", "#f2c84a", "#ffeaa0"],
    "mushroom": ["#4a2a5e", "#8a4fb0", "#c48ae0", "#f0d8ff"],
    "stem": ["#8a7a62", "#c8b896", "#efe2c4"],
    "flower": ["#e8b02a", "#ffe066", "#fff8e0"],
    "strange": ["#1e3a0c", "#2e5a14", "#e8ff6a", "#f6ffd0"],  # was B8FF6A-based (P1 17.9)
    "castings": ["#1a100a", "#2a1a10", "#4a3220"],
    "root": ["#3d2a18", "#6a4a2a"],
    "sprout": ["#2e6a2a", "#5aa040"],
    "egg": ["#d8cfa8", "#fff6dc"],
    "pebble": ["#4a4038", "#6e6458", "#988a76", "#c2b49c"],
}

# tile name -> (ring for the base ramp, feature)
SOLID = [
    ("strangestone", "strange", "glow"),
    ("core_rock", "core", "hot"),
    ("crystal", "core", "crystal"),
    ("stone", "rock", "fleck"),
    ("ore", "rock", "ore"),
    ("dirt", "dirt", "pebble"),
    ("clay", "clay", "smear"),
    ("topsoil", "topsoil", "roots"),
    ("mushroom", "topsoil", "mushroom"),
    ("grass", "grass", "grass"),
    ("flower", "grass", "flower"),
    ("garden_crystal", "castings", "g_crystal"),
    ("garden_root", "castings", "g_root"),
    ("garden_stone", "castings", "g_stone"),
    ("garden_bug", "castings", "g_bug"),
]
WALLS = ["core", "rock", "dirt", "topsoil", "grass"]


def palette():
    cols = []
    for k in ("topsoil", "dirt", "rock", "core", "grass"):
        cols += RAMPS[k]
    for k in ("clay", "crystal", "ore", "mushroom", "stem", "flower", "strange", "castings", "root",
              "sprout", "egg", "pebble"):
        cols += RAMPS[k]
    cols += [INK, "#ffffff"]
    seen, out = set(), []
    for c in cols:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out


PAL = palette()
PAL_RGB = [rgb(c) for c in PAL]


def snap(c):
    c = rgb(c) if isinstance(c, str) else c
    best, bd = PAL_RGB[0], 1e9
    for p in PAL_RGB:
        d = (p[0] - c[0]) ** 2 * 0.3 + (p[1] - c[1]) ** 2 * 0.59 + (p[2] - c[2]) ** 2 * 0.11
        if d < bd:
            best, bd = p, d
    return best


def ramp_pick(ramp, v):
    v = max(0.0, min(0.999, v))
    return ramp[min(3, int(v * 4))]


def solid_tile(ring, feature, mask, var, seed):
    """Returns (pixels[16][16] rgb, heights[16][16])."""
    ramp = RAMPS[ring]
    if len(ramp) < 4:
        ramp = [ramp[0], ramp[1], ramp[2], ramp[2]]
    px = [[None] * TS for _ in range(TS)]
    hg = [[0.0] * TS for _ in range(TS)]
    ox, oy = var * 37 + seed * 101, var * 53 + seed * 7
    for y in range(TS):
        for x in range(TS):
            wx, wy = x + ox, y + oy
            v = (0.55 + (vnoise(wx, wy, 3, 3) - 0.5) * 0.5 + (vnoise(wx, wy, 7, 4) - 0.5) * 0.35
                 + (h2(wx, wy, 1) - 0.5) * 0.18)
            # block seams: Terraria-ish dense blocks
            if x == 15 or y == 15:
                v -= 0.05
            if x == 0 or y == 0:
                v += 0.03
            h = 0.6 + vnoise(wx, wy, 4, 3) * 0.35
            if x in (0, 15) or y in (0, 15):
                h -= 0.2
            # open sides: dark ink rim on the very edge, a lit lip just inside
            d = 99
            if mask & 1:
                d = min(d, y)
            if mask & 2:
                d = min(d, 15 - x)
            if mask & 4:
                d = min(d, 15 - y)
            if mask & 8:
                d = min(d, x)
            col = ramp_pick(ramp, v)
            if d == 0:
                col = mix(INK, ramp[0], 0.35)
                h = 0.0
            elif d <= 2:
                col = ramp[3] if (d == 1 or h2(wx, wy, 9) < 0.5) else ramp[2]
                h = 0.35 + 0.25 * d
            px[y][x] = col
            hg[y][x] = h
    dec = feature_layer(feature, var, seed)
    for (x, y), (c, h) in dec.items():
        d = 99
        if mask & 1:
            d = min(d, y)
        if mask & 2:
            d = min(d, 15 - x)
        if mask & 4:
            d = min(d, 15 - y)
        if mask & 8:
            d = min(d, x)
        if d == 0 and feature not in ("grass", "flower"):
            continue
        px[y][x] = c
        hg[y][x] = h
    return px, hg


def blob(out, cx, cy, r, ramp, h0=1.0):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if 0 <= x < TS and 0 <= y < TS:
                dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                d = dx * dx + dy * dy
                if d <= 1.0:
                    lit = -dx * 0.5 - dy * 0.7 + 0.5
                    out[(x, y)] = (ramp[3] if lit > 0.75 else (ramp[2] if lit > 0.25 else ramp[1]),
                                   h0 + (1 - d) * 0.4)


def feature_layer(feature, var, seed):
    """Decals over the base texture: {(x, y): (colour, height)}."""
    out = {}
    s = var * 13 + seed

    def r(k):
        return h2(var, k, seed + 77)
    if feature == "hot":
        for k in range(3):
            if r(k) < 0.7:
                x, y = 2 + int(r(k + 10) * 11), 2 + int(r(k + 20) * 11)
                out[(x, y)] = (RAMPS["core"][3], 0.9)
                out[(x + 1, y)] = (RAMPS["core"][2], 0.85)
    elif feature == "fleck":
        if r(1) < 0.55:
            x, y = 3 + int(r(2) * 9), 3 + int(r(3) * 9)
            for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
                out[(x + dx, y + dy)] = (RAMPS["rock"][3], 0.9)
    elif feature == "ore":
        for k in range(3 + var % 2):
            x, y = 2 + int(r(k + 1) * 11), 2 + int(r(k + 30) * 11)
            blob(out, x, y, 1.6 + r(k + 40) * 0.8, RAMPS["ore"], 1.0)
    elif feature == "crystal":
        # a cluster of cyan prisms growing out of hot core rock
        bx = 4 + int(r(1) * 5)
        for k, (dx, hgt, w) in enumerate(((0, 10, 2), (3, 13, 3), (7, 8, 2))):
            x0 = bx + dx - 2
            for y in range(TS - 2 - hgt, TS - 2):
                ww = min(w, (y - (TS - 2 - hgt)) // 2 + 1)
                for x in range(x0 - ww + 1, x0 + ww + 1):
                    if 0 <= x < TS:
                        c = RAMPS["crystal"][3] if x <= x0 - ww + 1 else (
                            RAMPS["crystal"][2] if x <= x0 else RAMPS["crystal"][1])
                        out[(x, y)] = (c, 1.2 - (x - x0) * 0.15)
    elif feature == "pebble":
        if r(1) < 0.3:
            blob(out, 3 + r(2) * 9, 3 + r(3) * 9, 1.8, RAMPS["pebble"], 0.9)
        if r(4) < 0.2:
            blob(out, 3 + r(5) * 9, 3 + r(6) * 9, 1.2, RAMPS["pebble"], 0.9)
    elif feature == "smear":
        y0 = 3 + int(r(1) * 9)
        for x in range(2, 13):
            if h2(x, y0, s) < 0.75:
                out[(x, y0 + int(math.sin(x * 0.7 + var) * 1.2))] = (RAMPS["clay"][3], 0.85)
    elif feature == "roots":
        if r(1) < 0.75:
            x = 2 + int(r(2) * 11)
            for y in range(TS):
                x += (1 if h2(x, y, s) < 0.3 else (-1 if h2(x, y, s) > 0.7 else 0))
                if 1 <= x < 15:
                    out[(x, y)] = (RAMPS["root"][1] if y % 3 else RAMPS["root"][0], 0.75)
    elif feature == "mushroom":
        # little glowing caps (the light pool lights them; they read as lamps underground)
        for k in range(2):
            cx, cy = 4 + k * 7 + int(r(k) * 2), 8 + int(r(k + 5) * 4)
            for y in range(cy, min(TS - 1, cy + 4)):
                out[(cx, y)] = (RAMPS["stem"][1], 0.9)
                out[(cx + 1, y)] = (RAMPS["stem"][2], 0.9)
            for dx in range(-2, 4):
                for dy in range(-2, 1):
                    if abs(dx - 0.5) + abs(dy) * 1.4 <= 3.0:
                        c = RAMPS["mushroom"][3] if dy == -2 else (
                            RAMPS["mushroom"][2] if dx < 2 else RAMPS["mushroom"][1])
                        out[(cx + dx, cy + dy)] = (c, 1.2)
    elif feature in ("grass", "flower"):
        for x in range(TS):
            if h2(x, var, s) < 0.45:
                out[(x, 1 + int(h2(x, 3, s) * 3))] = (RAMPS["grass"][3], 1.0)
        if feature == "flower":
            for k in range(2):
                fx, fy = 3 + int(r(k) * 9), 4 + int(r(k + 3) * 8)
                for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    out[(fx + dx, fy + dy)] = (RAMPS["flower"][1], 1.0)
                out[(fx, fy)] = (RAMPS["flower"][2], 1.1)
    elif feature == "glow":
        for k in range(4):
            x, y = 2 + int(r(k) * 11), 2 + int(r(k + 9) * 11)
            out[(x, y)] = (RAMPS["strange"][3], 1.0)
    elif feature.startswith("g_"):
        for k in range(3):
            x, y = 2 + int(r(k) * 10) + k, 4 + int(r(k + 7) * 8)
            if feature == "g_root":
                out[(x, y)] = (RAMPS["sprout"][1], 1.0)
                out[(x, y + 1)] = (RAMPS["sprout"][0], 1.0)
                out[(x + 1, y - 1)] = (RAMPS["sprout"][1], 1.0)
            elif feature == "g_crystal":
                out[(x, y)] = (RAMPS["crystal"][3], 1.1)
                out[(x, y + 1)] = (RAMPS["crystal"][2], 1.1)
                out[(x + 1, y + 1)] = (RAMPS["crystal"][1], 1.0)
            elif feature == "g_stone":
                blob(out, x, y, 1.4, RAMPS["pebble"], 0.9)
            elif feature == "g_bug":
                blob(out, x, y, 1.3, ["#000", RAMPS["egg"][0], RAMPS["egg"][0], RAMPS["egg"][1]], 1.0)
    return out


def wall_tile(ring, ceiling, var):
    ramp = RAMPS[ring]
    wl, wd = ramp[4], ramp[5]
    px = [[None] * TS for _ in range(TS)]
    hg = [[0.0] * TS for _ in range(TS)]
    for y in range(TS):
        for x in range(TS):
            wx, wy = x + var * 41, y + var * 29
            v = vnoise(wx, wy, 5, 5) * 0.7 + h2(wx, wy, 2) * 0.3
            c = wl if v > 0.45 else wd
            if ceiling and y < 3:
                c = mix(wd, INK, 0.5) if y < 2 else wd
            px[y][x] = c
            hg[y][x] = 0.3 + v * 0.3
    return px, hg


def normals(hg):
    n = [[None] * TS for _ in range(TS)]
    for y in range(TS):
        for x in range(TS):
            h = hg[y][x]
            gx = (hg[y][min(15, x + 1)] if x < 15 else h) - (hg[y][max(0, x - 1)] if x > 0 else h)
            gy = (hg[min(15, y + 1)][x] if y < 15 else h) - (hg[max(0, y - 1)][x] if y > 0 else h)
            n[y][x] = enc_n(-gx * 1.8, -gy * 1.8, 1.0)
    return n


def build():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PAL_DIR, exist_ok=True)
    cols = 16 * VARIANTS
    img = Image.new("RGBA", (cols * TS, len(SOLID) * TS))
    nrm = Image.new("RGBA", img.size)
    rows = {}
    for row, (name, ring, feat) in enumerate(SOLID):
        rows[name] = row
        for mask in range(16):
            for var in range(VARIANTS):
                p, hg = solid_tile(ring, feat, mask, var, row)
                nn = normals(hg)
                x0, y0 = (mask * VARIANTS + var) * TS, row * TS
                for y in range(TS):
                    for x in range(TS):
                        c = snap(p[y][x])
                        img.putpixel((x0 + x, y0 + y), (c[0], c[1], c[2], 255))
                        nrm.putpixel((x0 + x, y0 + y), nn[y][x])
    img.save(os.path.join(OUT, "lantern_solid.png"))
    nrm.save(os.path.join(OUT, "lantern_solid_n.png"))
    wimg = Image.new("RGBA", (2 * VARIANTS * TS, len(WALLS) * TS))
    wnrm = Image.new("RGBA", wimg.size)
    wrows = {}
    for row, ring in enumerate(WALLS):
        wrows[ring] = row
        for ceil in range(2):
            for var in range(VARIANTS):
                p, hg = wall_tile(ring, ceil, var)
                nn = normals(hg)
                x0, y0 = (ceil * VARIANTS + var) * TS, row * TS
                for y in range(TS):
                    for x in range(TS):
                        c = snap(p[y][x])
                        wimg.putpixel((x0 + x, y0 + y), (c[0], c[1], c[2], 255))
                        wnrm.putpixel((x0 + x, y0 + y), nn[y][x])
    wimg.save(os.path.join(OUT, "lantern_wall.png"))
    wnrm.save(os.path.join(OUT, "lantern_wall_n.png"))
    meta = {"tile": TS, "variants": VARIANTS, "solid_rows": rows, "wall_rows": wrows,
            "tile_ring": {n: r for (n, r, _f) in SOLID},
            "palette": PAL}
    with open(os.path.join(OUT, "lantern_tiles.json"), "w") as f:
        json.dump(meta, f, indent=1)
    with open(os.path.join(PAL_DIR, "lantern_deep.gpl"), "w") as f:
        f.write("GIMP Palette\nName: Lantern Deep (Life of a Worm, D92)\nColumns: 4\n#\n")
        for c in PAL:
            r, g, b = rgb(c)
            f.write(f"{r:3d} {g:3d} {b:3d}\t{c}\n")
    with open(os.path.join(PAL_DIR, "lantern_deep.hex"), "w") as f:
        f.write("\n".join(c.lstrip("#") for c in PAL) + "\n")
    print("solid", img.size, "wall", wimg.size, "palette", len(PAL))


if __name__ == "__main__":
    build()


def light_textures():
    """Soft light shapes for the PointLight2D pool (scripts/lighting/lantern.gd)."""
    dst = os.path.join(ROOT, "assets", "sprites", "light")
    os.makedirs(dst, exist_ok=True)
    n = 256
    im = Image.new("RGBA", (n, n))
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - n / 2, y + 0.5 - n / 2) / (n / 2)
            v = max(0.0, 1.0 - d) ** 1.6
            g = int(255 * v)
            im.putpixel((x, y), (g, g, g, 255))
    im.save(os.path.join(dst, "light_radial.png"))
    w, h = 128, 512
    im = Image.new("RGBA", (w, h))
    for y in range(h):
        half = 18 + y * 0.075
        fall = (1.0 - y / h) ** 1.3
        for x in range(w):
            e = abs(x + 0.5 - w / 2) / half
            v = max(0.0, 1.0 - e * e) * fall * (0.85 + 0.15 * math.sin(x * 0.21 + y * 0.01))
            g = int(255 * max(0.0, min(1.0, v)))
            im.putpixel((x, y), (g, g, g, 255))
    im.save(os.path.join(dst, "light_shaft.png"))


if __name__ == "__main__" and "--lights" in sys.argv:
    light_textures()
