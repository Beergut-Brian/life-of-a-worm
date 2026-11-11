"""Swatch cards (Pillow) and the A/B/C compare sheet from the Godot frames.

    python3 art/tools/make_sheets.py

Needs the Godot frames from art/tools/render_all.sh in art/direction/<option>/{xs,planet,dock}.png.
Writes art/direction/<option>/swatch.png and art/direction/compare.png.
"""
import os
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from worm_looks import LOOKS, P1, P2, RINGS, rgb, de2000, dominant  # noqa: E402

DIR = os.path.join(HERE, "..", "direction")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(sz, bold=False):
    try:
        return ImageFont.truetype(BOLD if bold else FONT, sz)
    except OSError:
        return ImageFont.load_default()


def lum(c):
    r, g, b = rgb(c)
    return 0.299 * r + 0.587 * g + 0.114 * b


def chip(d, x, y, c, w=118, h=58, label=None):
    d.rectangle([x, y, x + w, y + h], fill=c, outline="#000000")
    d.text((x + 6, y + h - 18), label or c, fill="#000000" if lum(c) > 120 else "#ffffff", font=font(13))


def worm_dot(d, x, y, c, eyes):
    d.ellipse([x, y, x + 30, y + 30], fill=c, outline="#160f1e", width=2)
    if eyes == 1:
        d.ellipse([x + 9, y + 6, x + 23, y + 20], fill="#ffffff")
        d.ellipse([x + 15, y + 10, x + 21, y + 16], fill="#160f1e")
    else:
        for ex in (x + 6, x + 16):
            d.ellipse([ex, y + 8, ex + 8, y + 16], fill="#ffffff")
            d.ellipse([ex + 2, y + 10, ex + 6, y + 14], fill="#160f1e")


def swatch(key):
    look = LOOKS[key]
    W, H = 1500, 1060
    im = Image.new("RGB", (W, H), "#f4f1ea")
    d = ImageDraw.Draw(im)
    d.text((30, 22), look["name"], fill="#160f1e", font=font(38, True))
    for i, line in enumerate(textwrap.wrap(look["blurb"], 120)):
        d.text((32, 74 + i * 22), line, fill="#333333", font=font(17))
    y = 150
    d.text((30, y), "ring", font=font(16, True), fill="#000")
    for i, h in enumerate(["deep", "low", "mid (dom.)", "high", "wall", "wall dark"]):
        d.text((150 + i * 128, y), h, font=font(15, True), fill="#000")
    d.text((940, y), "worms on the dominant hue  (ΔE00 P1 / P2)", font=font(15, True), fill="#000")
    y += 26
    rows = [("sky", look["sky"]), ("topsoil", look["rings"]["topsoil"]), ("dirt", look["rings"]["dirt"]),
            ("rock", look["rings"]["rock"]), ("core", look["rings"]["core"]), ("space", look["space"])]
    for name, cols in rows:
        d.text((30, y + 18), name, font=font(20, True), fill="#160f1e")
        for i, c in enumerate(cols):
            chip(d, 150 + i * 128, y, c)
        dom = dominant(look, name)
        d.rectangle([940, y, 1130, y + 58], fill=dom, outline="#000")
        worm_dot(d, 958, y + 14, P1, 1)
        worm_dot(d, 1000, y + 14, P2, 2)
        d.text((1045, y + 20), "%.0f / %.0f" % (de2000(P1, dom), de2000(P2, dom)),
               fill="#000" if lum(dom) > 120 else "#fff", font=font(17, True))
        y += 70
    y += 10
    d.text((30, y), "grass", font=font(20, True), fill="#160f1e")
    for i, c in enumerate(look["grass"]):
        chip(d, 150 + i * 128, y, c)
    y += 80
    d.text((30, y + 18), "ink + UI", font=font(20, True), fill="#160f1e")
    chip(d, 150, y, look["outline"], label="outline " + look["outline"])
    chip(d, 278, y, look["char_outline"], label="char " + look["char_outline"])
    chip(d, 406, y, look["ui_accent"], label="UI " + look["ui_accent"])
    chip(d, 534, y, P1, label="P1 " + P1)
    chip(d, 662, y, P2, label="P2 " + P2)
    y += 80
    d.text((30, y + 18), "lights", font=font(20, True), fill="#160f1e")
    for i, (k, c) in enumerate(look["lights"].items()):
        chip(d, 150 + i * 128, y, c, label="%s %s" % (k, c))
    st = look["style"]
    notes = ["tile shades used: %d" % st["tile_shades"], "terrain outline: %d px" % st["terrain_outline"],
             "dither: %s" % ("ordered 4x4 Bayer" if st["dither"] else "none"),
             "normal maps + 2D lights: %s" % ("yes" if st["normals"] else "no"),
             "paper grain overlay: %s" % ("yes" if st["paper"] else "no")]
    for i, n in enumerate(notes):
        d.text((830, y - 70 + i * 24), n, font=font(16), fill="#333")
    # a strip of the actual frame for context
    xs = Image.open(os.path.join(DIR, look["slug"], "xs.png")).convert("RGB")
    im.paste(xs.crop((0, 300, 1920, 1080)).resize((1440, 585)).crop((0, 100, 1440, 250)), (30, H - 170))
    im.save(os.path.join(DIR, look["slug"], "swatch.png"))


def label(im, txt, sub):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 64 + len(sub) * 10, 52], fill="#160f1e")
    d.text((12, 4), txt, fill="#ffd23a", font=font(40, True))
    d.text((52, 16), sub, fill="#ffffff", font=font(19))


def compare():
    sheet = Image.new("RGB", (1920, 1080), "#160f1e")
    cells = [(0, 0), (960, 0), (0, 540)]
    for (x, y), (k, look) in zip(cells, LOOKS.items()):
        im = Image.open(os.path.join(DIR, look["slug"], "xs.png")).convert("RGB").resize((958, 538), Image.LANCZOS)
        label(im, k.upper(), look["name"][3:])
        sheet.paste(im, (x + 1, y + 1))
    for i, (k, look) in enumerate(LOOKS.items()):
        im = Image.open(os.path.join(DIR, look["slug"], "planet.png")).convert("RGB")
        im = im.crop((960 - 330, 540 - 330, 960 + 330, 540 + 330)).resize((318, 318), Image.LANCZOS)
        cell = Image.new("RGB", (318, 538), "#0b0b18")
        cell.paste(im, (0, 0))
        dk = Image.open(os.path.join(DIR, look["slug"], "dock.png")).convert("RGB").resize((318, 179), Image.LANCZOS)
        cell.paste(dk, (0, 348))
        d = ImageDraw.Draw(cell)
        d.rectangle([0, 0, 44, 46], fill="#160f1e")
        d.text((8, 2), k.upper(), fill="#ffd23a", font=font(36, True))
        d.text((52, 12), "planet + dock", fill="#cccccc", font=font(16))
        sheet.paste(cell.crop((0, 0, 318, 538)), (960 + 1 + i * 320, 541))
    sheet.save(os.path.join(DIR, "compare.png"))


if __name__ == "__main__":
    for k in LOOKS:
        swatch(k)
    compare()
    print("ok")
