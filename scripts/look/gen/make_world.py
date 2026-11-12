"""Ring tiles, parallax, sky clouds, light and particle textures for Life of a Worm (look B, D92).

    python3 scripts/look/gen/make_world.py        # from the repo root; writes assets/sprites/world|fx

Outputs (all original, procedural; see assets/CREDITS.md):
  world/materials.png, world/materials_n.png   128 px seamless texture (+ normal map) per material,
                                               side by side in the order of world/materials.json
  world/tile_masks.png                         the autotile atlas the TileSet uses: row = material,
                                               column = grass side * 16 + open mask (see ring_tiles.gdshader)
  world/castings.png                           4 tunnel-floor variants (translucent, crumbs)
  world/parallax_soil.png                      3 parallax layers packed in R, G, B (seamless)
  world/clouds.png                             cloud strip for the sky (seamless horizontally)
  fx/lantern.png, fx/shaft.png, fx/glow.png,   light textures
  fx/chunk.png, fx/debris.png, fx/flash.png    particle textures (white, tinted in game)
"""
import json
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pix import fbm, hexc, mix, normals_from_height, quantiles, scale, worley  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WORLD = os.path.join(ROOT, "assets", "sprites", "world")
FX = os.path.join(ROOT, "assets", "sprites", "fx")
S = 128  # material texture size (seamless)
T = 16   # tile size

INK = hexc("#120c10")

# Look B palettes (art/direction, D92). Four shades dark -> light, then accents.
PAL = {
    "dirt":     ["#2e1c13", "#4a2e1f", "#6c452c", "#93653d"],
    "clay":     ["#4e3018", "#7a5028", "#9c703c", "#bf9058"],
    "topsoil":  ["#1b2a1c", "#2a4229", "#3d5e36", "#5b7e45"],
    "grass":    ["#1d3322", "#2c4a2c", "#3f6236", "#58783e"],
    "stone":    ["#1b2030", "#2c3448", "#435069", "#64758f"],
    "core":     ["#5a1c0e", "#7e3410", "#b85a20", "#e0782a"],
    "strange":  ["#24360e", "#4a6a1a", "#86b830", "#c8f070"],
    "castings": ["#1e130c", "#2a1a10", "#3c2617", "#56391f"],
}
ROOT_COLS = [hexc("#5a3a22"), hexc("#a87e50"), hexc("#d4b07a")]
PEBBLE = [hexc("#3a3640"), hexc("#6b6670"), hexc("#8f8a94"), hexc("#bdb7c2")]

# Material order = row in tile_masks.png = index in materials.png. Tile names map onto these in
# materials.json ("tiles"), so RingSet tile names never have to match material names.
MATERIALS = ["dirt", "clay", "topsoil", "mycelium", "grass", "flowers", "stone", "ore",
             "core_rock", "crystal", "strangestone", "garden_root", "garden_stone", "garden_bug",
             "garden_crystal"]
TILES = {
    "dirt": "dirt", "clay": "clay", "topsoil": "topsoil", "mushroom": "mycelium",
    "grass": "grass", "flower": "flowers", "stone": "stone", "ore": "ore",
    "core_rock": "core_rock", "crystal": "crystal", "strangestone": "strangestone",
    "garden_root": "garden_root", "garden_stone": "garden_stone", "garden_bug": "garden_bug",
    "garden_crystal": "garden_crystal",
}
GRASSY = ["grass", "flowers"]


def clumps(seed, pal, n_points=130, crack=0.55, bump=0.12):
    """Terraria-like clumpy ground: Worley cells lit from the top left, quantized to 4 shades,
    broken dark cracks between clumps. Returns (colour rows, height rows)."""
    cols = [hexc(c) for c in pal]
    wl = worley(S, n_points, seed)
    n = fbm(S, seed + 7)
    rng = random.Random(seed + 3)
    clump_tone = [rng.uniform(-0.12, 0.12) for _ in range(n_points)]
    crack_on = [rng.random() < crack for _ in range(n_points * n_points)]
    val = [[0.0] * S for _ in range(S)]
    hgt = [[0.0] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            f1, f2, idx, (px, py) = wl[y][x]
            dx = x + 0.5 - px
            dy = y + 0.5 - py
            dx -= S * round(dx / S)
            dy -= S * round(dy / S)
            r = max(f2, 1.0)
            lit = -(dx * -0.6 + dy * -0.8) / r * -1.0  # toward top left = brighter
            v = n[y][x] * 0.7 + clump_tone[idx] + lit * bump + 0.15
            h = max(0.0, 1.0 - f1 / max(f2, 1.0)) * 0.6 + n[y][x] * 0.4
            if f2 - f1 < 1.1 and crack_on[(idx * 7 + int(f2)) % len(crack_on)]:
                v = -1.0
                h = 0.0
            val[y][x] = v
            hgt[y][x] = h
    q = quantiles(val, [0.12, 0.45, 0.85])
    out = [[None] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            v = val[y][x]
            k = 0 if v < q[0] else 1 if v < q[1] else 2 if v < q[2] else 3
            out[y][x] = cols[k]
    return out, hgt


def speckle(col, hgt, seed, colours, share, raise_by=0.15):
    rng = random.Random(seed)
    for _ in range(int(S * S * share)):
        x = rng.randrange(S)
        y = rng.randrange(S)
        col[y][x] = rng.choice(colours)
        hgt[y][x] += raise_by


def pebble(col, hgt, cx, cy, rx, ry, pal):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            u = (x + 0.5 - cx) / rx
            v = (y + 0.5 - cy) / ry
            d = u * u + v * v
            X = x % S
            Y = y % S
            if d <= 1.0:
                lit = -(u * -0.6 + v * -0.8)
                c = pal[2]
                if lit > 0.45:
                    c = pal[3]
                elif lit < -0.35:
                    c = pal[1]
                col[Y][X] = c
                hgt[Y][X] = 0.7 + (1.0 - d) * 0.6
            elif d <= 1.6 and v > 0.2:
                col[Y][X] = pal[0]  # contact shadow under the stone


def root(col, hgt, x, y, length, rng, cols=ROOT_COLS, branch=True):
    a = rng.uniform(0, math.tau)
    for i in range(length):
        a += rng.uniform(-0.28, 0.28)
        x += math.cos(a)
        y += math.sin(a)
        X = int(x) % S
        Y = int(y) % S
        col[Y][X] = cols[2] if i % 5 else cols[1]
        hgt[Y][X] = 0.9
        Y2 = (int(y) + 1) % S
        if col[Y2][X] not in cols:
            col[Y2][X] = cols[0]
        if branch and i > 4 and rng.random() < 0.06:
            root(col, hgt, x, y, rng.randint(3, 7), rng, cols, branch=False)


def blobs(col, hgt, rng, n, colours, r=(1, 2), height=0.8):
    for _ in range(n):
        cx = rng.uniform(0, S)
        cy = rng.uniform(0, S)
        rr = rng.uniform(*r)
        c = rng.choice(colours)
        for y in range(int(cy - rr - 1), int(cy + rr + 2)):
            for x in range(int(cx - rr - 1), int(cx + rr + 2)):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= rr:
                    col[y % S][x % S] = c
                    hgt[y % S][x % S] = height


def crystal_shard(col, hgt, cx, cy, size, pal, rng):
    a = rng.uniform(0, math.tau)
    ux, uy = math.cos(a), math.sin(a)
    for t in range(-size, size + 1):
        w = (size - abs(t)) * 0.45 + 0.6
        for s in range(-int(w) - 1, int(w) + 2):
            if abs(s) > w:
                continue
            x = int(cx + ux * t - uy * s) % S
            y = int(cy + uy * t + ux * s) % S
            col[y][x] = pal[2] if s < 0 else pal[1]
            if s == 0 and t < 0:
                col[y][x] = pal[3]
            hgt[y][x] = 1.0


def material(name):
    rng = random.Random(hash(name) & 0xffff if False else sum(map(ord, name)) * 97)
    seed = sum(map(ord, name)) * 13
    if name == "dirt":
        col, hgt = clumps(seed, PAL["dirt"], n_points=140)
        for _ in range(9):
            pebble(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1.6, 3.2),
                   rng.uniform(1.2, 2.4), PEBBLE)
        for _ in range(7):
            root(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.randint(8, 20), rng)
        blobs(col, hgt, rng, 14, [hexc("#9c5a34"), hexc("#7a4126")], (0.6, 1.4), 0.5)  # clay flecks
        speckle(col, hgt, seed + 1, [hexc("#2e1c13")], 0.02, -0.1)
        speckle(col, hgt, seed + 2, [hexc("#a8774a")], 0.01)
    elif name == "clay":
        col, hgt = clumps(seed, PAL["clay"], n_points=70, crack=0.4, bump=0.18)
        for _ in range(4):
            pebble(col, hgt, rng.uniform(0, S), rng.uniform(0, S), 1.8, 1.4, PEBBLE)
        speckle(col, hgt, seed + 1, [hexc("#d8b070")], 0.012)
    elif name == "topsoil":
        col, hgt = clumps(seed, PAL["topsoil"], n_points=160, crack=0.6)
        blobs(col, hgt, rng, 30, [hexc("#4a2e1f"), hexc("#5a3a24")], (0.6, 1.6), 0.4)  # loam
        for _ in range(12):
            root(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.randint(6, 16), rng)
        speckle(col, hgt, seed + 1, [hexc("#8a9a52"), hexc("#7d9048")], 0.012)  # moss
        for _ in range(4):
            pebble(col, hgt, rng.uniform(0, S), rng.uniform(0, S), 1.8, 1.3, PEBBLE)
    elif name == "mycelium":
        col, hgt = clumps(seed, PAL["topsoil"], n_points=160, crack=0.5)
        threads = [hexc("#6a5a48"), hexc("#b8ab94"), hexc("#e6dcc4")]
        for _ in range(26):
            root(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.randint(6, 18), rng, threads)
        blobs(col, hgt, rng, 10, [hexc("#c46a8a"), hexc("#e39ab8")], (0.8, 1.3), 1.0)  # tiny caps
    elif name in ("grass", "flowers"):
        col, hgt = clumps(seed, PAL["grass"], n_points=190, crack=0.45, bump=0.2)
        for _ in range(10):
            root(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.randint(5, 12), rng)
        speckle(col, hgt, seed + 1, [hexc("#8a9a52")], 0.03)
        if name == "flowers":
            for _ in range(22):
                x = rng.randrange(S)
                y = rng.randrange(S)
                petal = rng.choice([hexc("#f2d04a"), hexc("#f4f0e0"), hexc("#e86a8a")])
                for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                    col[(y + dy) % S][(x + dx) % S] = petal
                    hgt[(y + dy) % S][(x + dx) % S] = 0.9
                col[y][x] = hexc("#e08a20")
    elif name in ("stone", "ore"):
        col, hgt = clumps(seed, PAL["stone"], n_points=55, crack=0.75, bump=0.25)
        speckle(col, hgt, seed + 1, [hexc("#7d8ca6")], 0.01)
        if name == "ore":
            for _ in range(12):
                crystal_shard(col, hgt, rng.uniform(0, S), rng.uniform(0, S), 2,
                              [hexc("#5a4a20"), hexc("#a8862e"), hexc("#e0b84a"), hexc("#fff0a0")], rng)
    elif name in ("core_rock", "crystal"):
        col, hgt = clumps(seed, PAL["core"], n_points=60, crack=0.8, bump=0.25)
        speckle(col, hgt, seed + 1, [hexc("#ffc067")], 0.015)
        if name == "crystal":
            for _ in range(14):
                crystal_shard(col, hgt, rng.uniform(0, S), rng.uniform(0, S), 3,
                              [hexc("#1a5a78"), hexc("#2aa8c8"), hexc("#59e6ff"), hexc("#d0fbff")], rng)
    elif name == "strangestone":
        col, hgt = clumps(seed, PAL["strange"], n_points=40, crack=0.8, bump=0.25)
    else:  # gardens: dark castings soil with the garden's crop
        col, hgt = clumps(seed, PAL["castings"], n_points=120, crack=0.5)
        if name == "garden_root":
            for _ in range(16):
                root(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.randint(5, 12), rng,
                     [hexc("#7a4a10"), hexc("#d08a20"), hexc("#f0b040")])
            blobs(col, hgt, rng, 18, [hexc("#5aa83a"), hexc("#8fd860")], (0.8, 1.6), 1.0)
        elif name == "garden_stone":
            for _ in range(16):
                pebble(col, hgt, rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1.6, 3.0), 1.6,
                       [hexc("#4a4e58"), hexc("#9aa2b0"), hexc("#c8d0dc"), hexc("#f0f4fa")])
        elif name == "garden_bug":
            blobs(col, hgt, rng, 40, [hexc("#ffcc5a"), hexc("#ffe08a"), hexc("#e8a830")], (1.0, 1.8), 1.0)
        elif name == "garden_crystal":
            for _ in range(14):
                crystal_shard(col, hgt, rng.uniform(0, S), rng.uniform(0, S), 3,
                              [hexc("#4a1a78"), hexc("#8a40d0"), hexc("#c46cff"), hexc("#f0d0ff")], rng)
    return col, hgt


def build_materials():
    img = Image.new("RGB", (S * len(MATERIALS), S))
    nrm = Image.new("RGB", (S * len(MATERIALS), S))
    shares = {}
    for i, name in enumerate(MATERIALS):
        col, hgt = material(name)
        px = img.load()
        counts = {}
        for y in range(S):
            for x in range(S):
                px[i * S + x, y] = col[y][x]
                counts[col[y][x]] = counts.get(col[y][x], 0) + 1
        nrm.paste(normals_from_height(hgt, 2.5), (i * S, 0))
        shares[name] = {"#%02x%02x%02x" % c: round(n / (S * S), 4)
                        for c, n in sorted(counts.items(), key=lambda kv: -kv[1]) if n / (S * S) >= 0.01}
    img.save(os.path.join(WORLD, "materials.png"))
    nrm.save(os.path.join(WORLD, "materials_n.png"))
    return shares


# --- autotile masks ------------------------------------------------------------------------------
# Pixel: R = material index, G = code | open-side bits << 3, B = grass shade, A = 0 cut away.
# code: 0 near an edge, 1 ink, 2 lit lip, 3..6 deeper = darker (solid ground darkening away from air).
UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8
SIDES = [UP, RIGHT, DOWN, LEFT]


def side_dist(x, y, side):
    return {UP: y, RIGHT: T - 1 - x, DOWN: T - 1 - y, LEFT: x}[side]


def blade_heights(seed):
    rng = random.Random(seed)
    return [rng.choice([1, 2, 2, 3, 3, 4]) for _ in range(T)]


def mask_tile(mat, mask, grass_side):
    """grass_side: 0 none, else 1..4 = UP, RIGHT, DOWN, LEFT (only drawn if that side is open)."""
    out = []
    gs = SIDES[grass_side - 1] if grass_side else 0
    grass_open = gs and (mask & gs)
    blades = blade_heights(mat * 31 + grass_side * 7)
    for y in range(T):
        for x in range(T):
            e = 99
            near = 0
            for s in SIDES:
                if mask & s:
                    d = side_dist(x, y, s)
                    if s == gs and grass_open:
                        d += 0  # grass side: blades handled below
                    e = min(e, d)
                    if d <= 2:
                        near |= s
            for a, b in [(UP, RIGHT), (RIGHT, DOWN), (DOWN, LEFT), (LEFT, UP)]:
                if mask & a and mask & b:
                    e = min(e, side_dist(x, y, a) + side_dist(x, y, b) - 2)
            alpha = 255
            grass = 0
            if grass_open:
                d = side_dist(x, y, gs)
                along = {UP: x, DOWN: T - 1 - x, RIGHT: y, LEFT: T - 1 - y}[gs]
                h = blades[along]
                if d < 4:
                    if d < 4 - h:
                        alpha = 0
                    else:
                        k = d - (4 - h)
                        grass = 3 if k == 0 else 2 if k == 1 else 1
                elif d < 6:
                    grass = 1 if (along + d) % 3 else 0
            if e < 0:
                alpha = 0
            if grass:
                code = 0
            elif e == 0:
                code = 1
            elif e == 1:
                code = 2
            elif e <= 4:
                code = 0
            elif e <= 7:
                code = 3
            elif e <= 10:
                code = 4
            elif e <= 13:
                code = 5
            else:
                code = 6
            if grass_open and not grass and side_dist(x, y, gs) < 6 and code in (1, 2):
                code = 0
            out.append((mat, code | (near << 3), grass, alpha))
    return out


def build_masks():
    img = Image.new("RGBA", (T * 16 * 5, T * len(MATERIALS)), (0, 0, 0, 0))
    px = img.load()
    for mi, name in enumerate(MATERIALS):
        for gside in range(5 if name in GRASSY else 1):
            for mask in range(16):
                tile = mask_tile(mi, mask, gside)
                ox = (gside * 16 + mask) * T
                oy = mi * T
                for i, p in enumerate(tile):
                    px[ox + i % T, oy + i // T] = p
    img.save(os.path.join(WORLD, "tile_masks.png"))


def build_castings():
    """Tunnel floor: a translucent dark wash with crumbs, so the parallax shows through."""
    img = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    px = img.load()
    base = hexc(PAL["castings"][1])
    rng = random.Random(11)
    for v in range(4):
        for y in range(T):
            for x in range(T):
                px[v * T + x, y] = base + (120,)
        for _ in range(9):
            cx = v * T + rng.randrange(1, T - 2)
            cy = rng.randrange(1, T - 2)
            c = hexc(rng.choice(PAL["castings"][2:]))
            px[cx, cy] = c + (255,)
            if rng.random() < 0.6:
                px[cx + 1, cy] = c + (255,)
                px[cx, cy + 1] = hexc(PAL["castings"][0]) + (255,)
    img.save(os.path.join(WORLD, "castings.png"))


def build_parallax():
    """R: near layer, deep soil silhouettes (lumps); G: mid layer, roots and stones; B: far dark."""
    P = 256
    near = fbm(P, 501, ((4, 0.55), (8, 0.3), (32, 0.15)))
    far = fbm(P, 777, ((2, 0.6), (4, 0.3), (16, 0.1)))
    mid = [[0.0] * P for _ in range(P)]
    rng = random.Random(5)
    for _ in range(16):  # stones
        cx, cy = rng.uniform(0, P), rng.uniform(0, P)
        rx, ry = rng.uniform(5, 12), rng.uniform(4, 8)
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                u = (x + 0.5 - cx) / rx
                v = (y + 0.5 - cy) / ry
                if u * u + v * v <= 1:
                    mid[y % P][x % P] = 0.75 if (u + v) < -0.6 else 1.0
    for _ in range(14):  # long hanging roots
        x, y = rng.uniform(0, P), rng.uniform(0, P)
        a = math.pi / 2 + rng.uniform(-0.6, 0.6)
        w = rng.choice([1, 2, 2, 3])
        for i in range(rng.randint(30, 90)):
            a += rng.uniform(-0.25, 0.25)
            x += math.cos(a)
            y += math.sin(a)
            for k in range(w):
                mid[int(y) % P][int(x + k) % P] = 0.75
            if rng.random() < 0.05:
                w = max(1, w - 1)
    img = Image.new("RGB", (P, P))
    q_near = quantiles(near, [0.55])[0]
    px = img.load()
    for y in range(P):
        for x in range(P):
            n = near[y][x]
            r = 0 if n < q_near else (160 if n < q_near + 0.03 else 255)
            g = int(mid[y][x] * 255)
            b = int(max(0.0, min(1.0, far[y][x])) * 255)
            px[x, y] = (r, g, b)
    img.save(os.path.join(WORLD, "parallax_soil.png"))


def build_clouds():
    W, H = 512, 96
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(9)
    shades = [hexc("#c7e4f2"), hexc("#ffffff"), hexc("#9cc4de")]
    for _ in range(6):
        cx = rng.uniform(0, W)
        cy = rng.uniform(44, 66)
        puffs = [(cx + rng.uniform(-40, 40), cy + rng.uniform(-14, 8), rng.uniform(12, 24)) for _ in range(8)]
        for y in range(H):
            for x in range(W):
                best = None
                for (ux, uy, r) in puffs:
                    dx = (x + 0.5 - ux + W / 2) % W - W / 2
                    dy = y + 0.5 - uy
                    d = math.hypot(dx, dy * 1.3)
                    if d <= r:
                        lit = -(dx * -0.3 + dy * -0.95) / r
                        if best is None or lit > best:
                            best = lit
                if best is not None:
                    c = shades[1] if best > 0.2 else shades[0] if best > -0.5 else shades[2]
                    px[x, y] = c + (255,)
    img.save(os.path.join(WORLD, "clouds.png"))


def build_fx():
    # Lantern: soft radial falloff with a few pixel-stepped rings (reads as pixel art up close).
    L = 128
    img = Image.new("RGBA", (L, L))
    px = img.load()
    for y in range(L):
        for x in range(L):
            d = math.hypot(x + 0.5 - L / 2, y + 0.5 - L / 2) / (L / 2)
            v = max(0.0, 1.0 - d) ** 1.35
            v = math.floor(v * 40) / 40
            px[x, y] = (255, 255, 255, int(v * 255))
    img.save(os.path.join(FX, "lantern.png"))
    # Glow: a tighter, brighter core for small glowing food.
    G = 64
    img = Image.new("RGBA", (G, G))
    px = img.load()
    for y in range(G):
        for x in range(G):
            d = math.hypot(x + 0.5 - G / 2, y + 0.5 - G / 2) / (G / 2)
            v = max(0.0, 1.0 - d) ** 2.2
            px[x, y] = (255, 255, 255, int(v * 255))
    img.save(os.path.join(FX, "glow.png"))
    # Shaft: daylight cone, wide at the hole (top), fading toward the core (bottom).
    W, H = 64, 256
    img = Image.new("RGBA", (W, H))
    px = img.load()
    for y in range(H):
        t = y / H
        half = 10 + t * 22
        for x in range(W):
            dx = abs(x + 0.5 - W / 2)
            edge = max(0.0, min(1.0, (half - dx) / 6.0))
            v = edge * (1.0 - t) ** 1.3 * min(1.0, y / 6.0 + 0.4)
            if (x // 2 + y // 6) % 9 == 0:
                v *= 0.8  # faint dusty streaks
            px[x, y] = (255, 255, 255, int(max(0.0, v) * 255))
    img.save(os.path.join(FX, "shaft.png"))
    # Particles: a chunky 4 px crumb and a 3 px debris bit, white (tinted in game) with a dark corner.
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    px = img.load()
    for y in range(4):
        for x in range(4):
            if (x, y) in [(0, 0), (3, 0), (0, 3), (3, 3)]:
                continue
            px[x, y] = (255, 255, 255, 255) if x + y < 4 else (170, 170, 170, 255)
    img.save(os.path.join(FX, "chunk.png"))
    img = Image.new("RGBA", (3, 3), (0, 0, 0, 0))
    px = img.load()
    for (x, y) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (2, 2)]:
        px[x, y] = (255, 255, 255, 255) if x + y < 3 else (150, 150, 150, 255)
    img.save(os.path.join(FX, "debris.png"))


def main():
    os.makedirs(WORLD, exist_ok=True)
    os.makedirs(FX, exist_ok=True)
    shares = build_materials()
    build_masks()
    build_castings()
    build_parallax()
    build_clouds()
    build_fx()
    with open(os.path.join(WORLD, "materials.json"), "w") as f:
        json.dump({"size": S, "tile": T, "materials": MATERIALS, "tiles": TILES, "grassy": GRASSY,
                   "palette_shares": shares}, f, indent=1)
    print("world art written:", WORLD, FX)


if __name__ == "__main__":
    main()
