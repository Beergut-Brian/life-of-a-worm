"""Bake the per-look layers and sprites for the Godot preview scene (art/preview/preview.tscn).

    python3 art/tools/make_frames.py [a b c]

Writes art/preview/<look>/*.png and <shot>.json (xs = ring cross-section, planet, dock).
Godot composes the layers, adds lights, CanvasModulate, particles and glow, and takes the frame.
"""
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from worm_looks import LOOKS, P1, P2, rgb, mix, hexs  # noqa: E402
from pix import Spr, h2, vnoise, bayer, pick, char_ramp, enc_n, eye, mouth_o, smirk, FLAT_N  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PREV = os.path.join(REPO, "art", "preview")
TS = 16
W, H = 60, 34
PW, PH = W * TS, H * TS
SURF, R, CXT = 9.0, 150.0, 30.0
CYT = SURF + R
TH = {"topsoil": 3.5, "dirt": 11.0, "rock": 19.0}
K = 1.5  # worm stage shown in the frame: segments 1.5x the stage-1 16 px
INK_MOUTH = (60, 14, 30)


def depth_px(px, py):
    return R - math.hypot(px / TS - CXT, py / TS - CYT)


def ring_at(px, py, chunky=False):
    d = depth_px(px, py)
    if d < 0:
        return "sky"
    qx, qy = (px // 4 * 4, py // 4 * 4) if chunky else (px, py)
    dd = d + (vnoise(qx, qy, 22, 7) - 0.5) * 1.8
    if dd < TH["topsoil"]:
        return "topsoil"
    if dd < TH["dirt"]:
        return "dirt"
    if dd < TH["rock"]:
        return "rock"
    return "core"


def ring_of_cell(cx, cy):
    d = depth_px((cx + 0.5) * TS, (cy + 0.5) * TS)
    if d < 0:
        return "sky"
    dd = d + (h2(cx, cy, 7) - 0.5) * 1.3
    if dd < TH["topsoil"]:
        return "topsoil"
    if dd < TH["dirt"]:
        return "dirt"
    if dd < TH["rock"]:
        return "rock"
    return "core"


# Tunnels the worms ate (tile units). (polyline, radius)
TUNNELS = [
    ([(5, 15.4), (14, 14.8), (22, 16.0), (30, 15.6), (37, 16.2), (42.5, 15.4)], 1.5),   # P1, dirt
    ([(42.5, 15.4), (43.2, 12.5), (42.6, 9.5), (42.6, 6.0)], 1.05),                     # hole to sky
    ([(42.5, 15.4), (47, 18.0), (50.5, 19.5)], 1.05),                                    # to beetle pocket
    ([(51.5, 19.4)], 2.4),                                                               # beetle pocket
    ([(51.5, 19.6), (52.5, 23.0), (46, 25.4), (36, 24.9), (26, 25.6), (16, 24.6)], 1.5),  # P2, rock
    ([(26, 25.6), (27.2, 27.8), (28.5, 29.5)], 1.1),                                    # down to core
    ([(10.5, 11.6), (16.2, 11.9)], 1.0),                                                # topsoil burrow
    ([(14.5, 12.0), (13.6, 14.8)], 0.85),
]
CAVE = (30.0, 30.4, 6.8, 2.2)  # core cave ellipse


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def is_air_px(px, py):
    """Pixel-level carve (tunnels have smooth edges at pixel resolution)."""
    x, y = px / TS, py / TS
    if depth_px(px, py) < 0:
        return True
    for pts, r in TUNNELS:
        if len(pts) == 1:
            if math.hypot(x - pts[0][0], y - pts[0][1]) <= r:
                return True
        for i in range(len(pts) - 1):
            if seg_dist(x, y, pts[i], pts[i + 1]) <= r:
                return True
    cx, cy, rx, ry = CAVE
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1


def poly_y(pts, x):
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        if min(x0, x1) <= x <= max(x0, x1) and x0 != x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return pts[0][1] if abs(x - pts[0][0]) < abs(x - pts[-1][0]) else pts[-1][1]


def dist_field(mask, w, h, lim):
    """4-neighbour BFS distance from pixels where mask is False, capped at lim."""
    INF = lim + 1
    d = [[INF] * w for _ in range(h)]
    frontier = []
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                d[y][x] = 0
                frontier.append((x, y))
    for k in range(1, lim + 1):
        nxt = []
        for x, y in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and d[yy][xx] > k:
                    d[yy][xx] = k
                    nxt.append((xx, yy))
        frontier = nxt
    return d


# ---- cross-section terrain --------------------------------------------------------------------

_SOLID = None


def solid_mask():
    global _SOLID
    if _SOLID is None:
        _SOLID = [[not is_air_px(x, y) for x in range(PW)] for y in range(PH)]
    return _SOLID


def terrain(look):
    st = look["style"]
    solid = solid_mask()
    dair = dist_field(solid, PW, PH, 28 if st["normals"] else 4)  # distance into solid from air
    notsolid = [[not v for v in row] for row in solid]
    dsol = dist_field(notsolid, PW, PH, 6)                       # distance into air from solid
    rings = [[ring_of_cell(cx, cy) for cx in range(W)] for cy in range(H)]
    ter = Spr(PW, PH, st)
    back = Spr(PW, PH, st)
    heights = {}
    ink = look["outline"]
    for py in range(PH):
        for px in range(PW):
            chunky = False
            ring = ring_at(px, py, chunky)
            dpx = depth_px(px, py)
            if ring == "sky":
                ring = "topsoil"
            ramp = look["rings"][ring]
            if solid[py][px]:
                da = dair[py][px]
                air_up = py > 0 and any(not solid[max(0, py - k)][px] for k in range(1, 4))
                air_dn = py < PH - 1 and any(not solid[min(PH - 1, py + k)][px] for k in range(1, 4))
                if st["texture"] >= 1.0:   # B: dense textured blocks
                    v = (0.55 + (vnoise(px, py, 3, 3) - 0.5) * 0.5 + (vnoise(px, py, 9, 4) - 0.5) * 0.3
                         + (h2(px, py, 1) - 0.5) * 0.18 + (h2(px // TS, py // TS, 5) - 0.5) * 0.12)
                    lx, ly = px % TS, py % TS
                    if (lx == 15 or ly == 15) and h2(px // TS, py // TS, 15) < 0.6:
                        v -= 0.07
                    if (lx == 0 or ly == 0) and h2(px // TS, py // TS, 15) < 0.6:
                        v += 0.04
                    if da <= 2 and air_up:
                        v += 0.4
                    elif da <= 2 and air_dn:
                        v -= 0.35
                    elif da <= 3:
                        v -= 0.08
                elif st["dither"]:          # C: soft dithered grain
                    warp = vnoise(px, py, 40, 3) * 9 + vnoise(px, py, 12, 8) * 2
                    v = 0.52 + 0.26 * math.sin(py * 0.42 + warp) + (vnoise(px, py, 4, 9) - 0.5) * 0.3
                    if h2(px // 3, py // 2, 17) < 0.015:   # engraver's flick
                        v = 0.0
                    if da <= 3 and air_up:
                        v += 0.3
                    elif da <= 3 and air_dn:
                        v -= 0.25
                else:                       # A: flat, chunky specks, highlight band
                    v = 0.55
                    if h2(px // 2, py // 2, 4) < 0.05:
                        v = 0.1
                    if da in (3, 4) and air_up:
                        v = 0.95
                    if da <= 4 and air_dn:
                        v = 0.1
                c = pick(ramp[:4], v, px, py, st)
                c = features(look, ring, px, py, c, min(da, 4))
                if st["normals"] and da > 5:   # Terraria-style: solid ground darkens away from open air
                    c = mix(c, ramp[0], min(0.5, (da - 5) / 22.0))
                if st["terrain_outline"] and da <= st["terrain_outline"]:
                    c = ink
                elif st["terrain_outline"] >= 2 and py > 0 and ring != "topsoil" and ring_at(px, py - 1) not in (ring, "sky") and ring_at(px, py - 2) not in (ring, "sky"):
                    c = ink
                ter.put(px, py, c)
                hgt = min(da, 3) / 3.0 + vnoise(px, py, 4, 3) * 0.35 - (0.25 if (px % TS in (0, 15) or py % TS in (0, 15)) else 0)
                heights[(px, py)] = hgt
            # back wall (shows through every hole below the surface)
            if dpx >= 0:
                wl, wd = ramp[4], ramp[5]
                ds = dsol[py][px]
                if st["texture"] >= 1.0:
                    v = vnoise(px, py, 7, 5) * 0.7 + h2(px, py, 2) * 0.3
                    c = wl if v > 0.45 else wd
                    if ds <= 3:
                        c = mix(wd, "#000000", 0.25)

                elif st["dither"]:
                    v = vnoise(px, py, 9, 5) - (0.35 if ds <= 3 else 0)
                    c = wl if v > bayer(px, py) else wd
                else:
                    c = wd if (ds <= 2 or h2(px // 3, py // 3, 6) < 0.06) else wl
                back.put(px, py, c)
    grass(look, ter, solid, rings)
    if st["normals"]:
        for (px, py), hgt in heights.items():
            gx = heights.get((px + 1, py), hgt - 0.3) - heights.get((px - 1, py), hgt - 0.3)
            gy = heights.get((px, py + 1), hgt - 0.3) - heights.get((px, py - 1), hgt - 0.3)
            ter.n[px, py] = enc_n(-gx * 1.6, -gy * 1.6, 1.0)
    return ter, back


def features(look, ring, px, py, c, da):
    st = look["style"]
    if da <= 2 or st["texture"] < 0.5:
        return c
    cx, cy = px // 8, py // 8
    r = h2(cx, cy, 11)
    lx, ly = px - cx * 8, py - cy * 8
    ox, oy = int(h2(cx, cy, 12) * 4) + 1, int(h2(cx, cy, 13) * 4) + 1
    if ring == "dirt" and r < 0.12 and 0 <= lx - ox < 3 and 0 <= ly - oy < 2:   # pebble
        return look["rings"]["rock"][3] if ly - oy == 0 else look["rings"]["rock"][2]
    if ring == "rock" and r < 0.07 and 0 <= lx - ox < 2 and 0 <= ly - oy < 2:   # ore fleck
        return "#f2c84a" if h2(cx, cy, 14) < 0.6 else "#7fd8e8"
    if ring == "core" and r < 0.18 and 0 <= lx - ox < 2 and 0 <= ly - oy < 2:   # hot speck
        return look["rings"]["core"][3]
    if ring in ("topsoil", "dirt") and st["texture"] >= 1.0:                     # roots
        if vnoise(px, py * 0.5, 9, 21) > 0.82 and abs((px + int(vnoise(px, py, 6, 22) * 6)) % 23) == 0:
            return mix(look["rings"]["dirt"][0], look["rings"]["topsoil"][1], 0.4)
    return c


def grass(look, ter, solid, rings):
    st = look["style"]
    g = look["grass"]
    for px in range(PW):
        for py in range(1, PH):
            if solid[py][px] and not solid[py - 1][px] and depth_px(px, py - 1) < 0.2:
                # top surface pixel: grass cap and blades
                for k in range(4):
                    if py + k < PH and solid[py + k][px]:
                        v = 0.9 - k * 0.25
                        ter.put(px, py + k, pick([g[0], g[0], g[1], g[2]], v, px, py + k, st))
                if st["terrain_outline"]:
                    hb = [0, 1, 2, 1][px % 4]
                    for k in range(1, hb + 1):
                        ter.put(px, py - k, g[1])
                    ter.put(px, py - hb - 1, look["outline"])
                    if st["terrain_outline"] >= 2:
                        ter.put(px, py - hb - 2, look["outline"])
                else:
                    hb = int(h2(px, 0, 31) * 4.5)
                    for k in range(1, hb + 1):
                        ter.put(px, py - k, g[2] if k == hb else g[1])
                break


# ---- sprites ----------------------------------------------------------------------------------

def worm(look, colour, segs, heading, eyes, mouth_open=0.0, look_at=(1, 0), k=1.0):
    """segs: list of (x, y) world px centres head first. Returns (Spr, (ox, oy))."""
    st = look["style"]
    xs = [p[0] for p in segs]
    ys = [p[1] for p in segs]
    m = int(16 * k)
    ox, oy = int(min(xs)) - m, int(min(ys)) - m
    s = Spr(int(max(xs) - min(xs)) + 2 * m + 2, int(max(ys) - min(ys)) + 2 * m + 2, st)
    lit = st["lit"]
    ramp = char_ramp(colour, look["char_outline"], lit)
    belly = mix(colour, "#ffffff", 0.45) if colour == P1 else mix(colour, "#3a0a14", 0.4)
    sep = mix(colour, look["char_outline"], 0.6)
    n = len(segs)
    for i in range(n - 1, -1, -1):
        x, y = segs[i][0] - ox, segs[i][1] - oy
        r = (8.0 if i == 0 else max(4.5, 7.2 - i * 0.35)) * k

        def rec(nx, ny, v, r=r):
            if 0.25 < ny < 0.62 and i > 0:
                return belly
            if nx * nx + ny * ny > 0.78 and i > 0:
                return sep
            return None
        s.ell(x, y, r, r * 0.95, ramp, recolor=rec)
        if st["style"] if False else False:
            pass
    hx, hy = segs[0][0] - ox, segs[0][1] - oy
    if mouth_open > 0:
        ang = math.atan2(heading[1], heading[0])
        for y in range(int(hy - 10 * k), int(hy + 11 * k)):
            for x in range(int(hx - 10 * k), int(hx + 11 * k)):
                a = math.atan2(y + 0.5 - hy, x + 0.5 - hx) - ang
                a = (a + math.pi) % (2 * math.pi) - math.pi
                dd = math.hypot(x + 0.5 - hx, y + 0.5 - hy)
                if abs(a) < 0.55 * mouth_open and dd > 2.5 * k:
                    s.clear(x, y)
    s.outline(look["char_outline"], 1)
    if mouth_open > 0:  # inside of mouth and a tooth
        dx, dy = heading
        for j in range(2, int(5 * k)):
            for e in (-1, 0, 1):
                s.put(hx + dx * j, hy + dy * j + e, INK_MOUTH)
        s.put(hx + dx * int(6 * k), hy - int(3 * k), "#ffffff")
        s.put(hx + dx * int(6 * k), hy + int(3 * k), "#ffffff")
    s.lid = ramp[1]
    if eyes == 1:
        eye(s, hx - heading[0] * 1.5 * k, hy - 3.5 * k, 4.2 * k, look_at[0], look_at[1], lid=0.18)
    else:
        bx = hx - heading[0] * 1.0 * k
        eye(s, bx - 3.2 * k, hy - 3.5 * k, 2.3 * k, 1, 0.3)
        eye(s, bx + 2.0 * k, hy - 3.8 * k, 2.3 * k, -1, 0.3)
    return s, (ox, oy)


def food_grub(look, k=1.4):
    st = look["style"]
    s = Spr(int(22 * k), int(16 * k), st)
    ramp = char_ramp("#f3e2b0", look["char_outline"], st["lit"])
    for (x, y, r) in [(16, 9, 4.5), (11.5, 10, 4.5), (7, 9.5, 4.2), (4, 7, 3.2)]:
        s.ell(x * k, y * k, r * k, r * k, ramp, recolor=lambda nx, ny, v: ramp[1] if nx * nx + ny * ny > 0.8 else None)
    s.outline(look["char_outline"])
    eye(s, 13.6 * k, 7.5 * k, 2.4 * k, -1, -0.2)
    eye(s, 18.4 * k, 7.5 * k, 2.4 * k, -1, -0.2)
    mouth_o(s, 16.3 * k, 11.8 * k, 1.1 * k)
    for j in range(3):
        s.put(int(20.5 * k), int(3 * k) + j, "#7fd0ff")   # sweat drop
    return s


def food_nugget(look, k=1.4):
    st = look["style"]
    s = Spr(int(18 * k), int(15 * k), st)
    ramp = char_ramp("#e8b83a", look["char_outline"], st["lit"])
    s.ell(9 * k, 8 * k, 7 * k, 5.5 * k, ramp)
    s.outline(look["char_outline"])
    eye(s, 6.5 * k, 7 * k, 2.3 * k, 1, -0.3)
    eye(s, 11.3 * k, 7 * k, 2.3 * k, 1, -0.3)
    mouth_o(s, 9 * k, 11.3 * k, 1.0 * k)
    return s


def food_mushroom(look, k=1.4):
    st = look["style"]
    s = Spr(int(18 * k), int(20 * k), st)
    cap = char_ramp("#b06ad8" if st["lit"] else "#c47ad8", look["char_outline"], st["lit"])
    stem = char_ramp("#efe2c4", look["char_outline"], st["lit"])
    s.rect(6 * k, 9 * k, 12 * k, 19 * k, stem[2])
    s.rect(6 * k, 9 * k, 7 * k, 19 * k, stem[1])
    s.ell(9 * k, 7 * k, 8 * k, 5.5 * k, cap, mask=lambda nx, ny: ny < 0.55)
    for (x, y) in [(5, 5), (11, 4), (13, 7)]:
        s.rect(x * k, y * k, x * k + 2, y * k + 1, "#fff4e0")
    s.outline(look["char_outline"])
    eye(s, 7.4 * k, 12.5 * k, 1.9 * k, 1, 0)
    eye(s, 10.9 * k, 12.5 * k, 1.9 * k, 1, 0)
    mouth_o(s, 9.2 * k, 16.2 * k, 0.8 * k)
    return s


def food_crystal(look, col="#6af2ff", k=1.4):
    st = look["style"]
    s = Spr(int(16 * k), int(22 * k), st)
    ramp = char_ramp(col, look["char_outline"], st["lit"])
    m = 8 * k
    for y in range(int(2 * k), int(21 * k)):
        w = int(min(y - 1, 6 * k) * 0.9) + 1
        for x in range(int(m - w), int(m + w)):
            v = 0.85 if x < m else 0.45
            s.put(x, y, pick(ramp, v, x, y, st), enc_n(-0.6 if x < m else 0.6, -0.2, 0.8))
    s.outline(look["char_outline"])
    return s


def face_crystal(look, s, k=1.4):
    eye(s, 5.8 * k, 12 * k, 2.0 * k, -1, 0)
    eye(s, 10.0 * k, 12 * k, 2.0 * k, -1, 0)
    mouth_o(s, 8 * k, 16 * k, 0.8 * k)
    return s


def threat_beetle(look, k=1.6):
    st = look["style"]
    s = Spr(int(36 * k), int(26 * k), st)
    shell = char_ramp("#4a3fa8" if not st["dither"] else "#5a4f98", look["char_outline"], st["lit"])
    head = char_ramp("#2c2446", look["char_outline"], st["lit"])
    leg = look["char_outline"]
    for i in range(3):
        x = 12 + i * 6
        s.line(x * k, 19 * k, (x - 2) * k, 24 * k, leg)
    s.ell(19 * k, 13 * k, 12 * k, 9 * k, shell, mask=lambda nx, ny: ny < 0.75)
    s.line(19 * k, 5 * k, 19 * k, 20 * k, mix("#4a3fa8", look["char_outline"], 0.5))
    if st["lit"] or st["tile_shades"] == 2:
        for (x, y) in [(14, 7), (15, 7), (14, 8), (16, 7), (14, 9)]:
            s.put(x * k, y * k, "#ffffff")
    s.ell(8 * k, 15 * k, 6.5 * k, 6 * k, head)
    s.line(5 * k, 9 * k, 2 * k, 3 * k, leg); s.line(9 * k, 9 * k, 10 * k, 3 * k, leg)
    s.outline(look["char_outline"])
    s.lid = head[2]
    eye(s, 5.5 * k, 14 * k, 2.4 * k, -1, 0.2, lid=0.5)
    eye(s, 10.2 * k, 14 * k, 2.4 * k, -1, 0.2, lid=0.5)
    smirk(s, int(5 * k), int(19.5 * k), int(5 * k))
    return s


def tree(look):
    st = look["style"]
    s = Spr(56, 70, st)
    bark = char_ramp("#7a5232", look["char_outline"], st["lit"])
    leaf_base = {"a": "#1f8f8a", "b": "#356046", "c": "#5f7f3a"}[look["slug"][0]]
    leaf = char_ramp(leaf_base, look["char_outline"], st["lit"])
    s.rect(24, 34, 32, 70, bark[2])
    s.rect(24, 34, 26, 70, bark[3])
    s.rect(30, 34, 32, 70, bark[1])
    for (x, y, r) in [(18, 30, 13), (38, 28, 13), (28, 18, 15), (28, 34, 12)]:
        s.ell(x, y, r, r * 0.9, leaf)
    s.outline(look["outline"], 2 if st["terrain_outline"] >= 2 else 1)
    return s


def fence(look):
    st = look["style"]
    s = Spr(70, 22, st)
    wood = char_ramp("#c9a26a" if not st["lit"] else "#a88452", look["char_outline"], st["lit"])
    s.rect(0, 7, 70, 10, wood[2])
    s.rect(0, 14, 70, 17, wood[1])
    for x in range(2, 70, 14):
        s.rect(x, 2, x + 5, 22, wood[2])
        s.rect(x, 2, x + 1, 22, wood[3])
        s.put(x + 2, 1, wood[2]); s.put(x + 3, 1, wood[2])
    s.outline(look["outline"])
    return s


# ---- skies, light textures, paper ---------------------------------------------------------------

def sky_layer(look, w, h, horizon, stars=False):
    st = look["style"]
    sky = look["sky"]
    s = Spr(w, h, st)
    for y in range(h):
        t = min(1.0, y / max(1, horizon))
        for x in range(w):
            if st["dither"]:
                c = pick(sky, 0.15 + t * 0.85, x, y, st)
            elif st["tile_shades"] == 2:
                c = sky[min(3, int(t * 3.0) + 1)]
            else:
                a, b = (sky[0], sky[2]) if t < 0.6 else (sky[2], sky[3])
                c = mix(a, b, t / 0.6 if t < 0.6 else (t - 0.6) / 0.4)
            s.put(x, y, c)
    return s


def cloud(s, look, cx, cy, sc=1.0):
    st = look["style"]
    ramp = [mix(look["sky"][3], look["sky"][1], 0.5), mix(look["sky"][3], "#ffffff", 0.2),
            mix("#ffffff", look["sky"][3], 0.15), (255, 255, 255)]
    pts = [(-14, 2, 9), (0, -3, 12), (14, 1, 10), (25, 4, 7), (-24, 5, 6)]
    tmp = Spr(s.w, s.h, st)
    for dx, dy, r in pts:
        tmp.ell(cx + dx * sc, cy + dy * sc, r * sc * 1.3, r * sc, ramp,
                mask=lambda nx, ny: ny < 0.55, flat=st["tile_shades"] == 2)
    if st["terrain_outline"]:
        tmp.outline(look["outline"], 1)
    s.img.alpha_composite(tmp.img)


def hills(s, look, base_y, far=True):
    st = look["style"]
    col = mix(look["grass"][0], look["sky"][2], 0.55 if far else 0.25)
    dark = mix(col, look["sky"][0], 0.2)
    for x in range(s.w):
        hy = base_y - 22 * (0.5 + 0.5 * math.sin(x / 70.0 + 1.3)) - 10 * vnoise(x, 0, 40, 77)
        for y in range(int(hy), s.h):
            c = col if (not st["dither"] or (y - hy) / 30 < bayer(x, y)) else dark
            s.put(x, y, c)
        if st["terrain_outline"]:
            s.put(x, int(hy), look["outline"])
    # generic water tower on the far hill
    tx, ty = int(s.w * 0.72), int(base_y - 30)
    tcol = mix(col, look["sky"][0], 0.35)
    s.rect(tx - 1, ty, tx + 1, ty + 16, tcol)
    s.rect(tx + 9, ty, tx + 11, ty + 16, tcol)
    s.rect(tx - 3, ty - 9, tx + 13, ty, tcol)
    s.rect(tx - 1, ty - 12, tx + 11, ty - 9, tcol)


def light_tex(path, kind, steps=0):
    if kind == "radial":
        im = Image.new("RGBA", (256, 256))
        p = im.load()
        for y in range(256):
            for x in range(256):
                d = math.hypot(x - 127.5, y - 127.5) / 128
                v = max(0.0, 1 - d) ** 1.6
                if steps:
                    v = math.floor(v * steps + 0.5) / steps
                g = int(v * 255)
                p[x, y] = (g, g, g, 255)
    elif kind == "band":
        im = Image.new("RGBA", (256, 256))
        p = im.load()
        for y in range(256):
            t = y / 255.0
            v = 1.0 if t < 0.344 else max(0.0, 1 - (t - 0.344) / 0.09) ** 1.3
            for x in range(256):
                g = int(v * 255)
                p[x, y] = (g, g, g, 255)
    elif kind == "cone":
        im = Image.new("RGBA", (128, 256))
        p = im.load()
        for y in range(256):
            half = 16 + y * 0.16
            fall = max(0.0, 1 - y / 256.0) ** 1.2
            for x in range(128):
                e = abs(x - 63.5)
                v = 0 if e > half else (1 - (e / half) ** 3) * fall
                v *= 0.85 + 0.15 * math.sin(x * 0.9)
                g = int(max(0, v) * 255)
                p[x, y] = (g, g, g, 255)
    im.save(path)


def paper(path, w, h):
    s = Image.new("RGBA", (w, h))
    p = s.load()
    for y in range(h):
        for x in range(w):
            g = 236 + int(vnoise(x, y, 3, 41) * 14) + int(h2(x, y, 42) * 6)
            vx, vy = (x / w - 0.5) * 2, (y / h - 0.5) * 2
            vig = max(0.0, (vx * vx + vy * vy) - 0.55) * 26
            g = max(0, min(255, int(g - vig)))
            p[x, y] = (g, int(g * 0.975), int(g * 0.92), 255)
    s.save(path)


# ---- planet -----------------------------------------------------------------------------------

def planet(look, out):
    st = look["style"]
    S, C, RP = 300, 150, 112
    sp = Spr(S, S, st)
    bites = [(math.radians(-38), 30), (math.radians(205), 19), (math.radians(118), 12)]
    bite_c = [(C + math.cos(a) * RP, C + math.sin(a) * RP, r) for a, r in bites]
    tunnel = [(C + math.cos(math.radians(-38)) * (RP - 20), C + math.sin(math.radians(-38)) * (RP - 20)),
              (C + 40, C - 20), (C + 10, C + 10), (C - 30, C + 25), (C - 60, C + 15)]
    fr = [("core", 0.17), ("rock", 0.47), ("dirt", 0.8), ("topsoil", 1.0)]
    for y in range(S):
        for x in range(S):
            d = math.hypot(x + 0.5 - C, y + 0.5 - C)
            f = d / RP + (h2(x // 3, y // 3, 51) - 0.5) * 0.02
            if f > 1.0:
                continue
            ring = next(r for r, t in fr if f <= t)
            ramp = look["rings"][ring]
            air = any(math.hypot(x - bx, y - by) < br for bx, by, br in bite_c)
            if any(seg_dist(x, y, tunnel[i], tunnel[i + 1]) < 3.2 for i in range(len(tunnel) - 1)):
                air = True
            if air:
                if any(math.hypot(x - bx, y - by) < br for bx, by, br in bite_c):
                    continue
                sp.put(x, y, ramp[5])
                continue
            nx, ny = (x - C) / RP, (y - C) / RP
            nz = math.sqrt(max(0, 1 - nx * nx - ny * ny))
            if st["texture"] >= 1.0:
                v = 0.5 + (vnoise(x, y, 4, 52) - 0.5) * 0.6
            elif st["dither"]:
                inner = [0, 0.17, 0.47, 0.8][[r for r, _ in fr].index(ring)]
                outer = dict(fr)[ring]
                v = 0.25 + 0.6 * (f - inner) / (outer - inner) + (vnoise(x, y, 6, 53) - 0.5) * 0.3
            else:
                v = 0.55 if h2(x // 2, y // 2, 54) > 0.06 else 0.1
            c = pick(ramp[:4], v, x, y, st)
            if ring == "core" and f < 0.04:
                c = "#2fb8a8" if (x + y) % 3 else "#8af5e4"   # Strangestone seam
            if ring == "topsoil" and f > 0.955:
                c = look["grass"][1] if f < 0.985 else look["grass"][2]
            sp.put(x, y, c, enc_n(nx, ny, nz + 0.15))
    if st["terrain_outline"] or st["dither"]:
        # ink between rings
        for y in range(1, S - 1):
            for x in range(1, S - 1):
                d = math.hypot(x + 0.5 - C, y + 0.5 - C) / RP
                for t in (0.17, 0.47, 0.8):
                    if abs(d - t) < 0.5 / RP * (1.6 if st["terrain_outline"] >= 2 else 1.0) and sp.get(x, y)[3]:
                        sp.put(x, y, mix(look["outline"], look["rings"]["rock"][1], 0.3))
        sp.outline(look["outline"], st["terrain_outline"] or 1)
    # tiny props on the rim: trees and houses
    for k in range(26):
        a = k / 26 * 2 * math.pi + 0.1
        if any(abs(((a - ba + math.pi) % (2 * math.pi)) - math.pi) < (br / RP) * 1.3 for ba, br in bites):
            continue
        bx, by = C + math.cos(a) * (RP + 1), C + math.sin(a) * (RP + 1)
        ux, uy = math.cos(a), math.sin(a)
        if k % 4 == 1:  # house
            for i in range(5):
                for j in range(-2, 3):
                    sp.put(bx + ux * i - uy * j, by + uy * i + ux * j, "#f0e0c0" if i < 3 else "#5a6f9c")
        else:
            for i in range(2):
                sp.put(bx + ux * i, by + uy * i, "#6a4a30")
            for i in range(2, 6):
                for j in range(-2, 3):
                    if abs(j) + (i - 3.5) ** 2 / 2 < 2.6:
                        sp.put(bx + ux * i - uy * j, by + uy * i + ux * j, look["grass"][0] if k % 3 else look["grass"][1])
    # the two worms, stage 6, mid-chomp on the big bite and curled by the small one
    for colour, a0, n, rr, eyes in ((P1, -38, 14, 8.5, 1), (P2, 205, 11, 7.0, 2)):
        base = math.radians(a0)
        segs = []
        dist = RP + rr + 3
        for i in range(n):
            a = base + (0.75 * rr / dist) * (i + 1.4) * (1 if colour == P1 else -1)
            dd = dist if i else RP + 1
            if i == 0:
                a = base + 0.55 * rr / dist * (1 if colour == P1 else -1)
            segs.append((C + math.cos(a) * dd, C + math.sin(a) * dd))
        ramp = char_ramp(colour, look["char_outline"], st["lit"])
        tmp = Spr(S, S, st)
        for i in range(n - 1, -1, -1):
            r = rr * (1.0 if i == 0 else max(0.55, 1 - i * 0.05))
            tmp.ell(segs[i][0], segs[i][1], r, r, ramp)
        tmp.outline(look["char_outline"])
        hx, hy = segs[0]
        if eyes == 1:
            eye(tmp, hx, hy - 1.5, 3.4, -1, 0.2)
        else:
            eye(tmp, hx - 2.2, hy - 1.5, 1.9, 1, 0); eye(tmp, hx + 2.2, hy - 1.5, 1.9, -1, 0)
        sp.img.alpha_composite(tmp.img)
        sp.nrm.alpha_composite(tmp.nrm)
    sp.save(os.path.join(out, "planet.png"), normals=True)
    # space backdrop with stars and a bitten moon
    W2, H2 = 960, 544
    sk = Spr(W2, H2, st)
    spc = look["space"]
    for y in range(H2):
        for x in range(W2):
            t = vnoise(x, y, 120, 61) * 0.7 + y / H2 * 0.3
            if st["texture"] >= 1.0:
                c = mix(spc[0], spc[2], max(0, t - 0.25) * 0.9)
            elif st["dither"]:
                c = pick(spc[:3], t * 0.8, x, y, st)
            else:
                c = spc[0]
            sk.put(x, y, c)
    for i in range(170):
        x, y = int(h2(i, 1, 62) * W2), int(h2(i, 2, 62) * H2)
        b = h2(i, 3, 62)
        col = "#fff6d8" if st["dither"] else "#ffffff"
        sk.put(x, y, col if b > 0.4 else spc[3])
        if b > 0.93:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sk.put(x + dx, y + dy, spc[3] if st["texture"] >= 1 else col)
    moon = Spr(60, 60, st)
    mr = char_ramp("#d8d4c8", look["char_outline"], st["lit"])
    moon.ell(30, 30, 18, 18, mr, mask=lambda nx, ny: math.hypot(nx - 0.85, ny + 0.6) > 0.55)
    if st["terrain_outline"] or st["dither"]:
        moon.outline(look["outline"])
    sk.img.alpha_composite(moon.img, (150, 70))
    sk.save(os.path.join(out, "space.png"))
    # atmosphere halo
    halo = Image.new("RGBA", (S + 60, S + 60))
    hp = halo.load()
    hc = rgb(look["sky"][2])
    for y in range(S + 60):
        for x in range(S + 60):
            d = math.hypot(x + 0.5 - (C + 30), y + 0.5 - (C + 30)) / RP
            if 0.97 < d < 1.22:
                a = (1 - (d - 0.97) / 0.25) ** 1.5
                if st["dither"]:
                    a = 0.55 if a > bayer(x, y) else 0
                elif st["tile_shades"] == 2:
                    a = 0.55 if d < 1.08 else (0.25 if d < 1.14 else 0)
                hp[x, y] = (hc[0], hc[1], hc[2], int(a * 200))
    halo.save(os.path.join(out, "halo.png"))
    return {"planet": (480 - C, 272 - C), "halo": (480 - C - 30, 272 - C - 30)}


# ---- dock -------------------------------------------------------------------------------------

def reel_sprite(look, out):
    src = Image.open(os.path.join(PREV, "ref", "old_reel_pixel.png")).convert("RGBA")
    if look["style"]["dither"]:   # sepia ink for the storybook look
        p = src.load()
        for y in range(src.height):
            for x in range(src.width):
                if p[x, y][3] and p[x, y][:3] == (42, 30, 44):
                    p[x, y] = rgb(look["outline"]) + (255,)
    src.save(os.path.join(out, "reel.png"))
    return src.size


def kid_sprite(look, out):
    st = look["style"]
    s = Spr(20, 28, st)
    skin, hat = "#e0a882", char_ramp("#f6c833", look["char_outline"], st["lit"])
    s.rect(7, 22, 9, 28, skin); s.rect(11, 22, 13, 28, skin)       # legs
    s.rect(6, 18, 14, 23, "#3d5a88")                               # shorts
    for y in range(11, 18):                                        # striped shirt
        s.rect(5, y, 15, y + 1, "#2fa7a0" if y % 2 else "#f1e7cf")
    s.rect(3, 12, 5, 17, skin); s.rect(15, 12, 17, 17, skin)
    s.ell(10, 7.5, 4.5, 4.5, char_ramp(skin, look["char_outline"]))
    s.ell(10, 4, 7, 3.4, hat, mask=lambda nx, ny: ny < 0.5)
    s.rect(2, 5, 18, 6, hat[1])
    s.outline(look["char_outline"])
    s.put(8, 8, look["char_outline"]); s.put(12, 8, look["char_outline"])
    s.put(9, 10, "#8a3a3a"); s.put(10, 10, "#8a3a3a")
    s.save(os.path.join(out, "kid.png"))


def dock(look, out):
    st = look["style"]
    w, h, hor = 640, 360, 196
    sky = Spr(w, h, st)
    dawn = [look["sky"][0], look["sky"][1], mix(look["sky"][3], "#ffc890", 0.55), mix("#ffb070", look["sky"][3], 0.2)]
    for y in range(hor + 1):
        t = y / hor
        for x in range(w):
            if st["dither"]:
                c = pick(dawn, t, x, y, st)
            elif st["tile_shades"] == 2:
                c = dawn[min(3, int(t * 4))]
            else:
                c = mix(dawn[0], dawn[1], t / 0.4) if t < 0.4 else (mix(dawn[1], dawn[2], (t - 0.4) / 0.4) if t < 0.8 else mix(dawn[2], dawn[3], (t - 0.8) / 0.2))
            sky.put(x, y, c)
    sun = [mix("#ffd890", "#ff9a50", 0.3)] * 2 + ["#ffe4a8", "#fff4d0"]
    sky.ell(470, hor - 2, 24, 24, sun, mask=lambda nx, ny: ny < 0.08, flat=True)
    cloud(sky, look, 160, 70, 1.4)
    cloud(sky, look, 360, 120, 0.9)
    # far shore and town silhouettes
    shore = mix("#3a4a5a", dawn[1], 0.35)
    for x in range(w):
        hy = hor - 8 - 10 * vnoise(x, 0, 30, 81)
        for y in range(int(hy), hor + 1):
            sky.put(x, y, shore)
    for bx, bw, bh in [(70, 18, 14), (95, 12, 10), (520, 16, 12), (545, 22, 16), (575, 10, 9)]:
        sky.rect(bx, hor - 8 - bh, bx + bw, hor - 8, shore)
        for i in range(bw // 2 + 1):
            sky.rect(bx + i, hor - 8 - bh - i // 2 - 1, bx + bw - i, hor - 8 - bh - i // 2, shore)
    tx = 600
    sky.rect(tx, hor - 40, tx + 2, hor - 8, shore); sky.rect(tx + 12, hor - 40, tx + 14, hor - 8, shore)
    sky.rect(tx - 3, hor - 54, tx + 17, hor - 40, shore); sky.rect(tx, hor - 58, tx + 14, hor - 54, shore)
    # water with sky reflection and a sun glitter path
    water = [mix(dawn[0], "#10304a", 0.4), mix(dawn[1], "#204860", 0.35), mix(dawn[2], dawn[1], 0.4), dawn[3]]
    for y in range(hor + 1, h):
        t = (y - hor) / (h - hor)
        for x in range(w):
            v = 0.62 - t * 0.55 + (vnoise(x, y * 3, 9, 83) - 0.5) * 0.25
            if abs(x - 470) < 40 * (1 - t * 0.3) and (h2(x // 6, y, 84) > 0.55) and t < 0.75:
                v = 0.97
            sky.put(x, y, pick(water, v, x, y, st) if st["tile_shades"] != 4 else water[min(3, max(0, int(v * 4)))])
    sky.save(os.path.join(out, "dock_sky.png"))
    # dock, shore, shed, rail, bait tins, lantern, Strangestone
    d = Spr(w, h, st)
    wood = char_ramp("#9a6a40", look["char_outline"], st["lit"])
    grassc = char_ramp(look["grass"][0], look["char_outline"], st["lit"])
    for x in range(0, 140):                                   # near shore bank
        top = 230 + int(10 * vnoise(x, 0, 25, 85)) + max(0, x - 100) // 2
        for y in range(top, h):
            v = 0.7 - (y - top) / 60 + (h2(x, y, 86) - 0.5) * 0.2
            d.put(x, y, pick(grassc if y - top < 5 else look["rings"]["dirt"][:4], v, x, y, st))
    d.rect(20, 172, 92, 232, wood[1])                          # shed
    for x in range(20, 92, 8):
        d.rect(x, 172, x + 1, 232, wood[0])
    for i in range(40):
        d.rect(14 + i, 172 - i // 2, 98 - i, 173 - i // 2, "#5a6f9c" if not st["dither"] else "#6a7488")
    d.rect(48, 200, 64, 232, mix(wood[0], "#000000", 0.3))   # door
    for x in range(120, 470):                                  # deck planks
        for y in range(248, 258):
            pl = (x // 22) % 2
            v = 0.62 + (0.1 if pl else -0.05) + (h2(x, y // 3, 87) - 0.5) * 0.15 - (0.3 if y == 257 else 0) + (0.25 if y == 248 else 0)
            d.put(x, y, pick(wood, v, x, y, st), enc_n(0, -1 if y == 248 else 0, 1))
        if x % 22 == 0:
            for y in range(249, 258):
                d.put(x, y, wood[0])
    for px in range(130, 470, 56):                             # posts into the water
        d.rect(px, 258, px + 7, 320, wood[1])
        d.rect(px, 258, px + 2, 320, wood[2])
    for px in (130, 242, 354, 466):                            # back rail
        d.rect(px, 214, px + 4, 248, wood[2])
    d.rect(126, 214, 472, 218, wood[2]); d.rect(126, 218, 472, 219, wood[0])
    tin = char_ramp("#b8c4d0", look["char_outline"], st["lit"])
    for i, tx in enumerate((160, 190, 220)):                   # three bait tins (save slots)
        d.ell(tx + 7, 210, 8, 4, tin)
        d.rect(tx, 204, tx + 15, 212, tin[2]); d.rect(tx, 204, tx + 3, 212, tin[3])
        d.rect(tx + 2, 207, tx + 13, 209, ["#f2c230", "#3f8fd8", "#c8a97a"][i])
    stone = char_ramp("#2fb8a8", look["char_outline"], st["lit"])   # Strangestone under the first tin
    d.ell(167, 214, 10, 4, stone, mask=lambda nx, ny: ny > -0.6)
    d.rect(400, 196, 403, 248, wood[1])                        # lantern post
    d.rect(394, 190, 409, 193, wood[0])
    d.ell(401, 202, 4.5, 6, ["#c07020", "#f0a030", "#ffd070", "#fff4c0"])
    d.outline(look["outline"], 2 if st["terrain_outline"] >= 2 else 1)
    # rod and line with the sandwich on the hook
    d.line(291, 233, 372, 160, "#5a3a24")
    d.line(372, 160, 384, 276, mix("#ffffff", look["sky"][2], 0.4))
    d.rect(379, 276, 391, 279, "#e8c080"); d.rect(379, 279, 391, 280, "#7fbf5a"); d.rect(378, 280, 392, 283, "#e8c080")
    d.save(os.path.join(out, "dock.png"), normals=True)
    reel_sprite(look, out)
    kid_sprite(look, out)


# ---- assemble ---------------------------------------------------------------------------------

def L(kind, pos, color, energy, scale, height=24):
    return {"t": "light", "tex": "light_%s.png" % kind, "pos": pos, "color": color, "energy": energy,
            "scale": scale, "height": height}


def build(key):
    look = LOOKS[key]
    st = look["style"]
    out = os.path.join(PREV, key)
    os.makedirs(out, exist_ok=True)
    print("look", key)
    ter, back = terrain(look)
    ter.save(os.path.join(out, "xs_terrain.png"), normals=st["normals"])
    back.save(os.path.join(out, "xs_back.png"))
    sk = sky_layer(look, PW, PH, 150)
    cloud(sk, look, 160, 44, 1.2)
    cloud(sk, look, 640, 70, 0.9)
    hills(sk, look, 160)
    sk.save(os.path.join(out, "xs_sky.png"))
    sprites = {}

    def put(name, spr, pos, z=2):
        spr.save(os.path.join(out, name + ".png"), normals=st["normals"])
        sprites[name] = {"t": "sprite", "tex": name + ".png", "pos": [int(pos[0]), int(pos[1])], "z": z,
                         "normal": (name + "_n.png") if st["normals"] else None}

    # P1 in the dirt tunnel heading right, mouth open on a grub
    p1pts = TUNNELS[0][0]
    hx = 33.0 * TS
    segs = [(hx - i * 9 * K, poly_y(p1pts, (hx - i * 9 * K) / TS) * TS + 2 + 2 * math.sin(i * 1.3)) for i in range(8)]
    s, o = worm(look, P1, segs, (1, 0), 1, mouth_open=1.0, look_at=(1, 0.2), k=K)
    put("worm_p1", s, o, 4)
    gy = poly_y(p1pts, 36.0) * TS + 20
    put("grub", food_grub(look), (35.6 * TS, gy - 21), 3)
    # P2 in the rock tunnel heading left toward an ore nugget
    p2pts = TUNNELS[4][0]
    hx2 = 31.0 * TS
    segs2 = [(hx2 + i * 9 * K, poly_y(p2pts, (hx2 + i * 9 * K) / TS) * TS + 2 + 2 * math.sin(i * 1.1 + 1)) for i in range(7)]
    s, o = worm(look, P2, segs2, (-1, 0), 2, mouth_open=0.6, k=K)
    put("worm_p2", s, o, 4)
    ny = poly_y(p2pts, 27.4) * TS + 22
    put("nugget", food_nugget(look), (26.6 * TS, ny - 20), 3)
    # the smug beetle in its pocket, one stage bigger than P1
    put("beetle", threat_beetle(look), (49.9 * TS, 19.4 * TS + 2.4 * TS - 41), 3)
    # mushroom in the topsoil burrow
    put("mushroom", food_mushroom(look), (13.2 * TS, 12.6 * TS + 2 - 28), 3)
    # crystals in the core cave (one is food and has a face)
    cave_floor = int((CAVE[1] + CAVE[3]) * TS) - 2
    cr_cols = [look["lights"]["crystal"], "#d88af0", look["lights"]["crystal"]]
    for i, (cx, flip) in enumerate([(25.2, 0), (29.6, 0), (34.0, 0)]):
        c = food_crystal(look, cr_cols[i])
        if i == 1:
            face_crystal(look, c)
        put("crystal%d" % i, c, (cx * TS, cave_floor - 28), 3)
    # surface props
    sy = lambda x: (SURF + (math.hypot(x - CXT, R) - R)) * TS
    put("tree", tree(look), (19.5 * TS - 28, sy(19.5) - 66), 1)
    put("fence", fence(look), (49 * TS, sy(52) - 18), 1)
    items = [{"t": "sprite", "tex": "xs_back.png", "pos": [0, 0], "z": -2},
             {"t": "sprite", "tex": "xs_terrain.png", "pos": [0, 0], "z": 0,
              "normal": "xs_terrain_n.png" if st["normals"] else None}] + list(sprites.values())
    mouth = (segs[0][0] + 14, segs[0][1])
    items.append({"t": "particles", "pos": [mouth[0], mouth[1]], "colors": ["#f3e2b0", "#d8c690", "#ffffff", "#a8622c"],
                  "amount": 26, "dir": [-0.3, -1], "spread": 75, "speed": [35, 85], "gravity": [0, 160],
                  "size": 2, "lifetime": 0.7})
    sky_items = [{"t": "sprite", "tex": "xs_sky.png", "pos": [0, 0], "z": 0}]
    layers = [{"layer": -10, "items": sky_items}]
    lit = {"layer": 0, "items": items}
    if st["lit"]:
        lc = look["lights"]
        lit["modulate"] = "#9088a8"
        items += [
            L("band", [480, 300], lc["sun"], 1.0, 3.75, 200),
            L("cone", [42.8 * TS, 150 + 128], lc["sun"], 2.0, 1.0, 60),
            L("radial", [segs[0][0], segs[0][1]], "#c8ffd0", 1.3, 1.1, 30),
            L("radial", [segs2[0][0], segs2[0][1]], "#ffe0c8", 1.3, 1.0, 30),
            L("radial", [14.2 * TS, 12.0 * TS], "#c89cff", 1.2, 0.6, 20),
            L("radial", [25.7 * TS, cave_floor - 8], lc["crystal"], 1.6, 0.9, 20),
            L("radial", [30.1 * TS, cave_floor - 8], "#d88af0", 1.5, 0.8, 20),
            L("radial", [34.5 * TS, cave_floor - 8], lc["crystal"], 1.6, 0.9, 20),
            L("radial", [480, 600], lc["core"], 1.5, 2.6, 40),
        ]
    layers.append(lit)
    if st["paper"]:
        paper(os.path.join(out, "paper.png"), PW, PH)
        layers.append({"layer": 10, "items": [{"t": "sprite", "tex": "paper.png", "pos": [0, 0], "z": 0, "blend": "mul"}]})
    write(out, "xs", {"zoom": 2, "layers": layers, "glow": False})

    # planet shot
    pos = planet(look, out)
    pl_layers = [{"layer": -10, "items": [{"t": "sprite", "tex": "space.png", "pos": [0, 0], "z": 0}]},
                 {"layer": 0, "items": [{"t": "sprite", "tex": "planet.png", "pos": list(pos["planet"]), "z": 0,
                                          "normal": "planet_n.png" if st["normals"] else None}]},
                 {"layer": -5, "items": [{"t": "sprite", "tex": "halo.png", "pos": list(pos["halo"]), "z": 0,
                                          "blend": "add" if st["lit"] else None}]}]
    if st["lit"]:
        pl_layers[1]["modulate"] = "#7a80a0"
        pl_layers[1]["items"] += [L("radial", [180, 90], look["lights"]["sun"], 1.5, 4.5, 140),
                                  L("radial", [480, 272], look["lights"]["core"], 1.8, 0.55, 30)]
    if st["paper"]:
        pl_layers.append({"layer": 10, "items": [{"t": "sprite", "tex": "paper.png", "pos": [0, 0], "z": 0, "blend": "mul"}]})
    write(out, "planet", {"zoom": 2, "layers": pl_layers, "glow": False})

    # dock at dawn
    dock(look, out)
    rw, rh = Image.open(os.path.join(out, "reel.png")).size
    ditems = [{"t": "sprite", "tex": "dock.png", "pos": [0, 0], "z": 0, "normal": "dock_n.png" if st["normals"] else None},
              {"t": "sprite", "tex": "reel.png", "pos": [282 - rw // 2, 248 - rh], "z": 2},
              {"t": "sprite", "tex": "kid.png", "pos": [318, 248 - 28], "z": 2}]
    dlayers = [{"layer": -10, "items": [{"t": "sprite", "tex": "dock_sky.png", "pos": [0, 0], "z": 0}]},
               {"layer": 0, "items": ditems}]
    if st["lit"]:
        dlayers[1]["modulate"] = "#8a7c98"
        ditems += [L("radial", [470, 200], "#ffc890", 1.2, 3.2, 80),
                   L("radial", [401, 202], "#ffc060", 1.4, 0.55, 20),
                   L("radial", [167, 212], "#5ff0d8", 1.2, 0.3, 16)]
    else:
        ditems.append({"t": "particles", "pos": [401, 196], "colors": ["#fff4c0", "#ffd070"], "amount": 6,
                       "dir": [0, -1], "spread": 30, "speed": [4, 10], "gravity": [0, -4], "size": 1, "lifetime": 1.5})
    if st["paper"]:
        paper(os.path.join(out, "paper_dock.png"), 640, 360)
        dlayers.append({"layer": 10, "items": [{"t": "sprite", "tex": "paper_dock.png", "pos": [0, 0], "z": 0, "blend": "mul"}]})
    write(out, "dock", {"zoom": 5, "offset": [148, 92], "layers": dlayers, "glow": False})


def write(out, name, data):
    with open(os.path.join(out, name + ".json"), "w") as f:
        json.dump(data, f, indent=1)


if __name__ == "__main__":
    os.makedirs(PREV, exist_ok=True)
    for kind, steps in (("radial", 10), ("band", 0), ("cone", 0)):
        light_tex(os.path.join(PREV, "light_%s.png" % kind), kind, steps)
    for k in (sys.argv[1:] or ["a", "b", "c"]):
        build(k)
