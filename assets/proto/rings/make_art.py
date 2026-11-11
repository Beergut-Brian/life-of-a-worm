#!/usr/bin/env python3
"""Placeholder pixel art for Life of a Worm's living rings (slice A). Original, drawn in code.
Run from the repo root: python3 assets/proto/rings/make_art.py"""
from PIL import Image, ImageDraw
import os

OUT = os.path.dirname(os.path.abspath(__file__))
INK = (42, 26, 20, 255)
LEAF = (111, 191, 74, 255)
LEAF_LIGHT = (160, 222, 110, 255)
STEM = (90, 140, 50, 255)

# Green thumb: a two-leaf sprout on the crown, 14x14.
img = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.line([(7, 13), (7, 6)], fill=INK, width=3)
d.line([(7, 13), (7, 6)], fill=STEM, width=1)
d.ellipse([0, 2, 7, 8], fill=INK)
d.ellipse([1, 3, 6, 7], fill=LEAF)
d.ellipse([7, 0, 13, 6], fill=INK)
d.ellipse([8, 1, 12, 5], fill=LEAF)
d.point([(2, 4), (9, 2)], fill=LEAF_LIGHT)
img.save(os.path.join(OUT, "part_leaf.png"))
