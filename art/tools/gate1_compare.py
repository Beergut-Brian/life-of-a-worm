"""Gate 1 compare sheet. Pastes proofs (NEAREST, integer scale) and lays out labels only."""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = "art/concepts/round1"
PR = ROOT + "/proofs"
FP = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def font(n):
    if os.path.exists(FP):
        return ImageFont.truetype(FP, n)
    return ImageFont.load_default(size=n)

BG = (0x14, 0x14, 0x18); FG = (230, 230, 235); DIM = (160, 160, 170)
RED = (230, 40, 40); AMBER = (245, 170, 20)
NAMES = {"a": "A Wet Earth", "b": "B Low Light", "mix": "B+A mix"}
pal = json.load(open(PR + "/palettes.json"))["palettes"]

def palette_strip(key):
    ents = pal[key]
    CW, CH = 90, 120
    rows = (len(ents) + 11) // 12
    W = 1280; H = 40 + rows * CH + 10
    im = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(im)
    d.text((8, 8), f"{NAMES[key]} palette (from the owner's images) - ΔE00 to P1 #3cc24a / P2 #e4393c; <10 fail, <20 flag",
           font=font(15), fill=FG)
    for i, e in enumerate(ents):
        x = 8 + (i % 12) * CW; y = 40 + (i // 12) * CH
        m = min(e["dE_P1"], e["dE_P2"])
        col = RED if m < 10 else AMBER if m < 20 else None
        if col:
            d.rectangle([x - 4, y - 4, x + 67, y + 67], fill=col)
        d.rectangle([x, y, x + 63, y + 63], fill=e["hex"])
        d.text((x, y + 70), e["hex"], font=font(12), fill=FG)
        d.text((x, y + 85), f"P1 ΔE {e['dE_P1']:.1f}", font=font(11), fill=DIM)
        d.text((x, y + 99), f"P2 ΔE {e['dE_P2']:.1f}", font=font(11), fill=DIM)
    rx = 8 + 12 * CW + 10
    for j, (nm, hx) in enumerate((("P1", "#3cc24a"), ("P2", "#e4393c"))):
        x = rx + j * 80
        d.rectangle([x, 40, x + 63, 103], fill=hx)
        d.text((x, 110), f"{nm} ref", font=font(12), fill=FG)
        d.text((x, 125), hx, font=font(11), fill=DIM)
    im.save(f"{PR}/{key}-palette.png")
    return im

def fit(im, maxw=1280):
    k = 1
    while im.width // k > maxw: k += 1
    return im if k == 1 else im.resize((im.width // k, im.height // k), Image.NEAREST)

def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)

SRC = {
    "a": ["a-wet-earth/P1-1", "a-wet-earth/P2-1"],
    "b": ["b-low-light/P5-1", "b-low-light/P6-1", "b-low-light/P6-2"],
    "mix": ["a-wet-earth/P1-1", "a-wet-earth/P2-1", "b-low-light/P5-1", "b-low-light/P6-2"],
}
TITLES = {"a": "A  Wet Earth", "b": "B  Low Light",
          "mix": "B+A mix  (B technique, palette, light; A cutaway + worm anatomy)"}

def column(key):
    items = []  # (image, caption)
    p = Image.open(f"{PR}/{key}-stage1-640x360.png").convert("RGB")
    items.append((up(p, 2), "stage 1 true canvas 640x360 (game shows it 3x)"))
    x0, y0 = 320 - 106, 179 - 60
    items.append((up(p.crop((x0, y0, x0 + 213, y0 + 120)), 6), "6x crop around the worm"))
    items.append((fit(Image.open(f"{PR}/{key}-worm-sheet.png").convert("RGB")),
                  "grey-box worm | proposal | P1 collar | P2 collar  (1x row, then 6x)"))
    items.append((fit(palette_strip(key)), "palette (dE00 to P1/P2; red border = fail <10, amber = flag <20)"))
    m = Image.open(f"{PR}/{key}-stage5-minify-0.5x.png").convert("RGB")
    row = Image.new("RGB", (320 + 20 + 640, 360), BG)
    row.paste(m, (0, 0)); row.paste(up(m, 2), (340, 0))
    items.append((row, "same art minified at 0.5x (stage 5 camera)"))
    th = []
    for s in SRC[key]:
        t = Image.open(f"{ROOT}/{s}.png").convert("RGB")
        th.append(t.resize((300, round(t.height * 300 / t.width)), Image.LANCZOS))
    per = 4
    nrows = (len(th) + per - 1) // per
    th_h = th[0].height
    tr = Image.new("RGB", (1280, nrows * (th_h + 8)), BG)
    for i, t in enumerate(th):
        tr.paste(t, ((i % per) * 310, (i // per) * (th_h + 8)))
    items.append((tr, "owner's Midjourney picks used"))
    return items

cols = [column(k) for k in ("a", "b", "mix")]
cf, tf, cap = font(22), font(26), font(15)
GUT = 24; BAN = 70; TIT = 44; CAPH = 26; SP = 14
heights = [TIT + sum(i.height + CAPH + SP for i, _ in c) for c in cols]
W = 3 * 1280 + 4 * GUT; H = BAN + max(heights) + GUT
sheet = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(sheet)
d.text((GUT, 20), "Life of a Worm - Gate 1 compare, round 1 (AD, 2026-11-12). All pixels from Kaden's picks + grey-box tunnels; nothing drawn in code.",
       font=font(24), fill=FG)
for ci, (c, k) in enumerate(zip(cols, ("a", "b", "mix"))):
    x = GUT + ci * (1280 + GUT); y = BAN
    d.text((x, y), TITLES[k], font=tf, fill=FG); y += TIT
    for im, cp in c:
        sheet.paste(im, (x, y)); y += im.height + 4
        d.text((x, y), cp, font=cap, fill=DIM); y += CAPH - 4 + SP
sheet.save(f"{ROOT}/compare.png")
print(sheet.size)
for k in ("a", "b", "mix"):
    for e in pal[k]:
        m = min(e["dE_P1"], e["dE_P2"])
        if m < 20: print(k, e["hex"], "FAIL" if m < 10 else "flag", m)
