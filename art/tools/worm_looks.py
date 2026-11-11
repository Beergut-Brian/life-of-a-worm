"""Life of a Worm: the three look options (art-direction round 1). Pure data + colour helpers.

Every ring has a four-shade tile ramp (deep, low, mid, high) and two dug-out wall shades
(the back wall you see in a tunnel). `dom` is the ring's dominant hue (the mid shade).
Fixed in every option: P1 green #3cc24a, P2 red #e4393c (CLAUDE.md, art-direction.md).
"""

P1 = "#3cc24a"
P2 = "#e4393c"
RINGS = ["sky", "topsoil", "dirt", "rock", "core", "space"]

LOOKS = {
    "a": {
        "name": "A  Arcade Chomp",
        "slug": "a_arcade_chomp",
        "blurb": "Flat poster colour, 2 px ink outlines on every cut edge, huge faces, no lighting. "
                 "Loud and graphic, closest to Kaden's 'Super Mega Worm' note.",
        "outline": "#160f1e",
        "char_outline": "#160f1e",
        "ui_accent": "#ffd23a",
        "lights": {"sun": "#fff4c2", "worm": "#ffffff", "crystal": "#6af2ff", "core": "#ffb02e"},
        "sky": ["#2a7fe0", "#3d9bf0", "#62bdff", "#b4e6ff"],
        "space": ["#0b0b24", "#14163a", "#1e2356", "#2e3a7a"],
        "rings": {
            # deep, low, mid, high | wall, wall dark
            "topsoil": ["#0d3b3a", "#11564d", "#1a7a63", "#2a9688", "#0f3a34", "#0a2a26"],
            "dirt":    ["#4a2410", "#7a3d1a", "#a8622c", "#d48f4a", "#4e2a17", "#3a1e10"],
            "rock":    ["#22264e", "#343e78", "#4f62a8", "#7d93d6", "#272b4d", "#1c1f3a"],
            "core":    ["#9a4a0a", "#e08a12", "#ffbe2e", "#fff07a", "#b8641a", "#8a4610"],
        },
        "grass": ["#1a7a63", "#2a9688", "#8fe8d0"],
        "style": {"tile_shades": 2, "terrain_outline": 2, "char_outline": 1, "texture": 0.25,
                  "dither": False, "normals": False, "paper": False, "lit": False},
    },
    "b": {
        "name": "B  Lantern Deep",
        "slug": "b_lantern_deep",
        "blurb": "The lit, Terraria-like look: dense 4-shade textured tiles with ore flecks, normal maps, "
                 "dark ambient underground, light from the worms, crystals, the core and daylight shafts "
                 "through eaten holes, 3 parallax layers. Grown-up and adventurous.",
        "outline": "#120c10",
        "char_outline": "#140c12",
        "ui_accent": "#f2b544",
        "lights": {"sun": "#ffe2a8", "worm": "#d8ffe0", "crystal": "#59e6ff", "core": "#ff8a2a"},
        "sky": ["#2d5f96", "#4683bd", "#78afd8", "#c7e4f2"],
        "space": ["#05071a", "#0b1030", "#141c48", "#24306a"],
        "rings": {
            "topsoil": ["#1b2a1c", "#2a4229", "#3d5e36", "#5b7e45", "#2a3626", "#1e281b"],
            "dirt":    ["#2e1c13", "#4a2e1f", "#6c452c", "#93653d", "#43301f", "#322317"],
            "rock":    ["#1b2030", "#2c3448", "#435069", "#64758f", "#2a3144", "#1f2433"],
            "core":    ["#5a1c0e", "#7e3410", "#e0782a", "#ffc067", "#6a2814", "#4e1c0e"],
        },
        "grass": ["#3d5e36", "#5b7e45", "#9fbf63"],
        "style": {"tile_shades": 4, "terrain_outline": 0, "char_outline": 1, "texture": 1.0,
                  "dither": False, "normals": True, "paper": False, "lit": True},
    },
    "c": {
        "name": "C  Tall Tale",
        "slug": "c_tall_tale",
        "blurb": "Old Reel's story as a printed storybook: warm sun-faded palette, sepia ink line, "
                 "ordered-dither gradients and paper grain, like a fishing-tackle catalogue plate. "
                 "Ties the underground to the dock cutscenes.",
        "outline": "#3a2418",
        "char_outline": "#3a2418",
        "ui_accent": "#d8452c",
        "lights": {"sun": "#ffe6b0", "worm": "#fff1d0", "crystal": "#8fe3d0", "core": "#f2a03c"},
        "sky": ["#6d9fb8", "#8fbccb", "#bcd8d6", "#f2e4c0"],
        "space": ["#1b1d3a", "#262a50", "#343b68", "#4a5584"],
        "rings": {
            "topsoil": ["#3c4a26", "#56662f", "#768838", "#b8b060", "#4a4a2c", "#3a3a22"],
            "dirt":    ["#5a3420", "#7d4c2c", "#a2693c", "#c99560", "#6a4a34", "#54392a"],
            "rock":    ["#3c4256", "#56607a", "#76829c", "#a2acc0", "#4a4e5c", "#3a3d48"],
            "core":    ["#8a3c1c", "#c27434", "#eb9a3e", "#f8d27a", "#7a4428", "#5e331e"],
        },
        "grass": ["#768838", "#b8b060", "#d6d58a"],
        "style": {"tile_shades": 3, "terrain_outline": 1, "char_outline": 1, "texture": 0.6,
                  "dither": True, "normals": False, "paper": True, "lit": False},
    },
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c[:3])


def mix(a, b, t):
    a, b = rgb(a) if isinstance(a, str) else a, rgb(b) if isinstance(b, str) else b
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def dominant(look, ring):
    if ring in look["rings"]:
        return look["rings"][ring][2]
    return look[ring][2]


# ---- CIEDE2000 -------------------------------------------------------------------------------
import math


def _lab(c):
    c = rgb(c) if isinstance(c, str) else c
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in c)
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722)
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def de2000(c1, c2):
    L1, a1, b1 = _lab(c1)
    L2, a2, b2 = _lab(c2)
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = a1 * (1 + G), a2 * (1 + G)
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dLp, dCp = L2 - L1, C2p - C1p
    if C1p * C2p == 0:
        dhp = 0
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    elif h2p - h1p > 180:
        dhp = h2p - h1p - 360
    else:
        dhp = h2p - h1p + 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp / 2))
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2
    else:
        hbp = (h1p + h2p - 360) / 2
    T = (1 - 0.17 * math.cos(math.radians(hbp - 30)) + 0.24 * math.cos(math.radians(2 * hbp))
         + 0.32 * math.cos(math.radians(3 * hbp + 6)) - 0.20 * math.cos(math.radians(4 * hbp - 63)))
    dth = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + 0.015 * (Lbp - 50) ** 2 / math.sqrt(20 + (Lbp - 50) ** 2)
    Sc = 1 + 0.045 * Cbp
    Sh = 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dth)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2
                     + Rt * (dCp / Sc) * (dHp / Sh))
