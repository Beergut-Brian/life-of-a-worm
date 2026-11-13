"""A-002 main-character candidates: three player worms at gameplay scale (AD, 2026-11-12).

    python3 art/tools/worm_master_candidates.py     # writes art/concepts/worm-master/*

Rule (as in gate1_proofs.py): no new look is invented here. Each worm is derived from a Gate-1 proof
worm (art/concepts/round1/proofs/{a,b,mix}-worm-plain.png, themselves cut from Kaden's P2 / P5):
  * straighten: every source column's body run (outline stripped) is a vertical value profile;
    columns are mirrored to face right and nearest-neighbour resampled to the target length and
    thickness (the vertical thickening to the style bible's 9-10 art px);
  * palette remap: values ranked by luminance onto the style-bible v1.0 flesh ramp;
  * then the mechanical style-bible rules only: tapered head and tail, ring stripes / segment
    separators from the ramp, saddle band, slot collar with separators, 1 px eye, 1 px outline.
The in-world crop reuses gate1_proofs.env_mix (the approved B+A mix stage-1 frame) with the proof
worm left out.
"""
import json
import os
import statistics
import sys

sys.dont_write_bytecode = True  # do not touch the tracked art/tools/__pycache__
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(ROOT)
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))

from PIL import Image, ImageDraw, ImageFont, ImageOps  # noqa: E402

import gate1_proofs as g  # noqa: E402
from worm_looks import de2000  # noqa: E402

OUT = "art/concepts/worm-master"
PROOFS = "art/concepts/round1/proofs"
P1, P2 = "#3cc24a", "#e4393c"
BG = (0x14, 0x14, 0x1a)
INK = (210, 210, 220)
DIM = (140, 140, 155)

# style bible v1.0 flesh ramp; index 0 = outline / separators / eye
RAMP = ["#1e090d", "#3c0a1a", "#7d4650", "#c4917c", "#e8b08c", "#f0c8a4"]
SADDLE = "#c09b95"
OLD = ["#d6756a", "#a9334f", "#93674f"]
OUTLINE, DEEP, SHADOW, MID, LIGHT, GLINT = range(6)

# data/stages.tres: size and the zoom of its zoom_index (stage 1 = 3x camera)
STAGES = [(1, 1.0, 3.0), (2, 1.18, 2.0), (3, 1.36, 1.0), (4, 1.54, 1.0), (5, 1.72, 0.5)]
ENV_C = (320, 179)  # proof worm centre on the 640x360 stage-1 canvas


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def font(sz=12):
    return ImageFont.load_default(sz)


# ---------------------------------------------------------------- candidates
# interior thickness = silhouette - 2 (1 px outline top and bottom)
CANDS = {
    "c1": dict(name="C1 Annelid", src="a", T=9, L=46, period=3,
               tail=[1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6], head=[7, 6, 6, 5, 4, 3],
               fr=[0.12, 0.22, 0.36, 0.22, 0.08], collar_at=1 / 3, saddle=(4, 4, (MID, LIGHT, GLINT))),
    "c2": dict(name="C2 Lamplit", src="mix", T=10, L=44, period=4,
               tail=[2, 3, 3, 4, 5, 5, 6, 6, 7, 7], head=[8, 8, 7, 6, 5, 3],
               fr=[0.18, 0.2, 0.3, 0.2, 0.12], collar_at=1 / 4, saddle=(1, 5, (MID,))),
    "c3": dict(name="C3 Plated", src="b", T=10, L=42, period=5, src_cols=(0, 28),
               tail=[3, 4, 5, 6, 6, 7, 7], head=[8, 7, 5],
               fr=[0.14, 0.24, 0.32, 0.22, 0.08], collar_at=1 / 4, saddle=(0, 5, (MID, LIGHT))),
}


def source_profiles(key, cols=None):
    """Per source column, the body run's luminances (outline stripped), head mirrored to the right."""
    spr = Image.open(f"{PROOFS}/{key}-worm-plain.png").convert("RGBA")
    if cols:
        spr = spr.crop((cols[0], 0, cols[1], spr.height))
    if key != "b":  # a / mix face left (gate1 mirrored P2); b's head is already on the right
        spr = ImageOps.mirror(spr)
    px = spr.load()
    profs = []
    for x in range(spr.width):
        runs, cur = [], []
        for y in range(spr.height):
            if px[x, y][3]:
                cur.append(lum(px[x, y]))
            elif cur:
                runs.append(cur)
                cur = []
        if cur:
            runs.append(cur)
        if not runs:
            continue
        run = max(runs, key=len)
        if len(run) >= 5:  # strip a drawn outline (mix) so the new outline is the only one
            if run[0] < 50:
                run = run[1:]
            if run[-1] < 50:
                run = run[:-1]
        profs.append(run)
    return profs


def thickness_profile(c):
    """Interior thickness per column, tail (left) to head (right)."""
    ti = c["T"] - 2
    mid = c["L"] - len(c["tail"]) - len(c["head"])
    return c["tail"] + [ti] * mid + c["head"]


def build_interior(c):
    """Grid[y][x] of ramp indices (None = empty), interior only, stage 1, no collar/eye yet."""
    profs = source_profiles(c["src"], c.get("src_cols"))
    tp = thickness_profile(c)
    ti, L = c["T"] - 2, c["L"]
    vals = [[None] * L for _ in range(ti)]
    for x, t in enumerate(tp):
        sp = profs[min(len(profs) - 1, x * len(profs) // L)]
        top = round((ti - t) * 0.55)
        for k in range(t):
            vals[top + k][x] = sp[min(len(sp) - 1, k * len(sp) // t)]
    # smooth along the body (7 px window) so the source's top-lit / dark-under profile reads,
    # not its per-pixel speckle from the 1456 px -> 17 px downscale
    sm = [[None] * L for _ in range(ti)]
    for y in range(ti):
        for x in range(L):
            if vals[y][x] is not None:
                win = [vals[y][i] for i in range(max(0, x - 3), min(L, x + 4)) if vals[y][i] is not None]
                sm[y][x] = sum(win) / len(win)
    vals = sm
    flat = sorted(v for row in vals for v in row if v is not None)
    cuts, acc = [], 0.0
    for f in c["fr"][:-1]:
        acc += f
        cuts.append(flat[min(len(flat) - 1, int(len(flat) * acc))])
    grid = [[None if v is None else 1 + sum(v >= q for q in cuts) for v in row] for row in vals]
    return grid, tp


def col_cells(grid, x):
    return [y for y in range(len(grid)) if grid[y][x] is not None]


def apply_style(key, c, grid, tp):
    L = c["L"]
    over = [[None] * L for _ in grid]  # overlay tokens: "S" saddle, ("C", tone), 0 separator/eye
    head_n, tail_n = len(c["head"]), len(c["tail"])
    cc = round(L - 1 - L * c["collar_at"])  # collar centre column
    collar = (cc - 1, cc)  # first and last column: 2 px wide (thickness < 12)
    seps = (collar[0] - 1, collar[1] + 1)
    s_before, s_after, s_idx = c["saddle"]
    if key == "c3":  # saddle = the whole segment behind the collar
        sad = range(seps[0] - 5, seps[0])
    else:
        sad = range(seps[0] - s_before, seps[1] + 1 + s_after)

    if key == "c1":  # ring stripes: every 3rd column one ramp step darker (not below shadow)
        for x in range(tail_n - 2, L - head_n + 1):
            if x % c["period"] == 0 and x not in sad:
                for y in col_cells(grid, x):
                    if grid[y][x] > SHADOW:
                        grid[y][x] -= 1
    if key == "c2":  # strong top light, dark underside (the mix proof's own read)
        for x in range(L):
            ys = col_cells(grid, x)
            if len(ys) >= 4:
                grid[ys[0]][x] = GLINT if x < L - 2 else LIGHT
                grid[ys[1]][x] = max(grid[ys[1]][x], LIGHT)
                grid[ys[-1]][x] = DEEP
                grid[ys[-2]][x] = min(grid[ys[-2]][x], SHADOW)
    if key == "c3":  # plates: 4 px segments, 1 px shadow separators, flat shading per row
        phase = (seps[0]) % 5  # separators line up with the collar's separators
        for x0 in range(phase - 5, L, 5):
            seg = [x for x in range(x0 + 1, x0 + 5) if 0 <= x < L]
            for y in range(len(grid)):
                vs = [grid[y][x] for x in seg if grid[y][x] is not None]
                if vs:
                    m = statistics.median_low(vs)
                    for x in seg:
                        if grid[y][x] is not None:
                            grid[y][x] = m
            if 0 <= x0 < L - 2:
                for y in col_cells(grid, x0):
                    if grid[y][x0] > SHADOW:
                        grid[y][x0] = SHADOW
        # light falls on the plate tops: first row lit, last row deep (P5's own read)
        for x in range(L):
            ys = col_cells(grid, x)
            if len(ys) >= 4:
                grid[ys[-1]][x] = DEEP
                if grid[ys[0]][x] > SHADOW:
                    grid[ys[0]][x] = max(grid[ys[0]][x], LIGHT)

    # head: no dark streak may run to the tip (it would read as a mouth); dark only on the underside
    for x in range(L - head_n - 3, L):
        ys = col_cells(grid, x)
        for y in ys[:-2]:
            if grid[y][x] < MID:
                grid[y][x] = MID
    for x in sad:
        for y in col_cells(grid, x):
            if grid[y][x] in s_idx:
                over[y][x] = "S"
    for x in range(collar[0], collar[1] + 1):
        for y in col_cells(grid, x):
            v = grid[y][x]
            over[y][x] = ("C", 2 if v >= LIGHT else (1 if v == MID else 0), over[y][x])
    for x in seps:
        for y in col_cells(grid, x):
            over[y][x] = ("X", None, over[y][x])
    # eye: 1 px, upper half of the head, about 3 px behind the tip
    ex = L - 4 if key != "c3" else L - 3
    ys = col_cells(grid, ex)
    ey = ys[0] + max(1, (len(ys) - 1) // 2 - 1)
    over[ey][ex] = 0
    meta = {"collar_cols": list(collar), "separator_cols": list(seps), "eye": [ex, ey],
            "saddle_cols": [sad[0], sad[-1]]}
    return over, meta


def grow(grid, over, L, stage, period, start):
    """Stage length = base x (1 + 0.15 (stage - 1)), by repeating whole middle periods."""
    extra = round(L * 0.15 * (stage - 1) / period) * period
    if not extra:
        return grid, over
    block = list(range(start, start + period))
    ins = [block[i % period] for i in range(extra)]

    def g2(m):
        return [row[:start] + [row[x] for x in ins] + row[start:] for row in m]
    return g2(grid), g2(over)


def slot_tones(slot):
    """3 collar tones: underside darker, mid = the slot colour, lit top lighter."""
    sc = rgb(slot)
    return [tuple(round(v * 0.68) for v in sc), sc, tuple(round(v + (255 - v) * 0.25) for v in sc)]


def render(grid, over, slot=None):
    h, w = len(grid), len(grid[0])
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = img.load()
    sc = rgb(slot) if slot else None
    tones = slot_tones(slot) if slot else None
    for y in range(h):
        for x in range(w):
            v = grid[y][x]
            if v is None:
                continue
            o = over[y][x]
            if o == 0:
                col = rgb(RAMP[0])
            elif isinstance(o, tuple):  # collar / separator; the plain sprite shows what is under it
                if tones:
                    col = rgb(RAMP[0]) if o[0] == "X" else tones[o[1]]
                else:
                    col = rgb(SADDLE if o[2] == "S" else RAMP[v])
            elif o == "S":
                col = rgb(SADDLE)
            else:
                col = rgb(RAMP[v])
            px[x + 1, y + 1] = col + (255,)
    a = img.getchannel("A")
    ap = a.load()
    oc = rgb(RAMP[0]) + (255,)
    for y in range(img.height):
        for x in range(img.width):
            if ap[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and ap[nx, ny]:
                    px[x, y] = oc
                    break
    return img


def measure(img):
    a = img.getchannel("A")
    w, h = img.size
    cols = [sum(1 for y in range(h) if a.getpixel((x, y))) for x in range(w)]
    return cols


# ---------------------------------------------------------------- presentation
def label(img, xy, text, sz=12, col=INK):
    ImageDraw.Draw(img).text(xy, text, fill=col, font=font(sz))


def up(img, k):
    return img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.NEAREST)


def glow(spr, slot, a1=0.65, a2=0.5):
    """1-2 px outer glow in the slot colour behind a screen-size sprite (GATE1 far-zoom rec)."""
    sc = rgb(slot)
    out = Image.new("RGBA", (spr.width + 4, spr.height + 4), (0, 0, 0, 0))
    a = Image.new("L", out.size, 0)
    a.paste(spr.getchannel("A"), (2, 2))
    from PIL import ImageFilter
    r1 = a.filter(ImageFilter.MaxFilter(3))
    r2 = r1.filter(ImageFilter.MaxFilter(3))
    lay = Image.new("RGBA", out.size, sc + (0,))
    lay.putalpha(Image.eval(r2, lambda v: int(v * a2)))
    lay2 = Image.new("RGBA", out.size, sc + (0,))
    lay2.putalpha(Image.eval(r1, lambda v: int(v * a1)))
    out = Image.alpha_composite(out, lay)
    out = Image.alpha_composite(out, lay2)
    out.alpha_composite(spr, (2, 2))
    return out


def side_views(plain, p1, p2):
    pad, gap = 12, 24
    rows = []
    for k in (1, 3):
        ims = [up(s, k) for s in (plain, p1, p2)]
        rows.append((k, ims))
    w = pad * 2 + max(sum(i.width for i in ims) + gap * 2 for _, ims in rows) + 50
    h = pad + sum(max(i.height for i in ims) + 22 for _, ims in rows) + pad
    img = Image.new("RGB", (w, h), BG)
    y = pad
    for k, ims in rows:
        x = pad + 50
        label(img, (pad, y + 2), f"{k}x", 12, DIM)
        for name, im in zip(("plain", "P1", "P2"), ims):
            label(img, (x, y), name, 11, DIM)
            img.paste(im, (x, y + 16), im)
            x += im.width + gap
        y += max(i.height for i in ims) + 22
    return img


def in_world(env, spr):
    f = env.copy()
    f.paste(spr, (ENV_C[0] - spr.width // 2, ENV_C[1] - spr.height // 2), spr)
    crop = f.crop((ENV_C[0] - 100, ENV_C[1] - 55, ENV_C[0] + 100, ENV_C[1] + 55))
    return up(crop, 3)


def size_strip(variants, max_w=1100):
    """variants: list of (label, screen-size RGBA). Wrapped to max_w."""
    pad, gap = 12, 28
    cells = []
    for text, im in variants:
        tw = int(ImageDraw.Draw(Image.new("RGB", (1, 1))).textlength(text, font=font(11)))
        cells.append((text, im, max(im.width, tw)))
    rows, cur, cw = [], [], pad
    for c in cells:
        if cur and cw + c[2] > max_w - pad:
            rows.append(cur)
            cur, cw = [], pad
        cur.append(c)
        cw += c[2] + gap
    rows.append(cur)
    w = max(pad + sum(c[2] + gap for c in r) for r in rows)
    hs = [max(c[1].height for c in r) + 34 for r in rows]
    img = Image.new("RGB", (min(w, max_w), sum(hs) + pad), BG)
    y = pad
    for r, rh in zip(rows, hs):
        x = pad
        for text, im, cw in r:
            img.paste(im, (x, y + (rh - 34 - im.height) // 2), im)
            label(img, (x, y + rh - 26), text, 11, INK)
            x += cw + gap
        y += rh
    return img


def stack(parts, gap=10, bg=BG, title=None, tsz=16):
    w = max(p.width for p in parts)
    th = tsz + 14 if title else 0
    h = th + sum(p.height for p in parts) + gap * (len(parts) - 1)
    img = Image.new("RGB", (w, h), bg)
    if title:
        label(img, (8, 6), title, tsz)
    y = th
    for p in parts:
        img.paste(p, (0, y))
        y += p.height + gap
    return img


def mix_env():
    p6 = Image.new("RGB", (1456, 816 * 2))
    p6.paste(g.load("b-low-light/P6-1.png"), (0, 0))
    p6.paste(g.load("b-low-light/P6-2.png"), (0, 816))
    _, p5c = g.palette_of(g.load("b-low-light/P5-1.png"), 12)
    _, p6c = g.palette_of(p6, 6)
    bq = g.pal_img(g.dedupe(p5c + p6c + g.worm_ramp() + [g.lantern_amber(p6)]))
    return g.env_mix(g.tunnel_mask(), ENV_C, bq)


def main():
    os.makedirs(f"{OUT}/sprites", exist_ok=True)
    env = mix_env()
    report = {"rules": {"ramp": RAMP, "saddle": SADDLE, "P1": P1, "P2": P2,
                        "thickness_note": "silhouette incl. 1 px outline; median over columns "
                                          "excluding head and tail taper"},
              "candidates": {}}
    columns = []
    for key, c in CANDS.items():
        grid, tp = build_interior(c)
        over, meta = apply_style(key, c, grid, tp)
        plain, p1, p2 = (render(grid, over, s) for s in (None, P1, P2))
        for n, im in (("plain", plain), ("p1", p1), ("p2", p2)):
            im.save(f"{OUT}/sprites/{key}-stage1-{n}.png")

        # stage strip (P1 collar), screen size = art x size x zoom
        start = len(c["tail"]) + 2
        start += (meta["separator_cols"][0] - start) % c["period"] if key == "c3" else 0
        var = []
        st5 = None
        for s, size, zoom in STAGES:
            gg, oo = grow(grid, over, c["L"], s, c["period"], start)
            art = render(gg, oo, P1)
            scr = up(art, size * zoom)
            var.append((f"stage {s}, {scr.width}x{scr.height} px on screen", scr))
            if s == 5:
                st5 = (gg, oo, size * zoom)
        gg, oo, k5 = st5
        for slot, nm in ((P1, "P1"), (P2, "P2")):
            scr = up(render(gg, oo, slot), k5)
            gl = glow(scr, slot)
            var.append((f"stage 5 + {nm} glow, {gl.width}x{gl.height}", gl))

        sv = side_views(plain, p1, p2)
        world = in_world(env, p1)
        world2 = in_world(env, p2)
        wrow = Image.new("RGB", (world.width * 2 + 12, world.height + 22), BG)
        label(wrow, (8, 3), "in world, stage 1 at 3x (B+A mix frame): P1", 12, DIM)
        label(wrow, (world.width + 20, 3), "P2", 12, DIM)
        wrow.paste(world, (0, 22))
        wrow.paste(world2, (world.width + 12, 22))
        strip = size_strip(var, max_w=wrow.width)
        sheet = stack([sv, wrow, strip], title=f"{c['name']}  (from {c['src']}-worm-plain, "
                                                f"{plain.width}x{plain.height} art px at stage 1)")
        sheet.save(f"{OUT}/{key}-{c['name'].split()[1].lower()}.png")

        # compare column
        sv3 = Image.new("RGB", (620, p1.height * 3 * 2 + 50), BG)
        label(sv3, (8, 4), "3x side view: P1 / P2", 12, DIM)
        sv3.paste(up(p1, 3), (8, 22), up(p1, 3))
        sv3.paste(up(p2, 3), (8 + p1.width * 3 + 30, 22), up(p2, 3))
        sv3.paste(up(plain, 3), (8 + p1.width * 6 + 60, 22), up(plain, 3))
        label(sv3, (8 + p1.width * 6 + 60, p1.height * 3 + 26), "plain", 11, DIM)
        sv3 = sv3.crop((0, 0, 620, p1.height * 3 + 44))
        columns.append(stack([sv3, world, size_strip(var, max_w=620)], title=c["name"], tsz=15))

        # measurements and colours
        cols = measure(plain)
        body = cols[len(c["tail"]) + 1: len(cols) - len(c["head"]) - 1]
        used = set()
        for im in (plain, p1, p2):
            used |= {"#%02x%02x%02x" % px[:3] for _, px in im.getcolors(4096) if px[3]}
        colours = []
        for h in sorted(used, key=lambda h: lum(rgb(h))):
            hx = {sn: ["#%02x%02x%02x" % t for t in slot_tones(sl)] for sn, sl in (("P1", P1), ("P2", P2))}
            role = ("P1 collar" if h in hx["P1"] else "P2 collar" if h in hx["P2"]
                    else "ramp" if h in RAMP else "saddle" if h == SADDLE else "other")
            d1, d2 = round(de2000(h, P1), 1), round(de2000(h, P2), 1)
            colours.append({"hex": h, "role": role, "dE_P1": d1, "dE_P2": d2,
                            "flag": role not in ("P1 collar", "P2 collar") and min(d1, d2) < 20})
        report["candidates"][key] = {
            "name": c["name"], "source": f"{PROOFS}/{c['src']}-worm-plain.png",
            "stage1_art_px": list(plain.size),
            "thickness_median": statistics.median(body), "thickness_range": [min(body), max(body)],
            "length": plain.width, "old_colours_present": sorted(set(OLD) & used),
            "collar": meta, "colours": colours,
            "stage_screen_px": [list(v[1].size) for v in var[:5]],
        }
        print(key, plain.size, "median", statistics.median(body), "flags",
              [x["hex"] for x in colours if x["flag"]])

    head = ("Life of a Worm - A-002 main character candidates (AD, 2026-11-12). "
            "Derived from Kaden's round-1 picks; nothing new invented in code.")
    gap = 16
    w = sum(cm.width for cm in columns) + gap * (len(columns) + 1)
    h = max(cm.height for cm in columns) + 44
    cmp_ = Image.new("RGB", (w, h), BG)
    label(cmp_, (gap, 10), head, 18)
    x = gap
    for cm in columns:
        cmp_.paste(cm, (x, 40))
        x += cm.width + gap
    cmp_.save(f"{OUT}/compare.png")
    with open(f"{OUT}/deltae.json", "w") as f:
        json.dump(report, f, indent=1)


if __name__ == "__main__":
    main()
