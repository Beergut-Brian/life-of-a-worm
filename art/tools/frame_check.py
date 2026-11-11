"""Measured ΔE00 on the rendered Godot cross-section frames (after lighting, modulate, dither).

    python3 art/tools/frame_check.py
Samples a worm body segment and the tunnel wall / solid ground right next to it (screen px,
frame at zoom 2). Positions follow art/tools/make_frames.py (P1 head 33 tiles, P2 head 31 tiles).
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from worm_looks import LOOKS, de2000, hexs  # noqa: E402

# (label, body sample, [(what, sample), ...]) in 1920x1080 screen pixels
PROBES = [
    ("P1 in dirt", (1002, 506), [("tunnel wall", (1002, 472)), ("dirt", (1002, 585))]),
    ("P2 in rock", (1046, 806), [("tunnel wall", (1046, 772)), ("rock", (1046, 880))]),
]


def mean(im, xy, r=3):
    px = [im.getpixel((xy[0] + dx, xy[1] + dy)) for dx in range(-r, r + 1) for dy in range(-r, r + 1)]
    return tuple(sum(p[i] for p in px) / len(px) for i in range(3))


rows = ["| Option | Worm | body (frame) | against | colour | ΔE00 |", "| --- | --- | --- | --- | --- | --- |"]
for k, look in LOOKS.items():
    im = Image.open(os.path.join(HERE, "..", "direction", look["slug"], "xs.png")).convert("RGB")
    for lab, body, bgs in PROBES:
        b = mean(im, body, 2)
        for what, xy in bgs:
            c = mean(im, xy)
            rows.append(f"| {k.upper()} | {lab} | `{hexs(b)}` | {what} | `{hexs(c)}` | {de2000(b, c):.1f} |")
print("\n".join(rows))
