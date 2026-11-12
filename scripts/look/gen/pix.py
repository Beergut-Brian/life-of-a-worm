"""Small pixel-art helpers for the ring art generator (Pillow only, no numpy).

Everything is deterministic: every function takes its own seed, so re-running the generator gives
byte-identical PNGs.
"""
import math
import random

from PIL import Image


def hexc(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def scale(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c)


def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(size, cells, seed):
    """Periodic value noise in [0, 1): size x size, `cells` lattice cells across (wraps)."""
    rng = random.Random(seed)
    g = [[rng.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * size for _ in range(size)]
    k = cells / size
    for y in range(size):
        fy = y * k
        y0 = int(fy)
        ty = smooth(fy - y0)
        y0 %= cells
        y1 = (y0 + 1) % cells
        for x in range(size):
            fx = x * k
            x0 = int(fx)
            tx = smooth(fx - x0)
            x0 %= cells
            x1 = (x0 + 1) % cells
            a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
            b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
            out[y][x] = a + (b - a) * ty
    return out


def fbm(size, seed, octaves=((4, 0.5), (8, 0.3), (16, 0.15), (32, 0.05))):
    acc = [[0.0] * size for _ in range(size)]
    tot = 0.0
    for i, (cells, w) in enumerate(octaves):
        n = value_noise(size, cells, seed * 31 + i)
        tot += w
        for y in range(size):
            row = acc[y]
            nr = n[y]
            for x in range(size):
                row[x] += nr[x] * w
    return [[v / tot for v in row] for row in acc]


def worley(size, n_points, seed):
    """Periodic Worley: per pixel (F1, F2, index of nearest point, nearest point)."""
    rng = random.Random(seed)
    pts = [(rng.random() * size, rng.random() * size) for _ in range(n_points)]
    out = []
    for y in range(size):
        row = []
        for x in range(size):
            best = [(1e9, -1, None), (1e9, -1, None)]
            for i, (px, py) in enumerate(pts):
                dx = abs(x + 0.5 - px)
                dy = abs(y + 0.5 - py)
                dx = min(dx, size - dx)
                dy = min(dy, size - dy)
                d = math.hypot(dx, dy)
                if d < best[0][0]:
                    best[1] = best[0]
                    best[0] = (d, i, (px, py))
                elif d < best[1][0]:
                    best[1] = (d, i, (px, py))
            row.append((best[0][0], best[1][0], best[0][1], best[0][2]))
        out.append(row)
    return out


def quantiles(field, cuts):
    """Thresholds so that the share of pixels below each threshold matches `cuts`."""
    vals = sorted(v for row in field for v in row)
    n = len(vals)
    return [vals[min(n - 1, int(c * n))] for c in cuts]


def normals_from_height(h, strength=2.0, wrap=True):
    """Height field (0..1 floats) -> RGB normal map (OpenGL style, green up)."""
    hgt = len(h)
    w = len(h[0])
    img = Image.new("RGB", (w, hgt))
    px = img.load()
    for y in range(hgt):
        for x in range(w):
            def at(xx, yy):
                if wrap:
                    return h[yy % hgt][xx % w]
                return h[max(0, min(hgt - 1, yy))][max(0, min(w - 1, xx))]
            dx = (at(x + 1, y) - at(x - 1, y)) * strength
            dy = (at(x, y + 1) - at(x, y - 1)) * strength
            nx, ny, nz = -dx, dy, 1.0
            ln = math.sqrt(nx * nx + ny * ny + nz * nz)
            px[x, y] = (int((nx / ln * 0.5 + 0.5) * 255), int((ny / ln * 0.5 + 0.5) * 255),
                        int((nz / ln * 0.5 + 0.5) * 255))
    return img


class Canvas:
    """A sprite canvas: colour per pixel plus a 'body' mask, so the ink outline can be added after."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.c = [[None] * w for _ in range(h)]

    def put(self, x, y, col):
        x = int(x)
        y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c[y][x] = col

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.c[y][x]
        return None

    def blob(self, cx, cy, rx, ry, base, shade=True, hi=None, lo=None, rot=0.0, light=(-0.6, -0.8)):
        """A shaded ellipse lit from the top left: 3 tones plus a specular pixel."""
        hi = hi or scale(base, 1.3)
        lo = lo or scale(base, 0.62)
        ca = math.cos(rot)
        sa = math.sin(rot)
        best = None
        for y in range(int(cy - max(rx, ry) - 2), int(cy + max(rx, ry) + 3)):
            for x in range(int(cx - max(rx, ry) - 2), int(cx + max(rx, ry) + 3)):
                dx = x + 0.5 - cx
                dy = y + 0.5 - cy
                u = (dx * ca + dy * sa) / rx
                v = (-dx * sa + dy * ca) / ry
                d = u * u + v * v
                if d > 1.0:
                    continue
                col = base
                if shade:
                    lit = -(u * light[0] + v * light[1])  # >0 facing the light
                    lit = lit * 0.8 + (1 - d) * 0.25
                    if lit > 0.55:
                        col = hi
                    elif lit < -0.3 or d > 0.8 and lit < 0.1:
                        col = lo
                    if best is None or lit > best[0]:
                        best = (lit, x, y)
                self.put(x, y, col)
        return best

    def poly(self, pts, col):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 2):
            yc = y + 0.5
            xs = []
            n = len(pts)
            for i in range(n):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % n]
                if (y1 <= yc < y2) or (y2 <= yc < y1):
                    xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.put(x, y, col)

    def line(self, x0, y0, x1, y1, col):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.put(round(x0 + (x1 - x0) * t - 0.5), round(y0 + (y1 - y0) * t - 0.5), col)

    def outline(self, ink, diag=False):
        """Ink every empty pixel touching the body (4-neighbour; 8 with diag)."""
        add = []
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diag:
            nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.c[y][x] is not None:
                    continue
                for dx, dy in nb:
                    v = self.get(x + dx, y + dy)
                    if v is not None and v != ink:
                        add.append((x, y))
                        break
        for x, y in add:
            self.c[y][x] = ink

    def paste_into(self, img, ox, oy):
        px = img.load()
        for y in range(self.h):
            for x in range(self.w):
                v = self.c[y][x]
                if v is not None:
                    px[ox + x, oy + y] = v + (255,) if len(v) == 3 else v
