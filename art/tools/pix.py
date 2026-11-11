"""Small pixel-drawing kit for the Worm look options: noise, dither, shaded shapes with normal maps."""
import math
from PIL import Image

from worm_looks import rgb, mix

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
FLAT_N = (128, 128, 255, 255)


def h2(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 982451653) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65536.0


def vnoise(x, y, sc, s=0):
    fx, fy = x / sc, y / sc
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = h2(ix, iy, s), h2(ix + 1, iy, s)
    c, d = h2(ix, iy + 1, s), h2(ix + 1, iy + 1, s)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


def bayer(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def pick(ramp, v, x, y, st):
    """Choose a ramp colour for brightness v in [0,1] according to the look's style."""
    v = max(0.0, min(0.999, v))
    if st["dither"]:
        f = v * (len(ramp) - 1)
        i = int(f)
        if f - i > bayer(x, y):
            i += 1
        return ramp[min(i, len(ramp) - 1)]
    if st["tile_shades"] == 2:  # flat: mostly mid, a shadow and a highlight
        return ramp[1] if v < 0.3 else (ramp[3] if v > 0.82 else ramp[2])
    if st["tile_shades"] == 3:
        return ramp[1] if v < 0.36 else (ramp[3] if v > 0.74 else ramp[2])
    return ramp[min(3, int(v * 4))]


def char_ramp(base, outline, lit=False):
    hi = mix(base, "#fff6d8" if lit else "#ffffff", 0.38)
    return [mix(base, outline, 0.55), mix(base, outline, 0.28), rgb(base), hi]


def enc_n(nx, ny, nz):
    l = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return (int((nx / l * 0.5 + 0.5) * 255), int((-ny / l * 0.5 + 0.5) * 255), int((nz / l * 0.5 + 0.5) * 255), 255)


LIGHT = (-0.45, -0.7, 0.55)


class Spr:
    """An RGBA sprite plus a matching normal map."""

    def __init__(self, w, h, st):
        self.w, self.h, self.st = w, h, st
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.nrm = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p, self.n = self.img.load(), self.nrm.load()

    def put(self, x, y, c, n=FLAT_N):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            c = rgb(c) if isinstance(c, str) else c
            self.p[x, y] = (c[0], c[1], c[2], 255)
            self.n[x, y] = n

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[x, y]
        return (0, 0, 0, 0)

    def clear(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = (0, 0, 0, 0)
            self.n[x, y] = (0, 0, 0, 0)

    def ell(self, cx, cy, rx, ry, ramp, mask=None, recolor=None, flat=False):
        """Shaded ellipse. ramp = 4 colours deep..high. recolor(nx,ny)->colour or None overrides."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if d > 1.0:
                    continue
                if mask and not mask(nx, ny):
                    continue
                nz = math.sqrt(max(0.0, 1 - d))
                v = max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])
                v = 0.55 if flat else v
                c = recolor(nx, ny, v) if recolor else None
                if c is None:
                    c = pick(ramp, v, x, y, self.st)
                self.put(x, y, c, enc_n(nx, ny, nz + 0.35))

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.put(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def outline(self, c, thick=1, diag=False):
        c = rgb(c) if isinstance(c, str) else c
        for _ in range(thick):
            src = self.img.copy().load()
            for y in range(self.h):
                for x in range(self.w):
                    if src[x, y][3]:
                        continue
                    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    if diag:
                        nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
                    for dx, dy in nb:
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3]:
                            self.p[x, y] = (c[0], c[1], c[2], 255)
                            self.n[x, y] = FLAT_N
                            break

    def save(self, path, normals=False):
        self.img.save(path)
        if normals:
            self.nrm.save(path.replace(".png", "_n.png"))


# ---- faces ------------------------------------------------------------------------------------

def eye(s, cx, cy, r, look_dx=0, look_dy=0, lid=None, ink=(20, 14, 24)):
    """White eye of radius r with a pupil; lid = fraction of the eye covered from the top (smug)."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= r * r + 0.3:
                s.put(x, y, "#ffffff")
    pr = max(0.6, r * 0.45)
    px, py = cx + look_dx * (r - pr), cy + look_dy * (r - pr)
    for y in range(int(py - pr - 1), int(py + pr + 2)):
        for x in range(int(px - pr - 1), int(px + pr + 2)):
            dx, dy = x + 0.5 - px, y + 0.5 - py
            if dx * dx + dy * dy <= pr * pr + 0.2:
                s.put(x, y, ink)
    if lid:
        top = cy - r + 2 * r * lid
        for y in range(int(cy - r - 1), int(top) + 1):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy <= r * r + 0.3:
                    s.put(x, y, lid_col(s, x, y))
        for x in range(int(cx - r), int(cx + r + 1)):
            s.put(x, int(top) + 1, ink)


def lid_col(s, x, y):
    return getattr(s, "lid", (60, 60, 90))


def mouth_o(s, cx, cy, r=1, ink=(40, 12, 30)):
    for y in range(int(cy - r), int(cy + r + 1)):
        for x in range(int(cx - r), int(cx + r + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                s.put(x, y, ink)


def smirk(s, x0, y0, w, ink=(20, 14, 24)):
    for i in range(w):
        s.put(x0 + i, y0 - (1 if i >= w - 2 else 0), ink)
    s.put(x0 + w, y0 - 2, ink)
