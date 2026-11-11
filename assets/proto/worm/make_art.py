#!/usr/bin/env python3
"""Placeholder pixel art for the Life of a Worm trait prototype (R-c). Original, drawn in code.
Run from the repo root: python3 assets/proto/worm/make_art.py
Tinted sprites (segment, band, head) are drawn near-white so `modulate` gives the colour."""
from PIL import Image, ImageDraw
import math, os

OUT = os.path.dirname(os.path.abspath(__file__))
INK = (42, 26, 20, 255)
WHITE = (255, 255, 255, 255)
LIGHT = (236, 236, 236, 255)
SHADE = (196, 196, 196, 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, name):
    img.save(os.path.join(OUT, name))


def disc(d, cx, cy, r, fill, outline=None):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline)


# Segment: 16x16 round body, dark outline, lighter belly stripe at the bottom.
img = new(16, 16); d = ImageDraw.Draw(img)
disc(d, 7.5, 7.5, 7, SHADE, INK)
d.ellipse([2, 2, 13, 11], fill=LIGHT)
d.line([4, 11, 11, 11], fill=WHITE)
d.line([5, 12, 10, 12], fill=WHITE)
d.point([(5, 4), (6, 4), (4, 5)], fill=WHITE)
save(img, "segment.png")

# Flavour band: a vertical stripe across the segment (the body runs along x), no outline.
img = new(16, 16); d = ImageDraw.Draw(img)
for y in range(16):
    for x in range(16):
        if (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 6.2 ** 2 and 5 <= x <= 10:
            img.putpixel((x, y), WHITE if x not in (5, 10) else LIGHT)
save(img, "band.png")

# Head: 20x20, a touch bigger than a segment, facing +x.
img = new(20, 20); d = ImageDraw.Draw(img)
disc(d, 9.5, 9.5, 9, SHADE, INK)
d.ellipse([2, 2, 16, 13], fill=LIGHT)
d.point([(6, 4), (7, 4), (5, 5)], fill=WHITE)
save(img, "head.png")

# Faces (untinted): eyes + mouth at three openings. P1 one big eye with a lid, P2 two small eyes.
def face(player, open_amt):
    img = new(20, 20); d = ImageDraw.Draw(img)
    if player == 1:
        disc(d, 10, 6, 3.5, WHITE, INK)
        d.rectangle([10, 5, 12, 7], fill=INK)
        d.line([7, 3, 13, 3], fill=INK)  # lid
    else:
        disc(d, 9, 5, 2.2, WHITE, INK)
        disc(d, 13, 6, 2.2, WHITE, INK)
        d.point([(10, 5), (12, 6)], fill=INK)  # a little cross-eyed
    if open_amt == 0:
        d.line([13, 13, 18, 12], fill=INK)
        d.point([(12, 12)], fill=INK)
    else:
        h = 2 if open_amt == 1 else 5
        d.polygon([(11, 12), (19, 12 - h), (19, 12 + h)], fill=(120, 20, 36, 255), outline=INK)
        if open_amt == 2:
            d.line([15, 13, 17, 13], fill=(255, 130, 160, 255))  # tongue
            d.point([(18, 8), (18, 16)], fill=WHITE)  # teeth
    return img

for p in (1, 2):
    for o in range(3):
        save(face(p, o), f"face_p{p}_{o}.png")

# Trait parts (untinted, original shapes). One stage each for the prototype.
# Back fin (Wriggle): small orange-yellow fin sticking up.
img = new(12, 10); d = ImageDraw.Draw(img)
d.polygon([(1, 9), (5, 1), (7, 2), (10, 9)], fill=(255, 196, 40, 255), outline=INK)
d.line([5, 3, 4, 8], fill=(255, 120, 30, 255)); d.line([7, 4, 7, 8], fill=(255, 120, 30, 255))
save(img, "part_fin.png")

# Stone helmet: grey rock cap over the head's top-front.
img = new(22, 22); d = ImageDraw.Draw(img)
d.pieslice([1, 1, 21, 21], 180, 360, fill=(138, 144, 156, 255), outline=INK)
d.rectangle([1, 10, 21, 12], fill=(110, 116, 128, 255), outline=INK)
for (x, y) in [(6, 5), (12, 4), (16, 7), (9, 8)]:
    d.point([(x, y), (x + 1, y)], fill=(90, 94, 104, 255))
d.point([(5, 3), (6, 3)], fill=(200, 206, 214, 255))
save(img, "part_stone_helmet.png")

# Drill: cone pointing +x with spiral bands.
img = new(18, 16); d = ImageDraw.Draw(img)
d.polygon([(0, 1), (17, 8), (0, 14)], fill=(214, 168, 64, 255), outline=INK)
for x in (4, 8, 12):
    d.line([x, 2 + x // 3, x + 2, 13 - x // 3], fill=(150, 104, 30, 255))
d.rectangle([0, 1, 2, 14], fill=(160, 166, 178, 255), outline=INK)
save(img, "part_drill.png")

# Glow bulb: antenna stalk + bright bulb.
img = new(12, 14); d = ImageDraw.Draw(img)
d.line([3, 13, 6, 6], fill=INK, width=1)
disc(d, 7, 4, 3.5, (140, 255, 236, 255), INK)
d.point([(6, 3)], fill=WHITE)
save(img, "part_glow_bulb.png")

# Magnet: red horseshoe with silver tips, opening to -x (it rides the tail).
img = new(14, 14); d = ImageDraw.Draw(img)
d.arc([2, 2, 12, 12], -90, 90, fill=(220, 40, 50, 255), width=3)
d.rectangle([2, 2, 7, 4], fill=(220, 40, 50, 255)); d.rectangle([2, 10, 7, 12], fill=(220, 40, 50, 255))
d.rectangle([0, 2, 2, 4], fill=(220, 224, 232, 255)); d.rectangle([0, 10, 2, 12], fill=(220, 224, 232, 255))
d.arc([1, 1, 13, 13], -90, 90, fill=INK)
save(img, "part_magnet.png")

# Slick sheen: a translucent highlight crescent laid over each segment.
img = new(16, 16)
for y in range(16):
    for x in range(16):
        r = math.hypot(x - 7.5, y - 7.5)
        if 3.5 <= r <= 6.0 and x < 9 and y < 8:
            img.putpixel((x, y), (255, 255, 255, 190))
        elif r < 6.4 and (x + y) % 7 == 0:
            img.putpixel((x, y), (170, 230, 255, 150))
save(img, "part_sheen.png")

# Small FX.
img = new(9, 8); d = ImageDraw.Draw(img)
d.polygon([(4, 7), (0, 3), (0, 1), (2, 0), (4, 2), (6, 0), (8, 1), (8, 3)], fill=(255, 92, 140, 255), outline=INK)
save(img, "heart.png")
img = new(8, 10); d = ImageDraw.Draw(img)
d.line([5, 1, 5, 7], fill=INK); d.line([5, 1, 7, 3], fill=INK); disc(d, 3, 7, 2, INK)
save(img, "note.png")
img = new(7, 7); d = ImageDraw.Draw(img)
d.polygon([(3, 0), (4, 2), (6, 3), (4, 4), (3, 6), (2, 4), (0, 3), (2, 2)], fill=(255, 230, 80, 255), outline=INK)
save(img, "star.png")
print("ok", sorted(f for f in os.listdir(OUT) if f.endswith(".png")))
