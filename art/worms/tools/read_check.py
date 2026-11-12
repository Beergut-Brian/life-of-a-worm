"""Read-check sheet and lineup for Gulp (P1) and Burp (P2), from the shipped sprites.

    python3 art/worms/tools/read_check.py [out_dir]     (default: art/worms/renders)

Writes read_check.png (3D side, pixel worm at 1x, at game scale on dirt and topsoil, 16 px
silhouette, each with a "should read as" caption), lineup.png (both worms, stages 1 to 3, on
dirt and topsoil at game scale) and moods.png (every mood per stage at 6x).
"""
import os
import sys

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
CH = os.path.join(ROOT, "assets", "characters")
REN = os.path.join(ROOT, "art", "worms", "renders")
OUT = sys.argv[1] if len(sys.argv) > 1 else REN
FONT = os.path.join(ROOT, "assets", "fonts", "nunito")
# Lantern Deep palettes (tests/test_worm_look_deltae.gd).
DIRT = (0x4a, 0x2e, 0x1f)
TOPSOIL = (0x3d, 0x5e, 0x36)
SHEET_BG = (24, 18, 22)
TEXT = (240, 232, 214)
FLAVOURS = [(0.6275, 0.4392, 0.2353), (1, 0.6235, 0.1098), (0.5529, 0.6, 0.6824), (0.4353, 0.9412, 1),
            (0.902, 0.7608, 0.1608), (0.2275, 0.5255, 1), (0.7882, 0.7216, 1), (1, 0.4353, 0.8471)]
SEGS = {1: 4, 2: 6, 3: 10}
GAME_SCALE = 3      # the shared camera's zoom on a 1080p TV, about 3x at stage 1
MOODS = ["idle", "ajar", "open", "chomp_1", "chomp_2", "chomp_3", "squash", "happy", "worried", "sleep"]
CAP = {
    "gulp": "Gulp (P1): green worm, light belly stripe, ONE big lidded eye",
    "burp": "Burp (P2): red worm, dark belly stripe, TWO small eyes, a bit cross-eyed",
}


def font(px):
    for root, _d, files in os.walk(FONT):
        for f in sorted(files):
            if f.endswith(".ttf"):
                return ImageFont.truetype(os.path.join(root, f), px)
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", px)


def load(name, stage, part):
    return Image.open(os.path.join(CH, name, f"s{stage}", f"{part}.png")).convert("RGBA")


def tint(img, rgb):
    r, g, b, a = img.split()
    f = [int(c * 255) for c in rgb]
    r = r.point(lambda v: v * f[0] // 255)
    g = g.point(lambda v: v * f[1] // 255)
    b = b.point(lambda v: v * f[2] // 255)
    return Image.merge("RGBA", (r, g, b, a))


def worm(name, stage, mood="idle", flavours=True):
    """The assembled worm, facing right: tail, bodies (bands tinted), head + face, as in the game."""
    seg = load(name, stage, "body")
    head = load(name, stage, "head")
    head.alpha_composite(load(name, stage, f"face_{mood}"))
    n = SEGS[stage]
    step = max(1, round(seg.width * 0.62))   # Worm.spacing(): segments overlap like the game
    w = step * n + head.width - (head.width - seg.width) // 2
    h = head.height
    img = Image.new("RGBA", (w, h))
    cy = h // 2
    for i in range(n):
        tail = i == 0
        s = load(name, stage, "tail" if tail else "body")
        if flavours:
            band = tint(load(name, stage, "tail_band" if tail else "band"), FLAVOURS[(i + stage) % 8])
            s.alpha_composite(band)
        img.alpha_composite(s, (i * step, cy - s.height // 2 + (1 if stage == 3 else 0)))
    img.alpha_composite(head, (n * step - (head.width - seg.width) // 2, 0))
    return img


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def silhouette(img):
    a = img.split()[3].point(lambda v: 255 if v > 40 else 0)
    s = Image.new("RGBA", img.size, (12, 10, 14, 255))
    s.putalpha(a)
    return s


def on(img, bg, pad=8):
    c = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), bg + (255,))
    c.alpha_composite(img, (pad, pad))
    return c


def read_check():
    f_big, f = font(30), font(20)
    cols = []
    rows = []
    for name in ("gulp", "burp"):
        side = Image.open(os.path.join(REN, f"side_{name}.png")).convert("RGBA")
        side = side.resize((side.width * 200 // side.height, 200), Image.LANCZOS)
        sil = up(silhouette(worm(name, 1, flavours=False)), GAME_SCALE)
        lines = [[(side, "3D master, side (Blender)", "a round, shiny, friendly worm; face on the right"),
                  (on(sil, (210, 200, 180), 12), "stage 1 silhouette, game scale",
                   "head end obvious: big round head, tapered tail")]]
        for st in (1, 2, 3):
            px = worm(name, st)
            grown = {1: "a little worm with a face", 2: "grown a size, same worm",
                     3: ("a tiny bow on top" if name == "gulp" else "a little cap on top") + ", part of the head"}[st]
            lines.append([
                (on(px, DIRT, 4), f"stage {st}, 1x (real pixels)", "still a worm with a face, even this small"),
                (on(up(px, GAME_SCALE), DIRT, 12), f"stage {st}, game scale on dirt", grown),
                (on(up(px, GAME_SCALE), TOPSOIL, 12), f"stage {st}, game scale on topsoil",
                 "green body held apart from grass by the ink outline" if name == "gulp" else "red pops off the green"),
            ])
        rows.append((name, lines))
    # layout: per worm a block of cells in a wrapped grid, caption under each
    cell_w, gap = 620, 18
    blocks = []
    for name, lines in rows:
        heights = [max(c[0].height for c in ln) + 64 for ln in lines]
        blocks.append((name, lines, heights))
    H = sum(60 + sum(hs) + gap * len(hs) for _n, _l, hs in blocks) + 200
    W = cell_w * 3 + gap * 4
    out = Image.new("RGBA", (W, H), SHEET_BG + (255,))
    d = ImageDraw.Draw(out)
    d.text((gap, 18), "Gulp and Burp read check (stages 1 to 3). Caption: should read as ...", fill=TEXT, font=f_big)
    y = 70
    for name, lines, heights in blocks:
        d.text((gap, y), CAP[name], fill=TEXT, font=f_big)
        y += 50
        for ln, hgt in zip(lines, heights):
            for i, (img, label, should) in enumerate(ln):
                x = gap + i * (cell_w + gap)
                if img.width > cell_w:
                    img = img.resize((cell_w, img.height * cell_w // img.width), Image.NEAREST)
                out.alpha_composite(img, (x, y))
                ty = y + img.height + 4
                d.text((x, ty), label, fill=(190, 182, 170), font=f)
                d.text((x, ty + 24), "should read as: " + should, fill=TEXT, font=f)
            y += hgt + gap
    out = out.crop((0, 0, W, y + 10))
    return out


def lineup():
    pad, k = 24, GAME_SCALE
    worms = [(n, st) for st in (1, 2, 3) for n in ("gulp", "burp")]
    imgs = [up(worm(n, st), k) for n, st in worms]
    W = max(i.width for i in imgs) * 2 + pad * 3
    rowh = max(i.height for i in imgs) + pad
    out = Image.new("RGBA", (W * 2, rowh * 3 + pad), (0, 0, 0, 255))
    for half, bg in enumerate((DIRT, TOPSOIL)):
        out.paste(Image.new("RGBA", (W, out.height), bg + (255,)), (half * W, 0))
        for j, img in enumerate(imgs):
            col, row = j % 2, j // 2
            out.alpha_composite(img, (half * W + pad + col * (W - pad) // 2, pad + row * rowh))
    return out


def moods():
    k, gap = 6, 6
    rows = []
    for n in ("gulp", "burp"):
        for st in (1, 2, 3):
            head = load(n, st, "head")
            cells = []
            for m in MOODS:
                h = head.copy()
                h.alpha_composite(load(n, st, f"face_{m}"))
                cells.append(up(h, k))
            rows.append(cells)
    cw = 32 * k + gap
    out = Image.new("RGBA", (cw * len(MOODS) + gap, cw * len(rows) + 40), DIRT + (255,))
    d = ImageDraw.Draw(out)
    f = font(18)
    for i, m in enumerate(MOODS):
        d.text((gap + i * cw, 8), m, fill=TEXT, font=f)
    for j, cells in enumerate(rows):
        for i, c in enumerate(cells):
            out.alpha_composite(c, (gap + i * cw + (cw - c.width) // 2, 40 + j * cw + (cw - c.height) // 2))
    return out


os.makedirs(OUT, exist_ok=True)
read_check().save(os.path.join(OUT, "read_check.png"))
lineup().save(os.path.join(OUT, "lineup.png"))
moods().save(os.path.join(OUT, "moods.png"))
print("wrote", OUT)
