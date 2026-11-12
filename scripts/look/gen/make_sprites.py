"""Food and creature sprite sheets for the dirt and topsoil rings (look B with A's faces, D92).

    python3 scripts/look/gen/make_sprites.py      # from the repo root

Every sheet is 4 columns x 2 rows of equal cells:
  columns: 0 calm, 1 blink, 2 wide-eyed (a bigger worm is near / being carried), 3 smug (a threat)
  rows:    0 and 1 are the two frames of the idle / walk / flap loop
Bodies are drawn at the data's own radius (data/foods|creatures/<id>.tres), so a sprite is the size
the game already collides with, at 1 texel per world pixel. Ink outline 1 px, lit from the top left.
"""
import math
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pix import Canvas, hexc, mix, scale  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
INK = hexc("#140c12")
WHITE = hexc("#fbf7ef")
CALM, BLINK, WIDE, SMUG = range(4)


def tres(path):
    out = {}
    with open(os.path.join(ROOT, path)) as f:
        for line in f:
            m = re.match(r"(\w+) = (.*)", line.strip())
            if not m:
                continue
            k, v = m.groups()
            c = re.match(r"Color\(([\d.]+), ([\d.]+), ([\d.]+)", v)
            if c:
                out[k] = tuple(int(round(float(x) * 255)) for x in c.groups())
            elif re.match(r"^-?[\d.]+$", v):
                out[k] = float(v)
            else:
                out[k] = v.strip('"&')
    return out


def eyes(cv, cx, cy, spread, mood, big=False, look=1):
    """A-style faces. big: creature-size eyes. look: pupil side (+1 right)."""
    for sx in (-1, 1):
        ex = cx + sx * spread
        if not big:
            if mood == BLINK:
                cv.put(ex - 1, cy, INK)
                cv.put(ex, cy, INK)
            elif mood == WIDE:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        cv.put(ex + dx - 0.5 + 0.5, cy + dy, WHITE)
                cv.put(ex, cy, INK)
            elif mood == SMUG:
                cv.put(ex - 1, cy, INK)
                cv.put(ex, cy, INK)
                cv.put(ex - 1, cy + 1, WHITE)
                cv.put(ex, cy + 1, INK if look > 0 else WHITE)
                if look <= 0:
                    cv.put(ex - 1, cy + 1, INK)
            else:
                cv.put(ex - 1, cy, WHITE)
                cv.put(ex - 1, cy + 1, WHITE)
                cv.put(ex, cy, INK)
                cv.put(ex, cy + 1, INK)
        else:
            if mood == BLINK:
                for dx in range(-2, 2):
                    cv.put(ex + dx, cy + 1, INK)
            elif mood == WIDE:
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        if abs(dx) + abs(dy) < 4:
                            cv.put(ex + dx, cy + dy, WHITE)
                cv.put(ex, cy, INK)
                cv.put(ex, cy + 1, INK)
            elif mood == SMUG:
                for dx in range(-2, 2):
                    cv.put(ex + dx, cy, INK)  # heavy lid
                    cv.put(ex + dx, cy + 1, WHITE)
                cv.put(ex + (0 if look > 0 else -2), cy + 1, INK)
                cv.put(ex + (1 if look > 0 else -1), cy + 1, INK)
                cv.put(ex - 2 * sx, cy - 1 - (1 if sx < 0 else 0), INK)  # cocky brow
            else:
                for dy in range(-1, 2):
                    for dx in range(-2, 2):
                        cv.put(ex + dx, cy + dy, WHITE)
                cv.put(ex, cy, INK)
                cv.put(ex, cy + 1, INK)
                cv.put(ex - 1, cy + 1, INK)


def mouth(cv, cx, cy, mood, big=False):
    if mood == WIDE:
        cv.put(cx, cy, INK)
        cv.put(cx - 1, cy, INK)
        if big:
            cv.put(cx, cy + 1, INK)
            cv.put(cx - 1, cy + 1, INK)
            cv.put(cx - 1, cy - 1 , hexc("#7a2030"))
    elif mood == SMUG:
        cv.put(cx - 1, cy, INK)
        cv.put(cx, cy, INK)
        cv.put(cx + 1, cy - 1, INK)
        if big:
            cv.put(cx - 2, cy, INK)
            cv.put(cx + 2, cy - 2, INK)
    elif big:
        cv.put(cx - 1, cy, INK)
        cv.put(cx, cy, INK)


def sheet(name, folder, w, h, draw):
    img = Image.new("RGBA", (w * 4, h * 2), (0, 0, 0, 0))
    for row in range(2):
        for mood in range(4):
            cv = Canvas(w, h)
            draw(cv, mood, row)
            cv.outline(INK)
            cv.paste_into(img, mood * w, row * h)
    out = os.path.join(ROOT, "assets", "sprites", folder)
    os.makedirs(out, exist_ok=True)
    img.save(os.path.join(out, name + ".png"))
    return img


def cell_for(r, pad=4):
    n = int(math.ceil(r * 2 + pad))
    return n + (n % 2)


# --- foods -----------------------------------------------------------------------------------------

def food(id_):
    d = tres("data/foods/%s.tres" % id_)
    return d, d.get("radius", 5.0), d.get("color", (200, 200, 200)), d.get("accent", (255, 255, 255))


def make_seed():
    d, r, col, acc = food("seed")
    n = cell_for(r)

    def draw(cv, mood, row):
        c = n / 2
        sq = 1 if row else 0
        cv.blob(c, c + sq * 0.5, r * 0.8 + sq * 0.4, r - sq * 0.5, col, rot=0.35)
        cv.line(c - 1, c - r + 2, c + 1, c + r - 2, acc)
        cv.put(c + 1, c - r + 1, scale(col, 0.7))
        eyes(cv, c, c, 1.5, mood)
        mouth(cv, c, c + 2, mood)
    sheet("seed", "food", n, n, draw)


def make_root():
    d, r, col, acc = food("root")
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        sway = 1 if row else 0
        cv.poly([(c - r * 0.9, c - r * 0.5), (c + r * 0.9, c - r * 0.5), (c + sway, c + r + 1.5)], col)
        cv.blob(c, c - r * 0.45, r * 0.9, r * 0.45, col)
        for i in (-1, 1):
            cv.put(c + i * 2 + sway, c + r * 0.6, acc)
        cv.put(c - 1, c - r - 1, hexc("#5aa83a"))
        cv.put(c, c - r - 1 - sway, hexc("#8fd860"))
        cv.put(c + 1, c - r - 1, hexc("#5aa83a"))
        eyes(cv, c, c - 1, 1.5, mood)
        mouth(cv, c, c + 1, mood)
    sheet("root", "food", n, n, draw)


def make_mushroom():
    d, r, col, acc = food("mushroom")
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        sq = 1 if row else 0
        stem = acc if acc != (255, 255, 255) else hexc("#efe2c8")
        cv.poly([(c - r * 0.45, c - 1), (c + r * 0.45, c - 1), (c + r * 0.55, c + r), (c - r * 0.55, c + r)], stem)
        cv.blob(c, c - r * 0.35 + sq, r + sq * 0.5, r * 0.65 - sq * 0.3, col)
        for (dx, dy) in [(-r * 0.5, -r * 0.55), (r * 0.35, -r * 0.7), (r * 0.7, -r * 0.2)]:
            cv.put(c + dx, c + dy + sq, WHITE)
        eyes(cv, c, c + r * 0.25, 1.5, mood)
        mouth(cv, c, c + r * 0.25 + 2, mood)
    sheet("mushroom", "food", n, n, draw)


def make_crumb():
    d, r, col, acc = food("crumb")
    n = cell_for(r)

    def draw(cv, mood, row):
        c = n / 2
        s = r * 0.95
        sq = 0.5 if row else 0
        crust = acc if acc != (255, 255, 255) else scale(col, 0.7)
        cv.poly([(c - s, c - s + 1 + sq), (c - s + 1, c - s + sq), (c + s, c - s + 1 + sq), (c + s - 1, c + s), (c - s, c + s)], crust)
        cv.poly([(c - s + 1, c - s + 2 + sq), (c + s - 1, c - s + 2 + sq), (c + s - 1, c + s - 1), (c - s + 1, c + s - 1)], col)
        cv.put(c + 2, c + 2, scale(col, 0.8))
        cv.put(c - 2, c - 1, scale(col, 0.8))
        eyes(cv, c, c, 1.5, mood)
        mouth(cv, c, c + 2, mood)
    sheet("crumb", "food", n, n, draw)


def glossy(id_, shape="drop"):
    d, r, col, acc = food(id_)
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        sq = 0.5 if row else 0
        if shape == "drop":
            cv.poly([(c, c - r - 1.5 + sq), (c + r * 0.7, c - r * 0.1), (c - r * 0.7, c - r * 0.1)], col)
        cv.blob(c, c + r * 0.2 + sq * 0.5, r * 0.9 + sq * 0.3, r * 0.85 - sq * 0.3, col)
        cv.put(c - r * 0.45, c - r * 0.15, WHITE)
        cv.put(c - r * 0.45, c + r * 0.05, mix(WHITE, col, 0.4))
        eyes(cv, c, c + r * 0.25, 1.5, mood)
        mouth(cv, c, c + r * 0.25 + 2, mood)
    sheet(id_, "food", n, n, draw)


def make_egg():
    d, r, col, acc = food("bug_egg")
    n = cell_for(r)

    def draw(cv, mood, row):
        c = n / 2
        wob = 0.4 if row else 0
        cv.blob(c, c, r * 0.8, r + 0.5, col, rot=wob)
        cv.put(c + 2, c - 3, scale(col, 0.75))
        cv.put(c - 2, c + 3, scale(col, 0.75))
        eyes(cv, c, c, 1.5, mood)
        mouth(cv, c, c + 2, mood)
    sheet("bug_egg", "food", n, n, draw)


def rock(id_, big=False):
    d, r, col, acc = food(id_)
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        sq = 0.5 if row else 0
        cv.blob(c, c + sq, r + sq, r * 0.85 - sq, col, rot=0.2)
        if big:
            cv.line(c + r * 0.3, c - r * 0.7, c + r * 0.55, c - r * 0.2, scale(col, 0.6))
            cv.line(c - r * 0.75, c + r * 0.2, c - r * 0.45, c + r * 0.45, scale(col, 0.6))
            cv.blob(c - r * 0.3, c - r * 0.65, r * 0.35, r * 0.15, hexc("#5b7e45"), shade=False)
            eyes(cv, c, c - r * 0.05, r * 0.38, mood, big=True)
            mouth(cv, c, c + r * 0.4, mood, big=True)
        else:
            cv.put(c + 2, c - 1, scale(col, 0.7))
            eyes(cv, c, c, 1.5, mood)
            mouth(cv, c, c + 2, mood)
    sheet(id_, "food", n, n, draw)


def make_crystal():
    d, r, col, acc = food("crystal")
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        up = 0.5 if row else 0
        top = c - r - 1.5 - up
        cv.poly([(c, top), (c + r * 0.8, c - r * 0.3), (c + r * 0.6, c + r), (c - r * 0.6, c + r), (c - r * 0.8, c - r * 0.3)], col)
        cv.poly([(c, top), (c + r * 0.8, c - r * 0.3), (c + r * 0.6, c + r), (c + 0.5, c + r)], scale(col, 0.75))
        cv.line(c - r * 0.4, c - r * 0.4, c - r * 0.2, top + 2, WHITE)
        eyes(cv, c, c + 0.5, 1.5, mood)
        mouth(cv, c, c + 2.5, mood)
    sheet("crystal", "food", n, n, draw)


def make_cap():
    d, r, col, acc = food("bottle_cap")
    n = cell_for(r, 6)

    def draw(cv, mood, row):
        c = n / 2
        for i in range(16):
            a = i / 16 * math.tau + (0.2 if row else 0)
            if i % 2 == 0:
                cv.put(c + math.cos(a) * (r + 0.6), c + math.sin(a) * (r + 0.6), scale(col, 0.8))
        cv.blob(c, c, r, r, col)
        cv.blob(c, c, r * 0.6, r * 0.6, acc if acc != (255, 255, 255) else scale(col, 1.3), shade=False)
        eyes(cv, c, c, 1.5, mood)
        mouth(cv, c, c + 2, mood)
    sheet("bottle_cap", "food", n, n, draw)


# --- creatures --------------------------------------------------------------------------------------

def creature(id_):
    d = tres("data/creatures/%s.tres" % id_)
    return d, d.get("radius", 8.0), d.get("color", (200, 200, 200)), d.get("accent", (255, 255, 255))


def grub_draw(r, col, head):
    def draw(cv, mood, row):
        n = cv.w
        c = n / 2
        wig = 1 if row else 0
        for i, (dx, dy) in enumerate([(-r * 0.75, r * 0.15), (-r * 0.15, wig * 0.5), (r * 0.4, -r * 0.05)]):
            cv.blob(c + dx, c + dy, r * 0.62, r * (0.68 - abs(i - 1) * 0.08), col)
        for dx in (-r * 0.45, r * 0.1):
            cv.line(c + dx, c - r * 0.45, c + dx, c + r * 0.35, scale(col, 0.78))
        cv.blob(c + r * 0.85, c - r * 0.2 - wig * 0.5, r * 0.42, r * 0.42, head)
        eyes(cv, c + r * 0.85, c - r * 0.3 - wig * 0.5, 1, mood)
        mouth(cv, c + r * 1.0, c + r * 0.15, mood)
    return draw


def make_grub():
    d, r, col, acc = creature("grub")
    n = cell_for(r, 8)
    head = hexc("#a8623a")
    sheet("grub", "creatures", n, n, grub_draw(r, col, head))
    fd, fr, fcol, facc = food("grub")
    sheet("grub", "food", cell_for(fr, 8), cell_for(fr, 8), grub_draw(fr, fcol, head))


def make_ant():
    d, r, col, acc = creature("ant")
    n = cell_for(r, 8)

    def draw(cv, mood, row):
        c = n / 2
        step = 1 if row else -1
        for i, lx in enumerate((-r * 0.5, 0, r * 0.45)):
            s = step if i % 2 else -step
            cv.line(c + lx, c + 1, c + lx + s, c + r * 0.9, INK)
        cv.blob(c - r * 0.75, c, r * 0.55, r * 0.48, col)
        cv.blob(c, c - 0.5, r * 0.35, r * 0.32, col)
        cv.blob(c + r * 0.7, c - r * 0.25, r * 0.45, r * 0.42, col)
        cv.line(c + r * 0.8, c - r * 0.6, c + r * 1.25, c - r * 1.1 - (0.5 if row else 0), INK)
        eyes(cv, c + r * 0.8, c - r * 0.35, 1, mood)
    sheet("ant", "creatures", n, n, draw)


def beetle_draw(r, shell, accent, wide_shell=None):
    def draw(cv, mood, row):
        n = cv.w
        c = n / 2
        sh = wide_shell if (mood == WIDE and wide_shell) else shell
        step = 1.5 if row else -1.5
        for i in range(3):
            x = c + (i - 1) * r * 0.6
            s = step if i % 2 else -step
            cv.line(x, c + r * 0.5, x + s, c + r * 1.0, INK)
        cv.blob(c - r * 0.15, c, r * 0.95, r * 0.8, sh)
        cv.line(c - r * 0.15, c - r * 0.75, c - r * 0.15, c + r * 0.75, scale(sh, 0.55))
        cv.blob(c - r * 0.5, c - r * 0.4, r * 0.22, r * 0.14, accent, shade=False)
        hx = c + r * 0.75
        cv.blob(hx, c + r * 0.05, r * 0.45, r * 0.42, scale(sh, 0.7))
        cv.line(hx + r * 0.3, c - r * 0.15, hx + r * 0.65, c - r * 0.4, INK)
        cv.line(hx + r * 0.3, c + r * 0.3, hx + r * 0.65, c + r * 0.5, INK)
        cv.line(hx, c - r * 0.35, hx + r * 0.3, c - r * 0.85 - (1 if row else 0), INK)
        eyes(cv, hx + 1, c - r * 0.02, r * 0.2, mood, big=True)
        mouth(cv, hx + 1, c + r * 0.3, mood)
    return draw


def make_beetle():
    d, r, col, acc = creature("beetle")
    n = cell_for(r * 1.25, 8)
    sheet("beetle", "creatures", n, n, beetle_draw(r, col, acc))
    # The dirt ring's apex beetle (scripts/planet/apex_beetle.gd, radius 15): purple and smug while
    # it is a threat; the wide-eyed column is pale, its "you can eat me now" colour.
    ra = 15.0
    na = cell_for(ra * 1.25, 8)
    sheet("apex_beetle", "creatures", na, na, beetle_draw(ra, hexc("#3b2d63"), hexc("#8a78d8"), hexc("#c9b8ff")))


def make_bird():
    d, r, col, acc = creature("bird")
    w, h = cell_for(r * 3.4, 4), cell_for(r * 2.0, 6)

    def draw(cv, mood, row):
        cx, cy = w / 2, h / 2 + 2
        flap = -r * 0.8 if row == 0 else r * 0.35
        for sx in (-1, 1):
            cv.poly([(cx + sx * r * 0.3, cy - r * 0.2), (cx + sx * r * 1.6, cy - r * 0.2 + flap),
                     (cx + sx * r * 1.2, cy + r * 0.1 + flap * 0.5), (cx + sx * r * 0.4, cy + r * 0.3)], acc)
        cv.blob(cx, cy, r * 0.75, r * 0.6, col)
        cv.blob(cx + r * 0.55, cy - r * 0.55, r * 0.42, r * 0.4, col)
        beak = hexc("#f2b544")
        cv.poly([(cx + r * 0.9, cy - r * 0.6), (cx + r * 1.4, cy - r * 0.4), (cx + r * 0.9, cy - r * 0.3)], beak)
        cv.blob(cx - r * 0.1, cy + r * 0.15, r * 0.4, r * 0.25, mix(col, WHITE, 0.45), shade=False)
        eyes(cv, cx + r * 0.6, cy - r * 0.62, 1.5, mood)
    sheet("bird", "creatures", w, h, draw)


def make_boot():
    d, r, col, acc = creature("boot")
    w, h = cell_for(r * 2.2, 4), cell_for(r * 1.1, 4)

    def draw(cv, mood, row):
        c = w / 2
        rub = hexc("#3a3a40")
        cv.poly([(c - r, h - 12), (c + r * 0.9, h - 12), (c + r, h - 6), (c - r, h - 6)], rub)
        cv.poly([(c - r * 0.95, 4), (c - r * 0.2, 4), (c - r * 0.1, h - 18), (c + r * 0.85, h - 22),
                 (c + r * 0.95, h - 12), (c - r * 0.95, h - 12)], col)
        for i in range(5):
            cv.put(c - r * 0.6 + i * 3, h - 9, hexc("#55555c"))
        eyes(cv, c - r * 0.45, h * 0.35, 6, mood, big=True, look=-1)
        mouth(cv, c - r * 0.45, h * 0.35 + 7, SMUG if mood == SMUG else CALM, big=True)
    sheet("boot", "creatures", w, h, draw)


def main():
    make_seed()
    make_root()
    make_mushroom()
    make_crumb()
    glossy("honeydew")
    glossy("droplet")
    make_egg()
    rock("pebble")
    rock("boulder", big=True)
    rock("big_boulder", big=True)
    make_crystal()
    make_cap()
    make_grub()
    make_ant()
    make_beetle()
    make_bird()
    make_boot()
    print("sprites written")


if __name__ == "__main__":
    main()
