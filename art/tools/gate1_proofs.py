"""Gate 1 true-resolution proofs from the owner's round-1 Midjourney picks (AD, 2026-11-12).

    python3 art/tools/gate1_proofs.py      # writes art/concepts/round1/proofs/*

Rule: nothing here draws the look. Every pixel comes from Kaden's images
(art/concepts/round1/{a-wet-earth,b-low-light}/) or the grey-box frame; the script only crops,
mirrors, downscales, quantises, multiplies by a light map taken from an owner image, and
composites. Two mechanical exceptions, both game rules rather than style:
  * tunnel layout = the grey-box stage-1 frame's dug pockets (8x8 block mean of the frame);
  * the slot collar = P1 #3cc24a / P2 #e4393c, multiplied by the sprite's own shading.
B+A also gets a 1 px actor outline in P5's own segment-line colour (B's "dark outline on actors").

Real camera (art/brief.md exit check): stage 1 = 3x zoom, so the art canvas is 640x360 and one
16 px tile = 48 screen px; the grey-box worm is 33x18 art px with its head at (304..336, 170..187).
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

sys.path.insert(0, os.path.dirname(__file__))
from worm_looks import de2000  # noqa: E402

R1 = "art/concepts/round1"
OUT = f"{R1}/proofs"
W, H = 640, 360
WORM_BOX = (304, 170, 337, 188)  # grey-box worm, art px
P1, P2 = "#3cc24a", "#e4393c"


def load(p):
    return Image.open(f"{R1}/{p}").convert("RGB")


def hexc(c):
    return "#%02x%02x%02x" % tuple(c[:3])


def mirror_tile(img, w, h):
    """Fill w x h by mirror-tiling img (how a tile set repeats; seams stay continuous)."""
    tw, th = img.size
    row = Image.new("RGB", (tw * 2, th))
    row.paste(img, (0, 0))
    row.paste(ImageOps.mirror(img), (tw, 0))
    blk = Image.new("RGB", (tw * 2, th * 2))
    blk.paste(row, (0, 0))
    blk.paste(ImageOps.flip(row), (0, th))
    out = Image.new("RGB", (w, h))
    for y in range(0, h, th * 2):
        for x in range(0, w, tw * 2):
            out.paste(blk, (x, y))
    return out


def tunnel_mask():
    """Dug pockets of the grey-box stage-1 frame, at the 640x360 art canvas."""
    g = load("greybox-stage1.png").resize((W, H), Image.NEAREST).getchannel("R")
    m = g.resize((W // 4, H // 4), Image.BOX).point(lambda v: 255 if v < 47 else 0)
    m = m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MedianFilter(3))
    m = m.resize((W, H), Image.NEAREST)
    d = ImageDraw.Draw(m)
    d.rectangle((WORM_BOX[0] - 4, WORM_BOX[1] - 1, 372, WORM_BOX[3] + 1), fill=255)  # the worm's own tunnel
    d.rectangle((575, 245, W, H), fill=0)  # HUD panel, not terrain
    return m


def light_from_p5(center, lo=0.18, hi=1.25):
    """B's light model taken from P5 itself: its luminance, blurred, re-centred on the worm."""
    p5 = load("b-low-light/P5-1.png").convert("L").filter(ImageFilter.GaussianBlur(40))
    p5 = p5.resize((W, H), Image.BILINEAR)
    bx, by = 330, 230  # P5's lit floor pool, in 640x360 space
    shifted = ImageChops.offset(p5, center[0] - bx, center[1] - by)
    mx = max(shifted.getextrema()[1], 1)
    return shifted.point(lambda v: int(255 * min(1.0, lo + (hi - lo) * v / mx)))


def mul(img, lmap):
    return ImageChops.multiply(img, Image.merge("RGB", (lmap, lmap, lmap)))


def quant(img, n=None, palette_img=None):
    if palette_img is not None:
        return img.quantize(palette=palette_img, dither=Image.Dither.NONE).convert("RGB")
    return img.quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


def palette_of(img, n):
    q = img.quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: n * 3]
    counts = sorted(q.getcolors(), reverse=True)
    cols = [tuple(pal[i * 3:i * 3 + 3]) for _, i in counts]
    cols.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    return q, cols


def pal_img(cols):
    pi = Image.new("P", (1, 1))
    flat = [v for c in cols for v in c]
    pi.putpalette(flat + flat[:3] * (256 - len(cols)))
    return pi


def dedupe(cols, tol=4.0):
    """Merge near-identical colours (ΔE00 < tol), keep dark-to-light order."""
    keep = []
    for c in sorted(cols, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]):
        if all(de2000(hexc(c), hexc(k)) >= tol for k in keep):
            keep.append(c)
    return keep


def lantern_amber(p6):
    """The amber key: mean of P6's bright orange pixels (lantern and its reflection)."""
    px = [c for c in p6.get_flattened_data() if c[0] > 200 and 100 < c[1] < 190 and c[2] < 120]
    n = max(len(px), 1)
    return tuple(sum(c[i] for c in px) // n for i in range(3))


def worm_ramp(n=5):
    """B's worm flesh ramp, taken from the P5 worm's own pixels, dark to light."""
    spr = worm_p5()
    rgb = spr.convert("RGB")
    a = spr.getchannel("A")
    px = [c for c, m in zip(rgb.get_flattened_data(), a.get_flattened_data()) if m]
    strip = Image.new("RGB", (len(px), 1))
    strip.putdata(px)
    _, cols = palette_of(strip, n)
    return cols


def gradient_map(spr, ramp):
    """Keep the sprite's own values (A's anatomy), repaint them with B's ramp (rank by luminance)."""
    a = spr.getchannel("A")
    lum = spr.convert("L")
    vals = sorted(v for v, m in zip(lum.get_flattened_data(), a.get_flattened_data()) if m)
    cuts = [vals[int(len(vals) * i / len(ramp))] for i in range(1, len(ramp))]
    out = Image.new("RGBA", spr.size, (0, 0, 0, 0))
    po, pl, pa = out.load(), lum.load(), a.load()
    for y in range(spr.height):
        for x in range(spr.width):
            if pa[x, y]:
                i = sum(pl[x, y] >= c for c in cuts)
                po[x, y] = ramp[i] + (255,)
    return out


# ---------------------------------------------------------------- worms (from owner images)
P2_POLY = [(0, 388), (100, 384), (200, 398), (300, 436), (400, 462), (480, 450), (560, 420),
           (650, 378), (750, 328), (850, 268), (930, 214), (1000, 180), (1060, 174), (1100, 192),
           (1125, 234), (1112, 268), (1060, 290), (1000, 306), (940, 334), (880, 380), (800, 432),
           (720, 490), (640, 540), (580, 580), (520, 610), (450, 634), (380, 636), (300, 612),
           (200, 572), (100, 540), (0, 522)]


def worm_p2():
    """A: the P2 worm, lassoed by hand-picked outline points, mirrored to face left like the game."""
    src = load("a-wet-earth/P2-1.png")
    m = Image.new("L", src.size, 0)
    ImageDraw.Draw(m).polygon(P2_POLY, fill=255)
    rgba = src.copy()
    rgba.putalpha(m)
    rgba = ImageOps.mirror(rgba.crop((0, 170, 1130, 640)))
    return rgba


def worm_p5():
    """B: the P5 worm, keyed by its pink (R-G) against the brown/black ground."""
    src = load("b-low-light/P5-1.png").crop((300, 236, 1160, 630))
    r, g, b = src.split()
    key = ImageChops.subtract(r, g).point(lambda v: 255 if v > 45 else 0)
    key = ImageChops.multiply(key, r.point(lambda v: 255 if v > 60 else 0))
    key = key.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))  # close segment lines
    key = key.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))  # drop legs/feelers
    rgba = src.copy()
    rgba.putalpha(key)
    return rgba


def to_sprite(rgba, h, palette_img=None, n=None):
    """Downscale to gameplay height h, hard alpha, quantise."""
    w = round(rgba.width * h / rgba.height)
    small = rgba.resize((w, h), Image.LANCZOS)
    a = small.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    rgb = small.convert("RGB")
    rgb = quant(rgb, n=n, palette_img=palette_img) if (palette_img or n) else rgb
    rgb.putalpha(a)
    return rgb.crop(a.getbbox())


def outline(spr, col):
    a = spr.getchannel("A")
    ring = ImageChops.subtract(a.filter(ImageFilter.MaxFilter(3)), a)
    out = Image.new("RGBA", (spr.width + 2, spr.height + 2), (0, 0, 0, 0))
    base = Image.new("RGBA", out.size, col + (255,))
    ring2 = Image.new("L", out.size, 0)
    ring2.paste(ring.resize(spr.size), (1, 1))
    full_a = Image.new("L", out.size, 0)
    full_a.paste(a, (1, 1))
    grown = full_a.filter(ImageFilter.MaxFilter(3))
    out.paste(base, (0, 0), ImageChops.subtract(grown, full_a))
    out.paste(spr, (1, 1), spr)
    return out


def collar(spr, frac0, frac1, slot_hex):
    """Slot colour on 2 columns at the saddle, keeping the sprite's own shading."""
    s = spr.copy()
    sc = tuple(int(slot_hex[i:i + 2], 16) for i in (1, 3, 5))
    px = s.load()
    x0, x1 = int(s.width * frac0), max(int(s.width * frac0) + 2, int(s.width * frac1))
    for x in range(x0, x1):
        for y in range(s.height):
            r, g, b, a = px[x, y]
            if a:
                lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
                k = 0.55 + 0.6 * lum
                px[x, y] = tuple(min(255, int(c * k)) for c in sc) + (255,)
    return s


# ---------------------------------------------------------------- environments
def p1_crop():
    """P1 with its own (too big for the camera) worm painted out with soil from the same strata."""
    p1 = load("a-wet-earth/P1-1.png")
    donor = p1.crop((30, 515, 570, 650))  # same strata, 535 px to the left, no worm
    soft = Image.new("L", donor.size, 0)
    ImageDraw.Draw(soft).rectangle((12, 10, donor.width - 12, donor.height - 10), fill=255)
    p1.paste(donor, (565, 515), soft.filter(ImageFilter.GaussianBlur(6)))
    p1b = p1
    # stage-1 crop: 16:9, surface band at the top (the cutaway Kaden picked), soil below
    return p1b.crop((300, 300, 1217, 816)).resize((W, H), Image.LANCZOS)


def far_wall(soil, k=0.42):
    """Tunnel = the cutaway's back wall: the same soil, defocused and in shadow (P1's own haze)."""
    fw = soil.filter(ImageFilter.GaussianBlur(5))
    return ImageChops.multiply(fw, Image.new("RGB", soil.size, tuple(int(255 * k * c / 255) for c in (230, 245, 255))))


def env_a(mask):
    soil = p1_crop()
    tun = far_wall(soil)
    m = mask.copy()
    ImageDraw.Draw(m).rectangle((0, 0, W, 70), fill=0)  # surface band stays intact
    return Image.composite(tun, soil, m)


def tile_field(src, boxes, w, h, ts=16, seed=7):
    """Cut ts x ts tiles from src inside boxes and lay them on the 16 px grid at random (a tile set)."""
    import random
    rnd = random.Random(seed)
    tiles = []
    for (x0, y0, x1, y1) in boxes:
        for y in range(y0, y1 - ts + 1, ts // 2):
            for x in range(x0, x1 - ts + 1, ts // 2):
                t = src.crop((x, y, x + ts, y + ts))
                lum = t.convert("L").resize((1, 1), Image.BOX).getpixel((0, 0))
                r, g, _ = t.resize((1, 1), Image.BOX).getpixel((0, 0))
                tr, tg, _ = t.split()
                pink = ImageChops.subtract(tr, tg).getextrema()[1]
                if 22 < lum < 140 and r - g < 30 and pink < 70:  # lit enough, no piece of the pink worm
                    tiles.append(t)
    out = Image.new("RGB", (w, h))
    for y in range(0, h, ts):
        for x in range(0, w, ts):
            t = rnd.choice(tiles)
            out.paste(ImageOps.mirror(t) if rnd.random() < 0.5 else t, (x, y))
    return out


def p5_small():
    """P5 at the scale where its clods are about one 16 px tile."""
    p5 = load("b-low-light/P5-1.png")
    return p5.resize((round(1456 * 0.3), round(816 * 0.3)), Image.LANCZOS)


def env_b(mask, worm_c):
    s5 = p5_small()  # 437 x 245
    solid = tile_field(s5, [(0, 40, 100, 245), (330, 0, 437, 200), (60, 0, 330, 60)], W, H, seed=7)
    # P5's open cavity is near-black; its lit floor is the only bright ground. Tunnels = that void.
    tun = ImageChops.multiply(tile_field(s5, [(150, 150, 320, 235)], W, H, seed=11),
                              Image.new("RGB", (W, H), (46, 40, 44)))
    img = Image.composite(tun, solid, mask)
    return mul(img, light_from_p5(worm_c, lo=0.30, hi=1.35))


def env_mix(mask, worm_c, b_pal_img):
    soil = p1_crop()
    m = mask.copy()
    ImageDraw.Draw(m).rectangle((0, 0, W, 70), fill=0)
    img = Image.composite(far_wall(soil, 0.5), soil, m)
    # B light model over A's composition: P1's own top light pushed low-key, plus P5's pool on the worm
    depth = soil.convert("L").filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(255 * (v / 255) ** 1.6))
    pool = light_from_p5(worm_c, lo=0.0, hi=1.1)
    lmap = ImageChops.lighter(depth.point(lambda v: min(255, int(v * 2.2))), pool)
    lmap = lmap.point(lambda v: max(46, v))
    dusk = Image.new("L", (W, H), 255)
    ImageDraw.Draw(dusk).rectangle((0, 0, W, 62), fill=120)  # P6's dusk sky, not P1's overcast noon
    lmap = ImageChops.multiply(lmap, dusk.filter(ImageFilter.GaussianBlur(4)))
    return quant(mul(img, lmap), palette_img=b_pal_img)


# ---------------------------------------------------------------- main
def place(env, spr):
    out = env.copy()
    cx, cy = (WORM_BOX[0] + WORM_BOX[2]) // 2, (WORM_BOX[1] + WORM_BOX[3]) // 2
    out.paste(spr, (cx - spr.width // 2, cy - spr.height // 2), spr)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    mask = tunnel_mask()
    mask.save(f"{OUT}/tunnels-from-greybox.png")
    worm_c = ((WORM_BOX[0] + WORM_BOX[2]) // 2, (WORM_BOX[1] + WORM_BOX[3]) // 2)

    # palettes, all from the owner's images
    a_src = Image.new("RGB", (1456, 816 * 2))
    a_src.paste(load("a-wet-earth/P1-1.png"), (0, 0))
    a_src.paste(load("a-wet-earth/P2-1.png"), (0, 816))
    a_q, a_cols = palette_of(a_src, 24)
    _, p5_cols = palette_of(load("b-low-light/P5-1.png"), 12)
    p6_src = Image.new("RGB", (1456, 816 * 2))
    p6_src.paste(load("b-low-light/P6-1.png"), (0, 0))
    p6_src.paste(load("b-low-light/P6-2.png"), (0, 816))
    _, p6_cols = palette_of(p6_src, 6)
    ramp = worm_ramp()
    b_cols = dedupe(p5_cols + p6_cols + ramp + [lantern_amber(p6_src)])
    b_q = pal_img(b_cols)
    env = {
        "a": quant(env_a(mask), palette_img=a_q),
        "b": quant(env_b(mask, worm_c), palette_img=b_q),
        "mix": env_mix(mask, worm_c, b_q),
    }
    wa = to_sprite(worm_p2(), 17, palette_img=a_q)
    wb = to_sprite(worm_p5(), 18, palette_img=pal_img(ramp + [(60, 10, 26)]))
    p5_line = (60, 10, 26)  # P5's own segment-line colour, sampled at (560, 330)
    wmix = outline(gradient_map(to_sprite(worm_p2(), 15), ramp), p5_line)
    worms = {"a": (wa, 0.22, 0.30), "b": (wb, 0.30, 0.38), "mix": (wmix, 0.22, 0.30)}

    meta = {"palettes": {}, "worm_sizes": {}}
    for k, (spr, f0, f1) in worms.items():
        p1w, p2w = collar(spr, f0, f1, P1), collar(spr, f0, f1, P2)
        frame = place(env[k], p1w)
        frame.save(f"{OUT}/{k}-stage1-640x360.png")
        frame.resize((W * 3, H * 3), Image.NEAREST).save(f"{OUT}/{k}-stage1-3x.png")
        frame.resize((W // 2, H // 2), Image.NEAREST).save(f"{OUT}/{k}-stage5-minify-0.5x.png")
        spr.save(f"{OUT}/{k}-worm-plain.png")
        p1w.save(f"{OUT}/{k}-worm-p1.png")
        p2w.save(f"{OUT}/{k}-worm-p2.png")
        meta["worm_sizes"][k] = list(spr.size)
        worm_sheet(k, env[k], spr, p1w, p2w)

    for k, cols in (("a", a_cols), ("b", b_cols)):
        meta["palettes"][k] = [{"hex": hexc(c), "dE_P1": round(de2000(hexc(c), P1), 1),
                                "dE_P2": round(de2000(hexc(c), P2), 1)} for c in cols]
    # mix = B's palette (it is quantised to it); record which B colours the mix frame actually uses
    used = {hexc(c) for _, c in env["mix"].getcolors(1 << 16)}
    meta["palettes"]["mix"] = [p for p in meta["palettes"]["b"] if p["hex"] in used]
    with open(f"{OUT}/palettes.json", "w") as f:
        json.dump(meta, f, indent=1)
    print(json.dumps(meta["worm_sizes"]))


def worm_sheet(k, env, plain, p1w, p2w):
    """Grey-box worm vs proposal, on its own ground: 1x row and 6x row."""
    gb = load("greybox-stage1.png").resize((W, H), Image.NEAREST)
    bx0, by0 = WORM_BOX[0] - 14, WORM_BOX[1] - 12
    gcrop = gb.crop((bx0, by0, bx0 + 64, by0 + 42))
    cx, cy = (WORM_BOX[0] + WORM_BOX[2]) // 2, (WORM_BOX[1] + WORM_BOX[3]) // 2
    tiles = []
    for spr in (plain, p1w, p2w):
        t = env.crop((cx - 32, cy - 21, cx + 32, cy + 21))
        t.paste(spr, (32 - spr.width // 2, 21 - spr.height // 2), spr)
        tiles.append(t)
    row = [gcrop] + tiles
    one = Image.new("RGB", (len(row) * 70, 48), (20, 20, 24))
    for i, t in enumerate(row):
        one.paste(t, (i * 70 + 3, 3))
    six = one.resize((one.width * 6, one.height * 6), Image.NEAREST)
    sheet = Image.new("RGB", (six.width, six.height + one.height + 12), (20, 20, 24))
    sheet.paste(one, (0, 0))
    sheet.paste(six, (0, one.height + 12))
    sheet.save(f"{OUT}/{k}-worm-sheet.png")


if __name__ == "__main__":
    main()
