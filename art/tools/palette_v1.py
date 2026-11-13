"""Life of a Worm style bible v1.0 master palette (AD, 2026-11-12).

    python3 art/tools/palette_v1.py   # writes art/palette/worm-v1.{json,gpl,hex} + worm-v1-swatches.png

Every hex is sampled from Kaden's round-1 picks (P1, P5, P6) or the Gate-1 B+A mix palette, except
the worm flesh shift (A-001 condition: ΔE00 >= 20 from P2 red) and the ramps' in-between steps.
Prints ΔE00 to P1 green / P2 red; a non-slot colour under 20 is a FAIL.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from worm_looks import de2000  # noqa: E402

P1, P2 = "#3cc24a", "#e4393c"
# (group, name, hexes dark->light, source)
RAMPS = [
    ("shared", "void", ["#020000", "#010d17", "#19100b", "#1e090d"], "mix palette (P5 blacks, P6 night)"),
    ("worm", "flesh", ["#1e090d", "#3c0a1a", "#7d4650", "#c4917c", "#e8b08c", "#f0c8a4"], "mix worm ramp (P5), flesh shifted per A-001"),
    ("worm", "saddle", ["#c09b95"], "A palette (P2 saddle)"),
    ("dusk", "sky+water", ["#060d17", "#0a2a34", "#1f4d55", "#286168", "#528077", "#8fb0a2"], "P6-2 dusk; top step from P1 sky"),
    ("dusk", "silhouette", ["#04111c", "#19272c", "#25312e"], "P6-1 / P6-2 silhouettes"),
    ("light", "amber", ["#5a3214", "#a8601e", "#e68c33", "#f2b45e", "#fbe0a8"], "B palette amber (P6 lantern) + glow core"),
    ("ring", "grass crust", ["#25312e", "#46695e", "#65725a", "#8c9466"], "P6-2 reeds/grass, P1 grass line"),
    ("ring", "topsoil", ["#1c120e", "#3f261d", "#5e3d31", "#7d5640", "#a47c60"], "P5 lit soil (#a57259 nudged to #a47c60 for dE P2), P1 strata"),
    ("ring", "roots", ["#4d453c", "#655041", "#817964", "#a89a7c"], "P1 root mass"),
    ("ring", "dirt", ["#160e0c", "#2e2119", "#4a3a2c", "#5c4531", "#7a6450"], "P5 / P1 mid strata"),
    ("ring", "aquifer", ["#04111c", "#173f4e", "#27596c", "#40656c", "#577a77"], "P6-1 water"),
    ("ring", "rock", ["#0e1214", "#222a2c", "#2c3a39", "#3e5452", "#50746d", "#7d958c"], "P1 lower strata, mix teal"),
    ("ring", "core", ["#1a0d06", "#3d2008", "#7a4212", "#c0782a", "#f2b45e"], "amber ramp, darkened (core heat = amber, never red)"),
    ("ring", "castings", ["#0f0a08", "#2a1c16", "#3f2d24", "#8a7a6a"], "topsoil darkened + pale grit fleck"),
    ("life", "garden leaf", ["#2f4a3a", "#46695e", "#6a8458", "#b4b090"], "P6 reeds, P1 grass (kept >= 20 from P1 green)"),
    ("life", "chitin (threat)", ["#0b0d10", "#1b2226", "#33424a", "#6b7f86", "#c9d4d0"], "rock/teal ramp, cold; bone-pale top = 'edible now'"),
    ("space", "space", ["#010309", "#010d17", "#0a1a2a", "#1b2f45", "#fbe0a8"], "P6 night sky + amber star"),
]


def main():
    flat, rows = [], []
    for grp, name, hexes, src in RAMPS:
        for h in hexes:
            d1, d2 = de2000(h, P1), de2000(h, P2)
            flat.append({"group": grp, "ramp": name, "hex": h, "dE_P1": round(d1, 1), "dE_P2": round(d2, 1), "source": src})
            if min(d1, d2) < 20:
                print("FAIL", grp, name, h, round(d1, 1), round(d2, 1))
    os.makedirs("art/palette", exist_ok=True)
    json.dump({"version": "v1.0", "slot": {"P1": P1, "P2": P2}, "colours": flat}, open("art/palette/worm-v1.json", "w"), indent=1)
    uniq = list(dict.fromkeys(c["hex"] for c in flat))
    open("art/palette/worm-v1.hex", "w").write("\n".join(h[1:] for h in uniq + [P1, P2]) + "\n")
    with open("art/palette/worm-v1.gpl", "w") as f:
        f.write("GIMP Palette\nName: Life of a Worm v1.0\nColumns: 8\n#\n")
        for c in flat + [{"hex": P1, "ramp": "SLOT P1"}, {"hex": P2, "ramp": "SLOT P2"}]:
            r, g, b = (int(c["hex"][i:i + 2], 16) for i in (1, 3, 5))
            f.write(f"{r:3d} {g:3d} {b:3d}\t{c['ramp']} {c['hex']}\n")
    # swatch sheet
    sw, rh = 64, 92
    img = Image.new("RGB", (200 + 7 * sw, 30 + rh * (len(RAMPS) + 1)), "#14141a")
    d = ImageDraw.Draw(img)
    d.text((8, 8), "Life of a Worm palette v1.0 - dE00 to P1 / P2 under each swatch (>= 20 required)", fill="#dddddd")
    for i, (grp, name, hexes, src) in enumerate(RAMPS + [("slot", "SLOT (P1, P2)", [P1, P2], "player slot only")]):
        y = 30 + i * rh
        d.text((8, y + 20), f"{grp}/{name}", fill="#dddddd")
        for j, h in enumerate(hexes):
            x = 200 + j * sw
            d.rectangle((x, y, x + sw - 6, y + 50), fill=h)
            d.text((x, y + 54), h, fill="#bbbbbb")
            d.text((x, y + 68), f"{de2000(h, P1):.0f}/{de2000(h, P2):.0f}", fill="#888888")
    img.save("art/palette/worm-v1-swatches.png")
    print(len(uniq), "unique colours")


if __name__ == "__main__":
    main()
