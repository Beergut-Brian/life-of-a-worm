#!/usr/bin/env python3
"""Placeholder parts for the stages-traits slice (feature/stages-traits-1). Original, drawn in code.
Run from the repo root: python3 assets/proto/worm/make_slice_parts.py"""
from PIL import Image, ImageDraw
import os

OUT = os.path.dirname(os.path.abspath(__file__))
INK = (42, 26, 20, 255)
WHITE = (255, 255, 255, 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def disc(d, cx, cy, r, fill, outline=None):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline)


# Stage-2 feature: two springy feelers with round tips (sits on top of the head, faces +x).
img = new(16, 14); d = ImageDraw.Draw(img)
d.line([5, 13, 4, 6], fill=INK); d.line([4, 6, 6, 3], fill=INK)
d.line([9, 13, 10, 6], fill=INK); d.line([10, 6, 13, 3], fill=INK)
disc(d, 6, 2.5, 2.2, (255, 236, 120, 255), INK); disc(d, 13, 2.5, 2.2, (255, 236, 120, 255), INK)
d.point([(5, 2), (12, 2)], fill=WHITE)
img.save(os.path.join(OUT, "feature_feelers.png"))

# Float: a little white cloud puff riding above the head.
img = new(18, 12); d = ImageDraw.Draw(img)
for (cx, cy, r) in [(5, 7, 4), (9, 5, 5), (13, 7, 4)]:
    disc(d, cx, cy, r, (250, 252, 255, 255), INK)
for (cx, cy, r) in [(5, 7, 3), (9, 5, 4), (13, 7, 3)]:
    disc(d, cx, cy, r, (250, 252, 255, 255))
d.line([3, 10, 15, 10], fill=(200, 214, 240, 255))
img.save(os.path.join(OUT, "part_cloud.png"))

# Skater: a shiny blue blade under the tail with a curled toe.
img = new(18, 8); d = ImageDraw.Draw(img)
d.rectangle([3, 1, 13, 3], fill=(58, 134, 255, 255), outline=INK)
d.line([1, 6, 15, 6], fill=(220, 236, 255, 255), width=2)
d.arc([12, 1, 18, 7], -90, 90, fill=(220, 236, 255, 255))
d.line([5, 4, 5, 5], fill=INK); d.line([11, 4, 11, 5], fill=INK)
img.save(os.path.join(OUT, "part_skates.png"))

# Garden cart: a wooden tray on one wheel with a sprout sticking out (rides the back).
img = new(20, 16); d = ImageDraw.Draw(img)
d.polygon([(1, 5), (19, 5), (16, 11), (4, 11)], fill=(176, 116, 60, 255), outline=INK)
d.line([3, 7, 17, 7], fill=(132, 84, 40, 255))
disc(d, 10, 13, 2.6, (90, 90, 100, 255), INK)
d.line([9, 5, 8, 1], fill=(70, 160, 60, 255)); d.line([12, 5, 13, 2], fill=(70, 160, 60, 255))
disc(d, 8, 1.5, 1.4, (110, 200, 80, 255)); disc(d, 13, 2, 1.4, (110, 200, 80, 255))
img.save(os.path.join(OUT, "part_cart.png"))
